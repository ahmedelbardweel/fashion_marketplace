import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/shop_catalog_providers.dart';

class ShopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const ShopAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.showBack = true,
    this.showNotifications = true,
    this.actions,
  });

  final String title;
  final Widget? titleWidget;
  final bool showBack;
  final bool showNotifications;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(AppBarDesign.height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = showBack && Navigator.of(context).canPop();
    final unreadCount = showNotifications
        ? ref.watch(shopUnreadNotificationsCountProvider)
        : 0;
    final overlayStyle = AppColors.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AppBar(
      toolbarHeight: AppBarDesign.height,
      backgroundColor: SellerDesign.appBarBackground,
      foregroundColor: AppBarDesign.titleColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: overlayStyle,
      shape: Border(bottom: BorderSide(color: AppBarDesign.borderColor)),
      leading: canPop
          ? IconButton(
              tooltip: 'رجوع'.tr,
              onPressed: AppHaptics.action(
                () => Navigator.of(context).maybePop(),
              ),
              icon: Icon(AppIcons.back, color: AppBarDesign.iconColor),
            )
          : const Padding(
              padding: EdgeInsetsDirectional.only(start: AppSpacing.sm),
              child: Center(child: AppLogoMark()),
            ),
      leadingWidth: canPop ? 56 : 48,
      titleSpacing: canPop ? 0 : AppSpacing.xs,
      centerTitle: false,
      title: titleWidget != null
          ? Row(
              children: [
                if (canPop) ...[
                  const AppLogoMark(),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(child: titleWidget!),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPop) ...[
                  const AppLogoMark(),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    AppLang.tr(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppBarDesign.titleSize,
                      fontWeight: AppBarDesign.titleWeight,
                      color: AppBarDesign.titleColor,
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        ...?actions,
        if (showNotifications)
          IconButton(
            tooltip: 'الإشعارات'.tr,
            onPressed: AppHaptics.action(
              () => context.push(AppRoutes.shopNotifications),
            ),
            icon: _ShopBadgedIcon(icon: AppIcons.bell, count: unreadCount),
          ),
      ],
    );
  }
}

class _ShopBadgedIcon extends StatelessWidget {
  const _ShopBadgedIcon({
    required this.icon,
    required this.count,
    this.color,
    this.size,
  });

  final IconData icon;
  final int count;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: color ?? AppBarDesign.iconColor,
      size: size,
    );
    if (count <= 0) return iconWidget;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: AppBarDesign.badgeBackground,
      textColor: AppBarDesign.badgeText,
      child: iconWidget,
    );
  }
}

class ShopBottomNav extends ConsumerWidget {
  const ShopBottomNav({super.key});

  int _indexFor(String location) {
    if (location.startsWith(AppRoutes.shopProfile)) return 4;
    if (location.startsWith(AppRoutes.shopOrders)) return 3;
    if (location.startsWith(AppRoutes.shopOffers)) return 2;
    if (location.startsWith(AppRoutes.shopProducts) ||
        location.startsWith('/shop/product')) {
      return 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final current = _indexFor(location);
    final pendingOrders =
        ref.watch(shopStatsProvider).asData?.value.pendingOrders ?? 0;

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
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.shopHome,
                    selected: current == 0,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.shopHome),
                  ),
                ),
                _Item(
                  label: 'المنتجات'.tr,
                  icon: AppIcons.garment,
                  activeIcon: AppIcons.garmentFilled,
                  selected: current == 1,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.shopProducts,
                    selected: current == 1,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.shopProducts),
                  ),
                ),
                _Item(
                  label: 'العروض'.tr,
                  icon: AppIcons.offers,
                  activeIcon: AppIcons.offersActive,
                  selected: current == 2,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.shopOffers,
                    selected: current == 2,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.shopOffers),
                  ),
                ),
                _Item(
                  label: 'الطلبات'.tr,
                  icon: AppIcons.orders,
                  activeIcon: AppIcons.ordersActive,
                  selected: current == 3,
                  badgeCount: pendingOrders,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.shopOrders,
                    selected: current == 3,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.shopOrders),
                  ),
                ),
                _Item(
                  label: 'المتجر'.tr,
                  icon: AppIcons.shop,
                  activeIcon: AppIcons.shopActive,
                  selected: current == 4,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.shopProfile,
                    selected: current == 4,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.shopProfile),
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

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? SellerDesign.navSelectedIcon
        : SellerDesign.navUnselectedIcon;
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                _ShopBadgedIcon(
                  icon: selected ? activeIcon : icon,
                  count: badgeCount,
                  color: iconColor,
                  size: BottomNavDesign.iconSize,
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
    this.titleWidget,
    this.showBack = true,
    this.showBottomNav = true,
    this.showNotifications = true,
    this.actions,
    this.bottom,
  });

  final String title;
  final Widget? titleWidget;
  final Widget body;
  final bool showBack;
  final bool showBottomNav;
  final bool showNotifications;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellerDesign.pageBackground,
      appBar: ShopAppBar(
        title: title,
        titleWidget: titleWidget,
        showBack: showBack,
        showNotifications: showNotifications,
        actions: actions,
      ),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bottom != null)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: AppBorders.side),
              ),
              child: SafeArea(
                top: false,
                bottom: !showBottomNav,
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
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.trailingValue,
    this.badgeTone = BadgeTone.primary,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final String? trailingValue;
  final BadgeTone badgeTone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SellerDesign.statCardBackground,
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
                      AppLang.tr(title),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLang.tr(subtitle),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingValue != null) ...[
                const SizedBox(width: AppSpacing.md),
                Text(
                  trailingValue!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: SellerDesign.statValueWeight,
                    color: AppColors.text,
                  ),
                ),
              ] else if (badge != null) ...[
                const SizedBox(width: AppSpacing.sm),
                AppStatusBadge(label: badge!, tone: badgeTone),
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
      title: 'تسجيل الخروج'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'هل تريد تسجيل الخروج من حساب المحل؟'.tr,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppPalette.white,
            ),
            onPressed: AppHaptics.action(() => Navigator.of(context).pop(true)),
            child: Text('تسجيل الخروج'.tr),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'إلغاء'.tr,
            variant: AppButtonVariant.secondary,
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
