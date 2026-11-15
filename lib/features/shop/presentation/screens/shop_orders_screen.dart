import '../../../../core/theme/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/shop_product.dart';
import '../../../../core/filtering/filter_models.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/order_filter_sheet.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopOrdersScreen extends ConsumerStatefulWidget {
  const ShopOrdersScreen({super.key});

  @override
  ConsumerState<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends ConsumerState<ShopOrdersScreen> {
  OrderFilterState _filter = OrderFilterState.empty;

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    ShopOrder order,
  ) async {
    final statuses = [
      ('confirmed', 'تأكيد'.tr),
      ('processing', 'تجهيز'.tr),
      ('shipped', 'شحن'.tr),
      ('delivered', 'تسليم'.tr),
      ('cancelled', 'إلغاء'.tr),
    ];

    final status = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'تحديث حالة الطلب'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الطلب الحالي: ${order.statusLabel.tr}'.tr),
            const SizedBox(height: AppSpacing.md),
            ...statuses.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppButton(
                  label: item.$2,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => Navigator.of(context).pop(item.$1),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (status == null) return;
    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.updateOrderStatus(
      orderId: order.id,
      status: status,
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
    showAppSnackBar(context, 'تم تحديث حالة الطلب'.tr);
  }

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
                AppCard(
                  child: Text('الطلبات تظهر بعد موافقة الإدارة على المحل.'.tr),
                ),
              ],
            )
          : orders.skeletonWhen(
              placeholder: LoadingFixtures.shopOrders,
              skipLoadingOnReload: true,
              error: (error, _) => Center(
                child: Text(
                  ref.read(shopCatalogRepositoryProvider).mapError(error).tr,
                ),
              ),
              data: (items) {
                Future<void> handleRefresh() => Future.wait([
                  ref.refresh(myShopProvider.future),
                  ref.refresh(shopOrdersProvider.future),
                ]);

                if (items.isEmpty) {
                  return AppRefreshIndicator(
                    onRefresh: handleRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.page,
                      children: [AppCard(child: Text('لا توجد طلبات بعد'.tr))],
                    ),
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
                            () => _filter = _filter.copyWith(clearStatus: true),
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
                            : ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: AppSpacing.page,
                                children: filtered
                                  .map(
                                    (order) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm,
                                      ),
                                      child: AppCard(
                                        onTap: busy
                                            ? null
                                            : () => _update(context, ref, order),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order.customerName ??
                                                  order.customerEmail ??
                                                  'عميل'.tr,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(
                                              '${order.statusLabel.tr} · ${AppFormat.price(order.total)}',
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            Text(
                                              order.createdAt
                                                  .toString()
                                                  .split('.')
                                                  .first,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
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
