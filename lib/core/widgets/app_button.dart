import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import 'app_skeleton.dart';

enum AppButtonVariant { filled, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
    this.expand = true,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool expand;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = AppLang.tr(label);
    final Widget child;
    if (isLoading) {
      child = AppBusyLabel(label: text);
    } else if (leading != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading!,
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      );
    } else {
      child = Text(text);
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget button;
    switch (variant) {
      case AppButtonVariant.filled:
        button = ElevatedButton(
          onPressed: AppHaptics.action(effectiveOnPressed),
          child: child,
        );
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: AppHaptics.action(effectiveOnPressed),
          child: child,
        );
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: AppHaptics.action(effectiveOnPressed),
          child: child,
        );
    }

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: AppHaptics.action(onPressed),
      tooltip: tooltip == null ? null : AppLang.tr(tooltip!),
      icon: Icon(icon, color: ButtonDesign.iconButtonColor),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ButtonDesign.iconButtonRadius),
          side: BorderSide(color: ButtonDesign.iconButtonBorder),
        ),
      ),
    );
  }
}

class AppGoogleAuthButton extends StatelessWidget {
  const AppGoogleAuthButton({
    super.key,
    required this.onPressed,
    this.label = 'المتابعة باستخدام Google',
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final text = AppLang.tr(label);
    final effectiveOnPressed = isLoading ? null : onPressed;

    return SizedBox(
      width: double.infinity,
      height: AuthDesign.socialButtonHeight,
      child: OutlinedButton(
        onPressed: AppHaptics.action(effectiveOnPressed),
        style: OutlinedButton.styleFrom(
          backgroundColor: AuthDesign.socialButtonBackground,
          foregroundColor: AuthDesign.socialButtonForeground,
          side: BorderSide(
            color: AuthDesign.socialButtonBorder,
            width: AppBorders.width,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthDesign.socialButtonRadius),
          ),
        ),
        child: isLoading
            ? AppBusyLabel(label: text)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.google,
                    size: AuthDesign.socialIconSize,
                    color: AuthDesign.socialIconColor,
                  ),
                  const SizedBox(width: AuthDesign.socialIconSpacing),
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ButtonDesign.textSize,
                        fontWeight: ButtonDesign.textWeight,
                        color: AuthDesign.socialButtonForeground,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
