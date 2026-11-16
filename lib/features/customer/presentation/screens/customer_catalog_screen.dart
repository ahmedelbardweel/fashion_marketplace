import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/product_cart_sheet.dart';
import '../widgets/product_filter_sheet.dart';

class CustomerCatalogScreen extends ConsumerStatefulWidget {
  const CustomerCatalogScreen({super.key});

  @override
  ConsumerState<CustomerCatalogScreen> createState() =>
      _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends ConsumerState<CustomerCatalogScreen> {
  Future<void> _toggleFavorite(CustomerProduct product) async {
    final nextFav = !product.isFavorite;
    syncFavoriteAcrossProductLists(ref, product, nextFav);
    try {
      await ref.read(customerRepositoryProvider).toggleFavorite(product.id);
      ref.invalidate(customerProductDetailsProvider(product.id));
    } catch (_) {
      syncFavoriteAcrossProductLists(ref, product, product.isFavorite);
    }
  }

  Future<void> _openFilterBottomSheet() async {
    final currentFilter = ref.read(productFilterProvider);
    final categories = ref.read(customerCategoriesProvider).value ?? const [];
    final shops = ref.read(customerShopsProvider).value ?? const [];
    final loadedProducts = ref.read(catalogProductsProvider).items;

    final updated = await showCustomerProductFilterSheet(
      context: context,
      initial: currentFilter,
      sourceProducts: loadedProducts,
      categories: categories,
      shops: shops,
    );
    if (updated != null) {
      ref.read(productFilterProvider.notifier).state = updated;
    }
  }

  Future<void> _openSortSheet() async {
    final currentFilter = ref.read(productFilterProvider);
    final selected = await showAppSortSheet<ProductSortOption>(
      context: context,
      current: currentFilter.sort,
      options: kCustomerProductSortChoices,
    );
    if (selected != null) {
      ref.read(productFilterProvider.notifier).state = currentFilter.copyWith(
        sort: selected,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(productFilterProvider);
    final categories = ref.watch(customerCategoriesProvider).value ?? const [];
    final shops = ref.watch(customerShopsProvider).value ?? const [];
    final productsState = ref.watch(catalogProductsProvider);
    final compareList = ref.watch(productComparisonProvider);
    final selectedCategory = categories
        .where((c) => c.id == filter.categoryId)
        .firstOrNull;
    final departmentId = selectedCategory?.parentId ?? selectedCategory?.id;
    final departments = categories.where((c) => c.parentId == null).toList();
    final children = categories
        .where((c) => c.parentId == departmentId && departmentId != null)
        .toList();

    final quickOptions = <AppQuickFilterOption>[
      AppQuickFilterOption(
        id: 'in_stock',
        label: 'متوفر فقط',
        icon: AppIcons.checkCircle,
        selected: filter.inStockOnly,
        onTap: () {
          ref.read(productFilterProvider.notifier).state = filter.copyWith(
            inStockOnly: !filter.inStockOnly,
          );
        },
      ),
      if (categories.isNotEmpty) ...[
        AppQuickFilterOption(
          id: 'all_categories',
          label: 'الكل',
          selected: filter.categoryId == null,
          onTap: () {
            ref.read(productFilterProvider.notifier).state = filter.copyWith(
              clearCategory: true,
            );
          },
        ),
        for (final cat in departments)
          AppQuickFilterOption(
            id: 'cat_${cat.id}',
            label: cat.name,
            selected: departmentId == cat.id,
            onTap: () {
              final selected = departmentId == cat.id;
              ref.read(productFilterProvider.notifier).state = selected
                  ? filter.copyWith(clearCategory: true)
                  : filter.copyWith(categoryId: cat.id);
            },
          ),
      ],
    ];

    final activeTags = buildCustomerProductActiveTags(
      filter: filter,
      categories: categories,
      shops: shops,
      includeCategoryTag: true,
      includeShopTag: true,
      onChanged: (next) =>
          ref.read(productFilterProvider.notifier).state = next,
    );

    return CustomerScaffold(
      title: 'المنتجات'.tr,
      currentNavIndex: 1,
      showBack: false,
      body: Column(
        children: [
          if (children.isNotEmpty)
            Padding(
              padding: AppSpacing.pageHorizontal,
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text('عرض الكل'.tr),
                        selected: filter.categoryId == departmentId,
                        onSelected: (_) =>
                            ref.read(productFilterProvider.notifier).state =
                                filter.copyWith(categoryId: departmentId),
                      ),
                    ),
                    for (final child in children)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: Text(child.name.tr),
                          selected: filter.categoryId == child.id,
                          onSelected: (_) =>
                              ref.read(productFilterProvider.notifier).state =
                                  filter.copyWith(categoryId: child.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: CatalogDesign.toolbarBackground,
              border: Border(
                bottom: BorderSide(color: CatalogDesign.toolbarBorder),
              ),
            ),
            child: AppFilterToolbar(
              searchValue: filter.search ?? '',
              searchHint: 'بحث في الكتالوج، الماركة، اللون...',
              onSearchChanged: (value) {
                ref.read(productFilterProvider.notifier).state = value.isEmpty
                    ? filter.copyWith(clearSearch: true)
                    : filter.copyWith(search: value);
              },
              quickOptions: quickOptions,
              activeTags: activeTags,
              activeFacetCount: filter.activeFacetCount,
              onOpenAdvancedFilter: _openFilterBottomSheet,
              sortLabel: filter.sort.labelAr,
              isDefaultSort: filter.sort == ProductSortOption.newest,
              onOpenSort: _openSortSheet,
              totalCount:
                  productsState.totalCount ??
                  (productsState.hasMore ? null : productsState.items.length),
              filteredCount: productsState.isInitialLoading
                  ? null
                  : productsState.items.length,
              hasActiveCustomization: filter.hasActiveFilters,
              onClearAll: () => ref.read(productFilterProvider.notifier).state =
                  ProductFilter.empty,
              showCountWhenUnfiltered:
                  !productsState.isInitialLoading &&
                  (productsState.totalCount != null || !productsState.hasMore),
            ),
          ),

          // Products Grid
          Expanded(
            child: productsState.skeletonWhen(
              placeholder: LoadingFixtures.products,
              data: (products) {
                Future<void> handleRefresh() => Future.wait([
                  ref.refresh(customerCategoriesProvider.future),
                  ref.refresh(customerShopsProvider.future),
                  ref.read(catalogProductsProvider.notifier).refresh(),
                ]);

                if (products.isEmpty && !productsState.isInitialLoading) {
                  if (filter.hasActiveFilters) {
                    return AppRefreshIndicator(
                      onRefresh: handleRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.page,
                        children: [
                          AppFilterEmptyState(
                            onReset: () =>
                                ref.read(productFilterProvider.notifier).state =
                                    ProductFilter.empty,
                          ),
                          if (productsState.hasMore)
                            AppLoadMoreFooter(
                              isLoadingMore: productsState.isLoadingMore,
                              hasMore: productsState.hasMore,
                              itemsCount: products.length,
                              loadMoreError: productsState.loadMoreError,
                              onLoadMore: ref
                                  .read(catalogProductsProvider.notifier)
                                  .loadMore,
                              useProductGridSkeleton: true,
                            ),
                        ],
                      ),
                    );
                  }
                  return AppRefreshIndicator(
                    onRefresh: handleRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: AppEmpty(
                            icon: AppIcons.searchOff,
                            title: 'لا توجد منتجات منشورة حالياً'.tr,
                            message: 'يرجى المحاولة لاحقاً.'.tr,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final showFooter = !productsState.isInitialLoading;
                return AppRefreshIndicator(
                  onRefresh: handleRefresh,
                  child: AppPaginationScrollListener(
                    hasMore: productsState.hasMore,
                    isLoadingMore: productsState.isLoadingMore,
                    onLoadMore: ref
                        .read(catalogProductsProvider.notifier)
                        .loadMore,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          sliver: SliverGrid(
                            gridDelegate: ProductGridDelegate(
                              textScale:
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14,
                            ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = products[index];
                              return ProductGridCard(
                                imageUrl: product.coverImage,
                                meta: AppFormat.price(product.price),
                                inStock: product.totalStock > 0,
                                isFavorite: product.isFavorite,
                                onToggleFavorite: () =>
                                    _toggleFavorite(product),
                                onAddToCart: () =>
                                    showProductCartSheet(context, product.id),
                                onTap: () => context.push(
                                  AppRoutes.customerProductDetailsPath(
                                    product.id,
                                  ),
                                ),
                              );
                            }, childCount: products.length),
                          ),
                        ),
                        if (showFooter)
                          SliverToBoxAdapter(
                            child: AppLoadMoreFooter(
                              isLoadingMore: productsState.isLoadingMore,
                              hasMore: productsState.hasMore,
                              itemsCount: products.length,
                              loadMoreError: productsState.loadMoreError,
                              onLoadMore: ref
                                  .read(catalogProductsProvider.notifier)
                                  .loadMore,
                              useProductGridSkeleton: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              error: (err) => AppEmpty(
                icon: AppIcons.error,
                message: 'تعذر تحميل المنتجات: $err'.tr,
                actionLabel: 'إعادة المحاولة'.tr,
                onAction: ref.read(catalogProductsProvider.notifier).refresh,
              ),
            ),
          ),

          // Quick Compare Bottom Banner
          if (compareList.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                border: Border(top: BorderSide(color: AppColors.primaryBorder)),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.compare, color: AppColors.icon),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'تم تحديد ${compareList.length} منتجات للمقارنة'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: AppHaptics.action(
                      () => context.push(AppRoutes.customerCompare),
                    ),
                    child: Text(
                      'فتح المقارنة'.tr,
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: AppFont.extraBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
