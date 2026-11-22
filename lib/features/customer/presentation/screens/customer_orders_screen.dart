import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/order_filter_sheet.dart';
import '../widgets/customer_shell.dart';

class CustomerOrdersScreen extends ConsumerStatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  ConsumerState<CustomerOrdersScreen> createState() =>
      _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends ConsumerState<CustomerOrdersScreen> {
  OrderFilterState _filter = OrderFilterState.empty;

  BadgeTone _toneForStatus(String status) {
    return switch (status) {
      'completed' || 'delivered' => BadgeTone.success,
      'cancelled' || 'rejected' => BadgeTone.error,
      'shipped' || 'processing' => BadgeTone.primary,
      _ => BadgeTone.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return CustomerScaffold(
      title: 'طلباتي'.tr,
      currentNavIndex: 3,
      showBack: false,
      body: AppRefreshIndicator(
        onRefresh: () => ref.refresh(customerOrdersProvider.future),
        child: ordersAsync.skeletonWhen(
          placeholder: LoadingFixtures.orders,
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: AppEmpty(
                      icon: AppIcons.orders,
                      title: 'لا توجد طلبات سابقة'.tr,
                      message:
                          'عندما تشتري أي ملابس ستتمكن من تتبع شحنتها هنا فوراً'
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

            final filtered = filterCustomerOrders(orders, _filter);
            final shopNames = extractDistinctValues(
              orders.map((o) => o.shopName),
            );
            final statusCounts = <String, int>{};
            for (final o in orders) {
              statusCounts[o.status] = (statusCounts[o.status] ?? 0) + 1;
            }

            return Column(
              children: [
                AppFilterToolbar(
                  searchValue: _filter.search,
                  searchHint: 'ابحث برقم الطلب، المتجر، اسم المنتج...',
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
                      id: 'order_status_all',
                      label: 'الكل',
                      count: orders.length,
                      selected: _filter.status == null,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(clearStatus: true),
                      ),
                    ),
                    for (final entry in kOrderStatusFilters)
                      if ((statusCounts[entry.$1] ?? 0) > 0 ||
                          _filter.status == entry.$1)
                        AppQuickFilterOption(
                          id: 'order_status_${entry.$1}',
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
                  totalCount: orders.length,
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
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            final dateStr = DateFormat(
                              'yyyy/MM/dd – hh:mm a',
                            ).format(order.createdAt);
                            final shortId = order.id.length > 8
                                ? order.id.substring(0, 8).toUpperCase()
                                : order.id.toUpperCase();

                            return AppCard(
                              onTap: () => context.push(
                                AppRoutes.customerOrderDetailsPath(order.id),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'طلب #$shortId'.tr,
                                        style: TextStyle(
                                          fontSize: OrdersDesign.orderNumberSize,
                                          fontWeight:
                                              OrdersDesign.orderNumberWeight,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      AppStatusBadge(
                                        label: order.statusLabel,
                                        tone: _toneForStatus(order.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Row(
                                    children: [
                                      Icon(
                                        AppIcons.shop,
                                        size: 15,
                                        color: AppColors.icon,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        order.shopName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: AppFont.semiBold,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: OrdersDesign.dateColor,
                                    ),
                                  ),
                                  if (order.hasPaymentIssue ||
                                      order.isPaymentPending ||
                                      order.isPaymentVerified) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: 4,
                                      children: [
                                        AppStatusBadge(
                                          label: order.deliveryModeLabel,
                                          tone: order.isCustomerPickup
                                              ? BadgeTone.neutral
                                              : BadgeTone.primary,
                                        ),
                                        AppStatusBadge(
                                          label: order.hasPaymentIssue
                                              ? 'مشكلة في الحوالة — اضغط للتحديث'
                                              : order.paymentStatusLabel,
                                          tone: order.hasPaymentIssue
                                              ? BadgeTone.error
                                              : order.isPaymentVerified
                                              ? BadgeTone.success
                                              : BadgeTone.warning,
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.sm),
                                  const Divider(height: 1),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${order.items.length} قطع'.tr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        AppFormat.price(order.total),
                                        style: TextStyle(
                                          fontSize: OrdersDesign.totalSize,
                                          fontWeight: OrdersDesign.totalWeight,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
          error: (err, _) => AppEmpty(
            icon: AppIcons.error,
            message: 'تعذر تحميل الطلبات: $err'.tr,
          ),
        ),
      ),
    );
  }
}
