import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  BadgeTone _toneForStatus(String status) {
    return switch (status) {
      'completed' || 'delivered' => BadgeTone.success,
      'cancelled' || 'rejected' => BadgeTone.error,
      'shipped' || 'processing' => BadgeTone.primary,
      _ => BadgeTone.warning,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return CustomerScaffold(
      title: 'طلباتي'.tr,
      currentNavIndex: 3,
      showBack: false,
      body: RefreshIndicator.noSpinner(
        onRefresh: AppHaptics.refresh(() async {
          ref.invalidate(customerOrdersProvider);
        }),
        child: ordersAsync.skeletonWhen(
          placeholder: LoadingFixtures.orders,
          data: (orders) {
            if (orders.isEmpty) {
              return AppEmpty(
                icon: AppIcons.orders,
                title: 'لا توجد طلبات سابقة'.tr,
                message: 'عندما تشتري أي ملابس ستتمكن من تتبع شحنتها هنا فوراً'.tr,
                actionLabel: 'تصفح الأزياء الآن'.tr,
                onAction: AppHaptics.action(
                  () => context.go(AppRoutes.customerCatalog),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: orders.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final order = orders[index];
                final dateStr = DateFormat('yyyy/MM/dd – hh:mm a')
                    .format(order.createdAt);
                final shortId = order.id.length > 8
                    ? order.id.substring(0, 8).toUpperCase()
                    : order.id.toUpperCase();

                return AppCard(
                  onTap: () => context.push(
                    AppRoutes.customerOrderDetailsPath(order.id),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'طلب #$shortId'.tr,
                            style: TextStyle(
                              fontSize: OrdersDesign.orderNumberSize,
                              fontWeight: OrdersDesign.orderNumberWeight,
                              color: AppColors.text,
                            ),
                          ),
                          AppStatusBadge(
                            label: order.statusLabel,
                            tone: _toneForStatus(order.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            AppIcons.shop,
                            size: 15,
                            color: AppColors.icon,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            order.shopName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: AppFont.semiBold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: OrdersDesign.dateColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${order.items.length} قطع'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            AppFormat.price(order.total),
                            style: TextStyle(
                              fontSize: OrdersDesign.totalSize,
                              fontWeight: OrdersDesign.totalWeight,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
          error: (err, _) => AppEmpty(
            icon: AppIcons.error,
            message: 'تعذر تحميل الطلبات: $err'.tr,
          ),
        ),
      ),
    );
  }
}
