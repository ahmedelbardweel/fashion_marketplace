import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/product_cart_sheet.dart';
import '../widgets/product_filter_sheet.dart';

class ShopPublicProfileScreen extends ConsumerStatefulWidget {
  const ShopPublicProfileScreen({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<ShopPublicProfileScreen> createState() =>
      _ShopPublicProfileScreenState();
}

class _ShopPublicProfileScreenState
    extends ConsumerState<ShopPublicProfileScreen> {
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

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    final shopAsync = ref.watch(customerShopDetailsProvider(shopId));
    final productsState = ref.watch(shopPublicProductsProvider(shopId));
    final filter = ref.watch(shopPublicProductFilterProvider(shopId));
    final categories = ref.watch(customerCategoriesProvider).value ?? const [];

    return shopAsync.skeletonWhen(
      placeholder: LoadingFixtures.customerShop,
      data: (shop) {
        if (shop == null) {
          return CustomerScaffold(
            title: 'المتجر'.tr,
            body: AppEmpty(
              icon: AppIcons.shop,
              message: 'المتجر غير موجود'.tr,
            ),
          );
        }

        final locationText = [
          shop.city,
          shop.address,
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

        return CustomerScaffold(
          title: shop.name,
          body: AppRefreshIndicator(
            onRefresh: () => Future.wait([
              ref.refresh(customerShopDetailsProvider(shopId).future),
              ref.read(shopPublicProductsProvider(shopId).notifier).refresh(),
            ]),
            child: AppPaginationScrollListener(
              hasMore: productsState.hasMore,
              isLoadingMore: productsState.isLoadingMore,
              onLoadMore: ref
                  .read(shopPublicProductsProvider(shopId).notifier)
                  .loadMore,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover + Overlapping Avatar Header
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: ShopProfileDesign.coverHeight,
                      width: double.infinity,
                      color: ShopProfileDesign.coverBackground,
                      child:
                          shop.coverPath != null && shop.coverPath!.isNotEmpty
                          ? AppNetworkImage(
                              shop.coverPath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  AppIcons.shopActive,
                                  size: 48,
                                  color: AppColors.icon,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                AppIcons.shopActive,
                                size: 48,
                                color: AppColors.icon,
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: -(ShopProfileDesign.logoSize / 2),
                      child: Container(
                        width: ShopProfileDesign.logoSize,
                        height: ShopProfileDesign.logoSize,
                        decoration: BoxDecoration(
                          color: ShopProfileDesign.logoBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ShopProfileDesign.logoBorder,
                            width: ShopProfileDesign.logoBorderWidth,
                          ),
                          boxShadow: AppShadows.soft,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child:
                            shop.logoPath != null && shop.logoPath!.isNotEmpty
                            ? AppNetworkImage(
                                shop.logoPath!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                AppIcons.shopActive,
                                size: 34,
                                color: AppColors.icon,
                              ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: (ShopProfileDesign.logoSize / 2) + 12),

                // Shop Info
                Padding(
                  padding: AppSpacing.pageHorizontal,
                  child: Column(
                    children: [
                      Text(
                        shop.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ShopProfileDesign.nameSize,
                          fontWeight: ShopProfileDesign.nameWeight,
                          color: AppColors.text,
                        ),
                      ),
                      if (locationText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.location,
                              size: 15,
                              color: AppColors.icon,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                locationText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ShopProfileDesign.metaColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (shop.description != null &&
                          shop.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          shop.description!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.lg),

                AppSectionHeader(title: 'تشكيلة المتجر'.tr),
                const SizedBox(height: AppSpacing.sm),

                // Products Grid
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!productsState.isInitialLoading &&
                          (productsState.items.isNotEmpty ||
                              filter.hasActiveFilters))
                        AppFilterToolbar(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          searchValue: filter.search ?? '',
                          searchHint:
                              'ابحث في تشكيلة المتجر، اللون، المقاس...',
                          onSearchChanged: (val) {
                            ref
                                .read(shopPublicProductFilterProvider(shopId)
                                    .notifier)
                                .state = val.isEmpty
                                ? filter.copyWith(clearSearch: true)
                                : filter.copyWith(search: val);
                          },
                          quickOptions: [
                            AppQuickFilterOption(
                              id: 'shop_in_stock',
                              label: 'متوفر فقط',
                              icon: AppIcons.checkCircle,
                              selected: filter.inStockOnly,
                              onTap: () {
                                ref
                                    .read(shopPublicProductFilterProvider(
                                      shopId,
                                    ).notifier)
                                    .state = filter.copyWith(
                                  inStockOnly: !filter.inStockOnly,
                                );
                              },
                            ),
                            if (categories.isNotEmpty) ...[
                              AppQuickFilterOption(
                                id: 'shop_cat_all',
                                label: 'الكل',
                                selected: filter.categoryId == null,
                                onTap: () {
                                  ref
                                      .read(shopPublicProductFilterProvider(
                                        shopId,
                                      ).notifier)
                                      .state = filter.copyWith(
                                    clearCategory: true,
                                  );
                                },
                              ),
                              for (final cat in categories)
                                AppQuickFilterOption(
                                  id: 'shop_cat_${cat.id}',
                                  label: cat.name,
                                  selected: filter.categoryId == cat.id,
                                  onTap: () {
                                    final same = filter.categoryId == cat.id;
                                    ref
                                        .read(shopPublicProductFilterProvider(
                                          shopId,
                                        ).notifier)
                                        .state = same
                                        ? filter.copyWith(clearCategory: true)
                                        : filter.copyWith(categoryId: cat.id);
                                  },
                                ),
                            ],
                          ],
                          activeTags: buildCustomerProductActiveTags(
                            filter: filter,
                            categories: categories,
                            includeShopTag: false,
                            onChanged: (next) =>
                                ref
                                    .read(shopPublicProductFilterProvider(
                                      shopId,
                                    ).notifier)
                                    .state = next,
                          ),
                          activeFacetCount: filter.activeFacetCount,
                          sortLabel: filter.sort.labelAr,
                          isDefaultSort:
                              filter.sort == ProductSortOption.newest,
                          onOpenSort: () async {
                            final selected =
                                await showAppSortSheet<ProductSortOption>(
                                  context: context,
                                  current: filter.sort,
                                  options: kCustomerProductSortChoices,
                                );
                            if (selected != null && mounted) {
                              ref
                                  .read(shopPublicProductFilterProvider(
                                    shopId,
                                  ).notifier)
                                  .state = filter.copyWith(
                                sort: selected,
                              );
                            }
                          },
                          onOpenAdvancedFilter: () async {
                            final updated =
                                await showCustomerProductFilterSheet(
                                  context: context,
                                  initial: filter,
                                  sourceProducts: productsState.items,
                                  categories: categories,
                                  showShopSection: false,
                                );
                            if (updated != null && mounted) {
                              ref
                                  .read(shopPublicProductFilterProvider(
                                    shopId,
                                  ).notifier)
                                  .state = updated;
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
                          hasActiveCustomization: filter.hasActiveFilters,
                          onClearAll: () =>
                              ref
                                  .read(shopPublicProductFilterProvider(
                                    shopId,
                                  ).notifier)
                                  .state = ProductFilter.empty,
                        ),
                      productsState.skeletonWhen(
                        placeholder: LoadingFixtures.products,
                        data: (items) {
                          if (items.isEmpty &&
                              !productsState.isInitialLoading) {
                            if (filter.hasActiveFilters) {
                              return Column(
                                children: [
                                  AppFilterEmptyState(
                                    onReset: () =>
                                        ref
                                            .read(
                                              shopPublicProductFilterProvider(
                                                shopId,
                                              ).notifier,
                                            )
                                            .state = ProductFilter.empty,
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
                                            shopPublicProductsProvider(
                                              shopId,
                                            ).notifier,
                                          )
                                          .loadMore,
                                      useProductGridSkeleton: true,
                                    ),
                                ],
                              );
                            }
                            return AppEmpty(
                              icon: AppIcons.garment,
                              message:
                                  'لا توجد منتجات منشورة لهذا المتجر حالياً'.tr,
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                gridDelegate: ProductGridDelegate(
                                  textScale:
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(14) /
                                      14,
                                ),
                                itemBuilder: (context, index) {
                                  final p = items[index];
                                  return ProductGridCard(
                                    imageUrl: p.coverImage,
                                    meta: AppFormat.price(p.price),
                                    inStock: p.totalStock > 0,
                                    isFavorite: p.isFavorite,
                                    onToggleFavorite: () => _toggleFavorite(p),
                                    onAddToCart: () =>
                                        showProductCartSheet(context, p.id),
                                    onTap: () => context.push(
                                      AppRoutes.customerProductDetailsPath(
                                        p.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (!productsState.isInitialLoading)
                                AppLoadMoreFooter(
                                  isLoadingMore: productsState.isLoadingMore,
                                  hasMore: productsState.hasMore,
                                  itemsCount: items.length,
                                  loadMoreError: productsState.loadMoreError,
                                  onLoadMore: ref
                                      .read(
                                        shopPublicProductsProvider(
                                          shopId,
                                        ).notifier,
                                      )
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
                          onAction: ref
                              .read(
                                shopPublicProductsProvider(shopId).notifier,
                              )
                              .refresh,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
      error: (e, _) => CustomerScaffold(
        title: 'المتجر'.tr,
        body: AppEmpty(
          icon: AppIcons.error,
          message: 'تعذر تحميل المتجر: $e'.tr,
        ),
      ),
    );
  }
}
