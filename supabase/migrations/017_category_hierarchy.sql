-- Run this whole file in Supabase SQL Editor. Safe to rerun; no products deleted.
begin;
alter table public.categories add column if not exists parent_id uuid
  references public.categories(id) on delete restrict;
alter table public.categories add column if not exists icon_key text;
create index if not exists categories_parent_order_idx
  on public.categories(parent_id, sort_order);

-- Two levels: department -> product type. Serialize structural edits to prevent
-- concurrent writes from creating cycles or turning a department into a child.
create or replace function public.validate_category_parent()
returns trigger language plpgsql set search_path = public as $$
begin
  perform pg_advisory_xact_lock(170017);
  if new.parent_id is not null then
    if new.parent_id = new.id then raise exception 'التصنيف لا يمكن أن يكون أباً لنفسه'; end if;
    if not exists (select 1 from public.categories where id = new.parent_id and parent_id is null) then
      raise exception 'اختر تصنيفاً رئيسياً صالحاً';
    end if;
    if exists (select 1 from public.categories where parent_id = new.id) then
      raise exception 'لا يمكن نقل تصنيف رئيسي يحتوي على تصنيفات فرعية';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists categories_validate_parent on public.categories;
create trigger categories_validate_parent before insert or update of parent_id
  on public.categories for each row execute function public.validate_category_parent();

insert into public.categories(name, icon_key, sort_order, is_active)
values ('ملابس','clothing',10,true), ('أحذية','shoes',20,true),
 ('إكسسوارات','accessories',30,true), ('حقائب','bags',40,true),
 ('إلكترونيات','electronics',50,true), ('عطور وتجميل','beauty',60,true)
on conflict(name) do update set icon_key=excluded.icon_key,
 sort_order=excluded.sort_order, is_active=true, parent_id=null;

-- Reuse existing names/IDs, preserving product.category_id relationships.
with seed(department, name, position) as (values
 ('ملابس','هودي',10), ('ملابس','تيشيرتات',20), ('ملابس','قمصان',30),
 ('ملابس','بناطيل',40), ('ملابس','جاكيتات',50), ('ملابس','فساتين',60),
 ('ملابس','ملابس رياضية',70), ('ملابس','ملابس أطفال',80),
 ('أحذية','سنيكرز',10), ('أحذية','أحذية رسمية',20), ('أحذية','بوتات',30), ('أحذية','صنادل',40),
 ('إكسسوارات','ساعات',10), ('إكسسوارات','نظارات',20), ('إكسسوارات','مجوهرات',30), ('إكسسوارات','أحزمة',40),
 ('حقائب','حقائب يد',10), ('حقائب','حقائب ظهر',20), ('حقائب','حقائب سفر',30), ('حقائب','محافظ',40),
 ('إلكترونيات','هواتف',10), ('إلكترونيات','سماعات',20), ('إلكترونيات','ساعات ذكية',30), ('إلكترونيات','شواحن',40),
 ('عطور وتجميل','عطور',10), ('عطور وتجميل','مكياج',20), ('عطور وتجميل','عناية بالبشرة',30), ('عطور وتجميل','عناية بالشعر',40)
)
insert into public.categories(name,parent_id,sort_order,is_active)
select s.name,p.id,s.position,true from seed s join public.categories p on p.name=s.department
on conflict(name) do update set parent_id=excluded.parent_id, sort_order=excluded.sort_order, is_active=true;

-- Explicit mapping of the existing fashion seed; unknown names are left intact.
with legacy(name,department) as (values
 ('تيشيرتات وقمصان رجالي','ملابس'), ('هوديز وسويت شيرت','ملابس'),
 ('جاكيتات ومعاطف رجالي','ملابس'), ('بناطيل وجينز رجالي','ملابس'),
 ('فساتين وأزياء نسائية','ملابس'), ('بلوزات وأطقم نسائية','ملابس'),
 ('معاطف وجاكيتات نسائي','ملابس'), ('بناطيل وتنانير نسائي','ملابس'),
 ('بوات وسنيكرز رياضي','أحذية'), ('بوتات وأحذية كلاسيك','أحذية')
)
update public.categories c set parent_id=p.id
from legacy l join public.categories p on p.name=l.department
where c.name=l.name and c.parent_id is null;

-- A new RPC keeps the old admin endpoint compatible with older clients.
drop function if exists public.admin_upsert_category_tree(text,text,boolean,uuid,uuid);
create or replace function public.admin_upsert_category_tree(
 p_name text, p_description text default null, p_is_active boolean default true,
 p_id uuid default null, p_parent_id uuid default null, p_icon_key text default null
) returns public.categories language plpgsql security definer set search_path=public as $$
declare result public.categories;
begin
 perform public.require_admin();
 if coalesce(trim(p_name),'')='' then raise exception 'اسم التصنيف مطلوب'; end if;
 if p_id is null then
  insert into public.categories(name,description,is_active,parent_id,icon_key)
  values(trim(p_name),nullif(trim(p_description),''),p_is_active,p_parent_id,nullif(trim(p_icon_key),'')) returning * into result;
 else
  update public.categories set name=trim(p_name),description=nullif(trim(p_description),''),
    is_active=p_is_active,parent_id=p_parent_id,
    icon_key=case when p_parent_id is not null then null else coalesce(nullif(trim(p_icon_key),''), icon_key) end
    where id=p_id returning * into result;
 end if;
 if result.id is null then raise exception 'التصنيف غير موجود'; end if;
 return result;
end $$;
revoke all on function public.admin_upsert_category_tree(text,text,boolean,uuid,uuid,text) from public;
grant execute on function public.admin_upsert_category_tree(text,text,boolean,uuid,uuid,text) to authenticated;
commit;
