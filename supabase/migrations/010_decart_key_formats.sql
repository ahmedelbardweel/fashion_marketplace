-- Accept both Decart application-key prefixes without changing Vault permissions.
begin;
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
  if clean_key is null or clean_key !~ '^dct_(app|new-app)_[A-Za-z0-9]{20,512}$' then
    raise exception 'Invalid Decart API key format' using errcode = '22023';
  end if;
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

revoke all on function public.admin_set_decart_api_key(text) from public, anon, authenticated;
grant execute on function public.admin_set_decart_api_key(text) to authenticated;
notify pgrst, 'reload schema';
commit;
