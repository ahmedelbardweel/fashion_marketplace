import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/domain/models/app_user.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final nextActive = !user.isActive;
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: nextActive ? 'تفعيل الحساب' : 'تعليق الحساب',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              nextActive
                  ? 'تفعيل حساب ${user.displayName}؟'
                  : 'تعليق حساب ${user.displayName}؟',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'تأكيد',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'إلغاء',
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.setUserActive(
      userId: user.id,
      isActive: nextActive,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر تحديث الحساب' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      nextActive ? 'تم تفعيل الحساب' : 'تم تعليق الحساب',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'المستخدمون والمحلات',
      body: AdminAsyncBody<List<AppUser>>(
        placeholder: LoadingFixtures.users,
        value: users,
        emptyMessage: 'لا يوجد مستخدمون بعد',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminUsersProvider),
        builder: (items) {
          return ListView(
            padding: AppSpacing.page,
            children: items
                .map(
                  (user) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: busy ? null : () => _toggle(context, ref, user),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${user.role.labelAr} · ${user.isActive ? 'نشط' : 'موقوف'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.bodySmall,
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
    );
  }
}
