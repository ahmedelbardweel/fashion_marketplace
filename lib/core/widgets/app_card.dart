import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';

import '../theme/app_design.dart';

/// App-wide card. Every visual value comes from [CardDesign].
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CardDesign.radius);
    final content = Container(
      width: double.infinity,
      padding: padding ?? CardDesign.padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? CardDesign.background,
        borderRadius: radius,
        boxShadow: CardDesign.shadow,
        border: Border.all(
          color: borderColor ?? CardDesign.border,
          width: CardDesign.borderWidth,
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        borderRadius: radius,
        child: content,
      ),
    );
  }
}
