-- Run after migration 009; no fixtures or persistent writes are needed.
begin;
do $$
begin
  assert not has_function_privilege('anon', 'public.service_decart_api_key()', 'execute'), 'anonymous read';
  assert not has_function_privilege('authenticated', 'public.service_decart_api_key()', 'execute'), 'client read';
  assert has_function_privilege('service_role', 'public.service_decart_api_key()', 'execute'), 'server read';
  assert not has_function_privilege('anon', 'public.admin_set_decart_api_key(text)', 'execute'), 'anonymous write';
  assert not has_function_privilege('anon', 'public.admin_decart_status()', 'execute'), 'anonymous status';
end;
$$;
select set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-0000-0000-000000000001"}', true);
set local role authenticated;
do $$
begin
  begin
    perform public.admin_decart_status();
    raise exception 'Non-admin status access was allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.admin_set_decart_api_key('dct_app_12345678901234567890');
    raise exception 'Non-admin write was allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.service_decart_api_key();
    raise exception 'Client secret read was allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
select '8 permission checks passed' as result;
rollback;
