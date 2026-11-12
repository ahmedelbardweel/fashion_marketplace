// =============================================================================
//  ملف التصميم الموحّد للتطبيق  —  APP DESIGN SYSTEM
// =============================================================================
//
//  هذا هو الملف الوحيد الذي تحتاجه لتعديل شكل التطبيق بالكامل.
//  كل الألوان، الخطوط، سماكة الخط (Bold)، الحواف الدائرية، البوردر،
//  الظلال، المسافات، ومقاسات العناصر لكل صفحة موجودة هنا.
//
//  طريقة الاستخدام:
//   - غيّر اللون الرئيسي من [AppPalette.primary] فيتغير في كل التطبيق.
//   - غيّر لون الخط من [AppPalette.ink] ولون الأيقونات من [AppColors.icon].
//   - كل صفحة لها قسم خاص بها (ابحث عن اسم الصفحة مثل: ProductDetailsDesign).
//
//  ملاحظة: لا تضع أي لون أو مقاس مباشرة داخل الشاشات؛ أضفه هنا ثم استخدمه.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

export 'package:iconsax_plus/iconsax_plus.dart';

// =============================================================================
//  0) مكتبة الأيقونات الموحّدة  —  UNIFIED APP ICONS (Iconsax Plus)
// =============================================================================
//  جميع الأيقونات في التطبيق تستخدم مكتبة Iconsax Plus الاحترافية والموحدة.
//  لتغيير أي أيقونة في التطبيق بالكامل، غيّرها من هنا فقط.
// =============================================================================
abstract final class AppIcons {
  // --- التنقل والأسهم (متوافقة مع اتجاه العربية RTL) ---
  static const IconData back = IconsaxPlusLinear.arrow_right_1;
  static const IconData forward = IconsaxPlusLinear.arrow_left_2;
  static const IconData arrowForward = IconsaxPlusLinear.arrow_left;
  static const IconData chevronDown = IconsaxPlusLinear.arrow_down_1;
  static const IconData arrowUp = IconsaxPlusLinear.arrow_up;
  static const IconData arrowDown = IconsaxPlusLinear.arrow_down;
  static const IconData close = IconsaxPlusLinear.close_circle;
  static const IconData fullscreen = IconsaxPlusLinear.maximize_4;

  // --- شريط التنقل السفلي والأقسام الرئيسية (Linear & Bold) ---
  static const IconData home = IconsaxPlusLinear.home_2;
  static const IconData homeActive = IconsaxPlusBold.home_2;

  static const IconData catalog = IconsaxPlusLinear.category;
  static const IconData catalogActive = IconsaxPlusBold.category;

  static const IconData grid = IconsaxPlusLinear.element_3;
  static const IconData gridActive = IconsaxPlusBold.element_3;

  static const IconData heart = IconsaxPlusLinear.heart;
  static const IconData heartFilled = IconsaxPlusBold.heart;

  static const IconData bag = IconsaxPlusLinear.bag_2;
  static const IconData bagFilled = IconsaxPlusBold.bag_2;
  static const IconData addToCart = IconsaxPlusLinear.bag_tick_2;

  static const IconData orders = IconsaxPlusLinear.receipt_2_1;
  static const IconData ordersActive = IconsaxPlusBold.receipt_2_1;

  static const IconData shop = IconsaxPlusLinear.shop;
  static const IconData shopActive = IconsaxPlusBold.shop;

  static const IconData user = IconsaxPlusLinear.user;
  static const IconData userActive = IconsaxPlusBold.user;

  static const IconData dashboard = IconsaxPlusLinear.status_up;
  static const IconData dashboardActive = IconsaxPlusBold.status_up;

  static const IconData settings = IconsaxPlusLinear.setting_2;
  static const IconData settingsActive = IconsaxPlusBold.setting_2;

  // --- البحث والفلترة والمقارنة ---
  static const IconData search = IconsaxPlusLinear.search_normal_1;
  static const IconData searchOff = IconsaxPlusLinear.search_status;
  static const IconData filter = IconsaxPlusLinear.setting_4;
  static const IconData compare = IconsaxPlusLinear.arrow_swap_horizontal;

  // --- الأزياء والمنتجات والتجربة الافتراضية (AR / AI Try-On) ---
  static const IconData garment = IconsaxPlusLinear.shopping_bag;
  static const IconData garmentFilled = IconsaxPlusBold.shopping_bag;
  static const IconData tryOn = IconsaxPlusLinear.d_cube_scan;
  static const IconData tryOnFilled = IconsaxPlusBold.d_cube_scan;
  static const IconData sparkles = IconsaxPlusLinear.magic_star;
  static const IconData sparklesFilled = IconsaxPlusBold.magic_star;
  static const IconData camera = IconsaxPlusLinear.camera;
  static const IconData cameraFilled = IconsaxPlusBold.camera;
  static const IconData flipCamera = IconsaxPlusLinear.refresh_2;
  static const IconData bodyGuide = IconsaxPlusLinear.man;
  static const IconData focus = IconsaxPlusLinear.scan;
  static const IconData sun = IconsaxPlusLinear.sun_1;
  static const IconData ruler = IconsaxPlusLinear.ruler;

  // --- التقييمات والمراجعات ---
  static const IconData star = IconsaxPlusLinear.star_1;
  static const IconData starFilled = IconsaxPlusBold.star_1;
  static const IconData reviews = IconsaxPlusLinear.messages_2;
  static const IconData rateReview = IconsaxPlusLinear.message_edit;

  // --- الحساب والحقول والبيانات الشخصية ---
  static const IconData mail = IconsaxPlusLinear.sms;
  static const IconData lock = IconsaxPlusLinear.lock;
  static const IconData eye = IconsaxPlusLinear.eye;
  static const IconData eyeOff = IconsaxPlusLinear.eye_slash;
  static const IconData phone = IconsaxPlusLinear.call;
  static const IconData location = IconsaxPlusLinear.location;
  static const IconData city = IconsaxPlusLinear.buildings;
  static const IconData notes = IconsaxPlusLinear.note_text;
  static const IconData payment = IconsaxPlusLinear.wallet_money;
  static const IconData logout = IconsaxPlusLinear.logout;
  static const IconData verified = IconsaxPlusBold.verify;
  static const IconData shieldTick = IconsaxPlusLinear.shield_tick;

  // --- الإشعارات والإجراءات والحالات ---
  static const IconData bell = IconsaxPlusLinear.notification;
  static const IconData bellActive = IconsaxPlusBold.notification_bing;
  static const IconData add = IconsaxPlusLinear.add;
  static const IconData remove = IconsaxPlusLinear.minus;
  static const IconData edit = IconsaxPlusLinear.edit_2;
  static const IconData delete = IconsaxPlusLinear.trash;
  static const IconData check = IconsaxPlusLinear.tick_circle;
  static const IconData checkCircle = IconsaxPlusLinear.tick_circle;
  static const IconData checkCircleFilled = IconsaxPlusBold.tick_circle;
  static const IconData radioUnchecked = IconsaxPlusLinear.record;
  static const IconData error = IconsaxPlusLinear.danger;
  static const IconData info = IconsaxPlusLinear.info_circle;
  static const IconData refresh = IconsaxPlusLinear.refresh;
  static const IconData imageBroken = IconsaxPlusLinear.gallery_slash;
  static const IconData addPhoto = IconsaxPlusLinear.gallery_add;
  static const IconData inbox = IconsaxPlusLinear.direct_inbox;
}

// =============================================================================
//  1) لوحة الألوان الخام  —  RAW PALETTE
// =============================================================================
abstract final class AppPalette {
  /// اللون الرئيسي (تركوازي).
  static const Color primary = Color(0xFF007C83);

  /// درجة أغمق من اللون الرئيسي (للضغط / النصوص فوق الخلفيات الفاتحة).
  static const Color primaryDark = Color(0xFF00807C);

  /// خلفية تركوازية فاتحة جداً (للعناصر المحددة والبطاقات المميزة).
  static const Color primarySoft = Color(0xFFE6F6F5);

  /// حدود تركوازية فاتحة.
  static const Color primaryBorder = Color(0xFFADE0DE);

  /// لون الحبر (الخط الأساسي) — أسود.
  static const Color ink = Color(0xFF111111);

  static const Color white = Color(0xFFFFFFFF);
  static const Color gray900 = Color(0xFF1C1C1C);
  static const Color gray700 = Color(0xFF4A4A4A);
  static const Color gray500 = Color(0xFF8A8A8A);
  static const Color gray400 = Color(0xFFB4B4B4);
  static const Color gray300 = Color(0xFFD6D6D6);
  static const Color gray200 = Color(0xFFE9E9E9);
  static const Color gray100 = Color(0xFFF4F4F4);
  static const Color gray50 = Color(0xFFF8F8F8);

  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFDECEA);
  static const Color green = Color(0xFF12A150);
  static const Color greenSoft = Color(0xFFE8F7EE);
  static const Color amber = Color(0xFFB54708);
  static const Color amberSoft = Color(0xFFFFF4E5);
}

// =============================================================================
//  2) الألوان الدلالية  —  SEMANTIC COLORS (تستخدم في كل التطبيق)
// =============================================================================
class AppColors {
  AppColors._();

  // --- اللون الرئيسي ---
  static const Color primary = AppPalette.primary;
  static const Color primaryDark = AppPalette.primaryDark;
  static const Color primarySoft = AppPalette.primarySoft;
  static const Color primaryBorder = AppPalette.primaryBorder;
  static const Color onPrimary = AppPalette.white;

  // --- الخطوط ---
  /// لون الخط الأساسي (أسود).
  static const Color text = AppPalette.ink;

  /// لون الخط الثانوي (وصف، تفاصيل).
  static const Color textSecondary = AppPalette.gray700;

  /// لون الخط الخافت (تلميحات، تواريخ).
  static const Color textMuted = AppPalette.gray500;

  // --- الأيقونات ---
  /// لون الأيقونات الأساسي (أسود).
  static const Color icon = AppPalette.ink;

  /// لون الأيقونات غير النشطة.
  static const Color iconMuted = AppPalette.gray500;

  // --- الخلفيات ---
  static const Color background = AppPalette.white;
  static const Color surface = AppPalette.white;

  /// خلفية ثانوية (حقول، صناديق صور، أقسام).
  static const Color surfaceAlt = AppPalette.gray100;

  /// خلفية خافتة جداً.
  static const Color surfaceSubtle = AppPalette.gray50;

  // --- الحدود ---
  /// البوردر الموحد لكل التطبيق.
  static const Color border = AppPalette.gray200;
  static const Color borderStrong = AppPalette.gray300;
  static const Color divider = AppPalette.gray200;

  // --- الحالات ---
  static const Color error = AppPalette.red;
  static const Color errorSoft = AppPalette.redSoft;
  static const Color success = AppPalette.green;
  static const Color successSoft = AppPalette.greenSoft;
  static const Color warning = AppPalette.amber;
  static const Color warningSoft = AppPalette.amberSoft;

  /// لون نجوم التقييم.
  static const Color rating = AppPalette.ink;

  /// طبقة التعتيم خلف النوافذ المنبثقة.
  static const Color scrim = Color(0x73000000);

  // --- أسماء قديمة (متوافقة مع الكود الحالي) ---
  /// أسود حقيقي للخطوط والأيقونات.
  static const Color black = AppPalette.ink;
  static const Color white = AppPalette.white;
  static const Color gray900 = AppPalette.gray900;
  static const Color gray700 = AppPalette.gray700;
  static const Color gray500 = AppPalette.gray500;
  static const Color gray300 = AppPalette.gray300;
  static const Color gray100 = AppPalette.gray100;
  static const Color onBackground = text;
  static const Color onSurface = text;
  static const Color secondary = AppPalette.gray700;
}

// =============================================================================
//  3) الخطوط  —  TYPOGRAPHY
// =============================================================================
abstract final class AppFont {
  /// اسم خط Google المستخدم (يُطبق في app_typography.dart).
  static const String googleFamily = 'IBM Plex Sans Arabic';

  // --- سماكة الخط (Bold) ---
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  // --- أحجام الخط ---
  static const double display = 30;
  static const double headline = 24;
  static const double title = 18;
  static const double subtitle = 16;
  static const double body = 14;
  static const double small = 12;
  static const double tiny = 11;

  // --- أوزان عناصر الثيم العام ---
  static const FontWeight headlineWeight = bold;
  static const FontWeight titleWeight = bold;
  static const FontWeight subtitleWeight = semiBold;
  static const FontWeight bodyWeight = regular;
  static const FontWeight labelWeight = bold;

  static const double bodyHeight = 1.55;
}

// =============================================================================
//  4) الحواف الدائرية  —  RADII
// =============================================================================
class AppRadii {
  AppRadii._();

  /// حواف صغيرة (شارات، عناصر صغيرة).
  static const double xs = 6;

  /// الحواف الافتراضية للعناصر الصغيرة والحاويات.
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;

  /// حواف البطاقات.
  static const double card = 16;

  /// حواف الصور داخل البطاقات والقوائم.
  static const double image = 14;

  /// حواف النوافذ الحوارية.
  static const double dialog = 20;

  /// حواف أعلى النافذة السفلية.
  static const double bottomSheet = 24;

  /// حواف حقول الإدخال.
  static const double input = 14;

  /// حواف الأزرار.
  static const double button = 14;

  /// حواف الشرائح (Chips).
  static const double chip = 12;

  /// شكل كبسولة كامل.
  static const double pill = 999;
}

// =============================================================================
//  5) البوردر  —  BORDERS
// =============================================================================
abstract final class AppBorders {
  static const double width = 1;
  static const double widthStrong = 1.5;
  static const double widthSelected = 1.6;

  static const BorderSide side = BorderSide(color: AppColors.border, width: width);
  static const BorderSide selected = BorderSide(
    color: AppColors.primary,
    width: widthSelected,
  );
}

// =============================================================================
//  6) الظلال  —  SHADOWS
// =============================================================================
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  /// ظل خفيف جداً للبطاقات.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// ظل للأزرار العائمة فوق الصور.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// ظل الشريط السفلي الثابت.
  static const List<BoxShadow> bar = [
    BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, -4)),
  ];
}

// =============================================================================
//  7) المسافات  —  SPACING
// =============================================================================
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// المسافة الجانبية لكل الصفحات.
  static const double pageGutter = 16;

  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: pageGutter,
    vertical: md,
  );

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: pageGutter,
  );
}

// =============================================================================
//  8) الحركة  —  MOTION
// =============================================================================
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
}

// =============================================================================
//  9) العملة والأرقام
// =============================================================================
abstract final class AppFormat {
  static const String currency = 'ر.س';
  static String price(num value) => '${value.toStringAsFixed(2)} $currency';
}

// #############################################################################
//                              المكونات المشتركة
// #############################################################################

// -----------------------------------------------------------------------------
//  شريط التطبيق العلوي  —  APP BAR
// -----------------------------------------------------------------------------
abstract final class AppBarDesign {
  static const double height = 64;
  static const Color background = AppColors.white;
  static const Color iconColor = AppColors.icon;
  static const double iconSize = 24;
  static const Color titleColor = AppColors.text;
  static const double titleSize = 18;
  static const FontWeight titleWeight = AppFont.bold;
  static const bool showBottomBorder = true;
  static const Color borderColor = AppColors.border;

  // البحث داخل الشريط
  static const double searchHeight = 44;
  static const Color searchBackground = AppColors.surfaceAlt;
  static const Color searchBorder = Colors.transparent;
  static const double searchRadius = AppRadii.pill;
  static const Color searchIcon = AppColors.icon;
  static const Color searchHint = AppColors.textMuted;
  static const String searchHintText = 'ابحث عن قميص، فستان، هودي...';

  // الشارة فوق أيقونة السلة
  static const Color badgeBackground = AppColors.primary;
  static const Color badgeText = AppColors.onPrimary;
}

// -----------------------------------------------------------------------------
//  الشريط السفلي للتنقل  —  BOTTOM NAVIGATION
// -----------------------------------------------------------------------------
abstract final class BottomNavDesign {
  static const Color background = AppColors.white;
  static const Color borderColor = AppColors.border;
  static const double topRadius = 0;
  static const double height = 64;
  static const double iconSize = 24;
  static const Color selectedIcon = AppColors.icon;
  static const Color unselectedIcon = AppColors.iconMuted;
  static const Color selectedLabel = AppColors.text;
  static const Color unselectedLabel = AppColors.textMuted;
  static const double labelSize = 11;
  static const FontWeight selectedWeight = AppFont.bold;
  static const FontWeight unselectedWeight = AppFont.medium;

  /// الخلفية خلف الأيقونة المحددة.
  static const Color indicator = AppColors.primarySoft;
  static const double indicatorWidth = 56;
  static const double indicatorHeight = 30;
  static const double indicatorRadius = AppRadii.pill;
}

// -----------------------------------------------------------------------------
//  الأزرار  —  BUTTONS
// -----------------------------------------------------------------------------
abstract final class ButtonDesign {
  static const double height = 52;
  static const double heightSmall = 40;
  static const double radius = AppRadii.button;
  static const double textSize = 15;
  static const FontWeight textWeight = AppFont.bold;

  // الزر الرئيسي
  static const Color primaryBackground = AppColors.primary;
  static const Color primaryForeground = AppColors.onPrimary;
  static const Color disabledBackground = AppPalette.gray200;
  static const Color disabledForeground = AppPalette.gray500;

  // الزر المحدد بحدود
  static const Color outlinedForeground = AppColors.text;
  static const Color outlinedBorder = AppColors.borderStrong;
  static const Color outlinedBackground = AppColors.white;

  // الزر النصي
  static const Color textForeground = AppColors.text;

  // زر الأيقونة
  static const Color iconButtonColor = AppColors.icon;
  static const Color iconButtonBorder = AppColors.border;
  static const double iconButtonRadius = AppRadii.pill;
}

// -----------------------------------------------------------------------------
//  حقول الإدخال  —  INPUTS
// -----------------------------------------------------------------------------
abstract final class InputDesign {
  static const Color fill = AppColors.surfaceAlt;
  static const Color border = Colors.transparent;
  static const Color focusedBorder = AppColors.primary;
  static const Color errorBorder = AppColors.error;
  static const double borderWidth = 1;
  static const double focusedBorderWidth = 1.5;
  static const double radius = AppRadii.input;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 15,
  );
  static const Color text = AppColors.text;
  static const Color hint = AppColors.textMuted;
  static const Color label = AppColors.text;
  static const FontWeight labelWeight = AppFont.semiBold;
  static const Color prefixIcon = AppColors.icon;
  static const Color cursor = AppColors.primary;
}

// -----------------------------------------------------------------------------
//  الشرائح (الفلاتر / الخيارات)  —  CHIPS
// -----------------------------------------------------------------------------
abstract final class ChipDesign {
  static const double height = 38;
  static const double radius = AppRadii.pill;
  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 16);
  static const Color background = AppColors.surfaceAlt;
  static const Color border = Colors.transparent;
  static const Color text = AppColors.text;
  static const FontWeight textWeight = AppFont.semiBold;
  static const Color selectedBackground = AppColors.primary;
  static const Color selectedBorder = AppColors.primary;
  static const Color selectedText = AppColors.onPrimary;
  static const FontWeight selectedWeight = AppFont.bold;
  static const double textSize = 13;
}

// -----------------------------------------------------------------------------
//  البطاقات العامة  —  GENERIC CARD (AppCard)
// -----------------------------------------------------------------------------
abstract final class CardDesign {
  static const Color background = AppColors.white;
  static const Color border = AppColors.border;
  static const double borderWidth = AppBorders.width;
  static const double radius = AppRadii.card;
  static const EdgeInsets padding = EdgeInsets.all(16);
  static const List<BoxShadow> shadow = AppShadows.none;
}

// -----------------------------------------------------------------------------
//  شارات الحالة  —  STATUS BADGE
// -----------------------------------------------------------------------------
abstract final class BadgeDesign {
  static const double radius = AppRadii.pill;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 4,
  );
  static const double textSize = 12;
  static const FontWeight textWeight = AppFont.bold;
  static const Color neutralBackground = AppColors.surfaceAlt;
  static const Color neutralText = AppColors.text;
  static const Color primaryBackground = AppColors.primarySoft;
  static const Color primaryText = AppColors.primaryDark;
  static const Color successBackground = AppColors.successSoft;
  static const Color successText = AppColors.success;
  static const Color warningBackground = AppColors.warningSoft;
  static const Color warningText = AppColors.warning;
  static const Color errorBackground = AppColors.errorSoft;
  static const Color errorText = AppColors.error;
}

// -----------------------------------------------------------------------------
//  النافذة السفلية  —  BOTTOM SHEET
// -----------------------------------------------------------------------------
abstract final class SheetDesign {
  static const Color background = AppColors.white;
  static const double topRadius = AppRadii.bottomSheet;
  static const Color scrim = AppColors.scrim;
  static const Color handle = AppPalette.gray300;
  static const double handleWidth = 40;
  static const double handleHeight = 4;
  static const double maxHeightFactor = 0.92;
  static const double titleSize = 18;
  static const FontWeight titleWeight = AppFont.bold;
}

// -----------------------------------------------------------------------------
//  رسائل التنبيه السفلية  —  SNACKBAR
// -----------------------------------------------------------------------------
abstract final class SnackBarDesign {
  static const Color background = AppPalette.ink;
  static const Color errorBackground = AppPalette.red;
  static const Color text = AppColors.white;
  static const Color action = AppPalette.primarySoft;
  static const double radius = AppRadii.md;
}

// -----------------------------------------------------------------------------
//  هيكل التحميل  —  SKELETON
// -----------------------------------------------------------------------------
abstract final class SkeletonDesign {
  static const Color base = Color(0xFFE9E9E9);
  static const Color highlight = Color(0xFFF7F7F7);
  static const Duration duration = Duration(milliseconds: 1400);
}

// -----------------------------------------------------------------------------
//  الحالة الفارغة  —  EMPTY STATE
// -----------------------------------------------------------------------------
abstract final class EmptyStateDesign {
  static const double iconCircleSize = 88;
  static const Color iconCircleBackground = AppColors.surfaceAlt;
  static const double iconSize = 38;
  static const Color iconColor = AppColors.icon;
  static const double titleSize = 17;
  static const FontWeight titleWeight = AppFont.bold;
  static const Color titleColor = AppColors.text;
  static const Color messageColor = AppColors.textMuted;
}

// -----------------------------------------------------------------------------
//  عنوان القسم  —  SECTION HEADER
// -----------------------------------------------------------------------------
abstract final class SectionDesign {
  static const double titleSize = 18;
  static const FontWeight titleWeight = AppFont.extraBold;
  static const Color titleColor = AppColors.text;
  static const double actionSize = 13;
  static const FontWeight actionWeight = AppFont.bold;
  static const Color actionColor = AppColors.primaryDark;
  static const double spacingBelow = 12;
  static const double spacingBetweenSections = 28;
}

// #############################################################################
//                                 الصفحات
// #############################################################################

// -----------------------------------------------------------------------------
//  بطاقة المنتج (في الرئيسية، المنتجات، المفضلة، المتجر)  —  PRODUCT CARD
//  تعرض فقط: الصورة + السعر + زر المفضلة فوق الصورة + زر الإضافة للسلة.
// -----------------------------------------------------------------------------
abstract final class ProductCardDesign {
  // --- الصورة ---
  /// نسبة العرض إلى الارتفاع (أقل من 1 = صورة طولية).
  static const double imageAspectRatio = 0.78;
  static const double imageRadius = AppRadii.image;
  static const Color imageBackground = AppColors.surfaceAlt;
  static const Color imageBorderColor = AppColors.border;
  static const double imageBorderWidth = 1;
  static const BoxFit imageFit = BoxFit.cover;
  static const Color placeholderIcon = AppColors.iconMuted;

  // --- البطاقة ---
  static const Color cardBackground = Colors.transparent;
  static const Color cardBorderColor = Colors.transparent;
  static const double cardBorderWidth = 0;
  static const double cardRadius = AppRadii.card;
  static const EdgeInsets cardPadding = EdgeInsets.zero;
  static const List<BoxShadow> cardShadow = AppShadows.none;

  // --- زر المفضلة فوق الصورة ---
  static const AlignmentDirectional favoriteAlignment =
      AlignmentDirectional.topEnd;
  static const double favoriteInset = 8;
  static const double favoriteSize = 34;
  static const double favoriteIconSize = 18;
  static const Color favoriteBackground = Color(0xF2FFFFFF);
  static const Color favoriteIcon = AppColors.icon;
  static const Color favoriteActiveIcon = AppColors.icon;
  static const List<BoxShadow> favoriteShadow = AppShadows.soft;

  // --- السعر ---
  static const double infoTopSpacing = 10;
  static const double priceSize = 15;
  static const FontWeight priceWeight = AppFont.extraBold;
  static const Color priceColor = AppColors.text;

  // --- زر الإضافة للسلة ---
  static const double cartButtonSize = 38;
  static const double cartButtonRadius = AppRadii.pill;
  static const double cartIconSize = 19;
  static const Color cartButtonBackground = AppColors.primary;
  static const Color cartButtonIcon = AppColors.onPrimary;
  static const Color cartButtonDisabledBackground = AppPalette.gray200;
  static const Color cartButtonDisabledIcon = AppPalette.gray500;

  // --- نفاد الكمية ---
  static const double outOfStockImageOpacity = 0.55;
  static const Color outOfStockBadgeBackground = AppPalette.ink;
  static const Color outOfStockBadgeText = AppColors.white;
  static const String outOfStockLabel = 'نفدت الكمية';

  /// ارتفاع منطقة السعر والزر أسفل الصورة (لحساب الشبكة).
  static const double infoHeight = 48;
}

// -----------------------------------------------------------------------------
//  شبكة المنتجات  —  PRODUCT GRID
// -----------------------------------------------------------------------------
abstract final class ProductGridDesign {
  static const double minCardWidth = 160;
  static const int minColumns = 2;
  static const int maxColumns = 6;
  static const double crossSpacing = 12;
  static const double mainSpacing = 20;
}

// -----------------------------------------------------------------------------
//  صفحة تفاصيل المنتج  —  PRODUCT DETAILS
// -----------------------------------------------------------------------------
abstract final class ProductDetailsDesign {
  static const Color pageBackground = AppColors.white;

  // --- معرض الصور العلوي (مختلف عن صورة البطاقة: كامل العرض وطولي) ---
  /// نسبة ارتفاع المعرض من ارتفاع الشاشة.
  static const double galleryHeightFactor = 0.6;
  static const double galleryMinHeight = 360;
  static const double galleryMaxHeight = 640;
  static const Color galleryBackground = AppColors.surfaceSubtle;
  static const BoxFit galleryImageFit = BoxFit.cover;

  // --- الأزرار العائمة فوق المعرض ---
  static const double floatingButtonSize = 42;
  static const double floatingIconSize = 21;
  static const Color floatingButtonBackground = Color(0xF2FFFFFF);
  static const Color floatingButtonIcon = AppColors.icon;
  static const List<BoxShadow> floatingButtonShadow = AppShadows.floating;

  // --- عداد الصور (1/4) ---
  static const Color counterBackground = Color(0x99000000);
  static const Color counterText = AppColors.white;
  static const double counterTextSize = 12;

  // --- زر التجربة الافتراضية فوق الصورة ---
  static const Color tryOnPillBackground = AppColors.white;
  static const Color tryOnPillText = AppColors.text;
  static const Color tryOnPillIcon = AppColors.primary;
  static const double tryOnPillHeight = 38;

  // --- الصور المصغرة ---
  static const double thumbSize = 58;
  static const double thumbRadius = AppRadii.sm;
  static const Color thumbBorder = AppColors.border;
  static const Color thumbActiveBorder = AppColors.primary;
  static const double thumbActiveBorderWidth = 2;
  static const double thumbSpacing = 8;

  // --- ورقة المحتوى المتداخلة مع الصورة ---
  static const double contentOverlap = 22;
  static const double contentRadius = 26;
  static const Color contentBackground = AppColors.white;
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(20, 22, 20, 0);

  // --- المتجر والعنوان والسعر ---
  static const double shopNameSize = 13;
  static const FontWeight shopNameWeight = AppFont.bold;
  static const Color shopNameColor = AppColors.primaryDark;
  static const double titleSize = 21;
  static const FontWeight titleWeight = AppFont.bold;
  static const Color titleColor = AppColors.text;
  static const double priceSize = 24;
  static const FontWeight priceWeight = AppFont.extraBold;
  static const Color priceColor = AppColors.text;

  // --- التقييم المختصر ---
  static const double ratingStarSize = 16;
  static const Color ratingStar = AppColors.rating;
  static const Color ratingStarEmpty = AppPalette.gray300;
  static const double ratingTextSize = 13;

  // --- عنوان كل قسم ---
  static const double sectionTitleSize = 15;
  static const FontWeight sectionTitleWeight = AppFont.bold;
  static const Color sectionValueColor = AppColors.textMuted;
  static const double sectionSpacing = 24;

  // --- خيارات اللون والمقاس ---
  static const double optionHeight = 44;
  static const double optionMinWidth = 52;
  static const double optionRadius = AppRadii.chip;
  static const EdgeInsets optionPadding = EdgeInsets.symmetric(horizontal: 16);
  static const Color optionBackground = AppColors.white;
  static const Color optionBorder = AppColors.borderStrong;
  static const double optionBorderWidth = 1;
  static const Color optionText = AppColors.text;
  static const FontWeight optionWeight = AppFont.semiBold;
  static const Color optionSelectedBackground = AppColors.primarySoft;
  static const Color optionSelectedBorder = AppColors.primary;
  static const double optionSelectedBorderWidth = 1.8;
  static const Color optionSelectedText = AppColors.text;
  static const FontWeight optionSelectedWeight = AppFont.extraBold;
  static const Color optionDisabledText = AppPalette.gray400;
  static const Color optionDisabledBackground = AppColors.surfaceSubtle;

  // --- حالة المخزون ---
  static const int lowStockThreshold = 5;
  static const Color inStockColor = AppColors.success;
  static const Color lowStockColor = AppColors.warning;
  static const Color outOfStockColor = AppColors.error;

  // --- بطاقة التجربة الافتراضية ---
  static const Color tryOnCardBackground = AppColors.primarySoft;
  static const Color tryOnCardBorder = AppColors.primaryBorder;
  static const double tryOnCardRadius = AppRadii.card;
  static const Color tryOnIconBackground = AppColors.primary;
  static const Color tryOnIcon = AppColors.onPrimary;

  // --- بطاقة المتجر ---
  static const double shopLogoSize = 46;
  static const double shopLogoRadius = AppRadii.pill;
  static const Color shopCardBorder = AppColors.border;
  static const double shopCardRadius = AppRadii.card;

  // --- الأقسام القابلة للطي (الوصف، التفاصيل، التقييمات) ---
  static const Color expandableDivider = AppColors.divider;
  static const Color expandableIcon = AppColors.icon;
  static const double expandableTitleSize = 15;
  static const FontWeight expandableTitleWeight = AppFont.bold;
  static const Color bodyTextColor = AppColors.textSecondary;
  static const double bodyTextSize = 14;
  static const Color specLabelColor = AppColors.textMuted;
  static const Color specValueColor = AppColors.text;
  static const FontWeight specValueWeight = AppFont.semiBold;

  // --- التقييمات ---
  static const double reviewAvatarSize = 38;
  static const Color reviewAvatarBackground = AppColors.surfaceAlt;
  static const Color reviewAvatarText = AppColors.text;
  static const double reviewStarSize = 14;
  static const double reviewPickerStarSize = 34;
  static const Color reviewCardBorder = AppColors.border;
  static const double reviewCardRadius = AppRadii.card;

  // --- الشريط السفلي الثابت (الكمية + أضف للسلة) ---
  static const Color bottomBarBackground = AppColors.white;
  static const Color bottomBarBorder = AppColors.border;
  static const List<BoxShadow> bottomBarShadow = AppShadows.bar;
  static const EdgeInsets bottomBarPadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const double bottomBarButtonHeight = 54;
  static const double stepperWidth = 120;
  static const Color stepperBackground = AppColors.surfaceAlt;
  static const Color stepperIcon = AppColors.icon;
  static const Color stepperIconDisabled = AppPalette.gray400;
  static const double stepperRadius = AppRadii.button;
  static const double stepperValueSize = 16;

  // --- قسم "قد يعجبك أيضاً" ---
  static const double recommendationsTopSpacing = 32;
}

// -----------------------------------------------------------------------------
//  عارض الصور بملء الشاشة  —  FULLSCREEN GALLERY
// -----------------------------------------------------------------------------
abstract final class GalleryViewerDesign {
  static const Color background = AppColors.white;
  static const Color closeIcon = AppColors.icon;
  static const Color closeBackground = AppColors.surfaceAlt;
  static const Color indicatorActive = AppColors.text;
  static const Color indicatorInactive = AppPalette.gray300;
  static const double maxZoom = 4;
}

// -----------------------------------------------------------------------------
//  الصفحة الرئيسية  —  HOME
// -----------------------------------------------------------------------------
abstract final class HomeDesign {
  static const Color pageBackground = AppColors.white;

  // --- البانرات ---
  static const double bannerHeight = 196;
  static const double bannerRadius = AppRadii.lg;
  static const double bannerViewportFraction = 0.9;
  static const Color bannerBackground = AppColors.primary;
  static const Color bannerTitle = AppColors.white;
  static const double bannerTitleSize = 21;
  static const FontWeight bannerTitleWeight = AppFont.extraBold;
  static const Color bannerSubtitle = Color(0xE6FFFFFF);
  static const Color bannerButtonBackground = AppColors.white;
  static const Color bannerButtonText = AppColors.text;
  static const Color bannerImageOverlay = Color(0x66000000);
  static const Duration bannerAutoPlay = Duration(seconds: 5);
  static const Color bannerDotActive = AppColors.text;
  static const Color bannerDotInactive = AppPalette.gray300;

  // --- التصنيفات ---
  static const double categoryHeight = 40;

  // --- المحلات (دوائر مثل القصص) ---
  static const double shopAvatarSize = 66;
  static const Color shopAvatarBorder = AppColors.primary;
  static const double shopAvatarBorderWidth = 2;
  static const Color shopAvatarBackground = AppColors.surfaceAlt;
  static const Color shopAvatarIcon = AppColors.icon;
  static const double shopNameSize = 12;
  static const FontWeight shopNameWeight = AppFont.semiBold;
  static const double shopItemWidth = 78;
}

// -----------------------------------------------------------------------------
//  صفحة المنتجات (الكتالوج والفلترة)  —  CATALOG
// -----------------------------------------------------------------------------
abstract final class CatalogDesign {
  static const Color pageBackground = AppColors.white;
  static const Color toolbarBackground = AppColors.white;
  static const Color toolbarBorder = AppColors.border;
  static const Color resultCountColor = AppColors.textMuted;
  static const double resultCountSize = 13;
  static const Color filterButtonBackground = AppColors.surfaceAlt;
  static const Color filterButtonIcon = AppColors.icon;
  static const Color filterActiveDot = AppColors.primary;
  static const double filterButtonRadius = AppRadii.pill;
}

// -----------------------------------------------------------------------------
//  صفحة المفضلة  —  FAVORITES
// -----------------------------------------------------------------------------
abstract final class FavoritesDesign {
  static const Color pageBackground = AppColors.white;
  static const IconData emptyIcon = AppIcons.heart;
}

// -----------------------------------------------------------------------------
//  سلة المشتريات  —  CART
// -----------------------------------------------------------------------------
abstract final class CartDesign {
  static const Color pageBackground = AppColors.white;
  static const double itemImageWidth = 92;
  static const double itemImageHeight = 116;
  static const double itemImageRadius = AppRadii.image;
  static const Color itemImageBackground = AppColors.surfaceAlt;
  static const Color itemImageBorder = AppColors.border;
  static const Color itemDivider = AppColors.divider;
  static const double itemTitleSize = 14;
  static const FontWeight itemTitleWeight = AppFont.bold;
  static const Color itemMetaColor = AppColors.textMuted;
  static const double itemPriceSize = 15;
  static const FontWeight itemPriceWeight = AppFont.extraBold;
  static const Color removeIcon = AppColors.icon;
  static const Color stepperBackground = AppColors.surfaceAlt;
  static const double stepperRadius = AppRadii.pill;
  static const Color summaryBackground = AppColors.white;
  static const Color summaryBorder = AppColors.border;
  static const List<BoxShadow> summaryShadow = AppShadows.bar;
  static const Color summaryLabel = AppColors.textSecondary;
  static const double totalSize = 18;
  static const FontWeight totalWeight = AppFont.extraBold;
}

// -----------------------------------------------------------------------------
//  إتمام الطلب  —  CHECKOUT
// -----------------------------------------------------------------------------
abstract final class CheckoutDesign {
  static const Color pageBackground = AppColors.white;
  static const Color sectionBackground = AppColors.white;
  static const Color sectionBorder = AppColors.border;
  static const double sectionRadius = AppRadii.card;
  static const Color optionSelectedBorder = AppColors.primary;
  static const Color optionSelectedBackground = AppColors.primarySoft;
  static const Color successIconBackground = AppColors.primarySoft;
  static const Color successIcon = AppColors.primary;
  static const double successIconSize = 44;
}

// -----------------------------------------------------------------------------
//  طلباتي  —  ORDERS
// -----------------------------------------------------------------------------
abstract final class OrdersDesign {
  static const Color pageBackground = AppColors.white;
  static const Color cardBorder = AppColors.border;
  static const double cardRadius = AppRadii.card;
  static const double orderNumberSize = 15;
  static const FontWeight orderNumberWeight = AppFont.bold;
  static const Color dateColor = AppColors.textMuted;
  static const double totalSize = 16;
  static const FontWeight totalWeight = AppFont.extraBold;
}

// -----------------------------------------------------------------------------
//  تفاصيل الطلب  —  ORDER DETAILS
// -----------------------------------------------------------------------------
abstract final class OrderDetailsDesign {
  static const Color pageBackground = AppColors.white;
  static const Color timelineActive = AppColors.primary;
  static const Color timelineInactive = AppPalette.gray300;
  static const double timelineDotSize = 14;
  static const Color sectionBorder = AppColors.border;
  static const double sectionRadius = AppRadii.card;
}

// -----------------------------------------------------------------------------
//  الملف الشخصي  —  PROFILE
// -----------------------------------------------------------------------------
abstract final class ProfileDesign {
  static const Color pageBackground = AppColors.white;
  static const double avatarSize = 72;
  static const Color avatarBackground = AppColors.primarySoft;
  static const Color avatarText = AppColors.primaryDark;
  static const double nameSize = 19;
  static const FontWeight nameWeight = AppFont.extraBold;
  static const Color menuIcon = AppColors.icon;
  static const Color menuIconBackground = AppColors.surfaceAlt;
  static const double menuIconBoxSize = 40;
  static const Color menuChevron = AppColors.iconMuted;
  static const Color menuDivider = AppColors.divider;
  static const Color logoutColor = AppColors.error;
}

// -----------------------------------------------------------------------------
//  الإشعارات  —  NOTIFICATIONS
// -----------------------------------------------------------------------------
abstract final class NotificationsDesign {
  static const Color pageBackground = AppColors.white;
  static const Color iconBackground = AppColors.primarySoft;
  static const Color icon = AppColors.icon;
  static const double iconBoxSize = 44;
  static const Color unreadDot = AppColors.primary;
  static const Color divider = AppColors.divider;
}

// -----------------------------------------------------------------------------
//  المحلات وصفحة المتجر  —  SHOPS & SHOP PROFILE
// -----------------------------------------------------------------------------
abstract final class ShopProfileDesign {
  static const Color pageBackground = AppColors.white;
  static const double coverHeight = 170;
  static const Color coverBackground = AppColors.primarySoft;
  static const double logoSize = 84;
  static const Color logoBorder = AppColors.white;
  static const double logoBorderWidth = 3;
  static const Color logoBackground = AppColors.surfaceAlt;
  static const double nameSize = 20;
  static const FontWeight nameWeight = AppFont.extraBold;
  static const Color metaColor = AppColors.textMuted;
  static const Color listCardBorder = AppColors.border;
  static const double listCardRadius = AppRadii.card;
  static const double listLogoSize = 56;
}

// -----------------------------------------------------------------------------
//  مقارنة المنتجات  —  COMPARE
// -----------------------------------------------------------------------------
abstract final class CompareDesign {
  static const Color pageBackground = AppColors.white;
  static const double columnWidth = 160;
  static const double imageHeight = 190;
  static const double imageRadius = AppRadii.image;
  static const Color imageBackground = AppColors.surfaceAlt;
  static const Color rowLabelColor = AppColors.textMuted;
  static const Color rowDivider = AppColors.divider;
}

// -----------------------------------------------------------------------------
//  تسجيل الدخول والتسجيل  —  AUTH
// -----------------------------------------------------------------------------
abstract final class AuthDesign {
  static const Color pageBackground = AppColors.white;
  static const double logoSize = 76;
  static const Color logoBackground = AppColors.primary;
  static const Color logoIcon = AppColors.onPrimary;
  static const double logoRadius = 22;
  static const double titleSize = 26;
  static const FontWeight titleWeight = AppFont.extraBold;
  static const Color subtitleColor = AppColors.textMuted;
  static const double maxFormWidth = 460;
  static const Color linkColor = AppColors.primaryDark;
  static const Color choiceCardBorder = AppColors.border;
  static const Color choiceCardSelectedBorder = AppColors.primary;
  static const double choiceCardRadius = AppRadii.card;
}

// -----------------------------------------------------------------------------
//  شاشة البداية  —  SPLASH
// -----------------------------------------------------------------------------
abstract final class SplashDesign {
  static const Color background = AppColors.white;
  static const Color logoBackground = AppColors.primary;
  static const Color logoIcon = AppColors.onPrimary;
  static const double logoSize = 88;
  static const Color title = AppColors.text;
  static const Color indicator = AppColors.primary;
}

// -----------------------------------------------------------------------------
//  لوحة المتجر (البائع)  —  SELLER
// -----------------------------------------------------------------------------
abstract final class SellerDesign {
  static const Color pageBackground = AppColors.surfaceSubtle;
  static const Color appBarBackground = AppColors.white;
  static const Color statCardBackground = AppColors.white;
  static const Color statCardBorder = AppColors.border;
  static const double statCardRadius = AppRadii.card;
  static const Color statIconBackground = AppColors.primarySoft;
  static const Color statIcon = AppColors.icon;
  static const double statValueSize = 22;
  static const FontWeight statValueWeight = AppFont.extraBold;
  static const Color navSelectedBackground = AppColors.primarySoft;
  static const Color navSelectedIcon = AppColors.icon;
  static const Color navUnselectedIcon = AppColors.iconMuted;
  static const Color stepActive = AppColors.primary;
  static const Color stepInactive = AppPalette.gray300;
  static const Color uploadBoxBorder = AppPalette.gray300;
  static const Color uploadBoxBackground = AppColors.surfaceSubtle;
}

// -----------------------------------------------------------------------------
//  لوحة الإدارة  —  ADMIN
// -----------------------------------------------------------------------------
abstract final class AdminDesign {
  static const Color pageBackground = AppColors.surfaceSubtle;
  static const Color appBarBackground = AppColors.white;
  static const Color cardBackground = AppColors.white;
  static const Color cardBorder = AppColors.border;
  static const double cardRadius = AppRadii.card;
  static const Color statIconBackground = AppColors.primarySoft;
  static const Color statIcon = AppColors.icon;
  static const double statValueSize = 22;
  static const FontWeight statValueWeight = AppFont.extraBold;
  static const Color navSelectedBackground = AppColors.primarySoft;
  static const Color navSelectedIcon = AppColors.icon;
  static const Color navUnselectedIcon = AppColors.iconMuted;
}

// -----------------------------------------------------------------------------
//  التجربة الافتراضية (الكاميرا)  —  TRY-ON
// -----------------------------------------------------------------------------
abstract final class TryOnDesign {
  static const Color cameraBackground = Color(0xFF000000);
  static const Color overlayText = AppColors.white;
  static const Color overlayPanel = Color(0xB3000000);
  static const Color guideStroke = AppColors.primary;
  static const Color detectedStroke = AppColors.primary;
  static const Color controlBackground = AppColors.white;
  static const Color controlIcon = AppColors.icon;
  static const Color stepActive = AppColors.primary;
  static const Color stepInactive = AppPalette.gray300;
}
