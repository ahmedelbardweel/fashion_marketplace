-- Seed test product with transparent background image (AI Background Removal test)
do $$
declare
  sid uuid;
  cid uuid;
  pid uuid;
  base text := 'https://yjuuvsjhpoghqlndclpr.supabase.co/storage/v1/object/public/product-media/seed';
begin
  select id into sid
  from public.shops
  where status = 'approved'
  order by updated_at desc
  limit 1;

  if sid is null then
    raise exception 'لا يوجد محل معتمد لإضافة المنتج';
  end if;

  select id into cid from public.categories where name = 'قمصان' limit 1;

  insert into public.products (
    shop_id, category_id, name, description, price, status
  )
  values (
    sid,
    cid,
    'قميص أسود (تفريغ خلفية ✨)',
    'منتج تجريبي لمعاينة تفريغ الخلفية بالذكاء الاصطناعي بدقة عالية مع خلفية شفافة نقية.',
    199.00,
    'published'
  )
  returning id into pid;

  insert into public.product_variants (product_id, color, size, stock)
  values
    (pid, 'أسود', 'M', 15),
    (pid, 'أسود', 'L', 20),
    (pid, 'أسود', 'XL', 10);

  insert into public.product_images (product_id, file_path, kind, sort_order)
  values
    (pid, base || '/gallery-front-no-bg.png', 'gallery', 0);
end $$;
