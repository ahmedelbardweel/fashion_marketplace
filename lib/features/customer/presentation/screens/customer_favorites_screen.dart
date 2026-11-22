import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/network_guard.dart';
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

class CustomerFavoritesScreen extends ConsumerStatefulWidget {
  const CustomerFavoritesScreen({super.key});

  @override
  ConsumerState<CustomerFavoritesScreen> createState() =>
      _CustomerFavoritesScreenState();
}

class _CustomerFavoritesScreenState
    extends ConsumerState<CustomerFavoritesScreen> {
  ProductFilter _filter = ProductFilter.empty;

  Future<void> _toggleFavorite(CustomerProduct product) async {
    syncFavoriteAcrossProductLists(ref, product, false);
    try {
      await ref.read(customerRepositoryProvider).toggleFavorite(product.id);
      ref.invalidate(customerProductDetailsProvider(product.id));
    } catch (_) {
      syncFavoriteAcrossProductLists(ref, product, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(customerFavoritesPaginatedProvider);
    final categories = ref.watch(customerCategoriesProvider).value ?? const [];
    final shops = ref.watch(customerShopsProvider).value ?? const [];

    return CustomerScaffold(
      title: 'المفضلة'.tr,
      currentNavIndex: 2,
      showBack: false,
      body: AppRefreshIndicator(
        onRefresh: () =>
            ref.read(customerFavoritesPaginatedProvider.notifier).refresh(),
        child: favoritesState.skeletonWhen(
          placeholder: LoadingFixtures.products,
          data: (favorites) {
            if (favorites.isEmpty && !favoritesState.isInitialLoading) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: AppEmpty(
                      icon: FavoritesDesign.emptyIcon,
                      title: 'قائمة المفضلة فارغة'.tr,
                      message:
                          'احفظ الأزياء التي تنال إعجابك للرجوع إليها في أي وقت'
                              .tr,
                      actionLabel: 'تصفح الأزياء الآن'.tr,
                      onAction: AppHaptics.action(
                        () => context.go(AppRoutes.customerCatalog),
                      ),
                    ),
                  ),
                ],
              );
            }

            final exactFiltered = applyCustomerProductFilter(
              favorites,
              _filter,
            );
            final isSimilarFallback =
                exactFiltered.isEmpty &&
                _filter.hasActiveFilters &&
                favorites.isNotEmpty;
            final filtered = isSimilarFallback
                ? computeSimilarCustomerProducts(favorites, _filter)
                : exactFiltered;
            final catIds = favorites
                .map((p) => p.categoryId)
                .whereType<String>()
                .toSet();
            final favCategories = categories
                .where((c) => catIds.contains(c.id))
                .toList();
            final shopIds = favorites.map((p) => p.shopId).toSet();
            final favShops = shops
                .where((s) => shopIds.contains(s.id))
                .toList();

            return Column(
              children: [
                AppFilterToolbar(
                  searchValue: _filter.search ?? '',
                  searchHint: 'ابحث في المفضلة، المتجر، اللون...',
                  onSearchChanged: (val) => setState(() {
                    _filter = val.isEmpty
                        ? _filter.copyWith(clearSearch: true)
                        : _filter.copyWith(search: val);
                  }),
                  quickOptions: [
                    AppQuickFilterOption(
                      id: 'fav_in_stock',
                      label: 'متوفر فقط',
                      icon: AppIcons.checkCircle,
                      selected: _filter.inStockOnly,
                      onTap: () => setState(() {
                        _filter = _filter.copyWith(
                          inStockOnly: !_filter.inStockOnly,
                        );
                      }),
                    ),
                    if (favCategories.isNotEmpty) ...[
                      AppQuickFilterOption(
                        id: 'fav_cat_all',
                        label: 'الكل',
                        selected: _filter.categoryId == null,
                        onTap: () => setState(() {
                          _filter = _filter.copyWith(clearCategory: true);
                        }),
                      ),
                      for (final cat in favCategories)
                        AppQuickFilterOption(
                          id: 'fav_cat_${cat.id}',
                          label: cat.name,
                          selected: _filter.categoryId == cat.id,
                          onTap: () => setState(() {
                            final same = _filter.categoryId == cat.id;
                            _filter = same
                                ? _filter.copyWith(clearCategory: true)
                                : _filter.copyWith(categoryId: cat.id);
                          }),
                        ),
                    ],
                  ],
                  activeTags: buildCustomerProductActiveTags(
                    filter: _filter,
                    categories: favCategories,
                    shops: favShops,
                    onChanged: (next) => setState(() => _filter = next),
                  ),
                  activeFacetCount: _filter.activeFacetCount,
                  sortLabel: _filter.sort.labelAr,
                  isDefaultSort: _filter.sort == ProductSortOption.newest,
                  onOpenSort: () async {
                    final selected = await showAppSortSheet<ProductSortOption>(
                      context: context,
                      current: _filter.sort,
                      options: kCustomerProductSortChoices,
                    );
                    if (selected != null && mounted) {
                      setState(
                        () => _filter = _filter.copyWith(sort: selected),
                      );
                    }
                  },
                  onOpenAdvancedFilter: () async {
                    final updated = await showCustomerProductFilterSheet(
                      context: context,
                      initial: _filter,
                      sourceProducts: favorites,
                      categories: favCategories,
                      shops: favShops,
                    );
                    if (updated != null && mounted) {
                      setState(() => _filter = updated);
                    }
                  },
                  totalCount:
                      favoritesState.totalCount ??
                      (favoritesState.hasMore ? null : favorites.length),
                  filteredCount: favoritesState.isInitialLoading
                      ? null
                      : filtered.length,
                  hasActiveCustomization: _filter.hasActiveFilters,
                  showingSimilarFallback: isSimilarFallback,
                  onClearAll: () =>
                      setState(() => _filter = ProductFilter.empty),
                  showCountWhenUnfiltered:
                      !favoritesState.isInitialLoading &&
                      (favoritesState.totalCount != null ||
                          !favoritesState.hasMore),
                ),
                Expanded(
                  child: filtered.isEmpty && !favoritesState.isInitialLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          children: [
                            AppFilterEmptyState(
                              onReset: () => setState(
                                () => _filter = ProductFilter.empty,
                              ),
                            ),
                            if (favoritesState.hasMore)
                              AppLoadMoreFooter(
                                isLoadingMore: favoritesState.isLoadingMore,
                                hasMore: favoritesState.hasMore,
                                itemsCount: filtered.length,
                                loadMoreError: favoritesState.loadMoreError,
                                onLoadMore: ref
                                    .read(
                                      customerFavoritesPaginatedProvider
                                          .notifier,
                                    )
                                    .loadMore,
                                useProductGridSkeleton: true,
                              ),
                          ],
                        )
                      : AppPaginationScrollListener(
                          hasMore: favoritesState.hasMore,
                          isLoadingMore: favoritesState.isLoadingMore,
                          onLoadMore: ref
                              .read(customerFavoritesPaginatedProvider.notifier)
                              .loadMore,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                sliver: SliverGrid(
                                  gridDelegate: ProductGridDelegate(
                                    textScale:
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(14) /
                                        14,
                                  ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final product = filtered[index];
                                    return ProductGridCard(
                                      imageUrl: product.coverImage,
                                      meta: AppFormat.price(product.price),
                                      originalMeta: product.hasOffer
                                          ? AppFormat.price(
                                              product.originalPrice!,
                                            )
                                          : null,
                                      discountPercent: product.hasOffer
                                          ? product.discountPercent
                                          : null,
                                      inStock: product.totalStock > 0,
                                      isFavorite: true,
                                      onToggleFavorite: () =>
                                          _toggleFavorite(product),
                                      onAddToCart: () => showProductCartSheet(
                                        context,
                                        product.id,
                                      ),
                                      onTap: () => context.push(
                                        AppRoutes.customerProductDetailsPath(
                                          product.id,
                                        ),
                                      ),
                                    );
                                  }, childCount: filtered.length),
                                ),
                              ),
                              if (!favoritesState.isInitialLoading)
                                SliverToBoxAdapter(
                                  child: AppLoadMoreFooter(
                                    isLoadingMore: favoritesState.isLoadingMore,
                                    hasMore: favoritesState.hasMore,
                                    itemsCount: filtered.length,
                                    loadMoreError: favoritesState.loadMoreError,
                                    onLoadMore: ref
                                        .read(
                                          customerFavoritesPaginatedProvider
                                              .notifier,
                                        )
                                        .loadMore,
                                    useProductGridSkeleton: true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
          error: (err) => AppEmpty(
            icon: AppIcons.error,
            message: AppErrorMapper.message(
              err,
              fallback: 'تعذر تحميل المفضلة حالياً. حاول مرة أخرى.',
            ),
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: ref
                .read(customerFavoritesPaginatedProvider.notifier)
                .refresh,
          ),
        ),
      ),
    );
  }
}
