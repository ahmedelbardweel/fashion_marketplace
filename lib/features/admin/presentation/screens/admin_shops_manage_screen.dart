import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../../../shop/domain/models/shop.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/widgets/app_filter_bar.dart';

class AdminShopsManageScreen extends ConsumerStatefulWidget {
  const AdminShopsManageScreen({super.key});

  @override
  ConsumerState<AdminShopsManageScreen> createState() =>
      _AdminShopsManageScreenState();
}

class _AdminShopsManageScreenState
    extends ConsumerState<AdminShopsManageScreen> {
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

  Future<void> _openFilterSheet(List<Shop> items) async {
    var draft = _filter;
    final cities = extractDistinctValues(items.map((s) => s.city));
    final updated = await AppBottomSheet.show<AdminShopFilterState>(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          return AppFilterSheetScaffold(
            title: 'تصفية المتاجر',
            activeCount: draft.activeFacetCount,
            onReset: () => setModalState(
              () => draft = AdminShopFilterState(search: draft.search),
            ),
            onApply: () => Navigator.of(ctx).pop(draft),
            children: [
              AppFilterSection(
                title: 'ترتيب النتائج',
                child: AppFilterChoiceWrap<ShopSortOption>(
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
                child: AppFilterChoiceWrap<ShopStatus>(
                  options: const [
                    ShopStatus.approved,
                    ShopStatus.suspended,
                    ShopStatus.pending,
                    ShopStatus.rejected,
                  ],
                  selectedValue: draft.status,
                  allLabel: 'الكل',
                  labelBuilder: (st) => st.labelAr,
                  onSelected: (st) => setModalState(
                    () => draft = st == null
                        ? draft.copyWith(clearStatus: true)
                        : draft.copyWith(status: st),
                  ),
                ),
              ),
              if (cities.isNotEmpty)
                AppFilterSection(
                  title: 'المدينة',
                  child: AppFilterChoiceWrap<String>(
                    options: cities,
                    selectedValue: draft.city,
                    allLabel: 'الكل',
                    labelBuilder: (c) => c,
                    onSelected: (c) => setModalState(
                      () => draft = c == null
                          ? draft.copyWith(clearCity: true)
                          : draft.copyWith(city: c),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
    if (updated != null && mounted) {
      setState(() => _filter = updated);
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Shop shop) async {
    if (shop.status != ShopStatus.approved &&
        shop.status != ShopStatus.suspended) {
      context.push(AppRoutes.adminShopReviewPath(shop.id));
      return;
    }

    final suspend = shop.status != ShopStatus.suspended;
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: suspend ? 'تعليق المحل'.tr : 'إعادة تفعيل المحل'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              suspend
                  ? 'تعليق محل "${shop.name}"؟'.tr
                  : 'إعادة تفعيل محل "${shop.name}"؟'.tr,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'تأكيد'.tr,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'إلغاء'.tr,
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.setShopSuspended(
      shopId: shop.id,
      suspend: suspend,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر تحديث المحل'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      suspend ? 'تم تعليق المحل'.tr : 'تم إعادة تفعيل المحل'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shops = ref.watch(adminManagedShopsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'إدارة المحلات'.tr,
      body: AdminAsyncBody<List<Shop>>(
        placeholder: LoadingFixtures.shops,
        value: shops,
        emptyMessage: 'لا توجد محلات بعد'.tr,
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminManagedShopsProvider),
        onRefresh: () => ref.refresh(adminManagedShopsProvider.future),
        builder: (items) {
          final filtered = filterAdminShops(items, _filter);
          final statusCounts = <ShopStatus, int>{};
          for (final s in items) {
            statusCounts[s.status] = (statusCounts[s.status] ?? 0) + 1;
          }

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
                onOpenAdvancedFilter: () => _openFilterSheet(items),
                activeFacetCount: _filter.activeFacetCount,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'manage_shops_all',
                    label: 'الكل',
                    count: items.length,
                    selected: _filter.status == null,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(clearStatus: true),
                    ),
                  ),
                  for (final st in const [
                    ShopStatus.approved,
                    ShopStatus.suspended,
                    ShopStatus.pending,
                    ShopStatus.rejected,
                  ])
                    AppQuickFilterOption(
                      id: 'manage_shops_${st.name}',
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
                totalCount: items.length,
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
                        children: filtered
                            .map(
                              (shop) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: AppCard(
                                  onTap: busy
                                      ? null
                                      : () => _toggle(context, ref, shop),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shop.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        '${shop.status.labelAr} · ${shop.city ?? '-'}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      if (shop.ownerEmail != null) ...[
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          shop.ownerEmail!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        shop.status == ShopStatus.approved ||
                                                shop.status ==
                                                    ShopStatus.suspended
                                            ? 'اضغط للتعليق أو إعادة التفعيل'
                                                  .tr
                                            : 'اضغط لعرض تفاصيل الطلب'.tr,
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
