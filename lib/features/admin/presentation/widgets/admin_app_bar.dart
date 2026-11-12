import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_design.dart';
import 'admin_bottom_nav.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(AppBarDesign.height);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();

    return AppBar(
      toolbarHeight: AppBarDesign.height,
      backgroundColor: AdminDesign.appBarBackground,
      foregroundColor: AppBarDesign.titleColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      shape: const Border(
        bottom: BorderSide(color: AppBarDesign.borderColor, width: 1),
      ),
      leading: canPop
          ? IconButton(
              onPressed: AppHaptics.action(
                () => Navigator.of(context).maybePop(),
              ),
              icon: const Icon(
                AppIcons.back,
                color: AppBarDesign.iconColor,
              ),
            )
          : const SizedBox.shrink(),
      leadingWidth: canPop ? 56 : 12,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: AppBarDesign.titleSize,
          fontWeight: AppBarDesign.titleWeight,
          color: AppBarDesign.titleColor,
        ),
      ),
      actions: actions,
    );
  }
}

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = true,
    this.showBottomNav = true,
    this.actions,
    this.bottom,
  });

  final String title;
  final Widget body;
  final bool showBack;
  final bool showBottomNav;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminAppBar(title: title, showBack: showBack, actions: actions),
      body: SafeArea(child: body),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bottom != null)
            Material(
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: bottom,
              ),
            ),
          if (showBottomNav) const AdminBottomNav(),
        ],
      ),
    );
  }
}

class AdminFeatureTile extends StatelessWidget {
  const AdminFeatureTile({
    super.key,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final String code;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(CardDesign.radius),
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(CardDesign.radius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: CardDesign.border),
            borderRadius: BorderRadius.circular(CardDesign.radius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: AppFont.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: BadgeDesign.padding,
                  decoration: BoxDecoration(
                    color: BadgeDesign.primaryBackground,
                    borderRadius: BorderRadius.circular(BadgeDesign.radius),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: BadgeDesign.primaryText,
                      fontSize: BadgeDesign.textSize,
                      fontWeight: BadgeDesign.textWeight,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              const Icon(AppIcons.forward, color: AppColors.icon),
            ],
          ),
        ),
      ),
    );
  }
}
