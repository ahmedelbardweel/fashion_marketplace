import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../router/routes.dart';
import '../providers/admin_providers.dart';

class AdminBottomNav extends ConsumerWidget {
  const AdminBottomNav({super.key});

  int _indexFor(String location) {
    if (location.startsWith(AppRoutes.adminSettings)) return 4;
    if (location.startsWith(AppRoutes.adminBanners)) return 3;
    if (location.startsWith(AppRoutes.adminOrders)) return 2;
    if (location.startsWith(AppRoutes.adminShopsManage) ||
        location.startsWith(AppRoutes.adminShopApplications) ||
        location.startsWith('/admin/shops/')) {
      return 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final current = _indexFor(location);
    final pendingShops =
        ref.watch(adminStatsProvider).asData?.value.pendingShops ?? 0;

    return Material(
      color: BottomNavDesign.background,
      elevation: 0,
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
                _NavItem(
                  label: 'الرئيسية'.tr,
                  icon: AppIcons.dashboard,
                  activeIcon: AppIcons.dashboardActive,
                  selected: current == 0,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.adminHome,
                    selected: current == 0,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.adminHome),
                  ),
                ),
                _NavItem(
                  label: 'المحلات'.tr,
                  icon: AppIcons.shop,
                  activeIcon: AppIcons.shopActive,
                  selected: current == 1,
                  badgeCount: pendingShops,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.adminShopsManage,
                    selected: current == 1,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.adminShopsManage),
                  ),
                ),
                _NavItem(
                  label: 'الطلبات'.tr,
                  icon: AppIcons.orders,
                  activeIcon: AppIcons.ordersActive,
                  selected: current == 2,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.adminOrders,
                    selected: current == 2,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.adminOrders),
                  ),
                ),
                _NavItem(
                  label: 'البنرات'.tr,
                  icon: AppIcons.banners,
                  activeIcon: AppIcons.bannersActive,
                  selected: current == 3,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.adminBanners,
                    selected: current == 3,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.adminBanners),
                  ),
                ),
                _NavItem(
                  label: 'الإعدادات'.tr,
                  icon: AppIcons.settings,
                  activeIcon: AppIcons.settingsActive,
                  selected: current == 4,
                  onTap: () => AppRefreshIndicator.handleBottomNavTap(
                    targetRoute: AppRoutes.adminSettings,
                    selected: current == 4,
                    currentLocation: location,
                    onNavigate: () => context.go(AppRoutes.adminSettings),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
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
        ? AdminDesign.navSelectedIcon
        : AdminDesign.navUnselectedIcon;
    return Expanded(
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        child: Center(
          child: AnimatedContainer(
            duration: AppMotion.fast,
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: BottomNavDesign.indicatorHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AdminDesign.navSelectedBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                BottomNavDesign.indicatorRadius,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? activeIcon : icon,
                      size: BottomNavDesign.iconSize,
                      color: iconColor,
                    ),
                    if (badgeCount > 0)
                      PositionedDirectional(
                        end: -8,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppPalette.white,
                              fontSize: 9.5,
                              fontWeight: AppFont.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                  ],
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
