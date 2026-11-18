import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../domain/models/catalog_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  static const _sortChoices = [
    AppSortChoice(
      value: ProductSortOption.newest,
      label: 'الأحدث',
      icon: AppIcons.sparkles,
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

  Future<void> _openFilterSheet(List<AdminProduct> items) async {
    var draft = ref.read(adminProductFilterProvider);
    final shops = extractDistinctValues(items.map((p) => p.shopName));
    final categories = extractDistinctValues(items.map((p) => p.categoryName));
    final minCtrl = TextEditingController(
      text: draft.minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: draft.maxPrice?.toStringAsFixed(0) ?? '',
    );

    final updated = await AppBottomSheet.show<AdminProductFilterState>(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          AdminProductFilterState resolved() {
            return AdminProductFilterState(
              search: draft.search,
              status: draft.status,
              shopName: draft.shopName,
              categoryName: draft.categoryName,
              minPrice: double.tryParse(minCtrl.text.trim()),
              maxPrice: double.tryParse(maxCtrl.text.trim()),
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
                () => draft = AdminProductFilterState(search: draft.search),
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
              if (shops.isNotEmpty)
                AppFilterSection(
                  title: 'المتجر',
                  child: AppFilterChoiceWrap<String>(
                    options: shops,
                    selectedValue: draft.shopName,
                    allLabel: 'الكل',
                    labelBuilder: (s) => s,
                    onSelected: (s) => setModalState(
                      () => draft = s == null
                          ? draft.copyWith(clearShopName: true)
                          : draft.copyWith(shopName: s),
                    ),
                  ),
                ),
              if (categories.isNotEmpty)
                AppFilterSection(
                  title: 'التصنيف',
                  child: AppFilterChoiceWrap<String>(
                    options: categories,
                    selectedValue: draft.categoryName,
                    allLabel: 'الكل',
                    labelBuilder: (c) => c,
                    onSelected: (c) => setModalState(
                      () => draft = c == null
                          ? draft.copyWith(clearCategoryName: true)
                          : draft.copyWith(categoryName: c),
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
                    draft = AdminProductFilterState(
                      search: draft.search,
                      status: draft.status,
                      shopName: draft.shopName,
                      categoryName: draft.categoryName,
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
      ref.read(adminProductFilterProvider.notifier).state = updated;
    }
  }

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    AdminProduct product,
  ) async {
    final action = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: product.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المحل: ${product.shopName ?? '-'}\nالتصنيف: ${product.categoryName ?? '-'}\nالحالة: ${product.statusLabel}'.tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (product.status != 'hidden')
              AppButton(
                label: 'إخفاء المنتج'.tr,
                onPressed: () => Navigator.of(context).pop('hidden'),
              ),
            if (product.status == 'hidden') ...[
              AppButton(
                label: 'إعادة النشر'.tr,
                onPressed: () => Navigator.of(context).pop('published'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else
              const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'حذف المنتج'.tr,
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop('deleted'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.setProductStatus(
      productId: product.id,
      status: action,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر تحديث المنتج'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث حالة المنتج'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminProductFilterProvider);
    final productsState = ref.watch(adminProductsPaginatedProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'المنتجات'.tr,
      body: productsState.skeletonWhen(
        placeholder: LoadingFixtures.adminProducts,
        error: (err) => AppEmpty(
          icon: AppIcons.error,
          message: 'تعذر تحميل المنتجات: $err'.tr,
          actionLabel: 'إعادة المحاولة'.tr,
          onAction: ref.read(adminProductsPaginatedProvider.notifier).refresh,
        ),
        data: (items) {
          if (items.isEmpty &&
              !productsState.isInitialLoading &&
              !filter.hasActiveFilters &&
              !productsState.hasMore) {
            return AppRefreshIndicator(
              onRefresh: ref
                  .read(adminProductsPaginatedProvider.notifier)
                  .refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: [AppEmpty(message: 'لا توجد منتجات بعد'.tr)],
              ),
            );
          }

          final statusCounts = <String, int>{};
          for (final item in items) {
            statusCounts[item.status] = (statusCounts[item.status] ?? 0) + 1;
          }
          final showCounts =
              !productsState.isInitialLoading && !productsState.hasMore;

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: filter.search,
                searchHint: 'ابحث باسم المنتج، المتجر، التصنيف...',
                onSearchChanged: (val) {
                  ref.read(adminProductFilterProvider.notifier).state = filter
                      .copyWith(search: val);
                },
                sortLabel: filter.sort.labelAr,
                isDefaultSort: filter.sort == ProductSortOption.newest,
                onOpenSort: () async {
                  final selected = await showAppSortSheet<ProductSortOption>(
                    context: context,
                    current: filter.sort,
                    options: _sortChoices,
                  );
                  if (selected != null && mounted) {
                    ref.read(adminProductFilterProvider.notifier).state = filter
                        .copyWith(sort: selected);
                  }
                },
                onOpenAdvancedFilter: () => _openFilterSheet(items),
                activeFacetCount: filter.activeFacetCount,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'admin_prod_all',
                    label: 'الكل',
                    count: showCounts ? items.length : null,
                    selected: filter.status == null,
                    onTap: () {
                      ref.read(adminProductFilterProvider.notifier).state =
                          filter.copyWith(clearStatus: true);
                    },
                  ),
                  for (final st in const ['published', 'draft', 'hidden'])
                    AppQuickFilterOption(
                      id: 'admin_prod_$st',
                      label: _statusLabel(st),
                      count: showCounts ? (statusCounts[st] ?? 0) : null,
                      selected: filter.status == st,
                      onTap: () {
                        final same = filter.status == st;
                        ref.read(adminProductFilterProvider.notifier).state =
                            same
                            ? filter.copyWith(clearStatus: true)
                            : filter.copyWith(status: st);
                      },
                    ),
                ],
                activeTags: [
                  if (filter.shopName != null)
                    AppActiveFilterTag(
                      label: 'المتجر: ${filter.shopName!}'.tr,
                      onRemove: () {
                        ref.read(adminProductFilterProvider.notifier).state =
                            filter.copyWith(clearShopName: true);
                      },
                    ),
                  if (filter.categoryName != null)
                    AppActiveFilterTag(
                      label: 'التصنيف: ${filter.categoryName!}'.tr,
                      onRemove: () {
                        ref.read(adminProductFilterProvider.notifier).state =
                            filter.copyWith(clearCategoryName: true);
                      },
                    ),
                  if (filter.minPrice != null || filter.maxPrice != null)
                    AppActiveFilterTag(
                      label:
                          filter.minPrice != null && filter.maxPrice != null
                          ? 'السعر: من ${filter.minPrice!.toStringAsFixed(0)} إلى ${filter.maxPrice!.toStringAsFixed(0)}'
                                .tr
                          : filter.minPrice != null
                          ? 'السعر: من ${filter.minPrice!.toStringAsFixed(0)}'
                                .tr
                          : 'السعر: حتى ${filter.maxPrice!.toStringAsFixed(0)}'
                                .tr,
                      onRemove: () {
                        ref.read(adminProductFilterProvider.notifier).state =
                            filter.copyWith(clearPriceRange: true);
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
                showingSimilarFallback: productsState.isSimilarFallback,
                onClearAll: () =>
                    ref.read(adminProductFilterProvider.notifier).state =
                        AdminProductFilterState.empty,
                showCountWhenUnfiltered:
                    !productsState.isInitialLoading &&
                    (productsState.totalCount != null ||
                        !productsState.hasMore),
              ),
              Expanded(
                child: items.isEmpty && !productsState.isInitialLoading
                    ? AppRefreshIndicator(
                        onRefresh: ref
                            .read(adminProductsPaginatedProvider.notifier)
                            .refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          children: [
                            AppFilterEmptyState(
                              onReset: () =>
                                  ref
                                          .read(
                                            adminProductFilterProvider.notifier,
                                          )
                                          .state =
                                      AdminProductFilterState.empty,
                            ),
                            if (productsState.hasMore)
                              AppLoadMoreFooter(
                                isLoadingMore: productsState.isLoadingMore,
                                hasMore: productsState.hasMore,
                                itemsCount: items.length,
                                loadMoreError: productsState.loadMoreError,
                                onLoadMore: ref
                                    .read(
                                      adminProductsPaginatedProvider.notifier,
                                    )
                                    .loadMore,
                              ),
                          ],
                        ),
                      )
                    : AppRefreshIndicator(
                        onRefresh: ref
                            .read(adminProductsPaginatedProvider.notifier)
                            .refresh,
                        child: AppPaginationScrollListener(
                          hasMore: productsState.hasMore,
                          isLoadingMore: productsState.isLoadingMore,
                          onLoadMore: ref
                              .read(adminProductsPaginatedProvider.notifier)
                              .loadMore,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppSpacing.page,
                            itemCount:
                                items.length +
                                (productsState.isInitialLoading ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (index >= items.length) {
                                return AppLoadMoreFooter(
                                  isLoadingMore: productsState.isLoadingMore,
                                  hasMore: productsState.hasMore,
                                  itemsCount: items.length,
                                  loadMoreError: productsState.loadMoreError,
                                  onLoadMore: ref
                                      .read(
                                        adminProductsPaginatedProvider.notifier,
                                      )
                                      .loadMore,
                                );
                              }
                              final item = items[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: AppCard(
                                  onTap: busy
                                      ? null
                                      : () => _manage(context, ref, item),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        '${item.shopName ?? '-'} · ${item.statusLabel.tr}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        AppFormat.price(item.price),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
