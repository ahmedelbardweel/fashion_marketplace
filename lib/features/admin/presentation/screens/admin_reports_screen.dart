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
      title: 'التقارير',
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
                'ملخص تشغيلي من بيانات المنصة الحالية',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نمو الحسابات',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('المستخدمون: ${data.customers}'),
                    Text('المحلات: ${data.shops}'),
                    Text('نسبة المحلات المعتمدة: $approvalRate%'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الكتالوج',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('التصنيفات: ${data.categories}'),
                    Text('المنتجات: ${data.products}'),
                    Text('نسبة المخفي: $hiddenRate%'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'العمليات',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('الطلبات: ${data.orders}'),
                    Text('طلبات الانضمام المعلقة: ${data.pendingShops}'),
                    Text('المحلات المعلقة: ${data.suspendedShops}'),
                    Text('الإشعارات المرسلة: ${data.notifications}'),
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
