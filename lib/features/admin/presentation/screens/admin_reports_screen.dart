import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  bool _matchesGov(String? text, GazaGovernorateGroup group) {
    final c = text?.trim().toLowerCase() ?? '';
    if (c.isEmpty) return false;
    if (c.contains(group.governorate.name.toLowerCase())) return true;
    if (group.governorate.nameEn != null &&
        c.contains(group.governorate.nameEn!.toLowerCase())) {
      return true;
    }
    return group.areas.any(
      (a) =>
          c.contains(a.name.toLowerCase()) ||
          (a.nameEn != null && c.contains(a.nameEn!.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final orders = ref.watch(adminOrdersProvider).asData?.value ?? const [];
    final shops = ref.watch(adminManagedShopsProvider).asData?.value ?? const [];
    final users = ref.watch(adminUsersProvider).asData?.value ?? const [];
    final regions =
        ref.watch(adminGazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;

    final groups = groupGazaRegions(regions);

    Future<void> refreshAll() async {
      await Future.wait([
        ref.refresh(adminStatsProvider.future),
        ref.refresh(adminOrdersProvider.future),
        ref.refresh(adminManagedShopsProvider.future),
        ref.refresh(adminUsersProvider.future),
        ref.refresh(adminGazaRegionsProvider.future),
      ]);
    }

    return AdminScaffold(
      title: 'التقارير والإحصائيات'.tr,
      showBack: true,
      showBottomNav: false,
      body: AppRefreshIndicator(
        onRefresh: refreshAll,
        child: statsAsync.skeletonWhen(
          placeholder: LoadingFixtures.adminStats,
          error: (err, _) => ListView(
            padding: AppSpacing.page,
            children: [
              AdminNoticeBanner(
                title: 'تعذر تحميل التقارير',
                message: ref.read(adminRepositoryProvider).mapError(err),
                tone: BadgeTone.error,
                actionLabel: 'إعادة المحاولة',
                onAction: () => ref.invalidate(adminStatsProvider),
              ),
            ],
          ),
          data: (stats) {
            final deliveredOrders = orders
                .where((o) => o.status == 'delivered')
                .length;
            final cancelledOrders = orders
                .where((o) => o.status == 'cancelled')
                .length;
            final activeOrders =
                orders.length - deliveredOrders - cancelledOrders;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                AppSectionHeader(
                  title: 'ملخص الأداء العام'.tr,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'إجمالي المبيعات',
                        value: AppFormat.price(stats.totalSales),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'مبيعات اليوم',
                        value: AppFormat.price(stats.todaySales),
                        subtitle: '${stats.todayOrders} ${'طلب'.tr}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'العملاء',
                        value: '${stats.customers}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'العروض النشطة',
                        value: '${stats.activeOffers}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                AppSectionHeader(
                  title: 'توزيع حالات الطلبات'.tr,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'قيد التنفيذ',
                        value: '$activeOrders',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'تم التسليم',
                        value: '$deliveredOrders',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'ملغاة',
                        value: '$cancelledOrders',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                AppSectionHeader(
                  title: 'التوزيع حسب محافظات قطاع غزة'.tr,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final group in groups) ...[
                  _GazaGovernorateReportCard(
                    governorateName: AppLang.isEn
                        ? (group.governorate.nameEn ?? group.governorate.name)
                        : group.governorate.name,
                    shopsCount: shops
                        .where((s) => _matchesGov(s.city, group))
                        .length,
                    usersCount: users
                        .where((u) => _matchesGov(u.city, group))
                        .length,
                    ordersCount: orders
                        .where(
                          (o) =>
                              _matchesGov(o.shippingCity, group) ||
                              _matchesGov(o.shopCity, group),
                        )
                        .length,
                    deliveryAvailable: group.governorate.isDeliveryAvailable,
                    deliveryFee: group.governorate.deliveryFee,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GazaGovernorateReportCard extends StatelessWidget {
  const _GazaGovernorateReportCard({
    required this.governorateName,
    required this.shopsCount,
    required this.usersCount,
    required this.ordersCount,
    required this.deliveryAvailable,
    required this.deliveryFee,
  });

  final String governorateName;
  final int shopsCount;
  final int usersCount;
  final int ordersCount;
  final bool deliveryAvailable;
  final double deliveryFee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  governorateName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: AppFont.bold),
                ),
              ),
              AppStatusBadge(
                label: deliveryAvailable ? 'التوصيل متاح' : 'متوقف مؤقتاً',
                tone: deliveryAvailable ? BadgeTone.success : BadgeTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$shopsCount ${'محل'.tr}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFont.semiBold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$usersCount ${'مستخدم'.tr}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFont.semiBold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$ordersCount ${'طلب'.tr}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFont.semiBold,
                  ),
                ),
              ),
              Text(
                AppFormat.price(deliveryFee),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: AppFont.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
