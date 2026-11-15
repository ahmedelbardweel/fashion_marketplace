import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/models/user_role.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/widgets/app_filter_bar.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  AdminUserFilterState _filter = AdminUserFilterState.empty;

  Future<void> _openFilterSheet(List<AppUser> items) async {
    var draft = _filter;
    final cities = extractDistinctValues(items.map((u) => u.city));
    final updated = await AppBottomSheet.show<AdminUserFilterState>(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          return AppFilterSheetScaffold(
            title: 'تصفية المستخدمين',
            activeCount: draft.activeFacetCount,
            onReset: () => setModalState(
              () => draft = AdminUserFilterState(search: draft.search),
            ),
            onApply: () => Navigator.of(ctx).pop(draft),
            children: [
              AppFilterSection(
                title: 'ترتيب النتائج',
                child: AppFilterChoiceWrap<bool>(
                  options: const [false, true],
                  selectedValue: draft.sortByNameAsc,
                  allowDeselect: false,
                  labelBuilder: (asc) => asc ? 'الاسم: أ - ي' : 'الافتراضي',
                  onSelected: (v) {
                    if (v != null) {
                      setModalState(
                        () => draft = draft.copyWith(sortByNameAsc: v),
                      );
                    }
                  },
                ),
              ),
              AppFilterSection(
                title: 'الدور',
                child: AppFilterChoiceWrap<UserRole>(
                  options: const [UserRole.customer, UserRole.shop],
                  selectedValue: draft.role,
                  allLabel: 'الكل',
                  labelBuilder: (r) => r.labelAr,
                  onSelected: (r) => setModalState(
                    () => draft = r == null
                        ? draft.copyWith(clearRole: true)
                        : draft.copyWith(role: r),
                  ),
                ),
              ),
              AppFilterSection(
                title: 'الحالة',
                child: AppFilterChoiceWrap<ActiveStateFilter>(
                  options: ActiveStateFilter.values,
                  selectedValue: draft.activeFilter,
                  allowDeselect: false,
                  labelBuilder: (st) => st.labelAr,
                  onSelected: (st) {
                    if (st != null) {
                      setModalState(
                        () => draft = draft.copyWith(activeFilter: st),
                      );
                    }
                  },
                ),
              ),
              AppFilterSection(
                title: 'اكتمال الملف',
                child: AppFilterChoiceWrap<bool>(
                  options: const [true, false],
                  selectedValue: draft.profileCompleted,
                  allLabel: 'الكل',
                  labelBuilder: (done) => done ? 'مكتمل' : 'غير مكتمل',
                  onSelected: (done) => setModalState(
                    () => draft = done == null
                        ? draft.copyWith(clearProfileCompleted: true)
                        : draft.copyWith(profileCompleted: done),
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

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final nextActive = !user.isActive;
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: nextActive ? 'تفعيل الحساب'.tr : 'تعليق الحساب'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              nextActive
                  ? 'تفعيل حساب ${user.displayName}؟'.tr
                  : 'تعليق حساب ${user.displayName}؟'.tr,
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
    final ok = await actions.setUserActive(
      userId: user.id,
      isActive: nextActive,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر تحديث الحساب'.tr : actions.errorMessage(error),
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
    final users = ref.watch(adminUsersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'المستخدمون والمحلات'.tr,
      body: AdminAsyncBody<List<AppUser>>(
        placeholder: LoadingFixtures.users,
        value: users,
        emptyMessage: 'لا يوجد مستخدمون بعد'.tr,
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminUsersProvider),
        onRefresh: () => ref.refresh(adminUsersProvider.future),
        builder: (items) {
          final filtered = filterAdminUsers(items, _filter);
          final roleCounts = <UserRole, int>{};
          var inactiveCount = 0;
          for (final u in items) {
            roleCounts[u.role] = (roleCounts[u.role] ?? 0) + 1;
            if (!u.isActive) inactiveCount++;
          }

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث بالاسم، البريد، الهاتف، المدينة...',
                onSearchChanged: (val) =>
                    setState(() => _filter = _filter.copyWith(search: val)),
                sortLabel: _filter.sortByNameAsc
                    ? 'الاسم: أ - ي'
                    : 'الافتراضي',
                isDefaultSort: !_filter.sortByNameAsc,
                onOpenSort: () async {
                  final selected = await showAppSortSheet<bool>(
                    context: context,
                    current: _filter.sortByNameAsc,
                    options: const [
                      AppSortChoice(
                        value: false,
                        label: 'الافتراضي',
                        icon: AppIcons.user,
                      ),
                      AppSortChoice(
                        value: true,
                        label: 'الاسم: أ - ي',
                        icon: AppIcons.catalog,
                      ),
                    ],
                  );
                  if (selected != null && mounted) {
                    setState(
                      () =>
                          _filter = _filter.copyWith(sortByNameAsc: selected),
                    );
                  }
                },
                onOpenAdvancedFilter: () => _openFilterSheet(items),
                activeFacetCount: _filter.activeFacetCount,
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'users_all',
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
                    id: 'users_customer',
                    label: UserRole.customer.labelAr,
                    count: roleCounts[UserRole.customer] ?? 0,
                    selected: _filter.role == UserRole.customer,
                    onTap: () => setState(() {
                      final same = _filter.role == UserRole.customer;
                      _filter = same
                          ? _filter.copyWith(clearRole: true)
                          : _filter.copyWith(role: UserRole.customer);
                    }),
                  ),
                  AppQuickFilterOption(
                    id: 'users_shop',
                    label: UserRole.shop.labelAr,
                    count: roleCounts[UserRole.shop] ?? 0,
                    selected: _filter.role == UserRole.shop,
                    onTap: () => setState(() {
                      final same = _filter.role == UserRole.shop;
                      _filter = same
                          ? _filter.copyWith(clearRole: true)
                          : _filter.copyWith(role: UserRole.shop);
                    }),
                  ),
                  AppQuickFilterOption(
                    id: 'users_inactive',
                    label: ActiveStateFilter.inactive.labelAr,
                    count: inactiveCount,
                    selected:
                        _filter.activeFilter == ActiveStateFilter.inactive,
                    onTap: () => setState(() {
                      final same =
                          _filter.activeFilter == ActiveStateFilter.inactive;
                      _filter = _filter.copyWith(
                        activeFilter: same
                            ? ActiveStateFilter.all
                            : ActiveStateFilter.inactive,
                      );
                    }),
                  ),
                ],
                activeTags: [
                  if (_filter.activeFilter != ActiveStateFilter.all)
                    AppActiveFilterTag(
                      label: _filter.activeFilter.labelAr.tr,
                      onRemove: () => setState(
                        () => _filter = _filter.copyWith(
                          activeFilter: ActiveStateFilter.all,
                        ),
                      ),
                    ),
                  if (_filter.profileCompleted != null)
                    AppActiveFilterTag(
                      label: _filter.profileCompleted!
                          ? 'مكتمل'.tr
                          : 'غير مكتمل'.tr,
                      onRemove: () => setState(
                        () => _filter = _filter.copyWith(
                          clearProfileCompleted: true,
                        ),
                      ),
                    ),
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
                    setState(() => _filter = AdminUserFilterState.empty),
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
                              () => _filter = AdminUserFilterState.empty,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.page,
                        children: filtered
                            .map(
                              (user) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: AppCard(
                                  onTap: busy
                                      ? null
                                      : () => _toggle(context, ref, user),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.displayName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        '${user.role.labelAr} · ${user.isActive ? 'نشط'.tr : 'موقوف'.tr}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        user.email,
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
