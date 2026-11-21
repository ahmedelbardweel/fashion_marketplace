import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/gaza_region_picker_sheet.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../../shop/domain/models/shop.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminShopApplicationsScreen extends ConsumerStatefulWidget {
  const AdminShopApplicationsScreen({super.key});

  @override
  ConsumerState<AdminShopApplicationsScreen> createState() =>
      _AdminShopApplicationsScreenState();
}

class _AdminShopApplicationsScreenState
    extends ConsumerState<AdminShopApplicationsScreen> {
  ShopStatus? _statusFilter = ShopStatus.pending;
  String _search = '';
  String? _regionFilter;

  Future<void> _pickRegion() async {
    final regions =
        ref.read(adminGazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;
    final picked = await showGazaRegionPickerSheet(
      context: context,
      regions: regions,
      selectedRegionName: _regionFilter,
      allowClear: true,
      title: 'تصفية الطلبات حسب منطقة في غزة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _regionFilter = picked.name.isEmpty ? null : picked.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(adminShopApplicationsProvider);

    return AdminScaffold(
      title: 'طلبات انضمام المحلات'.tr,
      showBack: true,
      showBottomNav: false,
      body: appsAsync.skeletonWhen(
        placeholder: LoadingFixtures.shops,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل طلبات الانضمام',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminShopApplicationsProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return AdminCenteredEmptyView(
              onRefresh: () =>
                  ref.refresh(adminShopApplicationsProvider.future),
              title: 'لا توجد طلبات انضمام بعد',
              message:
                  'ستظهر هنا طلبات المتاجر الجديدة لمراجعة بياناتها ووثائقها.',
            );
          }

          final pendingCount = items
              .where((s) => s.status == ShopStatus.pending)
              .length;
          final approvedCount = items
              .where((s) => s.status == ShopStatus.approved)
              .length;
          final rejectedCount = items
              .where((s) => s.status == ShopStatus.rejected)
              .length;

          final q = _search.trim().toLowerCase();
          final rFilter = _regionFilter?.trim().toLowerCase();
          final filtered = items.where((s) {
            if (_statusFilter != null && s.status != _statusFilter) {
              return false;
            }
            if (rFilter != null && rFilter.isNotEmpty) {
              final loc = '${s.city ?? ''} ${s.address ?? ''}'.toLowerCase();
              if (!loc.contains(rFilter)) return false;
            }
            if (q.isNotEmpty) {
              final text =
                  '${s.name} ${s.ownerName ?? ''} ${s.city ?? ''} ${s.ownerPhone ?? ''}'
                      .toLowerCase();
              if (!text.contains(q)) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _search,
                searchHint: 'ابحث باسم المحل، المالك، أو المنطقة...',
                onSearchChanged: (v) => setState(() => _search = v),
                onOpenAdvancedFilter: _pickRegion,
                activeFacetCount: _regionFilter != null ? 1 : 0,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'app_pending',
                    label: 'قيد المراجعة',
                    count: pendingCount,
                    selected: _statusFilter == ShopStatus.pending,
                    onTap: () =>
                        setState(() => _statusFilter = ShopStatus.pending),
                  ),
                  AppQuickFilterOption(
                    id: 'app_all',
                    label: 'الكل',
                    count: items.length,
                    selected: _statusFilter == null,
                    onTap: () => setState(() => _statusFilter = null),
                  ),
                  AppQuickFilterOption(
                    id: 'app_approved',
                    label: 'معتمد',
                    count: approvedCount,
                    selected: _statusFilter == ShopStatus.approved,
                    onTap: () =>
                        setState(() => _statusFilter = ShopStatus.approved),
                  ),
                  AppQuickFilterOption(
                    id: 'app_rejected',
                    label: 'مرفوض',
                    count: rejectedCount,
                    selected: _statusFilter == ShopStatus.rejected,
                    onTap: () =>
                        setState(() => _statusFilter = ShopStatus.rejected),
                  ),
                ],
                activeTags: [
                  if (_regionFilter != null)
                    AppActiveFilterTag(
                      label: '${'المنطقة'.tr}: $_regionFilter',
                      onRemove: () => setState(() => _regionFilter = null),
                    ),
                ],
                totalCount: items.length,
                filteredCount: filtered.length,
                hasActiveCustomization:
                    _statusFilter != null ||
                    _search.trim().isNotEmpty ||
                    _regionFilter != null,
                onClearAll: () => setState(() {
                  _statusFilter = null;
                  _search = '';
                  _regionFilter = null;
                }),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? AdminCenteredEmptyView(
                        onRefresh: () =>
                            ref.refresh(adminShopApplicationsProvider.future),
                        title: _statusFilter == ShopStatus.pending
                            ? 'لا توجد طلبات معلّقة حالياً'
                            : 'لا توجد طلبات مطابقة',
                        message:
                            'جميع طلبات الانضمام تمت مراجعتها أو يمكنك عرض الكل.',
                      )
                    : AppRefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(adminShopApplicationsProvider.future),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final shop = filtered[index];
                            final meta = [
                              if (shop.city?.trim().isNotEmpty ?? false)
                                shop.city!.trim(),
                              if (shop.ownerName?.trim().isNotEmpty ?? false)
                                shop.ownerName!.trim(),
                            ].join(' · ');

                            return Material(
                              color: SellerDesign.statCardBackground,
                              borderRadius: BorderRadius.circular(
                                CardDesign.radius,
                              ),
                              child: InkWell(
                                onTap: AppHaptics.action(
                                  () => context.push(
                                    AppRoutes.adminShopReviewPath(shop.id),
                                  ),
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
                                            if (meta.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                meta,
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
