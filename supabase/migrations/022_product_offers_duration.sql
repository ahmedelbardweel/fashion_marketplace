-- Timed Product Offers: start/end dates, offer title, and automatic expiration sync.

alter table public.products
  add column if not exists original_price numeric(10, 2),
  add column if not exists discount_amount numeric(10, 2) not null default 0,
  add column if not exists discount_percent integer not null default 0,
  add column if not exists offer_title text,
  add column if not exists offer_starts_at timestamptz,
  add column if not exists offer_ends_at timestamptz;

create index if not exists products_active_offers_idx
  on public.products (shop_id, discount_percent)
  where discount_percent > 0;

create index if not exists products_offers_expiry_idx
  on public.products (offer_ends_at)
  where discount_percent > 0 and offer_ends_at is not null;

-- Activates scheduled offers whose start time arrived and expires ended offers
-- by restoring the original price automatically.
create or replace function public.sync_product_offers()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_activated integer := 0;
  v_expired integer := 0;
begin
  -- 1) Activate scheduled offers whose start time has arrived and not yet ended
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
    and price <> round(original_price - discount_amount, 2);

  get diagnostics v_activated = row_count;

  -- 2) Expire offers whose end time has passed and restore original price
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
    and offer_ends_at <= now();

  get diagnostics v_expired = row_count;

  return v_activated + v_expired;
end;
$$;

grant execute on function public.sync_product_offers() to anon, authenticated;

-- Remove previous 2-argument signature to avoid PostgREST RPC overload ambiguity.
drop function if exists public.shop_set_product_offer(uuid, numeric);

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

  -- Keep existing timed offers synchronized first
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
    -- Remove active/scheduled offer and restore original price
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
    -- Apply discounted price immediately if starting now, otherwise keep base price until start time
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
