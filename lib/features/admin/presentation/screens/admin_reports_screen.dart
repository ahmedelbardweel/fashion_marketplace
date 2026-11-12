import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/admin_stats.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return AdminScaffold(
      title: 'التقارير'.tr,
      body: AdminAsyncBody<AdminStats>(
        placeholder: LoadingFixtures.stats,
        value: stats,
        onRetry: () => ref.invalidate(adminStatsProvider),
        builder: (data) {
          final approvalRate = data.shops == 0
              ? 0
              : ((data.approvedShops / data.shops) * 100).round();
          final hiddenRate = data.products == 0
              ? 0
              : ((data.hiddenProducts / data.products) * 100).round();

          return ListView(
            padding: AppSpacing.page,
            children: [
              Text(
                'ملخص تشغيلي من بيانات المنصة الحالية'.tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نمو الحسابات'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('المستخدمون: ${data.customers}'.tr),
                    Text('المحلات: ${data.shops}'.tr),
                    Text('نسبة المحلات المعتمدة: $approvalRate%'.tr),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الكتالوج'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('التصنيفات: ${data.categories}'.tr),
                    Text('المنتجات: ${data.products}'.tr),
                    Text('نسبة المخفي: $hiddenRate%'.tr),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'العمليات'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('الطلبات: ${data.orders}'.tr),
                    Text('طلبات الانضمام المعلقة: ${data.pendingShops}'.tr),
                    Text('المحلات المعلقة: ${data.suspendedShops}'.tr),
                    Text('الإشعارات المرسلة: ${data.notifications}'.tr),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
