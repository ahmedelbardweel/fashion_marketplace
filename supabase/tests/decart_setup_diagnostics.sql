-- Read-only deployment diagnostics. Run using an authorized database connection.
-- Outputs only installation flags, never credentials or function bodies.
select
  (select extversion from pg_catalog.pg_extension
    where extname = 'supabase_vault') as vault_version,
  to_regprocedure('public.admin_decart_status()') is not null as status_installed,
  to_regprocedure('public.admin_set_decart_api_key(text)') is not null as save_installed,
  to_regprocedure('public.service_decart_api_key()') is not null as resolver_installed,
  coalesce((select position('new-app' in p.prosrc) > 0
    from pg_catalog.pg_proc p
    where p.oid = to_regprocedure('public.admin_set_decart_api_key(text)')),
    false) as new_app_format_supported,
  coalesce((select position('char_length(key_payload)' in p.prosrc) > 0
      and position('{20,512}' in p.prosrc) = 0
    from pg_catalog.pg_proc p
    where p.oid = to_regprocedure('public.admin_set_decart_api_key(text)')),
    false) as postgres_validation_fix_installed;
