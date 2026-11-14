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
    _PatternRule(
      RegExp(r'^(\d+) قطع$'),
      (m) => '${m.group(1)} items',
    ),
    _PatternRule(
      RegExp(r'^(\d+) قطعة$'),
      (m) => '${m.group(1)} pcs',
    ),
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
    _PatternRule(
      RegExp(r'^طلب #(.+)$'),
      (m) => 'Order #${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^الطلب الحالي: (.+)$'),
      (m) => 'Current Order: ${tr(m.group(1)!)}',
    ),
    _PatternRule(
      RegExp(r'^المتجر: (.+)$'),
      (m) => 'Shop: ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^المحل: (.+)$'),
      (m) => 'Shop: ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^الكمية: (\d+)$'),
      (m) => 'Qty: ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^المواصفات: (.+)$'),
      (m) => 'Specs: ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^المقاس: (.+)$'),
      (m) => 'Size: ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^بحث: (.+)$'),
      (m) => 'Search: ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^السعر: (.+)$'),
      (m) => 'Price: ${m.group(1)}',
    ),
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
    _PatternRule(
      RegExp(r'^التالي: (.+)$'),
      (m) => 'Next: ${tr(m.group(1)!)}',
    ),
    _PatternRule(
      RegExp(r'^تعديل (.+)$'),
      (m) => 'Edit ${tr(m.group(1)!)}',
    ),
    _PatternRule(
      RegExp(r'^صورة (\d+)$'),
      (m) => 'Image ${m.group(1)}',
    ),
    _PatternRule(
      RegExp(r'^(\d+)٪ مكتمل$'),
      (m) => '${m.group(1)}% complete',
    ),
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
    // --- App & Navigation ---
    'ملابسي': 'Shopy',
    'Shopy': 'Shopy',
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
    'مؤكد': 'Confirmed',
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
    'لا توجد إشعارات حالياً': 'No Notifications Yet',
    'لا توجد إشعارات جديدة': 'No New Notifications',
    'ستصلك هنا العروض الحصرية وتحديثات طلباتك':
        'Exclusive offers and order status updates will appear here',

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
