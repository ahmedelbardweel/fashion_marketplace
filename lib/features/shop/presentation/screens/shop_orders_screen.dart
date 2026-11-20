import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/order_filter_sheet.dart';
import '../../../../router/routes.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopOrdersScreen extends ConsumerStatefulWidget {
  const ShopOrdersScreen({super.key});

  @override
  ConsumerState<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends ConsumerState<ShopOrdersScreen> {
  OrderFilterState _filter = OrderFilterState.empty;

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(myShopProvider);
    final shop = shopState.asData?.value;
    final awaitingShop = shopState.isLoading && !shopState.hasValue;
    final orders = awaitingShop
        ? const AsyncLoading<List<ShopOrder>>()
        : ref.watch(shopOrdersProvider);
    final busy = ref.watch(shopCatalogActionProvider).isLoading;
    final approved = shop?.visibleStatus == ShopStatus.approved;

    return ShopScaffold(
      title: 'طلبات المحل'.tr,
      showBack: false,
      body: !approved && !awaitingShop
          ? ListView(
              padding: AppSpacing.page,
              children: [
                ShopNoticeBanner(
                  title: 'الطلبات غير مفعّلة بعد',
                  message:
                      'تظهر طلبات العملاء هنا تلقائياً بعد موافقة الإدارة على متجرك.',
                  tone: BadgeTone.warning,
                  actionLabel: 'متابعة حالة الطلب',
                  onAction: () => context.push(AppRoutes.shopStatus),
                ),
              ],
            )
          : orders.skeletonWhen(
              placeholder: LoadingFixtures.shopOrders,
              skipLoadingOnReload: true,
              error: (error, _) => ListView(
                padding: AppSpacing.page,
                children: [
                  ShopNoticeBanner(
                    title: 'تعذر تحميل الطلبات',
                    message: ref
                        .read(shopCatalogRepositoryProvider)
                        .mapError(error),
                    tone: BadgeTone.error,
                    actionLabel: 'إعادة المحاولة',
                    onAction: () => ref.invalidate(shopOrdersProvider),
                  ),
                ],
              ),
              data: (items) {
                Future<void> handleRefresh() => Future.wait([
                  ref.refresh(myShopProvider.future),
                  ref.refresh(shopOrdersProvider.future),
                  ref.refresh(shopStatsProvider.future),
                ]);

                if (items.isEmpty) {
                  return ShopCenteredEmptyView(
                    onRefresh: handleRefresh,
                    title: 'لا توجد طلبات بعد',
                    message:
                        'عندما يقوم العملاء بالطلب من متجرك ستظهر تفاصيل الطلبات هنا لمتابعتها.',
                  );
                }

                final filtered = filterShopOrders(items, _filter);
                final statusCounts = <String, int>{};
                for (final o in items) {
                  statusCounts[o.status] = (statusCounts[o.status] ?? 0) + 1;
                }

                return Column(
                  children: [
                    AppFilterToolbar(
                      searchValue: _filter.search,
                      searchHint: 'ابحث برقم الطلب، العميل، البريد...',
                      onSearchChanged: (val) => setState(
                        () => _filter = _filter.copyWith(search: val),
                      ),
                      sortLabel: _filter.sort.labelAr,
                      isDefaultSort: _filter.sort == OrderSortOption.newest,
                      onOpenSort: () async {
                        final selected = await showAppSortSheet<OrderSortOption>(
                          context: context,
                          current: _filter.sort,
                          options: kOrderSortChoices,
                        );
                        if (selected != null && mounted) {
                          setState(
                            () => _filter = _filter.copyWith(sort: selected),
                          );
                        }
                      },
                      onOpenAdvancedFilter: () async {
                        final updated = await showOrderFilterSheet(
                          context: context,
                          initial: _filter,
                        );
                        if (updated != null && mounted) {
                          setState(() => _filter = updated);
                        }
                      },
                      activeFacetCount: _filter.activeFacetCount,
                      quickOptions: [
                        AppQuickFilterOption(
                          id: 'shop_order_all',
                          label: 'الكل',
                          count: items.length,
                          selected: _filter.status == null,
                          onTap: () => setState(
                            () =>
                                _filter = _filter.copyWith(clearStatus: true),
                          ),
                        ),
                        for (final entry in kOrderStatusFilters)
                          AppQuickFilterOption(
                            id: 'shop_order_${entry.$1}',
                            label: entry.$2,
                            count: statusCounts[entry.$1] ?? 0,
                            selected: _filter.status == entry.$1,
                            onTap: () => setState(() {
                              final same = _filter.status == entry.$1;
                              _filter = same
                                  ? _filter.copyWith(clearStatus: true)
                                  : _filter.copyWith(status: entry.$1);
                            }),
                          ),
                      ],
                      activeTags: buildOrderActiveTags(
                        filter: _filter,
                        onChanged: (next) => setState(() => _filter = next),
                      ),
                      totalCount: items.length,
                      filteredCount: filtered.length,
                      hasActiveCustomization: _filter.hasActiveFilters,
                      onClearAll: () => setState(
                        () => _filter = OrderFilterState.empty,
                      ),
                      showCountWhenUnfiltered: true,
                    ),
                    Expanded(
                      child: AppRefreshIndicator(
                        onRefresh: handleRefresh,
                        child: filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: AppSpacing.page,
                                children: [
                                  AppFilterEmptyState(
                                    onReset: () => setState(
                                      () => _filter = OrderFilterState.empty,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: AppSpacing.page,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final order = filtered[index];
                                  return ShopOrderCard(
                                    order: order,
                                    onTap: busy
                                        ? null
                                        : () => showShopOrderStatusSheet(
                                            context,
                                            ref,
                                            order,
                                          ),
                                  );
                                },
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
