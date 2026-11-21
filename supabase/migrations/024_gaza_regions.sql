-- Gaza Strip Regions & Neighborhoods Hierarchy (Governorates + Areas + Delivery Rules)

create table if not exists public.gaza_regions (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.gaza_regions(id) on delete cascade,
  name text not null,
  name_en text,
  governorate_code text,
  delivery_fee numeric(10, 2) not null default 10,
  estimated_delivery text default 'نفس اليوم',
  is_delivery_available boolean not null default true,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists gaza_regions_parent_idx
  on public.gaza_regions (parent_id, sort_order);

create unique index if not exists gaza_regions_root_name_uidx
  on public.gaza_regions (name)
  where parent_id is null;

create unique index if not exists gaza_regions_child_name_uidx
  on public.gaza_regions (parent_id, name)
  where parent_id is not null;

drop trigger if exists gaza_regions_set_updated_at on public.gaza_regions;
create trigger gaza_regions_set_updated_at
  before update on public.gaza_regions
  for each row execute function public.set_updated_at();

alter table public.gaza_regions enable row level security;

drop policy if exists "gaza_regions_public_read" on public.gaza_regions;
create policy "gaza_regions_public_read"
  on public.gaza_regions for select
  using (is_active = true or public.current_user_role() = 'admin');

drop policy if exists "gaza_regions_admin_all" on public.gaza_regions;
create policy "gaza_regions_admin_all"
  on public.gaza_regions for all
  using (public.current_user_role() = 'admin')
  with check (public.current_user_role() = 'admin');

-- Optional region links on shops, profiles, and orders (keeping city text synced)
alter table public.shops
  add column if not exists region_id uuid references public.gaza_regions(id) on delete set null;

alter table public.profiles
  add column if not exists region_id uuid references public.gaza_regions(id) on delete set null;

alter table public.orders
  add column if not exists region_id uuid references public.gaza_regions(id) on delete set null;

-- Admin RPC: Create or update a governorate or neighborhood
create or replace function public.admin_upsert_region(
  p_name text,
  p_name_en text default null,
  p_parent_id uuid default null,
  p_delivery_fee numeric default 10,
  p_estimated_delivery text default 'نفس اليوم',
  p_is_delivery_available boolean default true,
  p_is_active boolean default true,
  p_sort_order int default 0,
  p_id uuid default null
)
returns public.gaza_regions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.gaza_regions;
  v_clean_name text := trim(coalesce(p_name, ''));
  v_clean_en text := nullif(trim(coalesce(p_name_en, '')), '');
  v_clean_est text := coalesce(nullif(trim(coalesce(p_estimated_delivery, '')), ''), 'نفس اليوم');
  v_fee numeric(10, 2) := greatest(0, coalesce(p_delivery_fee, 0));
  v_gov_code text;
begin
  perform public.require_admin();

  if v_clean_name = '' then
    raise exception 'اسم المنطقة مطلوب';
  end if;

  if p_parent_id is not null then
    select governorate_code into v_gov_code
    from public.gaza_regions
    where id = p_parent_id;
  end if;

  if p_id is null then
    insert into public.gaza_regions (
      parent_id,
      name,
      name_en,
      governorate_code,
      delivery_fee,
      estimated_delivery,
      is_delivery_available,
      is_active,
      sort_order
    )
    values (
      p_parent_id,
      v_clean_name,
      v_clean_en,
      v_gov_code,
      v_fee,
      v_clean_est,
      coalesce(p_is_delivery_available, true),
      coalesce(p_is_active, true),
      coalesce(p_sort_order, 0)
    )
    returning * into v_result;
  else
    update public.gaza_regions
    set
      parent_id = p_parent_id,
      name = v_clean_name,
      name_en = v_clean_en,
      governorate_code = coalesce(v_gov_code, governorate_code),
      delivery_fee = v_fee,
      estimated_delivery = v_clean_est,
      is_delivery_available = coalesce(p_is_delivery_available, true),
      is_active = coalesce(p_is_active, true),
      sort_order = coalesce(p_sort_order, sort_order),
      updated_at = now()
    where id = p_id
    returning * into v_result;
  end if;

  return v_result;
end;
$$;

grant execute on function public.admin_upsert_region(text, text, uuid, numeric, text, boolean, boolean, int, uuid) to authenticated;

create or replace function public.admin_delete_region(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  delete from public.gaza_regions where id = p_id;
end;
$$;

grant execute on function public.admin_delete_region(uuid) to authenticated;

create or replace function public.admin_toggle_region_delivery(
  p_id uuid,
  p_is_delivery_available boolean
)
returns public.gaza_regions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.gaza_regions;
begin
  perform public.require_admin();

  update public.gaza_regions
  set
    is_delivery_available = coalesce(p_is_delivery_available, true),
    updated_at = now()
  where id = p_id
  returning * into v_result;

  -- If governorate toggled, optionally cascade to its child neighborhoods
  if v_result.id is not null and v_result.parent_id is null then
    update public.gaza_regions
    set
      is_delivery_available = v_result.is_delivery_available,
      updated_at = now()
    where parent_id = v_result.id;
  end if;

  return v_result;
end;
$$;

grant execute on function public.admin_toggle_region_delivery(uuid, boolean) to authenticated;

-- Seed all 5 Gaza Strip Governorates (North -> South) & main neighborhoods
do $$
declare
  g_north uuid;
  g_gaza uuid;
  g_middle uuid;
  g_khan uuid;
  g_rafah uuid;
begin
  -- 1) شمال غزة
  insert into public.gaza_regions (name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values ('شمال غزة', 'North Gaza', 'north_gaza', 15, '2 - 4 ساعات', 1)
  on conflict (name) where parent_id is null do update set sort_order = excluded.sort_order
  returning id into g_north;
  if g_north is null then select id into g_north from public.gaza_regions where parent_id is null and name = 'شمال غزة'; end if;

  -- 2) غزة
  insert into public.gaza_regions (name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values ('غزة', 'Gaza City', 'gaza', 10, '1 - 2 ساعة', 2)
  on conflict (name) where parent_id is null do update set sort_order = excluded.sort_order
  returning id into g_gaza;
  if g_gaza is null then select id into g_gaza from public.gaza_regions where parent_id is null and name = 'غزة'; end if;

  -- 3) الوسطى
  insert into public.gaza_regions (name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values ('الوسطى', 'Middle Area', 'middle', 15, '2 - 4 ساعات', 3)
  on conflict (name) where parent_id is null do update set sort_order = excluded.sort_order
  returning id into g_middle;
  if g_middle is null then select id into g_middle from public.gaza_regions where parent_id is null and name = 'الوسطى'; end if;

  -- 4) خان يونس
  insert into public.gaza_regions (name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values ('خان يونس', 'Khan Yunis', 'khan_yunis', 18, 'نفس اليوم', 4)
  on conflict (name) where parent_id is null do update set sort_order = excluded.sort_order
  returning id into g_khan;
  if g_khan is null then select id into g_khan from public.gaza_regions where parent_id is null and name = 'خان يونس'; end if;

  -- 5) رفح
  insert into public.gaza_regions (name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values ('رفح', 'Rafah', 'rafah', 20, 'نفس اليوم', 5)
  on conflict (name) where parent_id is null do update set sort_order = excluded.sort_order
  returning id into g_rafah;
  if g_rafah is null then select id into g_rafah from public.gaza_regions where parent_id is null and name = 'رفح'; end if;

  -- Neighborhoods: North Gaza
  insert into public.gaza_regions (parent_id, name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values
    (g_north, 'جباليا', 'Jabalia', 'north_gaza', 15, '2 - 4 ساعات', 1),
    (g_north, 'معسكر جباليا', 'Jabalia Camp', 'north_gaza', 15, '2 - 4 ساعات', 2),
    (g_north, 'بيت لاهيا', 'Beit Lahia', 'north_gaza', 15, '2 - 4 ساعات', 3),
    (g_north, 'مشروع بيت لاهيا', 'Beit Lahia Project', 'north_gaza', 15, '2 - 4 ساعات', 4),
    (g_north, 'بيت حانون', 'Beit Hanoun', 'north_gaza', 18, 'نفس اليوم', 5),
    (g_north, 'الصفطاوي', 'Al-Saftawi', 'north_gaza', 12, '2 - 3 ساعات', 6),
    (g_north, 'التوام', 'Al-Tawam', 'north_gaza', 12, '2 - 3 ساعات', 7),
    (g_north, 'العطاطرة', 'Al-Atatra', 'north_gaza', 15, '2 - 4 ساعات', 8)
  on conflict (parent_id, name) where parent_id is not null do nothing;

  -- Neighborhoods: Gaza City
  insert into public.gaza_regions (parent_id, name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values
    (g_gaza, 'الرمال الشمالي', 'North Rimal', 'gaza', 10, '1 - 2 ساعة', 1),
    (g_gaza, 'الرمال الجنوبي', 'South Rimal', 'gaza', 10, '1 - 2 ساعة', 2),
    (g_gaza, 'تل الهوى', 'Tel Al-Hawa', 'gaza', 10, '1 - 2 ساعة', 3),
    (g_gaza, 'النصر', 'Al-Nasr', 'gaza', 10, '1 - 2 ساعة', 4),
    (g_gaza, 'الشيخ رضوان', 'Sheikh Radwan', 'gaza', 10, '1 - 2 ساعة', 5),
    (g_gaza, 'مخيم الشاطئ', 'Al-Shati Camp', 'gaza', 10, '1 - 2 ساعة', 6),
    (g_gaza, 'الشجاعية', 'Shuja''iyya', 'gaza', 12, '1 - 3 ساعات', 7),
    (g_gaza, 'التفاح', 'Al-Tuffah', 'gaza', 12, '1 - 3 ساعات', 8),
    (g_gaza, 'الدرج', 'Al-Daraj', 'gaza', 10, '1 - 2 ساعة', 9),
    (g_gaza, 'الزيتون', 'Al-Zaytoun', 'gaza', 12, '1 - 3 ساعات', 10),
    (g_gaza, 'الصبرة', 'Al-Sabra', 'gaza', 10, '1 - 2 ساعة', 11),
    (g_gaza, 'الشيخ عجلين', 'Sheikh Ajlin', 'gaza', 12, '1 - 3 ساعات', 12),
    (g_gaza, 'الزهراء', 'Al-Zahra', 'gaza', 12, '2 - 3 ساعات', 13),
    (g_gaza, 'المغراقة', 'Al-Mughraqa', 'gaza', 14, '2 - 3 ساعات', 14)
  on conflict (parent_id, name) where parent_id is not null do nothing;

  -- Neighborhoods: Middle Area
  insert into public.gaza_regions (parent_id, name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values
    (g_middle, 'دير البلح', 'Deir Al-Balah', 'middle', 15, '2 - 4 ساعات', 1),
    (g_middle, 'النصيرات', 'Nuseirat', 'middle', 15, '2 - 4 ساعات', 2),
    (g_middle, 'البريج', 'Bureij', 'middle', 15, '2 - 4 ساعات', 3),
    (g_middle, 'المغازي', 'Maghazi', 'middle', 15, '2 - 4 ساعات', 4),
    (g_middle, 'الزوايدة', 'Al-Zawaida', 'middle', 15, '2 - 4 ساعات', 5),
    (g_middle, 'المصدر', 'Al-Musaddar', 'middle', 16, 'نفس اليوم', 6),
    (g_middle, 'وادي السلقا', 'Wadi Al-Salqa', 'middle', 16, 'نفس اليوم', 7)
  on conflict (parent_id, name) where parent_id is not null do nothing;

  -- Neighborhoods: Khan Yunis
  insert into public.gaza_regions (parent_id, name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values
    (g_khan, 'وسط خان يونس', 'Central Khan Yunis', 'khan_yunis', 18, 'نفس اليوم', 1),
    (g_khan, 'معسكر خان يونس', 'Khan Yunis Camp', 'khan_yunis', 18, 'نفس اليوم', 2),
    (g_khan, 'المواصي - خان يونس', 'Al-Mawasi (Khan Yunis)', 'khan_yunis', 18, 'نفس اليوم', 3),
    (g_khan, 'القرارة', 'Al-Qarara', 'khan_yunis', 18, 'نفس اليوم', 4),
    (g_khan, 'بني سهيلا', 'Bani Suheila', 'khan_yunis', 18, 'نفس اليوم', 5),
    (g_khan, 'عبسان الكبيرة', 'Abasan Al-Kabira', 'khan_yunis', 20, 'نفس اليوم', 6),
    (g_khan, 'عبسان الجديدة', 'Abasan Al-Jadida', 'khan_yunis', 20, 'نفس اليوم', 7),
    (g_khan, 'خزاعة', 'Khuza''a', 'khan_yunis', 20, 'نفس اليوم', 8),
    (g_khan, 'السطر الغربي والشرقي', 'Al-Satar', 'khan_yunis', 18, 'نفس اليوم', 9)
  on conflict (parent_id, name) where parent_id is not null do nothing;

  -- Neighborhoods: Rafah
  insert into public.gaza_regions (parent_id, name, name_en, governorate_code, delivery_fee, estimated_delivery, sort_order)
  values
    (g_rafah, 'وسط رفح', 'Central Rafah', 'rafah', 20, 'نفس اليوم', 1),
    (g_rafah, 'تل السلطان', 'Tel Al-Sultan', 'rafah', 20, 'نفس اليوم', 2),
    (g_rafah, 'الشابورة', 'Al-Shaboura', 'rafah', 20, 'نفس اليوم', 3),
    (g_rafah, 'يبنا', 'Yibna', 'rafah', 20, 'نفس اليوم', 4),
    (g_rafah, 'الجنينة', 'Al-Jeneina', 'rafah', 20, 'نفس اليوم', 5),
    (g_rafah, 'حي البرازيل', 'Brazil Neighborhood', 'rafah', 20, 'نفس اليوم', 6),
    (g_rafah, 'خربة العدس', 'Khirbet Al-Adas', 'rafah', 22, 'نفس اليوم', 7),
    (g_rafah, 'مواصي رفح', 'Al-Mawasi (Rafah)', 'rafah', 20, 'نفس اليوم', 8)
  on conflict (parent_id, name) where parent_id is not null do nothing;
end $$;
