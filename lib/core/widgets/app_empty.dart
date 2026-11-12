import 'package:flutter/material.dart';

import '../theme/app_design.dart';

/// Empty / info state with an icon, a title and an optional message + action.
class AppEmpty extends StatelessWidget {
  const AppEmpty({
    super.key,
    required this.message,
    this.title,
    this.icon = AppIcons.inbox,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.lg,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: EmptyStateDesign.iconCircleSize,
              height: EmptyStateDesign.iconCircleSize,
              decoration: BoxDecoration(
                color: EmptyStateDesign.iconCircleBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: EmptyStateDesign.iconSize,
                color: EmptyStateDesign.iconColor,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(
                AppLang.tr(title!),
                textAlign: TextAlign.center,
                style: theme.titleMedium?.copyWith(
                  fontSize: EmptyStateDesign.titleSize,
                  fontWeight: EmptyStateDesign.titleWeight,
                  color: EmptyStateDesign.titleColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              AppLang.tr(message),
              textAlign: TextAlign.center,
              style: theme.bodyMedium?.copyWith(
                color: title == null
                    ? EmptyStateDesign.titleColor
                    : EmptyStateDesign.messageColor,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, ButtonDesign.height),
                ),
                child: Text(AppLang.tr(actionLabel!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section title with an optional trailing text action ("عرض الكل").
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = AppSpacing.pageHorizontal,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLang.tr(title),
              style: TextStyle(
                fontSize: SectionDesign.titleSize,
                fontWeight: SectionDesign.titleWeight,
                color: SectionDesign.titleColor,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: SectionDesign.actionColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppLang.tr(actionLabel!),
                style: const TextStyle(
                  fontSize: SectionDesign.actionSize,
                  fontWeight: SectionDesign.actionWeight,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tone for [AppStatusBadge].
enum BadgeTone { neutral, primary, success, warning, error }

/// Small pill used for statuses (order status, stock, etc.).
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
  });

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.neutral => (
        BadgeDesign.neutralBackground,
        BadgeDesign.neutralText,
      ),
      BadgeTone.primary => (
        BadgeDesign.primaryBackground,
        BadgeDesign.primaryText,
      ),
      BadgeTone.success => (
        BadgeDesign.successBackground,
        BadgeDesign.successText,
      ),
      BadgeTone.warning => (
        BadgeDesign.warningBackground,
        BadgeDesign.warningText,
      ),
      BadgeTone.error => (BadgeDesign.errorBackground, BadgeDesign.errorText),
    };
    return Container(
      padding: BadgeDesign.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BadgeDesign.radius),
      ),
      child: Text(
        AppLang.tr(label),
        style: TextStyle(
          color: fg,
          fontSize: BadgeDesign.textSize,
          fontWeight: BadgeDesign.textWeight,
        ),
      ),
    );
  }
}
