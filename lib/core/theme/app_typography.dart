import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_design.dart';

/// Builds the text theme. All sizes, weights and colors live in app_design.dart.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme() {
    final base = GoogleFonts.getTextTheme(AppFont.googleFamily);
    final ink = AppColors.text;

    TextStyle? s(
      TextStyle? style,
      double size,
      FontWeight weight, {
      Color? color,
      double? height,
    }) => style?.copyWith(
      color: color ?? ink,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    );

    return base.copyWith(
      displayLarge: s(base.displayLarge, AppFont.display + 6, AppFont.extraBold),
      displayMedium: s(base.displayMedium, AppFont.display, AppFont.extraBold),
      displaySmall: s(base.displaySmall, AppFont.headline + 2, AppFont.bold),
      headlineLarge: s(base.headlineLarge, AppFont.headline + 4, AppFont.headlineWeight),
      headlineMedium: s(base.headlineMedium, AppFont.headline, AppFont.headlineWeight),
      headlineSmall: s(base.headlineSmall, AppFont.title + 2, AppFont.headlineWeight),
      titleLarge: s(base.titleLarge, AppFont.title, AppFont.titleWeight),
      titleMedium: s(base.titleMedium, AppFont.subtitle, AppFont.subtitleWeight),
      titleSmall: s(base.titleSmall, AppFont.body, AppFont.subtitleWeight),
      bodyLarge: s(
        base.bodyLarge,
        AppFont.subtitle,
        AppFont.bodyWeight,
        height: AppFont.bodyHeight,
      ),
      bodyMedium: s(
        base.bodyMedium,
        AppFont.body,
        AppFont.bodyWeight,
        color: AppColors.textSecondary,
        height: AppFont.bodyHeight,
      ),
      bodySmall: s(
        base.bodySmall,
        AppFont.small,
        AppFont.bodyWeight,
        color: AppColors.textMuted,
        height: 1.45,
      ),
      labelLarge: s(base.labelLarge, AppFont.body, AppFont.labelWeight),
      labelMedium: s(base.labelMedium, AppFont.small, AppFont.semiBold),
      labelSmall: s(base.labelSmall, AppFont.tiny, AppFont.semiBold),
    );
  }
}
