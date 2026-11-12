import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';

class CustomerAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const CustomerAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.showSearch = true,
    this.showProfile = false,
    this.actions,
    this.onSearchSubmitted,
  });

  final String title;
  final bool showBack;
  final bool showSearch;
  final bool showProfile;
  final List<Widget>? actions;
  final ValueChanged<String>? onSearchSubmitted;

  @override
  Size get preferredSize => const Size.fromHeight(AppBarDesign.height);

  @override
  ConsumerState<CustomerAppBar> createState() => _CustomerAppBarState();
}

class _CustomerAppBarState extends ConsumerState<CustomerAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.curve,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted && _isSearching) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
    });
    _controller.forward();
    _focusNode.requestFocus();
  }

  void _closeSearch() {
    _focusNode.unfocus();
    _controller.reverse();
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    if (widget.onSearchSubmitted != null) {
      widget.onSearchSubmitted!(trimmed);
    } else if (trimmed.isNotEmpty) {
      ref.read(productFilterProvider.notifier).state = ref
          .read(productFilterProvider)
          .copyWith(search: trimmed);
      final currentLoc = GoRouterState.of(context).uri.path;
      if (!currentLoc.startsWith(AppRoutes.customerCatalog)) {
        context.push(AppRoutes.customerCatalog);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = widget.showBack && Navigator.of(context).canPop();
    final cartCount = ref.watch(cartProvider.notifier).totalItemCount;
    final compareCount = ref.watch(productComparisonProvider).length;

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
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final progress = _animation.value;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Layer 1: Normal Bar (Title, Search Pill trigger, Actions)
                    Positioned.fill(
                      child: Opacity(
                        opacity: (1.0 - progress * 1.6).clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: progress > 0.3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
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
                                if (!widget.showSearch) ...[
                                  Expanded(
                                    child: Text(
                                      AppLang.tr(widget.title),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: AppBarDesign.titleSize,
                                        fontWeight: AppBarDesign.titleWeight,
                                        color: AppBarDesign.titleColor,
                                      ),
                                    ),
                                  ),
                                ] else
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: AppHaptics.action(_openSearch),
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        height: AppBarDesign.searchHeight,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppBarDesign.searchBackground,
                                          borderRadius: BorderRadius.circular(
                                            AppBarDesign.searchRadius,
                                          ),
                                          border: Border.all(
                                            color: AppBarDesign.searchBorder,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              AppIcons.search,
                                              size: 20,
                                              color: AppBarDesign.searchIcon,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Expanded(
                                              child: Text(
                                                AppBarDesign.searchHintText,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: AppBarDesign
                                                          .searchHint,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: AppSpacing.xs),
                                // Actions
                                ...?widget.actions,
                                if (compareCount > 0)
                                  IconButton(
                                    tooltip: 'مقارنة المنتجات'.tr,
                                    icon: Badge(
                                      label: Text('$compareCount'),
                                      backgroundColor:
                                          AppBarDesign.badgeBackground,
                                      textColor: AppBarDesign.badgeText,
                                      child: Icon(
                                        AppIcons.compare,
                                        color: AppBarDesign.iconColor,
                                      ),
                                    ),
                                    onPressed: AppHaptics.action(
                                      () => context.push(
                                        AppRoutes.customerCompare,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'الإشعارات'.tr,
                                  icon: Icon(
                                    AppIcons.bell,
                                    color: AppBarDesign.iconColor,
                                  ),
                                  onPressed: AppHaptics.action(
                                    () => context.push(
                                      AppRoutes.customerNotifications,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'سلة المشتريات'.tr,
                                  icon: cartCount > 0
                                      ? Badge(
                                          label: Text('$cartCount'),
                                          backgroundColor:
                                              AppBarDesign.badgeBackground,
                                          textColor: AppBarDesign.badgeText,
                                          child: Icon(
                                            AppIcons.bag,
                                            color: AppBarDesign.iconColor,
                                          ),
                                        )
                                      : Icon(
                                          AppIcons.bag,
                                          color: AppBarDesign.iconColor,
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

                    // Layer 2: Expanded Full-Width Animated Search Bar
                    if (_isSearching || progress > 0)
                      Positioned(
                        left: AppSpacing.sm,
                        right: AppSpacing.sm,
                        top: 10,
                        bottom: 10,
                        child: Opacity(
                          opacity: progress.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.98 + (0.02 * progress),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppBarDesign.searchBackground,
                                borderRadius: BorderRadius.circular(
                                  AppBarDesign.searchRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 1.4,
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      AppIcons.back,
                                      color: AppBarDesign.iconColor,
                                      size: 20,
                                    ),
                                    tooltip: 'إغلاق البحث'.tr,
                                    onPressed: AppHaptics.action(_closeSearch),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _focusNode,
                                      textInputAction: TextInputAction.search,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.text,
                                            fontWeight: AppFont.semiBold,
                                          ),
                                      decoration: InputDecoration(
                                        hintText: AppBarDesign.searchHintText,
                                        hintStyle: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppBarDesign.searchHint,
                                            ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.xs,
                                              vertical: 8,
                                            ),
                                      ),
                                      onChanged: (text) => setState(() {}),
                                      onSubmitted: (query) =>
                                          _submitSearch(query),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        AppIcons.close,
                                        size: 18,
                                        color: AppColors.iconMuted,
                                      ),
                                      tooltip: 'مسح'.tr,
                                      onPressed: AppHaptics.action(() {
                                        _searchController.clear();
                                        setState(() {});
                                      }),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      AppIcons.search,
                                      color: AppBarDesign.iconColor,
                                      size: 20,
                                    ),
                                    tooltip: 'بحث'.tr,
                                    onPressed: AppHaptics.action(
                                      () =>
                                          _submitSearch(_searchController.text),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
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
                  onTap: () => context.go(AppRoutes.customerHome),
                ),
                _CustomerNavItem(
                  label: 'المنتجات'.tr,
                  icon: AppIcons.grid,
                  activeIcon: AppIcons.gridActive,
                  selected: current == 1,
                  onTap: () => context.go(AppRoutes.customerCatalog),
                ),
                _CustomerNavItem(
                  label: 'المفضلة'.tr,
                  icon: AppIcons.heart,
                  activeIcon: AppIcons.heartFilled,
                  selected: current == 2,
                  onTap: () => context.go(AppRoutes.customerFavorites),
                ),
                _CustomerNavItem(
                  label: 'طلباتي'.tr,
                  icon: AppIcons.orders,
                  activeIcon: AppIcons.ordersActive,
                  selected: current == 3,
                  onTap: () => context.go(AppRoutes.customerOrders),
                ),
                _CustomerNavItem(
                  label: 'حسابي'.tr,
                  icon: AppIcons.user,
                  activeIcon: AppIcons.userActive,
                  selected: current == 4,
                  onTap: () => context.go(AppRoutes.customerProfile),
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
    required this.body,
    this.currentNavIndex,
    this.showBack = true,
    this.showSearch = true,
    this.showProfile = false,
    this.actions,
    this.onSearchSubmitted,
    this.floatingActionButton,
    this.showBottomNav = true,
    this.bottomSheet,
    this.bottomNavigationBar,
  });

  final String title;
  final Widget body;
  final int? currentNavIndex;
  final bool showBack;
  final bool showSearch;
  final bool showProfile;
  final List<Widget>? actions;
  final ValueChanged<String>? onSearchSubmitted;
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
        showBack: showBack,
        showSearch: showSearch,
        showProfile: showProfile,
        actions: actions,
        onSearchSubmitted: onSearchSubmitted,
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
