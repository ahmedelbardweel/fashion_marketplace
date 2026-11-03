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

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    CatalogCategory? category,
  }) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController =
        TextEditingController(text: category?.description ?? '');
    var isActive = category?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: category == null ? 'تصنيف جديد' : 'تعديل التصنيف',
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'اسم التصنيف',
                    validator: (value) =>
                        Validators.required(value, field: 'اسم التصنيف'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: descController,
                    label: 'الوصف',
                    maxLines: 3,
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

    final name = nameController.text;
    final description = descController.text;
    final active = isActive;
    nameController.dispose();
    descController.dispose();
    if (saved != true) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.upsertCategory(
      name: name,
      description: description,
      isActive: active,
      id: category?.id,
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
    showAppSnackBar(context, 'تم حفظ التصنيف');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminCategoriesProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'التصنيفات',
      body: AdminAsyncBody<List<CatalogCategory>>(
        value: categories,
        emptyMessage: 'لا توجد تصنيفات بعد',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminCategoriesProvider),
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
                          : () => _openForm(context, ref, category: item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.isActive ? 'نشط' : 'متوقف',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(item.description!),
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
        label: 'إضافة تصنيف',
        isLoading: busy,
        onPressed: () => _openForm(context, ref),
      ),
    );
  }
}
