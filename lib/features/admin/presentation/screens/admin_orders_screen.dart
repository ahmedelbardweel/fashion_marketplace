import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/gaza_region_picker_sheet.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/order_filter_sheet.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  OrderFilterState _filter = OrderFilterState.empty;
  String? _selectedRegion;

  Future<void> _pickRegion() async {
    final regions =
        ref.read(adminGazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;
    final picked = await showGazaRegionPickerSheet(
      context: context,
      regions: regions,
      selectedRegionName: _selectedRegion,
      allowClear: true,
      title: 'تصفية الطلبات حسب منطقة في غزة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedRegion = picked.name.isEmpty ? null : picked.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'الطلبات'.tr,
      showBack: false,
      body: ordersAsync.skeletonWhen(
        placeholder: LoadingFixtures.adminOrders,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل الطلبات',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminOrdersProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return AdminCenteredEmptyView(
              onRefresh: () => ref.refresh(adminOrdersProvider.future),
              title: 'لا توجد طلبات بعد',
              message:
                  'ستظهر هنا جميع طلبات المنصة مع إمكانية متابعة حالتها وتحديثها.',
            );
          }

          var filtered = filterAdminOrders(items, _filter);
          if (_selectedRegion != null && _selectedRegion!.isNotEmpty) {
            final q = _selectedRegion!.toLowerCase();
            filtered = filtered.where((o) {
              final text =
                  '${o.shippingCity ?? ''} ${o.shippingAddress ?? ''} ${o.shopCity ?? ''}'
                      .toLowerCase();
              return text.contains(q);
            }).toList();
          }

          final shopNames = extractDistinctValues(items.map((o) => o.shopName));
          final statusCounts = <String, int>{};
          for (final o in items) {
            statusCounts[o.status] = (statusCounts[o.status] ?? 0) + 1;
          }

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث برقم الطلب، المتجر، العميل، المنطقة...',
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
                onOpenAdvancedFilter: _pickRegion,
                activeFacetCount:
                    _filter.activeFacetCount +
                    (_selectedRegion != null ? 1 : 0),
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
                activeTags: [
                  ...buildOrderActiveTags(
                    filter: _filter,
                    onChanged: (next) => setState(() => _filter = next),
                  ),
                  if (_selectedRegion != null)
                    AppActiveFilterTag(
                      label: '${'المنطقة'.tr}: $_selectedRegion',
                      onRemove: () => setState(() => _selectedRegion = null),
                    ),
                ],
                totalCount: items.length,
                filteredCount: filtered.length,
                hasActiveCustomization:
                    _filter.hasActiveFilters || _selectedRegion != null,
                onClearAll: () => setState(() {
                  _filter = OrderFilterState.empty;
                  _selectedRegion = null;
                }),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? AdminCenteredEmptyView(
                        onRefresh: () =>
                            ref.refresh(adminOrdersProvider.future),
                        title: 'لا توجد طلبات مطابقة',
                        message:
                            'جرّب إزالة الفلاتر أو اختيار منطقة أخرى في قطاع غزة.',
                      )
                    : AppRefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(adminOrdersProvider.future),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            return AdminOrderCard(
                              order: order,
                              onTap: busy
                                  ? null
                                  : () => showAdminOrderStatusSheet(
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
