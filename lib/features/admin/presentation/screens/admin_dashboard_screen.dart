import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/promo_banner_carousel.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';
import '../widgets/decart_credits_badge.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final statsAsync = ref.watch(adminStatsProvider);
    final bannersAsync = ref.watch(adminBannersProvider);
    final ordersAsync = ref.watch(adminOrdersProvider);
    final regionsAsync = ref.watch(adminGazaRegionsProvider);
    final subOverviewAsync = ref.watch(adminSubscriptionPayoutOverviewProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    Future<void> handleRefresh() async {
      await Future.wait([
        ref.refresh(adminStatsProvider.future),
        ref.refresh(adminBannersProvider.future),
        ref.refresh(adminOrdersProvider.future),
        ref.refresh(adminGazaRegionsProvider.future),
        ref.refresh(adminSubscriptionPayoutOverviewProvider.future),
        ref.refresh(adminShopApplicationsProvider.future),
        ref.refresh(adminTryonControlsProvider.future),
        ref.refresh(adminDecartCreditsProvider.future),
        ref.refresh(adminViduCreditsProvider.future),
      ]);
    }

    return AdminScaffold(
      title: 'لوحة الإدارة'.tr,
      titleWidget: AdminGreetingHeader(user: user),
      showBack: false,
      actions: [
        const Center(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: 2),
            child: DecartCreditsAppBarChip(),
          ),
        ),
        IconButton(
          tooltip: 'الإشعارات'.tr,
          onPressed: AppHaptics.action(
            () => context.push(AppRoutes.adminNotifications),
          ),
          icon: Icon(AppIcons.bell, color: AppBarDesign.iconColor),
        ),
      ],
      body: AppRefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // 1) Live Customer Banner Carousel Preview (exact customer appearance)
            bannersAsync.skeletonWhen(
              placeholder: LoadingFixtures.banners,
              skipLoadingOnReload: true,
              error: (_, _) => const SizedBox.shrink(),
              data: (banners) {
                final active = banners.where((b) => b.isActive).toList();
                if (active.isEmpty) return const SizedBox.shrink();
                return PromoBannerCarousel(
                  banners: active,
                  onBannerTap: (_) => context.go(AppRoutes.adminBanners),
                );
              },
            ),

            Padding(
              padding: AppSpacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  statsAsync.skeletonWhen(
                    placeholder: LoadingFixtures.adminStats,
                    skipLoadingOnReload: true,
                    error: (_, _) => AdminNoticeBanner(
                      title: 'تعذر تحميل إحصائيات المنصة',
                      message: 'اسحب للأسفل لإعادة تحميل البيانات.',
                      tone: BadgeTone.error,
                    ),
                    data: (stats) {
                      final totalRegions = stats.regionsTotal > 0
                          ? stats.regionsTotal
                          : (regionsAsync.asData?.value.length ?? 0);
                      final activeRegions = stats.activeRegions > 0
                          ? stats.activeRegions
                          : (regionsAsync.asData?.value
                                    .where(
                                      (r) => r.isActive && r.isDeliveryAvailable,
                                    )
                                    .length ??
                                0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (stats.pendingShops > 0) ...[
                            AdminNoticeBanner(
                              title:
                                  '${'طلبات انضمام بانتظار المراجعة'.tr} (${stats.pendingShops})',
                              message:
                                  'هناك متاجر جديدة تنتظر قرار الإدارة بالقبول أو الرفض.',
                              tone: BadgeTone.warning,
                              actionLabel: 'مراجعة الطلبات',
                              onAction: () =>
                                  context.push(AppRoutes.adminShopApplications),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // 2) Key KPI Row 1 & 2
                          Row(
                            children: [
                              Expanded(
                                child: AdminKpiCard(
                                  label: 'إجمالي المبيعات',
                                  value: AppFormat.price(stats.totalSales),
                                  subtitle: '${stats.orders} ${'طلب'.tr}',
                                  onTap: () =>
                                      context.go(AppRoutes.adminOrders),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AdminKpiCard(
                                  label: 'المحلات المعتمدة',
                                  value: '${stats.approvedShops}',
                                  subtitle: stats.pendingShops > 0
                                      ? '${stats.pendingShops} ${'قيد المراجعة'.tr}'
                                      : '${stats.shops} ${'إجمالي المحلات'.tr}',
                                  onTap: () =>
                                      context.go(AppRoutes.adminShopsManage),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: AdminKpiCard(
                                  label: 'العملاء المسجلون',
                                  value: '${stats.customers}',
                                  onTap: () =>
                                      context.push(AppRoutes.adminUsers),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AdminKpiCard(
                                  label: 'المنتجات والعروض',
                                  value: '${stats.products}',
                                  subtitle:
                                      '${stats.activeOffers} ${'عرض نشط'.tr}',
                                  onTap: () =>
                                      context.push(AppRoutes.adminProducts),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // 3) Organized Control Sections
                          AppSectionHeader(
                            title: 'أقسام التحكم والإدارة'.tr,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          AdminFeatureTile(
                            title: 'الاشتراكات والكشف المالي للمحلات',
                            subtitle:
                                'إيرادات الاشتراكات، مراجعة الإشعارات، ومستحقات المحلات (100%)',
                            badge:
                                (subOverviewAsync
                                            .asData
                                            ?.value
                                            .pendingSubscriptionsCount ??
                                        0) >
                                    0
                                ? '${subOverviewAsync.asData!.value.pendingSubscriptionsCount} ${'اشتراك'.tr}'
                                : null,
                            badgeTone: BadgeTone.warning,
                            trailingValue: AppFormat.price(
                              subOverviewAsync
                                      .asData
                                      ?.value
                                      .totalOwedToShops ??
                                  0,
                            ),
                            onTap: () => context.push(AppRoutes.adminRevenue),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'باقات اشتراك المحلات',
                            subtitle:
                                'تحديد قيمة ومدد باقات الاشتراك (مثال: 30 ₪ شهرياً) بدون عمولة',
                            onTap: () => context.push(
                              AppRoutes.adminSubscriptionPlans,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'مناطق قطاع غزة والتوصيل',
                            subtitle:
                                'المحافظات الخمس والأحياء ورسوم وحالة التوصيل',
                            trailingValue: '$activeRegions/$totalRegions',
                            onTap: () => context.push(AppRoutes.adminRegions),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'طرق الدفع وحسابات التحويل (غزة)',
                            subtitle:
                                'أرقام بنك فلسطين والمحافظ الإلكترونية لتحويل الطلبات والاشتراكات',
                            onTap: () =>
                                context.push(AppRoutes.adminPaymentMethods),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'طلبات انضمام المحلات',
                            subtitle: 'مراجعة الوثائق وقبول أو رفض المتاجر',
                            badge: stats.pendingShops > 0
                                ? '${stats.pendingShops}'
                                : null,
                            badgeTone: BadgeTone.warning,
                            trailingValue: stats.pendingShops == 0
                                ? '${stats.shops}'
                                : null,
                            onTap: () =>
                                context.push(AppRoutes.adminShopApplications),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'التصنيفات الرئيسية والفرعية',
                            subtitle: 'تنظيم أقسام المتجر والمنتجات',
                            trailingValue: '${stats.categories}',
                            onTap: () =>
                                context.push(AppRoutes.adminCategories),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'جميع المنتجات',
                            subtitle: 'مراجعة المنتجات وإخفاء أو حذف المخالف',
                            badge: stats.hiddenProducts > 0
                                ? '${stats.hiddenProducts} ${'مخفي'.tr}'
                                : null,
                            badgeTone: BadgeTone.warning,
                            trailingValue: '${stats.products}',
                            onTap: () => context.push(AppRoutes.adminProducts),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'إدارة المستخدمين',
                            subtitle: 'العملاء وأصحاب المحلات وحالة الحسابات',
                            trailingValue: '${stats.customers}',
                            onTap: () => context.push(AppRoutes.adminUsers),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'الإشعارات الجماعية والموجهة',
                            subtitle:
                                'إرسال تنبيهات للجميع أو لمناطق محددة في غزة',
                            trailingValue: '${stats.notifications}',
                            onTap: () =>
                                context.push(AppRoutes.adminNotifications),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AdminFeatureTile(
                            title: 'التقارير والإحصائيات المفصلة',
                            subtitle:
                                'أداء المنصة وتوزيع المحلات والطلبات في غزة',
                            onTap: () => context.push(AppRoutes.adminReports),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // 4) Today's Orders across the platform
                  AppSectionHeader(
                    title: 'طلبات اليوم'.tr,
                    actionLabel: 'عرض الكل'.tr,
                    onAction: () => context.go(AppRoutes.adminOrders),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ordersAsync.skeletonWhen(
                    placeholder: LoadingFixtures.adminOrders,
                    skipLoadingOnReload: true,
                    error: (_, _) => AdminNoticeBanner(
                      title: 'تعذر تحميل الطلبات',
                      message: 'افتح صفحة الطلبات لإعادة المحاولة.',
                      tone: BadgeTone.error,
                      actionLabel: 'الطلبات',
                      onAction: () => context.go(AppRoutes.adminOrders),
                    ),
                    data: (orders) {
                      final now = DateTime.now();
                      final todayOrders =
                          orders
                              .where(
                                (o) => _isSameDay(o.createdAt.toLocal(), now),
                              )
                              .toList()
                            ..sort(
                              (a, b) => b.createdAt.compareTo(a.createdAt),
                            );

                      if (todayOrders.isEmpty) {
                        return const AdminEmptyState(
                          title: 'لا توجد طلبات اليوم',
                          message:
                              'ستظهر هنا جميع طلبات المنصة المسجلة خلال اليوم.',
                        );
                      }

                      final todayTotal = todayOrders
                          .where((o) => o.status != 'cancelled')
                          .fold<double>(0, (sum, o) => sum + o.total);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AdminKpiCard(
                            label:
                                '${'إجمالي اليوم'.tr} (${todayOrders.length})',
                            value: AppFormat.price(todayTotal),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final order in todayOrders.take(10))
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: AdminOrderCard(
                                order: order,
                                onTap: busy
                                    ? null
                                    : () => showAdminOrderStatusSheet(
                                        context,
                                        ref,
                                        order,
                                      ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
