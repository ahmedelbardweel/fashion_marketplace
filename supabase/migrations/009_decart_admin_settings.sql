-- Keep the permanent Decart credential outside public platform_settings.
begin;
create extension if not exists supabase_vault with schema vault;

create or replace function public.admin_decart_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed_at timestamptz;
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  select updated_at into changed_at from vault.secrets
    where name = 'fashion_marketplace_decart_api_key';
  return jsonb_build_object('configured', found, 'updated_at', changed_at);
end;
$$;

create or replace function public.admin_set_decart_api_key(p_api_key text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  secret_id uuid;
  clean_key text := btrim(p_api_key);
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  ) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if clean_key is null or clean_key !~ '^dct_app_[A-Za-z0-9]{20,512}$' then
    raise exception 'Invalid Decart API key format' using errcode = '22023';
  end if;
  -- Serialize initial creation and rotations; never return or log the key.
  perform pg_catalog.pg_advisory_xact_lock(904283219);
  select id into secret_id from vault.secrets
    where name = 'fashion_marketplace_decart_api_key';
  if secret_id is null then
    perform vault.create_secret(clean_key, 'fashion_marketplace_decart_api_key',
      'Decart virtual try-on server credential');
  else
    perform vault.update_secret(secret_id, clean_key);
  end if;
end;
$$;

-- Only the Edge Function's service credential can retrieve the permanent key.
create or replace function public.service_decart_api_key()
returns text
language sql
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets
    where name = 'fashion_marketplace_decart_api_key';
$$;

revoke all on function public.admin_decart_status() from public, anon, authenticated;
revoke all on function public.admin_set_decart_api_key(text) from public, anon, authenticated;
revoke all on function public.service_decart_api_key() from public, anon, authenticated;
grant execute on function public.admin_decart_status() to authenticated;
grant execute on function public.admin_set_decart_api_key(text) to authenticated;
grant execute on function public.service_decart_api_key() to service_role;
notify pgrst, 'reload schema';
commit;
