import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/media_picker.dart';
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

enum _AdminPromoTab { banners, offers }

class AdminBannersScreen extends ConsumerStatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  ConsumerState<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends ConsumerState<AdminBannersScreen> {
  _AdminPromoTab _tab = _AdminPromoTab.banners;
  CatalogListFilterState _filter = CatalogListFilterState.empty;
  String _offerSearch = '';

  Future<void> _openBannerForm({AdminBanner? banner}) async {
    final titleCtrl = TextEditingController(text: banner?.title ?? '');
    final subtitleCtrl = TextEditingController(text: banner?.subtitle ?? '');
    final ctaCtrl = TextEditingController(
      text: (banner?.ctaLabel?.trim().isNotEmpty ?? false)
          ? banner!.ctaLabel!.trim()
          : (banner?.isShopBanner == true ? 'تصفح المحل'.tr : 'تسوق الآن'.tr),
    );
    final sortCtrl = TextEditingController(
      text: (banner?.sortOrder ?? 0).toString(),
    );
    var imagePath = banner?.imagePath ?? '';
    var isActive = banner?.isActive ?? true;
    var uploading = false;
    var saving = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final hasImage = imagePath.trim().isNotEmpty;

          Future<void> pickImage() async {
            final picked = await MediaPicker.pickImage();
            if (picked == null || !sheetCtx.mounted) return;
            setSheetState(() => uploading = true);
            try {
              final url = await ref
                  .read(adminRepositoryProvider)
                  .uploadBannerImage(
                    fileName: picked.fileName,
                    bytes: picked.bytes,
                    contentType: picked.contentType,
                  );
              if (!sheetCtx.mounted) return;
              setSheetState(() {
                imagePath = url;
                uploading = false;
              });
            } catch (err) {
              if (!sheetCtx.mounted) return;
              setSheetState(() => uploading = false);
              if (mounted) {
                showAppSnackBar(
                  context,
                  ref.read(adminRepositoryProvider).mapError(err),
                  isError: true,
                );
              }
            }
          }

          Future<void> save() async {
            FocusScope.of(sheetCtx).unfocus();
            if (formKey.currentState?.validate() != true) return;
            setSheetState(() => saving = true);
            final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.upsertBanner(
              id: banner?.id,
              title: titleCtrl.text,
              subtitle: subtitleCtrl.text,
              imagePath: imagePath,
              ctaLabel: ctaCtrl.text,
              sortOrder: sort,
              isActive: isActive,
            );
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(adminActionProvider).error;
              showAppSnackBar(
                context,
                err == null ? 'تعذر الحفظ'.tr : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حفظ البنر بنجاح'.tr);
          }

          Future<void> remove() async {
            if (banner == null) return;
            setSheetState(() => saving = true);
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.deleteBanner(banner.id);
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(adminActionProvider).error;
              showAppSnackBar(
                context,
                err == null ? 'تعذر الحذف'.tr : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حذف البنر'.tr);
          }

          return AppBottomSheetScaffold(
            title: banner == null ? 'بنر إعلاني جديد'.tr : 'تعديل البنر'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminBannerPreview(
                    title: titleCtrl.text.trim().isEmpty
                        ? 'عنوان البنر الرئيسي'.tr
                        : titleCtrl.text.trim(),
                    subtitle: subtitleCtrl.text.trim(),
                    imagePath: hasImage ? imagePath : null,
                    ctaLabel: ctaCtrl.text.trim().isEmpty
                        ? 'تسوق الآن'.tr
                        : ctaCtrl.text.trim(),
                    badgeText: banner?.isShopBanner == true
                        ? (banner!.isAutoOffer ? 'بنر عروض تلقائي' : 'بنر محل')
                        : 'بنر الإدارة',
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: titleCtrl,
                    label: 'العنوان الرئيسي *'.tr,
                    hint: 'مثال: خصم 30% على تشكيلة الموسم'.tr,
                    validator: (v) =>
                        Validators.required(v, field: 'العنوان'.tr),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: subtitleCtrl,
                    label: 'النص الفرعي (اختياري)'.tr,
                    hint: 'مثال: تسوق أحدث الأزياء مع توصيل لمناطق غزة'.tr,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppTextField(
                          controller: ctaCtrl,
                          label: 'نص زر البنر'.tr,
                          hint: 'تسوق الآن'.tr,
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: sortCtrl,
                          label: 'الترتيب'.tr,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Text(
                    'صورة خلفية البنر (اختياري)'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: hasImage
                              ? 'تغيير صورة البنر'.tr
                              : 'اختيار صورة من الجهاز'.tr,
                          variant: AppButtonVariant.secondary,
                          isLoading: uploading,
                          onPressed: saving ? null : pickImage,
                        ),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'إزالة'.tr,
                          variant: AppButtonVariant.secondary,
                          expand: false,
                          onPressed: saving || uploading
                              ? null
                              : () => setSheetState(() => imagePath = ''),
                        ),
                      ],
                    ],
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
                    onChanged: saving
                        ? null
                        : AppHaptics.change(
                            (v) => setSheetState(() => isActive = v),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: 'حفظ البنر'.tr,
                    isLoading: saving,
                    onPressed: uploading ? null : save,
                  ),
                  if (banner != null) ...[
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
                      onPressed: saving || uploading
                          ? null
                          : AppHaptics.action(remove),
                      child: Text('حذف البنر'.tr),
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
    titleCtrl.dispose();
    subtitleCtrl.dispose();
    ctaCtrl.dispose();
    sortCtrl.dispose();
  }

  Future<void> _toggleBannerActive(AdminBanner item, bool active) async {
    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.upsertBanner(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      imagePath: item.imagePath,
      ctaLabel: item.ctaLabel,
      sortOrder: item.sortOrder,
      isActive: active,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر التحديث'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      active ? 'تم تفعيل البنر'.tr : 'تم إيقاف البنر'.tr,
    );
  }

  Future<void> _confirmCancelOffer(AdminProduct offer) async {
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'إلغاء عرض المنتج'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'سيتم إيقاف خصم -${offer.discountPercent}% على "${offer.name}" وإعادة سعره الأصلي، وتحديث بنر المتجر تلقائياً.'
                  .tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.errorSoft,
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.25)),
                minimumSize: const Size(double.infinity, ButtonDesign.height),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ButtonDesign.radius),
                ),
              ),
              onPressed: AppHaptics.action(
                () => Navigator.of(context).pop(true),
              ),
              child: Text('تأكيد إلغاء العرض'.tr),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'تراجع'.tr,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.cancelProductOffer(offer.id);
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر إلغاء العرض'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم إلغاء العرض بنجاح'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(adminBannersProvider);
    final offersAsync = ref.watch(adminActiveOffersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    final bannersCount = bannersAsync.asData?.value.length ?? 0;
    final offersCount = offersAsync.asData?.value.length ?? 0;

    return AdminScaffold(
      title: 'العروض والبنرات'.tr,
      showBack: false,
      bottom: _tab == _AdminPromoTab.banners
          ? AppButton(
              label: 'إضافة بنر إعلاني'.tr,
              isLoading: busy,
              onPressed: () => _openBannerForm(),
            )
          : null,
      body: Column(
        children: [
          // Top segment chips: Banners vs Active Shop Offers
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text('${'البنرات'.tr} ($bannersCount)'),
                    ),
                    selected: _tab == _AdminPromoTab.banners,
                    onSelected: (_) =>
                        setState(() => _tab = _AdminPromoTab.banners),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text('${'عروض المحلات'.tr} ($offersCount)'),
                    ),
                    selected: _tab == _AdminPromoTab.offers,
                    onSelected: (_) =>
                        setState(() => _tab = _AdminPromoTab.offers),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == _AdminPromoTab.banners
                ? _buildBannersTab(bannersAsync, busy)
                : _buildOffersTab(offersAsync, busy),
          ),
        ],
      ),
    );
  }

  Widget _buildBannersTab(
    AsyncValue<List<AdminBanner>> bannersAsync,
    bool busy,
  ) {
    return bannersAsync.skeletonWhen(
      placeholder: LoadingFixtures.banners,
      error: (err, _) => ListView(
        padding: AppSpacing.page,
        children: [
          AdminNoticeBanner(
            title: 'تعذر تحميل البنرات',
            message: ref.read(adminRepositoryProvider).mapError(err),
            tone: BadgeTone.error,
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(adminBannersProvider),
          ),
        ],
      ),
      data: (items) {
        if (items.isEmpty) {
          return AdminCenteredEmptyView(
            onRefresh: () => ref.refresh(adminBannersProvider.future),
            title: 'لا توجد بنرات بعد',
            message:
                'أضف بنراً إعلانياً للمنصة أو انتظر بنرات العروض التلقائية للمحلات.',
          );
        }

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
              quickOptions: [
                AppQuickFilterOption(
                  id: 'adm_banner_all',
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
                  id: 'adm_banner_active',
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
                  id: 'adm_banner_inactive',
                  label: 'متوقف',
                  count: inactiveCount,
                  selected: _filter.activeFilter == ActiveStateFilter.inactive,
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
                      onRefresh: () => ref.refresh(adminBannersProvider.future),
                      title: 'لا توجد بنرات مطابقة',
                      message: 'جرّب تغيير البحث أو إزالة الفلتر.',
                    )
                  : AppRefreshIndicator(
                      onRefresh: () => ref.refresh(adminBannersProvider.future),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.page,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final originLabel = item.isShopBanner
                              ? (item.isAutoOffer
                                    ? 'بنر عروض تلقائي'
                                    : 'بنر محل')
                              : 'بنر الإدارة';
                          return Material(
                            color: SellerDesign.statCardBackground,
                            borderRadius: BorderRadius.circular(
                              CardDesign.radius,
                            ),
                            child: InkWell(
                              onTap: busy
                                  ? null
                                  : AppHaptics.action(
                                      () => _openBannerForm(banner: item),
                                    ),
                              borderRadius: BorderRadius.circular(
                                CardDesign.radius,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    CardDesign.radius,
                                  ),
                                  border: Border.all(
                                    color: SellerDesign.statCardBorder,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _AdminBannerPreview(
                                      title: item.title,
                                      subtitle: item.subtitle ?? '',
                                      imagePath: item.imagePath,
                                      ctaLabel:
                                          (item.ctaLabel?.trim().isNotEmpty ??
                                              false)
                                          ? item.ctaLabel!.trim()
                                          : (item.isShopBanner
                                                ? 'تصفح المحل'.tr
                                                : 'تسوق الآن'.tr),
                                      badgeText: originLabel,
                                      topRoundedOnly: true,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.xs,
                                      ),
                                      child: Row(
                                        children: [
                                          AppStatusBadge(
                                            label: item.isActive
                                                ? 'نشط للعملاء'
                                                : 'متوقف',
                                            tone: item.isActive
                                                ? BadgeTone.success
                                                : BadgeTone.neutral,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          AppStatusBadge(
                                            label: originLabel,
                                            tone: item.isShopBanner
                                                ? BadgeTone.primary
                                                : BadgeTone.neutral,
                                          ),
                                          const Spacer(),
                                          Switch(
                                            value: AppSkeleton.isActive(context)
                                                ? false
                                                : item.isActive,
                                            activeThumbColor:
                                                AppSkeleton.isActive(context)
                                                ? SkeletonDesign.highlight
                                                : AppColors.primary,
                                            onChanged: busy
                                                ? null
                                                : AppHaptics.change(
                                                    (v) => _toggleBannerActive(
                                                      item,
                                                      v,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
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
    );
  }

  Widget _buildOffersTab(
    AsyncValue<List<AdminProduct>> offersAsync,
    bool busy,
  ) {
    return offersAsync.skeletonWhen(
      placeholder: LoadingFixtures.adminProducts,
      error: (err, _) => ListView(
        padding: AppSpacing.page,
        children: [
          AdminNoticeBanner(
            title: 'تعذر تحميل العروض النشطة',
            message: ref.read(adminRepositoryProvider).mapError(err),
            tone: BadgeTone.error,
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(adminActiveOffersProvider),
          ),
        ],
      ),
      data: (offers) {
        if (offers.isEmpty) {
          return AdminCenteredEmptyView(
            onRefresh: () => ref.refresh(adminActiveOffersProvider.future),
            title: 'لا توجد عروض نشطة حالياً',
            message:
                'ستظهر هنا جميع منتجات المحلات التي عليها خصومات حالياً للمراجعة والرقابة.',
          );
        }

        final q = _offerSearch.trim().toLowerCase();
        final filtered = q.isEmpty
            ? offers
            : offers.where((p) {
                final text =
                    '${p.name} ${p.shopName ?? ''} ${p.shopCity ?? ''} ${p.offerTitle ?? ''}'
                        .toLowerCase();
                return text.contains(q);
              }).toList();

        return Column(
          children: [
            AppFilterToolbar(
              searchValue: _offerSearch,
              searchHint: 'ابحث باسم المنتج أو المحل أو المنطقة...',
              onSearchChanged: (v) => setState(() => _offerSearch = v),
              totalCount: offers.length,
              filteredCount: filtered.length,
              hasActiveCustomization: _offerSearch.trim().isNotEmpty,
              onClearAll: () => setState(() => _offerSearch = ''),
              showCountWhenUnfiltered: true,
            ),
            Expanded(
              child: filtered.isEmpty
                  ? AdminCenteredEmptyView(
                      onRefresh: () =>
                          ref.refresh(adminActiveOffersProvider.future),
                      title: 'لا توجد عروض مطابقة',
                      message: 'جرّب تعديل كلمة البحث.',
                    )
                  : AppRefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(adminActiveOffersProvider.future),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.page,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final offer = filtered[index];
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
                                Row(
                                  children: [
                                    if (offer.coverImage != null &&
                                        offer.coverImage!.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.sm,
                                        ),
                                        child: AppNetworkImage(
                                          offer.coverImage!,
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            offer.name,
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
                                            [
                                              if (offer.shopName != null)
                                                offer.shopName!,
                                              if (offer.shopCity != null &&
                                                  offer.shopCity!.isNotEmpty)
                                                offer.shopCity!,
                                            ].join(' · '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.textMuted,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                AppFormat.price(offer.price),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          AppFont.extraBold,
                                                      color: AppColors.text,
                                                    ),
                                              ),
                                              if (offer.originalPrice !=
                                                  null) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  AppFormat.price(
                                                    offer.originalPrice!,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.textMuted,
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    AppStatusBadge(
                                      label: '-${offer.discountPercent}%',
                                      tone: BadgeTone.error,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: AppColors.errorSoft,
                                    foregroundColor: AppColors.error,
                                    side: BorderSide(
                                      color: AppColors.error.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      42,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ButtonDesign.radius,
                                      ),
                                    ),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : AppHaptics.action(
                                          () => _confirmCancelOffer(offer),
                                        ),
                                  child: Text('إلغاء هذا العرض'.tr),
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
    );
  }
}

class _AdminBannerPreview extends StatelessWidget {
  const _AdminBannerPreview({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.ctaLabel,
    required this.badgeText,
    this.topRoundedOnly = false,
  });

  final String title;
  final String subtitle;
  final String? imagePath;
  final String ctaLabel;
  final String badgeText;
  final bool topRoundedOnly;

  @override
  Widget build(BuildContext context) {
    final isSkeleton = AppSkeleton.isActive(context);
    final hasImage =
        !isSkeleton && imagePath != null && imagePath!.trim().isNotEmpty;
    final radius = topRoundedOnly
        ? BorderRadius.vertical(top: Radius.circular(CardDesign.radius))
        : BorderRadius.circular(AppRadii.md);

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: isSkeleton ? SkeletonDesign.base : HomeDesign.bannerBackground,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage) ...[
            AppNetworkImage(
              imagePath!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Color(0xB8000000), Color(0x4D000000)],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSkeleton
                            ? SkeletonDesign.highlight
                            : AppPalette.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        badgeText.tr,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: AppFont.bold,
                          color: HomeDesign.bannerTitle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: AppFont.extraBold,
                        color: HomeDesign.bannerTitle,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle.tr,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSkeleton
                        ? SkeletonDesign.highlight
                        : HomeDesign.bannerButtonBackground,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    ctaLabel.tr,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: AppFont.bold,
                      color: HomeDesign.bannerButtonText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
