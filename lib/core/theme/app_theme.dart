import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_design.dart';
import 'app_typography.dart';

/// Material theme wiring. Every value comes from app_design.dart.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final textTheme = AppTypography.textTheme();

    OutlineInputBorder inputBorder(Color color, [double? width]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(InputDesign.radius),
          borderSide: color == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: color, width: width ?? InputDesign.borderWidth),
        );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ButtonDesign.radius),
    );
    final buttonText = textTheme.labelLarge?.copyWith(
      fontSize: ButtonDesign.textSize,
      fontWeight: ButtonDesign.textWeight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
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
        onError: AppColors.white,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.icon, size: 24),
      primaryIconTheme: const IconThemeData(color: AppColors.icon),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppBarDesign.background,
        foregroundColor: AppBarDesign.titleColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: AppBarDesign.iconColor,
          size: AppBarDesign.iconSize,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppBarDesign.iconColor,
          size: AppBarDesign.iconSize,
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: AppBarDesign.titleSize,
          fontWeight: AppBarDesign.titleWeight,
          color: AppBarDesign.titleColor,
        ),
        shape: AppBarDesign.showBottomBorder
            ? const Border(
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
          side: const BorderSide(
            color: CardDesign.border,
            width: CardDesign.borderWidth,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
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
      textSelectionTheme: const TextSelectionThemeData(
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
          side: const BorderSide(color: ButtonDesign.outlinedBorder),
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
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ChipDesign.background,
        selectedColor: ChipDesign.selectedBackground,
        disabledColor: AppColors.surfaceSubtle,
        checkmarkColor: ChipDesign.selectedText,
        side: const BorderSide(color: ChipDesign.border),
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
        iconTheme: const IconThemeData(color: AppColors.icon, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.white
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
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
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
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppBarDesign.badgeBackground,
        textColor: AppBarDesign.badgeText,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SheetDesign.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SheetDesign.topRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium?.copyWith(color: AppColors.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.border),
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceAlt,
        circularTrackColor: AppColors.surfaceAlt,
      ),
    );
  }
}
