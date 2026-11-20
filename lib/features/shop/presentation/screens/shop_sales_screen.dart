import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopSalesScreen extends ConsumerWidget {
  const ShopSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(shopStatsProvider);

    return ShopScaffold(
      title: 'المبيعات والأرباح'.tr,
      showBottomNav: false,
      body: statsAsync.skeletonWhen(
        placeholder: LoadingFixtures.shopStats,
        skipLoadingOnReload: true,
        error: (error, _) => ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل بيانات المبيعات',
              message: ref.read(shopCatalogRepositoryProvider).mapError(error),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(shopStatsProvider),
            ),
          ],
        ),
        data: (stats) {
          final avgOrderValue = stats.orders > 0
              ? stats.salesTotal / stats.orders
              : 0.0;
          final completedOrders = (stats.orders - stats.pendingOrders).clamp(
            0,
            stats.orders,
          );
          final publishRatio = stats.products > 0
              ? (stats.publishedProducts / stats.products).clamp(0.0, 1.0)
              : 0.0;

          return AppRefreshIndicator(
            onRefresh: () => ref.refresh(shopStatsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(
                      SellerDesign.statCardRadius,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي المبيعات'.tr,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.9),
                          fontWeight: AppFont.semiBold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          AppFormat.price(stats.salesTotal),
                          style: TextStyle(
                            fontSize: AppFont.display,
                            fontWeight: AppFont.extraBold,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroMetaItem(
                              label: 'متوسط قيمة الطلب'.tr,
                              value: AppFormat.price(avgOrderValue),
                            ),
                          ),
                          Expanded(
                            child: _HeroMetaItem(
                              label: 'طلبات مكتملة / مؤكدة'.tr,
                              value: '$completedOrders',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ShopKpiCard(
                  label: 'إجمالي الطلبات',
                  value: '${stats.orders}',
                  tone: BadgeTone.primary,
                  onTap: () => context.go(AppRoutes.shopOrders),
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopKpiCard(
                  label: 'قيد المعالجة',
                  value: '${stats.pendingOrders}',
                  tone: stats.pendingOrders > 0
                      ? BadgeTone.warning
                      : BadgeTone.success,
                  onTap: () => context.go(AppRoutes.shopOrders),
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopKpiCard(
                  label: 'منتجات منشورة',
                  value: '${stats.publishedProducts}',
                  tone: BadgeTone.success,
                  onTap: () => context.go(AppRoutes.shopProducts),
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopKpiCard(
                  label: 'وحدات المخزون',
                  value: '${stats.stockUnits}',
                  tone: stats.stockUnits == 0
                      ? BadgeTone.error
                      : BadgeTone.neutral,
                  onTap: () => context.go(AppRoutes.shopProducts),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'جاهزية الكتالوج للنشر'.tr,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: AppFont.bold),
                            ),
                          ),
                          AppStatusBadge(
                            label: '${(publishRatio * 100).round()}%',
                            tone: publishRatio >= 0.7
                                ? BadgeTone.success
                                : BadgeTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ShopProgressBar(value: publishRatio),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${stats.publishedProducts} ${'منتج منشور من أصل'.tr} ${stats.products} · ${stats.stockUnits} ${'قطعة متوفرة بالمخزون'.tr}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSectionHeader(
                  title: 'وصول سريع'.tr,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopFeatureTile(
                  title: 'متابعة الطلبات',
                  subtitle: 'تحديث حالات الطلبات قيد المعالجة والشحن',
                  badge: stats.pendingOrders > 0
                      ? '${stats.pendingOrders} ${'معلق'.tr}'
                      : null,
                  badgeTone: BadgeTone.warning,
                  onTap: () => context.go(AppRoutes.shopOrders),
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopFeatureTile(
                  title: 'إدارة المنتجات والمخزون',
                  subtitle: 'مراجعة الأسعار والكميات المتوفرة ونشر المسودات',
                  onTap: () => context.go(AppRoutes.shopProducts),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroMetaItem extends StatelessWidget {
  const _HeroMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppFont.tiny,
            color: AppColors.onPrimary.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: AppFont.subtitle,
            fontWeight: AppFont.bold,
            color: AppColors.onPrimary,
          ),
        ),
      ],
    );
  }
}
