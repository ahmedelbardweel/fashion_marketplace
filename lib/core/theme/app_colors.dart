import 'package:flutter/material.dart';

/// Strict black & white palette only.
class AppColors {
  AppColors._();

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray900 = Color(0xFF111111);
  static const Color gray700 = Color(0xFF333333);
  static const Color gray500 = Color(0xFF777777);
  static const Color gray300 = Color(0xFFCCCCCC);
  static const Color gray100 = Color(0xFFF5F5F5);
  /// Unified light border used across the whole app.
  static const Color border = Color(0xFFE6E6E6);
  static const Color error = Color(0xFF000000);
  static const Color success = Color(0xFF000000);

  static const Color background = white;
  static const Color surface = white;
  static const Color onBackground = black;
  static const Color onSurface = black;
  static const Color primary = black;
  static const Color onPrimary = white;
  static const Color secondary = gray700;
  static const Color divider = border;
}
