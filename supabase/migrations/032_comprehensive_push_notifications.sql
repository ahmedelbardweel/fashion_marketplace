-- =============================================================================
--  032_comprehensive_push_notifications.sql
--  Complete App-Wide Event Notification Triggers:
--  Automatically inserts rich notifications (with deep-link metadata) into
--  public.notifications for EVERY key app event so Push Notifications fire
--  even when the app is completely closed/terminated:
--    1) New order placed -> notifies Shop owner + Customer confirmation
--    2) Order status changed -> notifies Customer (+ Shop if customer cancelled)
--    3) New product published -> notifies Customers
--    4) New product offer/discount -> notifies Customers
--    5) New active promo banner -> notifies Customers
--    6) New product review -> notifies Shop owner
--    7) Shop application submitted / approved / rejected / suspended -> Admin & Shop
--    8) Shop settlement submitted / approved / rejected -> Admin & Shop
-- =============================================================================
begin;

-- 1) Add rich deep-link metadata column to public.notifications
alter table public.notifications
  add column if not exists metadata jsonb not null default '{}'::jsonb;

-- 2) Remove duplicate manual insert inside shop_update_order_status so the
--    unified AFTER UPDATE trigger on public.orders is the single source of truth.
create or replace function public.shop_update_order_status(
  p_order_id uuid,
  p_status public.order_status
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.orders;
  sid uuid;
begin
  sid := public.require_approved_shop();

  if p_status not in ('confirmed', 'processing', 'shipped', 'delivered', 'cancelled') then
    raise exception 'حالة الطلب غير مسموحة';
  end if;

  update public.orders
  set status = p_status, updated_at = now()
  where id = p_order_id
    and shop_id = sid
  returning * into result;

  if result.id is null then
    raise exception 'الطلب غير موجود';
  end if;

  return result;
end;
$$;

grant execute on function public.shop_update_order_status(uuid, public.order_status) to authenticated;

-- Helper: notify all active admins
create or replace function public.notify_all_admins(
  p_title text,
  p_body text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    target_user_id,
    sender_role,
    target_scope,
    metadata
  )
  select
    p_title,
    p_body,
    'all',
    auth.uid(),
    pr.id,
    'system',
    'user',
    coalesce(p_metadata, '{}'::jsonb)
  from public.profiles pr
  where pr.role = 'admin'
    and pr.is_active = true
    and pr.id is distinct from auth.uid();
end;
$$;

-- 3) Trigger: New Order -> notify Shop Owner + Customer confirmation
create or replace function public.trg_notify_on_order_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_owner_id uuid;
  v_shop_name text;
  v_customer_name text;
  v_total_text text;
begin
  select owner_id, name into v_shop_owner_id, v_shop_name
  from public.shops
  where id = new.shop_id;

  select coalesce(nullif(trim(full_name), ''), email, 'عميل')
    into v_customer_name
  from public.profiles
  where id = new.customer_id;

  v_total_text := to_char(coalesce(new.total, 0), 'FM999999990.##');

  -- Notify shop owner about the new order
  if v_shop_owner_id is not null and v_shop_owner_id <> new.customer_id then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      target_user_id,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'طلب جديد في متجرك 🛍️',
      'وصلك طلب جديد من ' || coalesce(v_customer_name, 'عميل') || ' بقيمة ' || v_total_text || ' ₪.',
      'shop',
      new.customer_id,
      v_shop_owner_id,
      new.shop_id,
      'system',
      'user',
      jsonb_build_object(
        'event_type', 'order_created',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'route', '/shop/orders'
      )
    );
  end if;

  -- Notify customer confirming order receipt
  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    target_user_id,
    shop_id,
    sender_role,
    target_scope,
    metadata
  )
  values (
    'تم استلام طلبك بنجاح ✅',
    'تم إرسال طلبك إلى ' || coalesce(v_shop_name, 'المتجر') || ' بقيمة ' || v_total_text || ' ₪ وسنبلغك بكل تحديث.',
    'customer',
    null,
    new.customer_id,
    new.shop_id,
    'system',
    'user',
    jsonb_build_object(
      'event_type', 'order_confirmed_receipt',
      'order_id', new.id,
      'shop_id', new.shop_id,
      'route', '/customer/orders/' || new.id::text
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_orders_notify_insert on public.orders;
create trigger trg_orders_notify_insert
  after insert on public.orders
  for each row
  execute function public.trg_notify_on_order_insert();

-- 4) Trigger: Order Status Updated -> notify Customer (and Shop if cancelled by customer)
create or replace function public.trg_notify_on_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_owner_id uuid;
  v_shop_name text;
  v_status_title text;
  v_status_body text;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  select owner_id, name into v_shop_owner_id, v_shop_name
  from public.shops
  where id = new.shop_id;

  v_status_title := case new.status
    when 'confirmed' then 'تم تأكيد طلبك ✅'
    when 'processing' then 'جاري تجهيز طلبك 📦'
    when 'shipped' then 'طلبك في الطريق إليك 🚚'
    when 'delivered' then 'تم تسليم طلبك بنجاح 🎉'
    when 'cancelled' then 'تم إلغاء طلبك'
    else 'تحديث جديد على طلبك'
  end;

  v_status_body := coalesce(v_shop_name, 'المتجر') || ': ' || v_status_title || '.';

  -- Notify customer unless the customer themselves cancelled it
  if auth.uid() is distinct from new.customer_id then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      target_user_id,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      v_status_title,
      v_status_body,
      'customer',
      auth.uid(),
      new.customer_id,
      new.shop_id,
      'shop',
      'user',
      jsonb_build_object(
        'event_type', 'order_status_changed',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'status', new.status::text,
        'route', '/customer/orders/' || new.id::text
      )
    );
  end if;

  -- If customer cancelled, notify shop owner
  if new.status = 'cancelled'
     and v_shop_owner_id is not null
     and auth.uid() = new.customer_id then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      target_user_id,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'تم إلغاء طلب من عميل',
      'قام العميل بإلغاء الطلب رقم #' || left(new.id::text, 8) || '.',
      'shop',
      new.customer_id,
      v_shop_owner_id,
      new.shop_id,
      'system',
      'user',
      jsonb_build_object(
        'event_type', 'order_cancelled_by_customer',
        'order_id', new.id,
        'shop_id', new.shop_id,
        'route', '/shop/orders'
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_orders_notify_status_change on public.orders;
create trigger trg_orders_notify_status_change
  after update of status on public.orders
  for each row
  when (old.status is distinct from new.status)
  execute function public.trg_notify_on_order_status_change();

-- 5) Trigger: New Product Review -> notify Shop Owner
create or replace function public.trg_notify_on_product_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_name text;
  v_shop_id uuid;
  v_shop_owner_id uuid;
  v_customer_name text;
begin
  select p.name, p.shop_id, s.owner_id
    into v_product_name, v_shop_id, v_shop_owner_id
  from public.products p
  join public.shops s on s.id = p.shop_id
  where p.id = new.product_id;

  if v_shop_owner_id is null or v_shop_owner_id = new.customer_id then
    return new;
  end if;

  select coalesce(nullif(trim(full_name), ''), 'عميل')
    into v_customer_name
  from public.profiles
  where id = new.customer_id;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    target_user_id,
    shop_id,
    sender_role,
    target_scope,
    metadata
  )
  values (
    'تقييم جديد على منتجك ⭐ (' || new.rating || '/5)',
    v_customer_name || ' قيّم "' || coalesce(v_product_name, 'منتج') || '"' ||
      case
        when nullif(trim(coalesce(new.comment, '')), '') is not null
          then ': ' || left(trim(new.comment), 80)
        else '.'
      end,
    'shop',
    new.customer_id,
    v_shop_owner_id,
    v_shop_id,
    'system',
    'user',
    jsonb_build_object(
      'event_type', 'new_review',
      'product_id', new.product_id,
      'shop_id', v_shop_id,
      'route', '/shop/products'
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_product_reviews_notify on public.product_reviews;
create trigger trg_product_reviews_notify
  after insert on public.product_reviews
  for each row
  execute function public.trg_notify_on_product_review();

-- 6) Trigger: New Published Product or New Discount/Offer -> notify Customers
create or replace function public.trg_notify_on_product_published_or_offer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_name text;
  v_shop_owner_id uuid;
  v_price_text text;
  v_became_published boolean := false;
  v_new_offer boolean := false;
begin
  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_became_published := true;
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from 'published' then
      v_became_published := true;
    elsif (new.price < old.price)
       or (coalesce(new.details->>'offer_active', 'false') = 'true'
           and coalesce(old.details->>'offer_active', 'false') <> 'true') then
      v_new_offer := true;
    end if;
  end if;

  if not v_became_published and not v_new_offer then
    return new;
  end if;

  select name, owner_id into v_shop_name, v_shop_owner_id
  from public.shops
  where id = new.shop_id;

  v_price_text := to_char(coalesce(new.price, 0), 'FM999999990.##');

  if v_new_offer then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'عرض وخصم جديد 🔥',
      coalesce(v_shop_name, 'متجر') || ' أطلق خصماً على "' || new.name || '" الآن بسعر ' || v_price_text || ' ₪!',
      'customer',
      v_shop_owner_id,
      new.shop_id,
      'shop',
      'all_customers',
      jsonb_build_object(
        'event_type', 'product_offer',
        'product_id', new.id,
        'shop_id', new.shop_id,
        'route', '/customer/products/' || new.id::text
      )
    );
  elsif v_became_published then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'وصول قطعة جديدة ✨',
      coalesce(v_shop_name, 'متجر') || ' أضاف "' || new.name || '" بسعر ' || v_price_text || ' ₪ — جرّبها افتراضياً الآن!',
      'customer',
      v_shop_owner_id,
      new.shop_id,
      'shop',
      'all_customers',
      jsonb_build_object(
        'event_type', 'product_published',
        'product_id', new.id,
        'shop_id', new.shop_id,
        'route', '/customer/products/' || new.id::text
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_products_notify_publish_or_offer on public.products;
create trigger trg_products_notify_publish_or_offer
  after insert or update of status, price, details on public.products
  for each row
  execute function public.trg_notify_on_product_published_or_offer();

-- 7) Trigger: New Active Promotional Banner -> notify Customers
create or replace function public.trg_notify_on_banner_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.is_active, false) = false then
    return new;
  end if;

  insert into public.notifications (
    title,
    body,
    audience,
    created_by,
    shop_id,
    sender_role,
    target_scope,
    metadata
  )
  values (
    coalesce(nullif(trim(new.title), ''), 'عرض جديد في وصلة 🎉'),
    coalesce(nullif(trim(new.subtitle), ''), 'تصفح أحدث العروض والبنرات الحصرية داخل التطبيق الآن.'),
    'customer',
    auth.uid(),
    new.shop_id,
    case when new.shop_id is not null then 'shop' else 'admin' end,
    'all_customers',
    jsonb_build_object(
      'event_type', 'new_banner',
      'banner_id', new.id,
      'shop_id', new.shop_id,
      'route', case
        when new.shop_id is not null then '/customer/shops/' || new.shop_id::text
        else '/customer/home'
      end
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_banners_notify_insert on public.banners;
create trigger trg_banners_notify_insert
  after insert on public.banners
  for each row
  execute function public.trg_notify_on_banner_insert();

-- 8) Trigger: Shop Status Changes -> notify Admins on submission, Shop on decision
create or replace function public.trg_notify_on_shop_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'pending' then
    perform public.notify_all_admins(
      'طلب متجر جديد بانتظار المراجعة 🏪',
      'قدّم متجر "' || coalesce(new.name, 'متجر') || '" طلباً للانضمام إلى المنصة.',
      jsonb_build_object(
        'event_type', 'shop_application_submitted',
        'shop_id', new.id,
        'route', '/admin/shops/' || new.id::text
      )
    );
  elsif new.status = 'approved' then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      target_user_id,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      'تم تفعيل متجرك بنجاح 🎉',
      'متجرك "' || coalesce(new.name, 'متجر') || '" أصبح نشطاً الآن ويمكنك إضافة منتجاتك وبدء البيع.',
      'shop',
      auth.uid(),
      new.owner_id,
      new.id,
      'admin',
      'user',
      jsonb_build_object(
        'event_type', 'shop_approved',
        'shop_id', new.id,
        'route', '/shop/home'
      )
    );
  elsif new.status in ('rejected', 'suspended') then
    insert into public.notifications (
      title,
      body,
      audience,
      created_by,
      target_user_id,
      shop_id,
      sender_role,
      target_scope,
      metadata
    )
    values (
      case when new.status = 'rejected' then 'تحديث على طلب متجرك' else 'تم إيقاف متجرك مؤقتاً' end,
      coalesce(nullif(trim(new.rejection_reason), ''), 'يرجى مراجعة حالة المتجر والتواصل مع الإدارة.'),
      'shop',
      auth.uid(),
      new.owner_id,
      new.id,
      'admin',
      'user',
      jsonb_build_object(
        'event_type', 'shop_' || new.status::text,
        'shop_id', new.id,
        'route', '/shop/status'
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_shops_notify_status_change on public.shops;
create trigger trg_shops_notify_status_change
  after update of status on public.shops
  for each row
  when (old.status is distinct from new.status)
  execute function public.trg_notify_on_shop_status_change();

-- 9) Trigger: Shop Settlements -> notify Admins on new request, Shop on review
create or replace function public.trg_notify_on_settlement_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_owner_id uuid;
  v_shop_name text;
  v_amount_text text;
begin
  select owner_id, name into v_shop_owner_id, v_shop_name
  from public.shops
  where id = new.shop_id;

  v_amount_text := to_char(coalesce(new.amount, 0), 'FM999999990.##');

  if tg_op = 'INSERT' then
    perform public.notify_all_admins(
      'تسوية مالية جديدة من متجر 💰',
      'أرسل متجر "' || coalesce(v_shop_name, 'متجر') || '" طلب تسوية بقيمة ' || v_amount_text || ' ₪.',
      jsonb_build_object(
        'event_type', 'settlement_submitted',
        'shop_id', new.shop_id,
        'route', '/admin/revenue'
      )
    );
  elsif tg_op = 'UPDATE' and old.status is distinct from new.status and v_shop_owner_id is not null then
    if new.status in ('approved', 'rejected') then
      insert into public.notifications (
        title,
        body,
        audience,
        created_by,
        target_user_id,
        shop_id,
        sender_role,
        target_scope,
        metadata
      )
      values (
        case when new.status = 'approved'
          then 'تم اعتماد التسوية المالية ✅'
          else 'تم رفض طلب التسوية المالية'
        end,
        case when new.status = 'approved'
          then 'تمت الموافقة على حوالة بقيمة ' || v_amount_text || ' ₪.'
          else coalesce(nullif(trim(new.admin_note), ''), 'يرجى مراجعة تفاصيل التسوية المالية في لوحة المبيعات.')
        end,
        'shop',
        auth.uid(),
        v_shop_owner_id,
        new.shop_id,
        'admin',
        'user',
        jsonb_build_object(
          'event_type', 'settlement_' || new.status,
          'shop_id', new.shop_id,
          'route', '/shop/sales'
        )
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_shop_settlements_notify on public.shop_settlements;
create trigger trg_shop_settlements_notify
  after insert or update of status on public.shop_settlements
  for each row
  execute function public.trg_notify_on_settlement_change();

notify pgrst, 'reload schema';
commit;
