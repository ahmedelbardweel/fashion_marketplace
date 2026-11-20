import 'dart:async';

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/category_department_grid.dart';
import '../widgets/product_cart_sheet.dart';

import '../../../../core/widgets/app_filter_bar.dart';
import '../widgets/product_filter_sheet.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  Future<void> _toggleFavorite(WidgetRef ref, CustomerProduct product) async {
    final nextFav = !product.isFavorite;
    syncFavoriteAcrossProductLists(ref, product, nextFav);
    try {
      await ref.read(customerRepositoryProvider).toggleFavorite(product.id);
      ref.invalidate(customerProductDetailsProvider(product.id));
    } catch (_) {
      syncFavoriteAcrossProductLists(ref, product, product.isFavorite);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(customerBannersProvider);
    final categoriesAsync = ref.watch(customerCategoriesProvider);
    final shopsAsync = ref.watch(customerShopsProvider);
    final productsState = ref.watch(homeProductsProvider);
    final homeFilter = ref.watch(homeProductFilterProvider);
    final currentUser = ref.watch(authControllerProvider).user;

    return CustomerScaffold(
      title: 'مرحباً'.tr,
      titleWidget: _HomeGreetingHeader(user: currentUser),
      currentNavIndex: 0,
      showBack: false,
      showProfile: true,
      body: AppRefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(customerBannersProvider.future),
          ref.refresh(customerCategoriesProvider.future),
          ref.refresh(customerShopsProvider.future),
          ref.refresh(customerNotificationsProvider.future),
          ref.read(homeProductsProvider.notifier).refresh(),
        ]),
        child: AppPaginationScrollListener(
          hasMore: productsState.hasMore,
          isLoadingMore: productsState.isLoadingMore,
          onLoadMore: ref.read(homeProductsProvider.notifier).loadMore,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1) Promotional Hero Banners
                bannersAsync.skeletonWhen(
                  placeholder: LoadingFixtures.banners,
                  data: (banners) {
                    if (banners.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _HomeBannerCarousel(banners: banners),
                    );
                  },
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // 2) Category Department Strip (top 6 categories)
                categoriesAsync.skeletonWhen(
                  placeholder: LoadingFixtures.categories,
                  data: (categories) => CategoryDepartmentGrid(
                    categories: categories,
                    onSelected: (category) {
                      ref.read(productFilterProvider.notifier).state =
                          ProductFilter(categoryId: category.id);
                      context.push(AppRoutes.customerCatalog);
                    },
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // 3) Approved Shops (below categories) (Rounded-square logo tiles matching department strip)
                shopsAsync.skeletonWhen(
                  placeholder: LoadingFixtures.customerShops,
                  data: (shops) {
                    if (shops.isEmpty) return const SizedBox.shrink();
                    final isSkeleton = AppSkeleton.isActive(context);
                    final header = AppSectionHeader(
                      title: 'المتاجر المعتمدة'.tr,
                      actionLabel: 'تصفح الكل'.tr,
                      onAction: AppHaptics.action(
                        () => context.push(AppRoutes.customerShops),
                      ),
                    );
                    if (isSkeleton) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          header,
                          const SizedBox(height: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableWidth =
                                (constraints.maxWidth -
                                        (AppSpacing.pageGutter * 2))
                                    .clamp(0.0, double.infinity);
                            final minWidth =
                                (shops.length * HomeDesign.departmentSquareSize) +
                                ((shops.length - 1) * 3.0);
                            final needsScroll = minWidth > availableWidth;
                            final row = ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: availableWidth,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (var i = 0; i < shops.length; i++) ...[
                                    if (needsScroll && i > 0)
                                      const SizedBox(
                                        width: HomeDesign.departmentGridGap,
                                      ),
                                    SizedBox(
                                      width: HomeDesign.departmentSquareSize,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Bone.square(
                                            size: HomeDesign
                                                .departmentSquareSize,
                                            borderRadius:
                                                BorderRadius.circular(
                                                  HomeDesign
                                                      .departmentCornerRadius,
                                                ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            shops[i].name,
                                            maxLines: 1,
                                            overflow: TextOverflow.clip,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: HomeDesign.shopNameSize,
                                              fontWeight:
                                                  HomeDesign.shopNameWeight,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                            if (!needsScroll) {
                              return Padding(
                                padding: AppSpacing.pageHorizontal,
                                child: row,
                              );
                            }
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: AppSpacing.pageHorizontal,
                              child: row,
                            );
                          },
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: SizedBox(
                            height: HomeDesign.shopAvatarSize + 24,
                        child: ListView.separated(
                          padding: AppSpacing.pageHorizontal,
                          scrollDirection: Axis.horizontal,
                          itemCount: shops.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: HomeDesign.departmentGridGap),
                          itemBuilder: (context, index) {
                            final shop = shops[index];
                            final hasLogo =
                                shop.logoPath != null &&
                                shop.logoPath!.trim().isNotEmpty;
                            return InkWell(
                              onTap: AppHaptics.action(
                                () => context.push(
                                  AppRoutes.customerShopProfilePath(shop.id),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                HomeDesign.departmentCornerRadius,
                              ),
                              child: SizedBox(
                                width: HomeDesign.shopItemWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: HomeDesign.shopAvatarSize,
                                      height: HomeDesign.shopAvatarSize,
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          HomeDesign.departmentCornerRadius,
                                        ),
                                        color: AppColors.primary.withValues(
                                          alpha: AppColors.isDark ? 0.14 : 0.08,
                                        ),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha:
                                                AppColors.isDark ? 0.24 : 0.08,
                                          ),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          HomeDesign.departmentCornerRadius - 4,
                                        ),
                                        child: hasLogo
                                            ? AppNetworkImage(
                                                shop.logoPath!,
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                                height: double.infinity,
                                                errorBuilder: (_, _, _) =>
                                                    Center(
                                                      child: Icon(
                                                        AppIcons.shopActive,
                                                        size: 24,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                              )
                                            : Center(
                                                child: Icon(
                                                  AppIcons.shopActive,
                                                  size: 24,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      shop.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: HomeDesign.shopNameSize,
                                        fontWeight: HomeDesign.shopNameWeight,
                                        color: AppColors.text,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // 4) Latest Products Grid
                AppSectionHeader(
                  title: 'أحدث الأزياء'.tr,
                  actionLabel: 'تصفح الكل'.tr,
                  onAction: AppHaptics.action(
                    () => context.push(AppRoutes.customerCatalog),
                  ),
                ),
                AppFilterToolbar(
                  searchValue: homeFilter.search ?? '',
                  searchHint: 'ابحث باسم المنتج، المتجر، اللون...',
                  onSearchChanged: (val) {
                    ref
                        .read(homeProductFilterProvider.notifier)
                        .state = val.isEmpty
                        ? homeFilter.copyWith(clearSearch: true)
                        : homeFilter.copyWith(search: val);
                  },
                  quickOptions: [
                    AppQuickFilterOption(
                      id: 'home_in_stock',
                      label: 'متوفر فقط',
                      icon: AppIcons.checkCircle,
                      selected: homeFilter.inStockOnly,
                      onTap: () {
                        ref
                            .read(homeProductFilterProvider.notifier)
                            .state = homeFilter.copyWith(
                          inStockOnly: !homeFilter.inStockOnly,
                        );
                      },
                    ),
                    if ((categoriesAsync.value ?? const []).isNotEmpty) ...[
                      AppQuickFilterOption(
                        id: 'home_cat_all',
                        label: 'الكل',
                        selected: homeFilter.categoryId == null,
                        onTap: () {
                          ref.read(homeProductFilterProvider.notifier).state =
                              homeFilter.copyWith(clearCategory: true);
                        },
                      ),
                      for (final cat in (categoriesAsync.value ?? const []).where(
                        (c) => c.parentId == null,
                      ))
                        AppQuickFilterOption(
                          id: 'home_cat_${cat.id}',
                          label: cat.name,
                          selected:
                              homeFilter.categoryId == cat.id ||
                              (categoriesAsync.value ?? const []).any(
                                (child) =>
                                    child.id == homeFilter.categoryId &&
                                    child.parentId == cat.id,
                              ),
                          onTap: () {
                            final allCats =
                                categoriesAsync.value ?? const [];
                            final activeCat = allCats
                                .where((c) => c.id == homeFilter.categoryId)
                                .firstOrNull;
                            final activeDepartmentId =
                                activeCat?.parentId ?? activeCat?.id;
                            final selected = activeDepartmentId == cat.id;
                            ref
                                .read(homeProductFilterProvider.notifier)
                                .state = selected
                                ? homeFilter.copyWith(clearCategory: true)
                                : homeFilter.copyWith(categoryId: cat.id);
                          },
                        ),
                    ],
                  ],
                  activeTags: buildCustomerProductActiveTags(
                    filter: homeFilter,
                    categories: categoriesAsync.value ?? const [],
                    shops: shopsAsync.value ?? const [],
                    onChanged: (next) =>
                        ref.read(homeProductFilterProvider.notifier).state =
                            next,
                  ),
                  activeFacetCount: homeFilter.activeFacetCount,
                  sortLabel: homeFilter.sort.labelAr,
                  isDefaultSort: homeFilter.sort == ProductSortOption.newest,
                  onOpenSort: () async {
                    final selected = await showAppSortSheet<ProductSortOption>(
                      context: context,
                      current: homeFilter.sort,
                      options: kCustomerProductSortChoices,
                    );
                    if (selected != null) {
                      ref.read(homeProductFilterProvider.notifier).state =
                          homeFilter.copyWith(sort: selected);
                    }
                  },
                  onOpenAdvancedFilter: () async {
                    final updated = await showCustomerProductFilterSheet(
                      context: context,
                      initial: homeFilter,
                      sourceProducts: productsState.items,
                      categories: categoriesAsync.value ?? const [],
                      shops: shopsAsync.value ?? const [],
                    );
                    if (updated != null) {
                      ref.read(homeProductFilterProvider.notifier).state =
                          updated;
                    }
                  },
                  totalCount:
                      productsState.totalCount ??
                      (productsState.hasMore
                          ? null
                          : productsState.items.length),
                  filteredCount: productsState.isInitialLoading
                      ? null
                      : productsState.items.length,
                  hasActiveCustomization: homeFilter.hasActiveFilters,
                  showingSimilarFallback: productsState.isSimilarFallback,
                  onClearAll: () =>
                      ref.read(homeProductFilterProvider.notifier).state =
                          ProductFilter.empty,
                ),
                const SizedBox(height: AppSpacing.xs),

                productsState.skeletonWhen(
                  placeholder: LoadingFixtures.products,
                  data: (products) {
                    if (products.isEmpty && !productsState.isInitialLoading) {
                      if (homeFilter.hasActiveFilters) {
                        return Padding(
                          padding: AppSpacing.pageHorizontal,
                          child: Column(
                            children: [
                              AppFilterEmptyState(
                                onReset: () =>
                                    ref
                                        .read(
                                          homeProductFilterProvider.notifier,
                                        )
                                        .state = ProductFilter
                                        .empty,
                              ),
                              if (productsState.hasMore)
                                AppLoadMoreFooter(
                                  isLoadingMore: productsState.isLoadingMore,
                                  hasMore: productsState.hasMore,
                                  itemsCount: products.length,
                                  loadMoreError: productsState.loadMoreError,
                                  onLoadMore: ref
                                      .read(homeProductsProvider.notifier)
                                      .loadMore,
                                  useProductGridSkeleton: true,
                                ),
                            ],
                          ),
                        );
                      }
                      return AppEmpty(
                        icon: AppIcons.garment,
                        message: 'لا توجد منتجات منشورة حالياً'.tr,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: AppSpacing.pageHorizontal,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length,
                            gridDelegate: ProductGridDelegate(
                              textScale:
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14,
                            ),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return ProductGridCard(
                                imageUrl: product.coverImage,
                                meta: AppFormat.price(product.price),
                                originalMeta: product.hasOffer
                                    ? AppFormat.price(product.originalPrice!)
                                    : null,
                                discountPercent: product.hasOffer
                                    ? product.discountPercent
                                    : null,
                                inStock: product.totalStock > 0,
                                isFavorite: product.isFavorite,
                                onToggleFavorite: () =>
                                    _toggleFavorite(ref, product),
                                onAddToCart: () =>
                                    showProductCartSheet(context, product.id),
                                onTap: () => context.push(
                                  AppRoutes.customerProductDetailsPath(
                                    product.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (!productsState.isInitialLoading)
                          AppLoadMoreFooter(
                            isLoadingMore: productsState.isLoadingMore,
                            hasMore: productsState.hasMore,
                            itemsCount: products.length,
                            loadMoreError: productsState.loadMoreError,
                            onLoadMore: ref
                                .read(homeProductsProvider.notifier)
                                .loadMore,
                            useProductGridSkeleton: true,
                          ),
                      ],
                    );
                  },
                  error: (err) => AppEmpty(
                    icon: AppIcons.error,
                    message: 'تعذر تحميل المنتجات: $err'.tr,
                    actionLabel: 'إعادة المحاولة'.tr,
                    onAction: ref.read(homeProductsProvider.notifier).refresh,
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

class _HomeBannerCarousel extends StatefulWidget {
  const _HomeBannerCarousel({required this.banners});

  final List<AdminBanner> banners;

  @override
  State<_HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<_HomeBannerCarousel> {
  final PageController _controller = PageController();
  Timer? _autoPlayTimer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length <= 1) return;
    _autoPlayTimer = Timer.periodic(HomeDesign.bannerAutoPlay, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: AppMotion.normal,
        curve: AppMotion.curve,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: HomeDesign.bannerHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final b = widget.banners[index];
              final hasImage =
                  b.imagePath != null && b.imagePath!.trim().isNotEmpty;
              return Material(
                color: HomeDesign.bannerBackground,
                borderRadius: BorderRadius.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: AppHaptics.action(
                    () => context.push(AppRoutes.customerCatalog),
                  ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage) ...[
                          AppNetworkImage(
                            b.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [Color(0xB8000000), Color(0x4D000000)],
                              ),
                            ),
                          ),
                        ] else ...[
                          PositionedDirectional(
                            end: -28,
                            top: -28,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppPalette.white.withValues(alpha: 0.10),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            end: 40,
                            bottom: -40,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppPalette.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.white.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                      ),
                                      child: Text(
                                        'عرض خاص'.tr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: AppFont.bold,
                                          color: HomeDesign.bannerTitle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        b.title.tr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: HomeDesign.bannerTitleSize,
                                          fontWeight:
                                              HomeDesign.bannerTitleWeight,
                                          color: HomeDesign.bannerTitle,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (b.subtitle != null &&
                                        b.subtitle!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Flexible(
                                        child: Text(
                                          b.subtitle!.tr,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: AppFont.medium,
                                            color: HomeDesign.bannerSubtitle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: HomeDesign.bannerButtonBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'تسوق الآن'.tr,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: AppFont.bold,
                                        color: HomeDesign.bannerButtonText,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      AppIcons.arrowForward,
                                      size: 14,
                                      color: HomeDesign.bannerButtonText,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _index;
              return GestureDetector(
                onTap: () => _controller.animateToPage(
                  i,
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                ),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  width: active ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: active
                        ? HomeDesign.bannerDotActive
                        : HomeDesign.bannerDotInactive,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _HomeGreetingHeader extends StatelessWidget {
  const _HomeGreetingHeader({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final fullName = user?.fullName?.trim();
    final email = user?.email.trim() ?? '';
    final city = user?.city?.trim() ?? '';
    final address = user?.address?.trim() ?? '';
    final location = city.isNotEmpty ? city : address;

    final greetingName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : (email.contains('@') ? email.split('@').first : 'بك'.tr);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${'مرحباً'.tr}${AppLang.isEn ? ',' : '،'} $greetingName 👋',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: AppBarDesign.titleWeight,
            color: AppBarDesign.titleColor,
            height: 1.15,
          ),
        ),
        if (email.isNotEmpty || location.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (email.isNotEmpty)
                Flexible(
                  flex: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.mail,
                        size: 11.5,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFont.medium,
                            color: AppColors.textMuted,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (email.isNotEmpty && location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.2,
                    ),
                  ),
                ),
              if (location.isNotEmpty)
                Flexible(
                  flex: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.location,
                        size: 11.5,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFont.semiBold,
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
