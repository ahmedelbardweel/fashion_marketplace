import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

enum _RegionDeliveryFilter { all, available, paused }

class AdminRegionsScreen extends ConsumerStatefulWidget {
  const AdminRegionsScreen({super.key});

  @override
  ConsumerState<AdminRegionsScreen> createState() => _AdminRegionsScreenState();
}

class _AdminRegionsScreenState extends ConsumerState<AdminRegionsScreen> {
  _RegionDeliveryFilter _deliveryFilter = _RegionDeliveryFilter.all;
  String _search = '';

  Future<void> _openRegionSheet({
    GazaRegion? region,
    GazaRegion? defaultParent,
    required List<GazaRegion> governorates,
  }) async {
    final nameCtrl = TextEditingController(text: region?.name ?? '');
    final nameEnCtrl = TextEditingController(text: region?.nameEn ?? '');
    final feeCtrl = TextEditingController(
      text: (region?.deliveryFee ?? defaultParent?.deliveryFee ?? 10)
          .toStringAsFixed(0),
    );
    final estCtrl = TextEditingController(
      text:
          region?.estimatedDelivery ??
          defaultParent?.estimatedDelivery ??
          'نفس اليوم',
    );
    final sortCtrl = TextEditingController(
      text: (region?.sortOrder ?? 1).toString(),
    );

    var parentId = region != null ? region.parentId : defaultParent?.id;
    var isDeliveryAvailable = region?.isDeliveryAvailable ?? true;
    var isActive = region?.isActive ?? true;
    var saving = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> save() async {
            FocusScope.of(sheetCtx).unfocus();
            if (formKey.currentState?.validate() != true) return;
            setSheetState(() => saving = true);
            final fee =
                double.tryParse(feeCtrl.text.trim().replaceAll('٫', '.')) ?? 10;
            final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.upsertRegion(
              id: region?.id,
              name: nameCtrl.text,
              nameEn: nameEnCtrl.text,
              parentId: parentId,
              deliveryFee: fee < 0 ? 0 : fee,
              estimatedDelivery: estCtrl.text,
              isDeliveryAvailable: isDeliveryAvailable,
              isActive: isActive,
              sortOrder: sort,
            );
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(adminActionProvider).error;
              showAppSnackBar(
                context,
                err == null ? 'تعذر حفظ المنطقة'.tr : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حفظ المنطقة بنجاح'.tr);
          }

          Future<void> remove() async {
            if (region == null) return;
            setSheetState(() => saving = true);
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.deleteRegion(region.id);
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(adminActionProvider).error;
              showAppSnackBar(
                context,
                err == null ? 'تعذر حذف المنطقة'.tr : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حذف المنطقة'.tr);
          }

          return AppBottomSheetScaffold(
            title: region == null
                ? (defaultParent != null
                      ? '${'إضافة حي في'.tr} ${defaultParent.name}'
                      : 'إضافة منطقة في قطاع غزة'.tr)
                : 'تعديل المنطقة'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'التبعية (محافظة رئيسية أم حي فرعي)'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: Text('محافظة رئيسية'.tr),
                        selected: parentId == null,
                        onSelected: (region != null && region.isGovernorate)
                            ? null
                            : (_) => setSheetState(() => parentId = null),
                      ),
                      for (final gov in governorates)
                        if (gov.id != region?.id)
                          ChoiceChip(
                            label: Text(
                              AppLang.isEn ? (gov.nameEn ?? gov.name) : gov.name,
                            ),
                            selected: parentId == gov.id,
                            onSelected: (_) => setSheetState(() {
                              parentId = gov.id;
                            }),
                          ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: nameCtrl,
                    label: 'اسم المنطقة بالعربية *'.tr,
                    hint: 'مثال: الرمال الشمالي أو النصيرات'.tr,
                    validator: (v) =>
                        Validators.required(v, field: 'اسم المنطقة'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: nameEnCtrl,
                    label: 'اسم المنطقة بالإنجليزية (اختياري)'.tr,
                    hint: 'e.g. North Rimal',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: feeCtrl,
                          label: 'رسوم التوصيل (₪)'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: sortCtrl,
                          label: 'ترتيب العرض'.tr,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: estCtrl,
                    label: 'مدة التوصيل المتوقعة'.tr,
                    hint: 'مثال: 1 - 2 ساعة أو نفس اليوم'.tr,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      'التوصيل متاح حالياً'.tr,
                      style: TextStyle(
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      'يمكنك إيقاف التوصيل مؤقتاً لهذه المنطقة حسب الظروف الميدانية.'
                          .tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: isDeliveryAvailable,
                    onChanged: saving
                        ? null
                        : AppHaptics.change(
                            (v) => setSheetState(() => isDeliveryAvailable = v),
                          ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      'إظهار المنطقة في التطبيق'.tr,
                      style: TextStyle(
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                    value: isActive,
                    onChanged: saving
                        ? null
                        : AppHaptics.change(
                            (v) => setSheetState(() => isActive = v),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: 'حفظ المنطقة'.tr,
                    isLoading: saving,
                    onPressed: save,
                  ),
                  if (region != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.errorSoft,
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.25),
                        ),
                        minimumSize: const Size(
                          double.infinity,
                          ButtonDesign.height,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ButtonDesign.radius,
                          ),
                        ),
                      ),
                      onPressed: saving ? null : AppHaptics.action(remove),
                      child: Text('حذف المنطقة'.tr),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameCtrl.dispose();
    nameEnCtrl.dispose();
    feeCtrl.dispose();
    estCtrl.dispose();
    sortCtrl.dispose();
  }

  Future<void> _toggleDelivery(GazaRegion region, bool nextAvailable) async {
    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.toggleRegionDelivery(
      id: region.id,
      isDeliveryAvailable: nextAvailable,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث حالة التوصيل'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      nextAvailable
          ? 'تم تفعيل التوصيل للمنطقة'.tr
          : 'تم إيقاف التوصيل مؤقتاً للمنطقة'.tr,
    );
  }

  bool _matchesLocation(String? cityText, GazaGovernorateGroup group) {
    final c = cityText?.trim().toLowerCase() ?? '';
    if (c.isEmpty) return false;
    if (c.contains(group.governorate.name.toLowerCase())) return true;
    if (group.governorate.nameEn != null &&
        c.contains(group.governorate.nameEn!.toLowerCase())) {
      return true;
    }
    return group.areas.any(
      (a) =>
          c.contains(a.name.toLowerCase()) ||
          (a.nameEn != null && c.contains(a.nameEn!.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(adminGazaRegionsProvider);
    final shops = ref.watch(adminManagedShopsProvider).asData?.value ?? const [];
    final users = ref.watch(adminUsersProvider).asData?.value ?? const [];
    final busy = ref.watch(adminActionProvider).isLoading;

    final currentRegions =
        regionsAsync.asData?.value ?? kDefaultGazaRegions;
    final governorates = currentRegions
        .where((r) => r.isGovernorate)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AdminScaffold(
      title: 'مناطق قطاع غزة والتوصيل'.tr,
      showBack: true,
      showBottomNav: false,
      bottom: AppButton(
        label: 'إضافة منطقة أو محافظة'.tr,
        isLoading: busy,
        onPressed: () => _openRegionSheet(governorates: governorates),
      ),
      body: regionsAsync.skeletonWhen(
        placeholder: kDefaultGazaRegions,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل مناطق قطاع غزة',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminGazaRegionsProvider),
            ),
          ],
        ),
        data: (regions) {
          final groups = groupGazaRegions(regions);
          final q = _search.trim().toLowerCase();
          final availableCount = regions
              .where((r) => r.isDeliveryAvailable)
              .length;
          final pausedCount = regions.length - availableCount;

          final visibleGroups = groups.where((g) {
            final matchesDelivery = switch (_deliveryFilter) {
              _RegionDeliveryFilter.all => true,
              _RegionDeliveryFilter.available =>
                g.governorate.isDeliveryAvailable ||
                    g.areas.any((a) => a.isDeliveryAvailable),
              _RegionDeliveryFilter.paused =>
                !g.governorate.isDeliveryAvailable ||
                    g.areas.any((a) => !a.isDeliveryAvailable),
            };
            if (!matchesDelivery) return false;
            if (q.isEmpty) return true;
            if (g.governorate.name.toLowerCase().contains(q) ||
                (g.governorate.nameEn?.toLowerCase().contains(q) ?? false)) {
              return true;
            }
            return g.areas.any(
              (a) =>
                  a.name.toLowerCase().contains(q) ||
                  (a.nameEn?.toLowerCase().contains(q) ?? false),
            );
          }).toList();

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _search,
                searchHint: 'ابحث باسم المحافظة أو الحي في قطاع غزة...',
                onSearchChanged: (v) => setState(() => _search = v),
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'region_all',
                    label: 'الكل',
                    count: regions.length,
                    selected: _deliveryFilter == _RegionDeliveryFilter.all,
                    onTap: () => setState(
                      () => _deliveryFilter = _RegionDeliveryFilter.all,
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'region_available',
                    label: 'التوصيل متاح',
                    count: availableCount,
                    selected:
                        _deliveryFilter == _RegionDeliveryFilter.available,
                    onTap: () => setState(
                      () => _deliveryFilter = _RegionDeliveryFilter.available,
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'region_paused',
                    label: 'متوقف مؤقتاً',
                    count: pausedCount,
                    selected: _deliveryFilter == _RegionDeliveryFilter.paused,
                    onTap: () => setState(
                      () => _deliveryFilter = _RegionDeliveryFilter.paused,
                    ),
                  ),
                ],
                totalCount: groups.length,
                filteredCount: visibleGroups.length,
                hasActiveCustomization:
                    _deliveryFilter != _RegionDeliveryFilter.all ||
                    _search.trim().isNotEmpty,
                onClearAll: () => setState(() {
                  _deliveryFilter = _RegionDeliveryFilter.all;
                  _search = '';
                }),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: visibleGroups.isEmpty
                    ? AdminCenteredEmptyView(
                        onRefresh: () =>
                            ref.refresh(adminGazaRegionsProvider.future),
                        title: 'لا توجد مناطق مطابقة',
                        message:
                            'جرّب تعديل البحث أو إضافة منطقة جديدة من الزر بالأسفل.',
                      )
                    : AppRefreshIndicator(
                        onRefresh: () => Future.wait([
                          ref.refresh(adminGazaRegionsProvider.future),
                          ref.refresh(adminManagedShopsProvider.future),
                          ref.refresh(adminUsersProvider.future),
                        ]),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: visibleGroups.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final group = visibleGroups[index];
                            final gov = group.governorate;
                            final govShops = shops
                                .where((s) => _matchesLocation(s.city, group))
                                .length;
                            final govUsers = users
                                .where((u) => _matchesLocation(u.city, group))
                                .length;

                            final filteredAreas = group.areas.where((a) {
                              if (_deliveryFilter ==
                                      _RegionDeliveryFilter.available &&
                                  !a.isDeliveryAvailable) {
                                return false;
                              }
                              if (_deliveryFilter ==
                                      _RegionDeliveryFilter.paused &&
                                  a.isDeliveryAvailable) {
                                return false;
                              }
                              if (q.isEmpty) return true;
                              if (gov.name.toLowerCase().contains(q) ||
                                  (gov.nameEn?.toLowerCase().contains(q) ??
                                      false)) {
                                return true;
                              }
                              return a.name.toLowerCase().contains(q) ||
                                  (a.nameEn?.toLowerCase().contains(q) ??
                                      false);
                            }).toList();

                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: SellerDesign.statCardBackground,
                                borderRadius: BorderRadius.circular(
                                  CardDesign.radius,
                                ),
                                border: Border.all(
                                  color: SellerDesign.statCardBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Governorate Header Row
                                  InkWell(
                                    onTap: busy
                                        ? null
                                        : AppHaptics.action(
                                            () => _openRegionSheet(
                                              region: gov,
                                              governorates: governorates,
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
                                                '${index + 1}. ${AppLang.isEn ? (gov.nameEn ?? gov.name) : gov.name}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          AppFont.extraBold,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${'التوصيل'.tr}: ${AppFormat.price(gov.deliveryFee)} · ${gov.estimatedDelivery.tr}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$govShops ${'محل'.tr} · $govUsers ${'مستخدم'.tr} · ${group.areas.length} ${'حي'.tr}',
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
                                          ),
                                        ),
                                        Switch(
                                          value: gov.isDeliveryAvailable,
                                          activeThumbColor: AppColors.primary,
                                          onChanged: busy
                                              ? null
                                              : AppHaptics.change(
                                                  (v) =>
                                                      _toggleDelivery(gov, v),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (filteredAreas.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    const Divider(height: 1),
                                    const SizedBox(height: AppSpacing.sm),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: filteredAreas.map((area) {
                                        final label = AppLang.isEn
                                            ? (area.nameEn ?? area.name)
                                            : area.name;
                                        return ActionChip(
                                          label: Text(
                                            '$label · ${area.deliveryFee.toStringAsFixed(0)} ₪',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: area.isDeliveryAvailable
                                                  ? AppColors.text
                                                  : AppColors.error,
                                              decoration:
                                                  area.isDeliveryAvailable
                                                  ? null
                                                  : TextDecoration.lineThrough,
                                            ),
                                          ),
                                          backgroundColor:
                                              area.isDeliveryAvailable
                                              ? AppColors.surfaceAlt
                                              : AppColors.errorSoft,
                                          side: BorderSide(
                                            color: area.isDeliveryAvailable
                                                ? AppColors.border
                                                : AppColors.error.withValues(
                                                    alpha: 0.3,
                                                  ),
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => _openRegionSheet(
                                                  region: area,
                                                  governorates: governorates,
                                                ),
                                        );
                                      }).toList(),
                                    ),
                                  ],

                                  const SizedBox(height: AppSpacing.sm),
                                  AppButton(
                                    label:
                                        '${'إضافة حي في'.tr} ${AppLang.isEn ? (gov.nameEn ?? gov.name) : gov.name}',
                                    variant: AppButtonVariant.secondary,
                                    onPressed: busy
                                        ? null
                                        : () => _openRegionSheet(
                                            defaultParent: gov,
                                            governorates: governorates,
                                          ),
                                  ),
                                ],
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
