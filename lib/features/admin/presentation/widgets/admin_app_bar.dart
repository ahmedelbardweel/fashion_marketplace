import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();

    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppColors.gray100,
      foregroundColor: AppColors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      shape: const Border(
        bottom: BorderSide(color: AppColors.border, width: 1),
      ),
      leading: canPop
          ? IconButton(
              onPressed: AppHaptics.action(
                () => Navigator.of(context).maybePop(),
              ),
              icon: const Icon(Icons.arrow_forward, color: AppColors.black),
            )
          : const SizedBox.shrink(),
      leadingWidth: canPop ? 56 : 12,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: AppColors.black),
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
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.card),
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
                        color: AppColors.gray500,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    badge!,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: AppColors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
