-- Support Google OAuth metadata (name / full_name) in handle_new_user trigger
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_role public.user_role;
  shop_name text;
  resolved_name text;
begin
  selected_role := coalesce(
    (new.raw_user_meta_data->>'role')::public.user_role,
    'customer'
  );

  -- Never allow self-signup as admin
  if selected_role = 'admin' then
    selected_role := 'customer';
  end if;

  resolved_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(trim(new.raw_user_meta_data->>'name'), '')
  );

  insert into public.profiles (id, email, full_name, phone, role)
  values (
    new.id,
    coalesce(new.email, ''),
    resolved_name,
    nullif(trim(new.raw_user_meta_data->>'phone'), ''),
    selected_role
  )
  on conflict (id) do update
  set
    full_name = coalesce(public.profiles.full_name, excluded.full_name),
    updated_at = now();

  if selected_role = 'shop' then
    shop_name := coalesce(
      nullif(trim(new.raw_user_meta_data->>'shop_name'), ''),
      'متجر جديد'
    );
    insert into public.shops (owner_id, name, status)
    values (new.id, shop_name, 'draft')
    on conflict (owner_id) do nothing;
  end if;

  return new;
end;
$$;

