import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopProductsScreen extends ConsumerStatefulWidget {
  const ShopProductsScreen({super.key});

  @override
  ConsumerState<ShopProductsScreen> createState() => _ShopProductsScreenState();
}

class _ShopProductsScreenState extends ConsumerState<ShopProductsScreen> {
  static const _sortChoices = [
    AppSortChoice(
      value: ProductSortOption.newest,
      label: 'الأحدث',
      icon: AppIcons.sparkles,
    ),
    AppSortChoice(
      value: ProductSortOption.stockAsc,
      label: 'الأقل مخزوناً',
      icon: AppIcons.error,
    ),
    AppSortChoice(
      value: ProductSortOption.stockDesc,
      label: 'الأكثر توفراً',
      icon: AppIcons.checkCircle,
    ),
    AppSortChoice(
      value: ProductSortOption.priceAsc,
      label: 'السعر: الأقل أولاً',
      icon: AppIcons.arrowUp,
    ),
    AppSortChoice(
      value: ProductSortOption.priceDesc,
      label: 'السعر: الأعلى أولاً',
      icon: AppIcons.arrowDown,
    ),
    AppSortChoice(
      value: ProductSortOption.nameAsc,
      label: 'الاسم: أ - ي',
      icon: AppIcons.catalog,
    ),
  ];

  static String _statusLabel(String status) {
    return switch (status) {
      'published' => 'منشور',
      'draft' => 'مسودة',
      'hidden' => 'مخفي',
      _ => status,
    };
  }

  Future<void> _openFilterSheet(List<ShopProduct> items) async {
    var draft = ref.read(shopProductFilterProvider);
    final shopCategories = ref.read(shopCategoriesProvider).value ?? const [];
    final categories = <String, String>{
      for (final cat in shopCategories) cat.id: cat.name,
    };
    for (final item in items) {
      if (item.categoryId != null &&
          item.categoryId!.isNotEmpty &&
          item.categoryName != null &&
          item.categoryName!.isNotEmpty) {
        categories[item.categoryId!] = item.categoryName!;
      }
    }
    final minCtrl = TextEditingController(
      text: draft.minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: draft.maxPrice?.toStringAsFixed(0) ?? '',
    );

    final updated = await AppBottomSheet.show<ShopProductFilterState>(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          ShopProductFilterState resolved() {
            final minP = double.tryParse(minCtrl.text.trim());
            final maxP = double.tryParse(maxCtrl.text.trim());
            return ShopProductFilterState(
              search: draft.search,
              status: draft.status,
              categoryId: draft.categoryId,
              stockFilter: draft.stockFilter,
              minPrice: minP,
              maxPrice: maxP,
              sort: draft.sort,
            );
          }

          final current = resolved();
          return AppFilterSheetScaffold(
            title: 'تصفية المنتجات',
            activeCount: current.activeFacetCount,
            onReset: () {
              minCtrl.clear();
              maxCtrl.clear();
              setModalState(
                () => draft = ShopProductFilterState(search: draft.search),
              );
            },
            onApply: () => Navigator.of(ctx).pop(resolved()),
            children: [
              AppFilterSection(
                title: 'ترتيب النتائج',
                child: AppFilterChoiceWrap<ProductSortOption>(
                  options: _sortChoices.map((e) => e.value).toList(),
                  selectedValue: draft.sort,
                  allowDeselect: false,
                  labelBuilder: (s) => s.labelAr,
                  onSelected: (s) {
                    if (s != null) {
                      setModalState(() => draft = draft.copyWith(sort: s));
                    }
                  },
                ),
              ),
              AppFilterSection(
                title: 'الحالة',
                child: AppFilterChoiceWrap<String>(
                  options: const ['published', 'draft', 'hidden'],
                  selectedValue: draft.status,
                  allLabel: 'الكل',
                  labelBuilder: _statusLabel,
                  onSelected: (st) => setModalState(
                    () => draft = st == null
                        ? draft.copyWith(clearStatus: true)
                        : draft.copyWith(status: st),
                  ),
                ),
              ),
              AppFilterSection(
                title: 'حالة المخزون',
                child: AppFilterChoiceWrap<StockFilter>(
                  options: StockFilter.values,
                  selectedValue: draft.stockFilter,
                  allowDeselect: false,
                  labelBuilder: (sf) => sf.labelAr,
                  onSelected: (sf) {
                    if (sf != null) {
                      setModalState(
                        () => draft = draft.copyWith(stockFilter: sf),
                      );
                    }
                  },
                ),
              ),
              if (categories.isNotEmpty)
                AppFilterSection(
                  title: 'التصنيف',
                  child: AppFilterChoiceWrap<String>(
                    options: categories.keys.toList(),
                    selectedValue: draft.categoryId,
                    allLabel: 'الكل',
                    labelBuilder: (id) => categories[id] ?? id,
                    onSelected: (id) => setModalState(
                      () => draft = id == null
                          ? draft.copyWith(clearCategory: true)
                          : draft.copyWith(categoryId: id),
                    ),
                  ),
                ),
              AppFilterSection(
                title: 'نطاق السعر',
                child: AppFilterRangeInputs(
                  minController: minCtrl,
                  maxController: maxCtrl,
                  presets: const [
                    ('أقل من 150', null, 150),
                    ('150 - 350', 150, 350),
                    ('أكثر من 350', 350, null),
                  ],
                  onPresetSelected: (min, max) => setModalState(() {
                    draft = ShopProductFilterState(
                      search: draft.search,
                      status: draft.status,
                      categoryId: draft.categoryId,
                      stockFilter: draft.stockFilter,
                      minPrice: min,
                      maxPrice: max,
                      sort: draft.sort,
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
    minCtrl.dispose();
    maxCtrl.dispose();
    if (updated != null && mounted) {
      ref.read(shopProductFilterProvider.notifier).state = updated;
    }
  }

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    ShopProduct product,
  ) async {
    final action = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: product.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الحالة: ${product.statusLabel}\nالمخزون: ${product.totalStock}'.tr,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'تعديل'.tr,
              onPressed: () => Navigator.of(context).pop('edit'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (product.status != 'published')
              AppButton(
                label: 'نشر'.tr,
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop('published'),
              ),
            if (product.status == 'published')
              AppButton(
                label: 'إيقاف النشر'.tr,
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop('hidden'),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'حذف'.tr,
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop('deleted'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'edit') {
      if (context.mounted) {
        context.push(AppRoutes.shopProductEditPath(product.id));
      }
      return;
    }

    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.setProductStatus(
      productId: product.id,
      status: action,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر التحديث'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث المنتج'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(myShopProvider);
    final shop = shopState.asData?.value;
    final awaitingShop = shopState.isLoading && !shopState.hasValue;
    final filter = ref.watch(shopProductFilterProvider);
    final productsState = awaitingShop
        ? const PaginatedListState<ShopProduct>(isInitialLoading: true)
        : ref.watch(shopProductsPaginatedProvider);
    final shopCategories = ref.watch(shopCategoriesProvider).value ?? const [];
    final busy = ref.watch(shopCatalogActionProvider).isLoading;
    final approved = shop?.visibleStatus == ShopStatus.approved;

    return ShopScaffold(
      title: 'المنتجات'.tr,
      showBack: false,
      body: !approved && !awaitingShop
          ? ListView(
              padding: AppSpacing.page,
              children: [
                AppCard(
                  child: Text(
                    'لا يمكن إدارة المنتجات قبل موافقة الإدارة على المحل.'.tr,
                  ),
                ),
              ],
            )
          : productsState.skeletonWhen(
              placeholder: LoadingFixtures.shopProducts,
              error: (error) => ListView(
                padding: AppSpacing.page,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          ref.read(shopCatalogRepositoryProvider).mapError(error),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'إعادة المحاولة'.tr,
                          onPressed: ref
                              .read(shopProductsPaginatedProvider.notifier)
                              .refresh,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty &&
                    !productsState.isInitialLoading &&
                    !filter.hasActiveFilters &&
                    !productsState.hasMore) {
                  return AppRefreshIndicator(
                    onRefresh: ref
                        .read(shopProductsPaginatedProvider.notifier)
                        .refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.page,
                      children: [
                        AppCard(child: Text('لا توجد منتجات بعد'.tr)),
                      ],
                    ),
                  );
                }

                final statusCounts = <String, int>{};
                var lowStockCount = 0;
                var outOfStockCount = 0;
                for (final item in items) {
                  statusCounts[item.status] =
                      (statusCounts[item.status] ?? 0) + 1;
                  if (item.totalStock <= 0) {
                    outOfStockCount++;
                  } else if (item.totalStock <= 5) {
                    lowStockCount++;
                  }
                }
                final showCounts =
                    !productsState.isInitialLoading && !productsState.hasMore;
                final categoryName = filter.categoryId == null
                    ? null
                    : shopCategories
                              .where((c) => c.id == filter.categoryId)
                              .map((c) => c.name)
                              .firstOrNull ??
                          items
                              .where((i) => i.categoryId == filter.categoryId)
                              .map((i) => i.categoryName)
                              .firstOrNull ??
                          filter.categoryId!;

                return Column(
                  children: [
                    AppFilterToolbar(
                      searchValue: filter.search,
                      searchHint: 'ابحث باسم المنتج، المتجر، اللون...',
                      onSearchChanged: (val) {
                        ref.read(shopProductFilterProvider.notifier).state =
                            filter.copyWith(search: val);
                      },
                      sortLabel: filter.sort.labelAr,
                      isDefaultSort: filter.sort == ProductSortOption.newest,
                      onOpenSort: () async {
                        final selected =
                            await showAppSortSheet<ProductSortOption>(
                              context: context,
                              current: filter.sort,
                              options: _sortChoices,
                            );
                        if (selected != null && mounted) {
                          ref.read(shopProductFilterProvider.notifier).state =
                              filter.copyWith(sort: selected);
                        }
                      },
                      onOpenAdvancedFilter: () => _openFilterSheet(items),
                      activeFacetCount: filter.activeFacetCount,
                      quickOptions: [
                        AppQuickFilterOption(
                          id: 'shop_prod_all',
                          label: 'الكل',
                          count: showCounts ? items.length : null,
                          selected:
                              filter.status == null &&
                              filter.stockFilter == StockFilter.all,
                          onTap: () {
                            ref.read(shopProductFilterProvider.notifier).state =
                                filter.copyWith(
                                  clearStatus: true,
                                  stockFilter: StockFilter.all,
                                );
                          },
                        ),
                        for (final st in const ['published', 'draft', 'hidden'])
                          AppQuickFilterOption(
                            id: 'shop_prod_$st',
                            label: _statusLabel(st),
                            count: showCounts ? (statusCounts[st] ?? 0) : null,
                            selected: filter.status == st,
                            onTap: () {
                              final same = filter.status == st;
                              ref
                                  .read(shopProductFilterProvider.notifier)
                                  .state = same
                                  ? filter.copyWith(clearStatus: true)
                                  : filter.copyWith(status: st);
                            },
                          ),
                        AppQuickFilterOption(
                          id: 'shop_stock_low',
                          label: StockFilter.lowStock.labelAr,
                          count: showCounts ? lowStockCount : null,
                          selected: filter.stockFilter == StockFilter.lowStock,
                          onTap: () {
                            final same =
                                filter.stockFilter == StockFilter.lowStock;
                            ref.read(shopProductFilterProvider.notifier).state =
                                filter.copyWith(
                                  stockFilter: same
                                      ? StockFilter.all
                                      : StockFilter.lowStock,
                                );
                          },
                        ),
                        AppQuickFilterOption(
                          id: 'shop_stock_out',
                          label: StockFilter.outOfStock.labelAr,
                          count: showCounts ? outOfStockCount : null,
                          selected:
                              filter.stockFilter == StockFilter.outOfStock,
                          onTap: () {
                            final same =
                                filter.stockFilter == StockFilter.outOfStock;
                            ref.read(shopProductFilterProvider.notifier).state =
                                filter.copyWith(
                                  stockFilter: same
                                      ? StockFilter.all
                                      : StockFilter.outOfStock,
                                );
                          },
                        ),
                      ],
                      activeTags: [
                        if (categoryName != null)
                          AppActiveFilterTag(
                            label: 'التصنيف: $categoryName'.tr,
                            onRemove: () {
                              ref
                                  .read(shopProductFilterProvider.notifier)
                                  .state = filter.copyWith(
                                clearCategory: true,
                              );
                            },
                          ),
                        if (filter.stockFilter != StockFilter.all)
                          AppActiveFilterTag(
                            label: filter.stockFilter.labelAr.tr,
                            onRemove: () {
                              ref
                                  .read(shopProductFilterProvider.notifier)
                                  .state = filter.copyWith(
                                stockFilter: StockFilter.all,
                              );
                            },
                          ),
                        if (filter.minPrice != null || filter.maxPrice != null)
                          AppActiveFilterTag(
                            label:
                                filter.minPrice != null &&
                                    filter.maxPrice != null
                                ? 'السعر: من ${filter.minPrice!.toStringAsFixed(0)} إلى ${filter.maxPrice!.toStringAsFixed(0)}'
                                      .tr
                                : filter.minPrice != null
                                ? 'السعر: من ${filter.minPrice!.toStringAsFixed(0)}'
                                      .tr
                                : 'السعر: حتى ${filter.maxPrice!.toStringAsFixed(0)}'
                                      .tr,
                            onRemove: () {
                              ref
                                  .read(shopProductFilterProvider.notifier)
                                  .state = filter.copyWith(
                                clearPriceRange: true,
                              );
                            },
                          ),
                      ],
                      totalCount:
                          productsState.totalCount ??
                          (productsState.hasMore ? null : items.length),
                      filteredCount: productsState.isInitialLoading
                          ? null
                          : items.length,
                      hasActiveCustomization: filter.hasActiveFilters,
                      onClearAll: () =>
                          ref.read(shopProductFilterProvider.notifier).state =
                              ShopProductFilterState.empty,
                      showCountWhenUnfiltered:
                          !productsState.isInitialLoading &&
                          (productsState.totalCount != null ||
                              !productsState.hasMore),
                    ),
                    Expanded(
                      child: items.isEmpty && !productsState.isInitialLoading
                          ? AppRefreshIndicator(
                              onRefresh: ref
                                  .read(shopProductsPaginatedProvider.notifier)
                                  .refresh,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: AppSpacing.page,
                                children: [
                                  AppFilterEmptyState(
                                    onReset: () =>
                                        ref
                                            .read(
                                              shopProductFilterProvider
                                                  .notifier,
                                            )
                                            .state = ShopProductFilterState.empty,
                                  ),
                                  if (productsState.hasMore)
                                    AppLoadMoreFooter(
                                      isLoadingMore:
                                          productsState.isLoadingMore,
                                      hasMore: productsState.hasMore,
                                      itemsCount: items.length,
                                      loadMoreError:
                                          productsState.loadMoreError,
                                      onLoadMore: ref
                                          .read(
                                            shopProductsPaginatedProvider
                                                .notifier,
                                          )
                                          .loadMore,
                                      useProductGridSkeleton: true,
                                    ),
                                ],
                              ),
                            )
                          : AppRefreshIndicator(
                              onRefresh: ref
                                  .read(shopProductsPaginatedProvider.notifier)
                                  .refresh,
                              child: AppPaginationScrollListener(
                                hasMore: productsState.hasMore,
                                isLoadingMore: productsState.isLoadingMore,
                                onLoadMore: ref
                                    .read(
                                      shopProductsPaginatedProvider.notifier,
                                    )
                                    .loadMore,
                                child: CustomScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    SliverPadding(
                                      padding: AppSpacing.page,
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
                                          final item = items[index];
                                          return ProductGridCard(
                                            imageUrl: item.coverImage,
                                            meta: AppFormat.price(item.price),
                                            inStock: item.totalStock > 0,
                                            showFavorite: false,
                                            onTap: busy
                                                ? null
                                                : () => _manage(
                                                    context,
                                                    ref,
                                                    item,
                                                  ),
                                          );
                                        }, childCount: items.length),
                                      ),
                                    ),
                                    if (!productsState.isInitialLoading)
                                      SliverToBoxAdapter(
                                        child: AppLoadMoreFooter(
                                          isLoadingMore:
                                              productsState.isLoadingMore,
                                          hasMore: productsState.hasMore,
                                          itemsCount: items.length,
                                          loadMoreError:
                                              productsState.loadMoreError,
                                          onLoadMore: ref
                                              .read(
                                                shopProductsPaginatedProvider
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
                    ),
                  ],
                );
              },
            ),
      bottom: approved
          ? AppButton(
              label: 'إضافة منتج'.tr,
              isLoading: busy,
              onPressed: () => context.push(AppRoutes.shopProductForm),
            )
          : null,
    );
  }
}
