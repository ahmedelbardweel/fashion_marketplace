-- Admin platform: categories, products, orders, banners, notifications, settings

create or replace function public.require_admin()
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.current_user_role() is distinct from 'admin' then
    raise exception 'للإدارة فقط';
  end if;
end;
$$;

do $$ begin
  create type public.product_status as enum ('draft', 'published', 'hidden', 'deleted');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.order_status as enum (
    'pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.notification_audience as enum ('all', 'customer', 'shop');
exception when duplicate_object then null;
end $$;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shop_documents (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  doc_type text not null,
  file_path text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  category_id uuid references public.categories (id) on delete set null,
  name text not null,
  description text,
  price numeric(12, 2) not null default 0,
  status public.product_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_shop_idx on public.products (shop_id);
create index if not exists products_status_idx on public.products (status);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles (id) on delete restrict,
  shop_id uuid not null references public.shops (id) on delete restrict,
  status public.order_status not null default 'pending',
  total numeric(12, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists orders_shop_idx on public.orders (shop_id);
create index if not exists orders_customer_idx on public.orders (customer_id);

create table if not exists public.banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  image_path text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience public.notification_audience not null default 'all',
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.notification_reads (
  notification_id uuid not null references public.notifications (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (notification_id, user_id)
);

create table if not exists public.platform_settings (
  key text primary key,
  value text not null,
  label text not null,
  updated_at timestamptz not null default now()
);

insert into public.platform_settings (key, value, label)
values
  ('app_name', 'Fashion Marketplace', 'اسم التطبيق'),
  ('decision_delay_hours', '24', 'تأخير ظهور قرار المحل (ساعات)'),
  ('allow_registrations', 'true', 'السماح بالتسجيل الجديد')
on conflict (key) do nothing;

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();

drop trigger if exists banners_set_updated_at on public.banners;
create trigger banners_set_updated_at
  before update on public.banners
  for each row execute function public.set_updated_at();

alter table public.categories enable row level security;
alter table public.shop_documents enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.banners enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_reads enable row level security;
alter table public.platform_settings enable row level security;

drop policy if exists "categories_public_read" on public.categories;
create policy "categories_public_read"
  on public.categories for select
  using (is_active = true or public.current_user_role() = 'admin');

drop policy if exists "categories_admin_all" on public.categories;
create policy "categories_admin_all"
  on public.categories for all
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists "shop_documents_owner_or_admin" on public.shop_documents;
create policy "shop_documents_owner_or_admin"
  on public.shop_documents for select
  using (
    public.current_user_role() = 'admin'
    or shop_id in (select id from public.shops where owner_id = auth.uid())
  );

drop policy if exists "shop_documents_admin_all" on public.shop_documents;
create policy "shop_documents_admin_all"
  on public.shop_documents for all
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists "products_admin_all" on public.products;
create policy "products_admin_all"
  on public.products for all
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists "products_public_published" on public.products;
create policy "products_public_published"
  on public.products for select
  using (status = 'published');

drop policy if exists "products_shop_own" on public.products;
create policy "products_shop_own"
  on public.products for all
  using (
    shop_id in (select id from public.shops where owner_id = auth.uid())
  )
  with check (
    shop_id in (select id from public.shops where owner_id = auth.uid())
  );

drop policy if exists "orders_admin_all" on public.orders;
create policy "orders_admin_all"
  on public.orders for all
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists "orders_customer_own" on public.orders;
create policy "orders_customer_own"
  on public.orders for select
  using (customer_id = auth.uid());

drop policy if exists "orders_shop_own" on public.orders;
create policy "orders_shop_own"
  on public.orders for select
  using (shop_id in (select id from public.shops where owner_id = auth.uid()));

drop policy if exists "banners_public_read" on public.banners;
create policy "banners_public_read"
  on public.banners for select
  using (is_active = true or public.current_user_role() = 'admin');

drop policy if exists "banners_admin_all" on public.banners;
create policy "banners_admin_all"
  on public.banners for all
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

drop policy if exists "notifications_read" on public.notifications;
create policy "notifications_read"
  on public.notifications for select
  using (
    public.current_user_role() = 'admin'
    or audience = 'all'
    or (audience = 'customer' and public.current_user_role() = 'customer')
    or (audience = 'shop' and public.current_user_role() = 'shop')
  );

drop policy if exists "notifications_admin_insert" on public.notifications;
create policy "notifications_admin_insert"
  on public.notifications for insert
  with check (public.current_user_role() = 'admin');

drop policy if exists "notification_reads_own" on public.notification_reads;
create policy "notification_reads_own"
  on public.notification_reads for all
  using (user_id = auth.uid() or public.current_user_role() = 'admin')
  with check (user_id = auth.uid() or public.current_user_role() = 'admin');

drop policy if exists "settings_admin_read" on public.platform_settings;
create policy "settings_admin_read"
  on public.platform_settings for select
  using (public.current_user_role() = 'admin');

drop policy if exists "settings_admin_all" on public.platform_settings;
create policy "settings_admin_all"
  on public.platform_settings for all
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- Decision delay from settings
create or replace function public.review_shop_application(
  p_shop_id uuid,
  p_approve boolean,
  p_rejection_reason text default null
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shops;
  delay_hours int;
begin
  perform public.require_admin();

  if not p_approve and coalesce(trim(p_rejection_reason), '') = '' then
    raise exception 'سبب الرفض مطلوب';
  end if;

  begin
    select greatest(0, value::int) into delay_hours
    from public.platform_settings
    where key = 'decision_delay_hours';
  exception when others then
    delay_hours := 24;
  end;
  delay_hours := coalesce(delay_hours, 24);

  update public.shops
  set
    status = case
      when p_approve then 'approved'::public.shop_status
      else 'rejected'::public.shop_status
    end,
    rejection_reason = case
      when p_approve then null
      else trim(p_rejection_reason)
    end,
    decision_at = now(),
    decision_visible_at = now() + make_interval(hours => delay_hours),
    updated_at = now()
  where id = p_shop_id
    and status = 'pending'
  returning * into result;

  if result.id is null then
    raise exception 'الطلب غير موجود أو تمت مراجعته مسبقاً';
  end if;

  return result;
end;
$$;

create or replace function public.admin_set_shop_suspended(
  p_shop_id uuid,
  p_suspend boolean
)
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shops;
begin
  perform public.require_admin();

  update public.shops
  set
    status = case
      when p_suspend then 'suspended'::public.shop_status
      else 'approved'::public.shop_status
    end,
    updated_at = now()
  where id = p_shop_id
    and status in ('approved', 'suspended')
  returning * into result;

  if result.id is null then
    raise exception 'يمكن تعليق أو تفعيل المحلات المعتمدة فقط';
  end if;

  return result;
end;
$$;

create or replace function public.admin_set_user_active(
  p_user_id uuid,
  p_is_active boolean
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.profiles;
begin
  perform public.require_admin();

  update public.profiles
  set is_active = p_is_active, updated_at = now()
  where id = p_user_id
    and role is distinct from 'admin'
  returning * into result;

  if result.id is null then
    raise exception 'لا يمكن تعديل هذا الحساب';
  end if;

  return result;
end;
$$;

create or replace function public.admin_upsert_category(
  p_name text,
  p_description text default null,
  p_is_active boolean default true,
  p_id uuid default null
)
returns public.categories
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.categories;
begin
  perform public.require_admin();

  if coalesce(trim(p_name), '') = '' then
    raise exception 'اسم التصنيف مطلوب';
  end if;

  if p_id is null then
    insert into public.categories (name, description, is_active)
    values (trim(p_name), nullif(trim(p_description), ''), p_is_active)
    returning * into result;
  else
    update public.categories
    set
      name = trim(p_name),
      description = nullif(trim(p_description), ''),
      is_active = p_is_active,
      updated_at = now()
    where id = p_id
    returning * into result;
  end if;

  if result.id is null then
    raise exception 'التصنيف غير موجود';
  end if;

  return result;
end;
$$;

create or replace function public.admin_set_product_status(
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
begin
  perform public.require_admin();

  if p_status not in ('hidden', 'deleted', 'published') then
    raise exception 'حالة غير مسموحة';
  end if;

  update public.products
  set status = p_status, updated_at = now()
  where id = p_product_id
    and status is distinct from 'deleted'
  returning * into result;

  if result.id is null then
    raise exception 'المنتج غير موجود';
  end if;

  return result;
end;
$$;

create or replace function public.admin_upsert_banner(
  p_title text,
  p_subtitle text default null,
  p_is_active boolean default true,
  p_id uuid default null
)
returns public.banners
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.banners;
begin
  perform public.require_admin();

  if coalesce(trim(p_title), '') = '' then
    raise exception 'عنوان البنر مطلوب';
  end if;

  if p_id is null then
    insert into public.banners (title, subtitle, is_active)
    values (trim(p_title), nullif(trim(p_subtitle), ''), p_is_active)
    returning * into result;
  else
    update public.banners
    set
      title = trim(p_title),
      subtitle = nullif(trim(p_subtitle), ''),
      is_active = p_is_active,
      updated_at = now()
    where id = p_id
    returning * into result;
  end if;

  return result;
end;
$$;

create or replace function public.admin_delete_banner(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  delete from public.banners where id = p_id;
end;
$$;

create or replace function public.admin_send_notification(
  p_title text,
  p_body text,
  p_audience public.notification_audience
)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.notifications;
begin
  perform public.require_admin();

  if coalesce(trim(p_title), '') = '' or coalesce(trim(p_body), '') = '' then
    raise exception 'عنوان ومحتوى الإشعار مطلوبان';
  end if;

  insert into public.notifications (title, body, audience, created_by)
  values (trim(p_title), trim(p_body), p_audience, auth.uid())
  returning * into result;

  return result;
end;
$$;

create or replace function public.admin_update_setting(
  p_key text,
  p_value text
)
returns public.platform_settings
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.platform_settings;
begin
  perform public.require_admin();

  if coalesce(trim(p_value), '') = '' then
    raise exception 'القيمة مطلوبة';
  end if;

  update public.platform_settings
  set value = trim(p_value), updated_at = now()
  where key = p_key
  returning * into result;

  if result.key is null then
    raise exception 'الإعداد غير موجود';
  end if;

  return result;
end;
$$;

create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.require_admin();

  return jsonb_build_object(
    'customers', (select count(*) from public.profiles where role = 'customer'),
    'shops', (select count(*) from public.shops),
    'pending_shops', (select count(*) from public.shops where status = 'pending'),
    'approved_shops', (select count(*) from public.shops where status = 'approved'),
    'suspended_shops', (select count(*) from public.shops where status = 'suspended'),
    'products', (select count(*) from public.products where status is distinct from 'deleted'),
    'hidden_products', (select count(*) from public.products where status = 'hidden'),
    'orders', (select count(*) from public.orders),
    'categories', (select count(*) from public.categories),
    'banners', (select count(*) from public.banners),
    'notifications', (select count(*) from public.notifications)
  );
end;
$$;

grant execute on function public.require_admin() to authenticated;
grant execute on function public.admin_set_shop_suspended(uuid, boolean) to authenticated;
grant execute on function public.admin_set_user_active(uuid, boolean) to authenticated;
grant execute on function public.admin_upsert_category(text, text, boolean, uuid) to authenticated;
grant execute on function public.admin_set_product_status(uuid, public.product_status) to authenticated;
grant execute on function public.admin_upsert_banner(text, text, boolean, uuid) to authenticated;
grant execute on function public.admin_delete_banner(uuid) to authenticated;
grant execute on function public.admin_send_notification(text, text, public.notification_audience) to authenticated;
grant execute on function public.admin_update_setting(text, text) to authenticated;
grant execute on function public.admin_dashboard_stats() to authenticated;
grant execute on function public.review_shop_application(uuid, boolean, text) to authenticated;
