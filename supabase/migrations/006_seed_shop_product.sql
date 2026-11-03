-- Seed one published product for the latest approved shop
-- Images must exist in public bucket product-media/seed/

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

  insert into public.categories (name, description, is_active, sort_order)
  values ('قمصان', 'قمصان جاهزة للتجربة بالكاميرا', true, 1)
  on conflict (name) do update
    set description = excluded.description,
        is_active = true
  returning id into cid;

  if cid is null then
    select id into cid from public.categories where name = 'قمصان';
  end if;

  insert into public.products (
    shop_id, category_id, name, description, price, status
  )
  values (
    sid,
    cid,
    'قميص أوفرسايز أسود',
    'قميص قطني أوفرسايز بقصة واسعة، مناسب للتجربة عبر الكاميرا قبل الشراء. قماش مريح وتفاصيل واضحة للون الأسود.',
    149.00,
    'published'
  )
  returning id into pid;

  insert into public.product_variants (product_id, color, size, stock)
  values
    (pid, 'أسود', 'S', 8),
    (pid, 'أسود', 'M', 12),
    (pid, 'أسود', 'L', 10),
    (pid, 'أسود', 'XL', 6)
  on conflict (product_id, color, size) do update
    set stock = excluded.stock, is_active = true;

  insert into public.product_images (product_id, file_path, kind, sort_order)
  values
    (pid, base || '/gallery-front.jpg', 'gallery', 0),
    (pid, base || '/gallery-detail.jpg', 'gallery', 1),
    (pid, base || '/ar-front.jpg', 'ar', 0),
    (pid, base || '/ar-back.jpg', 'ar', 1);
end $$;
