import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ShopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShopAppBar({
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
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
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

class ShopBottomNav extends StatelessWidget {
  const ShopBottomNav({super.key});

  int _indexFor(String location) {
    if (location.startsWith(AppRoutes.shopProfile)) return 3;
    if (location.startsWith(AppRoutes.shopOrders)) return 2;
    if (location.startsWith(AppRoutes.shopProducts) ||
        location.startsWith('/shop/product')) {
      return 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final current = _indexFor(location);

    return Material(
      color: AppColors.white,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.bottomSheet),
          ),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                _Item(
                  label: 'الرئيسية',
                  selected: current == 0,
                  onTap: () => context.go(AppRoutes.shopHome),
                ),
                _Item(
                  label: 'المنتجات',
                  selected: current == 1,
                  onTap: () => context.go(AppRoutes.shopProducts),
                ),
                _Item(
                  label: 'الطلبات',
                  selected: current == 2,
                  onTap: () => context.go(AppRoutes.shopOrders),
                ),
                _Item(
                  label: 'الملف',
                  selected: current == 3,
                  onTap: () => context.go(AppRoutes.shopProfile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.gray100 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: selected ? AppColors.border : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.black : AppColors.gray500,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class ShopScaffold extends StatelessWidget {
  const ShopScaffold({
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
      appBar: ShopAppBar(title: title, showBack: showBack, actions: actions),
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
          if (showBottomNav) const ShopBottomNav(),
        ],
      ),
    );
  }
}

class ShopFeatureTile extends StatelessWidget {
  const ShopFeatureTile({
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
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: AppColors.gray500),
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

Future<void> confirmShopLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await AppBottomSheet.show<bool>(
    context: context,
    child: AppBottomSheetScaffold(
      title: 'تسجيل الخروج',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('هل تريد تسجيل الخروج من حساب المحل؟'),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'تسجيل الخروج',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'إلغاء',
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
  if (confirmed == true) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}
