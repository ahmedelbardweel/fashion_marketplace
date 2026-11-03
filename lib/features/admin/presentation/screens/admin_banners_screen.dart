import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
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
    final subtitleController =
        TextEditingController(text: banner?.subtitle ?? '');
    var isActive = banner?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final action = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: banner == null ? 'بنر جديد' : 'تعديل البنر',
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: titleController,
                    label: 'العنوان',
                    validator: (value) =>
                        Validators.required(value, field: 'العنوان'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: subtitleController,
                    label: 'النص الثانوي',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('نشط'),
                    value: isActive,
                    onChanged: (value) => setModalState(() => isActive = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'حفظ',
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(context).pop('save');
                    },
                  ),
                  if (banner != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'حذف',
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
    final active = isActive;
    titleController.dispose();
    subtitleController.dispose();

    final actions = ref.read(adminActionProvider.notifier);
    if (action == 'delete' && banner != null) {
      final ok = await actions.deleteBanner(banner.id);
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
      isActive: active,
      id: banner?.id,
    );
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
    showAppSnackBar(context, 'تم حفظ البنر');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(adminBannersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'العروض والبنرات',
      body: AdminAsyncBody<List<AdminBanner>>(
        value: banners,
        emptyMessage: 'لا توجد بنرات بعد',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminBannersProvider),
        builder: (items) {
          return ListView(
            padding: AppSpacing.page,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: busy
                          ? null
                          : () => _openForm(context, ref, banner: item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.isActive ? 'نشط' : 'متوقف',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (item.subtitle != null &&
                              item.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(item.subtitle!),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      bottom: AppButton(
        label: 'إضافة بنر',
        isLoading: busy,
        onPressed: () => _openForm(context, ref),
      ),
    );
  }
}
