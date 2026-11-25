-- =============================================================================
--  041_vidu_tryon_provider_and_key_pool.sql
--  Dual Virtual Try-On Provider Switcher (Decart AI live VTON / Vidu AI photo)
--  + Multi-key Vidu API Pool with Vault encryption, live credit telemetry,
--  automatic key failover, and secure per-user task tracking with safe refunds.
-- =============================================================================
begin;

create extension if not exists supabase_vault with schema vault;

-- -----------------------------------------------------------------------------
--  1) Active Try-On Provider setting in public.tryon_settings
-- -----------------------------------------------------------------------------
alter table public.tryon_settings
  add column if not exists active_provider text not null default 'decart';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tryon_settings_active_provider_check'
      and conrelid = 'public.tryon_settings'::regclass
  ) then
    alter table public.tryon_settings
      add constraint tryon_settings_active_provider_check
      check (active_provider in ('decart', 'vidu'));
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
--  2) Encrypted Multi-Key Pool for Vidu AI API (mirrors decart_api_keys)
-- -----------------------------------------------------------------------------
create table if not exists public.vidu_api_keys (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  vault_secret_name text not null unique,
  key_hint text not null,
  priority integer not null default 100,
  is_active boolean not null default true,
  last_credits numeric(12, 2),
  last_status text not null default 'unknown'
    check (last_status in ('active', 'low', 'depleted', 'invalid', 'unknown')),
  last_checked_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vidu_api_keys_active_priority
  on public.vidu_api_keys (is_active, priority asc, created_at asc);

alter table public.vidu_api_keys enable row level security;
revoke all on table public.vidu_api_keys from public, anon, authenticated;

-- -----------------------------------------------------------------------------
--  3) Per-user Vidu generation task ledger (binds task_id -> user_id + key_id,
--     prevents cross-user polling and guarantees single-use failure refunds)
-- -----------------------------------------------------------------------------
create table if not exists public.vidu_tryon_tasks (
  task_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  key_id uuid references public.vidu_api_keys(id) on delete set null,
  state text not null default 'created',
  refunded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vidu_tryon_tasks_user_created
  on public.vidu_tryon_tasks (user_id, created_at desc);

alter table public.vidu_tryon_tasks enable row level security;
revoke all on table public.vidu_tryon_tasks from public, anon, authenticated;

-- -----------------------------------------------------------------------------
--  4) Key format validation & safe masking helpers for Vidu API keys
--     Official Vidu keys: vda_<account_or_id>_<secret>
-- -----------------------------------------------------------------------------
create or replace function public._is_valid_vidu_api_key(p_clean_key text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  secret_part text;
begin
  if p_clean_key is null then
    return false;
  end if;
  if p_clean_key !~ '^vda_[A-Za-z0-9][A-Za-z0-9_-]{2,63}_[A-Za-z0-9_-]+$' then
    return false;
  end if;
  secret_part := substring(p_clean_key from '^vda_[A-Za-z0-9][A-Za-z0-9_-]{2,63}_(.+)$');
  return secret_part is not null
    and char_length(secret_part) between 16 and 512;
end;
$$;

create or replace function public._mask_vidu_api_key(p_clean_key text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  prefix text;
  suffix text;
begin
  prefix := left(p_clean_key, 10);
  suffix := right(p_clean_key, 4);
  if char_length(coalesce(p_clean_key, '')) < 14 then
    return 'vda_…' || coalesce(suffix, '****');
  end if;
  return prefix || '…' || coalesce(suffix, '****');
end;
$$;

-- -----------------------------------------------------------------------------
--  5) Admin RPCs for Vidu API Key Pool
-- -----------------------------------------------------------------------------
create or replace function public.admin_list_vidu_keys()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', k.id,
          'label', k.label,
          'key_hint', k.key_hint,
          'priority', k.priority,
          'is_active', k.is_active,
          'last_credits', k.last_credits,
          'last_status', k.last_status,
          'last_checked_at', k.last_checked_at,
          'last_used_at', k.last_used_at,
          'created_at', k.created_at
        )
        order by k.priority asc, k.created_at asc
      )
      from public.vidu_api_keys k
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.admin_add_vidu_api_key(
  p_api_key text,
  p_label text default null,
  p_priority integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_key text := btrim(p_api_key);
  new_id uuid := gen_random_uuid();
  secret_name text := 'fashion_marketplace_vidu_key_' || replace(new_id::text, '-', '');
  next_priority integer;
  final_label text;
  key_count integer;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if not public._is_valid_vidu_api_key(clean_key) then
    raise exception 'Invalid Vidu API key format' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(904283220);

  select count(*), coalesce(max(priority), 0) + 1
  into key_count, next_priority
  from public.vidu_api_keys;

  if p_priority is not null and p_priority > 0 then
    next_priority := p_priority;
  end if;

  final_label := nullif(btrim(coalesce(p_label, '')), '');
  if final_label is null then
    final_label := 'مفتاح Vidu #' || (key_count + 1);
  end if;

  perform vault.create_secret(
    clean_key,
    secret_name,
    'Vidu virtual try-on pooled credential: ' || final_label
  );

  insert into public.vidu_api_keys (
    id,
    label,
    vault_secret_name,
    key_hint,
    priority,
    is_active,
    last_status
  ) values (
    new_id,
    final_label,
    secret_name,
    public._mask_vidu_api_key(clean_key),
    next_priority,
    true,
    'unknown'
  );

  return jsonb_build_object(
    'id', new_id,
    'label', final_label,
    'key_hint', public._mask_vidu_api_key(clean_key),
    'priority', next_priority,
    'is_active', true,
    'last_status', 'unknown'
  );
end;
$$;

create or replace function public.admin_toggle_vidu_api_key(
  p_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  update public.vidu_api_keys
  set is_active = coalesce(p_is_active, true),
      updated_at = now()
  where id = p_id;
end;
$$;

create or replace function public.admin_delete_vidu_api_key(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret_name text;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(904283220);

  select vault_secret_name into v_secret_name
  from public.vidu_api_keys
  where id = p_id;

  if v_secret_name is not null then
    delete from public.vidu_api_keys where id = p_id;
    delete from vault.secrets where name = v_secret_name;
  end if;
end;
$$;

create or replace function public.admin_vidu_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_cnt integer;
  total_cnt integer;
  changed_at timestamptz;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  select
    count(*) filter (where is_active),
    count(*),
    max(updated_at)
  into active_cnt, total_cnt, changed_at
  from public.vidu_api_keys;

  return jsonb_build_object(
    'configured', active_cnt > 0,
    'updated_at', changed_at,
    'total_keys', total_cnt,
    'active_keys', active_cnt
  );
end;
$$;

-- -----------------------------------------------------------------------------
--  6) Admin Provider Switcher & Updated Try-On Controls RPCs
-- -----------------------------------------------------------------------------
create or replace function public.admin_set_tryon_provider(p_provider text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  clean_provider text := lower(btrim(coalesce(p_provider, '')));
  row_data public.tryon_settings%rowtype;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if clean_provider not in ('decart', 'vidu') then
    raise exception 'Invalid try-on provider. Must be decart or vidu.'
      using errcode = '22023';
  end if;

  insert into public.tryon_settings (
    id, enabled, session_duration_seconds, daily_attempts_limit, active_provider, updated_at, updated_by
  )
  values (true, true, 30, 3, clean_provider, now(), auth.uid())
  on conflict (id) do update
    set active_provider = excluded.active_provider,
        updated_at = now(),
        updated_by = auth.uid()
  returning * into row_data;

  return jsonb_build_object(
    'enabled', row_data.enabled,
    'session_duration_seconds', row_data.session_duration_seconds,
    'daily_attempts_limit', row_data.daily_attempts_limit,
    'active_provider', row_data.active_provider,
    'updated_at', row_data.updated_at
  );
end;
$$;

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
      'active_provider', 'decart',
      'updated_at', null
    );
  end if;

  return jsonb_build_object(
    'enabled', row_data.enabled,
    'session_duration_seconds', row_data.session_duration_seconds,
    'daily_attempts_limit', row_data.daily_attempts_limit,
    'active_provider', coalesce(row_data.active_provider, 'decart'),
    'updated_at', row_data.updated_at
  );
end;
$$;

drop function if exists public.admin_update_tryon_controls(boolean, integer, integer);

create or replace function public.admin_update_tryon_controls(
  p_enabled boolean,
  p_session_duration_seconds integer,
  p_daily_attempts_limit integer,
  p_active_provider text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data public.tryon_settings%rowtype;
  resolved_provider text;
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

  if p_active_provider is not null and btrim(p_active_provider) <> '' then
    resolved_provider := lower(btrim(p_active_provider));
    if resolved_provider not in ('decart', 'vidu') then
      raise exception 'Invalid try-on provider' using errcode = '22023';
    end if;
  else
    select coalesce(active_provider, 'decart') into resolved_provider
    from public.tryon_settings
    where id = true;
    resolved_provider := coalesce(resolved_provider, 'decart');
  end if;

  insert into public.tryon_settings (
    id, enabled, session_duration_seconds, daily_attempts_limit, active_provider, updated_at, updated_by
  )
  values (
    true,
    coalesce(p_enabled, true),
    p_session_duration_seconds,
    p_daily_attempts_limit,
    resolved_provider,
    now(),
    auth.uid()
  )
  on conflict (id) do update
    set enabled = excluded.enabled,
        session_duration_seconds = excluded.session_duration_seconds,
        daily_attempts_limit = excluded.daily_attempts_limit,
        active_provider = excluded.active_provider,
        updated_at = now(),
        updated_by = auth.uid()
  returning * into row_data;

  return jsonb_build_object(
    'enabled', row_data.enabled,
    'session_duration_seconds', row_data.session_duration_seconds,
    'daily_attempts_limit', row_data.daily_attempts_limit,
    'active_provider', row_data.active_provider,
    'updated_at', row_data.updated_at
  );
end;
$$;

-- -----------------------------------------------------------------------------
--  7) Update get_my_tryon_quota() to check ONLY the active provider's key pool
--     (manual switching by admin; no silent cross-provider fallback)
-- -----------------------------------------------------------------------------
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
  v_remaining integer := 3;
  v_provider text := 'decart';
  v_total_keys integer := 0;
  v_usable_keys integer := 0;
  v_has_legacy_key boolean := false;
  v_tokens_available boolean := true;
  v_block_reason text := null;
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into cfg from public.tryon_settings where id = true;
  if found then
    v_enabled := cfg.enabled;
    v_duration := cfg.session_duration_seconds;
    v_limit := cfg.daily_attempts_limit;
    v_provider := coalesce(cfg.active_provider, 'decart');
  end if;

  select coalesce(attempts_used, 0) into used
  from public.tryon_daily_usage
  where user_id = uid and usage_date = today;

  used := coalesce(used, 0);
  v_remaining := greatest(v_limit - used, 0);

  if v_provider = 'vidu' then
    select
      count(*),
      count(*) filter (
        where is_active
          and last_status not in ('depleted', 'invalid')
          and (last_credits is null or last_credits > 0)
      )
    into v_total_keys, v_usable_keys
    from public.vidu_api_keys;

    v_tokens_available := v_total_keys > 0 and v_usable_keys > 0;
  else
    if to_regclass('public.decart_api_keys') is not null then
      select
        count(*),
        count(*) filter (
          where is_active
            and last_status not in ('depleted', 'invalid')
            and (last_credits is null or last_credits > 0)
        )
      into v_total_keys, v_usable_keys
      from public.decart_api_keys;

      if v_total_keys > 0 then
        v_tokens_available := v_usable_keys > 0;
      else
        select exists (
          select 1
          from vault.secrets
          where name = 'fashion_marketplace_decart_api_key'
        ) into v_has_legacy_key;
        v_tokens_available := coalesce(v_has_legacy_key, false);
      end if;
    else
      select exists (
        select 1
        from vault.secrets
        where name = 'fashion_marketplace_decart_api_key'
      ) into v_has_legacy_key;
      v_tokens_available := coalesce(v_has_legacy_key, false);
    end if;
  end if;

  if not v_enabled then
    v_block_reason := 'disabled';
  elsif not v_tokens_available then
    v_block_reason := 'tokens_depleted';
  elsif v_remaining <= 0 then
    v_block_reason := 'daily_limit_reached';
  end if;

  return jsonb_build_object(
    'enabled', v_enabled,
    'active_provider', v_provider,
    'tokens_available', v_tokens_available,
    'block_reason', v_block_reason,
    'session_duration_seconds', v_duration,
    'daily_limit', v_limit,
    'used_today', used,
    'remaining_today', v_remaining
  );
end;
$$;

-- -----------------------------------------------------------------------------
--  8) Service-role RPCs for Edge Functions (vidu-tryon & decart-session)
-- -----------------------------------------------------------------------------
create or replace function public.service_get_tryon_provider()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider text;
begin
  select coalesce(active_provider, 'decart') into v_provider
  from public.tryon_settings
  where id = true;
  return coalesce(v_provider, 'decart');
end;
$$;

create or replace function public.service_vidu_api_keys()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', k.id,
        'label', k.label,
        'key_hint', k.key_hint,
        'priority', k.priority,
        'is_active', k.is_active,
        'last_credits', k.last_credits,
        'last_status', k.last_status,
        'last_checked_at', k.last_checked_at,
        'last_used_at', k.last_used_at,
        'api_key', s.decrypted_secret
      )
      order by
        case
          when not k.is_active then 3
          when k.last_status = 'invalid' then 2
          when k.last_status = 'depleted' then 1
          else 0
        end asc,
        k.priority asc,
        k.created_at asc
    ),
    '[]'::jsonb
  )
  into result
  from public.vidu_api_keys k
  join vault.decrypted_secrets s on s.name = k.vault_secret_name;

  return result;
end;
$$;

create or replace function public.service_update_vidu_key_telemetry(
  p_id uuid,
  p_credits numeric default null,
  p_status text default null,
  p_mark_used boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_id is null then
    return;
  end if;

  update public.vidu_api_keys
  set
    last_credits = coalesce(p_credits, last_credits),
    last_status = case
      when p_status in ('active', 'low', 'depleted', 'invalid', 'unknown') then p_status
      else last_status
    end,
    last_checked_at = case
      when p_credits is not null or p_status is not null then now()
      else last_checked_at
    end,
    last_used_at = case when p_mark_used then now() else last_used_at end,
    updated_at = now()
  where id = p_id;
end;
$$;

create or replace function public.service_record_vidu_task(
  p_task_id text,
  p_user_id uuid,
  p_key_id uuid default null,
  p_state text default 'created'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_task_id is null or btrim(p_task_id) = '' or p_user_id is null then
    return;
  end if;

  insert into public.vidu_tryon_tasks (task_id, user_id, key_id, state, updated_at)
  values (btrim(p_task_id), p_user_id, p_key_id, coalesce(p_state, 'created'), now())
  on conflict (task_id) do update
    set state = excluded.state,
        updated_at = now();
end;
$$;

create or replace function public.service_get_vidu_task(
  p_task_id text,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data public.vidu_tryon_tasks%rowtype;
begin
  select * into row_data
  from public.vidu_tryon_tasks
  where task_id = btrim(coalesce(p_task_id, ''))
    and user_id = p_user_id;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'task_id', row_data.task_id,
    'user_id', row_data.user_id,
    'key_id', row_data.key_id,
    'state', row_data.state,
    'refunded', row_data.refunded
  );
end;
$$;

create or replace function public.service_mark_vidu_task_state(
  p_task_id text,
  p_user_id uuid,
  p_state text,
  p_refund_if_failed boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_refunded boolean := false;
begin
  if p_task_id is null or p_user_id is null then
    return false;
  end if;

  if p_refund_if_failed then
    update public.vidu_tryon_tasks
    set state = coalesce(p_state, state),
        refunded = true,
        updated_at = now()
    where task_id = btrim(p_task_id)
      and user_id = p_user_id
      and not refunded;

    if found then
      perform public.service_refund_tryon_attempt(p_user_id);
      v_refunded := true;
    else
      update public.vidu_tryon_tasks
      set state = coalesce(p_state, state),
          updated_at = now()
      where task_id = btrim(p_task_id)
        and user_id = p_user_id;
    end if;
  else
    update public.vidu_tryon_tasks
    set state = coalesce(p_state, state),
        updated_at = now()
    where task_id = btrim(p_task_id)
      and user_id = p_user_id;
  end if;

  return v_refunded;
end;
$$;

-- -----------------------------------------------------------------------------
--  9) Strict Least-Privilege Grants
-- -----------------------------------------------------------------------------
revoke all on function public._is_valid_vidu_api_key(text) from public, anon, authenticated;
revoke all on function public._mask_vidu_api_key(text) from public, anon, authenticated;
revoke all on function public.admin_list_vidu_keys() from public, anon, authenticated;
revoke all on function public.admin_add_vidu_api_key(text, text, integer) from public, anon, authenticated;
revoke all on function public.admin_toggle_vidu_api_key(uuid, boolean) from public, anon, authenticated;
revoke all on function public.admin_delete_vidu_api_key(uuid) from public, anon, authenticated;
revoke all on function public.admin_vidu_status() from public, anon, authenticated;
revoke all on function public.admin_set_tryon_provider(text) from public, anon, authenticated;
revoke all on function public.admin_get_tryon_controls() from public, anon, authenticated;
revoke all on function public.admin_update_tryon_controls(boolean, integer, integer, text) from public, anon, authenticated;
revoke all on function public.get_my_tryon_quota() from public, anon, authenticated;
revoke all on function public.service_get_tryon_provider() from public, anon, authenticated;
revoke all on function public.service_vidu_api_keys() from public, anon, authenticated;
revoke all on function public.service_update_vidu_key_telemetry(uuid, numeric, text, boolean) from public, anon, authenticated;
revoke all on function public.service_record_vidu_task(text, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.service_get_vidu_task(text, uuid) from public, anon, authenticated;
revoke all on function public.service_mark_vidu_task_state(text, uuid, text, boolean) from public, anon, authenticated;

grant execute on function public.admin_list_vidu_keys() to authenticated;
grant execute on function public.admin_add_vidu_api_key(text, text, integer) to authenticated;
grant execute on function public.admin_toggle_vidu_api_key(uuid, boolean) to authenticated;
grant execute on function public.admin_delete_vidu_api_key(uuid) to authenticated;
grant execute on function public.admin_vidu_status() to authenticated;
grant execute on function public.admin_set_tryon_provider(text) to authenticated;
grant execute on function public.admin_get_tryon_controls() to authenticated;
grant execute on function public.admin_update_tryon_controls(boolean, integer, integer, text) to authenticated;
grant execute on function public.get_my_tryon_quota() to authenticated;

grant execute on function public.service_get_tryon_provider() to service_role;
grant execute on function public.service_vidu_api_keys() to service_role;
grant execute on function public.service_update_vidu_key_telemetry(uuid, numeric, text, boolean) to service_role;
grant execute on function public.service_record_vidu_task(text, uuid, uuid, text) to service_role;
grant execute on function public.service_get_vidu_task(text, uuid) to service_role;
grant execute on function public.service_mark_vidu_task_state(text, uuid, text, boolean) to service_role;

notify pgrst, 'reload schema';
commit;
