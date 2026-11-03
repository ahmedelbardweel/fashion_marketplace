-- 008_customer_experience.sql
-- Customer features: order_items, favorites, product_reviews, RPCs, and RLS policies

-- 1. Order Items Table
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid references public.product_variants(id) on delete set null,
  product_name text not null,
  variant_info text,
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  quantity int not null check (quantity > 0),
  total_price numeric(12, 2) not null check (total_price >= 0),
  created_at timestamptz not null default now()
);

create index if not exists order_items_order_idx on public.order_items (order_id);
create index if not exists order_items_product_idx on public.order_items (product_id);

-- 2. Favorites Table
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (customer_id, product_id)
);

create index if not exists favorites_customer_idx on public.favorites (customer_id);
create index if not exists favorites_product_idx on public.favorites (product_id);

-- 3. Product Reviews Table
create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  rating int not null check (rating >= 1 and rating <= 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (customer_id, product_id)
);

create index if not exists product_reviews_product_idx on public.product_reviews (product_id);
create index if not exists product_reviews_customer_idx on public.product_reviews (customer_id);

-- 4. Enable RLS
alter table public.order_items enable row level security;
alter table public.favorites enable row level security;
alter table public.product_reviews enable row level security;

-- 5. Policies
-- Order items: Customer can read their own order items, shop owner can read items for their orders, admin can read all
drop policy if exists "order_items_customer_select" on public.order_items;
create policy "order_items_customer_select" on public.order_items
  for select using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (
          o.customer_id = auth.uid()
          or exists (select 1 from public.shops s where s.id = o.shop_id and s.owner_id = auth.uid())
          or public.current_user_role() = 'admin'
        )
    )
  );

-- Favorites: Customers manage their own favorites
drop policy if exists "favorites_owner_manage" on public.favorites;
create policy "favorites_owner_manage" on public.favorites
  for all using (customer_id = auth.uid())
  with check (customer_id = auth.uid());

-- Product reviews: Anyone can read reviews, customer can insert/update their own
drop policy if exists "product_reviews_select" on public.product_reviews;
create policy "product_reviews_select" on public.product_reviews
  for select using (true);

drop policy if exists "product_reviews_owner_manage" on public.product_reviews;
create policy "product_reviews_owner_manage" on public.product_reviews
  for all using (customer_id = auth.uid())
  with check (customer_id = auth.uid());

-- Ensure customer can read active shops and published products
drop policy if exists "customer_read_approved_shops" on public.shops;
create policy "customer_read_approved_shops" on public.shops
  for select using (status = 'approved');

drop policy if exists "customer_read_published_products" on public.products;
create policy "customer_read_published_products" on public.products
  for select using (status = 'published');

drop policy if exists "customer_read_product_variants" on public.product_variants;
create policy "customer_read_product_variants" on public.product_variants
  for select using (is_active = true);

drop policy if exists "customer_read_product_images" on public.product_images;
create policy "customer_read_product_images" on public.product_images
  for select using (true);

drop policy if exists "customer_read_categories" on public.categories;
create policy "customer_read_categories" on public.categories
  for select using (is_active = true);

drop policy if exists "customer_read_banners" on public.banners;
create policy "customer_read_banners" on public.banners
  for select using (is_active = true);

-- 6. RPC: Atomic Customer Place Order
create or replace function public.customer_place_order(
  p_shop_id uuid,
  p_items jsonb,
  p_delivery_address text,
  p_phone text
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

  -- Create order record
  insert into public.orders (customer_id, shop_id, status, total)
  values (v_customer_id, p_shop_id, 'pending', 0)
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
      order_id, product_id, variant_id, product_name, variant_info, unit_price, quantity, total_price
    )
    values (
      v_order.id, v_product_id, v_variant_id, v_product_name, v_variant_info, v_price, v_qty, (v_price * v_qty)
    );

    v_total := v_total + (v_price * v_qty);
  end loop;

  -- Update order total
  update public.orders
  set total = v_total
  where id = v_order.id
  returning * into v_order;

  -- Update customer profile phone/address if empty
  update public.profiles
  set phone = coalesce(nullif(phone, ''), p_phone),
      address = coalesce(nullif(address, ''), p_delivery_address)
  where id = v_customer_id;

  return v_order;
end;
$$;
