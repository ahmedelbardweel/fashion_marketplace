import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../providers/admin_providers.dart';

class AdminAsyncBody<T> extends ConsumerWidget {
  const AdminAsyncBody({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.emptyMessage = 'لا توجد بيانات',
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final String emptyMessage;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: AppSpacing.page,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ref.read(adminRepositoryProvider).mapError(error)),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'إعادة المحاولة', onPressed: onRetry),
            ],
          ),
        ),
      ),
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return ListView(
            padding: AppSpacing.page,
            children: [
              AppCard(child: Text(emptyMessage)),
            ],
          );
        }
        return builder(data);
      },
    );
  }
}
