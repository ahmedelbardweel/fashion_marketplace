import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_design.dart';
import '../theme/app_spacing.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Shared dashboard chrome for the three role interfaces.
class RoleShell extends ConsumerWidget {
  const RoleShell({
    super.key,
    required this.title,
    required this.roleLabel,
    required this.children,
  });

  final String title;
  final String roleLabel;
  final List<Widget> children;

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'تسجيل الخروج'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'هل تريد تسجيل الخروج من الحساب؟'.tr,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(),
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(title)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: AppHaptics.action(() => _confirmLogout(context, ref)),
            child: Text('خروج'.tr),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleLabel,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.gray500, letterSpacing: 1),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user?.displayName ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (user?.email != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      user!.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}
