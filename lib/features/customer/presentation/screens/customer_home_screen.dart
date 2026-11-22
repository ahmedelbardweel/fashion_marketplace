import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/network_guard.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../core/widgets/promo_banner_carousel.dart';
import '../../../../router/routes.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/customer_product.dart';
import '../../domain/models/customer_shop.dart';
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
                      child: PromoBannerCarousel(
                        banners: banners,
                        onBannerTap: (b) {
                          if (b.isShopBanner) {
                            context.push(
                              AppRoutes.customerShopProfilePath(b.shopId!),
                            );
                          } else {
                            context.push(AppRoutes.customerCatalog);
                          }
                        },
                      ),
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
                    final rootCategoriesCount = (categoriesAsync.asData?.value ??
                            const [])
                        .where((c) => c.parentId == null)
                        .length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppSectionHeader(
                          title: 'المتاجر المعتمدة'.tr,
                          actionLabel: 'تصفح الكل'.tr,
                          onAction: AppHaptics.action(
                            () => context.push(AppRoutes.customerShops),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                            bottom: AppSpacing.md,
                          ),
                          child: _ApprovedShopsStrip(
                            shops: shops,
                            referenceSlots: rootCategoriesCount >= 2
                                ? rootCategoriesCount
                                : 6,
                            onSelected: (shop) => context.push(
                              AppRoutes.customerShopProfilePath(shop.id),
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
                    message: AppErrorMapper.message(
                      err,
                      fallback: 'تعذر تحميل المنتجات حالياً. حاول مرة أخرى.',
                    ),
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

class _ApprovedShopsStrip extends StatelessWidget {
  const _ApprovedShopsStrip({
    required this.shops,
    required this.referenceSlots,
    required this.onSelected,
  });

  final List<CustomerShop> shops;
  final int referenceSlots;
  final ValueChanged<CustomerShop> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSkeleton = AppSkeleton.isActive(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            (constraints.maxWidth - (AppSpacing.pageGutter * 2)).clamp(
              0.0,
              double.infinity,
            );
        const tileSize = HomeDesign.departmentSquareSize;
        final refSlots = referenceSlots < 2 ? 6 : referenceSlots;
        final rawGap =
            (availableWidth - (refSlots * tileSize)) / (refSlots - 1);
        final gap = rawGap >= 3.0 ? rawGap : HomeDesign.departmentGridGap;
        final contentWidth =
            (shops.length * tileSize) + ((shops.length - 1) * gap);
        final needsScroll = contentWidth > availableWidth + 0.5;

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < shops.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _buildTile(context, shops[i], isSkeleton),
            ],
          ],
        );

        if (!needsScroll) {
          return Padding(
            padding: AppSpacing.pageHorizontal,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: row,
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.pageHorizontal,
          child: row,
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, CustomerShop shop, bool isSkeleton) {
    final hasLogo = shop.logoPath != null && shop.logoPath!.trim().isNotEmpty;
    final label = shop.name.trim();
    final labelStyle = TextStyle(
      fontSize: HomeDesign.departmentLabelSize,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AppColors.text,
    );

    final labelWidget = isSkeleton
        ? Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: labelStyle,
          )
        : label.contains(' ')
        ? Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: labelStyle,
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: labelStyle),
          );

    return SizedBox(
      width: HomeDesign.departmentSquareSize,
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            HomeDesign.departmentCornerRadius,
          ),
          onTap: isSkeleton
              ? null
              : AppHaptics.action(() => onSelected(shop)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isSkeleton
                  ? Bone.square(
                      size: HomeDesign.departmentSquareSize,
                      borderRadius: BorderRadius.circular(
                        HomeDesign.departmentCornerRadius,
                      ),
                    )
                  : Container(
                      width: HomeDesign.departmentSquareSize,
                      height: HomeDesign.departmentSquareSize,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          HomeDesign.departmentCornerRadius,
                        ),
                        color: AppColors.primary.withValues(
                          alpha: AppColors.isDark ? 0.14 : 0.08,
                        ),
                        border: Border.all(color: AppColors.border),
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
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(
                                    AppIcons.shopActive,
                                    size: HomeDesign.departmentIconSize - 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  AppIcons.shopActive,
                                  size: HomeDesign.departmentIconSize - 2,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    ),
              const SizedBox(height: AppSpacing.xs),
              labelWidget,
            ],
          ),
        ),
      ),
    );
  }
}
