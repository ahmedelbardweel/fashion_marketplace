import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerShopsScreen extends ConsumerStatefulWidget {
  const CustomerShopsScreen({super.key});

  @override
  ConsumerState<CustomerShopsScreen> createState() =>
      _CustomerShopsScreenState();
}

class _CustomerShopsScreenState extends ConsumerState<CustomerShopsScreen> {
  CustomerShopFilter _filter = CustomerShopFilter.empty;

  static const _sortChoices = [
    AppSortChoice(
      value: ShopSortOption.defaultOrder,
      label: 'الافتراضي',
      icon: AppIcons.shop,
    ),
    AppSortChoice(
      value: ShopSortOption.productsDesc,
      label: 'الأكثر منتجات',
      icon: AppIcons.garment,
    ),
    AppSortChoice(
      value: ShopSortOption.nameAsc,
      label: 'الاسم: أ - ي',
      icon: AppIcons.catalog,
    ),
  ];

  Future<void> _openFilterSheet(List<String> cities) async {
    var draft = _filter;
    final updated = await AppBottomSheet.show<CustomerShopFilter>(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          return AppFilterSheetScaffold(
            title: 'تصفية المتاجر',
            activeCount: draft.activeFacetCount,
            onReset: () => setModalState(
              () => draft = CustomerShopFilter(search: draft.search),
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
              AppFilterSwitchRow(
                title: 'متاجر لديها منتجات فقط',
                subtitle: 'عرض المتاجر التي نشرت منتجات فقط',
                value: draft.onlyWithProducts,
                onChanged: (v) => setModalState(
                  () => draft = draft.copyWith(onlyWithProducts: v),
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

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(customerShopsProvider);

    return CustomerScaffold(
      title: 'المتاجر المعتمدة'.tr,
      body: AppRefreshIndicator(
        onRefresh: () => ref.refresh(customerShopsProvider.future),
        child: shopsAsync.skeletonWhen(
          placeholder: LoadingFixtures.customerShops,
          data: (shops) {
            if (shops.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: AppEmpty(
                      icon: AppIcons.shop,
                      message: 'لا توجد متاجر معتمدة حالياً'.tr,
                    ),
                  ),
                ],
              );
            }

            final cities = extractDistinctValues(shops.map((s) => s.city));
            final filtered = filterCustomerShops(shops, _filter);

            return Column(
              children: [
                AppFilterToolbar(
                  searchValue: _filter.search,
                  searchHint: 'ابحث باسم المتجر، المدينة، الوصف...',
                  onSearchChanged: (val) =>
                      setState(() => _filter = _filter.copyWith(search: val)),
                  sortLabel: _filter.sort.labelAr,
                  isDefaultSort: _filter.sort == ShopSortOption.defaultOrder,
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
                  onOpenAdvancedFilter: () => _openFilterSheet(cities),
                  activeFacetCount: _filter.activeFacetCount,
                  quickOptions: [
                    AppQuickFilterOption(
                      id: 'shop_with_products',
                      label: 'متاجر لديها منتجات فقط',
                      icon: AppIcons.garment,
                      selected: _filter.onlyWithProducts,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(
                          onlyWithProducts: !_filter.onlyWithProducts,
                        ),
                      ),
                    ),
                    if (cities.isNotEmpty) ...[
                      AppQuickFilterOption(
                        id: 'city_all',
                        label: 'الكل',
                        selected: _filter.city == null,
                        onTap: () => setState(
                          () => _filter = _filter.copyWith(clearCity: true),
                        ),
                      ),
                      for (final city in cities)
                        AppQuickFilterOption(
                          id: 'city_$city',
                          label: city,
                          icon: AppIcons.city,
                          selected:
                              normalizeSearchText(_filter.city) ==
                              normalizeSearchText(city),
                          onTap: () => setState(() {
                            final same =
                                normalizeSearchText(_filter.city) ==
                                normalizeSearchText(city);
                            _filter = same
                                ? _filter.copyWith(clearCity: true)
                                : _filter.copyWith(city: city);
                          }),
                        ),
                    ],
                  ],
                  activeTags: [
                    if (_filter.city != null && _filter.city!.isNotEmpty)
                      AppActiveFilterTag(
                        label: 'المدينة: ${_filter.city!}'.tr,
                        onRemove: () => setState(
                          () => _filter = _filter.copyWith(clearCity: true),
                        ),
                      ),
                    if (_filter.onlyWithProducts)
                      AppActiveFilterTag(
                        label: 'متاجر لديها منتجات فقط'.tr,
                        onRemove: () => setState(
                          () => _filter = _filter.copyWith(
                            onlyWithProducts: false,
                          ),
                        ),
                      ),
                  ],
                  totalCount: shops.length,
                  filteredCount: filtered.length,
                  hasActiveCustomization: _filter.hasActiveFilters,
                  onClearAll: () => setState(
                    () => _filter = CustomerShopFilter.empty,
                  ),
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
                                () => _filter = CustomerShopFilter.empty,
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
                            final shop = filtered[index];
                            return AppCard(
                              onTap: () => context.push(
                                AppRoutes.customerShopProfilePath(shop.id),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: ShopProfileDesign.listLogoSize,
                                    height: ShopProfileDesign.listLogoSize,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primaryBorder,
                                        width: 1.5,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child:
                                        shop.logoPath != null &&
                                            shop.logoPath!.isNotEmpty
                                        ? AppNetworkImage(
                                            shop.logoPath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Icon(
                                              AppIcons.shopActive,
                                              color: AppColors.icon,
                                            ),
                                          )
                                        : Icon(
                                            AppIcons.shopActive,
                                            color: AppColors.icon,
                                          ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shop.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: AppFont.bold,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        if (shop.description != null &&
                                            shop.description!.isNotEmpty)
                                          Text(
                                            shop.description!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${shop.city ?? 'متجر أزياء'.tr} · ${shop.productsCount} منتج',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: AppFont.semiBold,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(AppIcons.forward, color: AppColors.icon),
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
            message: 'تعذر تحميل المتاجر: $err'.tr,
          ),
        ),
      ),
    );
  }
}
