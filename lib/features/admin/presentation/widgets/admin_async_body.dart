import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../providers/admin_providers.dart';

class AdminAsyncBody<T> extends ConsumerWidget {
  const AdminAsyncBody({
    super.key,
    required this.value,
    required this.onRetry,
    this.onRefresh,
    required this.builder,
    required this.placeholder,
    this.emptyMessage = 'لا توجد بيانات',
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Future<void> Function()? onRefresh;
  final Widget Function(T data) builder;
  final T placeholder;
  final String emptyMessage;
  final bool Function(T data)? isEmpty;

  Future<void> _handleRefresh() async {
    if (onRefresh != null) {
      await onRefresh!();
      return;
    }
    onRetry();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () =>
          AppSkeleton(child: Builder(builder: (_) => builder(placeholder))),
      error: (error, _) => AppRefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.page,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ref.read(adminRepositoryProvider).mapError(error).tr),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(label: 'إعادة المحاولة'.tr, onPressed: onRetry),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return AppRefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [AppCard(child: Text(emptyMessage.tr))],
            ),
          );
        }
        return AppRefreshIndicator(
          onRefresh: _handleRefresh,
          child: builder(data),
        );
      },
    );
  }
}
