-- 016_mega_fashion_seeder.sql
-- سيدر ضخم ومتكامل:
-- 1) 5 بنرات إعلانية احترافية
-- 2) 10 تصنيفات (ملابس رجالي، ملابس نسائي، بوات وسنيكرز، بوتات وأحذية كلاسيك)
-- 3) 10 محلات معتمدة (status = 'approved') مع شعارات وأغلفة وبيانات كاملة
-- 4) 200 منتج لكل محل (إجمالي 2,000 منتج منشور) مع المقاسات والألوان والمخزون وصور حقيقية مضمونة 100%

BEGIN;

-- ضمان وجود الأعمدة والجداول الحديثة قبل التفريغ والتعبئة
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS details jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  variant_id uuid REFERENCES public.product_variants(id) ON DELETE SET NULL,
  color text NOT NULL DEFAULT '',
  size text NOT NULL DEFAULT '',
  quantity int NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (customer_id, product_id, color, size)
);

CREATE TABLE IF NOT EXISTS public.comparison_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (customer_id, product_id)
);

-- =============================================================================
-- 0. تنظيف البيانات السابقة (لضمان عدم التكرار والبدء ببيانات نظيفة ومتناسقة)
-- =============================================================================
TRUNCATE TABLE
  public.cart_items,
  public.comparison_items,
  public.favorites,
  public.product_reviews,
  public.order_items,
  public.orders,
  public.product_images,
  public.product_variants,
  public.products,
  public.shop_images,
  public.shop_documents,
  public.shops,
  public.categories,
  public.banners
RESTART IDENTITY CASCADE;

-- =============================================================================
-- 1. إضافة 5 بنرات إعلانية احترافية (Banners) بصور أزياء وبوات مضمونة 100%
-- =============================================================================
INSERT INTO public.banners (title, subtitle, image_path, is_active, sort_order)
VALUES
  (
    'تشكيلة الموسم الجديد خصم حتى 40%',
    'أحدث الأزياء الرجالية والنسائية وأفخم البوات الرياضية والكلاسيكية',
    'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
    true,
    1
  ),
  (
    'عالم البوات والسنيكرز الأصلي',
    'تشكيلة واسعة من الأحذية الرياضية والبوتات الجلدية بأعلى جودة وراحة',
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=1200&q=80',
    true,
    2
  ),
  (
    'أناقة الشتاء والجاكيتات الفاخرة',
    'هوديز، بليزرات، ومعاطف عصرية تناسب جميع الإطلالات اليومية والرسمية',
    'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=1200&q=80',
    true,
    3
  ),
  (
    'تشكيلة الفساتين والأزياء النسائية',
    'تصاميم راقية وخامات فاخرة تمنحك إطلالة متكاملة في كل مناسبة',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
    true,
    4
  ),
  (
    'غرفة القياس الافتراضية بالذكاء الاصطناعي',
    'جرب الملابس عليك مباشرة بالكاميرا قبل الشراء وتأكد من المقاس المناسب',
    'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=1200&q=80',
    true,
    5
  );

-- =============================================================================
-- 2. إضافة 10 تصنيفات شاملة (رجالي، نسائي، بوات وسنيكرز، بوتات جلدية)
-- =============================================================================
INSERT INTO public.categories (id, name, description, is_active, sort_order)
VALUES
  ('10000000-0000-0000-0000-000000000001'::uuid, 'تيشيرتات وقمصان رجالي', 'قمصان كاجوال وكلاسيك وتيشيرتات قطنية وأوفرسايز رجالية', true, 1),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'هوديز وسويت شيرت', 'هوديز شتوية وسويت شيرت عصري مريح للجنسين', true, 2),
  ('10000000-0000-0000-0000-000000000003'::uuid, 'جاكيتات ومعاطف رجالي', 'جاكيتات جلد، بومبر، جينز، وبليزرات رسمية رجالية', true, 3),
  ('10000000-0000-0000-0000-000000000004'::uuid, 'بناطيل وجينز رجالي', 'بناطيل جينز، كارجو، تشينو، وبناطيل رياضية رجالية', true, 4),
  ('10000000-0000-0000-0000-000000000005'::uuid, 'فساتين وأزياء نسائية', 'فساتين سهرة، فساتين ميدي وكاجوال، وإطلالات نسائية راقية', true, 5),
  ('10000000-0000-0000-0000-000000000006'::uuid, 'بلوزات وأطقم نسائية', 'بلوزات، قمصان نسائية، كارديغان، وأطقم كاجوال متكاملة', true, 6),
  ('10000000-0000-0000-0000-000000000007'::uuid, 'معاطف وجاكيتات نسائي', 'ترانش كوت، بليزرات نسائية، وجاكيتات شتوية أنيقة', true, 7),
  ('10000000-0000-0000-0000-000000000008'::uuid, 'بناطيل وتنانير نسائي', 'بناطيل جينز نسائي، بناطيل قماش واسعة، وتنانير عصرية', true, 8),
  ('10000000-0000-0000-0000-000000000009'::uuid, 'بوات وسنيكرز رياضي', 'بوات رياضي، سنيكرز كاجوال، وأحذية مشي وجري رجالي ونسائي', true, 9),
  ('10000000-0000-0000-0000-000000000010'::uuid, 'بوتات وأحذية كلاسيك', 'بوتات جلدية شتوية، تشيلسي بوت، وأحذية رسمية وكلاسيكية', true, 10)
ON CONFLICT (name) DO UPDATE
SET
  description = EXCLUDED.description,
  is_active = true,
  sort_order = EXCLUDED.sort_order;

-- =============================================================================
-- 3. إنشاء 10 حسابات أصحاب محلات + 10 محلات معتمدة (Approved Shops)
-- =============================================================================
DO $$
DECLARE
  v_shop_owners uuid[] := ARRAY[
    '20000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid,
    '20000000-0000-0000-0000-000000000003'::uuid,
    '20000000-0000-0000-0000-000000000004'::uuid,
    '20000000-0000-0000-0000-000000000005'::uuid,
    '20000000-0000-0000-0000-000000000006'::uuid,
    '20000000-0000-0000-0000-000000000007'::uuid,
    '20000000-0000-0000-0000-000000000008'::uuid,
    '20000000-0000-0000-0000-000000000009'::uuid,
    '20000000-0000-0000-0000-000000000010'::uuid
  ];
  v_shop_ids uuid[] := ARRAY[
    '30000000-0000-0000-0000-000000000001'::uuid,
    '30000000-0000-0000-0000-000000000002'::uuid,
    '30000000-0000-0000-0000-000000000003'::uuid,
    '30000000-0000-0000-0000-000000000004'::uuid,
    '30000000-0000-0000-0000-000000000005'::uuid,
    '30000000-0000-0000-0000-000000000006'::uuid,
    '30000000-0000-0000-0000-000000000007'::uuid,
    '30000000-0000-0000-0000-000000000008'::uuid,
    '30000000-0000-0000-0000-000000000009'::uuid,
    '30000000-0000-0000-0000-000000000010'::uuid
  ];
  v_shop_names text[] := ARRAY[
    'دار الأناقة للأزياء',
    'نوفا فاشن هاوس',
    'بوتيك ليالي المخمل',
    'ستريت ستايل للملابس الرجالية',
    'خطوة ستور للبوات والأحذية',
    'إيليت كوتور للسيدات',
    'أوربان كلوب للملابس الرياضية',
    'كلاسيك مان للبدلات والقمصان',
    'سنيكرز زون - عالم البوات',
    'لافي روز للأزياء العصرية'
  ];
  v_shop_descs text[] := ARRAY[
    'وجهتك الأولى للأزياء العصرية الرجالية والنسائية وأحدث تشكيلات الموسم بخامات ممتازة.',
    'متجر متخصص في أحدث صيحات الموضة العالمية والملابس الكاجوال والرياضية.',
    'أرقى الفساتين والبلوزات والمعاطف النسائية بتصاميم عصرية وخامات تركية وأوروبية.',
    'كل ما يحتاجه الرجل العصري من تيشيرتات أوفرسايز، هوديز، جينزات، وجاكيتات.',
    'أضخم تشكيلة بوات رياضية، سنيكرز، وبوتات جلدية رجالية ونسائية بأعلى جودة.',
    'إطلالات نسائية متكاملة من الفساتين والأطقم الرسمية والكاجوال لكل المناسبات.',
    'ملابس رياضية، هوديز، أطقم مريحة، وبوات سنيكرز مخصصة للحركة اليومية.',
    'أناقة الرجل الكلاسيكي والسبور شيك: قمصان، بليزرات، بناطيل، وأحذية جلدية.',
    'متخصصون في البوات الرياضية والسنيكرز العصري والبوتات الشتوية لجميع المقاسات.',
    'تشكيلة متجددة من الملابس النسائية والرجالية والأحذية العصرية بأسعار منافسة.'
  ];
  v_cities text[] := ARRAY[
    'رام الله', 'نابلس', 'القدس', 'الخليل', 'بيت لحم',
    'جنين', 'طولكرم', 'رام الله', 'نابلس', 'قلقيلية'
  ];
  v_addresses text[] := ARRAY[
    'شارع ركب - مجمع الأناقة التجاري - الطابق الثاني',
    'رفيديا - الشارع الرئيسي مقابل جامعة النجاح',
    'شارع صلاح الدين - سنتر القدس التجاري',
    'عين سارة - عمارة النخيل الطابق الأول',
    'شارع المهد - مول بيت لحم الحديث',
    'شارع الناصرة - مجمع جنين مول',
    'شارع باريس - وسط البلد',
    'الماصيون - بوليفارد رام الله',
    'شارع فيصل - سنتر نابلس التجاري',
    'الشارع الغربي - مقابل البلدية'
  ];
  v_logos text[] := ARRAY[
    'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1595777457583-95e059d581b8?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1507679799987-c73779587ccf?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1560769629-975ec94e6a86?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=400&q=80'
  ];
  v_covers text[] := ARRAY[
    'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1507679799987-c73779587ccf?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1560769629-975ec94e6a86?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1571867424485-369464ed33cc?auto=format&fit=crop&w=1200&q=80'
  ];
  i int;
BEGIN
  DELETE FROM auth.users WHERE email LIKE 'shop%@shopy.ps';

  FOR i IN 1..10 LOOP
    -- إنشاء مستخدم صاحب المحل في auth.users إن لم يكن موجوداً
    INSERT INTO auth.users (
      id,
      instance_id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    )
    VALUES (
      v_shop_owners[i],
      '00000000-0000-0000-0000-000000000000'::uuid,
      'authenticated',
      'authenticated',
      'shop' || i || '@shopy.ps',
      '$2a$10$7EqJtq98hPqEX7fNZaFWoOHi6M1O8f7bV2e6W8f8p3kX7z9q1m2a.',
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'role', 'shop',
        'full_name', 'إدارة ' || v_shop_names[i],
        'phone', '05990000' || lpad(i::text, 2, '0'),
        'shop_name', v_shop_names[i]
      ),
      now(),
      now()
    )
    ON CONFLICT (id) DO NOTHING;

    -- ضمان وجود البروفايل ببيانات مكتملة
    INSERT INTO public.profiles (
      id, email, full_name, phone, city, address, role, is_active, profile_completed
    )
    VALUES (
      v_shop_owners[i],
      'shop' || i || '@shopy.ps',
      'إدارة ' || v_shop_names[i],
      '05990000' || lpad(i::text, 2, '0'),
      v_cities[i],
      v_addresses[i],
      'shop',
      true,
      true
    )
    ON CONFLICT (id) DO UPDATE
    SET
      full_name = EXCLUDED.full_name,
      phone = EXCLUDED.phone,
      city = EXCLUDED.city,
      address = EXCLUDED.address,
      role = 'shop',
      is_active = true,
      profile_completed = true;

    -- حذف أي سجل محل تلقائي قديم لنفس المالك وإدخال المحل المعتمد بالمعرف الثابت
    DELETE FROM public.shops WHERE owner_id = v_shop_owners[i] AND id <> v_shop_ids[i];

    INSERT INTO public.shops (
      id,
      owner_id,
      name,
      description,
      city,
      address,
      commercial_register,
      logo_path,
      cover_path,
      status,
      submitted_at,
      decision_at,
      decision_visible_at
    )
    VALUES (
      v_shop_ids[i],
      v_shop_owners[i],
      v_shop_names[i],
      v_shop_descs[i],
      v_cities[i],
      v_addresses[i],
      'CR-2026-' || lpad(i::text, 4, '0'),
      v_logos[i],
      v_covers[i],
      'approved',
      now() - interval '5 days',
      now() - interval '3 days',
      now() - interval '2 days'
    )
    ON CONFLICT (id) DO UPDATE
    SET
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      city = EXCLUDED.city,
      address = EXCLUDED.address,
      commercial_register = EXCLUDED.commercial_register,
      logo_path = EXCLUDED.logo_path,
      cover_path = EXCLUDED.cover_path,
      status = 'approved',
      decision_at = EXCLUDED.decision_at,
      decision_visible_at = EXCLUDED.decision_visible_at;
  END LOOP;
END $$;

-- =============================================================================
-- 4. توليد 200 منتج لكل محل (10 محلات × 200 منتج = 2,000 منتج)
--    مع توزيع متوازن على الـ 10 تصنيفات (رجالي، نسائي، بوات وسنيكرز، بوتات كلاسيك)
-- =============================================================================
DO $$
DECLARE
  v_shop_ids uuid[] := ARRAY[
    '30000000-0000-0000-0000-000000000001'::uuid,
    '30000000-0000-0000-0000-000000000002'::uuid,
    '30000000-0000-0000-0000-000000000003'::uuid,
    '30000000-0000-0000-0000-000000000004'::uuid,
    '30000000-0000-0000-0000-000000000005'::uuid,
    '30000000-0000-0000-0000-000000000006'::uuid,
    '30000000-0000-0000-0000-000000000007'::uuid,
    '30000000-0000-0000-0000-000000000008'::uuid,
    '30000000-0000-0000-0000-000000000009'::uuid,
    '30000000-0000-0000-0000-000000000010'::uuid
  ];

  v_cat_ids uuid[] := ARRAY[
    '10000000-0000-0000-0000-000000000001'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000004'::uuid,
    '10000000-0000-0000-0000-000000000005'::uuid,
    '10000000-0000-0000-0000-000000000006'::uuid,
    '10000000-0000-0000-0000-000000000007'::uuid,
    '10000000-0000-0000-0000-000000000008'::uuid,
    '10000000-0000-0000-0000-000000000009'::uuid,
    '10000000-0000-0000-0000-000000000010'::uuid
  ];

  -- أسماء منتجات واقعية لكل تصنيف من الـ 10 تصنيفات
  v_cat1_names text[] := ARRAY[
    'تيشيرت قطن أوفرسايز بريميوم', 'قميص كتان صيفي كاجوال', 'تيشيرت بولو كلاسيك مطرز', 'قميص أوكسفورد سليم فيت', 'تيشيرت أساسي بياقة دائرية'
  ];
  v_cat2_names text[] := ARRAY[
    'هودي شتوي مبطن بقبعة', 'سويت شيرت قطن ثقيل أوفرسايز', 'هودي رياضي بسحاب كامل', 'سويت شيرت كاجوال بطباعة عصرية', 'هودي ستريت ستايل فاخر'
  ];
  v_cat3_names text[] := ARRAY[
    'جاكيت بومبر مقاوم للرياح', 'جاكيت جلد كلاسيك فاخر', 'بليزر رجالي رسمي بقصة عصرية', 'جاكيت جينز مبطن للشتاء', 'معطف رجالي طويل صوف'
  ];
  v_cat4_names text[] := ARRAY[
    'بنطلون جينز سليم فيت', 'بنطلون كارجو بجيوب جانبية', 'بنطلون تشينو قطني مريح', 'بنطلون جينز ستريت وايد ليج', 'بنطلون رياضي جوغر قطني'
  ];
  v_cat5_names text[] := ARRAY[
    'فستان ميدي بطبعة زهور أنيقة', 'فستان سهرة مخمل فاخر', 'فستان كاجوال يومي بقصة انسيابية', 'فستان شيفون طويل للمناسبات', 'فستان كلاسيك بحزام خصر'
  ];
  v_cat6_names text[] := ARRAY[
    'بلوزة حرير ناعمة بأكمام طويلة', 'كارديغان صوف تريكو بأزرار ذهبية', 'طقم نسائي كاجوال قطعتين', 'قميص نسائي كلاسيك ساتان', 'بلوزة كاجوال بقصة عصرية'
  ];
  v_cat7_names text[] := ARRAY[
    'ترانش كوت نسائي كلاسيك طويل', 'بليزر نسائي رسمي أنيق', 'مانطو شتوي صوف فاخر', 'جاكيت نسائي قصير مبطن', 'معطف نسائي كشمير بحزام'
  ];
  v_cat8_names text[] := ARRAY[
    'بنطلون جينز نسائي هاي ويست', 'تنورة ميدي بليسيه أنيقة', 'بنطلون قماش واسع بالازو', 'تنورة كاجوال بقصة مستقيمة', 'بنطلون نسائي كلاسيك رسمي'
  ];
  v_cat9_names text[] := ARRAY[
    'بوات رياضي رانينغ خفيف ومريح', 'سنيكرز كاجوال يومي بنعل طبي', 'بوات سبور ستريت ستايل عصري', 'سنيكرز رياضي مبطن للمشي الطويل', 'بوات رياضي برو الترا فليكس'
  ];
  v_cat10_names text[] := ARRAY[
    'بوت جلد طبيعي تشيلسي كلاسيك', 'حذاء لوفر جلد رسمي فاخر', 'بوت شتوي مقاوم للماء بنعل متين', 'حذاء نسائي كلاسيك بكعب مريح', 'بوت جلد هاف بوت عصري'
  ];

  v_style_adjs text[] := ARRAY[
    'إصدار خاص', 'تشكيلة 2026', 'تصميم إيطالي', 'خامة تركية فاخرة', 'قصة مريحة',
    'ملمس ناعم', 'مقاوم للانكماش', 'جودة عالية', 'إطلالة عصرية', 'نسخة محدودة'
  ];

  -- صور مضمونة ومفحوصة 100% لكل تصنيف (3 صور لكل تصنيف: ملابس رجالي، نسائي، بوات وسنيكرز، وبوتات جلدية)
  v_cat1_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat2_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1609873814058-a8928924184a?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1608262618448-3bc64a7e2ae9?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat3_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1551028719-00167b16eac5?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1507679799987-c73779587ccf?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat4_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1665716648155-da912213dfee?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1581176315870-55a852d16b56?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat5_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1595777457583-95e059d581b8?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1572804013309-59a88b7e92f1?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat6_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat7_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1571867424485-369464ed33cc?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat8_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1509631179647-0177331693ae?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat9_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1560769629-975ec94e6a86?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1607522370275-f14206abe5d3?auto=format&fit=crop&w=800&q=80'
  ];
  v_cat10_imgs text[] := ARRAY[
    'https://images.unsplash.com/photo-1520639888713-7851133b1ed0?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1614253429340-98120bd6d753?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?auto=format&fit=crop&w=800&q=80'
  ];

  s_idx int;
  p_idx int;
  cat_idx int;
  name_idx int;
  adj_idx int;
  img_idx int;
  v_prod_id uuid;
  v_prod_name text;
  v_prod_price numeric(12, 2);
  v_img1 text;
  v_img2 text;
  v_img3 text;
  v_is_footwear boolean;
BEGIN
  FOR s_idx IN 1..10 LOOP
    FOR p_idx IN 1..200 LOOP
      cat_idx := ((p_idx - 1) % 10) + 1;
      name_idx := (((p_idx - 1) / 10) % 5) + 1;
      adj_idx := ((p_idx + s_idx - 2) % 10) + 1;
      img_idx := ((p_idx + s_idx - 2) % 3) + 1;

      CASE cat_idx
        WHEN 1 THEN
          v_prod_name := v_cat1_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat1_imgs[img_idx];
          v_img2 := v_cat1_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat1_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 2 THEN
          v_prod_name := v_cat2_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat2_imgs[img_idx];
          v_img2 := v_cat2_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat2_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 3 THEN
          v_prod_name := v_cat3_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat3_imgs[img_idx];
          v_img2 := v_cat3_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat3_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 4 THEN
          v_prod_name := v_cat4_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat4_imgs[img_idx];
          v_img2 := v_cat4_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat4_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 5 THEN
          v_prod_name := v_cat5_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat5_imgs[img_idx];
          v_img2 := v_cat5_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat5_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 6 THEN
          v_prod_name := v_cat6_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat6_imgs[img_idx];
          v_img2 := v_cat6_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat6_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 7 THEN
          v_prod_name := v_cat7_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat7_imgs[img_idx];
          v_img2 := v_cat7_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat7_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 8 THEN
          v_prod_name := v_cat8_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat8_imgs[img_idx];
          v_img2 := v_cat8_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat8_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := false;
        WHEN 9 THEN
          v_prod_name := v_cat9_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat9_imgs[img_idx];
          v_img2 := v_cat9_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat9_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := true;
        ELSE
          v_prod_name := v_cat10_names[name_idx] || ' - ' || v_style_adjs[adj_idx] || ' #' || p_idx;
          v_img1 := v_cat10_imgs[img_idx];
          v_img2 := v_cat10_imgs[(img_idx % 3) + 1];
          v_img3 := v_cat10_imgs[((img_idx + 1) % 3) + 1];
          v_is_footwear := true;
      END CASE;

      v_prod_price := (79 + ((p_idx * 17 + s_idx * 13) % 280))::numeric(12, 2);

      INSERT INTO public.products (
        shop_id,
        category_id,
        name,
        description,
        details,
        price,
        status,
        created_at,
        updated_at
      )
      VALUES (
        v_shop_ids[s_idx],
        v_cat_ids[cat_idx],
        v_prod_name,
        'قطعة أصلية بجودة عالية وتصميم عصري يناسب الاستخدام اليومي والمناسبات. خامات مريحة ومتينة مع تشطيب متقن ومقاسات قياسية مضمونة.',
        jsonb_build_object(
          'brand', 'Shopy Collection',
          'material', CASE WHEN v_is_footwear THEN 'جلد ونعل مطاطي مريح' ELSE 'قطن وألياف طبيعية فاخرة' END,
          'fit', 'قصة قياسية مريحة (Regular Fit)',
          'origin', 'تركيا',
          'care', CASE WHEN v_is_footwear THEN 'ينظف بقطعة قماش مبللة' ELSE 'غسيل بدرجة حرارة 30 مئوية' END,
          'sku', 'SHP-' || lpad(s_idx::text, 2, '0') || '-' || lpad(p_idx::text, 3, '0')
        ),
        v_prod_price,
        'published',
        now() - ((200 - p_idx) || ' minutes')::interval,
        now() - ((200 - p_idx) || ' minutes')::interval
      )
      RETURNING id INTO v_prod_id;

      -- إدخال المقاسات والألوان (Variants)
      IF v_is_footwear THEN
        INSERT INTO public.product_variants (product_id, color, size, stock, sku, is_active)
        VALUES
          (v_prod_id, 'أسود', '40', 10, 'SKU-' || s_idx || '-' || p_idx || '-1', true),
          (v_prod_id, 'أسود', '41', 15, 'SKU-' || s_idx || '-' || p_idx || '-2', true),
          (v_prod_id, 'أسود', '42', 18, 'SKU-' || s_idx || '-' || p_idx || '-3', true),
          (v_prod_id, 'أبيض', '42', 12, 'SKU-' || s_idx || '-' || p_idx || '-4', true),
          (v_prod_id, 'بني', '43', 14, 'SKU-' || s_idx || '-' || p_idx || '-5', true),
          (v_prod_id, 'رمادي', '44', 9,  'SKU-' || s_idx || '-' || p_idx || '-6', true);
      ELSE
        INSERT INTO public.product_variants (product_id, color, size, stock, sku, is_active)
        VALUES
          (v_prod_id, 'أسود', 'S',  12, 'SKU-' || s_idx || '-' || p_idx || '-1', true),
          (v_prod_id, 'أسود', 'M',  20, 'SKU-' || s_idx || '-' || p_idx || '-2', true),
          (v_prod_id, 'أسود', 'L',  16, 'SKU-' || s_idx || '-' || p_idx || '-3', true),
          (v_prod_id, 'أبيض', 'M',  14, 'SKU-' || s_idx || '-' || p_idx || '-4', true),
          (v_prod_id, 'كحلي', 'L',  15, 'SKU-' || s_idx || '-' || p_idx || '-5', true),
          (v_prod_id, 'بيج',  'XL', 10, 'SKU-' || s_idx || '-' || p_idx || '-6', true);
      END IF;

      -- إدخال صور المعرض والتجربة الافتراضية (Product Images)
      INSERT INTO public.product_images (product_id, file_path, kind, sort_order)
      VALUES
        (v_prod_id, v_img1, 'gallery', 0),
        (v_prod_id, v_img2, 'gallery', 1),
        (v_prod_id, v_img3, 'gallery', 2),
        (v_prod_id, v_img1, 'ar', 0);
    END LOOP;
  END LOOP;
END $$;

COMMIT;

