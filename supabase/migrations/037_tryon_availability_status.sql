-- =============================================================================
--  037_tryon_availability_status.sql
--  Extend get_my_tryon_quota() so customers' Product Details UI knows whether
--  Virtual Try-On is unavailable due to:
--    1. Admin disabling the feature (tryon_settings.enabled = false)
--    2. App Decart API tokens/credits being depleted or unconfigured
--    3. The user exhausting their daily try-on attempts
--  Never exposes API keys, hints, key counts, or credit balances to clients.
-- =============================================================================
begin;

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
  end if;

  select coalesce(attempts_used, 0) into used
  from public.tryon_daily_usage
  where user_id = uid and usage_date = today;

  used := coalesce(used, 0);
  v_remaining := greatest(v_limit - used, 0);

  -- Check Decart API key pool availability without leaking any key details.
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

  if not v_enabled then
    v_block_reason := 'disabled';
  elsif not v_tokens_available then
    v_block_reason := 'tokens_depleted';
  elsif v_remaining <= 0 then
    v_block_reason := 'daily_limit_reached';
  end if;

  return jsonb_build_object(
    'enabled', v_enabled,
    'tokens_available', v_tokens_available,
    'block_reason', v_block_reason,
    'session_duration_seconds', v_duration,
    'daily_limit', v_limit,
    'used_today', used,
    'remaining_today', v_remaining
  );
end;
$$;

revoke all on function public.get_my_tryon_quota() from public, anon, authenticated;
grant execute on function public.get_my_tryon_quota() to authenticated;

notify pgrst, 'reload schema';
commit;
