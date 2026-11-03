import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/shop_shell.dart';

class ShopSalesScreen extends ConsumerWidget {
  const ShopSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(shopStatsProvider);

    return ShopScaffold(
      title: 'المبيعات والأرباح',
      showBottomNav: false,
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(ref.read(shopCatalogRepositoryProvider).mapError(error)),
        ),
        data: (ShopStats stats) {
          return ListView(
            padding: AppSpacing.page,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إجمالي المبيعات',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      stats.salesTotal.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الطلبات: ${stats.orders}'),
                    Text('طلبات قيد المعالجة: ${stats.pendingOrders}'),
                    Text('منتجات منشورة: ${stats.publishedProducts}'),
                    Text('وحدات المخزون: ${stats.stockUnits}'),
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
