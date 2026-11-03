-- Roles
create type public.user_role as enum ('admin', 'shop', 'customer');

-- Profiles (1:1 with auth.users)
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role public.user_role not null default 'customer',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);

-- Shop status for join requests (phase 1 scaffold)
create type public.shop_status as enum (
  'draft',
  'pending',
  'approved',
  'rejected',
  'suspended'
);

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles (id) on delete cascade,
  name text not null,
  status public.shop_status not null default 'draft',
  rejection_reason text,
  decision_at timestamptz,
  decision_visible_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index shops_status_idx on public.shops (status);

-- Auto-create profile from signup metadata
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_role public.user_role;
  shop_name text;
begin
  selected_role := coalesce(
    (new.raw_user_meta_data->>'role')::public.user_role,
    'customer'
  );

  -- Never allow self-signup as admin
  if selected_role = 'admin' then
    selected_role := 'customer';
  end if;

  insert into public.profiles (id, email, full_name, phone, role)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'phone', ''),
    selected_role
  );

  if selected_role = 'shop' then
    shop_name := coalesce(
      nullif(new.raw_user_meta_data->>'shop_name', ''),
      'متجر جديد'
    );
    insert into public.shops (owner_id, name, status)
    values (new.id, shop_name, 'draft');
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- updated_at helper
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger shops_set_updated_at
  before update on public.shops
  for each row execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;
alter table public.shops enable row level security;

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (
    id = auth.uid()
    or public.current_user_role() = 'admin'
  );

create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "profiles_admin_update"
  on public.profiles for update
  using (public.current_user_role() = 'admin');

create policy "shops_select_own_or_admin"
  on public.shops for select
  using (
    owner_id = auth.uid()
    or public.current_user_role() = 'admin'
  );

create policy "shops_update_own"
  on public.shops for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "shops_admin_all"
  on public.shops for all
  using (public.current_user_role() = 'admin');
