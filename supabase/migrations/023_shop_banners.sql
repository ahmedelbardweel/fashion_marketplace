-- Shop-owned Banners & Automatic Offer Banner Sync
-- 1) Links banners optionally to a shop (shop_id = null => Admin platform banner)
-- 2) Automatically creates/updates/deactivates a shop's offers banner whenever offers change or expire
-- 3) Gives shops full control over ONLY their own banners via secure RPCs

alter table public.banners
  add column if not exists shop_id uuid references public.shops(id) on delete cascade,
  add column if not exists is_auto_offer boolean not null default false,
  add column if not exists cta_label text;

create index if not exists banners_shop_idx
  on public.banners (shop_id);

create unique index if not exists banners_shop_auto_offer_uidx
  on public.banners (shop_id)
  where is_auto_offer = true and shop_id is not null;

-- RLS: Allow shop owners to read their own banners (active or paused)
drop policy if exists "banners_shop_own_read" on public.banners;
create policy "banners_shop_own_read"
  on public.banners for select
  using (
    shop_id is not null
    and shop_id = public.current_shop_id()
  );

-- Synchronizes a shop's automatic "Offers Banner" based on currently active offers.
create or replace function public.sync_shop_offer_banner(p_shop_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops;
  v_active_count integer := 0;
  v_max_discount integer := 0;
  v_offer_image text;
  v_banner_image text;
  v_title text;
  v_subtitle text;
begin
  if p_shop_id is null then
    return;
  end if;

  select * into v_shop
  from public.shops
  where id = p_shop_id;

  if v_shop.id is null then
    return;
  end if;

  -- If shop is not approved, deactivate its auto offer banner
  if v_shop.status is distinct from 'approved' then
    update public.banners
    set is_active = false, updated_at = now()
    where shop_id = p_shop_id and is_auto_offer = true;
    return;
  end if;

  select
    count(*)::integer,
    coalesce(max(p.discount_percent), 0)::integer
  into v_active_count, v_max_discount
  from public.products p
  where p.shop_id = p_shop_id
    and p.status = 'published'
    and p.discount_percent > 0
    and (p.offer_starts_at is null or p.offer_starts_at <= now())
    and (p.offer_ends_at is null or p.offer_ends_at > now());

  if v_active_count > 0 then
    select pi.file_path into v_offer_image
    from public.products p
    join public.product_images pi on pi.product_id = p.id
    where p.shop_id = p_shop_id
      and p.status = 'published'
      and p.discount_percent > 0
      and (p.offer_starts_at is null or p.offer_starts_at <= now())
      and (p.offer_ends_at is null or p.offer_ends_at > now())
    order by p.discount_percent desc, pi.sort_order asc
    limit 1;

    v_banner_image := coalesce(
      nullif(trim(coalesce(v_shop.cover_path, '')), ''),
      nullif(trim(coalesce(v_offer_image, '')), ''),
      nullif(trim(coalesce(v_shop.logo_path, '')), '')
    );

    v_title := 'عروض ' || v_shop.name || ' — خصم حتى ' || v_max_discount || '%';
    if v_active_count = 1 then
      v_subtitle := 'عروض مميزة لفترة محدودة في ' || v_shop.name || ' — تصفح المحل الآن';
    else
      v_subtitle := v_active_count || ' منتجات عليها عروض حالياً — تصفح المحل الآن';
    end if;

    insert into public.banners (
      shop_id,
      is_auto_offer,
      title,
      subtitle,
      image_path,
      cta_label,
      is_active,
      sort_order
    )
    values (
      p_shop_id,
      true,
      v_title,
      v_subtitle,
      v_banner_image,
      'تصفح المحل',
      true,
      0
    )
    on conflict (shop_id) where (is_auto_offer = true and shop_id is not null)
    do update set
      title = excluded.title,
      subtitle = excluded.subtitle,
      image_path = coalesce(nullif(trim(coalesce(public.banners.image_path, '')), ''), excluded.image_path),
      cta_label = coalesce(nullif(trim(coalesce(public.banners.cta_label, '')), ''), 'تصفح المحل'),
      is_active = true,
      updated_at = now();
  else
    update public.banners
    set is_active = false, updated_at = now()
    where shop_id = p_shop_id
      and is_auto_offer = true
      and is_active = true;
  end if;
end;
$$;

-- Update sync_product_offers() so activating or expiring timed offers also syncs shop offer banners
create or replace function public.sync_product_offers()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_activated integer := 0;
  v_expired integer := 0;
  v_affected_shops uuid[] := '{}'::uuid[];
  v_shop_id uuid;
begin
  with activated as (
    update public.products
    set
      price = round(original_price - discount_amount, 2),
      updated_at = now()
    where discount_percent > 0
      and original_price is not null
      and discount_amount > 0
      and discount_amount < original_price
      and (offer_starts_at is null or offer_starts_at <= now())
      and (offer_ends_at is null or offer_ends_at > now())
      and price <> round(original_price - discount_amount, 2)
    returning shop_id
  )
  select count(*)::integer, coalesce(array_agg(distinct shop_id), '{}'::uuid[])
  into v_activated, v_affected_shops
  from activated;

  with expired as (
    update public.products
    set
      price = coalesce(original_price, price),
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
    where discount_percent > 0
      and offer_ends_at is not null
      and offer_ends_at <= now()
    returning shop_id
  )
  select
    count(*)::integer,
    v_affected_shops || coalesce(array_agg(distinct shop_id), '{}'::uuid[])
  into v_expired, v_affected_shops
  from expired;

  for v_shop_id in
    select distinct unnest(v_affected_shops)
  loop
    perform public.sync_shop_offer_banner(v_shop_id);
  end loop;

  return v_activated + v_expired;
end;
$$;

grant execute on function public.sync_product_offers() to anon, authenticated;

-- Update shop_set_product_offer() to automatically create/refresh/deactivate the shop's offer banner
create or replace function public.shop_set_product_offer(
  p_product_id uuid,
  p_discount_amount numeric,
  p_offer_starts_at timestamptz default now(),
  p_offer_ends_at timestamptz default null,
  p_offer_title text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := public.current_shop_id();
  prod public.products;
  base_price numeric(10, 2);
  clean_discount numeric(10, 2);
  clean_title text;
  starts_at timestamptz;
  ends_at timestamptz;
  new_price numeric(10, 2);
  applied_price numeric(10, 2);
  pct integer;
  next_details jsonb;
  result_json jsonb;
begin
  if sid is null then
    raise exception 'Shop account required';
  end if;

  perform public.sync_product_offers();

  select * into prod
  from public.products
  where id = p_product_id and shop_id = sid;

  if prod.id is null then
    raise exception 'Product not found';
  end if;

  base_price := coalesce(prod.original_price, prod.price);
  clean_discount := coalesce(p_discount_amount, 0);
  clean_title := nullif(trim(coalesce(p_offer_title, '')), '');

  if clean_discount <= 0 then
    next_details := coalesce(prod.details, '{}'::jsonb)
      - 'original_price'
      - 'discount_amount'
      - 'discount_percent'
      - 'offer_title'
      - 'offer_starts_at'
      - 'offer_ends_at';

    update public.products
    set
      price = base_price,
      original_price = null,
      discount_amount = 0,
      discount_percent = 0,
      offer_title = null,
      offer_starts_at = null,
      offer_ends_at = null,
      details = next_details,
      updated_at = now()
    where id = p_product_id;
  else
    if clean_discount >= base_price then
      raise exception 'Discount must be less than the product price';
    end if;

    starts_at := coalesce(p_offer_starts_at, now());
    ends_at := coalesce(p_offer_ends_at, starts_at + interval '7 days');

    if ends_at <= starts_at then
      raise exception 'Offer end date must be after start date';
    end if;

    if ends_at <= now() then
      raise exception 'Offer end date must be in the future';
    end if;

    new_price := round(base_price - clean_discount, 2);
    applied_price := case when starts_at <= now() then new_price else base_price end;
    pct := greatest(1, least(99, round((clean_discount / base_price) * 100)::integer));

    next_details := (
      coalesce(prod.details, '{}'::jsonb)
      - 'offer_title'
    ) || jsonb_build_object(
      'original_price', base_price,
      'discount_amount', round(clean_discount, 2),
      'discount_percent', pct,
      'offer_starts_at', starts_at,
      'offer_ends_at', ends_at
    );

    if clean_title is not null then
      next_details := next_details || jsonb_build_object('offer_title', clean_title);
    end if;

    update public.products
    set
      price = applied_price,
      original_price = base_price,
      discount_amount = round(clean_discount, 2),
      discount_percent = pct,
      offer_title = clean_title,
      offer_starts_at = starts_at,
      offer_ends_at = ends_at,
      details = next_details,
      updated_at = now()
    where id = p_product_id;
  end if;

  -- Automatically create/update/deactivate the shop's offers banner
  perform public.sync_shop_offer_banner(sid);

  select to_jsonb(p.*) || jsonb_build_object(
    'categories', (select to_jsonb(c.*) from public.categories c where c.id = p.category_id),
    'product_variants', coalesce((select jsonb_agg(to_jsonb(v.*)) from public.product_variants v where v.product_id = p.id), '[]'::jsonb),
    'product_images', coalesce((select jsonb_agg(to_jsonb(i.*) order by i.sort_order) from public.product_images i where i.product_id = p.id), '[]'::jsonb)
  )
  into result_json
  from public.products p
  where p.id = p_product_id;

  return result_json;
end;
$$;

grant execute on function public.shop_set_product_offer(uuid, numeric, timestamptz, timestamptz, text) to authenticated;

-- Shop-only banner create/update RPC (strictly scoped to current shop)
create or replace function public.shop_upsert_banner(
  p_title text,
  p_subtitle text default null,
  p_image_path text default null,
  p_is_active boolean default true,
  p_cta_label text default 'تصفح المحل',
  p_id uuid default null
)
returns public.banners
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := public.current_shop_id();
  v_shop public.shops;
  v_result public.banners;
  v_cta text;
begin
  if sid is null then
    raise exception 'Shop account required';
  end if;

  select * into v_shop from public.shops where id = sid;
  if v_shop.id is null or v_shop.status is distinct from 'approved' then
    raise exception 'Approved shop required to manage banners';
  end if;

  if coalesce(trim(p_title), '') = '' then
    raise exception 'عنوان البنر مطلوب';
  end if;

  v_cta := coalesce(nullif(trim(coalesce(p_cta_label, '')), ''), 'تصفح المحل');

  if p_id is null then
    insert into public.banners (
      shop_id,
      is_auto_offer,
      title,
      subtitle,
      image_path,
      cta_label,
      is_active,
      sort_order
    )
    values (
      sid,
      false,
      trim(p_title),
      nullif(trim(coalesce(p_subtitle, '')), ''),
      nullif(trim(coalesce(p_image_path, '')), ''),
      v_cta,
      coalesce(p_is_active, true),
      1
    )
    returning * into v_result;
  else
    update public.banners
    set
      title = trim(p_title),
      subtitle = nullif(trim(coalesce(p_subtitle, '')), ''),
      image_path = nullif(trim(coalesce(p_image_path, '')), ''),
      cta_label = v_cta,
      is_active = coalesce(p_is_active, true),
      updated_at = now()
    where id = p_id
      and shop_id = sid
    returning * into v_result;

    if v_result.id is null then
      raise exception 'Banner not found or access denied';
    end if;
  end if;

  return v_result;
end;
$$;

grant execute on function public.shop_upsert_banner(text, text, text, boolean, text, uuid) to authenticated;

-- Shop-only banner delete RPC (strictly scoped to current shop)
create or replace function public.shop_delete_banner(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  sid uuid := public.current_shop_id();
  v_deleted integer := 0;
begin
  if sid is null then
    raise exception 'Shop account required';
  end if;

  delete from public.banners
  where id = p_id
    and shop_id = sid;

  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then
    raise exception 'Banner not found or access denied';
  end if;
end;
$$;

grant execute on function public.shop_delete_banner(uuid) to authenticated;

-- Backfill auto-offer banners for any approved shops that already have active offers
do $$
declare
  r record;
begin
  for r in
    select distinct shop_id
    from public.products
    where status = 'published'
      and discount_percent > 0
      and (offer_starts_at is null or offer_starts_at <= now())
      and (offer_ends_at is null or offer_ends_at > now())
  loop
    perform public.sync_shop_offer_banner(r.shop_id);
  end loop;
end $$;
