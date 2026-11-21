import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
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
import '../../../../core/widgets/loading_fixtures.dart';
import '../../domain/models/catalog_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  CatalogListFilterState _filter = CatalogListFilterState.empty;

  Future<void> _openForm({CatalogCategory? category}) async {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    final descCtrl = TextEditingController(text: category?.description ?? '');
    var isActive = category?.isActive ?? true;
    var parentId = category?.parentId;
    var iconKey = category?.iconKey;
    var saving = false;
    final allCategories =
        ref.read(adminCategoriesProvider).value ?? const <CatalogCategory>[];
    final hasChildren = allCategories.any(
      (c) => c.parentId == category?.id && category != null,
    );
    final parents = allCategories
        .where((c) => c.parentId == null && c.id != category?.id)
        .toList();
    const iconOptions = <({String key, String label})>[
      (key: '', label: 'افتراضي'),
      (key: 'clothing', label: 'ملابس'),
      (key: 'shoes', label: 'أحذية'),
      (key: 'accessories', label: 'إكسسوارات'),
      (key: 'bags', label: 'حقائب'),
      (key: 'electronics', label: 'إلكترونيات'),
      (key: 'beauty', label: 'عطور وتجميل'),
    ];
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return AppBottomSheetScaffold(
            title: category == null ? 'تصنيف جديد'.tr : 'تعديل التصنيف'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: nameCtrl,
                    label: 'اسم التصنيف *'.tr,
                    validator: (v) =>
                        Validators.required(v, field: 'اسم التصنيف'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: descCtrl,
                    label: 'الوصف (اختياري)'.tr,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'القسم الرئيسي'.tr,
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
                        label: Text('تصنيف رئيسي مستقل'.tr),
                        selected: parentId == null,
                        onSelected: hasChildren
                            ? null
                            : (_) => setSheetState(() => parentId = null),
                      ),
                      for (final parent in parents)
                        ChoiceChip(
                          label: Text(parent.name),
                          selected: parentId == parent.id,
                          onSelected: hasChildren
                              ? null
                              : (_) => setSheetState(() {
                                  parentId = parent.id;
                                  iconKey = null;
                                }),
                        ),
                    ],
                  ),
                  if (parentId == null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'نوع القسم'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: iconOptions.map((opt) {
                        final selected = (iconKey ?? '') == opt.key;
                        return ChoiceChip(
                          label: Text(opt.label.tr),
                          selected: selected,
                          onSelected: (_) => setSheetState(
                            () => iconKey = opt.key.isEmpty ? null : opt.key,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      'تفعيل التصنيف'.tr,
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
                    label: 'حفظ التصنيف'.tr,
                    isLoading: saving,
                    onPressed: () async {
                      FocusScope.of(sheetCtx).unfocus();
                      if (formKey.currentState?.validate() != true) return;
                      setSheetState(() => saving = true);
                      final actions = ref.read(adminActionProvider.notifier);
                      final ok = await actions.upsertCategory(
                        id: category?.id,
                        name: nameCtrl.text,
                        description: descCtrl.text,
                        isActive: isActive,
                        parentId: parentId,
                        iconKey: parentId == null ? iconKey : null,
                      );
                      if (!mounted) return;
                      if (!ok) {
                        if (sheetCtx.mounted) {
                          setSheetState(() => saving = false);
                        }
                        final err = ref.read(adminActionProvider).error;
                        showAppSnackBar(
                          context,
                          err == null
                              ? 'تعذر الحفظ'.tr
                              : actions.errorMessage(err),
                          isError: true,
                        );
                        return;
                      }
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      showAppSnackBar(context, 'تم حفظ التصنيف بنجاح'.tr);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'إلغاء'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: saving ? null : () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(adminCategoriesProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'التصنيفات الرئيسية والفرعية'.tr,
      showBack: true,
      showBottomNav: false,
      bottom: AppButton(
        label: 'إضافة تصنيف جديد'.tr,
        isLoading: busy,
        onPressed: () => _openForm(),
      ),
      body: categoriesAsync.skeletonWhen(
        placeholder: LoadingFixtures.categories,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل التصنيفات',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminCategoriesProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return AdminCenteredEmptyView(
              onRefresh: () => ref.refresh(adminCategoriesProvider.future),
              title: 'لا توجد تصنيفات بعد',
              message: 'أضف أول تصنيف رئيسي لتنظيم منتجات المتاجر.',
            );
          }

          final ordered = hierarchicalCategoryOptions(items);
          final filtered = ordered.where((entry) {
            final c = entry.category;
            if (_filter.activeFilter == ActiveStateFilter.active &&
                !c.isActive) {
              return false;
            }
            if (_filter.activeFilter == ActiveStateFilter.inactive &&
                c.isActive) {
              return false;
            }
            final q = _filter.search.trim().toLowerCase();
            if (q.isNotEmpty) {
              final text =
                  '${c.name} ${c.description ?? ''} ${entry.parent?.name ?? ''}'
                      .toLowerCase();
              if (!text.contains(q)) return false;
            }
            return true;
          }).toList();

          final activeCount = items.where((c) => c.isActive).length;
          final inactiveCount = items.length - activeCount;

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث باسم التصنيف...',
                onSearchChanged: (v) =>
                    setState(() => _filter = _filter.copyWith(search: v)),
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'cat_all',
                    label: 'الكل',
                    count: items.length,
                    selected: _filter.activeFilter == ActiveStateFilter.all,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        activeFilter: ActiveStateFilter.all,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'cat_active',
                    label: 'نشط',
                    count: activeCount,
                    selected: _filter.activeFilter == ActiveStateFilter.active,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        activeFilter: ActiveStateFilter.active,
                      ),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'cat_inactive',
                    label: 'معطّل',
                    count: inactiveCount,
                    selected:
                        _filter.activeFilter == ActiveStateFilter.inactive,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        activeFilter: ActiveStateFilter.inactive,
                      ),
                    ),
                  ),
                ],
                totalCount: items.length,
                filteredCount: filtered.length,
                hasActiveCustomization: _filter.hasActiveFilters,
                onClearAll: () =>
                    setState(() => _filter = CatalogListFilterState.empty),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: filtered.isEmpty
                    ? AdminCenteredEmptyView(
                        onRefresh: () =>
                            ref.refresh(adminCategoriesProvider.future),
                        title: 'لا توجد تصنيفات مطابقة',
                        message: 'جرّب تعديل البحث أو إزالة الفلتر.',
                      )
                    : AppRefreshIndicator(
                        onRefresh: () =>
                            ref.refresh(adminCategoriesProvider.future),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final cat = entry.category;
                            final isSub = entry.parent != null;

                            return Padding(
                              padding: EdgeInsetsDirectional.only(
                                start: isSub ? AppSpacing.md : 0,
                              ),
                              child: Material(
                                color: SellerDesign.statCardBackground,
                                borderRadius: BorderRadius.circular(
                                  CardDesign.radius,
                                ),
                                child: InkWell(
                                  onTap: busy
                                      ? null
                                      : AppHaptics.action(
                                          () => _openForm(category: cat),
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    CardDesign.radius,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
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
                                                cat.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight: AppFont.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                isSub
                                                    ? '${'فرعي ضمن'.tr}: ${entry.parent!.name}'
                                                    : (cat.description
                                                                  ?.trim()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? cat.description!
                                                                .trim()
                                                          : 'قسم رئيسي'.tr),
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
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        AppStatusBadge(
                                          label: cat.isActive
                                              ? 'نشط'
                                              : 'معطّل',
                                          tone: cat.isActive
                                              ? BadgeTone.success
                                              : BadgeTone.neutral,
                                        ),
                                      ],
                                    ),
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
