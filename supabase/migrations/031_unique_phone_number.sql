-- =============================================================================
--  031_unique_phone_number.sql
--  Enforce globally unique phone numbers across all accounts (customers & shops)
--  via public.profiles.phone:
--  1) Normalizes phone numbers (Arabic/Persian digits, spaces, dashes,
--     +970/970/+972/972 -> canonical local digits) so duplicates cannot bypass
--     uniqueness by changing formatting.
--  2) Blocks duplicate phones BEFORE OTP email is sent via phone_number_exists().
--  3) Enforces uniqueness at the database level via BEFORE INSERT/UPDATE trigger
--     + unique partial index (when no historical duplicate phones exist).
-- =============================================================================
begin;

create or replace function public.normalize_phone(p_phone text)
returns text
language plpgsql
immutable
as $$
declare
  cleaned text;
begin
  if p_phone is null then
    return null;
  end if;

  -- Convert Eastern Arabic & Persian numerals to ASCII digits
  cleaned := translate(
    p_phone,
    '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
    '01234567890123456789'
  );

  -- Keep digits only
  cleaned := regexp_replace(cleaned, '[^0-9]', '', 'g');
  if cleaned = '' then
    return null;
  end if;

  -- Normalize international 00 prefix
  if cleaned like '00%' then
    cleaned := substr(cleaned, 3);
  end if;

  -- Normalize Palestine/regional +970 / +972 mobile prefixes to local 05xxxxxxxx
  if (cleaned like '970%' or cleaned like '972%') and length(cleaned) >= 12 then
    cleaned := substr(cleaned, 4);
    if left(cleaned, 1) <> '0' then
      cleaned := '0' || cleaned;
    end if;
  end if;

  return cleaned;
end;
$$;

-- Checks whether a normalized phone number already belongs to any account
-- (optionally excluding p_exclude_user_id when updating one's own profile).
create or replace function public.phone_number_exists(
  p_phone text,
  p_exclude_user_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  norm text := public.normalize_phone(p_phone);
begin
  if norm is null then
    return false;
  end if;

  return exists (
    select 1
    from public.profiles pr
    where public.normalize_phone(pr.phone) = norm
      and (p_exclude_user_id is null or pr.id <> p_exclude_user_id)
  );
end;
$$;

revoke all on function public.phone_number_exists(text, uuid) from public, anon;
grant execute on function public.phone_number_exists(text, uuid) to service_role, authenticated;

-- Database-level trigger preventing duplicate phones on public.profiles
create or replace function public.enforce_unique_profile_phone()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  norm text := public.normalize_phone(new.phone);
begin
  if norm is null then
    return new;
  end if;

  if public.phone_number_exists(norm, new.id) then
    raise exception 'رقم الهاتف مسجل مسبقاً لحساب آخر'
      using errcode = '23505';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_unique_profile_phone on public.profiles;
create trigger trg_enforce_unique_profile_phone
  before insert or update of phone on public.profiles
  for each row
  execute function public.enforce_unique_profile_phone();

-- Also create a unique index on profiles normalized phone when existing data has no duplicates
do $$
begin
  create unique index if not exists idx_profiles_unique_normalized_phone
    on public.profiles (public.normalize_phone(phone))
    where public.normalize_phone(phone) is not null;
exception
  when unique_violation then
    raise notice 'Skipped idx_profiles_unique_normalized_phone due to existing historical duplicate phones; trigger enforcement is active for all new inserts/updates.';
end;
$$;

notify pgrst, 'reload schema';
commit;
