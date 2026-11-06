-- Atomic seller editor: category creation, details, variants and ordered media.
alter table public.products add column if not exists details jsonb not null default '{}'::jsonb;

create or replace function public.shop_save_product_form(p_data jsonb)
returns public.products
language plpgsql security definer set search_path = public
as $$
declare
  sid uuid := public.require_approved_shop();
  result public.products;
  category uuid := nullif(p_data->>'category_id', '')::uuid;
  category_name text := trim(coalesce(p_data->>'new_category_name', ''));
  entry jsonb;
  position integer := 0;
  variants jsonb := p_data->'variants';
  images jsonb := p_data->'images';
  saved_variant public.product_variants;
  kept_variants uuid[] := '{}';
begin
  if jsonb_typeof(variants) is distinct from 'array' or jsonb_typeof(images) is distinct from 'array'
    or jsonb_typeof(p_data->'details') is distinct from 'object' then
    raise exception 'بيانات المنتج غير صالحة';
  end if;
  if jsonb_array_length(images) > 12 or jsonb_array_length(variants) > 200 then
    raise exception 'تجاوزت العدد المسموح للصور أو المقاسات';
  end if;
  if (p_data->>'price')::numeric < 0 or (p_data->>'price')::numeric = 'NaN'::numeric then
    raise exception 'السعر غير صالح';
  end if;
  if p_data->>'status' = 'published' and (
    not exists (select 1 from jsonb_array_elements(images) i where i->>'kind' = 'gallery') or jsonb_array_length(variants) = 0
    or coalesce((p_data->>'price')::numeric, 0) <= 0
    or trim(coalesce(p_data->>'description', '')) = ''
    or not exists (select 1 from jsonb_array_elements(variants) v where (v->>'stock')::integer > 0)
  ) then raise exception 'أكمل الوصف والسعر والصور والمخزون قبل النشر'; end if;
  if category_name <> '' then
    if length(category_name) > 80 then raise exception 'اسم التصنيف طويل جداً'; end if;
    perform pg_advisory_xact_lock(hashtext('shop_category_' || lower(category_name)));
    select id into category from public.categories where lower(name) = lower(category_name) and is_active limit 1;
    if category is null then
      if exists (select 1 from public.categories where lower(name) = lower(category_name)) then
        raise exception 'هذا التصنيف غير متاح، اختر تصنيفاً آخر';
      end if;
      insert into public.categories(name) values (category_name) returning id into category;
    end if;
  end if;
  if category is not null and not exists(select 1 from public.categories where id = category and is_active) then
    raise exception 'اختر تصنيفاً متاحاً';
  end if;
  if p_data->>'status' = 'published' and category is null then raise exception 'اختر تصنيف المنتج'; end if;
  result := public.shop_upsert_product(p_data->>'name', p_data->>'description',
    (p_data->>'price')::numeric, category, (p_data->>'status')::public.product_status,
    nullif(p_data->>'id', '')::uuid);
  update public.products set details = p_data->'details' where id = result.id;
  for entry in select value from jsonb_array_elements(variants) loop
    saved_variant := public.shop_upsert_variant(result.id, entry->>'color', entry->>'size', (entry->>'stock')::integer);
    if saved_variant.id = any(kept_variants) then raise exception 'اللون والمقاس مكرران'; end if;
    kept_variants := array_append(kept_variants, saved_variant.id);
  end loop;
  -- Keep historical IDs used by orders; retired options are unavailable to buyers.
  update public.product_variants set is_active = false, stock = 0
    where product_id = result.id and not (id = any(kept_variants));
  delete from public.product_images where product_id = result.id;
  for entry in select value from jsonb_array_elements(images) loop
    if coalesce(entry->>'path', '') !~ '^https://' or coalesce(entry->>'kind', '') not in ('gallery', 'ar', '3d_model') then
      raise exception 'صورة المنتج غير صالحة';
    end if;
    insert into public.product_images(product_id, file_path, kind, sort_order)
      values(result.id, entry->>'path', entry->>'kind', position);
    position := position + 1;
  end loop;
  select * into result from public.products where id = result.id and shop_id = sid;
  return result;
end;
$$;
revoke all on function public.shop_save_product_form(jsonb) from public, anon;
grant execute on function public.shop_save_product_form(jsonb) to authenticated;
