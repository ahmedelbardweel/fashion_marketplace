import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/catalog_models.dart';
import '../../../../core/filtering/filter_models.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/order_filter_sheet.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  OrderFilterState _filter = OrderFilterState.empty;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(adminOrdersProvider);

    return AdminScaffold(
      title: 'الطلبات'.tr,
      body: AdminAsyncBody<List<AdminOrder>>(
        placeholder: LoadingFixtures.adminOrders,
        value: orders,
        emptyMessage: 'لا توجد طلبات بعد'.tr,
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminOrdersProvider),
        onRefresh: () => ref.refresh(adminOrdersProvider.future),
        builder: (items) {
          final filtered = filterAdminOrders(items, _filter);
          final shopNames = extractDistinctValues(items.map((o) => o.shopName));
          final statusCounts = <String, int>{};
          for (final o in items) {
            statusCounts[o.status] = (statusCounts[o.status] ?? 0) + 1;
          }

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث برقم الطلب، المتجر، العميل...',
                onSearchChanged: (val) =>
                    setState(() => _filter = _filter.copyWith(search: val)),
                sortLabel: _filter.sort.labelAr,
                isDefaultSort: _filter.sort == OrderSortOption.newest,
                onOpenSort: () async {
                  final selected = await showAppSortSheet<OrderSortOption>(
                    context: context,
                    current: _filter.sort,
                    options: kOrderSortChoices,
                  );
                  if (selected != null && mounted) {
                    setState(() => _filter = _filter.copyWith(sort: selected));
                  }
                },
                onOpenAdvancedFilter: () async {
                  final updated = await showOrderFilterSheet(
                    context: context,
                    initial: _filter,
                    availableShops: shopNames,
                  );
                  if (updated != null && mounted) {
                    setState(() => _filter = updated);
                  }
                },
                activeFacetCount: _filter.activeFacetCount,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'admin_order_all',
                    label: 'الكل',
                    count: items.length,
                    selected: _filter.status == null,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(clearStatus: true),
                    ),
                  ),
                  for (final entry in kOrderStatusFilters)
                    AppQuickFilterOption(
                      id: 'admin_order_${entry.$1}',
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
                onClearAll: () =>
                    setState(() => _filter = OrderFilterState.empty),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.shopName ?? 'محل'.tr,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        '${order.statusLabel.tr} · ${AppFormat.price(order.total)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        order.customerEmail ?? '-',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
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
            ],
          );
        },
      ),
    );
  }
}
