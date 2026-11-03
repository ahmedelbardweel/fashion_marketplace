-- Profile completion + shop join requests
-- Run after 001_auth_profiles.sql

alter table public.profiles
  add column if not exists city text,
  add column if not exists address text,
  add column if not exists profile_completed boolean not null default false;

alter table public.shops
  add column if not exists description text,
  add column if not exists city text,
  add column if not exists address text,
  add column if not exists commercial_register text,
  add column if not exists submitted_at timestamptz;

-- Shops must not self-update status via RLS. All status changes go through RPCs.
drop policy if exists "shops_update_own" on public.shops;

-- Users must not self-update role / activation. Profile edits go through RPCs.
drop policy if exists "profiles_update_own" on public.profiles;

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
as $$
begin
  if public.current_user_role() is distinct from 'admin' then
    new.role := old.role;
    new.is_active := old.is_active;
    new.id := old.id;
    new.email := old.email;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_fields on public.profiles;
create trigger profiles_protect_fields
  before update on public.profiles
  for each row execute function public.protect_profile_fields();

-- Customer completes own profile (no admin review)
create or replace function public.complete_customer_profile(
  p_full_name text,
  p_phone text,
  p_city text,
  p_address text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.profiles;
begin
  if auth.uid() is null then
    raise exception 'غير مصرح';
  end if;

  if coalesce(trim(p_full_name), '') = ''
     or coalesce(trim(p_phone), '') = ''
     or coalesce(trim(p_city), '') = ''
     or coalesce(trim(p_address), '') = '' then
    raise exception 'جميع الحقول مطلوبة';
  end if;

  update public.profiles
  set
    full_name = trim(p_full_name),
    phone = trim(p_phone),
    city = trim(p_city),
    address = trim(p_address),
    profile_completed = true,
    updated_at = now()
  where id = auth.uid()
    and role = 'customer'
  returning * into result;

  if result.id is null then
    raise exception 'الملف غير موجود أو ليس حساب مستخدم';
  end if;

  return result;
end;
$$;

-- Shop owner completes shop profile (stays draft / rejected until submit)
create or replace function public.complete_shop_profile(
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
  current_status public.shop_status;
begin
  if auth.uid() is null then
    raise exception 'غير مصرح';
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
    profile_completed = true,
    updated_at = now()
  where id = auth.uid()
    and role = 'shop';

  if not found then
    raise exception 'الملف غير موجود أو ليس حساب محل';
  end if;

  select status into current_status
  from public.shops
  where owner_id = auth.uid();

  if current_status is null then
    insert into public.shops (
      owner_id, name, description, city, address, commercial_register, status
    )
    values (
      auth.uid(),
      trim(p_shop_name),
      trim(p_description),
      trim(p_city),
      trim(p_address),
      trim(p_commercial_register),
      'draft'
    )
    returning * into result;
    return result;
  end if;

  if current_status not in ('draft', 'rejected') then
    raise exception 'لا يمكن تعديل بيانات المحل في الحالة الحالية';
  end if;

  update public.shops
  set
    name = trim(p_shop_name),
    description = trim(p_description),
    city = trim(p_city),
    address = trim(p_address),
    commercial_register = trim(p_commercial_register),
    updated_at = now()
  where owner_id = auth.uid()
  returning * into result;

  return result;
end;
$$;

-- Shop submits join request to admin
create or replace function public.submit_shop_application()
returns public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.shops;
begin
  if auth.uid() is null then
    raise exception 'غير مصرح';
  end if;

  update public.shops
  set
    status = 'pending',
    rejection_reason = null,
    decision_at = null,
    decision_visible_at = null,
    submitted_at = now(),
    updated_at = now()
  where owner_id = auth.uid()
    and status in ('draft', 'rejected')
    and coalesce(trim(name), '') <> ''
    and coalesce(trim(description), '') <> ''
    and coalesce(trim(city), '') <> ''
    and coalesce(trim(address), '') <> ''
    and coalesce(trim(commercial_register), '') <> ''
  returning * into result;

  if result.id is null then
    raise exception 'أكمل بيانات المحل أولاً قبل إرسال الطلب';
  end if;

  update public.profiles
  set profile_completed = true, updated_at = now()
  where id = auth.uid();

  return result;
end;
$$;

-- Admin approves or rejects. Shop sees the decision after 24 hours.
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
  admin_role public.user_role;
begin
  if auth.uid() is null then
    raise exception 'غير مصرح';
  end if;

  select role into admin_role from public.profiles where id = auth.uid();
  if admin_role is distinct from 'admin' then
    raise exception 'للإدارة فقط';
  end if;

  if not p_approve and coalesce(trim(p_rejection_reason), '') = '' then
    raise exception 'سبب الرفض مطلوب';
  end if;

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
    decision_visible_at = now() + interval '24 hours',
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

grant execute on function public.complete_customer_profile(text, text, text, text) to authenticated;
grant execute on function public.complete_shop_profile(text, text, text, text, text, text, text) to authenticated;
grant execute on function public.submit_shop_application() to authenticated;
grant execute on function public.review_shop_application(uuid, boolean, text) to authenticated;
