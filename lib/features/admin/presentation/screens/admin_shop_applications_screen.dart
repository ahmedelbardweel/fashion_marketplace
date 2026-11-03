import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../../../shop/domain/models/shop.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminShopApplicationsScreen extends ConsumerWidget {
  const AdminShopApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(adminShopApplicationsProvider);

    return AdminScaffold(
      title: 'طلبات الانضمام',
      showBack: false,
      body: AdminAsyncBody<List<Shop>>(
        value: apps,
        emptyMessage: 'لا توجد طلبات انضمام حالياً',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminShopApplicationsProvider),
        builder: (shops) {
          final pending = shops.where((s) => s.status == ShopStatus.pending);
          final others = shops.where((s) => s.status != ShopStatus.pending);

          return ListView(
            padding: AppSpacing.page,
            children: [
              Text(
                'بانتظار المراجعة: ${pending.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              ...pending.map((shop) => _ShopTile(shop: shop)),
              if (others.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'طلبات سابقة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                ...others.map((shop) => _ShopTile(shop: shop)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push(AppRoutes.adminShopReviewPath(shop.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${shop.status.labelAr} · ${shop.city ?? '-'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (shop.ownerEmail != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                shop.ownerEmail!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
