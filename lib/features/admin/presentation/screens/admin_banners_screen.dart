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

class AdminBannersScreen extends ConsumerWidget {
  const AdminBannersScreen({super.key});

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
        title: banner == null ? 'بنر إعلاني جديد' : 'تعديل البنر الإعلاني',
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: titleController,
                    label: 'العنوان الرئيسي',
                    hint: 'مثال: خصم 30% على تشكيلة الصيف',
                    validator: (value) =>
                        Validators.required(value, field: 'العنوان'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: subtitleController,
                    label: 'النص الفرعي (اختياري)',
                    hint: 'مثال: تسوق أحدث الموديلات العصرية الآن',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: imageController,
                    label: 'رابط صورة البنر (اختياري)',
                    hint: 'https://...',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: const Text(
                      'تفعيل البنر للمستخدمين',
                      style: TextStyle(
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: const Text(
                      'يظهر فوراً في الصفحة الرئيسية للعميل عند التفعيل',
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
                    label: 'حفظ البنر',
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(context).pop('save');
                    },
                  ),
                  if (banner != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'حذف البنر',
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
            ? 'تم حذف البنر'
            : (error == null ? 'تعذر الحذف' : actions.errorMessage(error)),
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
        error == null ? 'تعذر الحفظ' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم حفظ البنر بنجاح');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(adminBannersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'العروض والبنرات',
      body: AdminAsyncBody<List<AdminBanner>>(
        placeholder: LoadingFixtures.banners,
        value: banners,
        emptyMessage: 'لا توجد بنرات إعلانية بعد',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminBannersProvider),
        builder: (items) {
          return ListView.separated(
            padding: AppSpacing.page,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
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
                      decoration: const BoxDecoration(
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
                                ? 'نشط (يظهر للمستخدم)'
                                : 'متوقف',
                            tone: item.isActive
                                ? BadgeTone.success
                                : BadgeTone.neutral,
                          ),
                          const Row(
                            children: [
                              Text(
                                'تعديل',
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
          );
        },
      ),
      bottom: AppButton(
        label: 'إضافة بنر إعلاني',
        isLoading: busy,
        onPressed: () => _openForm(context, ref),
      ),
    );
  }
}
