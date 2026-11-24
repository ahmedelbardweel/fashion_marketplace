class AppLang {
  AppLang._();

  /// Whether English (`en`) is currently active.
  static bool isEn = false;

  /// Translates [input] from Arabic to English when [isEn] is true.
  static String tr(String input) {
    if (!isEn || input.isEmpty) return input;

    final exact = _exact[input];
    if (exact != null) return exact;

    final trimmed = input.trim();
    final exactTrimmed = _exact[trimmed];
    if (exactTrimmed != null) return exactTrimmed;

    return _translateDynamic(input);
  }

  static String _translateDynamic(String s) {
    // Parameterized patterns
    for (final rule in _patterns) {
      final match = rule.pattern.firstMatch(s);
      if (match != null) {
        return rule.builder(match);
      }
    }

    // Fallback phrase replacements for composite strings
    var out = s;
    for (final entry in _phrases.entries) {
      if (out.contains(entry.key)) {
        out = out.replaceAll(entry.key, entry.value);
      }
    }
    return out;
  }

  static final List<_PatternRule> _patterns = [
    _PatternRule(
      RegExp(r'^جارٍ استئناف التجربة تلقائياً… \((\d+)/(\d+)\)$'),
      (m) => 'Resuming try-on automatically… (${m[1]}/${m[2]})',
    ),
    _PatternRule(
      RegExp(r'^تعذر تجهيز جلسة التجربة من الخادم \(HTTP (\d+)\)\.$'),
      (m) => 'Unable to prepare try-on session from server (HTTP ${m[1]}).',
    ),
    _PatternRule(
      RegExp(r'^(.+) \(رمز الخطأ: ([A-Za-z0-9]+)\)$'),
      (m) => '${AppLang.tr(m[1]!)} (Error code: ${m[2]})',
    ),
    _PatternRule(
      RegExp(r'^مدة كل جلسة: (\d+) ثانية · الحد اليومي: (\d+) محاولات$'),
      (m) => 'Session duration: ${m[1]}s · Daily limit: ${m[2]} tries per day',
    ),
    _PatternRule(
      RegExp(r'^متبقي (\d+) من (\d+) محاولات اليوم · (\d+) ثانية$'),
      (m) => '${m[1]} of ${m[2]} tries left today · ${m[3]}s per session',
    ),
    _PatternRule(
      RegExp(
        r'^استنفدت محاولاتك اليومية للتجربة \((\d+) محاولات\)\. يمكنك التجربة مجدداً غداً\.$',
      ),
      (m) =>
          'You have used all ${m[1]} daily try-on attempts. Please try again tomorrow.',
    ),
    _PatternRule(
      RegExp(
        r'^استهلكت جميع محاولاتك اليومية لتجربة الملابس \((\d+) محاولات\)\. ستعود محاولاتك تلقائياً غداً!$',
      ),
      (m) =>
          'You\'ve used all ${m[1]} try-on attempts for today. Your attempts will refresh automatically tomorrow!',
    ),
    _PatternRule(
      RegExp(
        r'^انتهت مدة التجربة المحددة \((\d+) ثانية\)\. تم إغلاق الكاميرا تلقائياً\.$',
      ),
      (m) =>
          'Your ${m[1]}-second try-on session ended. Camera has been turned off automatically.',
    ),
    _PatternRule(
      RegExp(r'^المتبقي لك اليوم: (\d+) من (\d+) محاولات$'),
      (m) => 'Remaining today: ${m[1]} of ${m[2]} attempts',
    ),
    _PatternRule(
      RegExp(r'^عرض (\d+) من (\d+)$'),
      (m) => 'Showing ${m[1]} of ${m[2]}',
    ),
    _PatternRule(
      RegExp(r'^إجمالي النتائج: (\d+)$'),
      (m) => 'Total results: ${m[1]}',
    ),
    _PatternRule(RegExp(r'^النتائج: (\d+)$'), (m) => 'Results: ${m[1]}'),
    _PatternRule(
      RegExp(r'^عرض المزيد \((\d+) منتجات\)$'),
      (m) => 'Load more (${m[1]} products)',
    ),
    _PatternRule(
      RegExp(r'^تم عرض جميع النتائج \((\d+)\)$'),
      (m) => 'All ${m[1]} results shown',
    ),
    _PatternRule(
      RegExp(r'^السعر: من ([\d.]+) إلى ([\d.]+)$'),
      (m) => 'Price: ₪${m[1]} - ₪${m[2]}',
    ),
    _PatternRule(
      RegExp(r'^السعر: من ([\d.]+)$'),
      (m) => 'Price: from ₪${m[1]}',
    ),
    _PatternRule(
      RegExp(r'^السعر: حتى ([\d.]+)$'),
      (m) => 'Price: up to ₪${m[1]}',
    ),
    _PatternRule(
      RegExp(r'^الإجمالي: من ([\d.]+) إلى ([\d.]+)$'),
      (m) => 'Total: ₪${m[1]} - ₪${m[2]}',
    ),
    _PatternRule(
      RegExp(r'^الإجمالي: من ([\d.]+)$'),
      (m) => 'Total: from ₪${m[1]}',
    ),
    _PatternRule(
      RegExp(r'^الإجمالي: حتى ([\d.]+)$'),
      (m) => 'Total: up to ₪${m[1]}',
    ),
    _PatternRule(
      RegExp(r'^هل أنت متأكد من إلغاء الطلب (.+)؟$'),
      (m) => 'Are you sure you want to cancel order ${m[1]}?',
    ),
    _PatternRule(
      RegExp(r'^هل أنت متأكد من حذف "(.+)"؟ لن يظهر للعملاء بعد الحذف\.$'),
      (m) =>
          'Are you sure you want to delete "${m[1]}"? It will no longer appear to customers.',
    ),
    _PatternRule(RegExp(r'^(\d+)٪ مكتمل$'), (m) => '${m[1]}% complete'),
    _PatternRule(
      RegExp(r'^المرحلة (\d+): (.+)$'),
      (m) => 'Step ${m[1]}: ${AppLang.tr(m[2]!)}',
    ),
    _PatternRule(
      RegExp(r'^نطاق صحيح بين (.+) و(.+)$'),
      (m) => 'Enter a valid range between ${m[1]} and ${m[2]}',
    ),
    _PatternRule(
      RegExp(r'^هل توافق على تفعيل خصم (\d+)% على هذا المنتج؟$'),
      (m) => 'Confirm applying a ${m[1]}% discount to this product?',
    ),
    _PatternRule(RegExp(r'^متبقي (\d+) أيام$'), (m) => '${m[1]} days left'),
    _PatternRule(RegExp(r'^متبقي (\d+) ساعات$'), (m) => '${m[1]} hours left'),
    _PatternRule(
      RegExp(r'^عروض (.+) — خصم حتى (\d+)%$'),
      (m) => '${m[1]} Offers — Up to ${m[2]}% Off',
    ),
    _PatternRule(
      RegExp(r'^(\d+) منتجات عليها عروض حالياً — تصفح المحل الآن$'),
      (m) => '${m[1]} products on offer now — Browse shop',
    ),
    _PatternRule(
      RegExp(r'^عروض مميزة لفترة محدودة في (.+) — تصفح المحل الآن$'),
      (m) => 'Limited-time offers at ${m[1]} — Browse shop',
    ),
    _PatternRule(
      RegExp(r'^التقييم: (\d+)\+ نجوم$'),
      (m) => 'Rating: ${m[1]}+ stars',
    ),
    _PatternRule(RegExp(r'^(\d+)★ فأعلى$'), (m) => '${m[1]}★ & up'),
    _PatternRule(RegExp(r'^(\d+) نجوم$'), (m) => '${m[1]} stars'),
    _PatternRule(RegExp(r'^المقاس: (.+)$'), (m) => 'Size: ${m[1]}'),
    _PatternRule(RegExp(r'^اللون: (.+)$'), (m) => 'Color: ${m[1]}'),
    _PatternRule(RegExp(r'^المتجر: (.+)$'), (m) => 'Shop: ${m[1]}'),
    _PatternRule(RegExp(r'^التصنيف: (.+)$'), (m) => 'Category: ${m[1]}'),
    _PatternRule(RegExp(r'^المدينة: (.+)$'), (m) => 'City: ${m[1]}'),
    _PatternRule(RegExp(r'^أقل من ([\d.]+)$'), (m) => 'Under ₪${m[1]}'),
    _PatternRule(RegExp(r'^أكثر من ([\d.]+)$'), (m) => 'Over ₪${m[1]}'),
    _PatternRule(
      RegExp(r'^([\d.]+)\s*-\s*([\d.]+)$'),
      (m) => '₪${m[1]} - ₪${m[2]}',
    ),
    _PatternRule(
      RegExp(r'^إتمام الشراء \((\d+)\)$'),
      (m) => 'Checkout (${m.group(1)})',
    ),
    _PatternRule(
      RegExp(r'^ملخص الطلب \((\d+)\)$'),
      (m) => 'Order Summary (${m.group(1)})',
    ),
    _PatternRule(
      RegExp(r'^القطع المشتراة \((\d+)\)$'),
      (m) => 'Purchased Items (${m.group(1)})',
    ),
    _PatternRule(RegExp(r'^(\d+) قطع$'), (m) => '${m.group(1)} items'),
    _PatternRule(RegExp(r'^(\d+) قطعة$'), (m) => '${m.group(1)} pcs'),
    _PatternRule(
      RegExp(r'^متبقي (\d+) فقط$'),
      (m) => 'Only ${m.group(1)} left',
    ),
    _PatternRule(
      RegExp(r'^تقييمات المشترين \((\d+)\)$'),
      (m) => 'Customer Reviews (${m.group(1)})',
    ),
    _PatternRule(
      RegExp(r'^تقييمات وآراء المشترين \((\d+)\)$'),
      (m) => 'Customer Reviews (${m.group(1)})',
    ),
    _PatternRule(
      RegExp(r'^اضغط لقراءة (\d+) تقييم أو كتابة تقييمك$'),
      (m) => 'Tap to read ${m.group(1)} reviews or write yours',
    ),
    _PatternRule(
      RegExp(r'^([\d.]+) \((\d+) تقييم\)$'),
      (m) => '${m.group(1)} (${m.group(2)} reviews)',
    ),
    _PatternRule(
      RegExp(r'^إضافة إلى السلة · (.+)$'),
      (m) => 'Add to Cart · ${tr(m.group(1)!)}',
    ),
    _PatternRule(
      RegExp(r'^إضافة مقاس \((.+)\) للسلة$'),
      (m) => 'Add Size (${m.group(1)}) to Cart',
    ),
    _PatternRule(
      RegExp(r'^تمت إضافة مقاس \((.+)\) بنجاح إلى سلتك!$'),
      (m) => 'Size (${m.group(1)}) added to your cart!',
    ),
    _PatternRule(
      RegExp(r'^تم تحديد (\d+) منتجات للمقارنة$'),
      (m) => '${m.group(1)} products selected for comparison',
    ),
    _PatternRule(
      RegExp(r'^تم تحديد الجسم \(المقاس: (.+)\)$'),
      (m) => 'Body detected (Size: ${m.group(1)})',
    ),
    _PatternRule(RegExp(r'^طلب #(.+)$'), (m) => 'Order #${m.group(1)}'),
    _PatternRule(
      RegExp(r'^الطلب الحالي: (.+)$'),
      (m) => 'Current Order: ${tr(m.group(1)!)}',
    ),
    _PatternRule(RegExp(r'^المتجر: (.+)$'), (m) => 'Shop: ${m.group(1)}'),
    _PatternRule(RegExp(r'^المحل: (.+)$'), (m) => 'Shop: ${m.group(1)}'),
    _PatternRule(RegExp(r'^الكمية: (\d+)$'), (m) => 'Qty: ${m.group(1)}'),
    _PatternRule(RegExp(r'^المواصفات: (.+)$'), (m) => 'Specs: ${m.group(1)}'),
    _PatternRule(RegExp(r'^المقاس: (.+)$'), (m) => 'Size: ${m.group(1)}'),
    _PatternRule(RegExp(r'^بحث: (.+)$'), (m) => 'Search: ${m.group(1)}'),
    _PatternRule(RegExp(r'^السعر: (.+)$'), (m) => 'Price: ${m.group(1)}'),
    _PatternRule(
      RegExp(r'^تاريخ الإنشاء: (.+)$'),
      (m) => 'Created: ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^الخطوة (\d+) من (\d+)$'),
      (m) => 'Step ${m.group(1)} of ${m.group(2)}',
    ),
    _PatternRule(
      RegExp(r'^المرحلة (\d+): (.+)$'),
      (m) => 'Step ${m.group(1)}: ${tr(m.group(2)!)}',
    ),
    _PatternRule(RegExp(r'^التالي: (.+)$'), (m) => 'Next: ${tr(m.group(1)!)}'),
    _PatternRule(RegExp(r'^تعديل (.+)$'), (m) => 'Edit ${tr(m.group(1)!)}'),
    _PatternRule(RegExp(r'^صورة (\d+)$'), (m) => 'Image ${m.group(1)}'),
    _PatternRule(RegExp(r'^(\d+)٪ مكتمل$'), (m) => '${m.group(1)}% complete'),
    _PatternRule(
      RegExp(r'^(.+) مطلوب$'),
      (m) => '${tr(m.group(1)!)} is required',
    ),
    _PatternRule(
      RegExp(r'^([\d.]+)\s*(?:₪|شيكل|ر\.س)$'),
      (m) => '₪${m.group(1)}',
    ),
  ];

  static const Map<String, String> _phrases = {
    'تعذر تحميل المنتجات:': 'Failed to load products:',
    'تعذر تحميل المتاجر:': 'Failed to load shops:',
    'تعذر تحميل المتجر:': 'Failed to load shop:',
    'تعذر تحميل الطلبات:': 'Failed to load orders:',
    'تعذر تحميل تفاصيل الطلب:': 'Failed to load order details:',
    'تعذر تحميل المفضلة:': 'Failed to load favorites:',
    'تعذر تحميل الإشعارات:': 'Failed to load notifications:',
    'حدث خطأ:': 'Error:',
    'ر.س': '₪',
    'شيكل': '₪',
    'خيارات': 'variants',
    'قطعة متاحة': 'pcs available',
    'قطعة': 'pcs',
    'صور': 'images',
    'مستندات': 'docs',
    'المخزون:': 'Stock:',
    'الحالة:': 'Status:',
    'التصنيف:': 'Category:',
    'الطلبات:': 'Orders:',
    'المنتجات:': 'Products:',
    'المستخدمون:': 'Users:',
    'المحلات:': 'Shops:',
    'التصنيفات:': 'Categories:',
    'بانتظار المراجعة:': 'Pending review:',
    'طلبات قيد المعالجة:': 'Processing orders:',
    'منتجات منشورة:': 'Published products:',
    'وحدات المخزون:': 'Stock units:',
    'طلبات الانضمام المعلقة:': 'Pending shop applications:',
    'المحلات المعلقة:': 'Suspended shops:',
    'الإشعارات المرسلة:': 'Sent notifications:',
  };

  static const Map<String, String> _exact = {
    'بحث...': 'Search...',
    'مسح البحث': 'Clear search',
    'فلترة': 'Filter',
    'ترتيب النتائج': 'Sort Results',
    'عرض النتائج': 'Show Results',
    'لا توجد نتائج مطابقة': 'No matching results',
    'جرّب تعديل كلمات البحث أو مسح بعض الفلاتر لعرض المزيد.':
        'Try adjusting your search keywords or clearing some filters.',
    'من': 'From',
    'إلى': 'To',
    'الأحدث': 'Newest',
    'الأقدم': 'Oldest',
    'السعر: الأقل أولاً': 'Price: Low to High',
    'السعر: الأعلى أولاً': 'Price: High to Low',
    'الأعلى تقييماً': 'Top Rated',
    'الأقل تقييماً': 'Lowest Rated',
    'الاسم: أ - ي': 'Name: A - Z',
    'أبجدياً: أ - ي': 'Alphabetical: A - Z',
    'أبجدياً: ي - أ': 'Alphabetical: Z - A',
    'الترتيب الافتراضي': 'Default Order',
    'الأقل مخزوناً': 'Lowest Stock',
    'الأكثر توفراً': 'Highest Stock',
    'الأعلى قيمة': 'Highest Total',
    'الأقل قيمة': 'Lowest Total',
    'الأكثر منتجات': 'Most Products',
    'الافتراضي': 'Default',
    'اليوم': 'Today',
    'آخر 7 أيام': 'Last 7 Days',
    'آخر 30 يوماً': 'Last 30 Days',
    'متوفر': 'In Stock',
    'مخزون منخفض': 'Low Stock',
    'متوفر فقط': 'In Stock Only',
    'المتوفر في المخزون فقط': 'Show in-stock items only',
    'إخفاء المنتجات غير المتوفرة حالياً':
        'Hide items that are currently out of stock',
    'نشط': 'Active',
    'معطّل': 'Inactive',
    'مكتمل': 'Completed',
    'غير مكتمل': 'Incomplete',
    'نطاق السعر': 'Price Range',
    'التقييم': 'Rating',
    'نطاق الإجمالي': 'Total Range',
    'الفترة الزمنية': 'Date Range',
    'حالة المخزون': 'Stock Status',
    'الحالة': 'Status',
    'الدور': 'Role',
    'اكتمال الملف': 'Profile Status',
    'الجمهور': 'Audience',
    'متاجر لديها منتجات فقط': 'Shops with products only',
    'عرض المتاجر التي نشرت منتجات فقط': 'Only show shops that have products',
    'مع تعليق فقط': 'With Comment Only',
    'تقييمات تحتوي على تعليق نصي فقط':
        'Only reviews that include text comments',
    'بحث في الكتالوج، الماركة، اللون...': 'Search catalog, brand, color...',
    'ابحث في تشكيلة المتجر، اللون، المقاس...':
        'Search shop collection, color, size...',
    'ابحث باسم المتجر، المدينة، الوصف...':
        'Search shop name, city, description...',
    'ابحث برقم الطلب، المتجر، اسم المنتج...': 'Search order #, shop, item...',
    'ابحث في المفضلة، المتجر، اللون...': 'Search favorites, shop, color...',
    'ابحث في الإشعارات...': 'Search notifications...',
    'ابحث باسم المنتج، المتجر، اللون...': 'Search product, shop, color...',
    'ابحث برقم الطلب، العميل، البريد...': 'Search order #, customer, email...',
    'ابحث باسم المنتج، المتجر، التصنيف...': 'Search product, shop, category...',
    'ابحث برقم الطلب، المتجر، العميل...': 'Search order #, shop, customer...',
    'ابحث باسم المتجر، المالك، المدينة، السجل...':
        'Search shop, owner, city, CR...',
    'ابحث بالاسم، البريد، الهاتف، المدينة...':
        'Search name, email, phone, city...',
    'ابحث باسم التصنيف أو المعرف...': 'Search category name or slug...',
    'ابحث في عنوان البنر أو الوصف...': 'Search banner title or subtitle...',
    'منشور': 'Published',
    'مسودة': 'Draft',
    'مخفي': 'Hidden',
    'مقبول': 'Approved',
    'مرفوض': 'Rejected',
    'معلق': 'Suspended',
    'صاحب متجر': 'Shop Owner',
    'الكل (العملاء والمتاجر)': 'All (Customers & Shops)',
    'العملاء': 'Customers',
    'أصحاب المتاجر': 'Shop Owners',
    'عرض الكل في الكتالوج': 'View All in Catalog',
    '5 نجوم': '5 Stars',
    '4 نجوم': '4 Stars',
    '3 نجوم': '3 Stars',
    'نجمتان': '2 Stars',
    'نجمة واحدة': '1 Star',
    'تصفية المفضلة': 'Filter Favorites',
    'تصفية المتاجر': 'Filter Shops',
    'تصفية الطلبات': 'Filter Orders',
    'تصفية المستخدمين': 'Filter Users',
    'تصفية الإشعارات': 'Filter Notifications',
    // --- Body zone selection ---
    'اختر منطقة التجربة': 'Choose your try-on area',
    'المس منطقة على الجسم أو اختر من الخيارات أدناه.':
        'Tap a body area or choose an option below.',
    'القطعة المختارة': 'Selected item',
    'منظر أمامي': 'Front view',
    'دليل مناطق الجسم': 'Body area guide',
    'الجزء العلوي': 'Upper body',
    'شورت': 'Shorts',
    'طقم كامل / فستان': 'Full outfit / dress',
    'الأحذية': 'Footwear',
    'ابدأ التجربة': 'Start try-on',
    'وجّه الكاميرا ليظهر الجزء العلوي والكتفين في إضاءة واضحة.':
        'Keep your upper body and shoulders visible in good light.',
    'وجّه الكاميرا نحو منطقة الخصر والرجلين في إضاءة واضحة.':
        'Keep your waist and legs visible in good light.',
    'وجّه الكاميرا نحو الخصر والركبتين في إضاءة واضحة.':
        'Keep your waist and knees visible in good light.',
    'قف أمام الكاميرا ليظهر الجسم في إضاءة واضحة.':
        'Stand in front of the camera with your body visible in good light.',
    'وجّه الكاميرا نحو القدمين والكاحلين في إضاءة واضحة.':
        'Keep your feet and ankles visible in good light.',
    // --- App & Navigation ---
    'ملابسي': 'وصلة',
    'وصلة': 'وصلة',
    'أو': 'OR',
    'المتابعة باستخدام Google': 'Continue with Google',
    'تعذر تسجيل الدخول عبر Google': 'Failed to sign in with Google',
    'يرجى إضافة GOOGLE_WEB_CLIENT_ID في ملف .env لتفعيل الدخول المباشر عبر Google':
        'Please add GOOGLE_WEB_CLIENT_ID in .env to enable native Google sign-in',
    'تأكد من إضافة بصمة SHA-1 و Web Client ID في إعدادات Google Cloud Console':
        'Ensure SHA-1 fingerprint and Web Client ID are configured in Google Cloud Console',
    'تعذر الحصول على رمز المصادقة (ID Token) من Google. تأكد من صحة GOOGLE_WEB_CLIENT_ID':
        'Failed to get ID Token from Google. Verify GOOGLE_WEB_CLIENT_ID',
    'السوق العصري': 'Modern Market',
    'الرئيسية': 'Home',
    'المنتجات': 'Products',
    'الكتالوج': 'Catalog',
    'المفضلة': 'Favorites',
    'طلباتي': 'My Orders',
    'حسابي': 'Profile',
    'الملف الشخصي': 'Profile',
    'سلة المشتريات': 'Shopping Cart',
    'الإشعارات': 'Notifications',
    'الإعدادات': 'Settings',
    'الطلبات': 'Orders',
    'المتجر': 'Shop',
    'المتاجر المعتمدة': 'Verified Shops',
    'المحلات': 'Shops',
    'أحدث الأزياء': 'Latest Fashion',
    'تصفح الكل': 'Browse All',
    'عرض الكل': 'View All',
    'عرض خاص': 'Special Offer',
    'تسوق الآن': 'Shop Now',
    'بحث': 'Search',
    'إغلاق البحث': 'Close search',
    'مسح': 'Clear',
    'مسح الكل': 'Clear All',
    'رجوع': 'Back',
    'إلغاء': 'Cancel',
    'حفظ': 'Save',
    'تأكيد': 'Confirm',
    'تعديل': 'Edit',
    'حذف': 'Delete',
    'إرسال': 'Send',
    'الكل': 'All',
    'الجميع': 'Everyone',
    'نشر': 'Publish',
    'مجاناً': 'Free',
    'ع': 'U',

    // --- Common Seeded Categories & Banners ---
    'هودي': 'Hoodies',
    'بلوزة': 'Blouses',
    'قمصان': 'Shirts',
    'قميص': 'Shirt',
    'فساتين': 'Dresses',
    'فستان': 'Dress',
    'بناطيل': 'Pants',
    'بنطلون': 'Pants',
    'جاكيتات': 'Jackets',
    'جاكيت': 'Jacket',
    'عبايات': 'Abayas',
    'عباية': 'Abaya',
    'أحذية': 'Shoes',
    'تيشيرت': 'T-Shirts',
    'تي شيرت': 'T-Shirts',
    'ملابس رياضية': 'Sportswear',
    'ملابس رجالية': 'Men Fashion',
    'ملابس نسائية': 'Women Fashion',
    'إكسسوارات': 'Accessories',
    'ملابس': 'Clothing',
    'حقائب': 'Bags',
    'إلكترونيات': 'Electronics',
    'عطور وتجميل': 'Perfumes & Beauty',
    'تيشيرتات': 'T-Shirts',
    'ملابس أطفال': 'Kids Wear',
    'سنيكرز': 'Sneakers',
    'أحذية رسمية': 'Formal Shoes',
    'بوتات': 'Boots',
    'صنادل': 'Sandals',
    'ساعات': 'Watches',
    'نظارات': 'Eyewear',
    'مجوهرات': 'Jewelry',
    'أحزمة': 'Belts',
    'حقائب يد': 'Handbags',
    'حقائب ظهر': 'Backpacks',
    'حقائب سفر': 'Travel Bags',
    'محافظ': 'Wallets',
    'هواتف': 'Phones',
    'سماعات': 'Audio',
    'ساعات ذكية': 'Smartwatches',
    'شواحن': 'Chargers',
    'عطور': 'Perfumes',
    'مكياج': 'Makeup',
    'عناية بالبشرة': 'Skincare',
    'عناية بالشعر': 'Haircare',
    'تشكيلة الصيف الجديدة': 'New Summer Collection',
    'خصومات تصل إلى 40% على أحدث الأزياء العصرية':
        'Up to 40% off on the latest modern fashion',
    'جرّب ملابسك افتراضياً قبل الشراء':
        'Try on your clothes virtually before buying',
    'تقنية الذكاء الاصطناعي تمنحك تجربة قياس مباشرة بالكاميرا':
        'AI technology gives you a live camera try-on experience',
    'أرقى المتاجر المحلية في مكان واحد': 'Top Local Boutiques in One Place',
    'تسوق من متاجر معتمدة مع توصيل سريع لباب منزلك':
        'Shop from verified stores with fast doorstep delivery',

    // --- Profile & Settings ---
    'عميل المتجر': 'Store Customer',
    'عميل': 'Customer',
    'إعدادات الحساب والتطبيق': 'Account & App Settings',
    'تعديل البيانات وعنوان التوصيل': 'Edit Profile & Delivery Address',
    'الاسم، رقم الهاتف، المدينة، والعنوان التفصيلي':
        'Name, phone number, city, and detailed address',
    'مظهر التطبيق': 'App Appearance',
    'مظهر التطبيق (الوضع الليلي / النهاري)': 'App Theme (Dark / Light Mode)',
    'الوضع النهاري (Light Mode)': 'Light Mode',
    'الوضع الليلي (Dark Mode)': 'Dark Mode',
    'خلفية فاتحة ومريحة للإضاءة العالية':
        'Bright clean surface ideal for daylight',
    'ألوان داكنة مريحة للعين في الإضاءة الخافتة':
        'Pure black dark theme comfortable for low light',
    'لغة التطبيق': 'App Language',
    'العربية': 'العربية (Arabic)',
    'اللغة الافتراضية للتطبيق (RTL)': 'Arabic interface (RTL)',
    'تم اختيار اللغة العربية': 'Switched language to Arabic',
    'إدارة الحساب': 'Account Management',
    'تسجيل الخروج': 'Sign Out',
    'الخروج من حسابك الحالي على هذا الجهاز':
        'Sign out from your account on this device',
    'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟':
        'Are you sure you want to sign out of your account?',
    'هل تريد تسجيل الخروج من الحساب؟': 'Do you want to sign out?',
    'هل تريد تسجيل الخروج من حساب المحل؟':
        'Do you want to sign out of the shop account?',
    'هل تريد تسجيل الخروج من لوحة الإدارة؟':
        'Do you want to sign out of the admin panel?',
    'حذف الحساب': 'Delete Account',
    'حذف الحساب نهائياً': 'Delete Account Permanently',
    'إيقاف الحساب وحذف جميع البيانات نهائياً':
        'Deactivate account and permanently remove personal data',
    'سيتم إيقاف حسابك وحذف بياناتك الشخصية ولن تتمكن من استعادتها مرة أخرى.':
        'Your account will be deactivated and your personal data removed permanently.',
    'تأكيد حذف الحساب': 'Confirm Account Deletion',
    'جاري حذف الحساب...': 'Deleting account...',
    'تعذر حذف الحساب حالياً، حاول مرة أخرى':
        'Could not delete account right now, please try again',
    'البيانات وعنوان التوصيل': 'Profile & Delivery Address',
    'الاسم الكامل': 'Full Name',
    'الاسم': 'Name',
    'رقم الهاتف': 'Phone Number',
    'الهاتف': 'Phone',
    'المدينة': 'City',
    'العنوان التفصيلي': 'Detailed Address',
    'العنوان': 'Address',
    'حفظ التعديلات': 'Save Changes',
    'يرجى كتابة الاسم ورقم الهاتف': 'Please enter your name and phone number',
    'تم حفظ بيانات الملف الشخصي بنجاح': 'Profile updated successfully',
    'تعذر تحديث البيانات': 'Failed to update profile',
    'روابط سريعة': 'Quick Links',
    'سجل طلباتي ومشترياتي': 'My Orders & Purchases',
    'قائمة المفضلة': 'Wishlist',
    'مقارنة الملابس المختارة': 'Compare Selected Clothes',
    'الإشعارات والتحديثات': 'Notifications & Updates',

    // --- Auth & Onboarding ---
    'تسجيل الدخول': 'Sign In',
    'دخول': 'Sign In',
    'خروج': 'Sign Out',
    'أدخل بيانات حسابك للمتابعة إلى عالم الأزياء':
        'Enter your credentials to continue to the fashion world',
    'البريد الإلكتروني': 'Email Address',
    'البريد': 'Email',
    'كلمة المرور': 'Password',
    'تأكيد كلمة المرور': 'Confirm Password',
    'إنشاء حساب جديد': 'Create New Account',
    'إنشاء حساب': 'Create Account',
    'إنشاء الحساب': 'Create Account',
    'اختر نوع الحساب': 'Choose Account Type',
    'حدد طريقة استخدامك للتطبيق للمتابعة':
        'Choose how you want to use the app to continue',
    'حساب متسوق': 'Shopper Account',
    'تصفح الأزياء وتجربة الملابس والشراء':
        'Browse fashion, try on clothes virtually, and shop',
    'حساب متجر أزياء': 'Fashion Boutique Account',
    'تسجيل متجرك وعرض منتجاتك واستقبال الطلبات':
        'Register your store, list products, and receive orders',
    'لدي حساب بالفعل · تسجيل الدخول': 'Already have an account · Sign In',
    'أنشئ حسابك كمستخدم': 'Create Your Shopper Account',
    'ستتمكن من تصفح المنتجات والشراء بعد التسجيل':
        'You will be able to browse and purchase products after signing up',
    'تسجيل مستخدم': 'Register Shopper',
    'أنشئ حساب المحل': 'Create Boutique Account',
    'إنشاء حساب المحل': 'Create Boutique Account',
    'تسجيل محل': 'Register Shop',
    'اسم المسؤول': 'Manager Name',
    'اسم المحل': 'Shop Name',
    'اسم المتجر': 'Shop Name',
    'بعد التسجيل أكمل البيانات وأرسل طلب الانضمام. المنتجات غير متاحة قبل موافقة الإدارة.':
        'After registration, complete your shop profile and submit your application for admin approval.',
    'إكمال الملف الشخصي': 'Complete Profile',
    'أكمل بياناتك للمتابعة': 'Complete your details to continue',
    'هذه البيانات مطلوبة لاستخدام المتجر وإتمام الطلبات لاحقاً':
        'These details are required for shopping and order delivery',
    'حفظ والمتابعة': 'Save & Continue',
    'البريد الإلكتروني غير صالح': 'Invalid email address',
    'كلمة المرور غير مقبولة': 'Invalid password',
    'كلمة المرور يجب أن تكون 8 أحرف على الأقل':
        'Password must be at least 8 characters',
    'كلمة المرور يجب أن تحتوي على أحرف وأرقام':
        'Password must contain letters and numbers',
    '8 أحرف على الأقل مع أرقام': 'At least 8 characters with numbers',
    'كلمتا المرور غير متطابقتين': 'Passwords do not match',
    'الاسم قصير جداً': 'Name is too short',
    'اسم المحل قصير جداً': 'Shop name is too short',
    'رقم الهاتف غير صالح': 'Invalid phone number',
    'هذا الحقل': 'This field',
    'البريد أو كلمة المرور غير صحيحة': 'Incorrect email or password',
    'هذا البريد مسجل مسبقاً': 'This email is already registered',
    'يجب تأكيد البريد الإلكتروني أولاً': 'Please confirm your email first',
    'هذا الحساب موقوف. تواصل مع الإدارة':
        'This account is suspended. Contact support.',
    'فشل تسجيل الدخول': 'Sign in failed',
    'فشل إنشاء الحساب': 'Registration failed',
    'فشل إنشاء حساب المحل': 'Shop registration failed',
    'العودة لتسجيل الدخول': 'Back to Sign In',

    // --- Catalog, Search & Filters ---
    'جميع المنتجات': 'All Products',
    'تصفح المنتجات': 'Browse Products',
    'تصفية المنتجات': 'Filter Products',
    'تصفية وبحث متقدم': 'Advanced Search & Filters',
    'التصنيف': 'Category',
    'التصنيفات': 'Categories',
    'المقاس': 'Size',
    'اللون': 'Color',
    'نطاق السعر (₪)': 'Price Range (₪)',
    'نطاق السعر (ر.س)': 'Price Range (₪)',
    'سعر القطعة (₪) *': 'Item Price (₪) *',
    'سعر القطعة (ر.س) *': 'Item Price (₪) *',
    'غير محدد': 'Not specified',
    'الحد الأدنى': 'Minimum',
    'الحد الأقصى': 'Maximum',
    'تطبيق الفلترة': 'Apply Filters',
    'إعادة ضبط': 'Reset',
    'إعادة ضبط الفلاتر': 'Reset Filters',
    'لا توجد منتجات مطابقة': 'No matching products found',
    'جرّب تغيير كلمات البحث أو إعادة ضبط الفلاتر':
        'Try changing your search query or resetting filters',
    'لا توجد منتجات منشورة حالياً': 'No published products right now',
    'لا توجد محلات معتمدة حالياً': 'No verified shops right now',
    'لا توجد متاجر معتمدة حالياً': 'No verified shops right now',

    // --- Product Details, Reviews & Try-On ---
    'تفاصيل المنتج': 'Product Details',
    'تشكيلة المتجر': 'Shop Collection',
    'زيارة المتجر': 'Visit Shop',
    'يباع بواسطة': 'Sold by',
    'جرّبها': 'Try On',
    'جرب الملابس': 'Try On',
    'جرّبها عليك الآن': 'Try It On Now',
    'غرفة القياس الافتراضية المباشرة': 'Live Virtual Fitting Room',
    'شاهد كيف تبدو هذه القطعة عليك بالكاميرا مباشرة قبل الشراء':
        'See how this piece looks on you live with your camera before buying',
    'اختر اللون والمقاس': 'Select Color & Size',
    'الألوان المتاحة': 'Available Colors',
    'المقاسات المتاحة': 'Available Sizes',
    'مقاس موحد': 'One Size',
    'متوفر في المخزون': 'In Stock',
    'نفدت الكمية': 'Out of Stock',
    'نفدت الكمية حالياً': 'Currently Out of Stock',
    'وصلت للكمية المتاحة': 'Maximum available stock reached',
    'هذا المنتج غير متاح حالياً': 'This product is currently unavailable',
    'الوصف': 'Description',
    'المواصفات والخامة والعناية': 'Specifications, Fabric & Care',
    'الماركة': 'Brand',
    'الخامة': 'Material',
    'الخامة وتركيبة القماش': 'Fabric & Material Composition',
    'القَصّة': 'Fit',
    'بلد الصنع': 'Country of Origin',
    'العناية': 'Care Instructions',
    'طريقة العناية': 'Care Instructions',
    'تعليمات الغسيل والعناية': 'Washing & Care Instructions',
    'رمز المنتج': 'Product SKU',
    'الشحن والتوصيل': 'Shipping & Delivery',
    'ادفع نقداً أو عبر البطاقة عند استلام طلبك':
        'Pay with cash or card upon receiving your order',
    'آراء العملاء السابقة': 'Customer Reviews',
    'شاركنا تجربتك مع القطعة': 'Share your experience with this item',
    'عرض الكل وإضافة تقييم': 'View All & Add Review',
    'أضف تقييمك ورأيك في القطعة': 'Add Your Rating & Review',
    'اكتب رأيك وتجربتك مع المقاس والجودة والخامة...':
        'Write your thoughts on fit, quality, and fabric...',
    'إرسال التقييم': 'Submit Review',
    'تمت إضافة تقييمك بنجاح': 'Your review has been added',
    'تعذر إضافة التقييم': 'Could not add review',
    'لا توجد تقييمات بعد · كن أول من يقيّم هذه القطعة':
        'No reviews yet · Be the first to review this item',
    'لا توجد تقييمات لهذا المنتج بعد. كن أول من يقيّمه.':
        'No reviews for this product yet. Be the first to review it.',
    'منتجات قد تعجبك': 'You May Also Like',
    'إضافة للمقارنة': 'Add to Compare',
    'إزالة من المقارنة': 'Remove from Compare',
    'تمت الإضافة للمقارنة': 'Added to comparison',
    'تمت الإزالة من المقارنة': 'Removed from comparison',
    'الحد الأقصى للمقارنة هو 3 منتجات': 'Maximum 3 products can be compared',
    'فتح المقارنة': 'Open Comparison',
    'عرض المقارنة': 'View Comparison',
    'تمت إضافة القطعة إلى السلة': 'Item added to cart',
    'تمت إضافة القطعة إلى سلة المشتريات': 'Item added to shopping cart',
    'عرض السلة': 'View Cart',
    'تكبير الصورة': 'Zoom Image',

    // --- Favorites & Comparison ---
    'قائمة المفضلة فارغة': 'Your Wishlist is Empty',
    'احفظ الأزياء التي تنال إعجابك للرجوع إليها في أي وقت':
        'Save fashion pieces you love to revisit anytime',
    'تصفح الأزياء الآن': 'Browse Fashion Now',
    'مقارنة المنتجات': 'Product Comparison',
    'قائمة المقارنة فارغة': 'Comparison List is Empty',
    'أضف منتجين أو أكثر من صفحة المنتج للمقارنة جنباً إلى جنب':
        'Add 2 or more products from the product page to compare side by side',
    'تفريغ': 'Clear',

    // --- Cart & Checkout ---
    'سلة المشتريات فارغة': 'Your Shopping Cart is Empty',
    'السلة فارغة': 'Cart is Empty',
    'تصفح أحدث الأزياء وأضف القطع المفضلة إلى سلتك':
        'Browse the latest fashion and add your favorite items to the cart',
    'المجموع الفرعي': 'Subtotal',
    'التوصيل': 'Delivery',
    'الإجمالي النهائي': 'Total',
    'الإجمالي المدفوع': 'Total Paid',
    'المبلغ المطلوب دفعه': 'Amount Due',
    'إتمام الشراء': 'Checkout',
    'عنوان التوصيل والتواصل': 'Delivery Address & Contact',
    'رقم هاتف المستلم': 'Recipient Phone Number',
    'عنوان التوصيل التفصيلي (المدينة، الحي، الشارع)':
        'Detailed Delivery Address (City, District, Street)',
    'ملاحظات إضافية للتوصيل (اختياري)': 'Delivery Notes (Optional)',
    'طريقة الدفع': 'Payment Method',
    'الدفع عند الاستلام': 'Cash on Delivery',
    'تأكيد الطلب الآن': 'Place Order Now',
    'يرجى إدخال عنوان التوصيل ورقم الهاتف':
        'Please enter delivery address and phone number',
    'تم تأكيد طلبك بنجاح': 'Order Confirmed Successfully',
    'تم تأكيد طلبك وإرساله للمتجر بنجاح':
        'Your order has been placed and sent to the shop!',
    'سيتولى المتجر تجهيز ملابسك وشحنها إلى عنوانك في أقرب وقت.':
        'The shop will prepare your items and ship them to your address soon.',
    'متابعة الطلبات': 'Track My Orders',
    'متابعة تفاصيل الطلب': 'View Order Details',
    'تعذر إرسال الطلب': 'Failed to place order',

    // --- Orders & Order Details ---
    'طلبات معلقة': 'Active Orders',
    'طلبات سابقة': 'Past Orders',
    'لا توجد طلبات بعد': 'No Orders Yet',
    'لا توجد طلبات سابقة': 'No Past Orders',
    'عندما تشتري أي ملابس ستتمكن من تتبع شحنتها هنا فوراً':
        'When you purchase items, you can track your shipments here right away',
    'اضغط لعرض تفاصيل الطلب': 'Tap to view order details',
    'تفاصيل الطلب': 'Order Details',
    'الطلب غير موجود': 'Order not found',
    'حالة الطلب': 'Order Status',
    'مراحل توصيل الشحنة': 'Shipment Progress',
    'قيد الانتظار': 'Pending',
    'تم التأكيد': 'Confirmed',
    'مؤكد': 'Confirmed',
    'عنوان التوصيل': 'Delivery Address',
    'ملاحظات': 'Notes',
    'قيد التجهيز': 'Preparing',
    'تم الشحن': 'Shipped',
    'تم التوصيل': 'Delivered',
    'تم التسليم': 'Delivered',
    'ملغي': 'Cancelled',
    'تم استلام الطلب': 'Order Received',
    'المتجر يقوم بتجهيز وتغليف المقاسات والألوان المطلوبة':
        'The shop is preparing and packaging your selected sizes and colors',
    'تم الشحن مع مندوب التوصيل': 'Shipped with Courier',
    'الشحنة في طريقها إلى عنوانك المحدد':
        'Your shipment is on its way to your delivery address',
    'تم الاستلام والتسليم': 'Delivered & Received',
    'تم تسليم الملابس للمشتري بنجاح': 'Items delivered to buyer successfully',

    // --- Notifications ---
    'إشعارات الطلبات والتنبيهات': 'Order Updates & Alerts',
    'استلام التنبيهات وإرسال إشعارات للعملاء':
        'Receive alerts and send notifications to customers',
    'لا توجد إشعارات حالياً': 'No Notifications Yet',
    'لا توجد إشعارات جديدة': 'No New Notifications',
    'ستصلك هنا العروض الحصرية وتحديثات طلباتك':
        'Exclusive offers and order status updates will appear here',
    'إشعارات الهاتف': 'Push Notifications',
    'مفعّلة — تصلك التنبيهات والطلبات فوراً':
        'Enabled — receiving alerts and order updates instantly',
    'متوقفة مؤقتاً من التطبيق': 'Paused in app settings',
    'غير مسموحة — اضغط لتفعيل صلاحية الإشعارات':
        'Permission denied — tap to enable notifications',
    'فعّل الإشعارات لاستلام العروض وتحديثات الطلبات':
        'Enable notifications for offers and order updates',
    'تفعيل': 'Enable',
    'تم تفعيل الإشعارات بنجاح': 'Notifications enabled successfully',
    'يرجى السماح بالإشعارات من إعدادات الجهاز لتصلك التنبيهات':
        'Please allow notifications in device settings to receive alerts',
    'إرسال إشعار للعملاء': 'Send Notification to Customers',
    'عملاء المحل': 'Shop Customers',
    'جميع العملاء': 'All Customers',
    'سيصل الإشعار للعملاء الذين طلبوا من محلك سابقاً':
        'Will be sent to customers who previously ordered from your shop',
    'سيصل الإشعار كعرض عام لجميع عملاء التطبيق':
        'Will be sent as a broadcast offer to all app customers',
    'مرسل من محلك': 'Sent by your shop',
    'إشعاراتي المرسلة': 'Sent by Me',
    'من المتجر': 'From Shop',

    // --- Virtual Try-On ---
    'تجربة الملابس — Decart': 'Virtual Try-On — Decart',
    'غرفة التجربة': 'Fitting Room',
    'تجربة تبدأ بجسمك': 'Try-On Starts With Your Pose',
    'خطوات بسيطة لتجربة أوضح وأكثر ثباتاً.':
        'Simple steps for a clearer, more stable try-on.',
    'فحص الجسم': 'Body Scan',
    'التجهيز': 'Setup',
    'التجربة': 'Try-On',
    'معاينة القطعة على الجسم': 'Garment Preview on Body',
    'إضاءة': 'Lighting',
    'ضوء أمامك': 'Light in Front',
    'وضوح': 'Clarity',
    'شخص واحد': 'Single Person',
    'أنت وحدك في الصورة': 'Only You in Frame',
    'ثبات وضعية الجسم': 'Steady Pose',
    'بوضعيتك الطبيعية': 'Natural Posture',
    'الكتفان واضحان': 'Shoulders Visible',
    'منطقة القطعة': 'Garment Area',
    'المعالجة في منطقة القطعة فقط': 'Processing in Garment Region Only',
    'الصورة الأصلية': 'Original Camera',
    'صورتك الأصلية': 'Your Original View',
    'عرض القطعة': 'Show Garment',
    'إخفاء القطعة': 'Hide Garment',
    'اختيار قطعة': 'Select Garment',
    'قطعتك': 'Your Garment',
    'قطعتك، على مقاس صورتك': 'Your Garment, Fitted to You',
    'متابعة التجربة': 'Continue Try-On',
    'إعادة المحاولة': 'Retry',
    'قف أمام الكاميرا لتحديد الجسم...':
        'Stand in front of the camera to detect body...',
    'المقاس المناسب لك:': 'Recommended Size for You:',
    'مطابقة القياس بنجاح': 'Size Matched Successfully',
    'القطعة متناسقة تماماً مع قياسات جسمك! هل ترغب بإضافتها إلى سلتك؟':
        'This piece matches your body measurements! Would you like to add it to your cart?',

    // --- Shop & Admin Panels ---
    'لوحة المحل': 'Shop Dashboard',
    'لوحة الإدارة': 'Admin Dashboard',
    'إضافة منتج': 'Add Product',
    'تعديل منتج': 'Edit Product',
    'نشر المنتج': 'Publish Product',
    'حفظ كمسودة': 'Save as Draft',
    'المبيعات والأرباح': 'Sales & Revenue',
    'إجمالي المبيعات': 'Total Sales',
    'ملف المحل': 'Shop Profile',
    'بيانات المحل': 'Shop Details',
    'إحصائيات التطبيق': 'App Statistics',
    'طلبات الانضمام': 'Shop Applications',
    'إدارة المحلات': 'Manage Shops',
    'إدارة المستخدمين': 'Manage Users',
    'العروض والبنرات': 'Banners & Offers',
    'البنرات': 'Banners',
    'التقارير': 'Reports',
    'إعدادات المنصة': 'Platform Settings',
    'جاري تحميل المزيد...': 'Loading more...',
    'تعذر تحميل الدفعة التالية': 'Could not load the next batch',
    'عرض المزيد': 'Load more',

    // --- Onboarding (Customer & Shop) ---
    'للمتسوّق': 'Shopper',
    'للمتاجر': 'For Shops',
    'تخطي': 'Skip',
    'التالي': 'Next',
    'ابدأ التسوق': 'Start Shopping',
    'سجّل متجرك': 'Register Your Shop',
    'لدي حساب متجر بالفعل': 'Already have a shop account',
    'تم': 'Done',
    'إغلاق': 'Close',
    'جولة التطبيق': 'App Tour',
    'استعرض ميزات التسوق وتجربة الملابس': 'Explore shopping & try-on features',
    'جولة المتاجر': 'Shop Tour',
    'تصفح منظم': 'Curated Browse',
    'كل متاجرك المفضلة في مكان واحد': 'Your Favorite Stores in One Place',
    'تصفح أزياء المتاجر المعتمدة حسب القسم والنوع، واستخدم الفلاتر للوصول للمقاس والسعر المناسب بسهولة.':
        'Browse verified boutiques by category and type, and filter effortlessly by size, color, and price.',
    'قياس بالكاميرا': 'Live Camera Try-On',
    'جرّب القطعة قبل ما تطلبها': 'Try On Before You Order',
    'افتح الكاميرا من مكانك، اختر منطقة اللبس المناسبة، وشاهد كيف تبدو القطعة عليك مباشرة قبل الشراء.':
        'Open your camera from anywhere, choose the fit zone, and preview how the piece looks on you live.',
    'اختيار دقيق': 'Confident Choice',
    'اختر أدق بدون تردد': 'Pick With Confidence',
    'قارن حتى 3 منتجات جنباً إلى جنب، احفظ اختياراتك في المفضلة، واطلع على التقييمات والمقاسات المتوفرة.':
        'Compare up to 3 pieces side by side, save favorites, and check real reviews and stock.',
    'سلة وتتبع': 'Order & Tracking',
    'طلبك واضح من البداية للتسليم': 'Clear Tracking Until Delivery',
    'أتمم طلبك بخطوات سريعة وتابع تجهيزه وشحنه لحظة بلحظة — أو أنشئ حساب متجر واعرض منتجاتك.':
        'Check out quickly and track packing and delivery step by step — or join as a store.',
    'واجهة متجرك': 'Storefront Setup',
    'أنشئ واجهة متجرك بسهولة': 'Build Your Storefront Easily',
    'أضف اسم متجرك وشعارك وصور المعرض خلال دقائق — ونُجهّز خلفية الشعار تلقائياً ليظهر بأناقة في الرئيسية.':
        'Add your shop name, logo, and gallery in minutes — we clean your logo background automatically.',
    'إدارة الكتالوج': 'Catalog Studio',
    'أضف منتجاتك بصور صافية': 'Publish Crisp Product Cards',
    'ارفع صور القطع لتتجهّز بخلفية بيضاء نظيفة تلقائياً، وحدد التصنيف والألوان والمقاسات والكميات بدقة.':
        'Upload pieces onto clean studio backdrops and configure categories, colors, sizes, and stock.',
    'ثقة المشتري': 'Shopper Confidence',
    'عملاؤك يجرّبون القطعة قبل الطلب': 'Let Shoppers Try Pieces Live',
    'كل قطعة منشورة تدعم المعاينة المباشرة بالكاميرا والمقارنة، مما يمنح العميل ثقة أكبر ويرفع نسبة إتمام الطلب.':
        'Every published item supports live camera previews and comparison to boost buyer confidence.',
    'الطلبات والأرباح': 'Orders & Sales',
    'تابع طلباتك ومبيعاتك من مكان واحد': 'Manage Orders & Sales in One Place',
    'استقبل إشعارات الطلبات فورياً، حدّث حالة التجهيز والشحن والتسليم، وراقب مبيعاتك ومخزونك بوضوح.':
        'Get instant order alerts, update fulfillment status, and monitor sales and inventory.',
    'متجر معتمد': 'Verified Shop',
    'هودي قطن عصري': 'Modern Cotton Hoodie',
    'معاينة مباشرة على مقاسك': 'Live preview fitted to you',
    'جاكيت كاجوال': 'Casual Jacket',
    'هودي كلاسيك': 'Classic Hoodie',
    'قيد التجهيز الآن': 'Preparing now',
    'تجهيز': 'Packing',
    'شحن': 'Shipped',
    'تسليم': 'Delivered',
    'تريد البيع معنا؟ بدّل إلى تبويب «للمتاجر»':
        'Want to sell here? Switch to the "For Shops" tab',
    'متجرك المعتمد': 'Your Verified Shop',
    'الشعار + الغلاف + المعرض': 'Logo + Cover + Gallery',
    'تجهيز خلفية الشعار تلقائياً ليظهر بنظافة':
        'Logo background cleaned automatically',
    'صورة صافية': 'Clean Cutout',
    'ملابس · هودي': 'Clothing · Hoodies',
    'هودي شتوي مبطن': 'Fleece Winter Hoodie',
    'معاينة فورية للمشتري': 'Instant preview for buyers',
    'إشعار فوري لكل طلب جديد وتحديث سريع للحالة':
        'Instant new-order alerts & quick status updates',
    'قبل': 'Before',
    'بعد': 'After',
    'ملاءمة 98%': '98% Fit',
    'الأنسب لك': 'Best Match',
    'طلب جديد': 'New Order',
    'جديد': 'New',
    'مباشر': 'Live',
    'إعداد سريع': 'Quick Setup',
    'الخطوة 1 من 3': 'Step 1 of 3',
    'الخطوة 2 من 3': 'Step 2 of 3',
    'الخطوة 3 من 3': 'Step 3 of 3',
    'كيف تستخدم التطبيق؟': 'How will you use وصلة?',
    'اختر دورك لنجهّز لك التجربة والميزات المناسبة لك.':
        'Choose your role so we tailor the right experience for you.',
    'اختر لغة العرض واتجاه الواجهة المفضّلين لديك.':
        'Pick your preferred display language and layout direction.',
    'اختر الوضع المريح لعينيك ويمكنك تغييره لاحقاً.':
        'Pick the appearance most comfortable for your eyes anytime.',
    'متسوّق': 'Shopper',
    'متجر': 'Shop',
    'نهاري': 'Light',
    'ليلي': 'Dark',
    'صاحب محل': 'Shop Owner',
    'مثال توضيحي': 'Sample Preview',
    'تسجيل الدخول بجوجل': 'Sign in with Google',
    'سجّل دخولك بسرعة وأمان عبر حساب Google أو بريدك الإلكتروني.':
        'Sign in quickly and securely using Google or your email.',
    'اكتشاف المنتجات': 'Discover Products',
    'تصفّح التصنيفات وابحث باسم القطعة أو المتجر واستخدم الفلاتر للوصول لما يناسبك.':
        'Browse categories, search by item or shop, and apply filters easily.',
    'اختيار المنتج': 'Choose Your Piece',
    'اختر اللون والمقاس والكمية المناسبة ثم اضغط إضافة إلى السلة.':
        'Pick your color, size, and quantity, then tap Add to Cart.',
    'مراجعة السلة': 'Review Cart',
    'راجع القطع والكميات والمجموع في سلتك ثم اضغط إتمام الشراء.':
        'Check your selected items, quantities, and total, then proceed to checkout.',
    'إكمال الطلب': 'Complete Order',
    'أدخل رقم الهاتف وطريقة الدفع وتأكد من الملخص ثم اضغط تأكيد الطلب الآن.':
        'Enter your phone number and payment method, review summary, and confirm.',
    'متابعة الطلب': 'Track Your Order',
    'تابع حالة طلبك من صفحة «طلباتي» أولاً بأول حتى وصوله إليك.':
        'Follow your order status step by step in "My Orders" until delivery.',
    'استلام الطلب': 'Order Delivered',
    'عند وصول الشحنة تتحدّث الحالة إلى «تم التوصيل» — هذه شاشة توضيحية فقط.':
        'Once delivered, the status updates to Delivered — illustrative example only.',
    'إنشاء حساب المحل والدخول': 'Create Shop Account & Sign In',
    'أنشئ حساب متجرك بالبريد وكلمة المرور لتبدأ إعداد واجهتك في التطبيق.':
        'Create your shop account with email and password to set up your storefront.',
    'استكمال بيانات المحل': 'Complete Shop Profile',
    'أضف وصف المحل والمدينة والسجل التجاري وارفع الشعار والصور ثم أرسل طلب الانضمام.':
        'Add shop description, city, commercial register, logo & photos, then submit.',
    'إضافة المنتجات والمخزون': 'Add Products & Stock',
    'ارفع صور القطع وحدّد التصنيف والسعر والألوان والمقاسات والكميات ثم انشر المنتج.':
        'Upload product images, set category, price, colors, sizes, and stock, then publish.',
    'إدارة وتحديث الطلبات': 'Manage & Update Orders',
    'استقبل طلبات العملاء وحدّث حالتها من التأكيد والتجهيز والشحن حتى التسليم.':
        'Receive customer orders and update statuses from Confirm & Pack to Ship & Deliver.',
    'اكتمال التسليم والمبيعات': 'Delivery Complete & Sales',
    'عند تسليم الطلب تكتمل العملية وتنعكس الأرباح في صفحة المبيعات — مثال توضيحي.':
        'Completed deliveries update your Sales & Revenue dashboard — sample preview.',
    'تصفّح الأقسام في الرئيسية': 'Browse Home & Categories',
    'استكشف العروض والأقسام الرئيسية وابحث أو فلتر للوصول السريع للمنتجات.':
        'Explore banners, categories, search, and filters right from the Home tab.',
    'البحث وفلترة المنتجات': 'Search & Filter Catalog',
    'انتقل لتبويب المنتجات وحدّد التصنيف أو السعر أو المتوفر فقط لعرض النتائج فوراً.':
        'Filter the full catalog by category, availability, or sort order in one tap.',
    'اختيار القطعة والمقاس': 'Pick Piece, Color & Size',
    'تظهر رسالة تأكيد الطلب ورقم التتبع للانتقال لمتابعة طلباتك — مثال توضيحي.':
        'Your order confirmation and tracking number appear here — sample preview.',
    'مراجعة سلة المشتريات': 'Review Shopping Cart',
    'تحقق من القطع والكميات والإجمالي النهائي ثم اضغط إتمام الشراء.':
        'Verify your items, quantities, and total, then tap Proceed to Checkout.',
    'تأكيد الطلب والدفع': 'Confirm Order & Payment',
    'أدخل رقم هاتف المستلم وطريقة الدفع ثم اضغط تأكيد الطلب الآن.':
        'Confirm your phone number and payment method, then tap Confirm Order Now.',
    'متابعة الطلب والاستلام': 'Track & Receive Order',
    'راقب حالة طلبك في «طلباتي» حتى تتحول إلى «تم التوصيل» — مثال توضيحي.':
        'Track your order status in My Orders until Delivered — sample preview.',
    'بس هيك خلصنا': 'And that’s it — you’re all set!',
    'مرحباً، ابدأ الآن': 'Welcome! Start now',
    'مرحباً': 'Hello',
    'ابدأ الآن': 'Start Now',
    // Virtual Try-On (Lucy VTON, lighting guidance, body zones & errors)
    'تجربة الملابس': 'Virtual Try-On',
    'بنطلون كامل': 'Full Pants',
    'شورت / ركبة': 'Shorts / Knee',
    'بوات / القدمين': 'Footwear / Feet',
    'رأس / نظارات': 'Head & Eyewear',
    'ساعة / معصم': 'Watch & Wrist',
    'شنط / حقائب': 'Bags & Purses',
    'الرأس والوجه والرقبة (نظارات / قبعة / عقد)':
        'Head, Face & Neck (Glasses / Hat / Necklace)',
    'النظارات الشمسية والطبية، القبعات، الحجاب، الأقراط، العقود والشالات':
        'Sunglasses, eyeglasses, hats, hijab, earrings, necklaces & scarves',
    'أظهر الوجه والرأس والرقبة بوضوح أمام الكاميرا في إضاءة جيدة.':
        'Keep your face, head, and neck clearly visible in good lighting.',
    'الساعات والمعصم واليد (ساعة / سوار / خاتم)':
        'Watches, Wrist & Hand (Watch / Bracelet / Ring)',
    'ساعات اليد، الأساور، الخواتم والقفازات على المعصم أو اليد':
        'Wristwatches, bracelets, rings & gloves on your wrist or hand',
    'ارفع يدك ومعصمك بوضوح أمام الكاميرا وثبّتهما في إضاءة واضحة.':
        'Hold your hand and wrist clearly in front of the camera in good lighting.',
    'الحقائب والشنط (كتف / يد / ظهر)': 'Bags & Purses (Shoulder / Hand / Back)',
    'حقائب اليد، شنط الكتف والكروس، وحقائب الظهر':
        'Handbags, shoulder & crossbody bags, and backpacks',
    'أظهر الكتف واليد بوضوح أمام الكاميرا ليظهر حمل الحقيبة بشكل طبيعي.':
        'Keep your shoulder and hand visible so the bag drapes naturally.',
    'الجزء العلوي (بلوزة / قميص / جاكيت)': 'Upper Body (Top / Shirt / Jacket)',
    'الصدر والكتفين والذراعين (بلوزة، تيشيرت، قميص، هودي، جاكيت)':
        'Chest, shoulders, and arms (t-shirt, shirt, hoodie, jacket)',
    'البنطلون الكامل (الرجلين بالكامل)': 'Full Pants (Full Legs)',
    'من الخصر حتى الكاحلين (بنطلون جينز، رسمي، كارغو، رياضي)':
        'From waist to ankles (jeans, dress pants, cargo, joggers)',
    'الشورت (أعلى الركبة)': 'Shorts (Above Knee)',
    'من الخصر حتى الركبتين فقط مع الحفاظ على الساقين السفليتين':
        'From waist to knees while keeping lower legs unchanged',
    'طقم كامل / فستان / عباية': 'Full Outfit / Dress / Abaya',
    'الجذع والرجلين معاً كقطعة متكاملة (فستان، عباية، بدلة، طقم)':
        'Torso and legs together as a complete outfit (dress, abaya, suit)',
    'البوت والحذاء (القدمين)': 'Shoes & Boots (Feet)',
    'القدمين والكاحلين فقط (بوات، سنيكرز، بوت جلدي، حذاء رسمي)':
        'Feet and ankles only (sneakers, boots, dress shoes)',
    'تبديل الكاميرا': 'Switch Camera',
    'إعادة': 'Retry',
    'حسناً': 'Got it',
    'نصائح الإضاءة والوضعية': 'Lighting & Framing Tips',
    'نصائح لأفضل ثبات للوجه والجسم': 'Tips for Best Face & Body Stability',
    'هذه الإرشادات لتحسين دقة المعاينة ولا توقف البث المباشر.':
        'These tips improve try-on accuracy and never interrupt the live stream.',
    'إضاءة أمامية متوازنة': 'Balanced Front Lighting',
    'لثبات الوجه والجسم: قف في إضاءة أمامية واضحة دون ضوء خلفي قوي.':
        'For stable face & body: stand in clear front lighting without strong backlighting.',
    'ثبات الوضعية والاتصال': 'Steady Posture & Connection',
    'تجنب الحركة السريعة واستخدم شبكة إنترنت مستقرة لنتيجة أدق.':
        'Avoid rapid movement and use a stable internet connection for sharper results.',
    'اتصال الإنترنت ضعيف حالياً؛ قد تقل دقة المعاينة مؤقتاً.':
        'Network connection is weak; try-on quality may temporarily drop.',
    'توقفت التجربة. يمكنك إعادة المحاولة الآن.':
        'Try-on stopped. You can retry now.',
    'انتظر لحظة، جارٍ تجهيز الإطلالة…': 'One moment, preparing your live look…',
    'جارٍ تبديل القطعة…': 'Switching garment…',
    'جارٍ تطبيق القطعة على جسمك…': 'Applying garment to your body…',
    'التجربة المباشرة بتقنية Lucy VTON متاحة على هواتف أندرويد وآيفون فقط.':
        'Live Lucy VTON try-on is available on Android and iOS phones only.',
    'يلزم منح إذن الكاميرا لتشغيل تجربة الملابس المباشرة.':
        'Camera permission is required to start live virtual try-on.',
    'تعذر بدء جلسة التجربة المباشرة. تحقق من الاتصال وأعد المحاولة.':
        'Could not start live try-on session. Check your connection and retry.',
    'الجلسة غير متصلة حالياً.': 'Try-on session is not currently connected.',
    'تعذر تحديث القطعة على البث المباشر.':
        'Could not update the garment on the live stream.',
    'رابط صورة القطعة غير صالح للتجربة.':
        'Garment image URL is not valid for try-on.',
    'تعذر تحميل صورة القطعة للتجربة.':
        'Could not download the garment image for try-on.',
    'حجم صورة القطعة كبير جداً للتجربة.':
        'Garment image file is too large for try-on.',
    'انقطع الاتصال بخادم التجربة. أعد المحاولة.':
        'Disconnected from try-on server. Please try again.',
    'يلزم اسم قطعة ورابط HTTPS صالح لصورتها.':
        'A garment name and valid HTTPS image URL are required.',
    'نفد رصيد حساب Decart أو انتهى الاشتراك. يرجى من الإدارة شحن الرصيد أو تحديث المفتاح.':
        'Decart account credits or subscription have run out. Please ask admin to top up or update the API key.',
    'تعذر فتح الكاميرا. تأكد من عدم استخدامها في تطبيق آخر.':
        'Could not open the camera. Make sure no other app is using it.',
    'مفتاح أو رصيد جلسة Decart غير صالح أو منتهي. يرجى من الإدارة تحديث المفتاح من لوحة التحكم.':
        'Decart API key or session token is invalid or expired. Please ask admin to update it in settings.',
    'نموذج Lucy VTON المطلوب غير متاح حالياً على الخادم.':
        'The requested Lucy VTON model is currently unavailable on the server.',
    'انتهت مهلة الاتصال بخادم التجربة. تحقق من سرعة الإنترنت ثم أعد المحاولة.':
        'Connection to try-on server timed out. Check your internet speed and retry.',
    'تعذر استقرار اتصال الفيديو عبر الشبكة. تحقق من الإنترنت وأعد المحاولة.':
        'Could not stabilize the video connection over the network. Check your internet and retry.',
    'لم يتم قبول وصف القطعة على الخادم. جرّب قطعة أخرى.':
        'The garment prompt was rejected by the server. Try another item.',
    'حدث خطأ مؤقت في خادم Decart. أعد المحاولة بعد قليل.':
        'Temporary Decart server error. Please try again shortly.',
    'بيانات القطعة أو إعدادات الجلسة غير صالحة.':
        'Invalid garment data or session configuration.',
    'انقطعت الجلسة الحالية. أعد تشغيل المعاينة المباشرة.':
        'Current session disconnected. Restart the live preview.',
    'تم إيقاف عملية التجربة.': 'Try-on session was cancelled.',
    'حدث خطأ غير متوقع أثناء المعاينة المباشرة. أعد المحاولة.':
        'An unexpected error occurred during live try-on. Please retry.',
    'تعذر إعداد الجلسة. تحقق من تسجيل الدخول ونشر خدمة decart-session.':
        'Could not prepare session. Check sign-in and decart-session deployment.',
    'لا توجد قطع بصور أمامية متاحة للتجربة.':
        'No garments with front-facing photos are available for try-on.',
    'المنتج المطلوب غير متاح للتجربة أو لا يملك صورة أمامية مناسبة. لم يتم استبداله بمنتج آخر.':
        'The requested product is unavailable for try-on or lacks a suitable front photo.',
    'تعذر تحميل قطع الملابس أو بدء الجلسة.':
        'Could not load garments or start the try-on session.',
    'تعذر تحديث القطعة.': 'Could not update the garment.',
    'تعذر تبديل الكاميرا.': 'Could not switch camera.',
    'إذن الكاميرا مرفوض. اسمح لهذا الموقع باستخدام الكاميرا من إعدادات المتصفح ثم أعد المحاولة.':
        'Camera permission denied. Allow camera access in settings and try again.',
    'لم يعثر المتصفح على كاميرا. صِل كاميرا بالكمبيوتر ثم أعد المحاولة.':
        'No camera found. Connect a camera and try again.',
    'تعذر تشغيل الكاميرا. قد تكون مستخدمة في تطبيق أو تبويب آخر؛ أغلقه وأعد المحاولة.':
        'Could not start camera. Close other apps using it and retry.',
    'الكاميرا لا تدعم إعدادات الفيديو المطلوبة. جرّب كاميرا أخرى.':
        'Camera does not support the required video settings. Try another camera.',
    'الوصول إلى الكاميرا غير متاح. افتح التطبيق عبر HTTPS أو localhost في متصفح يدعم الكاميرا.':
        'Camera access unavailable. Open over HTTPS or localhost.',
    'انتهت مهلة تشغيل الكاميرا. تحقق من طلب الإذن ثم أعد المحاولة.':
        'Camera startup timed out. Check camera permission and retry.',
    'إضافة الكاميرا غير مهيأة. أعد تشغيل التطبيق بالكامل بعد تحديث الحزم.':
        'Camera plugin is not initialized. Restart the app completely.',
    'فشل فتح الكاميرا. تحقق من توصيلها ومن إذن استخدامها في المتصفح أو إعدادات الجهاز.':
        'Failed to open camera. Check permissions in device settings.',
    'تعذر فتح الكاميرا.': 'Could not open the camera.',
    'تعذر تجهيز جلسة التجربة من الخادم. تحقق من الشبكة وتسجيل الدخول.':
        'Could not prepare try-on session from server. Check network and sign-in.',
    'تعذر تهيئة اتصال الفيديو. جرّب متصفحاً حديثاً يدعم WebRTC.':
        'Could not initialize video connection.',
    'تعذر فتح قناة الاتصال بخادم التجربة. تحقق من الشبكة ثم أعد المحاولة.':
        'Could not open signaling channel to try-on server. Check network and retry.',
    'تعذر تحميل صورة القطعة. تحقق من رابط الصورة والسماح بتحميلها من المتصفح (CORS).':
        'Could not load garment image. Check the image URL.',
    'انتهت صلاحية تسجيل الدخول أو رُفض الوصول للجلسة. سجّل الدخول مجدداً.':
        'Session expired or access denied. Please sign in again.',
    'خدمة التجربة غير منشورة على الخادم. يلزم نشر decart-session على Supabase.':
        'Try-on service is not deployed on the server (decart-session).',
    'عدد محاولات الاتصال كبير. انتظر قليلاً ثم أعد المحاولة.':
        'Too many connection attempts. Wait a moment and retry.',
    'تعذر إصدار رمز جلسة Decart. يلزم التحقق من مفتاح الخدمة وصلاحية الحساب على الخادم.':
        'Could not issue Decart session token. Check server API key and account status.',
    'خدمة التجربة غير مهيأة أو غير متاحة حالياً. تحقق من إعدادات الخادم ومفتاح Decart.':
        'Try-on service is not configured or unavailable. Check server settings and Decart key.',
    'أدخل مفتاح Decart صالحاً يبدأ بـ dct_ (مثل dct_wasla_ أو dct_app_)':
        'Enter a valid Decart key starting with dct_ (e.g. dct_wasla_ or dct_app_)',
    'حفظ المفتاح': 'Save Key',
    'مفتاح Decart الجديد': 'New Decart Key',
    'يوجد مفتاح محفوظ بأمان. يمكنك استبداله أدناه.':
        'A key is securely saved. You can replace it below.',
    'لم يُحفظ مفتاح من إعدادات الأدمن بعد.':
        'No key has been saved from admin settings yet.',
    'تم حفظ المفتاح. سيُستخدم في جلسات تجربة الملابس الجديدة.':
        'Key saved. It will be used for new virtual try-on sessions.',
    'حالة إعداد مفتاح تجربة الملابس': 'Virtual try-on key configuration status',
    'تعذر قراءة حالة إعداد المفتاح.':
        'Could not load key configuration status.',
    'يُحفظ المفتاح مشفّراً على السيرفر ولا يظهر بعد الحفظ. ':
        'The key is stored encrypted on the server and hidden after saving. ',
    'الحفظ لا يتحقق من رصيد Decart أو صلاحية الاشتراك.':
        'Saving does not verify Decart credits or subscription status.',
    // Try-On Guidelines Onboarding & Cost Controls
    'تعليمات التجربة الافتراضية': 'Virtual Try-On Guidelines',
    'للحصول على أفضل نتيجة قبل البدء': 'For Best Results Before You Start',
    'تظهر هذه الإرشادات في المرة الأولى فقط لمساعدتك على الحصول على تجربة واقعية وسلسة.':
        'These guidelines appear on your first visit only to help you get realistic, smooth results.',
    'إضاءة قوية وواضحة': 'Strong, Clear Lighting',
    'قف في مكان بإضاءة أمامية قوية وموزعة جيداً، وتجنب العتمة أو وجود نافذة مضيئة خلفك.':
        'Stand in bright, even front lighting and avoid dark rooms or strong backlighting.',
    'كاميرا نظيفة وثابتة': 'Clean, Steady Camera',
    'امسح عدسة الكاميرا جيداً قبل البدء ليظهر الوجه وتفاصيل الملابس أو الإكسسوارات بوضوح.':
        'Wipe your camera lens clean so your face and garment or accessory details stay crisp.',
    'إنترنت قوي ومستقر': 'Fast & Stable Internet',
    'استخدم شبكة Wi-Fi سريعة أو بيانات جوال قوية (4G/5G) لضمان استقرار البث المباشر دون تقطيع.':
        'Use fast Wi-Fi or strong 4G/5G mobile data for smooth live streaming without interruptions.',
    'تفسير وتوضيح التجربة': 'About Virtual Try-On',
    'تعمل التجربة بالذكاء الاصطناعي لإعطائك تصوراً تقريبياً للقطعة على جسمك أو يدك؛ قد تختلف درجات الألوان أو التفاصيل الدقيقة قليلاً حسب الإضاءة. يتم إيقاف الجلسة تلقائياً عند الخروج.':
        'Virtual try-on uses AI to give an approximate preview on your body or hand; fine details or shades may vary slightly with lighting. Sessions stop automatically when you exit.',
    'أوافق على الشروط والتعليمات': 'I agree to the terms and guidelines',
    'تم إيقاف خدمة التجربة الافتراضية مؤقتاً من قبل الإدارة.':
        'Virtual try-on is temporarily paused by the administrator.',
    'انتهى وقت الجلسة': 'Session Time Ended',
    'العودة': 'Go Back',
    'محاولة جديدة': 'Try Again',
    'التحكم في تكلفة التجربة الافتراضية': 'Virtual Try-On Cost Controls',
    'جارٍ تحميل إعدادات التكلفة…': 'Loading cost control settings…',
    'تعذر قراءة إعدادات التكلفة من السيرفر (تأكد من تطبيق تحديث 019).':
        'Could not load cost settings from server (ensure migration 019 is applied).',
    'تفعيل ميزة التجربة الافتراضية': 'Enable Virtual Try-On',
    'الخدمة متاحة حالياً للمستخدمين.': 'Service is currently active for users.',
    'الخدمة متوقفة مؤقتاً لتوفير التكلفة.':
        'Service is temporarily paused to control costs.',
    'مدة جلسة التجربة (بالثواني)': 'Session Duration (seconds)',
    'القيمة المسموحة بين 10 و300 ثانية (الافتراضي 30).':
        'Allowed range: 10 to 300 seconds (default 30).',
    'أدخل مدة بين 10 و300 ثانية.':
        'Enter a duration between 10 and 300 seconds.',
    'الحد اليومي للمحاولات لكل مستخدم': 'Daily Attempts Limit per User',
    'القيمة المسموحة بين 1 و100 محاولة يومياً (الافتراضي 3).':
        'Allowed range: 1 to 100 attempts per day (default 3).',
    'أدخل عدداً بين 1 و100 محاولة يومياً.':
        'Enter a number between 1 and 100 attempts per day.',
    'حفظ إعدادات التكلفة': 'Save Cost Controls',
    'تم حفظ إعدادات التحكم في تكلفة التجربة بنجاح.':
        'Try-on cost control settings saved successfully.',
    'يلزم تطبيق تحديث قاعدة البيانات 019 في Supabase أولاً.':
        'Please apply Supabase database migration 019 first.',
    'تعذر حفظ إعدادات التحكم في التكلفة. حاول مجدداً.':
        'Could not save cost control settings. Please try again.',
    // --- Shop Panel / Seller Experience ---
    'المبيعات': 'Sales',
    'قيد المعالجة': 'Pending',
    'المنشورة': 'Published',
    'المخزون': 'Stock',
    'منتجات منشورة': 'Published Products',
    'وحدات المخزون': 'Stock Units',
    'إجمالي الطلبات': 'Total Orders',
    'من أصل': 'of',
    'طلب': 'Order',
    'قطعة متاحة للبيع': 'items in stock',
    'قطعة متوفرة بالمخزون': 'items in stock',
    'أضف مخزوناً لمنتجاتك': 'Add product stock',
    'إجراءات سريعة': 'Quick Actions',
    'منتج جديد': 'New Product',
    'أحدث الطلبات': 'Recent Orders',
    'إدارة الطلب': 'Manage Order',
    'تحديث الحالة': 'Update Status',
    'متجري': 'My Shop',
    'إدارة المتجر والطلبات': 'Manage shop & orders',
    'تعديل ملف المتجر': 'Edit Shop Profile',
    'طلبات بانتظار المراجعة': 'Orders Awaiting Review',
    'لديك': 'You have',
    'طلبات قيد المعالجة وتحتاج متابعتك.':
        'pending orders needing your attention.',
    'مراجعة الطلبات': 'Review Orders',
    'أكمل ملف متجرك للبدء': 'Complete your shop profile to start',
    'استكمل بيانات المتجر وأرسل طلب الانضمام لتتمكن من نشر منتجاتك واستقبال الطلبات.':
        'Complete your shop details and submit your application to publish products and receive orders.',
    'استكمال البيانات': 'Complete Details',
    'طلبك قيد المراجعة': 'Your Application Is Under Review',
    'تقوم الإدارة بمراجعة بيانات متجرك حالياً. ستتمكن من البيع فور الموافقة.':
        'Admin is reviewing your shop details. You can start selling once approved.',
    'متابعة الحالة': 'Track Status',
    'يحتاج طلبك إلى تعديل': 'Your Application Needs Changes',
    'يرجى مراجعة بيانات المتجر وتحديثها ثم إعادة التقديم.':
        'Please review and update your shop details, then resubmit.',
    'تعديل وإعادة التقديم': 'Edit & Resubmit',
    'المتجر موقوف مؤقتاً': 'Shop Temporarily Suspended',
    'يرجى التواصل مع الإدارة لمراجعة حالة المتجر.':
        'Please contact admin to review your shop status.',
    'عرض الحالة': 'View Status',
    'ستظهر هنا أحدث طلبات العملاء فور استلامها لتتمكن من متابعتها بسرعة.':
        'Your latest customer orders will appear here as soon as they arrive.',
    'تعذر تحميل الإحصائيات': 'Failed to Load Statistics',
    'اسحب للأسفل لتحديث بيانات المتجر.': 'Pull down to refresh shop data.',
    'تعذر تحميل الطلبات': 'Failed to Load Orders',
    'افتح صفحة الطلبات لإعادة المحاولة.': 'Open the orders page to try again.',
    'متوسط قيمة الطلب': 'Avg. Order Value',
    'طلبات مكتملة / مؤكدة': 'Confirmed / Completed',
    'جاهزية الكتالوج للنشر': 'Catalog Publish Readiness',
    'منتج منشور من أصل': 'published out of',
    'وصول سريع': 'Quick Access',
    'تحديث حالات الطلبات قيد المعالجة والشحن':
        'Update pending and shipping order statuses',
    'إدارة المنتجات والمخزون': 'Manage Products & Stock',
    'مراجعة الأسعار والكميات المتوفرة ونشر المسودات':
        'Review prices, stock levels, and publish drafts',
    'تعذر تحميل بيانات المبيعات': 'Failed to Load Sales Data',
    'الخطوة التالية المقترحة': 'Suggested Next Step',
    'خيارات حالة أخرى': 'Other Status Options',
    'تأكيد الطلب': 'Confirm Order',
    'بدء التجهيز': 'Start Processing',
    'تأكيد التسليم': 'Mark as Delivered',
    'إلغاء الطلب': 'Cancel Order',
    'تأكيد إلغاء الطلب': 'Confirm Order Cancellation',
    'تأكيد الإلغاء': 'Confirm Cancel',
    'تراجع': 'Back',
    'الطلبات غير مفعّلة بعد': 'Orders Not Enabled Yet',
    'تظهر طلبات العملاء هنا تلقائياً بعد موافقة الإدارة على متجرك.':
        'Customer orders will appear here automatically once your shop is approved.',
    'عندما يقوم العملاء بالطلب من متجرك ستظهر تفاصيل الطلبات هنا لمتابعتها.':
        'When customers place orders from your shop, they will appear here.',
    'إدارة المنتجات': 'Manage Products',
    'تعديل المنتج': 'Edit Product',
    'إيقاف النشر مؤقتاً': 'Temporarily Unpublish',
    'حذف المنتج': 'Delete Product',
    'تأكيد حذف المنتج': 'Confirm Product Deletion',
    'حذف نهائياً': 'Delete Permanently',
    'إدارة المنتجات غير مفعّلة بعد': 'Products Not Enabled Yet',
    'لا يمكن إضافة أو إدارة المنتجات قبل موافقة الإدارة على متجرك.':
        'You cannot add or manage products until admin approves your shop.',
    'تعذر تحميل المنتجات': 'Failed to Load Products',
    'لا توجد منتجات في متجرك بعد': 'No Products in Your Shop Yet',
    'ابدأ بإضافة أول منتج مع الصور والمقاسات ليظهر للعملاء في المتجر.':
        'Start by adding your first product with photos and sizes to show it to customers.',
    'إضافة أول منتج': 'Add First Product',
    'ابحث باسم المنتج، التصنيف، اللون...':
        'Search by product, category, color...',
    'نفد المخزون': 'Out of Stock',
    'تعذر تحميل الإشعارات': 'Failed to Load Notifications',
    'ستصل هنا تنبيهات الإدارة والطلبات، ويمكنك إرسال عروض لعملاء متجرك.':
        'Admin and order alerts will arrive here, and you can send offers to your shop customers.',
    'ستظهر هنا تنبيهات المنصة وحالة طلب انضمام متجرك.':
        'Platform alerts and your shop application updates will appear here.',
    'ملف المتجر': 'Shop Profile',
    'تفضيلات التطبيق': 'App Preferences',
    'الهوية البصرية والمستندات': 'Branding & Documents',
    'بيانات المتجر': 'Shop Details',
    'معلومات المتجر': 'Shop Information',
    'بيانات المالك والتواصل': 'Owner & Contact Info',
    'اسم صاحب المحل': 'Shop Owner Name',
    'وصف المحل': 'Shop Description',
    'السجل التجاري': 'Commercial Register',
    'شعار المحل': 'Shop Logo',
    'صورة الغلاف': 'Cover Image',
    'تم الرفع': 'Uploaded',
    'غير مرفوع': 'Not Uploaded',
    'صور المعرض': 'Gallery Photos',
    'إضافة صورة': 'Add Photo',
    'أضف صوراً حقيقية لمتجرك لتعزيز ثقة العملاء.':
        'Add real photos of your shop to build customer trust.',
    'مستندات التوثيق': 'Verification Documents',
    'ارفع السجل التجاري أو إثبات المحل':
        'Upload your commercial register or shop proof',
    'مستند مرفوع': 'uploaded document(s)',
    'رفع مستند': 'Upload Document',
    'عرض حالة الطلب': 'View Application Status',
    'متابعة حالة الطلب': 'Track Application Status',
    'تعذر تحميل ملف المتجر': 'Failed to Load Shop Profile',
    'لم يتم العثور على بيانات المحل': 'Shop details not found',
    'حاول تحديث الصفحة أو التواصل مع الدعم.':
        'Try refreshing the page or contacting support.',
    'تحديث': 'Refresh',
    'اكتمال ملف المتجر': 'Shop Profile Completion',
    'جميع الحقول المطلوبة مكتملة، يمكنك إرسال الطلب للمراجعة الآن.':
        'All required fields are complete. You can submit your application for review now.',
    'أكمل جميع الحقول المطلوبة ثم أرسل طلب الانضمام لمراجعة الإدارة.':
        'Complete all required fields, then submit your application for admin review.',
    'سبب رفض الطلب السابق': 'Previous Rejection Reason',
    'حفظ مسودة': 'Save Draft',
    'حفظ وإرسال للمراجعة': 'Save & Submit for Review',
    'تعذر تحميل بيانات المحل': 'Failed to Load Shop Details',
    'حالة طلب الانضمام': 'Application Status',
    'مراحل تفعيل المتجر': 'Shop Activation Steps',
    'استكمال بيانات المتجر': 'Complete Shop Details',
    'إدخال المعلومات الأساسية ورفع الهوية':
        'Enter basic info and upload branding',
    'مراجعة الإدارة': 'Admin Review',
    'التحقق من السجل التجاري والبيانات':
        'Verifying commercial register and details',
    'تحتاج البيانات إلى تعديل وإعادة إرسال':
        'Details need editing and resubmission',
    'تفعيل المتجر وبدء البيع': 'Shop Activation & Selling',
    'المتجر موقوف حالياً': 'Shop is currently suspended',
    'إضافة المنتجات واستقبال طلبات العملاء':
        'Add products and receive customer orders',
    'الذهاب إلى لوحة المحل': 'Go to Shop Dashboard',
    'تعديل البيانات وإعادة التقديم': 'Edit Details & Resubmit',
    'الحالة الحالية': 'Current Status',
    'سبب الرفض': 'Rejection Reason',
    'تعذر تحميل حالة الطلب': 'Failed to Load Application Status',
    'اضغط للتحديث أو أعد تسجيل الدخول.': 'Tap to refresh or sign in again.',
    'طلب الانضمام قيد المراجعة لدى الإدارة. سيظهر القرار هنا فور اكتمال المراجعة.':
        'Your application is under admin review. The decision will appear here once completed.',
    'تمت الموافقة على متجرك بنجاح! يمكنك الآن إضافة منتجاتك واستقبال الطلبات.':
        'Your shop has been approved! You can now add products and receive orders.',
    'تم رفض طلب الانضمام. يمكنك تعديل البيانات وفق الملاحظات وإعادة التقديم.':
        'Your application was rejected. You can update the details and resubmit.',
    'تم تعليق المتجر مؤقتاً. يرجى التواصل مع إدارة المنصة لمعرفة التفاصيل.':
        'Your shop has been temporarily suspended. Please contact support for details.',
    'أكمل بيانات المتجر أولاً ثم أرسل طلب الانضمام للمراجعة.':
        'Complete your shop details first, then submit your application for review.',
    'الخطوة': 'Step',
    'السابق': 'Previous',
    'تعذر فتح المنتج': 'Failed to Open Product',
    'حدث خطأ أثناء تحميل بيانات المنتج. حاول مرة أخرى.':
        'An error occurred while loading product details. Please try again.',
    'تم إرسال الإشعار': 'Notification sent',
    'تعذر الإرسال': 'Failed to send',
    'تم تحديث المنتج': 'Product updated',
    'تم تحديث حالة الطلب': 'Order status updated',
    'تم تحديث ملف المحل': 'Shop profile updated',
    'تم حفظ البيانات': 'Details saved',
    'تم إرسال طلب الانضمام للإدارة': 'Application submitted to admin',
    'تم رفع الشعار': 'Logo uploaded',
    'تم رفع صورة الغلاف': 'Cover image uploaded',
    'تم رفع صورة المحل': 'Shop photo uploaded',
    'تم رفع المستند': 'Document uploaded',
    'تعذر رفع الشعار': 'Failed to upload logo',
    'تعذر رفع صورة الغلاف': 'Failed to upload cover image',
    'تعذر رفع الصورة': 'Failed to upload image',
    'تعذر رفع المستند': 'Failed to upload document',
    'تعذر حفظ البيانات': 'Failed to save details',
    'تعذر حفظ الملف': 'Failed to save profile',
    'تعذر التحديث': 'Failed to update',
    'المحتوى': 'Message',
    'إثبات محل': 'Shop Proof',
    'بدون صورة': 'No Image',
    'اضغط للرفع': 'Tap to Upload',
    'رفع': 'Upload',
    'محدد': 'Selected',
    'طلبات اليوم': "Today's Orders",
    'لا توجد طلبات اليوم': 'No Orders Today',
    'ستظهر هنا جميع طلبات اليوم منذ بداية الدوام وحتى نهاية اليوم.':
        'All orders placed today from opening to closing will appear here.',
    'إجمالي اليوم': "Today's Total",
    'إعدادات المتجر والتطبيق': 'Shop & App Settings',
    'تعديل بيانات المتجر والمالك': 'Edit Shop & Owner Details',
    'اسم المحل، الوصف، المدينة، العنوان، السجل التجاري، والهاتف':
        'Shop name, description, city, address, register, and phone',
    'الشعار، صورة الغلاف، صور المعرض، ومستندات التوثيق':
        'Logo, cover image, gallery photos, and verification documents',
    'حذف المحل': 'Delete Shop',
    'حذف المحل نهائياً': 'Delete Shop Permanently',
    'إغلاق المتجر وإيقاف جميع المنتجات والحساب نهائياً':
        'Close shop and permanently deactivate products and account',
    'سيتم إغلاق متجرك وإيقاف جميع منتجاتك وحسابك ولن تتمكن من استعادتها مرة أخرى.':
        'Your shop will be closed and all your products and account will be permanently deactivated.',
    'تأكيد حذف المحل': 'Confirm Shop Deletion',
    'جاري حذف المحل...': 'Deleting shop...',
    'تعذر حذف المحل حالياً، حاول مرة أخرى':
        'Could not delete shop right now, please try again',
    'طلبات المحل': 'Shop Orders',
    'إضافة وتعديل المنتجات والمخزون': 'Add and manage products and inventory',
    'متابعة طلبات المحل وتحديث حالتها': 'Track shop orders and update status',
    'ملخص المبيعات والمخزون': 'Summary of sales and inventory',
    'أقل من 150': 'Under 150',
    'أكثر من 350': 'Over 350',
    'حالة توثيق المتجر': 'Shop Verification Status',
    'يمكنك متابعة حالة طلب الانضمام أو استكمال بياناتك من صفحة الحالة.':
        'You can track your application status or complete your details from the status page.',
    'الأساسيات': 'Basics',
    'المواصفات': 'Specs',
    'المقاسات': 'Sizes',
    'الصور': 'Photos',
    'المراجعة': 'Review',
    'البيانات الأساسية': 'Basic Info',
    '4 حقول فقط للتعريف بالمنتج وسعره وتصنيفه.':
        'Just 4 quick fields for product name, category, price, and description.',
    'اسم المنتج *': 'Product Name *',
    'مثال: جاكيت جينز كلاسيك': 'e.g. Classic Denim Jacket',
    'التصنيف *': 'Category *',
    'إضافة تصنيف جديد': 'Add New Category',
    'مثال: 120': 'e.g. 120',
    'وصف المنتج *': 'Product Description *',
    'القَصّة، الأسلوب، وما يميز المنتج':
        'Fit, style, and what makes this item stand out',
    'مواصفات إضافية (اختياري)': 'Extra Specs (Optional)',
    'اختر من الخيارات الجاهزة بلمسة واحدة، أو اضغط التالي للتخطي.':
        'Pick quick presets with one tap, or press Next to skip.',
    'اختياري — اسم العلامة أو المتجر': 'Optional — brand or shop name',
    'مثال: قطن 100%': 'e.g. 100% Cotton',
    'تعليمات العناية': 'Care Instructions',
    'مثال: غسيل بارد': 'e.g. Cold Wash',
    'رمز المنتج (SKU)': 'Product SKU',
    'اختياري — رمز خاص بالمتجر': 'Optional — internal shop code',
    'قطن 100%': '100% Cotton',
    'كتان': 'Linen',
    'جينز': 'Denim',
    'بوليستر': 'Polyester',
    'صوف': 'Wool',
    'جلد': 'Leather',
    'حرير': 'Silk',
    'غسيل بارد': 'Cold Wash',
    'غسيل يدوي': 'Hand Wash',
    'تنظيف جاف': 'Dry Clean',
    'لا يُكوى': 'Do Not Iron',
    'صور المنتج': 'Product Photos',
    'اختر حتى 12 صورة — يتم إزالة الخلفية تلقائياً وتكون الصورة الأولى هي الرئيسية.':
        'Pick up to 12 photos — background is removed automatically and the first photo is the main image.',
    'اختيار صور المنتج': 'Select Product Photos',
    'لم تُضف صوراً بعد': 'No Photos Added Yet',
    'صورة أمامية، خلفية، وصورة للتفاصيل تزيد ثقة المشتري.':
        'Front, back, and detail shots build buyer confidence.',
    'صورة': 'Photo',
    'أضف الألوان والمقاسات المتوفرة بالكمية المناسبة لكل خيار.':
        'Add available colors, sizes, and stock quantities.',
    'مثال: أسود': 'e.g. Black',
    'مثال: M أو 40': 'e.g. M or 40',
    'إضافة لون ومقاس': 'Add Color & Size',
    'تعديل الخيار': 'Edit Option',
    'حفظ الخيار': 'Save Option',
    'عدد القطع المتاحة': 'Available Stock',
    'أزرق': 'Blue',
    'اختيار التصنيف': 'Select Category',
    'التصنيفات المتاحة': 'Available Categories',
    'مثال: ملابس صيفية': 'e.g. Summer Wear',
    'ابحث في التصنيفات...': 'Search categories...',
    'لا يوجد تصنيف مطابق، يمكنك إضافة تصنيف جديد.':
        'No matching category found. You can add a new one.',
    'تصنيف رئيسي': 'Main Category',
    'اختر التصنيف أو أضف تصنيفاً جديداً': 'Choose a category or add a new one',
    'تغيير': 'Change',
    // --- Remaining Shop Models, Repositories, Form & Bottom Sheets ---
    'قيد المراجعة': 'Under Review',
    'موقوف': 'Suspended',
    'محذوف': 'Deleted',
    'أسود': 'Black',
    'أبيض': 'White',
    'كحلي': 'Navy',
    'رمادي': 'Gray',
    'بيج': 'Beige',
    'بني': 'Brown',
    'أحمر': 'Red',
    'أخضر': 'Green',
    'اسم التصنيف': 'Category Name',
    'استخدام التصنيف': 'Use Category',
    'استخدم اسماً واضحاً مثل فساتين سهرة أو ملابس رياضية. سيُحفظ التصنيف مع المنتج.':
        'Use a clear name like Evening Dresses or Sportswear. It will be saved with the product.',
    'اكتب اسم المنتج أولاً': 'Enter the product name first',
    'أدخل سعراً صحيحاً أكبر من صفر': 'Enter a valid price greater than zero',
    'أضف وصفاً يوضح المنتج للعميل':
        'Add a description that explains the product to customers',
    'اختر تصنيفاً أو أضف تصنيفاً جديداً': 'Choose a category or add a new one',
    'انتظر تجهيز الصور أو أعد محاولة الصور المتعثرة أو احذفها':
        'Wait for photos to finish processing, or retry/remove failed ones',
    'أضف صورة واحدة على الأقل للمنتج': 'Add at least one product photo',
    'أضف اللون والمقاس والكمية المتاحة': 'Add color, size, and available stock',
    'أضف كمية متاحة قبل النشر': 'Add available stock before publishing',
    'أدخل اللون والمقاس وكمية صحيحة': 'Enter a valid color, size, and quantity',
    'هذا اللون والمقاس موجودان بالفعل؛ عدّل كميتهما':
        'This color and size already exist; edit its quantity instead',
    'يمكن إضافة 12 صورة كحد أقصى': 'You can add up to 12 photos maximum',
    'تعذر اختيار الصور، حاول مجدداً': 'Could not pick photos, please try again',
    'تعذر الحفظ': 'Failed to save',
    'تم نشر المنتج بنجاح': 'Product published successfully',
    'تم حفظ المسودة': 'Draft saved',
    'مغادرة إضافة المنتج؟': 'Leave product form?',
    'التغييرات غير المحفوظة لن تُضاف إلى منتجاتك.':
        'Unsaved changes will not be added to your products.',
    'متابعة التعديل': 'Continue Editing',
    'مغادرة دون حفظ': 'Leave Without Saving',
    'جاري تحميل التصنيفات': 'Loading categories',
    'تعذر تحميل التصنيفات — إعادة المحاولة':
        'Failed to load categories — Retry',
    'جاري تجهيز الصور… يمكنك إكمال البيانات':
        'Processing photos… you can keep editing details',
    'الصورة الرئيسية': 'Main Photo',
    'صورة تجربة الملابس': 'Try-On Photo',
    'جاري إزالة الخلفية وتجهيز الصورة': 'Removing background & preparing photo',
    'تعذرت معالجة الصورة. أعد المحاولة أو احذفها لاختيار صورة أخرى.':
        'Photo processing failed. Retry or delete to pick another photo.',
    'جعلها الرئيسية': 'Set as Main',
    'تقديم الصورة': 'Move Earlier',
    'تأخير الصورة': 'Move Later',
    'حذف الصورة': 'Delete Photo',
    'كل خيار وكمّيته': 'Variants & Stock',
    'راجع منتجك قبل النشر': 'Review Your Product Before Publishing',
    'تأكد من السعر والصورة الرئيسية والمخزون. يمكنك الرجوع لأي مرحلة لتعديلها.':
        'Verify price, main photo, and stock. You can jump back to any step to edit.',
    'بيانات المنتج': 'Product Details',
    'وصف المنتج': 'Product Description',
    'جدول قياسات المنتج': 'Product Size Chart',
    'اختياري · لاقتراح المقاس المناسب للعميل':
        'Optional · helps recommend the right size to customers',
    'أضف مقاساً أولاً': 'Add a size first',
    'بدون قياسات': 'No measurements',
    'تعديل جدول القياسات': 'Edit Size Chart',
    'جدول القياسات جاهز': 'Size chart ready',
    'حفظ نطاق القياسات': 'Save Measurement Ranges',
    'قياسات المقاس': 'Size Measurements',
    'كل القيم بالسنتيمتر. اترك القياس فارغاً إذا لم يرد في جدول الشركة.':
        'All values are in cm. Leave blank if not listed in the brand chart.',
    'أدخل نطاق قياسات جسم العميل بالسنتيمتر حسب جدول الشركة، وليس أبعاد القطعة المفرودة. للصدر في القطع العلوية، وللخصر والورك في السفلية، ولطول القدم في الأحذية.':
        'Enter customer body measurement ranges in cm per brand chart (chest for tops, waist/hip for bottoms, foot length for shoes).',
    'تعذر العثور على المنتج محلياً': 'Product not found locally',
    'تعذر تحديث بيانات المحل بدون اتصال':
        'Cannot update shop details while offline',
    'تعذر حفظ المنتج بدون جلسة محل صالحة':
        'Cannot save product without a valid shop session',
    'حدث خطأ. حاول مرة أخرى': 'Something went wrong. Please try again',
    'يجب تسجيل الدخول': 'Sign in required',
    'يجب تسجيل الدخول أولاً': 'Please sign in first',
    'تعذر رفع الملف': 'Failed to upload file',
    // --- Shop Offers ---
    'العروض': 'Offers',
    'إعداد عرض المنتج': 'Set Product Offer',
    'تأكيد نسبة العرض': 'Confirm Discount Percentage',
    'السعر الأساسي': 'Base Price',
    'قيمة الخصم (₪)': 'Discount Amount (₪)',
    'قيمة الخصم': 'Discount Amount',
    'أدخل مبلغ الخصم بالشيكل': 'Enter discount amount in ₪',
    'نسبة العرض المحسوبة': 'Calculated Discount',
    'السعر قبل العرض': 'Original Price',
    'السعر بعد العرض': 'Offer Price',
    'متابعة لتأكيد العرض': 'Continue to Confirm',
    'أدخل قيمة خصم صحيحة أقل من سعر المنتج':
        'Enter a valid discount less than the product price',
    'إزالة العرض': 'Remove Offer',
    'تأكيد وتفعيل العرض': 'Confirm & Activate Offer',
    'تعديل قيمة الخصم': 'Edit Discount Amount',
    'تم تفعيل العرض بنجاح': 'Offer activated successfully',
    'تمت إزالة العرض': 'Offer removed',
    'تعذر حفظ العرض': 'Failed to save offer',
    'العروض غير مفعّلة بعد': 'Offers Not Enabled Yet',
    'يمكنك إنشاء العروض على منتجاتك بعد موافقة الإدارة على متجرك.':
        'You can create offers on your products once your shop is approved.',
    'لا توجد منتجات لعمل عروض عليها بعد': 'No Products for Offers Yet',
    'أضف منتجاتك أولاً ثم اضغط على أي منتج هنا لتحديد قيمة الخصم.':
        'Add your products first, then tap any product here to set a discount.',
    'ابحث باسم المنتج لإضافة عرض...': 'Search products to add an offer...',
    'عليها عرض': 'On Offer',
    'بدون عرض': 'No Offer',
    'لا توجد عروض مفعّلة حالياً': 'No Active Offers Yet',
    'اضغط على أي منتج من قائمة الكل لتحديد قيمة الخصم وتفعيل العرض.':
        'Tap any product in All to set a discount and activate an offer.',
    'تأكيد بيانات العرض': 'Confirm Offer Details',
    'تمت جدولة العرض بنجاح': 'Offer scheduled successfully',
    'تأكيد وجدولة العرض': 'Confirm & Schedule Offer',
    'تعديل بيانات العرض': 'Edit Offer Details',
    'وقت بداية العرض': 'Offer Start Time',
    'يبدأ فوراً': 'Start Immediately',
    'تحديد وقت لاحق': 'Schedule for Later',
    'تاريخ ووقت البداية': 'Start Date & Time',
    'مدة العرض': 'Offer Duration',
    '24 ساعة': '24 Hours',
    '3 أيام': '3 Days',
    'أسبوع': '1 Week',
    'أسبوعين': '2 Weeks',
    'شهر': '1 Month',
    'تاريخ مخصص': 'Custom Date',
    'تاريخ ووقت الانتهاء': 'End Date & Time',
    'بداية العرض': 'Offer Starts',
    'نهاية العرض': 'Offer Ends',
    'المدة الإجمالية': 'Total Duration',
    'فوراً': 'Immediately',
    'ينتهي العرض تلقائياً ويعود السعر الأصلي عند انتهاء المدة.':
        'The offer ends automatically and the original price is restored when time expires.',
    'سيعود المنتج لسعره الأصلي تلقائياً بعد انتهاء مدة العرض.':
        'The product will automatically revert to its original price once the offer ends.',
    'عنوان العرض (اختياري)': 'Offer Title (Optional)',
    'عرض محدود': 'Limited Offer',
    'تخفيضات الموسم': 'Season Sale',
    'عرض نهاية الأسبوع': 'Weekend Deal',
    'عرض فلاش': 'Flash Sale',
    'وسم أو عنوان مخصص للعرض': 'Custom Offer Label',
    'مثال: عرض نهاية الأسبوع أو خصم الموسم': 'e.g. Weekend Deal or Season Sale',
    'وقت بداية العرض المجدول يجب أن يكون في المستقبل':
        'Scheduled start time must be in the future',
    'تاريخ نهاية العرض يجب أن يكون بعد وقت البداية وفي المستقبل':
        'Offer end date must be after the start time and in the future',
    'مجدول': 'Scheduled',
    'يبدأ في': 'Starts at',
    'يوم واحد': '1 Day',
    'ساعة واحدة': '1 Hour',
    'أيام': 'days',
    'متبقي يوم واحد': '1 day left',
    'متبقي ساعة واحدة': '1 hour left',
    'ينتهي قريباً': 'Ending soon',
    // --- Shop Banners ---
    'بنرات المتجر': 'Shop Banners',
    'إدارة بنرات العروض والإعلانات الخاصة بمتجرك':
        'Manage your shop promotional & offer banners',
    'التحكم في بنرات العروض والإعلانات الظاهرة للعملاء':
        'Control offer & promo banners shown to customers',
    'عروض المحل': 'Shop Offers',
    'بنر المتجر': 'Shop Banner',
    'تصفح المحل': 'Browse Shop',
    'إضافة بنر جديد': 'Add New Banner',
    'تعديل البنر': 'Edit Banner',
    'عنوان البنر الرئيسي': 'Main Banner Title',
    'مثال: عروض متجرنا — خصم حتى 40%': 'e.g. Our Shop Offers — Up to 40% Off',
    'مثال: عروض مميزة لفترة محدودة — تصفح المحل الآن':
        'e.g. Limited-time deals — Browse our shop now',
    'نص زر التصفح': 'Action Button Label',
    'صورة خلفية البنر (اختياري)': 'Banner Background Image (Optional)',
    'تغيير صورة البنر': 'Change Banner Image',
    'اختيار صورة من الجهاز': 'Pick Image from Device',
    'تفعيل البنر للعملاء': 'Show Banner to Customers',
    'يظهر في الصفحة الرئيسية للعميل وعند الضغط عليه يفتح صفحة متجرك مباشرة.':
        'Appears on the customer home screen and opens your shop directly when tapped.',
    'تعذر حفظ البنر': 'Failed to save banner',
    'تعذر حذف البنر': 'Failed to delete banner',
    'تعذر تحديث حالة البنر': 'Failed to update banner status',
    'تم تفعيل البنر': 'Banner activated',
    'تم إيقاف البنر': 'Banner paused',
    'البنرات غير مفعّلة بعد': 'Banners Not Enabled Yet',
    'يمكنك التحكم في بنرات متجرك بعد موافقة الإدارة على طلب الانضمام.':
        'You can manage your shop banners once your shop application is approved.',
    'تعذر تحميل البنرات': 'Failed to load banners',
    'لا توجد بنرات لمتجرك بعد': 'No Shop Banners Yet',
    'عند تفعيل أي عرض سينزل بنر تلقائي باسم متجرك هنا، أو يمكنك إضافة بنر إعلاني جديد من الزر بالأسفل.':
        'Activating any offer automatically creates a banner for your shop here, or you can add one below.',
    'ابحث في بنرات متجرك...': 'Search your banners...',
    'نشط للعملاء': 'Live to Customers',
    'بنر عروض تلقائي': 'Auto Offer Banner',
    'جرّب تغيير البحث أو اختيار عرض الكل.':
        'Try changing your search or selecting All.',
    // --- Admin Redesign & Gaza Strip Regions ---
    'إدارة المنصة': 'Platform Admin',
    'أقسام التحكم والإدارة': 'Control & Management',
    'مناطق قطاع غزة والتوصيل': 'Gaza Strip Regions & Delivery',
    'المحافظات الخمس والأحياء ورسوم وحالة التوصيل':
        '5 governorates, neighborhoods, delivery fees & status',
    'مراجعة الوثائق وقبول أو رفض المتاجر':
        'Review documents and approve or reject shops',
    'التصنيفات الرئيسية والفرعية': 'Main & Sub Categories',
    'تنظيم أقسام المتجر والمنتجات': 'Organize store & product categories',
    'مراجعة المنتجات وإخفاء أو حذف المخالف':
        'Moderate products and hide or remove violations',
    'العملاء وأصحاب المحلات وحالة الحسابات':
        'Customers, shop owners & account status',
    'الإشعارات الجماعية والموجهة': 'Broadcast & Regional Notifications',
    'إرسال تنبيهات للجميع أو لمناطق محددة في غزة':
        'Send alerts to everyone or specific Gaza areas',
    'التقارير والإحصائيات المفصلة': 'Detailed Reports & Analytics',
    'أداء المنصة وتوزيع المحلات والطلبات في غزة':
        'Platform performance & Gaza governorate breakdown',
    'طلبات انضمام بانتظار المراجعة': 'Pending Shop Applications',
    'هناك متاجر جديدة تنتظر قرار الإدارة بالقبول أو الرفض.':
        'New shops are waiting for admin approval or rejection.',
    'العملاء المسجلون': 'Registered Customers',
    'المنتجات والعروض': 'Products & Offers',
    'عرض نشط': 'active offers',
    'إجمالي المحلات': 'total shops',
    'تعذر تحميل إحصائيات المنصة': 'Failed to load platform stats',
    'اسحب للأسفل لإعادة تحميل البيانات.': 'Pull down to reload data.',
    'ستظهر هنا جميع طلبات المنصة المسجلة خلال اليوم.':
        'All platform orders placed today will appear here.',
    'مناطق غزة': 'Gaza Areas',
    'اختر المنطقة في قطاع غزة': 'Select Area in Gaza Strip',
    'ابحث باسم المحافظة أو الحي في غزة...':
        'Search governorate or neighborhood in Gaza...',
    'ابحث باسم المحافظة أو الحي في قطاع غزة...':
        'Search governorate or neighborhood in Gaza Strip...',
    'كل المحافظات': 'All Governorates',
    'لا توجد مناطق مطابقة للبحث': 'No matching areas found',
    'التوصيل متوقف مؤقتاً': 'Delivery Paused',
    'التوصيل متاح': 'Delivery Available',
    'متوقف مؤقتاً': 'Temporarily Paused',
    'إضافة منطقة أو محافظة': 'Add Region or Governorate',
    'إضافة منطقة في قطاع غزة': 'Add Gaza Region',
    'تعديل المنطقة': 'Edit Region',
    'إضافة حي في': 'Add Neighborhood in',
    'التبعية (محافظة رئيسية أم حي فرعي)': 'Hierarchy (Governorate or Area)',
    'محافظة رئيسية': 'Main Governorate',
    'اسم المنطقة بالعربية *': 'Region Name (Arabic) *',
    'مثال: الرمال الشمالي أو النصيرات': 'e.g. North Rimal or Nuseirat',
    'اسم المنطقة بالإنجليزية (اختياري)': 'Region Name (English, optional)',
    'رسوم التوصيل (₪)': 'Delivery Fee (₪)',
    'ترتيب العرض': 'Sort Order',
    'مدة التوصيل المتوقعة': 'Estimated Delivery Time',
    'مثال: 1 - 2 ساعة أو نفس اليوم': 'e.g. 1 - 2 hours or Same day',
    'التوصيل متاح حالياً': 'Delivery Currently Available',
    'يمكنك إيقاف التوصيل مؤقتاً لهذه المنطقة حسب الظروف الميدانية.':
        'You can pause delivery for this area anytime based on field conditions.',
    'إظهار المنطقة في التطبيق': 'Show Region in App',
    'حفظ المنطقة': 'Save Region',
    'حذف المنطقة': 'Delete Region',
    'تعذر حفظ المنطقة': 'Failed to save region',
    'تعذر حذف المنطقة': 'Failed to delete region',
    'تم حفظ المنطقة بنجاح': 'Region saved successfully',
    'تم حذف المنطقة': 'Region deleted',
    'تعذر تحديث حالة التوصيل': 'Failed to update delivery status',
    'تم تفعيل التوصيل للمنطقة': 'Delivery enabled for region',
    'تم إيقاف التوصيل مؤقتاً للمنطقة': 'Delivery paused for region',
    'تعذر تحميل مناطق قطاع غزة': 'Failed to load Gaza regions',
    'لا توجد مناطق مطابقة': 'No Matching Regions',
    'جرّب تعديل البحث أو إضافة منطقة جديدة من الزر بالأسفل.':
        'Try adjusting search or adding a new region below.',
    'المنطقة في قطاع غزة': 'Area in Gaza Strip',
    'اختر المحافظة أو الحي في قطاع غزة':
        'Choose governorate or neighborhood in Gaza',
    'اختيار من مناطق قطاع غزة': 'Pick from Gaza Strip Areas',
    'اختيار المدينة في قطاع غزة': 'Select City in Gaza Strip',
    'اختر المدينة أو الحي في قطاع غزة':
        'Choose city or neighborhood in Gaza Strip',
    'المدينة *': 'City *',
    'كل المناطق': 'All Regions',
    'المحافظة': 'Governorate',
    'يرجى اختيار المدينة من مناطق قطاع غزة':
        'Please select a city from Gaza Strip areas',
    'يرجى اختيار منطقة معتمدة من قائمة قطاع غزة':
        'Please select an official area from the Gaza Strip list',
    'يرجى تحديث المدينة باختيار منطقة معتمدة من القائمة':
        'Please update your city by selecting an official area from the list',
    'يرجى اختيار المدينة من مناطق قطاع غزة المعتمدة':
        'Please choose your city from the official Gaza Strip areas',
    'يرجى اختيار منطقة التوصيل من قائمة قطاع غزة المعتمدة':
        'Please choose a delivery area from the official Gaza Strip list',
    'منطقة التوصيل في قطاع غزة *': 'Delivery Area in Gaza Strip *',
    'العنوان التفصيلي (الشارع، المعلم القريب)':
        'Detailed Address (Street, Nearby Landmark)',
    'حي': 'areas',
    'مستخدم': 'users',
    'محل': 'shops',
    'المحلات والطلبات': 'Shops & Applications',
    'عرض ملف المحل والوثائق': 'View Shop Profile & Documents',
    'تصفية المحلات حسب منطقة في غزة': 'Filter Shops by Gaza Area',
    'تصفية الطلبات حسب منطقة في غزة': 'Filter Orders by Gaza Area',
    'تصفية المستخدمين حسب منطقة في غزة': 'Filter Users by Gaza Area',
    'ابحث باسم المحل، المالك، أو منطقة غزة...':
        'Search by shop, owner, or Gaza area...',
    'ابحث بالاسم، البريد، الهاتف، أو منطقة غزة...':
        'Search by name, email, phone, or Gaza area...',
    'ابحث برقم الطلب، المتجر، العميل، المنطقة...':
        'Search by order ID, shop, customer, area...',
    'لا توجد محلات مسجلة بعد': 'No Registered Shops Yet',
    'ستظهر هنا جميع المحلات وطلبات الانضمام بمجرد تسجيلها في المنصة.':
        'All shops and applications will appear here once registered.',
    'لا توجد محلات مطابقة': 'No Matching Shops',
    'لا توجد طلبات مطابقة': 'No Matching Orders',
    'جرّب إزالة الفلاتر أو اختيار منطقة أخرى في قطاع غزة.':
        'Try clearing filters or selecting another Gaza area.',
    'حفظ حالة الطلب': 'Save Order Status',
    'عروض المحلات': 'Shop Offers',
    'بنر الإدارة': 'Admin Banner',
    'بنر محل': 'Shop Banner',
    'نص زر البنر': 'Banner CTA Text',
    'الترتيب': 'Order',
    'إلغاء عرض المنتج': 'Cancel Product Offer',
    'تأكيد إلغاء العرض': 'Confirm Cancel Offer',
    'إلغاء هذا العرض': 'Cancel This Offer',
    'إلغاء العرض على المنتج': 'Cancel Product Offer',
    'تم إلغاء العرض بنجاح': 'Offer cancelled successfully',
    'تعذر إلغاء العرض': 'Failed to cancel offer',
    'تعذر تحميل العروض النشطة': 'Failed to load active offers',
    'لا توجد عروض مطابقة': 'No Matching Offers',
    'لا توجد بنرات بعد': 'No Banners Yet',
    'لا توجد بنرات مطابقة': 'No Matching Banners',
    'إخفاء المنتج (مخالف)': 'Hide Product (Violation)',
    'حذف المنتج نهائياً': 'Delete Product Permanently',
    'اسم التصنيف *': 'Category Name *',
    'الوصف (اختياري)': 'Description (Optional)',
    'القسم الرئيسي': 'Parent Department',
    'نوع القسم': 'Department Type',
    'تفعيل التصنيف': 'Enable Category',
    'حفظ التصنيف': 'Save Category',
    'تم حفظ التصنيف بنجاح': 'Category saved successfully',
    'فرعي ضمن': 'Sub-category of',
    'قسم رئيسي': 'Main Department',
    'عملاء': 'Customers',
    'أصحاب محلات': 'Shop Owners',
    'معلّقون': 'Suspended',
    'لا يوجد مستخدمون بعد': 'No Users Yet',
    'لا يوجد مستخدمون مطابقون': 'No Matching Users',
    'الجمهور المستهدف': 'Target Audience',
    'العملاء فقط': 'Customers Only',
    'المحلات فقط': 'Shops Only',
    'تخصيص لمنطقة في قطاع غزة (اختياري)': 'Target Gaza Strip Area (Optional)',
    'كل مناطق قطاع غزة': 'All Gaza Strip Areas',
    'استهداف منطقة في قطاع غزة': 'Target Area in Gaza Strip',
    'عنوان الإشعار *': 'Notification Title *',
    'نص الإشعار *': 'Notification Body *',
    'إرسال الإشعار الآن': 'Send Notification Now',
    'تم إرسال الإشعار بنجاح': 'Notification sent successfully',
    'تعذر إرسال الإشعار': 'Failed to send notification',
    'لا توجد إشعارات مرسلة بعد': 'No Notifications Sent Yet',
    'أرسل أول إشعار للعملاء أو المحلات أو لمناطق محددة في قطاع غزة.':
        'Send your first alert to customers, shops, or specific Gaza areas.',
    'التقارير والإحصائيات': 'Reports & Analytics',
    'ملخص الأداء العام': 'Overall Performance Summary',
    'مبيعات اليوم': 'Today\'s Sales',
    'توزيع حالات الطلبات': 'Order Status Breakdown',
    'قيد التنفيذ': 'In Progress',
    'ملغاة': 'Cancelled',
    'التوزيع حسب محافظات قطاع غزة': 'Breakdown by Gaza Governorates',
    'إعدادات الإدارة والتطبيق': 'Admin & App Settings',
    'الذكاء الاصطناعي وغرفة القياس': 'AI & Virtual Try-On',
    'إعدادات المنصة العامة': 'General Platform Settings',
    'الخروج من حساب الإدارة على هذا الجهاز':
        'Sign out of the admin account on this device',
    'هل تريد تسجيل الخروج من حساب الإدارة؟':
        'Do you want to sign out of the admin account?',
    'لا توجد طلبات معلّقة حالياً': 'No Pending Applications',
    'جميع طلبات الانضمام تمت مراجعتها أو يمكنك عرض الكل.':
        'All applications have been reviewed, or switch to All.',
    'الإيرادات والعمولات والاتفاقيات': 'Revenue, Commissions & Agreements',
    'نسب الاتفاق مع المحلات، المستحقات، وطلبات التسوية':
        'Shop commission agreements, dues, and settlement requests',
    'تسوية': 'settlement',
    'الإيرادات والعمولات': 'Revenue & Commissions',
    'تعذر تحميل بيانات الإيرادات': 'Failed to load revenue data',
    'عمولات المنصة المكتسبة': 'Platform Commissions Earned',
    'مبيعات': 'Sales',
    'المحصّل فعلياً': 'Collected So Far',
    'مستحقات عند المحلات': 'Outstanding at Shops',
    'محل مجمّد مالياً': 'shop(s) on financial hold',
    'تسويات بانتظار التأكيد': 'Pending Settlements',
    'حسابات المحلات': 'Shop Accounts',
    'طلبات التسوية': 'Settlement Requests',
    'لا توجد حسابات محلات بعد': 'No Shop Financial Accounts Yet',
    'ستظهر هنا اتفاقيات العمولات والمستحقات المالية لكل محل.':
        'Commission agreements and balances for each shop will appear here.',
    'لا توجد طلبات تسوية معلّقة': 'No Pending Settlement Requests',
    'ستظهر هنا إيصالات السداد المرفوعة من المحلات لمراجعتها واعتمادها.':
        'Payment receipts submitted by shops will appear here for review.',
    'اعتماد الاستلام': 'Confirm Receipt',
    'الاتفاقية الحالية': 'Current Agreement',
    'سقف الذمة المسموح': 'Allowed Credit Limit',
    'المستحق حالياً على المحل': 'Current Shop Dues',
    'تنبيه: نسبة الإلغاء': 'Warning: Cancellation Rate',
    'تعديل اتفاقية العمولة والسقف': 'Edit Commission Agreement & Limit',
    'تسجيل دفعة سداد مستلمة': 'Record Received Payment',
    'كشف الحساب التفصيلي': 'Detailed Account Ledger',
    'فك التجميد المالي للمحل': 'Lift Financial Hold',
    'تجميد مالي مؤقت للمحل': 'Place Temporary Financial Hold',
    'تم فك التجميد المالي للمحل': 'Financial hold lifted for shop',
    'تم تفعيل التجميد المالي للمحل': 'Financial hold activated for shop',
    'تعذر تحديث الحالة المالية': 'Failed to update financial status',
    'اتفاقية العمولة': 'Commission Agreement',
    'نوع احتساب العمولة': 'Commission Type',
    'نسبة مئوية (%)': 'Percentage (%)',
    'مبلغ ثابت (₪)': 'Fixed Fee (₪)',
    'هجين (% + ₪)': 'Hybrid (% + ₪)',
    'نسبة المنصة (%)': 'Platform Rate (%)',
    'مثال: 5': 'e.g. 5',
    'مبلغ ثابت لكل طلب (₪)': 'Fixed Fee per Order (₪)',
    'سقف الذمة المالية المسموح (₪)': 'Allowed Credit Limit (₪)',
    'مثال: 300': 'e.g. 300',
    'دورة التسوية والسداد': 'Settlement Cycle',
    'أسبوعياً': 'Weekly',
    'كل أسبوعين': 'Biweekly',
    'شهرياً': 'Monthly',
    'تجميد تلقائي عند تجاوز السقف': 'Auto-Hold When Limit Reached',
    'يتم تجميد المحل تلقائياً عند بلوغ سقف الذمة حتى سداد المستحقات.':
        'Automatically places the shop on financial hold once dues reach the credit limit.',
    'بنود أو ملاحظات الاتفاق (اختياري)': 'Agreement Terms / Notes (Optional)',
    'حفظ الاتفاقية': 'Save Agreement',
    'تعذر حفظ الاتفاقية': 'Failed to save agreement',
    'تم تحديث اتفاقية العمولة بنجاح':
        'Commission agreement updated successfully',
    'تسجيل دفعة مستلمة': 'Record Received Payment',
    'المبلغ المستلم (₪) *': 'Amount Received (₪) *',
    'أدخل مبلغاً صحيحاً أكبر من صفر': 'Enter a valid amount greater than zero',
    'طريقة التحصيل': 'Collection Method',
    'نقداً (كاش)': 'Cash',
    'تحويل بنكي': 'Bank Transfer',
    'جوال باي': 'Jawwal Pay',
    'بال باي': 'PalPay',
    'رقم الإيصال / الحوالة (اختياري)': 'Receipt / Transfer Ref (Optional)',
    'تأكيد تسجيل الدفعة': 'Confirm Payment Entry',
    'تعذر تسجيل الدفعة': 'Failed to record payment',
    'تم تسجيل الدفعة وتحديث رصيد المحل': 'Payment recorded and balance updated',
    'كشف حساب': 'Account Ledger',
    'تعذر تحميل كشف الحساب': 'Failed to load account ledger',
    'لا توجد حركات مالية بعد': 'No Financial Entries Yet',
    'ستظهر هنا عمولات الطلبات المسلّمة ودفعات السداد المؤكدة.':
        'Delivered order commissions and confirmed payments will appear here.',
    'اعتماد دفعة التسوية': 'Approve Settlement Payment',
    'رفض طلب التسوية': 'Reject Settlement Request',
    'تأكيد استلام مبلغ': 'Confirm receiving',
    'اكتب سبب رفض طلب التسوية ليظهر لصاحب المحل.':
        'Enter the rejection reason to show to the shop owner.',
    'ملاحظة الإدارة (اختياري)': 'Admin Note (Optional)',
    'تأكيد الاستلام والخصم': 'Confirm Receipt & Deduct',
    'تم اعتماد التسوية وتحديث الذمة': 'Settlement approved and balance updated',
    'تم رفض طلب التسوية': 'Settlement request rejected',
    'الاتفاقية موثّقة': 'Agreement Accepted',
    'بانتظار موافقة المحل': 'Awaiting Shop Acceptance',
    'تجميد مالي': 'Financial Hold',
    'إلغاء مرتفع': 'High Cancellation',
    'المبيعات المسلّمة': 'Delivered Sales',
    'حصة المنصة / المسدّد': 'Platform Fee / Paid',
    'المستحق حالياً': 'Current Balance Due',
    'دفعة سداد': 'Settlement Payment',
    'تعديل إداري': 'Admin Adjustment',
    'عمولة طلب': 'Order Commission',
    'بانتظار التأكيد': 'Awaiting Confirmation',
    'تعذر توثيق الموافقة': 'Failed to record acceptance',
    'تم توثيق موافقتك على اتفاقية العمولة':
        'Your acceptance of the commission agreement has been recorded',
    'تقديم طلب سداد وتسوية': 'Submit Settlement Payment',
    'المستحق الحالي للمنصة': 'Current Dues to Platform',
    'مبلغ السداد (₪) *': 'Payment Amount (₪) *',
    'رقم الحوالة أو الإيصال (اختياري)':
        'Transfer / Receipt Reference (Optional)',
    'إرفاق صورة الإيصال (اختياري)': 'Attach Receipt Photo (Optional)',
    'تم إرفاق الإيصال — تغيير الصورة': 'Receipt Attached — Change Photo',
    'ملاحظات للإدارة (اختياري)': 'Notes for Admin (Optional)',
    'إرسال طلب التسوية للمراجعة': 'Submit Settlement for Review',
    'تعذر إرسال طلب التسوية': 'Failed to submit settlement request',
    'تم إرسال طلب التسوية وستقوم الإدارة بمراجعته':
        'Settlement submitted and awaiting admin review',
    'موافقة مطلوبة على اتفاقية العمولة': 'Commission Agreement Approval Needed',
    'نسبة المنصة المتفق عليها': 'Agreed Platform Commission',
    'سقف الذمة': 'Credit Limit',
    'التسوية': 'Settlement',
    'أوافق على اتفاقية العمولة': 'Accept Commission Agreement',
    'المتجر في حالة تجميد مالي مؤقت': 'Shop Is on Temporary Financial Hold',
    'تجاوزت المستحقات سقف الذمة المسموح. يرجى تقديم طلب تسوية لإعادة تفعيل المتجر فور التأكيد.':
        'Your dues reached the credit limit. Submit a settlement to reactivate your shop once confirmed.',
    'تقديم طلب سداد الآن': 'Submit Payment Now',
    'اقتربت من سقف الذمة المالية': 'Approaching Credit Limit',
    'صافي أرباح المحل (المسلّمة)': 'Net Shop Earnings (Delivered)',
    'حصة المنصة': 'Platform Commission',
    'اتفاقية العمولة والمستحقات': 'Commission Agreement & Dues',
    'دورة التسوية': 'Settlement Cycle',
    'تم سداده للمنصة': 'Paid to Platform',
    'المستحق الحالي للسداد': 'Current Balance Due',
    'تقديم طلب سداد / تسوية': 'Submit Payment / Settlement',
    'طلبات التسوية المرسلة': 'Submitted Settlements',
    'كشف الحركات المالية': 'Financial Ledger',
    'تُسجّل عمولة كل طلب تلقائياً هنا فور تسليم الطلب للعميل.':
        'Order commissions are automatically logged here once delivered.',
    'الأعلى مستحقات': 'Highest Dues',
    'الأعلى مبيعات': 'Highest Sales',
    'الأعلى عمولة': 'Highest Commission',
    'الأقرب للسقف': 'Nearest Credit Limit',
    'الأعلى إلغاءً': 'Highest Cancellation',
    'الاسم (أ - ي)': 'Name (A - Z)',
    'الأحدث أولاً': 'Newest First',
    'الأقدم أولاً': 'Oldest First',
    'الأعلى مبلغاً': 'Highest Amount',
    'الأقل مبلغاً': 'Lowest Amount',
    'ترتيب حسابات المحلات': 'Sort Shop Accounts',
    'ترتيب طلبات التسوية': 'Sort Settlement Requests',
    'فلترة متقدمة للحسابات المالية': 'Advanced Financial Filters',
    'حالة الذمة والمخاطر': 'Balance & Risk Status',
    'عليها مستحقات': 'Has Dues',
    'قرب/تجاوز السقف': 'Near / Over Limit',
    'بانتظار الموافقة': 'Awaiting Approval',
    'خالي الذمة': 'Settled (Zero Due)',
    'حالة توثيق الاتفاقية': 'Agreement Status',
    'نطاق المستحقات المالية (₪)': 'Outstanding Balance Range (₪)',
    'من (₪)': 'Min (₪)',
    'إلى (₪)': 'Max (₪)',
    'لديها طلبات تسوية معلّقة فقط': 'With pending settlements only',
    'لديها تسوية معلّقة': 'Has pending settlement',
    'تسوية معلّقة': 'pending settlement',
    'فلترة طلبات التسوية': 'Filter Settlement Requests',
    'مرفق الإيصال': 'Receipt Attachment',
    'بإيصال مرفق': 'With Receipt',
    'بدون إيصال': 'Without Receipt',
    'نطاق مبلغ التسوية (₪)': 'Settlement Amount Range (₪)',
    'ابحث باسم المحل أو المنطقة في غزة...': 'Search by shop or Gaza area...',
    'ابحث باسم المحل أو رقم الحوالة...':
        'Search by shop name or transfer ref...',
    'المستحق': 'Due',
    'مبيعات النتائج': 'Filtered Sales',
    'عمولات النتائج': 'Filtered Fees',
    'مستحقات النتائج': 'Filtered Dues',
    'إجمالي مبالغ الطلبات المصفّاة': 'Total Filtered Settlements',
    'لا توجد حسابات مطابقة للفلاتر': 'No Accounts Match Filters',
    'جرّب تعديل معايير الفلترة أو الضغط على مسح الكل لعرض جميع المحلات.':
        'Try adjusting your filters or tap Clear All to view all shops.',
    'لا توجد طلبات تسوية مطابقة': 'No Matching Settlement Requests',
    'جرّب تعديل البحث أو إزالة الفلاتر لعرض جميع الطلبات المعلّقة.':
        'Try adjusting your search or clearing filters.',
    'إعادة تعيين': 'Reset',
    'المبلغ': 'Amount',
    'منطقة قطاع غزة': 'Gaza Strip Area',
    'حساب الإدارة': 'Admin Account',
    'تعديل بيانات حساب الإدارة': 'Edit Admin Account Details',
    'الاسم الكامل، رقم الهاتف، المنطقة، والعنوان':
        'Full name, phone number, area, and address',
    'يرجى كتابة الاسم الكامل': 'Please enter your full name',
    'تم حفظ بيانات حساب الإدارة بنجاح':
        'Admin account details saved successfully',
    'إعدادات المنصة والذكاء الاصطناعي': 'Platform & AI Settings',
    'تجربة الملابس — Decart API': 'Virtual Try-On — Decart API',
    'مفتاح ربط خدمة تجربة الملابس بالذكاء الاصطناعي':
        'API key for AI virtual try-on service',
    'مفتاح محفوظ ومشفّر بأمان — اضغط للاستبدال':
        'Key securely encrypted — tap to replace',
    'لم يتم إعداد مفتاح Decart بعد': 'Decart API key not configured yet',
    'مدة الجلسة والحد اليومي وتفعيل الخدمة':
        'Session duration, daily limit, and service toggle',
    'مفعّلة': 'Enabled',
    'ثانية': 'sec',
    'محاولة/يوم': 'tries/day',
    'تعديل الثوابت والقيم العامة': 'Edit general constants and values',
    'تعديل الثوابت والقيم العامة للتطبيق': 'Edit general app settings & values',
    'لا توجد إعدادات عامة بعد': 'No General Settings Yet',
    'ستظهر هنا ثوابت وإعدادات المنصة بمجرد إضافتها.':
        'Platform constants and settings will appear here once added.',
    'توكن': 'cr',
    'مفتاح منتهي': 'Invalid Key',
    'رصيد توكن Decart API': 'Decart API Token Balance',
    'جارٍ فحص الرصيد...': 'Checking balance...',
    'يلزم تحديث الدالة': 'Update Function',
    'غير مُعدّ': 'Not Set',
    'مفتاح غير صالح': 'Invalid Key',
    'نفد الرصيد': 'Out of Credits',
    'رصيد منخفض': 'Low Balance',
    'الرصيد نشط': 'Active',
    'تعذر الفحص': 'Check Failed',
    'الرصيد المتبقي في Decart API': 'Remaining Decart API Balance',
    'يعادل تقريباً': 'Approx.',
    'أعد نشر Edge Function (decart-session) في Supabase لقراءة الرصيد المباشر.':
        'Redeploy the decart-session Edge Function in Supabase to fetch live balance.',
    'رفض Decart المفتاح الحالي. يرجى تحديثه أدناه.':
        'Decart rejected the current key. Please update it below.',
    'تحديث الرصيد': 'Refresh Balance',
    'رصيد Decart API والقياس الافتراضي': 'Decart API Balance & Virtual Try-On',
    'إعدادات الجلسة الحالية': 'Current Session Controls',
    'تحديث مفتاح Decart API': 'Update Decart API Key',
    'إجمالي توكن Decart API': 'Total Decart API Tokens',
    'مفاتيح نشطة': 'active keys',
    'إجمالي التوكن المتبقية (كل المفاتيح)': 'Total Remaining Tokens (All Keys)',
    'تبديل تلقائي ذكي': 'Smart Auto-Failover',
    'رفض Decart المفاتيح الحالية. يرجى إضافة مفتاح جديد أدناه.':
        'Decart rejected the current keys. Please add a new key below.',
    'توزيع الرصيد حسب المفاتيح': 'Balance Breakdown by Key',
    'إدارة وإضافة مفاتيح Decart API': 'Manage & Add Decart API Keys',
    'إدارة مفاتيح Decart API': 'Manage Decart API Keys',
    'غير صالح': 'Invalid',
    'قيد الفحص': 'Checking',
    'منخفض': 'Low',
    'محفوظ': 'Saved',
    'المفاتيح المضافة': 'Configured Keys',
    'تبديل تلقائي عند النفاد': 'Auto-Failover on Depletion',
    'إضافة مفتاح Decart API جديد': 'Add New Decart API Key',
    'اسم تعريفي للمفتاح (اختياري)': 'Key Label (Optional)',
    'مثال: حساب أساسي / احتياطي 2': 'e.g. Primary / Backup 2',
    'تُحفظ جميع المفاتيح مشفّرة في السيرفر، ويقوم النظام تلقائياً بحساب مجموع التوكن والانتقال للمفتاح التالي فور نفاد أي مفتاح دون انقطاع للعميل.':
        'All keys are encrypted on the server. Total tokens are summed automatically and failover switches to the next key seamlessly.',
    'إضافة المفتاح للقائمة': 'Add Key to Pool',
    'تمت إضافة المفتاح بنجاح وتفعيله ضمن التبديل التلقائي الذكي.':
        'Key added and enabled for smart auto-failover.',
    'تعذر تحديث حالة المفتاح': 'Failed to update key status',
    'تم حذف المفتاح من القائمة': 'Key removed from pool',
    'تعذر حذف المفتاح': 'Failed to remove key',
    'الرصيد: --': 'Balance: --',
    'حذف المفتاح': 'Delete Key',
    'خدمة التجربة الافتراضية غير متاحة مؤقتاً لانتهاء الرصيد. يرجى المحاولة لاحقاً.':
        'Virtual try-on is temporarily unavailable due to depleted balance. Please try again later.',
    'تعذر العثور على المستخدم محلياً': 'Unable to find user locally',
    'تعذر العثور على المحل محلياً': 'Unable to find shop locally',
    'نفس اليوم': 'Same Day',
    'المستخدمون': 'Users',
    'تم حفظ البنر بنجاح': 'Banner saved successfully',
    'تعذر الحذف': 'Failed to delete',
    'تم حذف البنر': 'Banner deleted',
    'بنر إعلاني جديد': 'New Promo Banner',
    'العنوان الرئيسي *': 'Main Title *',
    'مثال: خصم 30% على تشكيلة الموسم': 'e.g. 30% off seasonal collection',
    'النص الفرعي (اختياري)': 'Subtitle (Optional)',
    'مثال: تسوق أحدث الأزياء مع توصيل لمناطق غزة':
        'e.g. Shop latest fashion with Gaza delivery',
    'إزالة': 'Remove',
    'تفعيل البنر للمستخدمين': 'Enable Banner for Users',
    'يظهر فوراً في الصفحة الرئيسية للعميل عند التفعيل':
        'Appears immediately on the customer home screen when enabled',
    'حفظ البنر': 'Save Banner',
    'حذف البنر': 'Delete Banner',
    'إضافة بنر إعلاني': 'Add Promo Banner',
    'أضف بنراً إعلانياً للمنصة أو انتظر بنرات العروض التلقائية للمحلات.':
        'Add a platform promo banner or wait for automatic shop offer banners.',
    'متوقف': 'Inactive',
    'جرّب تغيير البحث أو إزالة الفلتر.':
        'Try changing search or clearing filters.',
    'لا توجد عروض نشطة حالياً': 'No Active Offers Currently',
    'ستظهر هنا جميع منتجات المحلات التي عليها خصومات حالياً للمراجعة والرقابة.':
        'All discounted shop products will appear here for review.',
    'ابحث باسم المنتج أو المحل أو المنطقة...':
        'Search by product, shop, or area...',
    'جرّب تعديل كلمة البحث.': 'Try adjusting your search query.',
    'افتراضي': 'Default',
    'تصنيف جديد': 'New Category',
    'تعديل التصنيف': 'Edit Category',
    'تصنيف رئيسي مستقل': 'Standalone Main Category',
    'تعذر تحميل التصنيفات': 'Failed to load categories',
    'لا توجد تصنيفات بعد': 'No Categories Yet',
    'أضف أول تصنيف رئيسي لتنظيم منتجات المتاجر.':
        'Add your first main category to organize store products.',
    'ابحث باسم التصنيف...': 'Search by category name...',
    'لا توجد تصنيفات مطابقة': 'No Matching Categories',
    'جرّب تعديل البحث أو إزالة الفلتر.':
        'Try adjusting search or clearing filters.',
    'المحلات المعتمدة': 'Approved Shops',
    'طلبات انضمام المحلات': 'Shop Applications',
    'إرسال إشعار جديد': 'Send New Notification',
    'المنطقة': 'Area',
    'مثال: عروض جديدة في غزة أو تحديث التوصيل':
        'e.g. New offers in Gaza or delivery update',
    'اكتب تفاصيل الإشعار بوضوح...': 'Write notification details clearly...',
    'نص الإشعار': 'Notification Body',
    'ستظهر هنا جميع طلبات المنصة مع إمكانية متابعة حالتها وتحديثها.':
        'All platform orders will appear here for tracking and status updates.',
    'تعذر تحديث المنتج': 'Failed to update product',
    'تم تحديث حالة المنتج': 'Product status updated',
    'ابحث باسم المنتج أو المحل...': 'Search by product or shop...',
    'جرّب تعديل الفلاتر أو البحث بكلمة أخرى.':
        'Try adjusting filters or searching another term.',
    'اسم المنطقة': 'Area Name',
    'تعذر تحميل التقارير': 'Failed to load reports',
    'العروض النشطة': 'Active Offers',
    'مجمّد مالياً': 'Financial Hold',
    'ملاحظات (اختياري)': 'Notes (Optional)',
    'سبب الرفض *': 'Rejection Reason *',
    'تأكيد الرفض': 'Confirm Rejection',
    'تعذر تنفيذ الإجراء': 'Failed to complete action',
    'رفض': 'Reject',
    'إعادة تحميل إعدادات المنصة': 'Reload Platform Settings',
    'القيمة': 'Value',
    'تم تحديث الإعداد': 'Setting updated',
    'الإدارة': 'Admin',
    'المتبقي': 'Remaining',
    'الخدمة متوقفة مؤقتاً لتوفير التكلفة':
        'Service temporarily paused to save costs',
    'إدارة المحافظات الخمس والأحياء ورسوم التوصيل':
        'Manage all 5 governorates, areas, and delivery fees',
    'إرسال تنبيهات للعملاء والمحلات ومناطق غزة':
        'Send alerts to customers, shops, and Gaza areas',
    'تعليق المحل': 'Suspend Shop',
    'إعادة تفعيل المحل': 'Reactivate Shop',
    'تعذر تحديث المحل': 'Failed to update shop',
    'تم تعليق المحل': 'Shop suspended',
    'تم إعادة تفعيل المحل': 'Shop reactivated',
    'تعذر تحميل المحلات': 'Failed to load shops',
    'معتمد': 'Approved',
    'معلّق': 'Suspended',
    'تعذر تحميل طلبات الانضمام': 'Failed to load shop applications',
    'لا توجد طلبات انضمام بعد': 'No Shop Applications Yet',
    'ستظهر هنا طلبات المتاجر الجديدة لمراجعة بياناتها ووثائقها.':
        'New shop applications and their documents will appear here for review.',
    'ابحث باسم المحل، المالك، أو المنطقة...':
        'Search by shop, owner, or area...',
    'قبول المحل': 'Approve Shop',
    'تأكيد القبول': 'Confirm Approval',
    'تعذر قبول الطلب': 'Failed to approve application',
    'تم قبول الطلب': 'Application approved',
    'رفض المحل': 'Reject Shop',
    'اكتب سبب الرفض. سيظهر للمحل حسب إعداد تأخير القرار.':
        'Enter the rejection reason. It will be shown to the shop.',
    'تعذر رفض الطلب': 'Failed to reject application',
    'تم رفض الطلب': 'Application rejected',
    'مراجعة المحل': 'Review Shop',
    'الشعار': 'Logo',
    'تعذر عرض الشعار': 'Failed to load logo',
    'صور المحل': 'Shop Photos',
    'لا توجد صور مرفوعة': 'No photos uploaded',
    'المستندات': 'Documents',
    'لا توجد مستندات مرفوعة لهذا المحل بعد':
        'No documents uploaded for this shop yet',
    'تعذر فتح المستند': 'Failed to open document',
    'اضغط لإنشاء رابط مؤقت للعرض': 'Tap to generate temporary viewing link',
    'قبول': 'Approve',
    'تفعيل الحساب': 'Activate Account',
    'تعليق الحساب': 'Suspend Account',
    'تعذر تحديث الحساب': 'Failed to update account',
    'تم تفعيل الحساب': 'Account activated',
    'تم تعليق الحساب': 'Account suspended',
    'تعذر تحميل المستخدمين': 'Failed to load users',
    'ستظهر هنا حسابات العملاء وأصحاب المحلات فور تسجيلهم.':
        'Customer and shop owner accounts will appear here once registered.',
    'لا توجد بيانات': 'No Data',
    'العميل': 'Customer',
    'الإجمالي': 'Total',
    'تحديث حالة الطلب': 'Update Order Status',
    'تعذر تحديث الطلب': 'Failed to update order',
    'هذا الإعداد متاح للأدمن النشط فقط.':
        'This setting is available to active admins only.',
    'خدمة حفظ المفتاح غير مكتملة على السيرفر. يلزم مراجعة تحديثات قاعدة البيانات.':
        'Key storage service is incomplete on server. Check database migrations.',
    'رفض السيرفر صيغة المفتاح. تأكد من صحة المفتاح وتطبيق تحديث قاعدة البيانات.':
        'Server rejected key format. Verify key and database migrations.',
    'يوجد خطأ في قاعدة التحقق من المفتاح على السيرفر. يلزم تطبيق تحديث قاعدة البيانات.':
        'Server key validation rule error. Apply latest database migration.',
    'جلسة تسجيل الدخول غير صالحة. سجّل الدخول مجدداً ثم أعد المحاولة.':
        'Session is invalid. Please sign in again and retry.',
    'رفض السيرفر حفظ المفتاح. يلزم فحص الخطأ في قاعدة البيانات.':
        'Server rejected saving key. Check database error.',
    'تعذر التحقق من جلسة الدخول. سجّل الدخول مجدداً ثم أعد المحاولة.':
        'Could not verify login session. Sign in again and retry.',
    'انتهت مهلة الحفظ دون تأكيد النتيجة. حدّث حالة الإعداد قبل المحاولة مجدداً.':
        'Save timed out without confirmation. Refresh status before retrying.',
    'تعذر الاتصال بالسيرفر لتأكيد الحفظ. تحقق من الاتصال وحاول مجدداً.':
        'Could not connect to server to confirm save. Check connection and retry.',
    'تعذر تأكيد حفظ المفتاح بسبب خطأ غير متوقع في التطبيق.':
        'Could not confirm saving key due to an unexpected app error.',
    'جارٍ الحفظ…': 'Saving…',
    'لا يوجد اتصال بالإنترنت. تأكد من تشغيل الواي فاي أو بيانات الهاتف ثم حاول مرة أخرى.':
        'No internet connection. Please turn on Wi-Fi or mobile data and try again.',
    'الجهاز متصل بالشبكة لكن لا يوجد إنترنت فعلي أو تعذر الوصول للخادم. تحقق من اتصالك وحاول مجدداً.':
        'Connected to a network, but no active internet or server unreachable. Please check your connection.',
    'انتهت مهلة الاتصال بسبب بطء الإنترنت أو عدم استجابة الخادم. حاول مرة أخرى.':
        'Connection timed out due to slow internet or server delay. Please try again.',
    'انقطع الاتصال بالإنترنت أثناء تنفيذ العملية. تأكد من استقرار الشبكة وأعد المحاولة.':
        'Internet connection dropped during the operation. Check stability and try again.',
    'الخادم غير متاح مؤقتاً حالياً. يرجى المحاولة مرة أخرى بعد قليل.':
        'Server is temporarily unavailable. Please try again shortly.',
    'حدث خطأ غير متوقع. حاول مرة أخرى.':
        'An unexpected error occurred. Please try again.',
    'كلمة المرور غير مقبولة (يجب أن تكون 6 أحرف على الأقل)':
        'Password is invalid (must be at least 6 characters)',
    'محاولات كثيرة متتالية. انتظر قليلاً ثم أعد المحاولة.':
        'Too many attempts. Please wait a moment and try again.',
    'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مجدداً.':
        'Your session has expired. Please sign in again.',
    'تعذر إتمام المصادقة. تحقق من بياناتك واتصالك بالإنترنت.':
        'Authentication failed. Please check your details and internet connection.',
    'ليس لديك صلاحية لتنفيذ هذا الإجراء.':
        'You do not have permission to perform this action.',
    'هذه البيانات مسجلة مسبقاً ولا يمكن تكرارها.':
        'This data already exists and cannot be duplicated.',
    'لا يمكن تنفيذ العملية لارتباط هذا العنصر ببيانات أخرى.':
        'Cannot complete this action because this item is linked to other records.',
    'صيغة البيانات المدخلة غير صحيحة. راجع الحقول وحاول مجدداً.':
        'Invalid input format. Please check the fields and try again.',
    'استغرق الخادم وقتاً أطول من المعتاد. حاول مرة أخرى.':
        'The server took too long to respond. Please try again.',
    'هذه الخدمة غير مهيأة بالكامل على الخادم بعد.':
        'This service is not fully configured on the server yet.',
    'حجم الملف كبير جداً. اختر صورة أو ملفاً أصغر وحاول مجدداً.':
        'File is too large. Choose a smaller image or file and try again.',
    'صيغة الملف غير مدعومة. يرجى اختيار صورة بصيغة JPG أو PNG.':
        'Unsupported file format. Please choose a JPG or PNG image.',
    'انتهت الجلسة أو ليس لديك صلاحية لرفع الملفات.':
        'Session expired or you lack permission to upload files.',
    'تعذر رفع الملف إلى الخادم. تحقق من الإنترنت وحجم الملف وحاول مجدداً.':
        'Failed to upload file. Check your internet connection and file size.',
    'انتهت جلسة الدخول أو غير مصرح بتنفيذ هذا الإجراء.':
        'Session expired or unauthorized for this action.',
    'الخدمة المطلوبة غير متوفرة حالياً على الخادم.':
        'The requested service is currently unavailable on the server.',
    'طلبات كثيرة متتالية. انتظر قليلاً ثم أعد المحاولة.':
        'Too many requests. Please wait a moment and try again.',
    'تعذر إعداد الجلسة. تحقق من تسجيل الدخول واتصالك بالإنترنت.':
        'Could not prepare session. Check your sign-in and internet connection.',
    'تأكيد البريد الإلكتروني': 'Verify Email Address',
    'تحقق من بريدك الإلكتروني': 'Verify Your Email',
    'أدخل رمز التحقق': 'Enter Verification Code',
    'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى بريدك الإلكتروني':
        'Enter the 6-digit verification code sent to your email',
    'أدخل رمز التحقق المكوّن من 6 أرقام':
        'Enter the 6-digit verification code',
    'لصق الرمز': 'Paste Code',
    'لم يصلك الرمز؟': "Didn't receive the code?",
    'إعادة إرسال الرمز': 'Resend Code',
    'لا يوجد رمز مكوّن من 6 أرقام في الحافظة':
        'No 6-digit code found in clipboard',
    'لحماية المنصة من الحسابات الوهمية، أرسلنا رمز تحقق إلى بريدك الإلكتروني:':
        'To protect the platform from fake accounts, we sent a verification code to your email:',
    'رمز التحقق (OTP)': 'Verification Code (OTP)',
    'أدخل رمز التحقق المكون من 6 أرقام على الأقل':
        'Enter the verification code (at least 6 digits)',
    'تفقّد صندوق الوارد أو مجلد الرسائل غير المرغوب فيها (Spam).':
        'Check your inbox or Spam/Junk folder.',
    'تأكيد الرمز وإتمام التسجيل': 'Verify Code & Complete Registration',
    'إعادة إرسال الرمز بعد': 'Resend code in',
    'إعادة إرسال رمز التحقق': 'Resend Verification Code',
    'تغيير البريد الإلكتروني': 'Change Email Address',
    'تم إرسال رمز التحقق إلى بريدك الإلكتروني':
        'Verification code sent to your email',
    'تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني':
        'A new verification code was sent to your email',
    'تم تأكيد بريدك الإلكتروني بنجاح': 'Your email has been verified',
    'تعذر إعادة إرسال رمز التحقق': 'Failed to resend verification code',
    'رمز التحقق غير صحيح أو منتهي الصلاحية':
        'Verification code is invalid or expired',
    'رمز التحقق غير صحيح أو منتهي الصلاحية. تأكد من الرمز أو اطلب رمزاً جديداً.':
        'Verification code is invalid or expired. Check the code or request a new one.',
    'يرجى الانتظار 60 ثانية قبل طلب رمز تحقق جديد.':
        'Please wait 60 seconds before requesting a new code.',
    'انتهت جلسة التسجيل المؤقتة. يرجى الرجوع وإعادة إدخال بياناتك.':
        'Your temporary signup session expired. Please go back and re-enter your details.',
    'تعذر معالجة رمز التحقق. حاول مجدداً.':
        'Could not process the verification code. Please try again.',
    'تعذر الاتصال بخدمة التحقق من البريد. حاول مجدداً.':
        'Could not reach the email verification service. Please try again.',
    'رقم الهاتف مسجل مسبقاً لحساب آخر':
        'This phone number is already registered to another account',
    'تأكيد تسجيل الدخول': 'Verify Sign In',
    'تأكيد الرمز وتسجيل الدخول': 'Verify Code & Sign In',
    'تم تسجيل الدخول بنجاح': 'Signed in successfully',
    'انتهت جلسة الدخول المؤقتة. يرجى الرجوع وإعادة إدخال بياناتك.':
        'Your temporary sign-in session expired. Please go back and re-enter your details.',
    'تجربة إشعار عند إغلاق التطبيق (خلال 5 ثوانٍ)':
        'Test closed-app notification (in 5s)',
    'سيصل إشعار تجريبي خلال 5 ثوانٍ — أغلق التطبيق الآن وشاهد ظهوره!':
        'A test notification will arrive in 5 seconds — close the app now to see it!',
    'FCM متصل — تصلك الإشعارات حتى عند إغلاق التطبيق':
        'FCM connected — notifications arrive even when the app is closed',
    'مفعّلة — بانتظار ربط Firebase (FCM) للإشعارات خارج التطبيق':
        'Enabled — waiting for Firebase (FCM) setup for closed-app push',
    'خدمة FCM غير مربوطة بعد في التطبيق — أضف google-services.json أو مفاتيح Firebase في .env ثم أعد تشغيل التطبيق.':
        'FCM is not connected in the app yet — add google-services.json or Firebase keys in .env and restart.',
    'تم جدولة إشعار FCM — أغلق التطبيق الآن، سيصلك خلال 5 ثوانٍ!':
        'FCM push scheduled — close the app now, it will arrive in 5 seconds!',
    'تعذر إرسال إشعار FCM من الخادم.':
        'Failed to send FCM notification from server.',
    'تعذر الاتصال بخدمة إشعارات FCM على الخادم.':
        'Could not reach the FCM push service on the server.',
    'تعذر إرسال إشعار FCM. تحقق من الاتصال بالإنترنت.':
        'Failed to send FCM notification. Check your internet connection.',
    'يرجى تسجيل الدخول أولاً لاختبار إشعارات FCM.':
        'Please sign in first to test FCM notifications.',
    // --- Dual Delivery + Gaza Banks/Wallets + Receipt Verification ---
    'طريقة التوصيل': 'Delivery Method',
    'توصيل من المحل': 'Shop Delivery',
    'توصيل من الزبون': 'Customer Pickup / Own Courier',
    'يوصلها المتجر لعنوانك': 'Delivered to your address by the shop',
    'بدون رسوم توصيل': 'No delivery fee',
    'لن يتم إضافة رسوم توصيل — ستقوم بإرسال مندوبك أو الاستلام من المتجر بعد تأكيد الحوالة.':
        'No delivery fee will be added — you will send your courier or pick up after receipt verification.',
    'رقم هاتف التواصل': 'Contact Phone Number',
    'ملاحظات الاستلام أو اسم المندوب (اختياري)':
        'Pickup notes or courier name (optional)',
    'قيمة المنتجات': 'Items Subtotal',
    'رسوم التوصيل (من المحل)': 'Delivery Fee (Shop Delivery)',
    'رسوم التوصيل (توصيل الزبون)': 'Delivery Fee (Customer Pickup)',
    'المبلغ المطلوب تحويله': 'Amount to Transfer',
    'التحويل البنكي أو المحفظة وإشعار الدفع': 'Bank / Wallet Transfer & Receipt',
    'جاري تحميل طرق الدفع المتاحة...': 'Loading available payment methods...',
    'تعذر تحميل أرقام البنوك والمحافظ': 'Could not load bank & wallet accounts',
    'لا توجد وسائل دفع مفعّلة حالياً من الإدارة. يرجى المحاولة لاحقاً.':
        'No payment methods are currently enabled by admin. Please try later.',
    'حساب بنكي': 'Bank Account',
    'محفظة إلكترونية': 'E-Wallet',
    'اسم المستفيد': 'Account Holder',
    'رقم المحفظة للتحويل': 'Wallet Number for Transfer',
    'رقم الحساب للتحويل': 'Account Number for Transfer',
    'رقم المحفظة': 'Wallet Number',
    'رقم الحساب': 'Account Number',
    'تم نسخ': 'Copied',
    'إشعار الحوالة المالية *': 'Transfer Receipt *',
    'إشعار الحوالة المالية': 'Transfer Receipt',
    'إشعار الحوالة المرفق': 'Attached Transfer Receipt',
    'مطلوب': 'Required',
    'جاري رفع صورة إشعار الحوالة...': 'Uploading transfer receipt...',
    'تم رفع صورة إشعار الحوالة بنجاح': 'Transfer receipt uploaded successfully',
    'تغيير من المعرض': 'Change from Gallery',
    'تصوير مجدداً': 'Retake Photo',
    'من المعرض': 'From Gallery',
    'تصوير الإشعار': 'Take Photo',
    'عرض الإشعار بالحجم الكامل': 'View Full Receipt',
    'تعذر تحميل صورة الإشعار': 'Could not load receipt image',
    'يرجى رفع صورة إشعار الحوالة أولاً لتفعيل زر إرسال الطلب':
        'Please upload the transfer receipt image first to enable submission',
    'يرجى رفع صورة إشعار الحوالة أولاً لإتمام الطلب':
        'Please upload the transfer receipt image first to complete your order',
    'ارفع إشعار الحوالة لإتمام الطلب': 'Upload Receipt to Complete Order',
    'إرسال الطلب وإشعار الحوالة': 'Submit Order & Receipt',
    'تم إرسال طلبك وإشعار الحوالة بنجاح':
        'Order & Transfer Receipt Sent Successfully',
    'سيراجع صاحب المتجر إشعار الحوالة ويبدأ بتجهيز وشحن طلبك فوراً، وسيصلك إشعار بكل تحديث.':
        'The shop owner will review your transfer receipt and start preparing your order. You will be notified of every update.',
    'يرجى إدخال رقم هاتف التواصل': 'Please enter a contact phone number',
    'يرجى إدخال العنوان التفصيلي للتوصيل':
        'Please enter the detailed delivery address',
    'يرجى اختيار وسيلة الدفع (بنك أو محفظة)':
        'Please select a payment method (bank or wallet)',
    'الحوالة المالية وإشعار الدفع': 'Transfer & Payment Receipt',
    'بانتظار مراجعة الإشعار': 'Receipt Pending Review',
    'تم تأكيد الحوالة': 'Transfer Verified',
    'مشكلة في إشعار الحوالة': 'Receipt Issue Reported',
    'توجد مشكلة في إشعار الحوالة': 'Issue with Transfer Receipt',
    'مشكلة في الحوالة — اضغط للتحديث': 'Receipt Issue — Tap to Fix',
    'رقم الحساب / المحفظة': 'Account / Wallet Number',
    'تم نسخ رقم الحساب / المحفظة': 'Account / wallet number copied',
    'رفع إشعار من المعرض': 'Upload from Gallery',
    'تم رفع إشعار الحوالة الجديد وإرساله للمتجر للمراجعة':
        'New transfer receipt uploaded and sent to shop for review',
    'بانتظار تأكيد إشعار الحوالة': 'Awaiting Receipt Verification',
    'بانتظار تحديث إشعار الحوالة': 'Awaiting Updated Receipt',
    'تم تأكيد الحوالة والطلب': 'Transfer & Order Confirmed',
    'يراجع المتجر إشعار الحوالة المالية الآن':
        'The shop is reviewing your transfer receipt now',
    'يرجى رفع إشعار حوالة واضح لإكمال الطلب':
        'Please upload a clear transfer receipt to continue',
    'تم تأكيد طلبك وحوالتك بنجاح': 'Your order and transfer have been confirmed',
    'جاهز للاستلام من المتجر': 'Ready for Pickup at Shop',
    'الطلب جاهز ويمكن لمندوبك استلامه من المتجر':
        'Your order is ready for your courier or self-pickup',
    'مراحل تجهيز واستلام الطلب': 'Order Preparation & Pickup Stages',
    'التوصيل (توصيل الزبون)': 'Delivery (Customer Pickup)',
    'التوصيل (من المحل)': 'Delivery (Shop Delivery)',
    'إشعار بانتظار المراجعة': 'Receipt Awaiting Review',
    'حوالة مؤكدة': 'Transfer Verified',
    'مشكلة في الحوالة': 'Transfer Issue',
    'مراجعة إشعار الحوالة': 'Review Transfer Receipt',
    'الإجمالي المطلوب': 'Total Required',
    'الملاحظة المرسلة للعميل': 'Note sent to customer',
    'تأكيد استلام الحوالة والمتابعة للشحن':
        'Confirm Transfer & Continue Shipping',
    'إبلاغ العميل بمشكلة في المبلغ أو الإشعار':
        'Report Issue with Amount or Receipt',
    'تُفتح مراحل التجهيز والشحن تلقائياً فور تأكيد استلام الحوالة المالية أعلاه.':
        'Preparation and shipping stages unlock automatically once you confirm the transfer above.',
    'إبلاغ العميل بمشكلة في الحوالة': 'Report Transfer Issue to Customer',
    'اختر سبباً سريعاً أو اكتب رسالة توضيحية تصل للعميل فوراً:':
        'Pick a quick reason or write a message that notifies the customer immediately:',
    'المبلغ المحوّل أقل من قيمة الطلب المطلوبة':
        'Transferred amount is less than the order total',
    'صورة إشعار الحوالة غير واضحة، يرجى رفع صورة أوضح':
        'Receipt image is unclear, please upload a clearer photo',
    'لم تصل الحوالة إلى الحساب بعد، يرجى التحقق':
        'Transfer has not arrived in the account yet, please check',
    'تم التحويل إلى رقم حساب مختلف عن الرقم المعتمد':
        'Transferred to a different account number than listed',
    'رسالة للعميل (مثال: المبلغ ناقص 10 شيكل)':
        'Message to customer (e.g., amount is short by 10 ₪)',
    'إرسال الملاحظة للعميل': 'Send Note to Customer',
    'يرجى كتابة سبب المشكلة أولاً': 'Please enter the issue reason first',
    'تم تأكيد الحوالة بنجاح ويمكنك الآن متابعة مراحل الشحن':
        'Transfer confirmed — you can now proceed with shipping stages',
    'تم إبلاغ العميل بالمشكلة وبانتظار رفع إشعار جديد':
        'Customer notified of the issue; awaiting updated receipt',
    'تعذر تأكيد الحوالة': 'Failed to confirm transfer',
    'تعذر إرسال الملاحظة': 'Failed to send issue note',
    'رسوم التوصيل الخاصة بالمحل': 'Shop Delivery Fee',
    'تُضاف هذه القيمة تلقائياً إلى إجمالي الطلب عند اختيار الزبون (توصيل من المحل)، ولا تُضاف عند اختيار (توصيل من الزبون).':
        'This fee is automatically added when the customer selects Shop Delivery, and omitted for Customer Pickup.',
    'مجاناً (0 ₪)': 'Free (0 ₪)',
    'قيمة التوصيل بالشيكل (₪)': 'Delivery Fee (₪)',
    'حفظ قيمة التوصيل': 'Save Delivery Fee',
    'تم تحديث رسوم التوصيل بنجاح': 'Delivery fee updated successfully',
    'تعذر حفظ قيمة التوصيل': 'Failed to save delivery fee',
    'قيمة التوصيل الحالية': 'Current delivery fee',
    'التوصيل مجاني حالياً (0 ₪) — اضغط للتحديد':
        'Delivery is currently free (0 ₪) — tap to set',
    'يرجى إدخال قيمة توصيل صحيحة (0 أو أكثر)':
        'Please enter a valid delivery fee (0 or greater)',
    'طرق الدفع والحوالات (غزة)': 'Payment Methods & Transfers (Gaza)',
    'أرقام بنك فلسطين والمحافظ الإلكترونية وتفعيلها أو إيقافها':
        'Bank of Palestine & Gaza e-wallets — edit, enable or pause',
    'أرقام بنك فلسطين والمحافظ الإلكترونية وتفعيلها وإيقافها':
        'Bank of Palestine & Gaza e-wallets — edit, enable or pause',
    'إضافة بنك أو محفظة': 'Add Bank or Wallet',
    'إضافة بنك أو محفظة إلكترونية': 'Add Bank or E-Wallet',
    'إضافة بنك أو محفظة جديدة': 'Add New Bank or Wallet',
    'تعديل وسيلة الدفع': 'Edit Payment Method',
    'نوع وسيلة الدفع': 'Payment Method Type',
    'اسم المحفظة (مثال: محفظة بال باي / جوال باي) *':
        'Wallet Name (e.g. PalPay / Jawwal Pay) *',
    'اسم البنك (مثال: بنك فلسطين) *': 'Bank Name (e.g. Bank of Palestine) *',
    'اسم البنك أو المحفظة': 'Bank or Wallet Name',
    'رقم المحفظة للتحويل *': 'Wallet Number *',
    'رقم الحساب البنكي *': 'Bank Account Number *',
    'رقم IBAN (اختياري)': 'IBAN (optional)',
    'اسم المستفيد / صاحب الحساب': 'Beneficiary / Account Holder Name',
    'تعليمات التحويل للزبون (اختياري)': 'Transfer Instructions (optional)',
    'ترتيب الظهور (الأصغر يظهر أولاً)': 'Sort Order (smaller appears first)',
    'تفعيل وسيلة الدفع للعملاء': 'Enable Payment Method for Customers',
    'ظاهرة ومتاحة للتحويل في شاشة إتمام الشراء':
        'Visible and selectable during checkout',
    'مخفية وموقفة مؤقتاً عن العملاء': 'Hidden and paused for customers',
    'حذف وسيلة الدفع': 'Delete Payment Method',
    'تعذر حفظ وسيلة الدفع': 'Failed to save payment method',
    'تعذر حذف وسيلة الدفع': 'Failed to delete payment method',
    'تم حفظ وسيلة الدفع بنجاح': 'Payment method saved successfully',
    'تم حذف وسيلة الدفع': 'Payment method deleted',
    'تعذر تحميل طرق الدفع': 'Failed to load payment methods',
    'مفعّلة للعملاء': 'Active for Customers',
    'موقفة': 'Paused',
    'البنوك': 'Banks',
    'المحافظ': 'Wallets',
    'لا توجد وسائل دفع بعد': 'No Payment Methods Yet',
    'أضف أرقام حسابات بنك فلسطين والمحافظ الإلكترونية في غزة لتظهر للعملاء عند الدفع.':
        'Add Bank of Palestine and Gaza e-wallet numbers so customers can transfer during checkout.',
    'نسخ الرقم': 'Copy Number',
    'تم نسخ الرقم بنجاح': 'Number copied successfully',
    'تم تفعيل': 'Activated',
    'تم إيقاف': 'Paused',
    'وسيلة الدفع': 'Payment Method',
    'حالة الحوالة': 'Transfer Status',
    'حفظ التغييرات': 'Save Changes',
    'توصيل المحل': 'Shop Delivery',
    'توصيل الزبون': 'Customer Pickup',
    'الإشعار مرفق': 'Receipt Attached',
    'جاري الرفع': 'Uploading',
    'ارفع الإشعار': 'Upload Receipt',
    'تأكيد وإرسال الطلب': 'Confirm & Submit Order',
    'جاري رفع إشعار الحوالة...': 'Uploading transfer receipt...',
    'الدفع وإشعار الحوالة': 'Payment & Transfer Receipt',
    'رفع الإشعار من المعرض': 'Upload Receipt',
    'كاميرا': 'Camera',
    'تم إرفاق إشعار الحوالة': 'Transfer Receipt Attached',
    'اضغط على الصورة للمعاينة': 'Tap image to preview',
    'ملاحظات أو اسم المندوب (اختياري)': 'Notes or courier name (optional)',
    'منطقة التوصيل والتواصل': 'Delivery Area & Contact',
    'بيانات التواصل': 'Contact Info',
    'اضغط لإدخال المنطقة والعنوان ورقم الهاتف':
        'Tap to enter area, address, and phone number',
    'ملاحظات للتوصيل (اختياري)': 'Delivery notes (optional)',
    'إخفاء': 'Hide',
    'بنك': 'Bank',
    'محفظة': 'Wallet',
    'العودة إلى السلة': 'Back to Cart',
    'إتمام الطلب': 'Place Order',
    'إشعار حوالة': 'Transfer Receipt',
    'إشعار حوالة طلب': 'Order Transfer Receipt',
    'الاسم بالإنجليزية (اختياري)': 'English Name (optional)',
    'القطع المشتراة': 'Purchased Items',
    'الكمية': 'Quantity',
    'تاريخ الإنشاء': 'Created At',
    'تعذر تحديث الحالة': 'Failed to update status',
    'تم تسليم الملابس بنجاح': 'Order delivered successfully',
    'جاري تجهيز الملابس': 'Preparing your order',
    'حوالة بنكية / محفظة': 'Bank / Wallet Transfer',
    'رسوم التوصيل': 'Delivery Fee',
    'نسخ': 'Copy',
    'أفضل سعر': 'Best Price',
    'الألوان': 'Colors',
    'منتجات للمقارنة': 'Items to Compare',
    'أضف منتجاً آخر للمقارنة بين الأسعار والمواصفات':
        'Add another product to compare prices and specs',
    'أوف وايت': 'Off-White',
    'رمادي غامق': 'Charcoal',
    'جملي': 'Camel',
    'سماوي': 'Sky Blue',
    'تركوازي': 'Turquoise',
    'زيتي': 'Olive',
    'نعناعي': 'Mint',
    'عنابي': 'Burgundy',
    'فوشي': 'Fuchsia',
    'مرجاني': 'Coral',
    'موف': 'Lavender',
    'خردلي': 'Mustard',
    'ذهبي': 'Gold',
    'فضي': 'Silver',
    'تحديد الكل': 'Select All',
    'إلغاء الكل': 'Clear All',
    'إضافة ألوان ومقاسات': 'Add Colors & Sizes',
    'الألوان المتوفرة': 'Available Colors',
    'المقاسات المتوفرة': 'Available Sizes',
    'اختر اللون': 'Select Color',
    'اختر المقاس': 'Select Size',
    'حدد اللون': 'Select Color',
    'حدد القياس': 'Select Size',
    'لون آخر (اختياري)': 'Other Color (optional)',
    'مثال: كشميري': 'e.g. Cashmere',
    'مقاس آخر (اختياري)': 'Other Size (optional)',
    'مثال: 3XL أو 45': 'e.g. 3XL or 45',
    'حفظ الخيارات': 'Save Options',
    'اختر لوناً ومقاساً وأدخل كمية صحيحة':
        'Select a color, size, and valid stock quantity',
    'جميع الخيارات المختارة مضافة بالفعل؛ عدّلها من القائمة':
        'All selected options already exist; edit them from the list',
    'لا يوجد اتصال بالإنترنت. تحقق من الواي فاي أو بيانات الهاتف وحاول مرة أخرى.':
        'No internet connection. Check your Wi-Fi or mobile data and try again.',
    'تعذر الاتصال بالخادم حالياً. تحقق من الإنترنت وحاول مجدداً.':
        'Unable to reach the server right now. Check your internet and try again.',
    'الاتصال بطيء حالياً ولم يستجب الخادم في الوقت المناسب. حاول مرة أخرى.':
        'Your connection is slow and the server did not respond in time. Please try again.',
    'انقطع الاتصال بالإنترنت أثناء تنفيذ العملية. حاول مرة أخرى.':
        'Internet connection dropped during the request. Please try again.',
    'الخدمة غير متاحة مؤقتاً. يرجى المحاولة بعد قليل.':
        'Service is temporarily unavailable. Please try again shortly.',
    'تعذر تسجيل الدخول عبر Google حالياً. حاول مجدداً أو استخدم البريد الإلكتروني.':
        'Could not sign in with Google right now. Try again or use email.',
    'تعذر تسجيل الدخول عبر Google حالياً. حاول مرة أخرى أو استخدم البريد الإلكتروني.':
        'Could not sign in with Google right now. Try again or use email.',
    'تعذر فتح صفحة تسجيل الدخول عبر Google':
        'Could not open Google sign-in page',
    'تعذر تسجيل الدخول. تحقق من بياناتك واتصالك بالإنترنت وحاول مجدداً.':
        'Could not sign in. Please check your details and internet connection.',
    'البيانات المدخلة غير صحيحة. راجع الحقول وحاول مجدداً.':
        'The entered details are invalid. Please review the fields and try again.',
    'استغرقت العملية وقتاً أطول من المعتاد. حاول مرة أخرى.':
        'The operation took longer than expected. Please try again.',
    'هذه الخدمة غير متوفرة مؤقتاً. حاول مرة أخرى لاحقاً.':
        'This service is temporarily unavailable. Please try again later.',
    'حجم الملف كبير جداً. اختر صورة أصغر وحاول مجدداً.':
        'File is too large. Please choose a smaller image and try again.',
    'تعذر رفع الصورة. تحقق من الإنترنت وحجم الصورة وحاول مجدداً.':
        'Could not upload image. Check your internet and image size, then try again.',
    'الخدمة المطلوبة غير متوفرة مؤقتاً. حاول لاحقاً.':
        'This service is temporarily unavailable. Please try again later.',
    'حدث خطأ مؤقت في التطبيق. أعد تشغيل التطبيق وحاول مجدداً.':
        'A temporary app error occurred. Please restart the app and try again.',
    'يرجى السماح للتطبيق بالوصول إلى الكاميرا أو الصور من إعدادات الجهاز.':
        'Please allow camera or photo access in your device settings.',
    'البيانات المدخلة غير صالحة. يرجى مراجعتها والمحاولة مجدداً.':
        'Invalid input. Please review your details and try again.',
    'تعذر تشغيل التطبيق حالياً. تحقق من اتصالك بالإنترنت وأعد المحاولة.':
        'Could not start the app right now. Check your internet and try again.',
    'تعذر تحميل المنتجات حالياً. حاول مرة أخرى.':
        'Could not load products right now. Please try again.',
    'تعذر تحميل المفضلة حالياً. حاول مرة أخرى.':
        'Could not load favorites right now. Please try again.',
    'تعذر تحميل الإشعارات حالياً. حاول مرة أخرى.':
        'Could not load notifications right now. Please try again.',
    'تعذر تحميل الطلبات حالياً. حاول مرة أخرى.':
        'Could not load orders right now. Please try again.',
    'تعذر تحميل المتاجر حالياً. حاول مرة أخرى.':
        'Could not load shops right now. Please try again.',
    'تعذر تحميل تفاصيل الطلب حالياً. حاول مرة أخرى.':
        'Could not load order details right now. Please try again.',
    'تعذر تحميل تفاصيل المنتج حالياً. حاول مرة أخرى.':
        'Could not load product details right now. Please try again.',
    'تعذر تحميل بيانات المتجر حالياً. حاول مرة أخرى.':
        'Could not load shop details right now. Please try again.',
    'تعذر تشغيل الكاميرا. تأكد من منح صلاحية الكاميرا وحاول مجدداً.':
        'Could not start the camera. Make sure camera permission is granted and try again.',
    'تعذر تحميل التجربة الافتراضية حالياً. حاول مرة أخرى.':
        'Could not load virtual try-on right now. Please try again.',
    'خدمة التجربة الافتراضية غير متوفرة مؤقتاً. يرجى المحاولة لاحقاً.':
        'Virtual try-on is temporarily unavailable. Please try again later.',
    // --- Shop Subscriptions & 100% Per-Shop Financial Statements ---
    'شهر واحد (30 يوم)': '1 Month (30 days)',
    '3 شهور (90 يوم)': '3 Months (90 days)',
    '6 شهور (180 يوم)': '6 Months (180 days)',
    'سنة كاملة (365 يوم)': '1 Full Year (365 days)',
    'معتمد ومفعّل': 'Approved & Active',
    'منتهي': 'Expired',
    'بانتظار المراجعة': 'Pending Review',
    'عمولة 0%': '0% Commission',
    'باقة الاشتراك وتحويل الرسوم': 'Subscription Plan & Fee Transfer',
    'اشتراك ثابت بدون أي عمولة على المبيعات (0% عمولة)':
        'Flat subscription with zero sales commission (0%)',
    '1. اختر باقة الاشتراك': '1. Choose a Subscription Plan',
    'تعذر تحميل باقات الاشتراك': 'Could not load subscription plans',
    'لا توجد باقات اشتراك مفعّلة حالياً. يرجى التواصل مع الإدارة.':
        'No active subscription plans right now. Please contact support.',
    '2. حوّل قيمة الاشتراك إلى أحد حسابات الإدارة':
        '2. Transfer the Subscription Fee to an Admin Account',
    'تعذر تحميل حسابات التحويل': 'Could not load transfer accounts',
    'لم تقم الإدارة بإضافة حسابات تحويل بعد. تواصل مع الدعم.':
        'No transfer accounts configured yet. Please contact support.',
    '3. أرفق صورة إشعار التحويل *': '3. Attach Transfer Receipt Photo *',
    'التقط صورة واضحة أو اختر لقطة شاشة لإشعار الحوالة ليتم اعتماد اشتراكك بسرعة.':
        'Take a clear photo or pick a screenshot of the transfer receipt for fast approval.',
    'تم إرفاق صورة الإشعار': 'Receipt photo attached',
    'إشعار الاشتراك المرفق سابقاً': 'Previously attached subscription receipt',
    'ملاحظات إضافية حول الحوالة (اختياري)':
        'Additional transfer notes (optional)',
    'تعذر اختيار صورة الإشعار، حاول مرة أخرى':
        'Could not select receipt image, please try again',
    'رقم المحفظة / الجوال': 'Wallet / Mobile Number',
    'استكمال بيانات المحل والاشتراك': 'Complete Shop Profile & Subscription',
    'اكتمال ملف المتجر والاشتراك': 'Shop Profile & Subscription Progress',
    'جميع البيانات وإشعار الاشتراك جاهزة — أرسل الطلب ليتم فتح متجرك.':
        'All details and subscription receipt are ready — submit to open your shop.',
    'أكمل بيانات المتجر ثم اختر باقة الاشتراك وأرفق إشعار التحويل لإرسال الطلب.':
        'Complete your shop details, pick a plan, and attach your transfer receipt.',
    'يرجى اختيار باقة الاشتراك أولاً':
        'Please select a subscription plan first',
    'يرجى اختيار حساب التحويل أولاً': 'Please select a transfer account first',
    'يرجى إرفاق صورة إشعار تحويل الاشتراك قبل إرسال الطلب':
        'Please attach your subscription transfer receipt before submitting',
    'تم إرسال طلب اعتماد المتجر وإشعار الاشتراك للإدارة':
        'Shop application & subscription receipt submitted to admin',
    'إرسال الطلب والاشتراك': 'Submit Application & Subscription',
    'انتهت مدة اشتراك متجرك': 'Your Shop Subscription Expired',
    'تم إيقاف نشر المنتجات الجديدة مؤقتاً حتى تجديد الاشتراك وإرسال إشعار التحويل.':
        'Publishing new products is temporarily paused until you renew your subscription.',
    'تجديد الاشتراك الآن': 'Renew Subscription Now',
    'اقترب موعد تجديد اشتراكك': 'Subscription Renewal Coming Up',
    'تجديد الاشتراك': 'Renew Subscription',
    'الاشتراك والكشف المالي': 'Subscription & Financial Statement',
    'كشف حسابك 100% بدون عمولة وحالة الاشتراك':
        'Your 100% zero-commission statement & subscription status',
    'تجديد اشتراك المتجر': 'Renew Shop Subscription',
    'اختر باقة التجديد وأرفق الإشعار':
        'Choose Renewal Plan & Attach Receipt',
    'بعد التحويل، سيتم تفعيل أو تمديد اشتراكك فور مراجعة الإدارة.':
        'After transfer, your subscription will be activated or extended upon admin review.',
    'إرسال طلب تجديد الاشتراك': 'Submit Subscription Renewal',
    'يرجى إرفاق صورة إشعار تحويل الاشتراك':
        'Please attach the subscription transfer receipt',
    'تعذر إرسال طلب التجديد': 'Could not submit renewal request',
    'تم إرسال إشعار تجديد الاشتراك وستقوم الإدارة بمراجعته':
        'Subscription renewal receipt submitted for admin review',
    'تعذر تحميل الكشف المالي': 'Could not load financial statement',
    'المتبقي لك لدى المنصة (100%)': 'Remaining Balance Owed to You (100%)',
    'مبيعات معتمدة (100% لك)': 'Verified Sales (100% Yours)',
    'تم تحويله لك': 'Paid Out to You',
    'طلبات قيد التنفيذ (غير مكتملة بعد)': 'In-Progress Orders (Not Completed Yet)',
    'التحويلات': 'Payouts',
    'الاشتراكات': 'Subscriptions',
    'لا توجد طلبات مسجلة بعد': 'No Orders Recorded Yet',
    'ستظهر هنا جميع طلبات متجرك وتفاصيل مستحقاتك الكاملة (100% بدون عمولة).':
        'All your shop orders and full 100% zero-commission earnings will appear here.',
    'لا توجد تحويلات مستحقات بعد': 'No Payouts Received Yet',
    'عندما تقوم الإدارة بتحويل مستحقات مبيعاتك إلى حسابك ستظهر جميع التحويلات وإشعاراتها هنا.':
        'When the platform transfers your sales proceeds, all payouts and receipts will appear here.',
    'لا يوجد سجل اشتراكات بعد': 'No Subscription History Yet',
    'ستظهر هنا جميع باقات الاشتراك والتجديدات مع حالة كل إشعار.':
        'All your subscription plans, renewals, and receipt statuses will appear here.',
    'حالة اشتراك المتجر': 'Shop Subscription Status',
    'منتهي — يحتاج تجديد': 'Expired — Renewal Needed',
    'فعّال': 'Active',
    'غير مفعّل': 'Inactive',
    'انتهى بتاريخ': 'Expired on',
    'ينتهي بتاريخ': 'Expires on',
    'لديك طلب تجديد اشتراك قيد المراجعة من الإدارة حالياً.':
        'You have a subscription renewal request currently under admin review.',
    'تجديد أو ترقية الباقة': 'Renew or Upgrade Plan',
    'محتسب في رصيدك (100%)': 'Credited to your balance (100%)',
    'بانتظار التأكيد/التسليم': 'Awaiting confirmation/delivery',
    'رقم المرجع': 'Reference No.',
    'إشعار تحويل المستحقات': 'Payout Transfer Receipt',
    'تجديد اشتراك': 'Subscription Renewal',
    'اشتراك تأسيس': 'Initial Subscription',
    'الفترة': 'Period',
    'إشعار تحويل الاشتراك': 'Subscription Transfer Receipt',
    'باقات اشتراك المحلات': 'Shop Subscription Plans',
    'إضافة باقة اشتراك': 'Add Subscription Plan',
    'إضافة باقة اشتراك جديدة': 'Add New Subscription Plan',
    'تعديل باقة الاشتراك': 'Edit Subscription Plan',
    'اسم الباقة (مثال: الباقة الشهرية) *': 'Plan Name (e.g. Monthly Plan) *',
    'اسم الباقة': 'Plan Name',
    'قيمة الاشتراك (₪) *': 'Subscription Price (₪) *',
    'أدخل سعراً صحيحاً': 'Enter a valid price',
    'المدة بالأيام *': 'Duration in Days *',
    'يوم على الأقل': 'At least 1 day',
    '30 يوم': '30 Days',
    '90 يوم': '90 Days',
    '180 يوم': '180 Days',
    '365 يوم': '365 Days',
    'وصف ومزايا الباقة (اختياري)': 'Plan Description & Perks (Optional)',
    'تفعيل الباقة للمحلات': 'Enable Plan for Shops',
    'ظاهرة ومتاحة للمحلات عند التسجيل والتجديد':
        'Visible and available to shops for onboarding & renewal',
    'مخفية وموقفة مؤقتاً عن المحلات': 'Hidden and temporarily paused',
    'حفظ الباقة': 'Save Plan',
    'حذف الباقة': 'Delete Plan',
    'تعذر حفظ باقة الاشتراك': 'Could not save subscription plan',
    'تم حفظ باقة الاشتراك بنجاح': 'Subscription plan saved successfully',
    'تعذر حذف باقة الاشتراك': 'Could not delete subscription plan',
    'تم حذف باقة الاشتراك': 'Subscription plan deleted',
    'يرجى إدخال سعر اشتراك صحيح': 'Please enter a valid subscription price',
    'يرجى إدخال مدة صحيحة بالأيام (يوم واحد على الأقل)':
        'Please enter a valid duration (at least 1 day)',
    'كل الباقات': 'All Plans',
    'لا توجد باقات اشتراك بعد': 'No Subscription Plans Yet',
    'أضف باقات الاشتراك (مثل 30 ₪ شهرياً) لتظهر للمحلات عند التسجيل والتجديد.':
        'Add subscription plans (e.g. 30 ₪/month) for shops to choose during signup & renewal.',
    'اشتراك ثابت بدون أي عمولة على المبيعات (0%)':
        'Flat subscription with zero sales commission (0%)',
    'مراجعة المحل والاشتراك': 'Review Shop & Subscription',
    'قبول المحل وتفعيل الاشتراك': 'Approve Shop & Activate Subscription',
    'تأكيد القبول وتفعيل الاشتراك': 'Confirm Approval & Activate',
    'تم اعتماد المحل وتفعيل اشتراكه بنجاح':
        'Shop approved and subscription activated',
    'رفض الطلب': 'Reject Application',
    'اكتب سبب الرفض ليظهر للتاجر ويتمكن من تصحيح البيانات أو إشعار الحوالة وإعادة الإرسال.':
        'Enter the rejection reason so the shop owner can fix the details or receipt and resubmit.',
    'تم رفض الطلب وإشعار التاجر بالسبب':
        'Application rejected and shop notified',
    'اشتراك فعّال': 'Active Subscription',
    'بانتظار التحقق': 'Awaiting Verification',
    'بيانات الاشتراك وإشعار الحوالة': 'Subscription Details & Transfer Receipt',
    'الباقة المختارة': 'Selected Plan',
    'تم التحويل إلى': 'Transferred To',
    'صورة إشعار التحويل (اضغط للتكبير والتحقق)':
        'Transfer Receipt Photo (Tap to zoom & verify)',
    'إشعار اشتراك': 'Subscription Receipt',
    'لم يتم إرفاق إشعار تحويل اشتراك مع هذا الطلب.':
        'No subscription transfer receipt attached to this application.',
    'الاشتراكات والكشف المالي للمحلات': 'Subscriptions & Shop Payouts',
    'إيرادات الاشتراكات، مراجعة الإشعارات، ومستحقات المحلات (100%)':
        'Subscription revenue, receipt reviews, and 100% shop payouts',
    'تحديد قيمة ومدد باقات الاشتراك (مثال: 30 ₪ شهرياً) بدون عمولة':
        'Set subscription plan prices & durations (e.g. 30 ₪/mo) with 0% commission',
    'طرق الدفع وحسابات التحويل (غزة)': 'Payment Methods & Transfer Accounts (Gaza)',
    'أرقام بنك فلسطين والمحافظ الإلكترونية لتحويل الطلبات والاشتراكات':
        'Bank of Palestine & e-wallet accounts for order and subscription transfers',
    'مراجعة إشعارات الاشتراك وكشف مستحقات المحلات (100% بدون عمولة)':
        'Review subscription receipts and 100% zero-commission shop balances',
    'إدارة أسعار ومدد باقات اشتراك المتاجر':
        'Manage shop subscription plan prices and durations',
    'اشتراك': 'subscription',
    'باقات الاشتراك': 'Subscription Plans',
    'تعذر تحميل بيانات الاشتراكات والمالية':
        'Could not load subscriptions and financial data',
    'إشعارات اشتراك بانتظار المراجعة': 'Subscription Receipts Pending Review',
    'هناك طلبات اشتراك أو تجديد جديدة مرفق معها إشعار الحوالة بانتظار التحقق والاعتماد.':
        'New shop subscription or renewal receipts are waiting for verification.',
    'مراجعة الإشعارات': 'Review Receipts',
    'إيرادات الاشتراكات': 'Subscription Revenue',
    'متبقي للمحلات (100%)': 'Owed to Shops (100%)',
    'محوّل': 'Paid',
    'إدارة باقات الاشتراك': 'Manage Plans',
    'حسابات التحويل': 'Transfer Accounts',
    'الكشف المالي للمحلات': 'Shop Statements',
    'إشعارات الاشتراكات': 'Subscription Receipts',
    'بحث باسم المحل أو المدينة...': 'Search by shop name or city...',
    'سيظهر هنا الكشف المالي الكامل لكل محل (100% من مبيعاته بدون عمولة).':
        'Each shop\'s full 100% zero-commission financial statement will appear here.',
    'معتمدة': 'Approved',
    'مرفوضة': 'Rejected',
    'لا توجد طلبات اشتراك هنا': 'No Subscription Requests Here',
    'ستظهر هنا جميع طلبات اشتراك وتجديد المحلات مع صور إشعارات التحويل.':
        'All shop subscription and renewal requests with transfer receipts will appear here.',
    'اشتراك نشط': 'Active Plan',
    'اشتراك منتهي': 'Expired Plan',
    'اشتراك قيد المراجعة': 'Pending Plan',
    'غير مشترك': 'No Plan',
    'ينتهي الاشتراك': 'Subscription Ends',
    'مبيعات (100%)': 'Sales (100%)',
    'تم تحويله': 'Paid Out',
    'المتبقي للمحل': 'Remaining Owed',
    'كشف الحساب': 'Statement',
    'تحويل مستحقات': 'Record Payout',
    'تسجيل جديد': 'New Signup',
    'تجديد': 'Renewal',
    'الصلاحية': 'Validity',
    'ملاحظة التاجر': 'Shop Note',
    'اعتماد وتفعيل الاشتراك': 'Approve & Activate',
    'رفض إشعار الاشتراك': 'Reject Subscription Receipt',
    'تعذر تحديث حالة الاشتراك': 'Could not update subscription status',
    'تم اعتماد وتفعيل اشتراك المتجر بنجاح':
        'Shop subscription approved and activated',
    'تم رفض إشعار الاشتراك وإشعار التاجر':
        'Subscription receipt rejected and shop notified',
    'المتبقي للمحل حالياً (100% بدون عمولة)':
        'Current Balance Owed to Shop (100%, 0% Fee)',
    'المبلغ المحوّل للمحل (₪) *': 'Payout Amount to Shop (₪) *',
    'طريقة التحويل': 'Transfer Method',
    'نقدي': 'Cash',
    'رقم الحوالة / المرجع (اختياري)': 'Transfer Reference No. (Optional)',
    'إرفاق إشعار التحويل للمحل (اختياري)':
        'Attach Payout Receipt Photo (Optional)',
    'تصوير': 'Camera',
    'ملاحظات للمحل (اختياري)': 'Notes for Shop (Optional)',
    'تأكيد وتسجيل التحويل': 'Confirm & Record Payout',
    'تعذر تسجيل التحويل': 'Could not record payout',
    'تم تسجيل تحويل المستحقات للمحل وإشعار التاجر':
        'Payout recorded and shop owner notified',
    'الكشف المالي': 'Financial Statement',
    'تعذر تحميل كشف المحل': 'Could not load shop statement',
    'مبيعات معتمدة (100%)': 'Verified Sales (100%)',
    'حوالة': 'payouts',
    'صافي المتبقي للمحل (عمولة 0%)': 'Net Owed to Shop (0% Commission)',
    'تسجيل تحويل': 'Record Payout',
    'التحويلات المسجلة للمحل': 'Recorded Payouts to Shop',
    'لم يتم تسجيل أي تحويلات لهذا المحل بعد.':
        'No payouts have been recorded for this shop yet.',
    'المرجع': 'Ref',
    'لا توجد طلبات مسجلة لهذا المحل بعد.':
        'No orders recorded for this shop yet.',
    'استكمال بيانات المتجر والاشتراك': 'Complete Shop Profile & Subscription',
    'إدخال المعلومات الأساسية واختيار الباقة وإرفاق إشعار التحويل':
        'Enter shop details, pick a plan, and attach transfer receipt',
    'مراجعة الإدارة والتحقق من الاشتراك': 'Admin Review & Receipt Verification',
    'تحتاج البيانات أو إشعار الاشتراك إلى تعديل وإعادة إرسال':
        'Details or subscription receipt need updates and resubmission',
    'التحقق من بيانات المتجر وإشعار تحويل الاشتراك':
        'Verifying shop details and subscription transfer receipt',
    'فتح المتجر وتفعيل الاشتراك (عمولة 0%)':
        'Open Shop & Activate Plan (0% Fee)',
    'نشر المنتجات واستقبال الطلبات بدون أي عمولة':
        'Publish products and receive orders with zero commission',
    // --- 5-Step Shop Onboarding Wizard ---
    'فتح متجر جديد': 'Open a New Shop',
    'البيانات': 'Details',
    'المالك': 'Owner',
    'يرجى إكمال جميع الحقول المطلوبة في معلومات المتجر':
        'Please complete all required shop details first',
    'يرجى إدخال اسم صاحب المحل ورقم الهاتف بشكل صحيح':
        'Please enter the shop owner name and phone number',
    'أكمل بيانات المحل والمالك المطلوبة لحفظ المسودة':
        'Complete the required shop and owner fields to save as draft',
    'الهوية': 'Identity',
    'الباقة': 'Plan',
    'التحويل': 'Transfer',
    'الإرسال': 'Submit',
    'يرجى إكمال جميع الحقول المطلوبة في بيانات المحل':
        'Please complete all required shop details first',
    'يرجى اختيار باقة الاشتراك للمتابعة':
        'Please choose a subscription plan to continue',
    'يرجى إرفاق صورة إشعار تحويل الاشتراك قبل المتابعة':
        'Please attach your subscription transfer receipt to continue',
    'أكمل بيانات المحل المطلوبة لحفظ المسودة':
        'Complete the required shop fields to save as draft',
    'تم حفظ بيانات المتجر كمسودة بنجاح': 'Shop draft saved successfully',
    'عرّفنا بمتجرك': 'Tell Us About Your Shop',
    'أدخل البيانات الأساسية للمحل ومعلومات التواصل — هذه المعلومات ستظهر للعملاء وللإدارة عند مراجعة متجرك.':
        'Enter your basic shop and contact info — shown to customers and used for admin review.',
    'هوية المتجر ووثائق التوثيق': 'Shop Identity & Documents',
    'أضف شعار وصورة غلاف متجرك ومستندات التوثيق لزيادة ثقة العملاء وتسريع الموافقة. هذه الخطوة اختيارية ويمكنك تعديلها لاحقاً.':
        'Add your logo, cover photo, and verification docs to boost customer trust. Optional — you can update anytime.',
    'اختياري': 'Optional',
    'اختر باقة اشتراك متجرك': 'Choose Your Shop Plan',
    'نظامنا بسيط وعادل: اشتراك ثابت فقط بدون أي نسبة أو عمولة على مبيعاتك (0% عمولة — 100% من أرباح طلباتك لك).':
        'Simple and fair: flat subscription only with zero sales commission (0% fee — keep 100% of every order).',
    'تحويل رسوم الاشتراك وإرفاق الإشعار': 'Transfer Fee & Upload Receipt',
    'حوّل قيمة الباقة المختارة إلى أحد حسابات الإدارة أدناه ثم ارفع صورة واضحة لإشعار التحويل.':
        'Transfer your selected plan fee to one of the admin accounts below, then upload a clear receipt photo.',
    'أولاً: انسخ رقم أحد حسابات الإدارة وحوّل المبلغ':
        '1. Copy an admin account number & transfer the fee',
    'ثانياً: أرفق صورة إشعار التحويل *': '2. Attach Transfer Receipt Photo *',
    'اختر لقطة شاشة من المعرض أو التقط صورة واضحة للإشعار لتسريع التحقق.':
        'Pick a screenshot from gallery or take a clear photo for fast verification.',
    'راجع طلبك قبل الإرسال': 'Review Before Submitting',
    'تأكد من صحة بيانات متجرك وباقة الاشتراك وإشعار التحويل، ثم اضغط تأكيد وإرسال الطلب.':
        'Double-check your shop details, chosen plan, and transfer receipt, then submit.',
    'جاهز للإرسال': 'Ready to Submit',
    'الاشتراك وإشعار التحويل': 'Subscription & Transfer Receipt',
    'قيمة الاشتراك': 'Subscription Fee',
    'العمولة على المبيعات': 'Sales Commission',
    'ماذا يحدث بعد إرسال الطلب؟': 'What Happens Next?',
    'يصل طلب متجرك مع صورة إشعار التحويل مباشرة للإدارة.':
        'Your shop request and transfer receipt go straight to admin.',
    'تتحقق الإدارة من الإشعار وتعتمد المتجر وتفعّل باقتك فوراً.':
        'Admin verifies your receipt, approves your shop, and activates your plan.',
    'يُفتح متجرك وتبدأ بنشر منتجاتك ومتابعة كشفك المالي الكامل (100% بدون عمولة).':
        'Your shop opens and you start publishing products with 100% of sales (0% commission).',
    '/ شهر': '/ month',
    '/ 3 شهور': '/ 3 months',
    '/ 6 شهور': '/ 6 months',
    '/ سنة': '/ year',
    'الأوفر': 'Best Value',
    'عمولة 0% على المبيعات — 100% من أرباح طلباتك لك':
        '0% sales commission — keep 100% of your order revenue',
    'نشر المنتجات واستقبال الطلبات وكشف مالي متكامل':
        'Publish products, receive orders & full financial statement',
    // --- Product Details Description & Specs (EN) ---
    'وصف القطعة': 'Product Description',
    'المنتج غير موجود': 'Product not found',
    'تعذر تحميل تفاصيل المنتج': 'Could not load product details',
    'قصة عادية': 'Regular Fit',
    'قصة مريحة': 'Relaxed Fit',
    'قصة واسعة': 'Oversized Fit',
    'قصة ضيقة': 'Slim Fit',
    'غسيل آلي': 'Machine Wash',
    'غسيل بماء بارد': 'Cold Water Wash',
    'قطن': 'Cotton',
    'تركيا': 'Turkey',
    'فلسطين': 'Palestine',
    'مصر': 'Egypt',
    'الصين': 'China',
    'إيطاليا': 'Italy',
    // --- Multi-Shop Shipments & Grouped Payment Transfer ---
    'توصيل مستقل لكل محل': 'Independent delivery per shop',
    'اضغط لإدخال رقم هاتف التواصل': 'Tap to enter contact phone number',
    'إجمالي هذه الشحنة': 'Shipment total',
    'المبلغ المطلوب تحويله (حوالة واحدة)': 'Total to Transfer (1 Transfer)',
    'تم تقسيم سلتك تلقائياً إلى شحنات مستقلة لكل متجر، وسيتم تأكيد الحوالة وتجهيز كل شحنة من محلها.':
        'Your cart was automatically split into separate shipments per shop. Once your transfer is verified, each shop prepares its shipment.',
    'سيتم مراجعة إشعار الحوالة وتأكيده ليبدأ المتجر بتجهيز وشحن طلبك فوراً، وسيصلك إشعار بكل تحديث.':
        'Your transfer receipt will be verified so the shop can start preparing and shipping your order right away.',
    'إشعار حوالة مجمّعة': 'Combined Transfer Receipt',
    'حصتك': 'Your share',
    'تأكيد استلام الحوالة': 'Confirm Transfer Receipt',
    'تم تأكيد استلام الحوالة بنجاح': 'Transfer confirmed successfully',
    'الإبلاغ عن مشكلة في الإشعار': 'Report Receipt Issue',
    'الإبلاغ عن مشكلة في الحوالة': 'Report Transfer Issue',
    'مثال: المبلغ المحوّل ناقص أو صورة الإشعار غير واضحة':
        'e.g. Transferred amount is incomplete or receipt photo is blurry',
    'تم إشعار العميل بالمشكلة لإعادة رفع الإشعار':
        'Customer notified to re-upload the transfer receipt',
    'يمكنك اختيار التوصيل أو الاستلام لكل محل في الخطوة التالية.':
        'You can choose delivery or pickup for each shop in the next step.',
    'يمكنك اختيار الاستلام الشخصي (مجاناً) في الخطوة التالية.':
        'You can choose self-pickup (free) in the next step.',
    'ألوان وصور القطعة': 'Item Colors & Photos',
    'قطع أخرى للتجربة': 'Other Items to Try',
    'ألوان القطعة': 'Colors',
    'قطع أخرى': 'Other Items',
    'جارٍ تجهيز التجربة الافتراضية': 'Preparing Virtual Try-On',
    'التجربة جاهزة الآن!': 'Try-On is Ready!',
    'تم التحقق من الكاميرا والقطعة بنجاح.':
        'Camera and garment verified successfully.',
    'نتحقق من الكاميرا والاتصال ونجهّز القطعة لتدخل على بث جاهز مباشرة.':
        'Verifying camera, connection, and preparing your outfit so you enter a ready live preview.',
    'الكاميرا والاتصال': 'Camera & Connection',
    'تجهيز القطعة': 'Garment Ready',
    'البث المباشر': 'Live Stream',
    'دخول للتجربة الآن': 'Enter Try-On Now',
    'إلغاء والعودة للمنتج': 'Cancel & Back to Product',
    'إيقاف التجربة': 'Stop Try-On',
    'القطع': 'Items',
    'القطعة': 'Garment',
    'الأصلية': 'Original',
    'توفير النت': 'Data Saver',
    'جودة عالية': 'High Quality',
    'جارٍ التبديل…': 'Switching…',
    'جارٍ تجهيز الإطلالة…': 'Preparing look…',
    'انتهت جلسات التجربة المتاحة لليوم، نراك مجدداً قريباً.':
        'Today\'s try-on sessions have ended. See you again soon.',
    'يرجى السماح بالوصول إلى الكاميرا ثم إعادة المحاولة.':
        'Please allow camera access and try again.',
    'تعذر إكمال البث حالياً، تحقق من الإنترنت وجرّب مجدداً.':
        'Unable to continue the preview right now. Please check your connection and try again.',
    'انتهت محاولاتك اليومية': 'Daily Attempts Finished',
    'التجربة متوقفة مؤقتاً': 'Try-On Temporarily Paused',
    'انتهت المحاولات': 'No Tries Left',
    'خدمة تجربة الملابس الافتراضية متوقفة مؤقتاً لنفاد رصيد التجربة في التطبيق، وسيتم تفعيلها مجدداً فور تجديده من قبل الإدارة.':
        'Virtual try-on is temporarily paused because the app\'s try-on credits have run out. It will be back as soon as the admin refills them.',
    'ميزة تجربة الملابس الافتراضية متوقفة مؤقتاً من قبل الإدارة. يرجى المحاولة لاحقاً.':
        'Virtual try-on is temporarily paused by the administration. Please try again later.',
    'لا يوجد اتصال بالإنترنت': 'No Internet Connection',
    'بدون إنترنت': 'Offline',
    'ميزة تجربة الملابس الافتراضية تحتاج إلى اتصال نشط بالإنترنت. يرجى الاتصال بالإنترنت ثم المحاولة مجدداً.':
        'Virtual try-on requires an active internet connection. Please connect to the internet and try again.',
    'تخصيص أنواع الإشعارات': 'Customize Notification Types',
    'اختر أنواع التنبيهات التي تود استلامها على جهازك في أي وقت.':
        'Choose which types of alerts you want to receive on your device at any time.',
    'الطلبات والمدفوعات': 'Orders & Payments',
    'العروض والخصومات': 'Offers & Discounts',
    'المنتجات والتقييمات': 'Products & Reviews',
    'النظام والإدارة': 'System & Admin',
    'تنبيهات الطلبات الجديدة وتحديثات الشحن وإيصالات الدفع والتسويات':
        'New orders, shipping updates, payment receipts, and settlements',
    'الخصومات الحصرية والعروض المؤقتة والبنرات الترويجية':
        'Exclusive discounts, timed offers, and promotional banners',
    'وصول المنتجات الجديدة وتقييمات العملاء على القطع':
        'New product arrivals and customer reviews',
    'إشعارات الإدارة وحالة المتجر والاشتراكات وتنبيهات المنصة':
        'Admin notices, shop status, subscriptions, and platform alerts',
    'النظام': 'System',
    'تحديد الكل كمقروء': 'Mark All as Read',
    'غير مقروء': 'Unread',
    'أمس': 'Yesterday',
    'هذا الأسبوع': 'This Week',
    'سابقاً': 'Earlier',
    'الآن': 'Just now',
    'مفعّلة — اضغط لتخصيص أنواع الإشعارات':
        'Enabled — tap to customize notification types',
    'مرفوضة من النظام — اضغط لفتح إعدادات الجهاز':
        'Blocked by system — tap to open device settings',
    'موعد التسليم': 'Delivery Schedule',
    'تحديد موعد التسليم': 'Set Delivery Schedule',
    'حفظ وإشعار العميل': 'Save & Notify Customer',
    'تم حفظ موعد التسليم وإشعار العميل':
        'Delivery schedule saved and customer notified',
    'تعذر حفظ موعد التسليم': 'Could not save delivery schedule',
    'محدد من المحل': 'Set by Shop',
    'بانتظار التحديد': 'Pending',
    'تحديد': 'Set',
    'يوم التسليم': 'Delivery Day',
    'غداً': 'Tomorrow',
    'بعد غد': 'Day After Tomorrow',
    'تاريخ آخر': 'Pick Date',
    'خلال ساعتين': 'Within 2 hours',
    'صباحاً (10 ص - 1 م)': 'Morning (10 AM - 1 PM)',
    'ظهراً (1 م - 4 م)': 'Afternoon (1 PM - 4 PM)',
    'مساءً (4 م - 8 م)': 'Evening (4 PM - 8 PM)',
    'ملاحظة للعميل (اختياري)': 'Note for Customer (Optional)',
    'ملاحظة من المحل': 'Note from Shop',
    'ملاحظة العميل': 'Customer Note',
    'المحل والتواصل': 'Shop & Contact',
    'العميل والتواصل': 'Customer & Contact',
    'واتساب': 'WhatsApp',
    'اتصال': 'Call',
    'نسخ العنوان': 'Copy Address',
    'تأخر / مشكلة؟': 'Delay / Issue?',
    'استفسار أو متابعة الطلب': 'Order Inquiry & Follow-Up',
    'تأخر في تأكيد الطلب': 'Delay in confirmation',
    'تأخر في التوصيل': 'Delivery delay',
    'استفسار عن موعد التسليم': 'Delivery schedule inquiry',
    'مشكلة أو استفسار آخر': 'Other issue or question',
    'تفاصيل إضافية (اختياري)': 'Additional details (optional)',
    'اكتب رسالتك للمحل باختصار...': 'Write a brief message for the shop...',
    'إرسال نسخة لإدارة التطبيق': 'Send a copy to App Admin',
    'في حال تأخر رد المحل أو وجود مشكلة لم تُحل':
        'If the shop is unresponsive or an issue remains unresolved',
    'إرسال المتابعة': 'Send Inquiry',
    'تم إرسال استفسارك للمحل بنجاح': 'Inquiry sent to the shop',
    'تم إرسال رسالتك للمحل وللإدارة للمتابعة':
        'Message sent to the shop and admin team',
    'التوصيل والدفع': 'Delivery & Payment',
    'القطع المطلوبة': 'Ordered Items',
    'مراحل الطلب': 'Order Stages',
    'تأكيد المحل': 'Shop Confirmed',
    'تجهيز الطلب': 'Preparing Order',
    'في الطريق إليك': 'On the Way',
    'جاهز للاستلام': 'Ready for Pickup',
    'مراجعة توفر القطع وتحديد موعد التسليم':
        'Checking item availability and setting delivery time',
    'تجهيز وتغليف المقاسات المطلوبة': 'Packing your selected sizes and colors',
    'يمكنك الاستلام من المحل': 'Ready to be picked up from the shop',
    'الطلب مع مندوب التوصيل': 'Out for delivery to your address',
    'اكتمل الطلب بنجاح': 'Order delivered successfully',
    'سيحدد المحل موعد التسليم فور تأكيد طلبك وسيصلك إشعار مباشرة.':
        'The shop will set the delivery time once confirmed and notify you immediately.',
    'اضغط لتحديد يوم وفترة التسليم وإشعار العميل':
        'Tap to set delivery day & time window and notify customer',
    'انتظار': 'Pending',
    'استلام': 'Pickup',
    'المزيد': 'More',
    'تغيير حالة الطلب': 'Change Order Status',
    'تحديد كجاهز للاستلام': 'Mark Ready for Pickup',
    'تم الشحن مع المندوب': 'Mark as Shipped',
    'تأكيد الحوالة': 'Confirm Transfer',
    'مشكلة في الإشعار': 'Receipt Issue',
    'الحوالة المالية': 'Bank / Wallet Transfer',
    'هذا الطلب ملغي': 'This order is cancelled',
    'تفاصيل القطع غير متوفرة حالياً': 'Item details are currently unavailable',
    'تعذر فتح تطبيق الاتصال': 'Could not open phone dialer',
    'تعذر فتح واتساب على هذا الجهاز': 'Could not open WhatsApp on this device',
    'رفع من المعرض': 'From Gallery',
    'تم إلغاء هذا الطلب': 'This order was cancelled',
    'يلزم تحديث إشعار الحوالة': 'Transfer receipt update required',
    'بانتظار مراجعة الحوالة وتأكيد المحل':
        'Waiting for transfer check and shop confirmation',
    'تم إرسال طلبك للمحل وبانتظار التأكيد':
        'Sent to shop, waiting for confirmation',
    'أكد المحل طلبك وسيبدأ التجهيز قريباً':
        'Order confirmed; preparation starts soon',
    'المحل يجهّز ويغلّف طلبك حالياً': 'The shop is packing your order now',
    'طلبك جاهز للاستلام من المحل': 'Your order is ready for pickup',
    'طلبك في الطريق إليك الآن': 'Your order is on the way',
    'تم تسليم طلبك بنجاح': 'Your order has been delivered',
  };
}

class _PatternRule {
  const _PatternRule(this.pattern, this.builder);
  final RegExp pattern;
  final String Function(RegExpMatch match) builder;
}

extension AppStringTranslation on String {
  String get tr => AppLang.tr(this);
}
