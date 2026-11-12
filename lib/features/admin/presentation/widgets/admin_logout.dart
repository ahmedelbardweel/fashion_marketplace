import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

Future<void> confirmAdminLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await AppBottomSheet.show<bool>(
    context: context,
    child: AppBottomSheetScaffold(
      title: 'تسجيل الخروج'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'هل تريد تسجيل الخروج من لوحة الإدارة؟'.tr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'تسجيل الخروج'.tr,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'إلغاء'.tr,
            variant: AppButtonVariant.outlined,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );

  if (confirmed == true) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}
