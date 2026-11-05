import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
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
        button = ElevatedButton(onPressed: effectiveOnPressed, child: child);
      case AppButtonVariant.outlined:
        button = OutlinedButton(onPressed: effectiveOnPressed, child: child);
      case AppButtonVariant.text:
        button = TextButton(onPressed: effectiveOnPressed, child: child);
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
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: AppColors.black),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
