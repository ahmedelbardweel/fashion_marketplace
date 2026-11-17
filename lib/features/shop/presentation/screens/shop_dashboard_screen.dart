import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/app_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(myShopProvider).asData?.value;
    final statsState = ref.watch(shopStatsProvider);
    final stats =
        statsState.asData?.value ??
        (statsState.isLoading ? LoadingFixtures.shopStats : null);
    final approved = shop?.visibleStatus == ShopStatus.approved;
    final unreadNotifications = ref.watch(shopUnreadNotificationsCountProvider);

    return ShopScaffold(
      title: shop?.name ?? 'لوحة المحل'.tr,
      showBack: false,
      body: AppSkeleton(
        enabled:
            (ref.watch(myShopProvider).isLoading &&
                !ref.watch(myShopProvider).hasValue) ||
            (ref.watch(shopStatsProvider).isLoading &&
                !ref.watch(shopStatsProvider).hasValue),
        child: AppRefreshIndicator(
          onRefresh: () => Future.wait([
            ref.refresh(myShopProvider.future),
            ref.refresh(shopStatsProvider.future),
            ref.refresh(shopNotificationsProvider.future),
          ]),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHOP PANEL',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.gray500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      shop?.name ?? 'المحل'.tr,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'الحالة: ${shop?.visibleStatus.labelAr ?? '.tr-'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (!approved) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'إدارة المنتجات والطلبات متاحة بعد موافقة الإدارة.'.tr,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (stats != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المنتجات'.tr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${stats.products}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الطلبات'.tr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${stats.orders}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              ShopFeatureTile(
                code: 'SHOP-10',
                title: 'المنتجات'.tr,
                subtitle: 'إضافة وتعديل المنتجات والمخزون'.tr,
                badge: stats?.products.toString(),
                onTap: () => context.go(AppRoutes.shopProducts),
              ),
              const SizedBox(height: AppSpacing.sm),
              ShopFeatureTile(
                code: 'SHOP-17',
                title: 'الطلبات'.tr,
                subtitle: 'متابعة طلبات المحل وتحديث حالتها'.tr,
                badge: stats?.pendingOrders == null || stats!.pendingOrders == 0
                    ? null
                    : stats.pendingOrders.toString(),
                onTap: () => context.go(AppRoutes.shopOrders),
              ),
              const SizedBox(height: AppSpacing.sm),
              ShopFeatureTile(
                code: 'SHOP-19',
                title: 'المبيعات والأرباح'.tr,
                subtitle: 'ملخص المبيعات والمخزون'.tr,
                onTap: () => context.push(AppRoutes.shopSales),
              ),
              const SizedBox(height: AppSpacing.sm),
              ShopFeatureTile(
                code: 'SHOP-20',
                title: 'الإشعارات'.tr,
                subtitle: 'استلام التنبيهات وإرسال إشعارات للعملاء'.tr,
                badge: unreadNotifications == 0
                    ? null
                    : (unreadNotifications > 99
                          ? '99+'
                          : '$unreadNotifications'),
                onTap: () => context.push(AppRoutes.shopNotifications),
              ),
              const SizedBox(height: AppSpacing.sm),
              ShopFeatureTile(
                code: 'SHOP-21',
                title: 'ملف المحل'.tr,
                subtitle: 'تعديل البيانات والشعار والمستندات'.tr,
                onTap: () => context.go(AppRoutes.shopProfile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
