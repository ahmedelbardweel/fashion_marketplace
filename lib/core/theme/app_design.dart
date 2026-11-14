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

import '../l10n/app_translations.dart';
export 'package:iconsax_plus/iconsax_plus.dart';
export '../l10n/app_translations.dart';

// =============================================================================
//  0) مكتبة الأيقونات الموحّدة  —  UNIFIED APP ICONS (Iconsax Plus)
// =============================================================================
//  جميع الأيقونات في التطبيق تستخدم مكتبة Iconsax Plus الاحترافية والموحدة.
//  لتغيير أي أيقونة في التطبيق بالكامل، غيّرها من هنا فقط.
// =============================================================================
abstract final class AppIcons {
  /// مسار شعار التطبيق الموحد بدون خلفية.
  static const String logoAsset = 'assets/images/app_logo.png';

  // --- التنقل والأسهم (متوافقة مع اتجاه العربية RTL) ---
  static IconData get back => AppLang.isEn ? IconsaxPlusLinear.arrow_left_1 : IconsaxPlusLinear.arrow_right_1;
  static IconData get forward => AppLang.isEn ? IconsaxPlusLinear.arrow_right_3 : IconsaxPlusLinear.arrow_left_2;
  static IconData get arrowForward => AppLang.isEn ? IconsaxPlusLinear.arrow_right : IconsaxPlusLinear.arrow_left;
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
  static const IconData google = IconData(
    0xf1a0,
    fontFamily: 'FontAwesomeBrands',
    fontPackage: 'font_awesome_flutter',
  );
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

  /// هل الوضع الليلي مفعّل حالياً؟ يتم تحديثه تلقائياً عند تبديل الثيم.
  static bool isDark = false;

  // --- اللون الرئيسي ---
  static Color get primary =>
      isDark ? const Color(0xFF00A3AB) : AppPalette.primary;
  static Color get primaryDark =>
      isDark ? const Color(0xFF38C6CE) : AppPalette.primaryDark;
  static Color get primarySoft =>
      isDark ? const Color(0xFF132E32) : AppPalette.primarySoft;
  static Color get primaryBorder =>
      isDark ? const Color(0xFF1E4E54) : AppPalette.primaryBorder;
  static const Color onPrimary = AppPalette.white;

  // --- الخطوط ---
  /// لون الخط الأساسي.
  static Color get text =>
      isDark ? const Color(0xFFFFFFFF) : AppPalette.ink;

  /// لون الخط الثانوي (وصف، تفاصيل).
  static Color get textSecondary =>
      isDark ? const Color(0xFFD4D4D4) : AppPalette.gray700;

  /// لون الخط الخافت (تلميحات، تواريخ).
  static Color get textMuted =>
      isDark ? const Color(0xFF8E8E8E) : AppPalette.gray500;

  // --- الأيقونات ---
  /// لون الأيقونات الأساسي.
  static Color get icon =>
      isDark ? const Color(0xFFFFFFFF) : AppPalette.ink;

  /// لون الأيقونات غير النشطة.
  static Color get iconMuted =>
      isDark ? const Color(0xFF8E8E8E) : AppPalette.gray500;

  // --- الخلفيات (أسود صافي ورمادي فحمي محايد بدون أي درجة كحلي) ---
  static Color get background =>
      isDark ? const Color(0xFF000000) : AppPalette.white;
  static Color get surface =>
      isDark ? const Color(0xFF121212) : AppPalette.white;

  /// خلفية ثانوية (حقول، صناديق صور، أقسام).
  static Color get surfaceAlt =>
      isDark ? const Color(0xFF1C1C1C) : AppPalette.gray100;

  /// خلفية خافتة جداً.
  static Color get surfaceSubtle =>
      isDark ? const Color(0xFF0A0A0A) : AppPalette.gray50;

  // --- الحدود ---
  /// البوردر الموحد لكل التطبيق.
  static Color get border =>
      isDark ? const Color(0xFF262626) : AppPalette.gray200;
  static Color get borderStrong =>
      isDark ? const Color(0xFF383838) : AppPalette.gray300;
  static Color get divider =>
      isDark ? const Color(0xFF222222) : AppPalette.gray200;

  // --- الحالات ---
  static Color get error =>
      isDark ? const Color(0xFFF97066) : AppPalette.red;
  static Color get errorSoft =>
      isDark ? const Color(0xFF3A1818) : AppPalette.redSoft;
  static Color get success =>
      isDark ? const Color(0xFF32D583) : AppPalette.green;
  static Color get successSoft =>
      isDark ? const Color(0xFF113222) : AppPalette.greenSoft;
  static Color get warning =>
      isDark ? const Color(0xFFFDB022) : AppPalette.amber;
  static Color get warningSoft =>
      isDark ? const Color(0xFF36260E) : AppPalette.amberSoft;

  /// لون نجوم التقييم.
  static Color get rating =>
      isDark ? const Color(0xFFFDB022) : AppPalette.ink;

  /// طبقة التعتيم خلف النوافذ المنبثقة.
  static const Color scrim = Color(0x73000000);

  // --- أسماء قديمة (متوافقة مع الكود الحالي) ---
  static Color get black => text;
  static Color get white => surface;
  static Color get gray900 =>
      isDark ? const Color(0xFFFFFFFF) : AppPalette.gray900;
  static Color get gray700 => textSecondary;
  static Color get gray500 => textMuted;
  static Color get gray300 => borderStrong;
  static Color get gray100 => surfaceAlt;
  static Color get onBackground => text;
  static Color get onSurface => text;
  static Color get secondary => textSecondary;
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

  static BorderSide get side => BorderSide(color: AppColors.border, width: width);
  static BorderSide get selected => BorderSide(
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
  static String get currency => '₪';
  static String price(num value) => AppLang.isEn ? '₪${value.toStringAsFixed(2)}' : '${value.toStringAsFixed(2)} ₪';
}

// #############################################################################
//                              المكونات المشتركة
// #############################################################################

// -----------------------------------------------------------------------------
//  شريط التطبيق العلوي  —  APP BAR
// -----------------------------------------------------------------------------
abstract final class AppBarDesign {
  static const double height = 64;
  static const double logoSize = 36;
  static Color get background => AppColors.white;
  static Color get iconColor => AppColors.icon;
  static const double iconSize = 24;
  static Color get titleColor => AppColors.text;
  static const double titleSize = 18;
  static const FontWeight titleWeight = AppFont.bold;
  static const bool showBottomBorder = true;
  static Color get borderColor => AppColors.border;

  // البحث داخل الشريط
  static const double searchHeight = 44;
  static Color get searchBackground => AppColors.surfaceAlt;
  static const Color searchBorder = Colors.transparent;
  static const double searchRadius = AppRadii.pill;
  static Color get searchIcon => AppColors.icon;
  static Color get searchHint => AppColors.textMuted;
  static String get searchHintText => AppLang.isEn ? 'Search shirts, dresses, hoodies...' : 'ابحث عن قميص، فستان، هودي...';

  // الشارة فوق أيقونة السلة
  static Color get badgeBackground => AppColors.primary;
  static Color get badgeText => AppColors.onPrimary;
}

// -----------------------------------------------------------------------------
//  الشريط السفلي للتنقل  —  BOTTOM NAVIGATION
// -----------------------------------------------------------------------------
abstract final class BottomNavDesign {
  static Color get background => AppColors.white;
  static Color get borderColor => AppColors.border;
  static const double topRadius = 0;
  static const double height = 68;
  static const double iconSize = 22;
  static Color get selectedIcon => AppColors.icon;
  static Color get unselectedIcon => AppColors.iconMuted;
  static Color get selectedLabel => AppColors.text;
  static Color get unselectedLabel => AppColors.textMuted;
  static const double labelSize = 11;
  static const FontWeight selectedWeight = AppFont.bold;
  static const FontWeight unselectedWeight = AppFont.medium;

  /// الخلفية خلف الأيقونة والنص للعنصر المحدد.
  static Color get indicator => AppColors.primarySoft;
  static const double indicatorWidth = 64;
  static const double indicatorHeight = 52;
  static const double indicatorRadius = 20;
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
  static Color get primaryBackground => AppColors.primary;
  static Color get primaryForeground => AppColors.onPrimary;
  static Color get disabledBackground => AppPalette.gray200;
  static Color get disabledForeground => AppPalette.gray500;

  // الزر المحدد بحدود
  static Color get outlinedForeground => AppColors.text;
  static Color get outlinedBorder => AppColors.borderStrong;
  static Color get outlinedBackground => AppColors.white;

  // الزر النصي
  static Color get textForeground => AppColors.text;

  // زر الأيقونة
  static Color get iconButtonColor => AppColors.icon;
  static Color get iconButtonBorder => AppColors.border;
  static const double iconButtonRadius = AppRadii.pill;
}

// -----------------------------------------------------------------------------
//  حقول الإدخال  —  INPUTS
// -----------------------------------------------------------------------------
abstract final class InputDesign {
  static Color get fill => AppColors.surfaceAlt;
  static const Color border = Colors.transparent;
  static Color get focusedBorder => AppColors.primary;
  static Color get errorBorder => AppColors.error;
  static const double borderWidth = 1;
  static const double focusedBorderWidth = 1.5;
  static const double radius = AppRadii.input;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 15,
  );
  static Color get text => AppColors.text;
  static Color get hint => AppColors.textMuted;
  static Color get label => AppColors.text;
  static const FontWeight labelWeight = AppFont.semiBold;
  static Color get prefixIcon => AppColors.icon;
  static Color get cursor => AppColors.primary;
}

// -----------------------------------------------------------------------------
//  الشرائح (الفلاتر / الخيارات)  —  CHIPS
// -----------------------------------------------------------------------------
abstract final class ChipDesign {
  static const double height = 38;
  static const double radius = AppRadii.pill;
  static const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 16);
  static Color get background => AppColors.surfaceAlt;
  static const Color border = Colors.transparent;
  static Color get text => AppColors.text;
  static const FontWeight textWeight = AppFont.semiBold;
  static Color get selectedBackground => AppColors.primary;
  static Color get selectedBorder => AppColors.primary;
  static Color get selectedText => AppColors.onPrimary;
  static const FontWeight selectedWeight = AppFont.bold;
  static const double textSize = 13;
}

// -----------------------------------------------------------------------------
//  البطاقات العامة  —  GENERIC CARD (AppCard)
// -----------------------------------------------------------------------------
abstract final class CardDesign {
  static Color get background => AppColors.white;
  static Color get border => AppColors.border;
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
  static Color get neutralBackground => AppColors.surfaceAlt;
  static Color get neutralText => AppColors.text;
  static Color get primaryBackground => AppColors.primarySoft;
  static Color get primaryText => AppColors.primaryDark;
  static Color get successBackground => AppColors.successSoft;
  static Color get successText => AppColors.success;
  static Color get warningBackground => AppColors.warningSoft;
  static Color get warningText => AppColors.warning;
  static Color get errorBackground => AppColors.errorSoft;
  static Color get errorText => AppColors.error;
}

// -----------------------------------------------------------------------------
//  النافذة السفلية  —  BOTTOM SHEET
// -----------------------------------------------------------------------------
abstract final class SheetDesign {
  static Color get background => AppColors.white;
  static const double topRadius = AppRadii.bottomSheet;
  static Color get scrim => AppColors.scrim;
  static Color get handle => AppPalette.gray300;
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
  static const Color text = AppPalette.white;
  static const Color action = AppPalette.primarySoft;
  static const double radius = AppRadii.md;
}

// -----------------------------------------------------------------------------
//  هيكل التحميل  —  SKELETON
// -----------------------------------------------------------------------------
abstract final class SkeletonDesign {
  static Color get base => AppColors.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE9E9E9);
  static Color get highlight => AppColors.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F7);
  static const Duration duration = Duration(milliseconds: 1400);
}

// -----------------------------------------------------------------------------
//  الحالة الفارغة  —  EMPTY STATE
// -----------------------------------------------------------------------------
abstract final class EmptyStateDesign {
  static const double iconCircleSize = 88;
  static Color get iconCircleBackground => AppColors.surfaceAlt;
  static const double iconSize = 38;
  static Color get iconColor => AppColors.icon;
  static const double titleSize = 17;
  static const FontWeight titleWeight = AppFont.bold;
  static Color get titleColor => AppColors.text;
  static Color get messageColor => AppColors.textMuted;
}

// -----------------------------------------------------------------------------
//  عنوان القسم  —  SECTION HEADER
// -----------------------------------------------------------------------------
abstract final class SectionDesign {
  static const double titleSize = 18;
  static const FontWeight titleWeight = AppFont.extraBold;
  static Color get titleColor => AppColors.text;
  static const double actionSize = 13;
  static const FontWeight actionWeight = AppFont.bold;
  static Color get actionColor => AppColors.primaryDark;
  static const double spacingBelow = 8;
  static const double spacingBetweenSections = 12;
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
  static Color get imageBackground => AppColors.surfaceAlt;
  static Color get imageBorderColor => AppColors.border;
  static const double imageBorderWidth = 1;
  static const BoxFit imageFit = BoxFit.cover;
  static Color get placeholderIcon => AppColors.iconMuted;

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
  static Color get favoriteBackground => AppColors.isDark ? const Color(0xE6141414) : const Color(0xF2FFFFFF);
  static Color get favoriteIcon => AppColors.icon;
  static Color get favoriteActiveIcon => AppColors.icon;
  static const List<BoxShadow> favoriteShadow = AppShadows.soft;

  // --- السعر ---
  static const double infoTopSpacing = 6;
  static const double priceSize = 15;
  static const FontWeight priceWeight = AppFont.extraBold;
  static Color get priceColor => AppColors.text;

  // --- زر الإضافة للسلة ---
  static const double cartButtonSize = 38;
  static const double cartButtonRadius = AppRadii.pill;
  static const double cartIconSize = 19;
  static Color get cartButtonBackground => AppColors.primary;
  static Color get cartButtonIcon => AppColors.onPrimary;
  static Color get cartButtonDisabledBackground => AppPalette.gray200;
  static Color get cartButtonDisabledIcon => AppPalette.gray500;

  // --- نفاد الكمية ---
  static const double outOfStockImageOpacity = 0.55;
  static const Color outOfStockBadgeBackground = AppPalette.ink;
  static const Color outOfStockBadgeText = AppPalette.white;
  static String get outOfStockLabel => AppLang.isEn ? 'Out of stock' : 'نفدت الكمية';

  /// ارتفاع منطقة السعر والزر أسفل الصورة (لحساب الشبكة).
  static const double infoHeight = 44;
}

// -----------------------------------------------------------------------------
//  شبكة المنتجات  —  PRODUCT GRID
// -----------------------------------------------------------------------------
abstract final class ProductGridDesign {
  static const double minCardWidth = 160;
  static const int minColumns = 2;
  static const int maxColumns = 6;
  static const double crossSpacing = 10;
  static const double mainSpacing = 12;
}

// -----------------------------------------------------------------------------
//  صفحة تفاصيل المنتج  —  PRODUCT DETAILS
// -----------------------------------------------------------------------------
abstract final class ProductDetailsDesign {
  static Color get pageBackground => AppColors.white;

  // --- معرض الصور العلوي (مختلف عن صورة البطاقة: كامل العرض وطولي) ---
  /// نسبة ارتفاع المعرض من ارتفاع الشاشة.
  static const double galleryHeightFactor = 0.6;
  static const double galleryMinHeight = 360;
  static const double galleryMaxHeight = 640;
  static Color get galleryBackground => AppColors.surfaceSubtle;
  static const BoxFit galleryImageFit = BoxFit.cover;

  // --- الأزرار العائمة فوق المعرض ---
  static const double floatingButtonSize = 42;
  static const double floatingIconSize = 21;
  static Color get floatingButtonBackground => AppColors.isDark ? const Color(0xE6141414) : const Color(0xF2FFFFFF);
  static Color get floatingButtonIcon => AppColors.icon;
  static const List<BoxShadow> floatingButtonShadow = AppShadows.floating;

  // --- عداد الصور (1/4) ---
  static const Color counterBackground = Color(0x99000000);
  static const Color counterText = AppPalette.white;
  static const double counterTextSize = 12;

  // --- زر التجربة الافتراضية فوق الصورة ---
  static Color get tryOnPillBackground => AppColors.white;
  static Color get tryOnPillText => AppColors.text;
  static Color get tryOnPillIcon => AppColors.primary;
  static const double tryOnPillHeight = 38;

  // --- الصور المصغرة ---
  static const double thumbSize = 58;
  static const double thumbRadius = AppRadii.sm;
  static Color get thumbBorder => AppColors.border;
  static Color get thumbActiveBorder => AppColors.primary;
  static const double thumbActiveBorderWidth = 2;
  static const double thumbSpacing = 8;

  // --- ورقة المحتوى المتداخلة مع الصورة ---
  static const double contentOverlap = 22;
  static const double contentRadius = 26;
  static Color get contentBackground => AppColors.white;
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(20, 22, 20, 0);

  // --- المتجر والعنوان والسعر ---
  static const double shopNameSize = 13;
  static const FontWeight shopNameWeight = AppFont.bold;
  static Color get shopNameColor => AppColors.primaryDark;
  static const double titleSize = 21;
  static const FontWeight titleWeight = AppFont.bold;
  static Color get titleColor => AppColors.text;
  static const double priceSize = 24;
  static const FontWeight priceWeight = AppFont.extraBold;
  static Color get priceColor => AppColors.text;

  // --- التقييم المختصر ---
  static const double ratingStarSize = 16;
  static Color get ratingStar => AppColors.rating;
  static Color get ratingStarEmpty => AppPalette.gray300;
  static const double ratingTextSize = 13;

  // --- عنوان كل قسم ---
  static const double sectionTitleSize = 15;
  static const FontWeight sectionTitleWeight = AppFont.bold;
  static Color get sectionValueColor => AppColors.textMuted;
  static const double sectionSpacing = 24;

  // --- خيارات اللون والمقاس ---
  static const double optionHeight = 44;
  static const double optionMinWidth = 52;
  static const double optionRadius = AppRadii.chip;
  static const EdgeInsets optionPadding = EdgeInsets.symmetric(horizontal: 16);
  static Color get optionBackground => AppColors.white;
  static Color get optionBorder => AppColors.borderStrong;
  static const double optionBorderWidth = 1;
  static Color get optionText => AppColors.text;
  static const FontWeight optionWeight = AppFont.semiBold;
  static Color get optionSelectedBackground => AppColors.primarySoft;
  static Color get optionSelectedBorder => AppColors.primary;
  static const double optionSelectedBorderWidth = 1.8;
  static Color get optionSelectedText => AppColors.text;
  static const FontWeight optionSelectedWeight = AppFont.extraBold;
  static Color get optionDisabledText => AppPalette.gray400;
  static Color get optionDisabledBackground => AppColors.surfaceSubtle;

  // --- حالة المخزون ---
  static const int lowStockThreshold = 5;
  static Color get inStockColor => AppColors.success;
  static Color get lowStockColor => AppColors.warning;
  static Color get outOfStockColor => AppColors.error;

  // --- بطاقة التجربة الافتراضية ---
  static Color get tryOnCardBackground => AppColors.primarySoft;
  static Color get tryOnCardBorder => AppColors.primaryBorder;
  static const double tryOnCardRadius = AppRadii.card;
  static Color get tryOnIconBackground => AppColors.primary;
  static Color get tryOnIcon => AppColors.onPrimary;

  // --- بطاقة المتجر ---
  static const double shopLogoSize = 46;
  static const double shopLogoRadius = AppRadii.pill;
  static Color get shopCardBorder => AppColors.border;
  static const double shopCardRadius = AppRadii.card;

  // --- الأقسام القابلة للطي (الوصف، التفاصيل، التقييمات) ---
  static Color get expandableDivider => AppColors.divider;
  static Color get expandableIcon => AppColors.icon;
  static const double expandableTitleSize = 15;
  static const FontWeight expandableTitleWeight = AppFont.bold;
  static Color get bodyTextColor => AppColors.textSecondary;
  static const double bodyTextSize = 14;
  static Color get specLabelColor => AppColors.textMuted;
  static Color get specValueColor => AppColors.text;
  static const FontWeight specValueWeight = AppFont.semiBold;

  // --- التقييمات ---
  static const double reviewAvatarSize = 38;
  static Color get reviewAvatarBackground => AppColors.surfaceAlt;
  static Color get reviewAvatarText => AppColors.text;
  static const double reviewStarSize = 14;
  static const double reviewPickerStarSize = 34;
  static Color get reviewCardBorder => AppColors.border;
  static const double reviewCardRadius = AppRadii.card;

  // --- الشريط السفلي الثابت (الكمية + أضف للسلة) ---
  static Color get bottomBarBackground => AppColors.white;
  static Color get bottomBarBorder => AppColors.border;
  static const List<BoxShadow> bottomBarShadow = AppShadows.bar;
  static const EdgeInsets bottomBarPadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const double bottomBarButtonHeight = 54;
  static const double stepperWidth = 120;
  static Color get stepperBackground => AppColors.surfaceAlt;
  static Color get stepperIcon => AppColors.icon;
  static Color get stepperIconDisabled => AppPalette.gray400;
  static const double stepperRadius = AppRadii.button;
  static const double stepperValueSize = 16;

  // --- قسم "قد يعجبك أيضاً" ---
  static const double recommendationsTopSpacing = 32;
}

// -----------------------------------------------------------------------------
//  عارض الصور بملء الشاشة  —  FULLSCREEN GALLERY
// -----------------------------------------------------------------------------
abstract final class GalleryViewerDesign {
  static Color get background => AppColors.white;
  static Color get closeIcon => AppColors.icon;
  static Color get closeBackground => AppColors.surfaceAlt;
  static Color get indicatorActive => AppColors.text;
  static Color get indicatorInactive => AppPalette.gray300;
  static const double maxZoom = 4;
}

// -----------------------------------------------------------------------------
//  الصفحة الرئيسية  —  HOME
// -----------------------------------------------------------------------------
abstract final class HomeDesign {
  static Color get pageBackground => AppColors.white;

  // --- البانرات ---
  static const double bannerHeight = 196;
  static const double bannerRadius = AppRadii.lg;
  /// مقدار تضييق عرض بطاقة البانر من الأسفل من كل جهة (يزداد العرض كلما اتجهنا للأعلى).
  static const double bannerBottomInset = 18;
  static const double bannerViewportFraction = 0.9;
  static Color get bannerBackground => AppColors.primary;
  static const Color bannerTitle = AppPalette.white;
  static const double bannerTitleSize = 21;
  static const FontWeight bannerTitleWeight = AppFont.extraBold;
  static const Color bannerSubtitle = Color(0xE6FFFFFF);
  static const Color bannerButtonBackground = AppPalette.white;
  static const Color bannerButtonText = AppPalette.ink;
  static const Color bannerImageOverlay = Color(0x66000000);
  static const Duration bannerAutoPlay = Duration(seconds: 5);
  static Color get bannerDotActive => AppColors.text;
  static Color get bannerDotInactive => AppPalette.gray300;

  // --- التصنيفات ---
  static const double categoryHeight = 36;

  // --- المحلات (دوائر مثل القصص) ---
  static const double shopAvatarSize = 62;
  static Color get shopAvatarBorder => AppColors.primary;
  static const double shopAvatarBorderWidth = 2;
  static Color get shopAvatarBackground => AppColors.surfaceAlt;
  static Color get shopAvatarIcon => AppColors.icon;
  static const double shopNameSize = 12;
  static const FontWeight shopNameWeight = AppFont.semiBold;
  static const double shopItemWidth = 68;
}

// -----------------------------------------------------------------------------
//  صفحة المنتجات (الكتالوج والفلترة)  —  CATALOG
// -----------------------------------------------------------------------------
abstract final class CatalogDesign {
  static Color get pageBackground => AppColors.white;
  static Color get toolbarBackground => AppColors.white;
  static Color get toolbarBorder => AppColors.border;
  static Color get resultCountColor => AppColors.textMuted;
  static const double resultCountSize = 13;
  static Color get filterButtonBackground => AppColors.surfaceAlt;
  static Color get filterButtonIcon => AppColors.icon;
  static Color get filterActiveDot => AppColors.primary;
  static const double filterButtonRadius = AppRadii.pill;
}

// -----------------------------------------------------------------------------
//  صفحة المفضلة  —  FAVORITES
// -----------------------------------------------------------------------------
abstract final class FavoritesDesign {
  static Color get pageBackground => AppColors.white;
  static const IconData emptyIcon = AppIcons.heart;
}

// -----------------------------------------------------------------------------
//  سلة المشتريات  —  CART
// -----------------------------------------------------------------------------
abstract final class CartDesign {
  static Color get pageBackground => AppColors.white;
  static const double itemImageWidth = 92;
  static const double itemImageHeight = 116;
  static const double itemImageRadius = AppRadii.image;
  static Color get itemImageBackground => AppColors.surfaceAlt;
  static Color get itemImageBorder => AppColors.border;
  static Color get itemDivider => AppColors.divider;
  static const double itemTitleSize = 14;
  static const FontWeight itemTitleWeight = AppFont.bold;
  static Color get itemMetaColor => AppColors.textMuted;
  static const double itemPriceSize = 15;
  static const FontWeight itemPriceWeight = AppFont.extraBold;
  static Color get removeIcon => AppColors.icon;
  static Color get stepperBackground => AppColors.surfaceAlt;
  static const double stepperRadius = AppRadii.pill;
  static Color get summaryBackground => AppColors.white;
  static Color get summaryBorder => AppColors.border;
  static const List<BoxShadow> summaryShadow = AppShadows.bar;
  static Color get summaryLabel => AppColors.textSecondary;
  static const double totalSize = 18;
  static const FontWeight totalWeight = AppFont.extraBold;
}

// -----------------------------------------------------------------------------
//  إتمام الطلب  —  CHECKOUT
// -----------------------------------------------------------------------------
abstract final class CheckoutDesign {
  static Color get pageBackground => AppColors.white;
  static Color get sectionBackground => AppColors.white;
  static Color get sectionBorder => AppColors.border;
  static const double sectionRadius = AppRadii.card;
  static Color get optionSelectedBorder => AppColors.primary;
  static Color get optionSelectedBackground => AppColors.primarySoft;
  static Color get successIconBackground => AppColors.primarySoft;
  static Color get successIcon => AppColors.primary;
  static const double successIconSize = 44;
}

// -----------------------------------------------------------------------------
//  طلباتي  —  ORDERS
// -----------------------------------------------------------------------------
abstract final class OrdersDesign {
  static Color get pageBackground => AppColors.white;
  static Color get cardBorder => AppColors.border;
  static const double cardRadius = AppRadii.card;
  static const double orderNumberSize = 15;
  static const FontWeight orderNumberWeight = AppFont.bold;
  static Color get dateColor => AppColors.textMuted;
  static const double totalSize = 16;
  static const FontWeight totalWeight = AppFont.extraBold;
}

// -----------------------------------------------------------------------------
//  تفاصيل الطلب  —  ORDER DETAILS
// -----------------------------------------------------------------------------
abstract final class OrderDetailsDesign {
  static Color get pageBackground => AppColors.white;
  static Color get timelineActive => AppColors.primary;
  static Color get timelineInactive => AppPalette.gray300;
  static const double timelineDotSize = 14;
  static Color get sectionBorder => AppColors.border;
  static const double sectionRadius = AppRadii.card;
}

// -----------------------------------------------------------------------------
//  الملف الشخصي  —  PROFILE
// -----------------------------------------------------------------------------
abstract final class ProfileDesign {
  static Color get pageBackground => AppColors.white;
  static const double avatarSize = 72;
  static Color get avatarBackground => AppColors.primarySoft;
  static Color get avatarText => AppColors.primaryDark;
  static const double nameSize = 19;
  static const FontWeight nameWeight = AppFont.extraBold;
  static Color get menuIcon => AppColors.icon;
  static Color get menuIconBackground => AppColors.surfaceAlt;
  static const double menuIconBoxSize = 40;
  static Color get menuChevron => AppColors.iconMuted;
  static Color get menuDivider => AppColors.divider;
  static Color get logoutColor => AppColors.error;
}

// -----------------------------------------------------------------------------
//  الإشعارات  —  NOTIFICATIONS
// -----------------------------------------------------------------------------
abstract final class NotificationsDesign {
  static Color get pageBackground => AppColors.white;
  static Color get iconBackground => AppColors.primarySoft;
  static Color get icon => AppColors.icon;
  static const double iconBoxSize = 44;
  static Color get unreadDot => AppColors.primary;
  static Color get divider => AppColors.divider;
}

// -----------------------------------------------------------------------------
//  المحلات وصفحة المتجر  —  SHOPS & SHOP PROFILE
// -----------------------------------------------------------------------------
abstract final class ShopProfileDesign {
  static Color get pageBackground => AppColors.white;
  static const double coverHeight = 170;
  static Color get coverBackground => AppColors.primarySoft;
  static const double logoSize = 84;
  static Color get logoBorder => AppColors.white;
  static const double logoBorderWidth = 3;
  static Color get logoBackground => AppColors.surfaceAlt;
  static const double nameSize = 20;
  static const FontWeight nameWeight = AppFont.extraBold;
  static Color get metaColor => AppColors.textMuted;
  static Color get listCardBorder => AppColors.border;
  static const double listCardRadius = AppRadii.card;
  static const double listLogoSize = 56;
}

// -----------------------------------------------------------------------------
//  مقارنة المنتجات  —  COMPARE
// -----------------------------------------------------------------------------
abstract final class CompareDesign {
  static Color get pageBackground => AppColors.white;
  static const double columnWidth = 160;
  static const double imageHeight = 190;
  static const double imageRadius = AppRadii.image;
  static Color get imageBackground => AppColors.surfaceAlt;
  static Color get rowLabelColor => AppColors.textMuted;
  static Color get rowDivider => AppColors.divider;
}

// -----------------------------------------------------------------------------
//  تسجيل الدخول والتسجيل  —  AUTH
// -----------------------------------------------------------------------------
abstract final class AuthDesign {
  static Color get pageBackground => AppColors.white;
  static const double logoSize = 76;
  static Color get logoBackground => AppColors.primary;
  static Color get logoIcon => AppColors.onPrimary;
  static const double logoRadius = 22;
  static const double titleSize = 26;
  static const FontWeight titleWeight = AppFont.extraBold;
  static Color get subtitleColor => AppColors.textMuted;
  static const double maxFormWidth = 460;
  static Color get linkColor => AppColors.primaryDark;
  static Color get choiceCardBorder => AppColors.border;
  static Color get choiceCardSelectedBorder => AppColors.primary;
  static const double choiceCardRadius = AppRadii.card;

  // --- التسجيل الاجتماعي (Google) والفاصل ---
  static const double socialButtonHeight = ButtonDesign.height;
  static const double socialButtonRadius = ButtonDesign.radius;
  static const double socialIconSize = 18;
  static const double socialIconSpacing = 10;
  static Color get socialIconColor => AppColors.icon;
  static Color get socialButtonBackground => AppColors.surfaceAlt;
  static Color get socialButtonBorder => AppColors.border;
  static Color get socialButtonForeground => AppColors.text;
  static Color get dividerColor => AppColors.divider;
  static Color get dividerTextColor => AppColors.textMuted;
  static const double dividerTextSize = 13;
}

// -----------------------------------------------------------------------------
//  شاشة البداية  —  SPLASH
// -----------------------------------------------------------------------------
abstract final class SplashDesign {
  static Color get background => AppColors.white;
  static Color get logoBackground => Colors.transparent;
  static Color get logoIcon => AppColors.onPrimary;
  static const double logoSize = 112;
  static Color get title => AppColors.text;
  static Color get indicator => AppColors.primary;
}

// -----------------------------------------------------------------------------
//  لوحة المتجر (البائع)  —  SELLER
// -----------------------------------------------------------------------------
abstract final class SellerDesign {
  static Color get pageBackground => AppColors.surfaceSubtle;
  static Color get appBarBackground => AppColors.white;
  static Color get statCardBackground => AppColors.white;
  static Color get statCardBorder => AppColors.border;
  static const double statCardRadius = AppRadii.card;
  static Color get statIconBackground => AppColors.primarySoft;
  static Color get statIcon => AppColors.icon;
  static const double statValueSize = 22;
  static const FontWeight statValueWeight = AppFont.extraBold;
  static Color get navSelectedBackground => AppColors.primarySoft;
  static Color get navSelectedIcon => AppColors.icon;
  static Color get navUnselectedIcon => AppColors.iconMuted;
  static Color get stepActive => AppColors.primary;
  static Color get stepInactive => AppPalette.gray300;
  static Color get uploadBoxBorder => AppPalette.gray300;
  static Color get uploadBoxBackground => AppColors.surfaceSubtle;
}

// -----------------------------------------------------------------------------
//  لوحة الإدارة  —  ADMIN
// -----------------------------------------------------------------------------
abstract final class AdminDesign {
  static Color get pageBackground => AppColors.surfaceSubtle;
  static Color get appBarBackground => AppColors.white;
  static Color get cardBackground => AppColors.white;
  static Color get cardBorder => AppColors.border;
  static const double cardRadius = AppRadii.card;
  static Color get statIconBackground => AppColors.primarySoft;
  static Color get statIcon => AppColors.icon;
  static const double statValueSize = 22;
  static const FontWeight statValueWeight = AppFont.extraBold;
  static Color get navSelectedBackground => AppColors.primarySoft;
  static Color get navSelectedIcon => AppColors.icon;
  static Color get navUnselectedIcon => AppColors.iconMuted;
}

/// شارة شعار التطبيق بدون خلفية (للشريط العلوي وشاشة البداية وتسجيل الدخول).
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size = AppBarDesign.logoSize,
    this.fit = BoxFit.contain,
  });

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppIcons.logoAsset,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.medium,
    );
  }
}

// -----------------------------------------------------------------------------
//  التجربة الافتراضية (الكاميرا)  —  TRY-ON
// -----------------------------------------------------------------------------
abstract final class TryOnDesign {
  static const Color cameraBackground = Color(0xFF000000);
  static const Color overlayText = AppPalette.white;
  static const Color overlayPanel = Color(0xB3000000);
  static Color get guideStroke => AppColors.primary;
  static Color get detectedStroke => AppColors.primary;
  static Color get controlBackground => AppColors.white;
  static Color get controlIcon => AppColors.icon;
  static Color get stepActive => AppColors.primary;
  static Color get stepInactive => AppPalette.gray300;
}
