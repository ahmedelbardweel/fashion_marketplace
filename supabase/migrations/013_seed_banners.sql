-- 013_seed_banners.sql
-- تحديث دالة حفظ البنرات لدعم رابط الصورة (اختياري) + إضافة بنرات إعلانية جاهزة للظهور عند المستخدم

create or replace function public.admin_upsert_banner(
  p_title text,
  p_subtitle text default null,
  p_is_active boolean default true,
  p_id uuid default null,
  p_image_path text default null
)
returns public.banners
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.banners;
begin
  perform public.require_admin();

  if coalesce(trim(p_title), '') = '' then
    raise exception 'عنوان البنر مطلوب';
  end if;

  if p_id is null then
    insert into public.banners (title, subtitle, image_path, is_active)
    values (
      trim(p_title),
      nullif(trim(p_subtitle), ''),
      nullif(trim(p_image_path), ''),
      p_is_active
    )
    returning * into result;
  else
    update public.banners
    set
      title = trim(p_title),
      subtitle = nullif(trim(p_subtitle), ''),
      image_path = coalesce(nullif(trim(p_image_path), ''), image_path),
      is_active = p_is_active,
      updated_at = now()
    where id = p_id
    returning * into result;
  end if;

  return result;
end;
$$;

-- إضافة بنرات إعلانية احترافية لتظهر فوراً في الصفحة الرئيسية للعميل
insert into public.banners (title, subtitle, image_path, is_active, sort_order)
values
  (
    'خصم 30% على تشكيلة الموسم الجديد',
    'تسوق أحدث الأزياء العصرية وجربها بالكاميرا قبل الشراء',
    'https://yjuuvsjhpoghqlndclpr.supabase.co/storage/v1/object/public/product-media/seed/gallery-front.jpg',
    true,
    1
  ),
  (
    'تجربة القياس الافتراضي بالذكاء الاصطناعي',
    'شاهد كيف تبدو الملابس عليك مباشرة عبر الكاميرا بدقة عالية',
    null,
    true,
    2
  );
