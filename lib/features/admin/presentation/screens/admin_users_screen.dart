import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  AdminUserFilterState _filter = AdminUserFilterState.empty;

  Future<void> _pickGazaRegion() async {
    final regions =
        ref.read(adminGazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;
    final picked = await showGazaRegionPickerSheet(
      context: context,
      regions: regions,
      selectedRegionName: _filter.city,
      allowClear: true,
      title: 'تصفية المستخدمين حسب منطقة في غزة',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filter = picked.name.isEmpty
          ? _filter.copyWith(clearCity: true)
          : _filter.copyWith(city: picked.name);
    });
  }

  Future<void> _openUserSheet(AppUser user) async {
    final nextActive = !user.isActive;
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: user.displayName,
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
                          user.email,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: AppFont.semiBold),
                        ),
                      ),
                      AppStatusBadge(
                        label: user.isActive ? 'نشط' : 'معلّق',
                        tone: user.isActive
                            ? BadgeTone.success
                            : BadgeTone.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${'الدور'.tr}: ${user.role.labelAr.tr}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (user.phone?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${'الهاتف'.tr}: ${user.phone}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (user.city?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${'المنطقة'.tr}: ${user.city}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: AppFont.semiBold,
                      ),
                    ),
                  ],
                  if (user.address?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${'العنوان'.tr}: ${user.address}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (nextActive)
              AppButton(
                label: 'تفعيل الحساب'.tr,
                onPressed: () => Navigator.of(context).pop(true),
              )
            else
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
                  () => Navigator.of(context).pop(true),
                ),
                child: Text('تعليق الحساب'.tr),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'إغلاق'.tr,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.setUserActive(
      userId: user.id,
      isActive: nextActive,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث الحساب'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      nextActive ? 'تم تفعيل الحساب'.tr : 'تم تعليق الحساب'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'إدارة المستخدمين'.tr,
      showBack: true,
      showBottomNav: false,
      body: usersAsync.skeletonWhen(
        placeholder: LoadingFixtures.users,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل المستخدمين',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminUsersProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return AdminCenteredEmptyView(
              onRefresh: () => ref.refresh(adminUsersProvider.future),
              title: 'لا يوجد مستخدمون بعد',
              message: 'ستظهر هنا حسابات العملاء وأصحاب المحلات فور تسجيلهم.',
            );
          }

          final filtered = filterAdminUsers(items, _filter);
          final customerCount = items
              .where((u) => u.role == UserRole.customer)
              .length;
          final shopOwnerCount = items
              .where((u) => u.role == UserRole.shop)
              .length;
          final suspendedCount = items.where((u) => !u.isActive).length;

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث بالاسم، البريد، الهاتف، أو منطقة غزة...',
                onSearchChanged: (v) =>
                    setState(() => _filter = _filter.copyWith(search: v)),
                onOpenAdvancedFilter: _pickGazaRegion,
                activeFacetCount:
                    (_filter.city != null && _filter.city!.isNotEmpty) ? 1 : 0,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'u_all',
                    label: 'الكل',
                    count: items.length,
                    selected:
                        _filter.role == null &&
                        _filter.activeFilter == ActiveStateFilter.all,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        clearRole: true,
                        activeFilter: ActiveStateFilter.all,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'u_customer',
                    label: 'عملاء',
                    count: customerCount,
                    selected: _filter.role == UserRole.customer,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        role: UserRole.customer,
                        activeFilter: ActiveStateFilter.all,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'u_shop',
                    label: 'أصحاب محلات',
                    count: shopOwnerCount,
                    selected: _filter.role == UserRole.shop,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        role: UserRole.shop,
                        activeFilter: ActiveStateFilter.all,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'u_suspended',
                    label: 'معلّقون',
                    count: suspendedCount,
                    selected:
                        _filter.activeFilter == ActiveStateFilter.inactive,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        clearRole: true,
                        activeFilter: ActiveStateFilter.inactive,
                      ),
                    ),
                  ),
                ],
                activeTags: [
                  if (_filter.city != null && _filter.city!.isNotEmpty)
                    AppActiveFilterTag(
                      label: '${'المنطقة'.tr}: ${_filter.city}',
                      onRemove: () => setState(
                        () => _filter = _filter.copyWith(clearCity: true),
                      ),
                    ),
                ],
                totalCount: items.length,
                filteredCount: filtered.length,
                hasActiveCustomization: _filter.hasActiveFilters,
                onClearAll: () =>
                    setState(() => _filter = AdminUserFilterState.empty),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? AdminCenteredEmptyView(
                        onRefresh: () =>
                            ref.refresh(adminUsersProvider.future),
                        title: 'لا يوجد مستخدمون مطابقون',
                        message:
                            'جرّب إزالة الفلاتر أو اختيار منطقة أخرى في قطاع غزة.',
                      )
                    : AppRefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(adminUsersProvider.future),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            final meta = [
                              user.role.labelAr.tr,
                              if (user.city?.trim().isNotEmpty ?? false)
                                user.city!.trim(),
                              if (user.phone?.trim().isNotEmpty ?? false)
                                user.phone!.trim(),
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
                                        () => _openUserSheet(user),
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
                                              user.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: AppFont.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              user.email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.textMuted,
                                                  ),
                                            ),
                                            if (meta.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                meta,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          AppFont.semiBold,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      AppStatusBadge(
                                        label: user.isActive ? 'نشط' : 'معلّق',
                                        tone: user.isActive
                                            ? BadgeTone.success
                                            : BadgeTone.error,
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
