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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = isLoading ? AppBusyLabel(label: label) : Text(label);

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
      tooltip: tooltip,
      icon: Icon(icon, color: ButtonDesign.iconButtonColor),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ButtonDesign.iconButtonRadius),
          side: const BorderSide(color: ButtonDesign.iconButtonBorder),
        ),
      ),
    );
  }
}
