-- =============================================================================
--  027_decart_api_key_pool.sql
--  Multi-key Decart API Pool with Vault encryption, live balance telemetry,
--  and automatic failover ordering for zero-downtime Virtual Try-On.
-- =============================================================================
begin;

create extension if not exists supabase_vault with schema vault;

create table if not exists public.decart_api_keys (
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

create index if not exists idx_decart_api_keys_active_priority
  on public.decart_api_keys (is_active, priority asc, created_at asc);

alter table public.decart_api_keys enable row level security;

-- Lock down direct table access; all reads/writes go through SECURITY DEFINER RPCs.
revoke all on table public.decart_api_keys from public, anon, authenticated;

-- Helper: validate Decart API key format (same strict rules as migration 012).
create or replace function public._is_valid_decart_api_key(p_clean_key text)
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
  if p_clean_key !~ '^dct_[A-Za-z0-9][A-Za-z0-9-]{0,63}_[A-Za-z0-9_-]+$' then
    return false;
  end if;
  secret_part := substring(p_clean_key from '^dct_[A-Za-z0-9][A-Za-z0-9-]{0,63}_(.+)$');
  return secret_part is not null
    and char_length(secret_part) between 20 and 512;
end;
$$;

-- Helper: safe masked hint for UI display (never reveals the secret).
create or replace function public._mask_decart_api_key(p_clean_key text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  prefix text;
  suffix text;
begin
  prefix := substring(p_clean_key from '^(dct_[A-Za-z0-9-]+_)');
  suffix := right(p_clean_key, 4);
  if prefix is null then
    return 'dct_…' || coalesce(suffix, '****');
  end if;
  return prefix || '…' || coalesce(suffix, '****');
end;
$$;

-- Seamlessly migrate any existing single Vault secret into the pool as Key #1.
do $$
declare
  legacy_secret text;
begin
  select decrypted_secret into legacy_secret
  from vault.decrypted_secrets
  where name = 'fashion_marketplace_decart_api_key'
  limit 1;

  if legacy_secret is not null and not exists (
    select 1 from public.decart_api_keys
    where vault_secret_name = 'fashion_marketplace_decart_api_key'
  ) then
    insert into public.decart_api_keys (
      label,
      vault_secret_name,
      key_hint,
      priority,
      is_active
    ) values (
      'المفتاح الأساسي',
      'fashion_marketplace_decart_api_key',
      public._mask_decart_api_key(btrim(legacy_secret)),
      1,
      true
    );
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
--  Admin RPC: List all keys metadata (never exposes secrets)
-- -----------------------------------------------------------------------------
create or replace function public.admin_list_decart_keys()
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
      from public.decart_api_keys k
    ),
    '[]'::jsonb
  );
end;
$$;

-- -----------------------------------------------------------------------------
--  Admin RPC: Add a new Decart API key to the encrypted pool
-- -----------------------------------------------------------------------------
create or replace function public.admin_add_decart_api_key(
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
  secret_name text := 'fashion_marketplace_decart_key_' || replace(new_id::text, '-', '');
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

  if not public._is_valid_decart_api_key(clean_key) then
    raise exception 'Invalid Decart API key format' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(904283219);

  select count(*), coalesce(max(priority), 0) + 1
  into key_count, next_priority
  from public.decart_api_keys;

  if p_priority is not null and p_priority > 0 then
    next_priority := p_priority;
  end if;

  final_label := nullif(btrim(coalesce(p_label, '')), '');
  if final_label is null then
    final_label := 'مفتاح Decart #' || (key_count + 1);
  end if;

  perform vault.create_secret(
    clean_key,
    secret_name,
    'Decart virtual try-on pooled credential: ' || final_label
  );

  insert into public.decart_api_keys (
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
    public._mask_decart_api_key(clean_key),
    next_priority,
    true,
    'unknown'
  );

  return jsonb_build_object(
    'id', new_id,
    'label', final_label,
    'key_hint', public._mask_decart_api_key(clean_key),
    'priority', next_priority,
    'is_active', true,
    'last_status', 'unknown'
  );
end;
$$;

-- -----------------------------------------------------------------------------
--  Admin RPC: Toggle key active/inactive
-- -----------------------------------------------------------------------------
create or replace function public.admin_toggle_decart_api_key(
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

  update public.decart_api_keys
  set is_active = coalesce(p_is_active, true),
      updated_at = now()
  where id = p_id;
end;
$$;

-- -----------------------------------------------------------------------------
--  Admin RPC: Delete a Decart API key (both Vault secret and metadata row)
-- -----------------------------------------------------------------------------
create or replace function public.admin_delete_decart_api_key(p_id uuid)
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

  perform pg_catalog.pg_advisory_xact_lock(904283219);

  select vault_secret_name into v_secret_name
  from public.decart_api_keys
  where id = p_id;

  if v_secret_name is not null then
    delete from public.decart_api_keys where id = p_id;
    delete from vault.secrets where name = v_secret_name;
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
--  Backward-compatible admin_decart_status() & admin_set_decart_api_key()
-- -----------------------------------------------------------------------------
create or replace function public.admin_decart_status()
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
  from public.decart_api_keys;

  if total_cnt = 0 then
    select updated_at into changed_at
    from vault.secrets
    where name = 'fashion_marketplace_decart_api_key';
    return jsonb_build_object(
      'configured', found,
      'updated_at', changed_at,
      'total_keys', case when found then 1 else 0 end,
      'active_keys', case when found then 1 else 0 end
    );
  end if;

  return jsonb_build_object(
    'configured', active_cnt > 0,
    'updated_at', changed_at,
    'total_keys', total_cnt,
    'active_keys', active_cnt
  );
end;
$$;

create or replace function public.admin_set_decart_api_key(p_api_key text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.admin_add_decart_api_key(p_api_key, null, null);
end;
$$;

-- -----------------------------------------------------------------------------
--  Service-role RPCs for decart-session Edge Function
-- -----------------------------------------------------------------------------
create or replace function public.service_decart_api_keys()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
  legacy_secret text;
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
  from public.decart_api_keys k
  join vault.decrypted_secrets s on s.name = k.vault_secret_name;

  if jsonb_array_length(result) = 0 then
    select decrypted_secret into legacy_secret
    from vault.decrypted_secrets
    where name = 'fashion_marketplace_decart_api_key'
    limit 1;

    if legacy_secret is not null then
      result := jsonb_build_array(
        jsonb_build_object(
          'id', null,
          'label', 'المفتاح الأساسي',
          'key_hint', public._mask_decart_api_key(btrim(legacy_secret)),
          'priority', 1,
          'is_active', true,
          'last_credits', null,
          'last_status', 'unknown',
          'api_key', btrim(legacy_secret)
        )
      );
    end if;
  end if;

  return result;
end;
$$;

create or replace function public.service_update_decart_key_telemetry(
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

  update public.decart_api_keys
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

revoke all on function public._is_valid_decart_api_key(text) from public, anon, authenticated;
revoke all on function public._mask_decart_api_key(text) from public, anon, authenticated;
revoke all on function public.admin_list_decart_keys() from public, anon, authenticated;
revoke all on function public.admin_add_decart_api_key(text, text, integer) from public, anon, authenticated;
revoke all on function public.admin_toggle_decart_api_key(uuid, boolean) from public, anon, authenticated;
revoke all on function public.admin_delete_decart_api_key(uuid) from public, anon, authenticated;
revoke all on function public.admin_decart_status() from public, anon, authenticated;
revoke all on function public.admin_set_decart_api_key(text) from public, anon, authenticated;
revoke all on function public.service_decart_api_keys() from public, anon, authenticated;
revoke all on function public.service_update_decart_key_telemetry(uuid, numeric, text, boolean) from public, anon, authenticated;

grant execute on function public.admin_list_decart_keys() to authenticated;
grant execute on function public.admin_add_decart_api_key(text, text, integer) to authenticated;
grant execute on function public.admin_toggle_decart_api_key(uuid, boolean) to authenticated;
grant execute on function public.admin_delete_decart_api_key(uuid) to authenticated;
grant execute on function public.admin_decart_status() to authenticated;
grant execute on function public.admin_set_decart_api_key(text) to authenticated;
grant execute on function public.service_decart_api_keys() to service_role;
grant execute on function public.service_update_decart_key_telemetry(uuid, numeric, text, boolean) to service_role;

notify pgrst, 'reload schema';
commit;
