-- Allow shop owners to safely delete/deactivate their shop and account
-- while preserving historical order records.

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
as $$
begin
  if current_setting('app.allow_self_deactivate', true) = 'true'
     and new.id = auth.uid()
     and new.role = old.role
     and new.email = old.email then
    return new;
  end if;

  if public.current_user_role() is distinct from 'admin' then
    new.role := old.role;
    new.is_active := old.is_active;
    new.id := old.id;
    new.email := old.email;
  end if;
  return new;
end;
$$;

create or replace function public.delete_my_shop_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  sid uuid;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  select id into sid
  from public.shops
  where owner_id = uid
  limit 1;

  if sid is not null then
    update public.products
    set status = 'deleted', updated_at = now()
    where shop_id = sid;

    update public.shops
    set status = 'suspended', updated_at = now()
    where id = sid;
  end if;

  perform set_config('app.allow_self_deactivate', 'true', true);

  update public.profiles
  set is_active = false, updated_at = now()
  where id = uid;
end;
$$;

grant execute on function public.delete_my_shop_account() to authenticated;
