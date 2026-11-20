-- Product Offers / Discounts support for Shop Offers screen & Customer cards.

alter table public.products
  add column if not exists original_price numeric(10, 2),
  add column if not exists discount_amount numeric(10, 2) not null default 0,
  add column if not exists discount_percent integer not null default 0;

create index if not exists products_active_offers_idx
  on public.products (shop_id, discount_percent)
  where discount_percent > 0;

create or replace function public.shop_set_product_offer(
  p_product_id uuid,
  p_discount_amount numeric
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
  new_price numeric(10, 2);
  pct integer;
  next_details jsonb;
  result_json jsonb;
begin
  if sid is null then
    raise exception 'Shop account required';
  end if;

  select * into prod
  from public.products
  where id = p_product_id and shop_id = sid;

  if prod.id is null then
    raise exception 'Product not found';
  end if;

  base_price := coalesce(prod.original_price, prod.price);
  clean_discount := coalesce(p_discount_amount, 0);

  if clean_discount <= 0 then
    -- Remove active offer and restore original price
    next_details := coalesce(prod.details, '{}'::jsonb)
      - 'original_price'
      - 'discount_amount'
      - 'discount_percent';

    update public.products
    set
      price = base_price,
      original_price = null,
      discount_amount = 0,
      discount_percent = 0,
      details = next_details,
      updated_at = now()
    where id = p_product_id;
  else
    if clean_discount >= base_price then
      raise exception 'Discount must be less than the product price';
    end if;

    new_price := round(base_price - clean_discount, 2);
    pct := greatest(1, least(99, round((clean_discount / base_price) * 100)::integer));
    next_details := coalesce(prod.details, '{}'::jsonb) || jsonb_build_object(
      'original_price', base_price,
      'discount_amount', round(clean_discount, 2),
      'discount_percent', pct
    );

    update public.products
    set
      price = new_price,
      original_price = base_price,
      discount_amount = round(clean_discount, 2),
      discount_percent = pct,
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

grant execute on function public.shop_set_product_offer(uuid, numeric) to authenticated;
