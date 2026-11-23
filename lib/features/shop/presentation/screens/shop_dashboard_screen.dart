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
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);
    final statsAsync = ref.watch(shopStatsProvider);
    final ordersAsync = ref.watch(shopOrdersProvider);
    final bannersAsync = ref.watch(shopBannersProvider);
    final currentUser = ref.watch(authControllerProvider).user;
    final busy = ref.watch(shopCatalogActionProvider).isLoading;

    final shop = shopAsync.asData?.value;
    final awaitingShop = shopAsync.isLoading && !shopAsync.hasValue;
    final approved = shop?.visibleStatus == ShopStatus.approved;

    Future<void> handleRefresh() async {
      await Future.wait([
        ref.refresh(myShopProvider.future),
        ref.refresh(shopStatsProvider.future),
        if (approved) ref.refresh(shopOrdersProvider.future),
        if (approved) ref.refresh(shopBannersProvider.future),
        ref.refresh(shopNotificationsProvider.future),
      ]);
    }

    return ShopScaffold(
      title: 'لوحة المحل'.tr,
      titleWidget: _ShopGreetingHeader(shop: shop, user: currentUser),
      showBack: false,
      body: AppRefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            if (approved)
              bannersAsync.skeletonWhen(
                placeholder: LoadingFixtures.banners,
                skipLoadingOnReload: true,
                error: (_, _) => const SizedBox.shrink(),
                data: (banners) {
                  final activeBanners = banners
                      .where((b) => b.isActive)
                      .toList();
                  if (activeBanners.isEmpty) return const SizedBox.shrink();
                  return PromoBannerCarousel(
                    banners: activeBanners,
                    onBannerTap: (_) => context.go(AppRoutes.shopBanners),
                  );
                },
              ),
            Padding(
              padding: AppSpacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            if (!awaitingShop && shop != null && !approved) ...[
              _buildApprovalBanner(context, shop),
              const SizedBox(height: AppSpacing.md),
            ] else if (!awaitingShop &&
                shop != null &&
                approved &&
                shop.isSubscriptionExpired) ...[
              ShopNoticeBanner(
                title: 'انتهت مدة اشتراك متجرك'.tr,
                message:
                    'تم إيقاف نشر المنتجات الجديدة مؤقتاً حتى تجديد الاشتراك وإرسال إشعار التحويل.'
                        .tr,
                tone: BadgeTone.error,
                actionLabel: 'تجديد الاشتراك الآن'.tr,
                onAction: () => context.push(AppRoutes.shopSales),
              ),
              const SizedBox(height: AppSpacing.md),
            ] else if (!awaitingShop &&
                shop != null &&
                approved &&
                shop.isSubscriptionActive &&
                shop.subscriptionDaysRemaining > 0 &&
                shop.subscriptionDaysRemaining <= 5) ...[
              ShopNoticeBanner(
                title: 'اقترب موعد تجديد اشتراكك'.tr,
                message: AppLang.isEn
                    ? '${shop.subscriptionDaysRemaining} days remaining in your subscription. Renew early to keep publishing.'
                    : 'متبقي ${shop.subscriptionDaysRemaining} أيام على انتهاء اشتراكك. يمكنك التجديد مبكراً دون انقطاع.',
                tone: BadgeTone.warning,
                actionLabel: 'تجديد الاشتراك'.tr,
                onAction: () => context.push(AppRoutes.shopSales),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            statsAsync.skeletonWhen(
              placeholder: LoadingFixtures.shopStats,
              skipLoadingOnReload: true,
              error: (_, _) => ShopNoticeBanner(
                title: 'تعذر تحميل الإحصائيات',
                message: 'اسحب للأسفل لتحديث بيانات المتجر.',
                tone: BadgeTone.error,
              ),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShopFeatureTile(
                    title: 'المنتجات',
                    subtitle: 'إضافة وتعديل المنتجات والمخزون',
                    trailingValue: '${stats.products}',
                    onTap: () => context.go(AppRoutes.shopProducts),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ShopFeatureTile(
                    title: 'الطلبات',
                    subtitle: 'متابعة طلبات المحل وتحديث حالتها',
                    trailingValue: '${stats.orders}',
                    onTap: () => context.go(AppRoutes.shopOrders),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ShopFeatureTile(
                    title: 'بنرات المتجر',
                    subtitle: 'إدارة بنرات العروض والإعلانات الخاصة بمتجرك',
                    trailingValue: '${bannersAsync.asData?.value.length ?? 0}',
                    onTap: () => context.go(AppRoutes.shopBanners),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ShopFeatureTile(
                    title: 'الاشتراك والكشف المالي',
                    subtitle: 'كشف حسابك 100% بدون عمولة وحالة الاشتراك',
                    trailingValue: AppFormat.price(stats.salesTotal),
                    onTap: () => context.push(AppRoutes.shopSales),
                  ),
                ],
              ),
            ),
            if (approved) ...[
              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(
                title: 'طلبات اليوم'.tr,
                actionLabel: 'عرض الكل'.tr,
                onAction: () => context.go(AppRoutes.shopOrders),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.sm),
              ordersAsync.skeletonWhen(
                placeholder: LoadingFixtures.shopOrders,
                skipLoadingOnReload: true,
                error: (_, _) => ShopNoticeBanner(
                  title: 'تعذر تحميل الطلبات',
                  message: 'افتح صفحة الطلبات لإعادة المحاولة.',
                  tone: BadgeTone.error,
                  actionLabel: 'الطلبات',
                  onAction: () => context.go(AppRoutes.shopOrders),
                ),
                data: (orders) {
                  final now = DateTime.now();
                  final todayOrders =
                      orders
                          .where((o) => _isSameDay(o.createdAt.toLocal(), now))
                          .toList()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                        if (todayOrders.isEmpty) {
                          return const ShopEmptyState(
                            title: 'لا توجد طلبات اليوم',
                            message:
                                'ستظهر هنا جميع طلبات اليوم منذ بداية الدوام وحتى نهاية اليوم.',
                          );
                        }

                        final todayTotal = todayOrders.fold<double>(
                          0,
                          (sum, o) => sum + o.total,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ShopKpiCard(
                              label:
                                  '${'إجمالي اليوم'.tr} (${todayOrders.length})',
                              value: AppFormat.price(todayTotal),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            for (final order in todayOrders)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: ShopOrderCard(
                                  order: order,
                                  onTap: busy
                                      ? null
                                      : () => showShopOrderStatusSheet(
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
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalBanner(BuildContext context, Shop shop) {
    switch (shop.visibleStatus) {
      case ShopStatus.draft:
        return ShopNoticeBanner(
          title: 'أكمل ملف متجرك للبدء',
          message:
              'استكمل بيانات المتجر وأرسل طلب الانضمام لتتمكن من نشر منتجاتك واستقبال الطلبات.',
          tone: BadgeTone.primary,
          actionLabel: 'استكمال البيانات',
          onAction: () => context.push(AppRoutes.shopCompleteProfile),
        );
      case ShopStatus.pending:
        return ShopNoticeBanner(
          title: 'طلبك قيد المراجعة',
          message:
              'تقوم الإدارة بمراجعة بيانات متجرك حالياً. ستتمكن من البيع فور الموافقة.',
          tone: BadgeTone.warning,
          actionLabel: 'متابعة الحالة',
          onAction: () => context.push(AppRoutes.shopStatus),
        );
      case ShopStatus.rejected:
        return ShopNoticeBanner(
          title: 'يحتاج طلبك إلى تعديل',
          message:
              shop.visibleRejectionReason ??
              'يرجى مراجعة بيانات المتجر وتحديثها ثم إعادة التقديم.',
          tone: BadgeTone.error,
          actionLabel: 'تعديل وإعادة التقديم',
          onAction: () => context.push(AppRoutes.shopCompleteProfile),
        );
      case ShopStatus.suspended:
        return ShopNoticeBanner(
          title: 'المتجر موقوف مؤقتاً',
          message: 'يرجى التواصل مع الإدارة لمراجعة حالة المتجر.',
          tone: BadgeTone.error,
          actionLabel: 'عرض الحالة',
          onAction: () => context.push(AppRoutes.shopStatus),
        );
      case ShopStatus.approved:
        return const SizedBox.shrink();
    }
  }
}

class _ShopGreetingHeader extends StatelessWidget {
  const _ShopGreetingHeader({required this.shop, required this.user});

  final Shop? shop;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final rawName = shop?.name.trim() ?? '';
    final shopName = rawName.isNotEmpty ? rawName : 'متجري'.tr;
    final email = (user?.email.trim().isNotEmpty ?? false)
        ? user!.email.trim()
        : (shop?.ownerEmail?.trim() ?? '');
    final city = shop?.city?.trim() ?? '';
    final address = shop?.address?.trim() ?? '';
    final location = city.isNotEmpty ? city : address;
    final status = shop?.visibleStatus;
    final statusColor = status == null
        ? AppColors.textMuted
        : switch (status) {
            ShopStatus.approved => AppColors.success,
            ShopStatus.pending => AppColors.warning,
            ShopStatus.rejected || ShopStatus.suspended => AppColors.error,
            ShopStatus.draft => AppColors.textMuted,
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${'مرحباً'.tr}${AppLang.isEn ? ',' : '،'} $shopName 👋',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: AppBarDesign.titleWeight,
            color: AppBarDesign.titleColor,
            height: 1.15,
          ),
        ),
        if (email.isNotEmpty || location.isNotEmpty || status != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (email.isNotEmpty)
                Flexible(
                  flex: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.mail,
                        size: 11.5,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (email.isNotEmpty && location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '·',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: AppFont.bold,
                    ),
                  ),
                ),
              if (location.isNotEmpty)
                Flexible(
                  flex: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.location,
                        size: 11.5,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (status != null && (email.isNotEmpty || location.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '·',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: AppFont.bold,
                    ),
                  ),
                ),
              if (status != null)
                Text(
                  status.labelAr.tr,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: AppFont.bold,
                    color: statusColor,
                    height: 1.15,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
