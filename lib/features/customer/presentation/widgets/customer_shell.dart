import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';

class CustomerAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomerAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.showBack = true,
    this.showProfile = false,
    this.actions,
  });

  final String title;
  final Widget? titleWidget;
  final bool showBack;
  final bool showProfile;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(AppBarDesign.height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = showBack && Navigator.of(context).canPop();
    final cartCount = ref.watch(cartProvider.notifier).totalItemCount;
    final compareCount = ref.watch(productComparisonProvider).length;
    final unreadNotificationsCount = ref.watch(
      customerUnreadNotificationsCountProvider,
    );

    return Material(
      color: AppBarDesign.background,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppBarDesign.background,
          border: Border(
            bottom: BorderSide(color: AppBarDesign.borderColor),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppBarDesign.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      onPressed: AppHaptics.action(
                        () => Navigator.of(context).maybePop(),
                      ),
                      icon: Icon(
                        AppIcons.back,
                        color: AppBarDesign.iconColor,
                      ),
                      tooltip: 'رجوع'.tr,
                    ),
                  const AppLogoMark(),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child:
                        titleWidget ??
                        Text(
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
                  const SizedBox(width: AppSpacing.xs),
                  ...?actions,
                  if (compareCount > 0)
                    IconButton(
                      tooltip: 'مقارنة المنتجات'.tr,
                      icon: Badge(
                        label: Text('$compareCount'),
                        backgroundColor: AppBarDesign.badgeBackground,
                        textColor: AppBarDesign.badgeText,
                        child: Icon(
                          AppIcons.compare,
                          color: AppBarDesign.iconColor,
                        ),
                      ),
                      onPressed: AppHaptics.action(
                        () => context.push(AppRoutes.customerCompare),
                      ),
                    ),
                  IconButton(
                    tooltip: 'الإشعارات'.tr,
                    icon: _BadgedAppBarIcon(
                      icon: AppIcons.bell,
                      count: unreadNotificationsCount,
                    ),
                    onPressed: AppHaptics.action(
                      () => context.push(AppRoutes.customerNotifications),
                    ),
                  ),
                  IconButton(
                    tooltip: 'سلة المشتريات'.tr,
                    icon: _BadgedAppBarIcon(
                      icon: AppIcons.bag,
                      count: cartCount,
                    ),
                    onPressed: AppHaptics.action(
                      () => context.push(AppRoutes.customerCart),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgedAppBarIcon extends StatelessWidget {
  const _BadgedAppBarIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: AppBarDesign.iconColor);
    if (count <= 0) return iconWidget;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: AppBarDesign.badgeBackground,
      textColor: AppBarDesign.badgeText,
      child: iconWidget,
    );
  }
}

class CustomerBottomNav extends StatelessWidget {
  const CustomerBottomNav({super.key, this.currentIndex});

  final int? currentIndex;

  int _indexFor(String location) {
    if (currentIndex != null) return currentIndex!;
    if (location.startsWith(AppRoutes.customerProfile)) return 4;
    if (location.startsWith(AppRoutes.customerOrders)) return 3;
    if (location.startsWith(AppRoutes.customerFavorites)) return 2;
    if (location.startsWith(AppRoutes.customerCatalog) ||
        location.startsWith('/customer/products')) {
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
                _CustomerNavItem(
                  label: 'الرئيسية'.tr,
                  icon: AppIcons.home,
                  activeIcon: AppIcons.homeActive,
                  selected: current == 0,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.customerHome,
                    selected: current == 0,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.customerHome),
                  ),
                ),
                _CustomerNavItem(
                  label: 'المنتجات'.tr,
                  icon: AppIcons.grid,
                  activeIcon: AppIcons.gridActive,
                  selected: current == 1,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.customerCatalog,
                    selected: current == 1,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.customerCatalog),
                  ),
                ),
                _CustomerNavItem(
                  label: 'المفضلة'.tr,
                  icon: AppIcons.heart,
                  activeIcon: AppIcons.heartFilled,
                  selected: current == 2,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.customerFavorites,
                    selected: current == 2,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.customerFavorites),
                  ),
                ),
                _CustomerNavItem(
                  label: 'طلباتي'.tr,
                  icon: AppIcons.orders,
                  activeIcon: AppIcons.ordersActive,
                  selected: current == 3,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.customerOrders,
                    selected: current == 3,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.customerOrders),
                  ),
                ),
                _CustomerNavItem(
                  label: 'حسابي'.tr,
                  icon: AppIcons.user,
                  activeIcon: AppIcons.userActive,
                  selected: current == 4,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.customerProfile,
                    selected: current == 4,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.customerProfile),
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

class _CustomerNavItem extends StatelessWidget {
  const _CustomerNavItem({
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
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? BottomNavDesign.indicator
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
                      ? BottomNavDesign.selectedIcon
                      : BottomNavDesign.unselectedIcon,
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

class CustomerScaffold extends StatelessWidget {
  const CustomerScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    required this.body,
    this.currentNavIndex,
    this.showBack = true,
    this.showProfile = false,
    this.actions,
    this.floatingActionButton,
    this.showBottomNav = true,
    this.bottomSheet,
    this.bottomNavigationBar,
  });

  final String title;
  final Widget? titleWidget;
  final Widget body;
  final int? currentNavIndex;
  final bool showBack;
  final bool showProfile;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBottomNav;
  final Widget? bottomSheet;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomerAppBar(
        title: title,
        titleWidget: titleWidget,
        showBack: showBack,
        showProfile: showProfile,
        actions: actions,
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: !showBottomNav
          ? bottomNavigationBar
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?bottomNavigationBar,
                CustomerBottomNav(currentIndex: currentNavIndex),
              ],
            ),
      floatingActionButton: floatingActionButton,
      bottomSheet: bottomSheet,
    );
  }
}
