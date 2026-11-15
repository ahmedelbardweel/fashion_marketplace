import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../customer/presentation/providers/customer_providers.dart';
import '../../domain/models/catalog_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

import '../../../../core/widgets/app_filter_bar.dart';

class AdminBannersScreen extends ConsumerStatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  ConsumerState<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends ConsumerState<AdminBannersScreen> {
  CatalogListFilterState _filter = CatalogListFilterState.empty;

  static const _sortChoices = [
    AppSortChoice(
      value: DisplayOrderSort.displayOrder,
      label: 'الترتيب الافتراضي',
      icon: AppIcons.catalog,
    ),
    AppSortChoice(
      value: DisplayOrderSort.nameAsc,
      label: 'أبجدياً: أ - ي',
      icon: AppIcons.arrowUp,
    ),
    AppSortChoice(
      value: DisplayOrderSort.nameDesc,
      label: 'أبجدياً: ي - أ',
      icon: AppIcons.arrowDown,
    ),
  ];

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    AdminBanner? banner,
  }) async {
    final titleController = TextEditingController(text: banner?.title ?? '');
    final subtitleController = TextEditingController(
      text: banner?.subtitle ?? '',
    );
    final imageController = TextEditingController(
      text: banner?.imagePath ?? '',
    );
    var isActive = banner?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final action = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: banner == null ? 'بنر إعلاني جديد'.tr : 'تعديل البنر الإعلاني'.tr,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: titleController,
                    label: 'العنوان الرئيسي'.tr,
                    hint: 'مثال: خصم 30% على تشكيلة الصيف'.tr,
                    validator: (value) =>
                        Validators.required(value, field: 'العنوان'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: subtitleController,
                    label: 'النص الفرعي (اختياري)'.tr,
                    hint: 'مثال: تسوق أحدث الموديلات العصرية الآن'.tr,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: imageController,
                    label: 'رابط صورة البنر (اختياري)'.tr,
                    hint: 'https://...',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      'تفعيل البنر للمستخدمين'.tr,
                      style: TextStyle(
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      'يظهر فوراً في الصفحة الرئيسية للعميل عند التفعيل'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: isActive,
                    onChanged: AppHaptics.change(
                      (value) => setModalState(() => isActive = value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'حفظ البنر'.tr,
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(context).pop('save');
                    },
                  ),
                  if (banner != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'حذف البنر'.tr,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.of(context).pop('delete'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    final title = titleController.text;
    final subtitle = subtitleController.text;
    final imagePath = imageController.text;
    final active = isActive;
    titleController.dispose();
    subtitleController.dispose();
    imageController.dispose();

    final actions = ref.read(adminActionProvider.notifier);
    if (action == 'delete' && banner != null) {
      final ok = await actions.deleteBanner(banner.id);
      ref.invalidate(customerBannersProvider);
      if (!context.mounted) return;
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        ok
            ? 'تم حذف البنر'.tr
            : (error == null ? 'تعذر الحذف'.tr : actions.errorMessage(error)),
        isError: !ok,
      );
      return;
    }

    if (action != 'save') return;
    final ok = await actions.upsertBanner(
      title: title,
      subtitle: subtitle,
      imagePath: imagePath,
      isActive: active,
      id: banner?.id,
    );
    ref.invalidate(customerBannersProvider);
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر الحفظ'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم حفظ البنر بنجاح'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(adminBannersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'العروض والبنرات'.tr,
      body: AdminAsyncBody<List<AdminBanner>>(
        placeholder: LoadingFixtures.banners,
        value: banners,
        emptyMessage: 'لا توجد بنرات إعلانية بعد'.tr,
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminBannersProvider),
        onRefresh: () => ref.refresh(adminBannersProvider.future),
        builder: (items) {
          final filtered = filterAdminBanners(items, _filter);
          final activeCount = items.where((b) => b.isActive).length;
          final inactiveCount = items.length - activeCount;

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث في عنوان البنر أو الوصف...',
                onSearchChanged: (val) =>
                    setState(() => _filter = _filter.copyWith(search: val)),
                sortLabel: _filter.sort.labelAr,
                isDefaultSort: _filter.sort == DisplayOrderSort.displayOrder,
                onOpenSort: () async {
                  final selected = await showAppSortSheet<DisplayOrderSort>(
                    context: context,
                    current: _filter.sort,
                    options: _sortChoices,
                  );
                  if (selected != null && mounted) {
                    setState(() => _filter = _filter.copyWith(sort: selected));
                  }
                },
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'banner_all',
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
                    id: 'banner_active',
                    label: ActiveStateFilter.active.labelAr,
                    count: activeCount,
                    selected: _filter.activeFilter == ActiveStateFilter.active,
                    onTap: () => setState(() {
                      final same =
                          _filter.activeFilter == ActiveStateFilter.active;
                      _filter = _filter.copyWith(
                        activeFilter: same
                            ? ActiveStateFilter.all
                            : ActiveStateFilter.active,
                      );
                    }),
                  ),
                  AppQuickFilterOption(
                    id: 'banner_inactive',
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
                totalCount: items.length,
                filteredCount: filtered.length,
                hasActiveCustomization: _filter.hasActiveFilters,
                onClearAll: () =>
                    setState(() => _filter = CatalogListFilterState.empty),
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
                              () => _filter = CatalogListFilterState.empty,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.page,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
              final hasImage =
                  item.imagePath != null && item.imagePath!.trim().isNotEmpty;
              return AppCard(
                padding: EdgeInsets.zero,
                onTap: busy
                    ? null
                    : () => _openForm(context, ref, banner: item),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live Banner Preview Header
                    Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: HomeDesign.bannerBackground,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(CardDesign.radius),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasImage) ...[
                            AppNetworkImage(
                              item.imagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                            const ColoredBox(
                              color: HomeDesign.bannerImageOverlay,
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: AppFont.extraBold,
                                    color: HomeDesign.bannerTitle,
                                  ),
                                ),
                                if (item.subtitle != null &&
                                    item.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: HomeDesign.bannerSubtitle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppStatusBadge(
                            label: item.isActive
                                ? 'نشط (يظهر للمستخدم)'.tr
                                : 'متوقف'.tr,
                            tone: item.isActive
                                ? BadgeTone.success
                                : BadgeTone.neutral,
                          ),
                          Row(
                            children: [
                              Text(
                                'تعديل'.tr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: AppFont.bold,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                AppIcons.edit,
                                size: 16,
                                color: AppColors.icon,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
              ),
            ],
          );
        },
      ),
      bottom: AppButton(
        label: 'إضافة بنر إعلاني'.tr,
        isLoading: busy,
        onPressed: () => _openForm(context, ref),
      ),
    );
  }
}
