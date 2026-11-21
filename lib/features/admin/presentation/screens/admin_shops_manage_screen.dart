import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/gaza_region_picker_sheet.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../../shop/domain/models/shop.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminShopsManageScreen extends ConsumerStatefulWidget {
  const AdminShopsManageScreen({super.key});

  @override
  ConsumerState<AdminShopsManageScreen> createState() =>
      _AdminShopsManageScreenState();
}

class _AdminShopsManageScreenState
    extends ConsumerState<AdminShopsManageScreen> {
  AdminShopFilterState _filter = AdminShopFilterState.empty;
  GazaRegion? _selectedRegion;

  Future<void> _pickGazaRegionFilter() async {
    final regions =
        ref.read(adminGazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;
    final picked = await showGazaRegionPickerSheet(
      context: context,
      regions: regions,
      selectedRegionName: _selectedRegion?.name,
      allowClear: true,
      title: 'تصفية المحلات حسب منطقة في غزة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedRegion = picked.name.isEmpty ? null : picked;
    });
  }

  Future<void> _openShopActionsSheet(Shop shop) async {
    if (shop.status == ShopStatus.pending ||
        shop.status == ShopStatus.rejected) {
      context.push(AppRoutes.adminShopReviewPath(shop.id));
      return;
    }

    final suspend = shop.status != ShopStatus.suspended;
    final choice = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: shop.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shop.ownerName ?? shop.ownerEmail ?? '-',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: AppFont.bold),
                        ),
                      ),
                      AppStatusBadge(
                        label: shop.status.labelAr,
                        tone: adminShopStatusTone(shop.status),
                      ),
                    ],
                  ),
                  if (shop.city?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${'المنطقة'.tr}: ${shop.city}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (shop.ownerPhone?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${'الهاتف'.tr}: ${shop.ownerPhone}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'عرض ملف المحل والوثائق'.tr,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop('review'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (suspend)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.errorSoft,
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                  minimumSize: const Size(double.infinity, ButtonDesign.height),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ButtonDesign.radius),
                  ),
                ),
                onPressed: AppHaptics.action(
                  () => Navigator.of(context).pop('toggle'),
                ),
                child: Text('تعليق المحل'.tr),
              )
            else
              AppButton(
                label: 'إعادة تفعيل المحل'.tr,
                onPressed: () => Navigator.of(context).pop('toggle'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'review') {
      context.push(AppRoutes.adminShopReviewPath(shop.id));
      return;
    }

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.setShopSuspended(
      shopId: shop.id,
      suspend: suspend,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث المحل'.tr : actions.errorMessage(err),
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
    final shopsAsync = ref.watch(adminManagedShopsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'المحلات والطلبات'.tr,
      showBack: false,
      body: shopsAsync.skeletonWhen(
        placeholder: LoadingFixtures.shops,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل المحلات',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminManagedShopsProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return AdminCenteredEmptyView(
              onRefresh: () => ref.refresh(adminManagedShopsProvider.future),
              title: 'لا توجد محلات مسجلة بعد',
              message:
                  'ستظهر هنا جميع المحلات وطلبات الانضمام بمجرد تسجيلها في المنصة.',
            );
          }

          final regions =
              ref.watch(adminGazaRegionsProvider).asData?.value ??
              kDefaultGazaRegions;
          final govGroups = groupGazaRegions(regions);

          final pendingCount = items
              .where((s) => s.status == ShopStatus.pending)
              .length;
          final approvedCount = items
              .where((s) => s.status == ShopStatus.approved)
              .length;
          final suspendedCount = items
              .where((s) => s.status == ShopStatus.suspended)
              .length;
          final rejectedCount = items
              .where((s) => s.status == ShopStatus.rejected)
              .length;

          // Apply status/search filters first
          var filtered = filterAdminShops(items, _filter);

          // Apply Gaza region filter with smart Arabic/English matching
          if (_selectedRegion != null) {
            final region = _selectedRegion!;
            final matchedGov = govGroups
                .where((g) => g.governorate.id == region.id)
                .firstOrNull;
            if (matchedGov != null) {
              filtered = filtered
                  .where(
                    (s) =>
                        matchesGazaGovernorate(s.city, matchedGov) ||
                        matchesGazaGovernorate(s.address, matchedGov),
                  )
                  .toList();
            } else {
              final qAr = region.name.split('·').last.trim().toLowerCase();
              final qEn = region.nameEn?.trim().toLowerCase() ?? '';
              filtered = filtered.where((s) {
                final text = '${s.city ?? ''} ${s.address ?? ''}'.toLowerCase();
                return (qAr.isNotEmpty && text.contains(qAr)) ||
                    (qEn.isNotEmpty && text.contains(qEn));
              }).toList();
            }
          }

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث باسم المحل، المالك، أو منطقة غزة...',
                onSearchChanged: (v) =>
                    setState(() => _filter = _filter.copyWith(search: v)),
                onOpenAdvancedFilter: _pickGazaRegionFilter,
                activeFacetCount: _selectedRegion != null ? 1 : 0,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'shop_all',
                    label: 'الكل',
                    count: items.length,
                    selected: _filter.status == null,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(clearStatus: true),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'shop_pending',
                    label: 'قيد المراجعة',
                    count: pendingCount,
                    selected: _filter.status == ShopStatus.pending,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        status: ShopStatus.pending,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'shop_approved',
                    label: 'معتمد',
                    count: approvedCount,
                    selected: _filter.status == ShopStatus.approved,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        status: ShopStatus.approved,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'shop_suspended',
                    label: 'معلّق',
                    count: suspendedCount,
                    selected: _filter.status == ShopStatus.suspended,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        status: ShopStatus.suspended,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'shop_rejected',
                    label: 'مرفوض',
                    count: rejectedCount,
                    selected: _filter.status == ShopStatus.rejected,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        status: ShopStatus.rejected,
                      ),
                    ),
                  ),
                ],
                activeTags: [
                  if (_selectedRegion != null)
                    AppActiveFilterTag(
                      label:
                          '${'المنطقة'.tr}: ${AppLang.isEn ? (_selectedRegion!.nameEn ?? _selectedRegion!.name) : _selectedRegion!.name}',
                      onRemove: () => setState(() => _selectedRegion = null),
                    ),
                ],
                totalCount: items.length,
                filteredCount: filtered.length,
                hasActiveCustomization:
                    _filter.hasActiveFilters || _selectedRegion != null,
                onClearAll: () => setState(() {
                  _filter = AdminShopFilterState.empty;
                  _selectedRegion = null;
                }),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? AdminCenteredEmptyView(
                        onRefresh: () =>
                            ref.refresh(adminManagedShopsProvider.future),
                        title: 'لا توجد محلات مطابقة',
                        message:
                            'جرّب إزالة الفلاتر أو اختيار منطقة أخرى في قطاع غزة.',
                      )
                    : AppRefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(adminManagedShopsProvider.future),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final shop = filtered[index];
                            final subParts = [
                              if (shop.city?.trim().isNotEmpty ?? false)
                                shop.city!.trim(),
                              if (shop.ownerName?.trim().isNotEmpty ?? false)
                                shop.ownerName!.trim(),
                              if (shop.ownerPhone?.trim().isNotEmpty ?? false)
                                shop.ownerPhone!.trim(),
                            ].join(' · ');

                            return Material(
                              color: SellerDesign.statCardBackground,
                              borderRadius: BorderRadius.circular(
                                CardDesign.radius,
                              ),
                              child: InkWell(
                                onTap: busy
                                    ? null
                                    : AppHaptics.action(
                                        () => _openShopActionsSheet(shop),
                                      ),
                                borderRadius: BorderRadius.circular(
                                  CardDesign.radius,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      CardDesign.radius,
                                    ),
                                    border: Border.all(
                                      color: SellerDesign.statCardBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              shop.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: AppFont.bold,
                                                  ),
                                            ),
                                            if (subParts.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                subParts,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      AppStatusBadge(
                                        label: shop.status.labelAr,
                                        tone: adminShopStatusTone(shop.status),
                                      ),
                                    ],
                                  ),
                                ),
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
