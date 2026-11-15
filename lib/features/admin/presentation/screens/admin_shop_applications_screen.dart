import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../../../shop/domain/models/shop.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../../../../core/filtering/filter_models.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminShopApplicationsScreen extends ConsumerStatefulWidget {
  const AdminShopApplicationsScreen({super.key});

  @override
  ConsumerState<AdminShopApplicationsScreen> createState() =>
      _AdminShopApplicationsScreenState();
}

class _AdminShopApplicationsScreenState
    extends ConsumerState<AdminShopApplicationsScreen> {
  AdminShopFilterState _filter = AdminShopFilterState.empty;

  static const _sortChoices = [
    AppSortChoice(
      value: ShopSortOption.newest,
      label: 'الأحدث',
      icon: AppIcons.arrowDown,
    ),
    AppSortChoice(
      value: ShopSortOption.nameAsc,
      label: 'الاسم: أ - ي',
      icon: AppIcons.catalog,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(adminShopApplicationsProvider);

    return AdminScaffold(
      title: 'طلبات الانضمام'.tr,
      showBack: false,
      body: AdminAsyncBody<List<Shop>>(
        placeholder: LoadingFixtures.shops,
        value: apps,
        emptyMessage: 'لا توجد طلبات انضمام حالياً'.tr,
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminShopApplicationsProvider),
        onRefresh: () => ref.refresh(adminShopApplicationsProvider.future),
        builder: (shops) {
          final filtered = filterAdminShops(shops, _filter);
          final cities = extractDistinctValues(shops.map((s) => s.city));
          final statusCounts = <ShopStatus, int>{};
          for (final s in shops) {
            statusCounts[s.status] = (statusCounts[s.status] ?? 0) + 1;
          }
          final pending = filtered.where((s) => s.status == ShopStatus.pending);
          final others = filtered.where((s) => s.status != ShopStatus.pending);

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث باسم المتجر، المالك، المدينة، السجل...',
                onSearchChanged: (val) =>
                    setState(() => _filter = _filter.copyWith(search: val)),
                sortLabel: _filter.sort.labelAr,
                isDefaultSort: _filter.sort == ShopSortOption.newest,
                onOpenSort: () async {
                  final selected = await showAppSortSheet<ShopSortOption>(
                    context: context,
                    current: _filter.sort,
                    options: _sortChoices,
                  );
                  if (selected != null && mounted) {
                    setState(() => _filter = _filter.copyWith(sort: selected));
                  }
                },
                onOpenAdvancedFilter: cities.isEmpty
                    ? null
                    : () async {
                        var draft = _filter;
                        final updated =
                            await AppBottomSheet.show<AdminShopFilterState>(
                              context: context,
                              isScrollControlled: true,
                              child: StatefulBuilder(
                                builder: (ctx, setModalState) =>
                                    AppFilterSheetScaffold(
                                      title: 'تصفية المتاجر',
                                      activeCount: draft.activeFacetCount,
                                      onReset: () => setModalState(
                                        () => draft = AdminShopFilterState(
                                          search: draft.search,
                                        ),
                                      ),
                                      onApply: () =>
                                          Navigator.of(ctx).pop(draft),
                                      children: [
                                        AppFilterSection(
                                          title: 'المدينة',
                                          child: AppFilterChoiceWrap<String>(
                                            options: cities,
                                            selectedValue: draft.city,
                                            allLabel: 'الكل',
                                            labelBuilder: (c) => c,
                                            onSelected: (c) => setModalState(
                                              () => draft = c == null
                                                  ? draft.copyWith(
                                                      clearCity: true,
                                                    )
                                                  : draft.copyWith(city: c),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              ),
                            );
                        if (updated != null && mounted) {
                          setState(() => _filter = updated);
                        }
                      },
                activeFacetCount: _filter.activeFacetCount,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'apps_all',
                    label: 'الكل',
                    count: shops.length,
                    selected: _filter.status == null,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(clearStatus: true),
                    ),
                  ),
                  for (final st in const [
                    ShopStatus.pending,
                    ShopStatus.approved,
                    ShopStatus.rejected,
                    ShopStatus.suspended,
                  ])
                    AppQuickFilterOption(
                      id: 'apps_${st.name}',
                      label: st.labelAr,
                      count: statusCounts[st] ?? 0,
                      selected: _filter.status == st,
                      onTap: () => setState(() {
                        final same = _filter.status == st;
                        _filter = same
                            ? _filter.copyWith(clearStatus: true)
                            : _filter.copyWith(status: st);
                      }),
                    ),
                ],
                activeTags: [
                  if (_filter.city != null)
                    AppActiveFilterTag(
                      label: 'المدينة: ${_filter.city!}'.tr,
                      onRemove: () => setState(
                        () => _filter = _filter.copyWith(clearCity: true),
                      ),
                    ),
                ],
                totalCount: shops.length,
                filteredCount: filtered.length,
                hasActiveCustomization: _filter.hasActiveFilters,
                onClearAll: () =>
                    setState(() => _filter = AdminShopFilterState.empty),
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
                              () => _filter = AdminShopFilterState.empty,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.page,
                        children: [
                          if (pending.isNotEmpty) ...[
                            Text(
                              'بانتظار المراجعة: ${pending.length}'.tr,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ...pending.map((shop) => _ShopTile(shop: shop)),
                          ],
                          if (others.isNotEmpty) ...[
                            if (pending.isNotEmpty)
                              const SizedBox(height: AppSpacing.lg),
                            Text(
                              'طلبات سابقة'.tr,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ...others.map((shop) => _ShopTile(shop: shop)),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push(AppRoutes.adminShopReviewPath(shop.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${shop.status.labelAr} · ${shop.city ?? '-'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (shop.ownerEmail != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                shop.ownerEmail!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
