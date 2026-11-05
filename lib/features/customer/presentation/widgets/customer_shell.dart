import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
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
  Size get preferredSize => const Size.fromHeight(64);

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
      duration: const Duration(milliseconds: 280),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
      color: AppColors.white,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
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
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      color: AppColors.black,
                                    ),
                                    tooltip: 'رجوع',
                                  ),
                                if (!widget.showSearch) ...[
                                  Text(
                                    widget.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppColors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const Spacer(),
                                ] else
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _openSearch,
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray100,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.input,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.search,
                                              size: 20,
                                              color: AppColors.gray500,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            Expanded(
                                              child: Text(
                                                'ابحث عن قميص، فستان، هودي، أو مقاسك...',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: AppColors.gray500,
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
                                    tooltip: 'مقارنة المنتجات',
                                    icon: Badge(
                                      label: Text('$compareCount'),
                                      backgroundColor: AppColors.black,
                                      textColor: AppColors.white,
                                      child: const Icon(
                                        Icons.compare_arrows_rounded,
                                        color: AppColors.black,
                                      ),
                                    ),
                                    onPressed: () =>
                                        context.push(AppRoutes.customerCompare),
                                  ),
                                IconButton(
                                  tooltip: 'الإشعارات',
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: AppColors.black,
                                  ),
                                  onPressed: () => context.push(
                                    AppRoutes.customerNotifications,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'سلة المشتريات',
                                  icon: cartCount > 0
                                      ? Badge(
                                          label: Text('$cartCount'),
                                          backgroundColor: AppColors.black,
                                          textColor: AppColors.white,
                                          child: const Icon(
                                            Icons.shopping_bag_outlined,
                                            color: AppColors.black,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: AppColors.black,
                                        ),
                                  onPressed: () =>
                                      context.push(AppRoutes.customerCart),
                                ),
                                if (widget.showProfile)
                                  IconButton(
                                    tooltip: 'الملف الشخصي',
                                    icon: const Icon(
                                      Icons.person_outline_rounded,
                                      color: AppColors.black,
                                    ),
                                    onPressed: () =>
                                        context.push(AppRoutes.customerProfile),
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
                                color: AppColors.gray100,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.input,
                                ),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      color: AppColors.black,
                                      size: 20,
                                    ),
                                    tooltip: 'إغلاق البحث',
                                    onPressed: _closeSearch,
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
                                            color: AppColors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      decoration: InputDecoration(
                                        hintText: 'ابحث عن قميص، فستان، هودي، أو مقاسك...',
                                        hintStyle: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.gray500,
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
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: AppColors.gray500,
                                      ),
                                      tooltip: 'مسح',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.search,
                                      color: AppColors.black,
                                      size: 20,
                                    ),
                                    tooltip: 'بحث',
                                    onPressed: () =>
                                        _submitSearch(_searchController.text),
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
      color: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.bottomSheet),
        ),
      ),
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
                _CustomerNavItem(
                  label: 'الرئيسية',
                  selected: current == 0,
                  onTap: () => context.go(AppRoutes.customerHome),
                ),
                _CustomerNavItem(
                  label: 'المنتجات',
                  selected: current == 1,
                  onTap: () => context.go(AppRoutes.customerCatalog),
                ),
                _CustomerNavItem(
                  label: 'المفضلة',
                  selected: current == 2,
                  onTap: () => context.go(AppRoutes.customerFavorites),
                ),
                _CustomerNavItem(
                  label: 'طلباتي',
                  selected: current == 3,
                  onTap: () => context.go(AppRoutes.customerOrders),
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
        onTap: onTap,
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
      backgroundColor: AppColors.white,
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
