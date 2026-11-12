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

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  Widget _buildTimelineStep({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final active = isCompleted || isCurrent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? OrderDetailsDesign.timelineActive
                    : AppColors.surfaceAlt,
                border: Border.all(
                  color: active
                      ? OrderDetailsDesign.timelineActive
                      : OrderDetailsDesign.timelineInactive,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? Icon(
                      AppIcons.check,
                      size: 14,
                      color: AppColors.white,
                    )
                  : (isCurrent
                        ? Center(
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          )
                        : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted
                    ? OrderDetailsDesign.timelineActive
                    : OrderDetailsDesign.timelineInactive,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? AppFont.bold : AppFont.medium,
                  color: active ? AppColors.text : AppColors.textMuted,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(customerOrderDetailsProvider(orderId));

    return orderAsync.skeletonWhen(
      placeholder: LoadingFixtures.order,
      data: (order) {
        if (order == null) {
          return CustomerScaffold(
            title: 'تفاصيل الطلب'.tr,
            showSearch: false,
            body: AppEmpty(
              icon: AppIcons.orders,
              message: 'الطلب غير موجود'.tr,
            ),
          );
        }

        final currentStep = order.statusStep;
        final dateStr = DateFormat('yyyy/MM/dd – hh:mm a')
            .format(order.createdAt);
        final shortId = order.id.length > 8
            ? order.id.substring(0, 8).toUpperCase()
            : order.id.toUpperCase();

        return CustomerScaffold(
          title: 'طلب #$shortId'.tr,
          showSearch: false,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'المتجر: ${order.shopName}'.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: AppFont.bold,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          AppStatusBadge(
                            label: order.statusLabel,
                            tone: BadgeTone.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تاريخ الإنشاء: $dateStr'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Status Timeline Card
                Text(
                  'مراحل توصيل الشحنة'.tr,
                  style: TextStyle(
                    fontSize: SectionDesign.titleSize,
                    fontWeight: SectionDesign.titleWeight,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      _buildTimelineStep(
                        context: context,
                        title: 'تم استلام الطلب'.tr,
                        subtitle: 'تم تأكيد طلبك وإرساله للمتجر بنجاح'.tr,
                        isCompleted: currentStep > 1,
                        isCurrent: currentStep == 1,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        context: context,
                        title: 'جاري تجهيز الملابس'.tr,
                        subtitle:
                            'المتجر يقوم بتجهيز وتغليف المقاسات والألوان المطلوبة'.tr,
                        isCompleted: currentStep > 2,
                        isCurrent: currentStep == 2,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        context: context,
                        title: 'تم الشحن مع مندوب التوصيل'.tr,
                        subtitle: 'الشحنة في طريقها إلى عنوانك المحدد'.tr,
                        isCompleted: currentStep > 3,
                        isCurrent: currentStep == 3,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        context: context,
                        title: 'تم الاستلام والتسليم'.tr,
                        subtitle: 'تم تسليم الملابس للمشتري بنجاح'.tr,
                        isCompleted: currentStep >= 4,
                        isCurrent: currentStep == 4,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Items List
                Text(
                  'القطع المشتراة (${order.items.length})'.tr,
                  style: TextStyle(
                    fontSize: SectionDesign.titleSize,
                    fontWeight: SectionDesign.titleWeight,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: TextStyle(
                                        fontWeight: AppFont.bold,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    if (item.variantInfo != null)
                                      Text(
                                        'المواصفات: ${item.variantInfo}'.tr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    Text(
                                      'الكمية: ${item.quantity}'.tr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                AppFormat.price(item.totalPrice),
                                style: TextStyle(
                                  fontWeight: AppFont.bold,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الإجمالي المدفوع'.tr,
                            style: TextStyle(
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            AppFormat.price(order.total),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: AppFont.extraBold,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      error: (err, _) => CustomerScaffold(
        title: 'تفاصيل الطلب'.tr,
        showSearch: false,
        body: AppEmpty(
          icon: AppIcons.error,
          message: 'تعذر تحميل تفاصيل الطلب: $err'.tr,
        ),
      ),
    );
  }
}
