import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_design.dart';
import 'app_typography.dart';

/// Persists and restores user preferences (ThemeMode & Locale) across restarts.
class AppPreferences {
  AppPreferences._();

  static const _themeKey = 'app_theme_mode';
  static const _localeKey = 'app_locale_code';

  static SharedPreferences? _prefs;
  static ThemeMode initialThemeMode = ThemeMode.light;
  static Locale initialLocale = const Locale('ar');

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedTheme = _prefs?.getString(_themeKey);
      if (savedTheme == 'dark') {
        initialThemeMode = ThemeMode.dark;
        AppColors.isDark = true;
      } else {
        initialThemeMode = ThemeMode.light;
        AppColors.isDark = false;
      }

      final savedLocale = _prefs?.getString(_localeKey);
      if (savedLocale == 'en') {
        initialLocale = const Locale('en');
        AppLang.isEn = true;
      } else {
        initialLocale = const Locale('ar');
        AppLang.isEn = false;
      }
    } catch (_) {
      // Fallback to defaults if storage is unavailable
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  static Future<void> setLocale(Locale locale) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(AppPreferences.initialThemeMode);

  @override
  set state(ThemeMode value) {
    AppColors.isDark = value == ThemeMode.dark;
    super.state = value;
    unawaited(AppPreferences.setThemeMode(value));
  }
}

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier() : super(AppPreferences.initialLocale);

  @override
  set state(Locale value) {
    AppLang.isEn = value.languageCode == 'en';
    super.state = value;
    unawaited(AppPreferences.setLocale(value));
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, Locale>((ref) {
  return AppLocaleNotifier();
});

/// Material theme wiring. Every value comes from app_design.dart.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final prev = AppColors.isDark;
    final isDark = brightness == Brightness.dark;
    AppColors.isDark = isDark;

    final textTheme = AppTypography.textTheme();

    OutlineInputBorder inputBorder(Color color, [double? width]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(InputDesign.radius),
          borderSide: color == Colors.transparent
              ? BorderSide.none
              : BorderSide(
                  color: color,
                  width: width ?? InputDesign.borderWidth,
                ),
        );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ButtonDesign.radius),
    );
    final buttonText = textTheme.labelLarge?.copyWith(
      fontSize: ButtonDesign.textSize,
      fontWeight: ButtonDesign.textWeight,
    );

    final scheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            primaryContainer: AppColors.primarySoft,
            onPrimaryContainer: AppColors.text,
            secondary: AppColors.primaryDark,
            onSecondary: AppColors.onPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.text,
            onSurfaceVariant: AppColors.textSecondary,
            surfaceContainerHighest: AppColors.surfaceAlt,
            error: AppColors.error,
            onError: AppPalette.white,
            outline: AppColors.border,
            outlineVariant: AppColors.border,
          )
        : ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            primaryContainer: AppColors.primarySoft,
            onPrimaryContainer: AppColors.text,
            secondary: AppColors.primaryDark,
            onSecondary: AppColors.onPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.text,
            onSurfaceVariant: AppColors.textSecondary,
            surfaceContainerHighest: AppColors.surfaceAlt,
            error: AppColors.error,
            onError: AppPalette.white,
            outline: AppColors.border,
            outlineVariant: AppColors.border,
          );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: scheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: AppColors.icon, size: 24),
      primaryIconTheme: IconThemeData(color: AppColors.icon),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppBarDesign.background,
        foregroundColor: AppBarDesign.titleColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: AppBarDesign.iconColor,
          size: AppBarDesign.iconSize,
        ),
        actionsIconTheme: IconThemeData(
          color: AppBarDesign.iconColor,
          size: AppBarDesign.iconSize,
        ),
        centerTitle: true,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: AppBarDesign.titleSize,
          fontWeight: AppBarDesign.titleWeight,
          color: AppBarDesign.titleColor,
        ),
        shape: AppBarDesign.showBottomBorder
            ? Border(
                bottom: BorderSide(color: AppBarDesign.borderColor),
              )
            : null,
      ),
      cardTheme: CardThemeData(
        color: CardDesign.background,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CardDesign.radius),
          side: BorderSide(
            color: CardDesign.border,
            width: CardDesign.borderWidth,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.icon,
        textColor: AppColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: InputDesign.fill,
        contentPadding: InputDesign.padding,
        hintStyle: textTheme.bodyMedium?.copyWith(color: InputDesign.hint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: InputDesign.label),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: InputDesign.focusedBorder,
        ),
        prefixIconColor: InputDesign.prefixIcon,
        suffixIconColor: InputDesign.prefixIcon,
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.error),
        border: inputBorder(InputDesign.border),
        enabledBorder: inputBorder(InputDesign.border),
        disabledBorder: inputBorder(InputDesign.border),
        focusedBorder: inputBorder(
          InputDesign.focusedBorder,
          InputDesign.focusedBorderWidth,
        ),
        errorBorder: inputBorder(InputDesign.errorBorder),
        focusedErrorBorder: inputBorder(
          InputDesign.errorBorder,
          InputDesign.focusedBorderWidth,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: InputDesign.cursor,
        selectionColor: AppColors.primaryBorder,
        selectionHandleColor: AppColors.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: ButtonDesign.primaryBackground,
          foregroundColor: ButtonDesign.primaryForeground,
          iconColor: ButtonDesign.primaryForeground,
          disabledBackgroundColor: ButtonDesign.disabledBackground,
          disabledForegroundColor: ButtonDesign.disabledForeground,
          minimumSize: const Size(64, ButtonDesign.height),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ButtonDesign.primaryBackground,
          foregroundColor: ButtonDesign.primaryForeground,
          disabledBackgroundColor: ButtonDesign.disabledBackground,
          disabledForegroundColor: ButtonDesign.disabledForeground,
          minimumSize: const Size(64, ButtonDesign.height),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: ButtonDesign.outlinedBackground,
          foregroundColor: ButtonDesign.outlinedForeground,
          iconColor: AppColors.icon,
          minimumSize: const Size(64, ButtonDesign.height),
          side: BorderSide(color: ButtonDesign.outlinedBorder),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ButtonDesign.textForeground,
          iconColor: AppColors.icon,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.icon),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ChipDesign.background,
        selectedColor: ChipDesign.selectedBackground,
        disabledColor: AppColors.surfaceSubtle,
        checkmarkColor: ChipDesign.selectedText,
        side: BorderSide(color: ChipDesign.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ChipDesign.radius),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: ChipDesign.text,
          fontSize: ChipDesign.textSize,
          fontWeight: ChipDesign.textWeight,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: ChipDesign.selectedText,
          fontSize: ChipDesign.textSize,
          fontWeight: ChipDesign.selectedWeight,
        ),
        iconTheme: IconThemeData(color: AppColors.icon, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppPalette.white
              : AppPalette.gray500,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
        side: BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.text,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: AppFont.medium,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppBarDesign.badgeBackground,
        textColor: AppBarDesign.badgeText,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: SheetDesign.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SheetDesign.topRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium?.copyWith(color: AppColors.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SnackBarDesign.background,
        actionTextColor: SnackBarDesign.action,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: SnackBarDesign.text,
          fontWeight: AppFont.semiBold,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SnackBarDesign.radius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceAlt,
        circularTrackColor: AppColors.surfaceAlt,
      ),
    );

    AppColors.isDark = prev;
    return theme;
  }
}
