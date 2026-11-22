-- =============================================================================
--  029_email_otp_verification_guard.sql
--  Anti-spam Email OTP protection:
--  1) Do NOT create public.profiles or public.shops rows for unverified signups
--     (email_confirmed_at is null) so fake/bot registrations cannot pollute the
--     database or admin lists.
--  2) Automatically provision profiles + draft shop the instant the user
--     confirms their email via OTP (email_confirmed_at transitions NULL -> NOT NULL).
--  3) Google OAuth users arrive already confirmed on INSERT and provision immediately.
-- =============================================================================
begin;

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
  -- Block provisioning until email is verified via OTP (prevents bot/spam pollution).
  if new.email_confirmed_at is null then
    return new;
  end if;

  selected_role := coalesce(
    (new.raw_user_meta_data->>'role')::public.user_role,
    'customer'
  );

  -- Never allow self-signup as admin.
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
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, public.profiles.email),
    full_name = coalesce(nullif(public.profiles.full_name, ''), excluded.full_name),
    phone = coalesce(nullif(public.profiles.phone, ''), excluded.phone),
    updated_at = now();

  if selected_role = 'shop' then
    shop_name := coalesce(
      nullif(new.raw_user_meta_data->>'shop_name', ''),
      'متجر جديد'
    );
    insert into public.shops (owner_id, name, status)
    values (new.id, shop_name, 'draft')
    on conflict (owner_id) do nothing;
  end if;

  return new;
end;
$$;

-- Provision immediately on INSERT if already confirmed (e.g. Google OAuth).
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Provision automatically the moment an Email OTP signup is verified.
drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.handle_new_user();

notify pgrst, 'reload schema';
commit;
