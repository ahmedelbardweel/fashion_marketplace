import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

enum _ShopBannerFilter { all, active, paused }

class ShopBannersScreen extends ConsumerStatefulWidget {
  const ShopBannersScreen({super.key});

  @override
  ConsumerState<ShopBannersScreen> createState() => _ShopBannersScreenState();
}

class _ShopBannersScreenState extends ConsumerState<ShopBannersScreen> {
  _ShopBannerFilter _filter = _ShopBannerFilter.all;
  String _search = '';

  Future<void> _openBannerSheet({AdminBanner? banner}) async {
    final shop = ref.read(myShopProvider).asData?.value;
    final defaultTitle = banner?.title ??
        (shop != null && shop.name.trim().isNotEmpty
            ? 'عروض ${shop.name.trim()}'
            : '');
    final titleCtrl = TextEditingController(text: defaultTitle);
    final subtitleCtrl = TextEditingController(text: banner?.subtitle ?? '');
    final ctaCtrl = TextEditingController(
      text: (banner?.ctaLabel?.trim().isNotEmpty ?? false)
          ? banner!.ctaLabel!.trim()
          : 'تصفح المحل'.tr,
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

          Future<void> pickAndUploadImage() async {
            final picked = await MediaPicker.pickImage();
            if (picked == null || !sheetCtx.mounted) return;
            setSheetState(() => uploading = true);
            try {
              final url = await ref
                  .read(shopStorageRepositoryProvider)
                  .uploadBytes(
                    bucket: 'shop-media',
                    folder: 'banners',
                    fileName: picked.fileName,
                    bytes: picked.bytes,
                    contentType: picked.contentType,
                  );
              if (!sheetCtx.mounted) return;
              setSheetState(() {
                imagePath = url;
                uploading = false;
              });
            } catch (error) {
              if (!sheetCtx.mounted) return;
              setSheetState(() => uploading = false);
              if (mounted) {
                showAppSnackBar(
                  context,
                  ref.read(shopStorageRepositoryProvider).mapError(error),
                  isError: true,
                );
              }
            }
          }

          Future<void> save() async {
            FocusScope.of(sheetCtx).unfocus();
            if (formKey.currentState?.validate() != true) return;
            setSheetState(() => saving = true);
            final actions = ref.read(shopCatalogActionProvider.notifier);
            final ok = await actions.upsertBanner(
              id: banner?.id,
              title: titleCtrl.text,
              subtitle: subtitleCtrl.text,
              imagePath: imagePath,
              ctaLabel: ctaCtrl.text,
              isActive: isActive,
            );
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(shopCatalogActionProvider).error;
              showAppSnackBar(
                context,
                err == null ? 'تعذر حفظ البنر'.tr : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حفظ البنر بنجاح'.tr);
          }

          Future<void> deleteCurrent() async {
            if (banner == null) return;
            setSheetState(() => saving = true);
            final actions = ref.read(shopCatalogActionProvider.notifier);
            final ok = await actions.deleteBanner(banner.id);
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(shopCatalogActionProvider).error;
              showAppSnackBar(
                context,
                err == null ? 'تعذر حذف البنر'.tr : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حذف البنر'.tr);
          }

          return AppBottomSheetScaffold(
            title: banner == null ? 'إضافة بنر جديد'.tr : 'تعديل البنر'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Live Banner Preview
                  _ShopBannerPreviewBox(
                    title: titleCtrl.text.trim().isEmpty
                        ? 'عنوان البنر الرئيسي'.tr
                        : titleCtrl.text.trim(),
                    subtitle: subtitleCtrl.text.trim(),
                    imagePath: hasImage ? imagePath : null,
                    ctaLabel: ctaCtrl.text.trim().isEmpty
                        ? 'تصفح المحل'.tr
                        : ctaCtrl.text.trim(),
                    isAutoOffer: banner?.isAutoOffer ?? false,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: titleCtrl,
                    label: 'العنوان الرئيسي'.tr,
                    hint: 'مثال: عروض متجرنا — خصم حتى 40%'.tr,
                    validator: (value) =>
                        Validators.required(value, field: 'العنوان'.tr),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: subtitleCtrl,
                    label: 'النص الفرعي (اختياري)'.tr,
                    hint: 'مثال: عروض مميزة لفترة محدودة — تصفح المحل الآن'.tr,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: ctaCtrl,
                    label: 'نص زر التصفح'.tr,
                    hint: 'تصفح المحل'.tr,
                    onChanged: (_) => setSheetState(() {}),
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
                          onPressed: saving ? null : pickAndUploadImage,
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
                      'تفعيل البنر للعملاء'.tr,
                      style: TextStyle(
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      'يظهر في الصفحة الرئيسية للعميل وعند الضغط عليه يفتح صفحة متجرك مباشرة.'
                          .tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: isActive,
                    onChanged: saving
                        ? null
                        : AppHaptics.change(
                            (value) => setSheetState(() => isActive = value),
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
                          : AppHaptics.action(deleteCurrent),
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

    await Future<void>.delayed(const Duration(milliseconds: 350));
    titleCtrl.dispose();
    subtitleCtrl.dispose();
    ctaCtrl.dispose();
  }

  Future<void> _toggleBannerActive(AdminBanner banner, bool nextActive) async {
    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.upsertBanner(
      id: banner.id,
      title: banner.title,
      subtitle: banner.subtitle,
      imagePath: banner.imagePath,
      ctaLabel: banner.ctaLabel,
      isActive: nextActive,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث حالة البنر'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      nextActive ? 'تم تفعيل البنر'.tr : 'تم إيقاف البنر'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(myShopProvider);
    final shop = shopState.asData?.value;
    final awaitingShop = shopState.isLoading && !shopState.hasValue;
    final approved = shop?.visibleStatus == ShopStatus.approved;
    final bannersAsync = ref.watch(shopBannersProvider);
    final busy = ref.watch(shopCatalogActionProvider).isLoading;

    return ShopScaffold(
      title: 'بنرات المتجر'.tr,
      showBack: false,
      showBottomNav: true,
      bottom: approved
          ? AppButton(
              label: 'إضافة بنر جديد'.tr,
              isLoading: busy,
              onPressed: () => _openBannerSheet(),
            )
          : null,
      body: !approved && !awaitingShop
          ? ListView(
              padding: AppSpacing.page,
              children: [
                ShopNoticeBanner(
                  title: 'البنرات غير مفعّلة بعد',
                  message:
                      'يمكنك التحكم في بنرات متجرك بعد موافقة الإدارة على طلب الانضمام.',
                  tone: BadgeTone.warning,
                  actionLabel: 'متابعة حالة الطلب',
                  onAction: () => context.push(AppRoutes.shopStatus),
                ),
              ],
            )
          : bannersAsync.skeletonWhen(
              placeholder: LoadingFixtures.banners,
              error: (error, _) => ListView(
                padding: AppSpacing.page,
                children: [
                  ShopNoticeBanner(
                    title: 'تعذر تحميل البنرات',
                    message: ref
                        .read(shopCatalogRepositoryProvider)
                        .mapError(error),
                    tone: BadgeTone.error,
                    actionLabel: 'إعادة المحاولة',
                    onAction: () => ref.invalidate(shopBannersProvider),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ShopCenteredEmptyView(
                    onRefresh: () => ref.refresh(shopBannersProvider.future),
                    title: 'لا توجد بنرات لمتجرك بعد',
                    message:
                        'عند تفعيل أي عرض سينزل بنر تلقائي باسم متجرك هنا، أو يمكنك إضافة بنر إعلاني جديد من الزر بالأسفل.',
                  );
                }

                final activeCount = items.where((b) => b.isActive).length;
                final pausedCount = items.length - activeCount;
                final q = _search.trim().toLowerCase();
                final filtered = items.where((item) {
                  if (_filter == _ShopBannerFilter.active && !item.isActive) {
                    return false;
                  }
                  if (_filter == _ShopBannerFilter.paused && item.isActive) {
                    return false;
                  }
                  if (q.isNotEmpty) {
                    final haystack =
                        '${item.title} ${item.subtitle ?? ''}'.toLowerCase();
                    if (!haystack.contains(q)) return false;
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    AppFilterToolbar(
                      searchValue: _search,
                      searchHint: 'ابحث في بنرات متجرك...',
                      onSearchChanged: (val) => setState(() => _search = val),
                      quickOptions: [
                        AppQuickFilterOption(
                          id: 'shop_banner_all',
                          label: 'الكل',
                          count: items.length,
                          selected: _filter == _ShopBannerFilter.all,
                          onTap: () =>
                              setState(() => _filter = _ShopBannerFilter.all),
                        ),
                        AppQuickFilterOption(
                          id: 'shop_banner_active',
                          label: 'نشط',
                          count: activeCount,
                          selected: _filter == _ShopBannerFilter.active,
                          onTap: () => setState(
                            () => _filter = _ShopBannerFilter.active,
                          ),
                        ),
                        AppQuickFilterOption(
                          id: 'shop_banner_paused',
                          label: 'متوقف',
                          count: pausedCount,
                          selected: _filter == _ShopBannerFilter.paused,
                          onTap: () => setState(
                            () => _filter = _ShopBannerFilter.paused,
                          ),
                        ),
                      ],
                      totalCount: items.length,
                      filteredCount: filtered.length,
                      hasActiveCustomization:
                          _filter != _ShopBannerFilter.all ||
                          _search.trim().isNotEmpty,
                      onClearAll: () => setState(() {
                        _filter = _ShopBannerFilter.all;
                        _search = '';
                      }),
                      showCountWhenUnfiltered: true,
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? ShopCenteredEmptyView(
                              onRefresh: () =>
                                  ref.refresh(shopBannersProvider.future),
                              title: 'لا توجد نتائج مطابقة',
                              message: 'جرّب تغيير البحث أو اختيار عرض الكل.',
                            )
                          : AppRefreshIndicator(
                              onRefresh: () =>
                                  ref.refresh(shopBannersProvider.future),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: AppSpacing.page,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppSpacing.md),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return AppCard(
                                    padding: EdgeInsets.zero,
                                    onTap: busy
                                        ? null
                                        : () => _openBannerSheet(banner: item),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _ShopBannerPreviewBox(
                                          title: item.title,
                                          subtitle: item.subtitle ?? '',
                                          imagePath: item.imagePath,
                                          ctaLabel:
                                              (item.ctaLabel?.trim().isNotEmpty ??
                                                  false)
                                              ? item.ctaLabel!.trim()
                                              : 'تصفح المحل'.tr,
                                          isAutoOffer: item.isAutoOffer,
                                          topRoundedOnly: true,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.sm,
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
                                              if (item.isAutoOffer) ...[
                                                const SizedBox(
                                                  width: AppSpacing.xs,
                                                ),
                                                AppStatusBadge(
                                                  label: 'بنر عروض تلقائي',
                                                  tone: BadgeTone.primary,
                                                ),
                                              ],
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
                                                        (val) =>
                                                            _toggleBannerActive(
                                                              item,
                                                              val,
                                                            ),
                                                      ),
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
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ShopBannerPreviewBox extends StatelessWidget {
  const _ShopBannerPreviewBox({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.ctaLabel,
    required this.isAutoOffer,
    this.topRoundedOnly = false,
  });

  final String title;
  final String subtitle;
  final String? imagePath;
  final String ctaLabel;
  final bool isAutoOffer;
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
      height: 146,
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
                        (isAutoOffer ? 'عروض المحل' : 'بنر المتجر').tr,
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
