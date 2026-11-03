-- Shop platform: media, products variants/images, orders update, sales

alter table public.shops
  add column if not exists logo_path text,
  add column if not exists cover_path text;

create table if not exists public.shop_images (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  file_path text not null,
  kind text not null default 'gallery',
  created_at timestamptz not null default now()
);

create index if not exists shop_images_shop_idx on public.shop_images (shop_id);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  file_path text not null,
  kind text not null default 'gallery',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists product_images_product_idx on public.product_images (product_id);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  color text not null,
  size text not null,
  stock int not null default 0 check (stock >= 0),
  sku text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, color, size)
);

create index if not exists product_variants_product_idx on public.product_variants (product_id);

drop trigger if exists product_variants_set_updated_at on public.product_variants;
create trigger product_variants_set_updated_at
  before update on public.product_variants
  for each row execute function public.set_updated_at();

alter table public.shop_images enable row level security;
alter table public.product_images enable row level security;
alter table public.product_variants enable row level security;

create or replace function public.current_shop_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.shops where owner_id = auth.uid() limit 1;
$$;

create or replace function public.require_shop_owner()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  sid uuid;
begin
  if auth.uid() is null then
    raise exception 'غير مصرح';
  end if;
  select id into sid from public.shops where owner_id = auth.uid();
  if sid is null then
    raise exception 'لا يوجد محل مرتبط بالحساب';
  end if;
  return sid;
end;
$$;

create or replace function public.require_approved_shop()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  sid uuid;
  sstatus public.shop_status;
begin
  sid := public.require_shop_owner();
  select status into sstatus from public.shops where id = sid;
  if sstatus is distinct from 'approved' then
    raise exception 'يجب موافقة الإدارة قبل إدارة المنتجات والطلبات';
  end if;
  return sid;
end;
$$;

drop policy if exists "shop_images_owner_or_admin" on public.shop_images;
create policy "shop_images_owner_or_admin"
  on public.shop_images for all
  using (
    public.current_user_role() = 'admin'
    or shop_id = public.current_shop_id()
  )
  with check (
    public.current_user_role() = 'admin'
    or shop_id = public.current_shop_id()
  );

drop policy if exists "shop_documents_owner_write" on public.shop_documents;
create policy "shop_documents_owner_write"
  on public.shop_documents for insert
  with check (shop_id = public.current_shop_id());

drop policy if exists "shop_documents_owner_delete" on public.shop_documents;
create policy "shop_documents_owner_delete"
  on public.shop_documents for delete
  using (shop_id = public.current_shop_id());

drop policy if exists "product_images_owner_or_admin" on public.product_images;
create policy "product_images_owner_or_admin"
  on public.product_images for all
  using (
    public.current_user_role() = 'admin'
    or product_id in (
      select p.id from public.products p
      where p.shop_id = public.current_shop_id()
    )
  )
  with check (
    public.current_user_role() = 'admin'
    or product_id in (
      select p.id from public.products p
      where p.shop_id = public.current_shop_id()
    )
  );

drop policy if exists "product_variants_owner_or_admin" on public.product_variants;
create policy "product_variants_owner_or_admin"
  on public.product_variants for all
  using (
    public.current_user_role() = 'admin'
    or product_id in (
      select p.id from public.products p
      where p.shop_id = public.current_shop_id()
    )
  )
  with check (
    public.current_user_role() = 'admin'
    or product_id in (
      select p.id from public.products p
      where p.shop_id = public.current_shop_id()
    )
  );

-- Storage buckets
insert into storage.buckets (id, name, public)
values
  ('shop-media', 'shop-media', true),
  ('shop-documents', 'shop-documents', false),
  ('product-media', 'product-media', true)
on conflict (id) do nothing;

drop policy if exists "shop_media_read" on storage.objects;
create policy "shop_media_read"
  on storage.objects for select
  using (bucket_id in ('shop-media', 'product-media'));

drop policy if exists "shop_media_write" on storage.objects;
create policy "shop_media_write"
  on storage.objects for insert
  with check (
    bucket_id in ('shop-media', 'product-media', 'shop-documents')
    and auth.role() = 'authenticated'
  );

drop policy if exists "shop_media_update" on storage.objects;
create policy "shop_media_update"
  on storage.objects for update
  using (
    bucket_id in ('shop-media', 'product-media', 'shop-documents')
    and auth.role() = 'authenticated'
  );

drop policy if exists "shop_media_delete" on storage.objects;
create policy "shop_media_delete"
  on storage.objects for delete
  using (
    bucket_id in ('shop-media', 'product-media', 'shop-documents')
    and auth.role() = 'authenticated'
  );

drop policy if exists "shop_documents_read_owner_admin" on storage.objects;
create policy "shop_documents_read_owner_admin"
  on storage.objects for select
  using (
    bucket_id = 'shop-documents'
    and (
      public.current_user_role() = 'admin'
      or auth.uid()::text = (storage.foldername(name))[1]
    )
  );

-- Update shop media paths
create or replace function public.shop_set_media(
  p_logo_path text default null,
  p_cover_path text default null
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shops;
  sid uuid;
begin
  sid := public.require_shop_owner();
  update public.shops
  set
    logo_path = coalesce(p_logo_path, logo_path),
    cover_path = coalesce(p_cover_path, cover_path),
    updated_at = now()
  where id = sid
  returning * into result;
  return result;
end;
$$;

create or replace function public.shop_add_image(p_file_path text, p_kind text default 'gallery')
returns public.shop_images
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shop_images;
  sid uuid;
begin
  sid := public.require_shop_owner();
  if coalesce(trim(p_file_path), '') = '' then
    raise exception 'مسار الصورة مطلوب';
  end if;
  insert into public.shop_images (shop_id, file_path, kind)
  values (sid, trim(p_file_path), coalesce(nullif(trim(p_kind), ''), 'gallery'))
  returning * into result;
  return result;
end;
$$;

create or replace function public.shop_add_document(p_doc_type text, p_file_path text)
returns public.shop_documents
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shop_documents;
  sid uuid;
begin
  sid := public.require_shop_owner();
  if coalesce(trim(p_doc_type), '') = '' or coalesce(trim(p_file_path), '') = '' then
    raise exception 'نوع المستند والمسار مطلوبان';
  end if;
  insert into public.shop_documents (shop_id, doc_type, file_path)
  values (sid, trim(p_doc_type), trim(p_file_path))
  returning * into result;
  return result;
end;
$$;

create or replace function public.shop_upsert_product(
  p_name text,
  p_description text,
  p_price numeric,
  p_category_id uuid default null,
  p_status public.product_status default 'draft',
  p_id uuid default null
)
returns public.products
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.products;
  sid uuid;
begin
  sid := public.require_approved_shop();

  if coalesce(trim(p_name), '') = '' then
    raise exception 'اسم المنتج مطلوب';
  end if;
  if p_price is null or p_price < 0 then
    raise exception 'السعر غير صالح';
  end if;
  if p_status not in ('draft', 'published', 'hidden') then
    raise exception 'حالة المنتج غير مسموحة';
  end if;

  if p_id is null then
    insert into public.products (shop_id, category_id, name, description, price, status)
    values (sid, p_category_id, trim(p_name), nullif(trim(p_description), ''), p_price, p_status)
    returning * into result;
  else
    update public.products
    set
      category_id = p_category_id,
      name = trim(p_name),
      description = nullif(trim(p_description), ''),
      price = p_price,
      status = p_status,
      updated_at = now()
    where id = p_id
      and shop_id = sid
      and status is distinct from 'deleted'
    returning * into result;
  end if;

  if result.id is null then
    raise exception 'المنتج غير موجود';
  end if;
  return result;
end;
$$;

create or replace function public.shop_set_product_status(
  p_product_id uuid,
  p_status public.product_status
)
returns public.products
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.products;
  sid uuid;
begin
  sid := public.require_approved_shop();
  if p_status not in ('draft', 'published', 'hidden', 'deleted') then
    raise exception 'حالة غير مسموحة';
  end if;

  update public.products
  set status = p_status, updated_at = now()
  where id = p_product_id
    and shop_id = sid
    and status is distinct from 'deleted'
  returning * into result;

  if result.id is null then
    raise exception 'المنتج غير موجود';
  end if;
  return result;
end;
$$;

create or replace function public.shop_upsert_variant(
  p_product_id uuid,
  p_color text,
  p_size text,
  p_stock int,
  p_id uuid default null
)
returns public.product_variants
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.product_variants;
  sid uuid;
begin
  sid := public.require_approved_shop();

  if not exists (
    select 1 from public.products
    where id = p_product_id and shop_id = sid and status is distinct from 'deleted'
  ) then
    raise exception 'المنتج غير موجود';
  end if;

  if coalesce(trim(p_color), '') = '' or coalesce(trim(p_size), '') = '' then
    raise exception 'اللون والمقاس مطلوبان';
  end if;
  if p_stock is null or p_stock < 0 then
    raise exception 'المخزون غير صالح';
  end if;

  if p_id is null then
    insert into public.product_variants (product_id, color, size, stock)
    values (p_product_id, trim(p_color), trim(p_size), p_stock)
    on conflict (product_id, color, size)
    do update set stock = excluded.stock, is_active = true, updated_at = now()
    returning * into result;
  else
    update public.product_variants
    set
      color = trim(p_color),
      size = trim(p_size),
      stock = p_stock,
      updated_at = now()
    where id = p_id
      and product_id = p_product_id
    returning * into result;
  end if;

  return result;
end;
$$;

create or replace function public.shop_add_product_image(
  p_product_id uuid,
  p_file_path text,
  p_kind text default 'gallery'
)
returns public.product_images
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.product_images;
  sid uuid;
begin
  sid := public.require_approved_shop();
  if not exists (
    select 1 from public.products where id = p_product_id and shop_id = sid
  ) then
    raise exception 'المنتج غير موجود';
  end if;
  if coalesce(trim(p_file_path), '') = '' then
    raise exception 'مسار الصورة مطلوب';
  end if;

  insert into public.product_images (product_id, file_path, kind)
  values (
    p_product_id,
    trim(p_file_path),
    case when p_kind = 'ar' then 'ar' else 'gallery' end
  )
  returning * into result;
  return result;
end;
$$;

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

create or replace function public.shop_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  sid uuid;
begin
  sid := public.require_shop_owner();
  return jsonb_build_object(
    'products', (
      select count(*) from public.products
      where shop_id = sid and status is distinct from 'deleted'
    ),
    'published_products', (
      select count(*) from public.products
      where shop_id = sid and status = 'published'
    ),
    'orders', (select count(*) from public.orders where shop_id = sid),
    'pending_orders', (
      select count(*) from public.orders
      where shop_id = sid and status in ('pending', 'confirmed', 'processing')
    ),
    'sales_total', coalesce((
      select sum(total) from public.orders
      where shop_id = sid and status in ('delivered', 'shipped', 'processing', 'confirmed')
    ), 0),
    'stock_units', coalesce((
      select sum(v.stock) from public.product_variants v
      join public.products p on p.id = v.product_id
      where p.shop_id = sid and p.status is distinct from 'deleted'
    ), 0)
  );
end;
$$;

create or replace function public.shop_update_profile(
  p_shop_name text,
  p_description text,
  p_city text,
  p_address text,
  p_commercial_register text,
  p_owner_name text,
  p_phone text
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shops;
  sid uuid;
  sstatus public.shop_status;
begin
  sid := public.require_shop_owner();
  select status into sstatus from public.shops where id = sid;

  if sstatus not in ('approved', 'draft', 'rejected') then
    raise exception 'لا يمكن تعديل الملف في الحالة الحالية';
  end if;

  if coalesce(trim(p_shop_name), '') = ''
     or coalesce(trim(p_description), '') = ''
     or coalesce(trim(p_city), '') = ''
     or coalesce(trim(p_address), '') = ''
     or coalesce(trim(p_commercial_register), '') = ''
     or coalesce(trim(p_owner_name), '') = ''
     or coalesce(trim(p_phone), '') = '' then
    raise exception 'جميع الحقول مطلوبة';
  end if;

  update public.profiles
  set
    full_name = trim(p_owner_name),
    phone = trim(p_phone),
    city = trim(p_city),
    address = trim(p_address),
    updated_at = now()
  where id = auth.uid();

  update public.shops
  set
    name = trim(p_shop_name),
    description = trim(p_description),
    city = trim(p_city),
    address = trim(p_address),
    commercial_register = trim(p_commercial_register),
    updated_at = now()
  where id = sid
  returning * into result;

  return result;
end;
$$;

grant execute on function public.current_shop_id() to authenticated;
grant execute on function public.require_shop_owner() to authenticated;
grant execute on function public.require_approved_shop() to authenticated;
grant execute on function public.shop_set_media(text, text) to authenticated;
grant execute on function public.shop_add_image(text, text) to authenticated;
grant execute on function public.shop_add_document(text, text) to authenticated;
grant execute on function public.shop_upsert_product(text, text, numeric, uuid, public.product_status, uuid) to authenticated;
grant execute on function public.shop_set_product_status(uuid, public.product_status) to authenticated;
grant execute on function public.shop_upsert_variant(uuid, text, text, int, uuid) to authenticated;
grant execute on function public.shop_add_product_image(uuid, text, text) to authenticated;
grant execute on function public.shop_update_order_status(uuid, public.order_status) to authenticated;
grant execute on function public.shop_dashboard_stats() to authenticated;
grant execute on function public.shop_update_profile(text, text, text, text, text, text, text) to authenticated;
