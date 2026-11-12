import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/admin_stats.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return AdminScaffold(
      title: 'إحصائيات التطبيق'.tr,
      body: AdminAsyncBody<AdminStats>(
        placeholder: LoadingFixtures.stats,
        value: stats,
        onRetry: () => ref.invalidate(adminStatsProvider),
        builder: (data) {
          final items = [
            ('المستخدمون'.tr, data.customers),
            ('المحلات'.tr, data.shops),
            ('طلبات معلقة'.tr, data.pendingShops),
            ('محلات معتمدة'.tr, data.approvedShops),
            ('محلات معلقة'.tr, data.suspendedShops),
            ('المنتجات'.tr, data.products),
            ('منتجات مخفية'.tr, data.hiddenProducts),
            ('الطلبات'.tr, data.orders),
            ('التصنيفات'.tr, data.categories),
            ('البنرات'.tr, data.banners),
            ('الإشعارات'.tr, data.notifications),
          ];

          return ListView(
            padding: AppSpacing.page,
            children: [
              Text(
                'نظرة عامة من قاعدة البيانات مباشرة'.tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.$1,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${item.$2}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
