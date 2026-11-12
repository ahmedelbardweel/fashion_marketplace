import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../router/routes.dart';

class AdminBottomNav extends StatelessWidget {
  const AdminBottomNav({super.key});

  int _indexFor(String location) {
    if (location.startsWith(AppRoutes.adminSettings)) return 2;
    if (location.startsWith(AppRoutes.adminShopApplications) ||
        location.startsWith('/admin/shops/')) {
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
                  onTap: () => context.go(AppRoutes.adminHome),
                ),
                _NavItem(
                  label: 'الطلبات'.tr,
                  icon: AppIcons.shop,
                  activeIcon: AppIcons.shopActive,
                  selected: current == 1,
                  onTap: () => context.go(AppRoutes.adminShopApplications),
                ),
                _NavItem(
                  label: 'الإعدادات'.tr,
                  icon: AppIcons.settings,
                  activeIcon: AppIcons.settingsActive,
                  selected: current == 2,
                  onTap: () => context.go(AppRoutes.adminSettings),
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
                Icon(
                  selected ? activeIcon : icon,
                  size: BottomNavDesign.iconSize,
                  color: selected
                      ? AdminDesign.navSelectedIcon
                      : AdminDesign.navUnselectedIcon,
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
