import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final stats = ref.watch(adminStatsProvider);
    final pending = stats.asData?.value.pendingShops;

    final features = <_AdminFeature>[
      _AdminFeature(
        code: 'ADM-02',
        title: 'إحصائيات التطبيق',
        subtitle: 'نظرة عامة على المستخدمين والمحلات والمنتجات',
        route: AppRoutes.adminStats,
        badge: stats.asData?.value.customers.toString(),
      ),
      _AdminFeature(
        code: 'ADM-03',
        title: 'طلبات انضمام المحلات',
        subtitle: 'مراجعة الطلبات الجديدة وقبولها أو رفضها',
        route: AppRoutes.adminShopApplications,
        badge: pending == null || pending == 0 ? null : pending.toString(),
      ),
      _AdminFeature(
        code: 'ADM-07',
        title: 'تصنيفات المنتجات',
        subtitle: 'إضافة وتعديل وتفعيل التصنيفات',
        route: AppRoutes.adminCategories,
      ),
      _AdminFeature(
        code: 'ADM-08',
        title: 'جميع المنتجات',
        subtitle: 'عرض المنتجات وإخفاء أو حذف المخالف منها',
        route: AppRoutes.adminProducts,
      ),
      _AdminFeature(
        code: 'ADM-10',
        title: 'إدارة المستخدمين',
        subtitle: 'تعليق أو تفعيل حسابات المستخدمين والمحلات',
        route: AppRoutes.adminUsers,
      ),
      _AdminFeature(
        code: 'ADM-14',
        title: 'إدارة المحلات',
        subtitle: 'تعليق أو إعادة تفعيل المحلات المعتمدة',
        route: AppRoutes.adminShopsManage,
      ),
      _AdminFeature(
        code: 'ADM-11',
        title: 'متابعة الطلبات',
        subtitle: 'عرض كل طلبات المنصة وحالاتها',
        route: AppRoutes.adminOrders,
      ),
      _AdminFeature(
        code: 'ADM-12',
        title: 'العروض والبنرات',
        subtitle: 'إدارة البنرات الظاهرة في الصفحة الرئيسية',
        route: AppRoutes.adminBanners,
      ),
      _AdminFeature(
        code: 'ADM-13',
        title: 'الإشعارات',
        subtitle: 'إرسال إشعارات للمستخدمين أو المحلات',
        route: AppRoutes.adminNotifications,
      ),
      _AdminFeature(
        code: 'ADM-15',
        title: 'التقارير',
        subtitle: 'تقارير ملخصة لأداء المنصة',
        route: AppRoutes.adminReports,
      ),
      _AdminFeature(
        code: 'ADM-16',
        title: 'إعدادات المنصة',
        subtitle: 'اسم التطبيق وسياسة ظهور القرارات',
        route: AppRoutes.adminSettings,
      ),
    ];

    return AdminScaffold(
      title: 'لوحة الإدارة',
      showBack: false,
      body: RefreshIndicator(
        color: AppColors.black,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          ref.invalidate(adminShopApplicationsProvider);
          await ref.read(adminStatsProvider.future);
        },
        child: ListView(
          padding: AppSpacing.page,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTROL CENTER',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.gray500,
                          letterSpacing: 1.4,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user?.displayName ?? 'الإدارة',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'اختر ميزة للانتقال إلى واجهتها الخاصة',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AdminFeatureTile(
                  code: feature.code,
                  title: feature.title,
                  subtitle: feature.subtitle,
                  badge: feature.badge,
                  onTap: () => context.push(feature.route),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminFeature {
  const _AdminFeature({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.route,
    this.badge,
  });

  final String code;
  final String title;
  final String subtitle;
  final String route;
  final String? badge;
}
