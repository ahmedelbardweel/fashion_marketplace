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
import '../widgets/admin_logout.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    PlatformSetting setting,
  ) async {
    final controller = TextEditingController(text: setting.value);
    final formKey = GlobalKey<FormState>();

    final saved = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: setting.label,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: controller,
                label: 'القيمة',
                validator: (value) =>
                    Validators.required(value, field: 'القيمة'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'حفظ',
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        ),
      ),
    );

    final value = controller.text;
    controller.dispose();
    if (saved != true) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.updateSetting(key: setting.key, value: value);
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
    showAppSnackBar(context, 'تم تحديث الإعداد');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminSettingsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'إعدادات المنصة',
      showBack: false,
      body: AdminAsyncBody<List<PlatformSetting>>(
        value: settings,
        emptyMessage: 'لا توجد إعدادات',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminSettingsProvider),
        builder: (items) {
          return ListView(
            padding: AppSpacing.page,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: busy ? null : () => _edit(context, ref, item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.key,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            item.value,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
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
        label: 'تسجيل الخروج',
        variant: AppButtonVariant.outlined,
        onPressed: () => confirmAdminLogout(context, ref),
      ),
    );
  }
}
