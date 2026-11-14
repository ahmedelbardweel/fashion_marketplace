-- 015_supabase_cart_and_orders_sync.sql
-- Persistent Supabase storage for customer cart_items, comparison_items, and full order delivery metadata

-- 1. Customer Cart Items Table (persisted per customer in Supabase)
create table if not exists public.cart_items (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete set null,
  color text not null default '',
  size text not null default '',
  quantity int not null default 1 check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, product_id, color, size)
);

create index if not exists cart_items_customer_idx on public.cart_items (customer_id);
create index if not exists cart_items_product_idx on public.cart_items (product_id);

alter table public.cart_items enable row level security;

drop policy if exists "cart_items_owner_manage" on public.cart_items;
create policy "cart_items_owner_manage" on public.cart_items
  for all using (customer_id = auth.uid())
  with check (customer_id = auth.uid());

-- 2. Customer Product Comparison Table (persisted per customer in Supabase)
create table if not exists public.comparison_items (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (customer_id, product_id)
);

create index if not exists comparison_items_customer_idx on public.comparison_items (customer_id);

alter table public.comparison_items enable row level security;

drop policy if exists "comparison_items_owner_manage" on public.comparison_items;
create policy "comparison_items_owner_manage" on public.comparison_items
  for all using (customer_id = auth.uid())
  with check (customer_id = auth.uid());

-- 3. Add delivery details columns to orders & image_path to order_items
alter table public.orders
  add column if not exists delivery_address text,
  add column if not exists phone text,
  add column if not exists notes text;

alter table public.order_items
  add column if not exists image_path text;

-- 4. Update customer_place_order RPC to store delivery metadata & clear ordered items from cart_items
create or replace function public.customer_place_order(
  p_shop_id uuid,
  p_items jsonb,
  p_delivery_address text,
  p_phone text,
  p_notes text default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_order public.orders;
  v_total numeric(12, 2) := 0;
  v_item jsonb;
  v_price numeric(12, 2);
  v_qty int;
  v_product_id uuid;
  v_variant_id uuid;
  v_product_name text;
  v_variant_info text;
  v_image_path text;
  v_stock int;
begin
  v_customer_id := auth.uid();
  if v_customer_id is null then
    raise exception 'يجب تسجيل الدخول لإتمام الطلب';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'السلة فارغة';
  end if;

  -- Verify shop exists and is approved
  if not exists (select 1 from public.shops where id = p_shop_id and status = 'approved') then
    raise exception 'المحل غير متوفر أو غير معتمد';
  end if;

  -- Create order record with delivery address, phone, and notes
  insert into public.orders (
    customer_id,
    shop_id,
    status,
    total,
    delivery_address,
    phone,
    notes
  )
  values (
    v_customer_id,
    p_shop_id,
    'pending',
    0,
    nullif(trim(p_delivery_address), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(coalesce(p_notes, '')), '')
  )
  returning * into v_order;

  -- Loop through items, calculate total and insert order_items
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_variant_id := nullif(v_item->>'variant_id', '')::uuid;
    v_qty := coalesce((v_item->>'quantity')::int, 1);
    v_price := (v_item->>'unit_price')::numeric;
    v_product_name := coalesce(v_item->>'product_name', 'منتج');
    v_variant_info := v_item->>'variant_info';
    v_image_path := nullif(v_item->>'image_path', '');

    -- Check and decrement stock if variant provided
    if v_variant_id is not null then
      select stock into v_stock
      from public.product_variants
      where id = v_variant_id for update;

      if v_stock is null or v_stock < v_qty then
        raise exception 'الكمية المطلوبة غير متوفرة في المخزون للمنتج %', v_product_name;
      end if;

      update public.product_variants
      set stock = stock - v_qty
      where id = v_variant_id;
    end if;

    insert into public.order_items (
      order_id,
      product_id,
      variant_id,
      product_name,
      variant_info,
      unit_price,
      quantity,
      total_price,
      image_path
    )
    values (
      v_order.id,
      v_product_id,
      v_variant_id,
      v_product_name,
      v_variant_info,
      v_price,
      v_qty,
      (v_price * v_qty),
      v_image_path
    );

    v_total := v_total + (v_price * v_qty);

    -- Remove ordered item from persistent cart_items table
    delete from public.cart_items
    where customer_id = v_customer_id
      and product_id = v_product_id;
  end loop;

  -- Update order total
  update public.orders
  set total = v_total
  where id = v_order.id
  returning * into v_order;

  -- Update customer profile phone/address if empty
  update public.profiles
  set phone = coalesce(nullif(phone, ''), nullif(trim(p_phone), '')),
      address = coalesce(nullif(address, ''), nullif(trim(p_delivery_address), ''))
  where id = v_customer_id;

  return v_order;
end;
$$;
