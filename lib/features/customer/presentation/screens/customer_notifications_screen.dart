import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerNotificationsScreen extends ConsumerWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(customerNotificationsProvider);

    return CustomerScaffold(
      title: 'الإشعارات'.tr,
      showSearch: false,
      body: RefreshIndicator.noSpinner(
        onRefresh: AppHaptics.refresh(() async {
          ref.invalidate(customerNotificationsProvider);
        }),
        child: notificationsAsync.skeletonWhen(
          placeholder: LoadingFixtures.notifications,
          data: (notifications) {
            if (notifications.isEmpty) {
              return AppEmpty(
                icon: AppIcons.bell,
                title: 'لا توجد إشعارات جديدة'.tr,
                message: 'ستصلك هنا العروض الحصرية وتحديثات طلباتك'.tr,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: notifications.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final dateStr = DateFormat('yyyy/MM/dd – hh:mm a')
                    .format(notif.createdAt);

                return AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: NotificationsDesign.iconBoxSize,
                        height: NotificationsDesign.iconBoxSize,
                        decoration: BoxDecoration(
                          color: NotificationsDesign.iconBackground,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.bellActive,
                          color: NotificationsDesign.icon,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: AppFont.bold,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          error: (err, _) => AppEmpty(
            icon: AppIcons.error,
            message: 'تعذر تحميل الإشعارات: $err'.tr,
          ),
        ),
      ),
    );
  }
}
