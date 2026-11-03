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

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var audience = 'all';
    final formKey = GlobalKey<FormState>();

    final saved = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'إرسال إشعار',
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
                    controller: bodyController,
                    label: 'المحتوى',
                    maxLines: 4,
                    validator: (value) =>
                        Validators.required(value, field: 'المحتوى'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('الجمهور', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in const [
                        ('all', 'الجميع'),
                        ('customer', 'المستخدمون'),
                        ('shop', 'المحلات'),
                      ])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: audience == option.$1,
                          onSelected: (_) =>
                              setModalState(() => audience = option.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'إرسال',
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    final title = titleController.text;
    final body = bodyController.text;
    final selectedAudience = audience;
    titleController.dispose();
    bodyController.dispose();
    if (saved != true) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.sendNotification(
      title: title,
      body: body,
      audience: selectedAudience,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر الإرسال' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم إرسال الإشعار');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(adminNotificationsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'الإشعارات',
      body: AdminAsyncBody<List<AdminNotification>>(
        value: notifications,
        emptyMessage: 'لا توجد إشعارات مرسلة بعد',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminNotificationsProvider),
        builder: (items) {
          return ListView(
            padding: AppSpacing.page,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.audienceLabel,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(item.body),
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
        label: 'إرسال إشعار',
        isLoading: busy,
        onPressed: () => _send(context, ref),
      ),
    );
  }
}
