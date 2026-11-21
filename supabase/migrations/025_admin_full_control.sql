-- Full Admin Control RPCs: Orders intervention, Offers moderation, Banners full control,
-- Region-targeted notifications, and Enriched Dashboard Stats.

-- 1) Optional target region on notifications
alter table public.notifications
  add column if not exists target_region text;

-- 2) Seed additional platform control settings (safe & idempotent)
insert into public.platform_settings (key, value, label)
values
  ('platform_commission_percent', '5', 'نسبة عمولة المنصة (%)'),
  ('maintenance_mode', 'false', 'وضع الصيانة المؤقت'),
  ('support_whatsapp', '+970590000000', 'رقم واتساب الدعم الفني')
on conflict (key) do nothing;

-- 3) Admin Order Status Override / Intervention
create or replace function public.admin_update_order_status(
  p_order_id uuid,
  p_status text
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders;
begin
  perform public.require_admin();

  if p_status not in ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled') then
    raise exception 'حالة الطلب غير صالحة';
  end if;

  update public.orders
  set
    status = p_status::public.order_status,
    updated_at = now()
  where id = p_order_id
  returning * into v_order;

  if v_order.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  return v_order;
end;
$$;

grant execute on function public.admin_update_order_status(uuid, text) to authenticated;

-- 4) Admin Offer Moderation: Cancel any violating product offer & refresh that shop's auto banner
create or replace function public.admin_cancel_product_offer(p_product_id uuid)
returns public.products
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prod public.products;
  v_base_price numeric(10, 2);
begin
  perform public.require_admin();

  select * into v_prod
  from public.products
  where id = p_product_id;

  if v_prod.id is null then
    raise exception 'المنتج غير موجود';
  end if;

  v_base_price := coalesce(v_prod.original_price, v_prod.price);

  update public.products
  set
    price = v_base_price,
    original_price = null,
    discount_amount = 0,
    discount_percent = 0,
    offer_title = null,
    offer_starts_at = null,
    offer_ends_at = null,
    details = coalesce(details, '{}'::jsonb)
      - 'original_price'
      - 'discount_amount'
      - 'discount_percent'
      - 'offer_title'
      - 'offer_starts_at'
      - 'offer_ends_at',
    updated_at = now()
  where id = p_product_id
  returning * into v_prod;

  perform public.sync_shop_offer_banner(v_prod.shop_id);

  return v_prod;
end;
$$;

grant execute on function public.admin_cancel_product_offer(uuid) to authenticated;

-- 5) Upgraded Admin Banner Upsert (supports image upload, cta_label, sort_order, and editing any banner)
drop function if exists public.admin_upsert_banner(text, text, boolean, uuid);
drop function if exists public.admin_upsert_banner(text, text, boolean, uuid, text);

create or replace function public.admin_upsert_banner(
  p_title text,
  p_subtitle text default null,
  p_is_active boolean default true,
  p_id uuid default null,
  p_image_path text default null,
  p_cta_label text default null,
  p_sort_order int default 0
)
returns public.banners
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.banners;
  clean_cta text := nullif(trim(coalesce(p_cta_label, '')), '');
  clean_img text := nullif(trim(coalesce(p_image_path, '')), '');
begin
  perform public.require_admin();

  if coalesce(trim(p_title), '') = '' then
    raise exception 'عنوان البنر مطلوب';
  end if;

  if p_id is null then
    insert into public.banners (
      title,
      subtitle,
      image_path,
      cta_label,
      is_active,
      sort_order
    )
    values (
      trim(p_title),
      nullif(trim(coalesce(p_subtitle, '')), ''),
      clean_img,
      clean_cta,
      coalesce(p_is_active, true),
      coalesce(p_sort_order, 0)
    )
    returning * into result;
  else
    update public.banners
    set
      title = trim(p_title),
      subtitle = nullif(trim(coalesce(p_subtitle, '')), ''),
      image_path = clean_img,
      cta_label = coalesce(clean_cta, cta_label),
      is_active = coalesce(p_is_active, true),
      sort_order = coalesce(p_sort_order, sort_order),
      updated_at = now()
    where id = p_id
    returning * into result;
  end if;

  return result;
end;
$$;

grant execute on function public.admin_upsert_banner(text, text, boolean, uuid, text, text, int) to authenticated;

-- 6) Upgraded Admin Send Notification (supports optional Gaza region targeting)
drop function if exists public.admin_send_notification(text, text, public.notification_audience);

create or replace function public.admin_send_notification(
  p_title text,
  p_body text,
  p_audience public.notification_audience,
  p_target_region text default null
)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.notifications;
  v_region text := nullif(trim(coalesce(p_target_region, '')), '');
begin
  perform public.require_admin();

  if coalesce(trim(p_title), '') = '' or coalesce(trim(p_body), '') = '' then
    raise exception 'العنوان ونص الإشعار مطلوبان';
  end if;

  insert into public.notifications (
    title,
    body,
    audience,
    target_region,
    sender_role,
    target_scope
  )
  values (
    trim(p_title),
    trim(p_body),
    p_audience,
    v_region,
    'admin',
    case when v_region is not null then 'region' else 'audience' end
  )
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.admin_send_notification(text, text, public.notification_audience, text) to authenticated;

-- 7) Enriched Admin Dashboard Stats
create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today_start timestamptz := date_trunc('day', now());
begin
  perform public.require_admin();

  return jsonb_build_object(
    'customers', (select count(*) from public.profiles where role = 'customer'),
    'shops', (select count(*) from public.shops where status is distinct from 'draft'),
    'pending_shops', (select count(*) from public.shops where status = 'pending'),
    'approved_shops', (select count(*) from public.shops where status = 'approved'),
    'suspended_shops', (select count(*) from public.shops where status = 'suspended'),
    'products', (select count(*) from public.products where status is distinct from 'deleted'),
    'hidden_products', (select count(*) from public.products where status = 'hidden'),
    'active_offers', (
      select count(*) from public.products
      where status = 'published'
        and discount_percent > 0
        and (offer_starts_at is null or offer_starts_at <= now())
        and (offer_ends_at is null or offer_ends_at > now())
    ),
    'orders', (select count(*) from public.orders),
    'today_orders', (select count(*) from public.orders where created_at >= v_today_start),
    'today_sales', coalesce((select sum(total) from public.orders where created_at >= v_today_start and status is distinct from 'cancelled'), 0),
    'total_sales', coalesce((select sum(total) from public.orders where status is distinct from 'cancelled'), 0),
    'categories', (select count(*) from public.categories),
    'banners', (select count(*) from public.banners),
    'notifications', (select count(*) from public.notifications),
    'regions_total', (select count(*) from public.gaza_regions),
    'active_regions', (select count(*) from public.gaza_regions where is_active = true and is_delivery_available = true)
  );
end;
$$;

grant execute on function public.admin_dashboard_stats() to authenticated;
