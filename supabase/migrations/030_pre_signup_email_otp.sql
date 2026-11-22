-- =============================================================================
--  030_pre_signup_email_otp.sql
--  True Pre-Registration Email OTP Verification:
--  - NO user row is created in auth.users, public.profiles, or public.shops
--    until the 6-digit email OTP is entered and verified!
--  - Stores only salted SHA-256 hashes of short-lived OTP codes (never passwords).
--  - Completely locked down from anon/authenticated clients (service_role only).
-- =============================================================================
begin;

create table if not exists public.pending_email_otps (
  email text primary key,
  code_hash text not null,
  salt text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  resend_count integer not null default 1,
  window_started_at timestamptz not null default now(),
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_pending_email_otps_expires_at
  on public.pending_email_otps (expires_at);

alter table public.pending_email_otps enable row level security;

revoke all on table public.pending_email_otps from public, anon, authenticated;
grant all on table public.pending_email_otps to service_role;

-- Fast O(1) check used exclusively by the signup-otp Edge Function (service_role)
-- to block duplicate emails BEFORE sending an OTP or creating any record.
create or replace function public.auth_email_exists(p_email text)
returns boolean
language sql
security definer
set search_path = auth, public
as $$
  select exists(
    select 1
    from auth.users
    where lower(email) = lower(trim(p_email))
  );
$$;

revoke all on function public.auth_email_exists(text) from public, anon, authenticated;
grant execute on function public.auth_email_exists(text) to service_role;

notify pgrst, 'reload schema';
commit;
