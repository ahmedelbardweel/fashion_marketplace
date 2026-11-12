import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
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
  Size get preferredSize => const Size.fromHeight(AppBarDesign.height);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    return AppBar(
      toolbarHeight: AppBarDesign.height,
      backgroundColor: SellerDesign.appBarBackground,
      foregroundColor: AppBarDesign.titleColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      shape: Border(bottom: BorderSide(color: AppBarDesign.borderColor)),
      leading: canPop
          ? IconButton(
              onPressed: AppHaptics.action(
                () => Navigator.of(context).maybePop(),
              ),
              icon: Icon(
                AppIcons.back,
                color: AppBarDesign.iconColor,
              ),
            )
          : const SizedBox.shrink(),
      leadingWidth: canPop ? 56 : 12,
      title: Text(
        AppLang.tr(title),
        style: TextStyle(
          fontSize: AppBarDesign.titleSize,
          fontWeight: AppBarDesign.titleWeight,
          color: AppBarDesign.titleColor,
        ),
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
      color: BottomNavDesign.background,
      child: Container(
        decoration: BoxDecoration(
          color: BottomNavDesign.background,
          border: Border(top: BorderSide(color: BottomNavDesign.borderColor)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: BottomNavDesign.height,
            child: Row(
              children: [
                _Item(
                  label: 'الرئيسية'.tr,
                  icon: AppIcons.dashboard,
                  activeIcon: AppIcons.dashboardActive,
                  selected: current == 0,
                  onTap: () => context.go(AppRoutes.shopHome),
                ),
                _Item(
                  label: 'المنتجات'.tr,
                  icon: AppIcons.garment,
                  activeIcon: AppIcons.garmentFilled,
                  selected: current == 1,
                  onTap: () => context.go(AppRoutes.shopProducts),
                ),
                _Item(
                  label: 'الطلبات'.tr,
                  icon: AppIcons.orders,
                  activeIcon: AppIcons.ordersActive,
                  selected: current == 2,
                  onTap: () => context.go(AppRoutes.shopOrders),
                ),
                _Item(
                  label: 'المتجر'.tr,
                  icon: AppIcons.shop,
                  activeIcon: AppIcons.shopActive,
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
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.fast,
            constraints: const BoxConstraints(
              minWidth: BottomNavDesign.indicatorWidth,
              minHeight: BottomNavDesign.indicatorHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? SellerDesign.navSelectedBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                BottomNavDesign.indicatorRadius,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: BottomNavDesign.iconSize,
                  color: selected
                      ? SellerDesign.navSelectedIcon
                      : SellerDesign.navUnselectedIcon,
                ),
                const SizedBox(height: 2),
                Text(
                  AppLang.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: BottomNavDesign.labelSize,
                    color: selected
                        ? BottomNavDesign.selectedLabel
                        : BottomNavDesign.unselectedLabel,
                    fontWeight: selected
                        ? BottomNavDesign.selectedWeight
                        : BottomNavDesign.unselectedWeight,
                  ),
                ),
              ],
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
      backgroundColor: AppColors.background,
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
                      AppLang.tr(code),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLang.tr(title),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLang.tr(subtitle),
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
                    AppLang.tr(badge!),
                    style: TextStyle(
                      color: BadgeDesign.primaryText,
                      fontSize: BadgeDesign.textSize,
                      fontWeight: BadgeDesign.textWeight,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              Icon(AppIcons.forward, color: AppColors.icon),
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
      title: 'تسجيل الخروج'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('هل تريد تسجيل الخروج من حساب المحل؟'.tr),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'تسجيل الخروج'.tr,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'إلغاء'.tr,
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
