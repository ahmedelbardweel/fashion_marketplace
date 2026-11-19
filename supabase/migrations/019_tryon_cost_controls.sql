-- Virtual Try-On cost controls: admin-configurable session duration (default 30s),
-- per-user daily attempt cap (default 3/day), and global enable/disable toggle.
begin;

create table if not exists public.tryon_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default true,
  session_duration_seconds integer not null default 30
    check (session_duration_seconds between 10 and 300),
  daily_attempts_limit integer not null default 3
    check (daily_attempts_limit between 1 and 100),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

insert into public.tryon_settings (id, enabled, session_duration_seconds, daily_attempts_limit)
values (true, true, 30, 3)
on conflict (id) do nothing;

alter table public.tryon_settings enable row level security;
revoke all on table public.tryon_settings from public, anon, authenticated;

create table if not exists public.tryon_daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default (now() at time zone 'utc')::date,
  attempts_used integer not null default 0 check (attempts_used >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

create index if not exists idx_tryon_daily_usage_date
  on public.tryon_daily_usage (usage_date);

alter table public.tryon_daily_usage enable row level security;
revoke all on table public.tryon_daily_usage from public, anon, authenticated;

-- Admin: read current try-on cost controls
create or replace function public.admin_get_tryon_controls()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data public.tryon_settings%rowtype;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  select * into row_data from public.tryon_settings where id = true;
  if not found then
    return jsonb_build_object(
      'enabled', true,
      'session_duration_seconds', 30,
      'daily_attempts_limit', 3,
      'updated_at', null
    );
  end if;

  return jsonb_build_object(
    'enabled', row_data.enabled,
    'session_duration_seconds', row_data.session_duration_seconds,
    'daily_attempts_limit', row_data.daily_attempts_limit,
    'updated_at', row_data.updated_at
  );
end;
$$;

-- Admin: update try-on cost controls
create or replace function public.admin_update_tryon_controls(
  p_enabled boolean,
  p_session_duration_seconds integer,
  p_daily_attempts_limit integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data public.tryon_settings%rowtype;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if p_session_duration_seconds is null
    or p_session_duration_seconds not between 10 and 300
  then
    raise exception 'Session duration must be between 10 and 300 seconds'
      using errcode = '22023';
  end if;

  if p_daily_attempts_limit is null
    or p_daily_attempts_limit not between 1 and 100
  then
    raise exception 'Daily attempts limit must be between 1 and 100'
      using errcode = '22023';
  end if;

  insert into public.tryon_settings (
    id, enabled, session_duration_seconds, daily_attempts_limit, updated_at, updated_by
  )
  values (
    true, coalesce(p_enabled, true), p_session_duration_seconds, p_daily_attempts_limit, now(), auth.uid()
  )
  on conflict (id) do update
    set enabled = excluded.enabled,
        session_duration_seconds = excluded.session_duration_seconds,
        daily_attempts_limit = excluded.daily_attempts_limit,
        updated_at = now(),
        updated_by = auth.uid()
  returning * into row_data;

  return jsonb_build_object(
    'enabled', row_data.enabled,
    'session_duration_seconds', row_data.session_duration_seconds,
    'daily_attempts_limit', row_data.daily_attempts_limit,
    'updated_at', row_data.updated_at
  );
end;
$$;

-- Authenticated user: read own daily quota without consuming an attempt
create or replace function public.get_my_tryon_quota()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'utc')::date;
  cfg public.tryon_settings%rowtype;
  used integer := 0;
  v_enabled boolean := true;
  v_duration integer := 30;
  v_limit integer := 3;
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into cfg from public.tryon_settings where id = true;
  if found then
    v_enabled := cfg.enabled;
    v_duration := cfg.session_duration_seconds;
    v_limit := cfg.daily_attempts_limit;
  end if;

  select coalesce(attempts_used, 0) into used
  from public.tryon_daily_usage
  where user_id = uid and usage_date = today;

  used := coalesce(used, 0);

  return jsonb_build_object(
    'enabled', v_enabled,
    'session_duration_seconds', v_duration,
    'daily_limit', v_limit,
    'used_today', used,
    'remaining_today', greatest(v_limit - used, 0)
  );
end;
$$;

-- Edge Function (service_role only): atomically enforce quota and consume 1 attempt
create or replace function public.service_consume_tryon_attempt(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'utc')::date;
  cfg public.tryon_settings%rowtype;
  v_enabled boolean := true;
  v_duration integer := 30;
  v_limit integer := 3;
  v_used integer := 0;
begin
  if p_user_id is null then
    raise exception 'User id required' using errcode = '22023';
  end if;

  select * into cfg from public.tryon_settings where id = true;
  if found then
    v_enabled := cfg.enabled;
    v_duration := cfg.session_duration_seconds;
    v_limit := cfg.daily_attempts_limit;
  end if;

  if not v_enabled then
    select coalesce(attempts_used, 0) into v_used
    from public.tryon_daily_usage
    where user_id = p_user_id and usage_date = today;
    v_used := coalesce(v_used, 0);
    return jsonb_build_object(
      'allowed', false,
      'reason', 'disabled',
      'enabled', false,
      'session_duration_seconds', v_duration,
      'daily_limit', v_limit,
      'used_today', v_used,
      'remaining_today', greatest(v_limit - v_used, 0)
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(hashtext('tryon_quota:' || p_user_id::text));

  select coalesce(attempts_used, 0) into v_used
  from public.tryon_daily_usage
  where user_id = p_user_id and usage_date = today;
  v_used := coalesce(v_used, 0);

  if v_used >= v_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'daily_limit_reached',
      'enabled', true,
      'session_duration_seconds', v_duration,
      'daily_limit', v_limit,
      'used_today', v_used,
      'remaining_today', 0
    );
  end if;

  insert into public.tryon_daily_usage (user_id, usage_date, attempts_used, updated_at)
  values (p_user_id, today, 1, now())
  on conflict (user_id, usage_date) do update
    set attempts_used = public.tryon_daily_usage.attempts_used + 1,
        updated_at = now()
  returning attempts_used into v_used;

  return jsonb_build_object(
    'allowed', true,
    'reason', null,
    'enabled', true,
    'session_duration_seconds', v_duration,
    'daily_limit', v_limit,
    'used_today', v_used,
    'remaining_today', greatest(v_limit - v_used, 0)
  );
end;
$$;

-- Edge Function (service_role only): refund 1 attempt if upstream token minting fails
create or replace function public.service_refund_tryon_attempt(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'utc')::date;
begin
  if p_user_id is null then
    return;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(hashtext('tryon_quota:' || p_user_id::text));

  update public.tryon_daily_usage
  set attempts_used = greatest(attempts_used - 1, 0),
      updated_at = now()
  where user_id = p_user_id and usage_date = today;
end;
$$;

revoke all on function public.admin_get_tryon_controls() from public, anon, authenticated;
grant execute on function public.admin_get_tryon_controls() to authenticated;

revoke all on function public.admin_update_tryon_controls(boolean, integer, integer) from public, anon, authenticated;
grant execute on function public.admin_update_tryon_controls(boolean, integer, integer) to authenticated;

revoke all on function public.get_my_tryon_quota() from public, anon, authenticated;
grant execute on function public.get_my_tryon_quota() to authenticated;

revoke all on function public.service_consume_tryon_attempt(uuid) from public, anon, authenticated;
grant execute on function public.service_consume_tryon_attempt(uuid) to service_role;

revoke all on function public.service_refund_tryon_attempt(uuid) from public, anon, authenticated;
grant execute on function public.service_refund_tryon_attempt(uuid) to service_role;

notify pgrst, 'reload schema';
commit;
