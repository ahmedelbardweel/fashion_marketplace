import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
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
                color: isCompleted || isCurrent ? AppColors.black : AppColors.gray100,
                border: Border.all(
                  color: isCompleted || isCurrent ? AppColors.black : AppColors.border,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: AppColors.white)
                  : (isCurrent
                      ? const Center(
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
                color: isCompleted ? AppColors.black : AppColors.border,
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted || isCurrent
                          ? AppColors.black
                          : AppColors.gray500,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.gray500),
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

    return orderAsync.when(
      data: (order) {
        if (order == null) {
          return const CustomerScaffold(
            title: 'تفاصيل الطلب',
            body: Center(child: Text('الطلب غير موجود')),
          );
        }

        final currentStep = order.statusStep;
        final dateStr =
            DateFormat('yyyy/MM/dd – hh:mm a').format(order.createdAt);

        return CustomerScaffold(
          title: 'طلب #${order.id.substring(0, 8).toUpperCase()}',
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
                          Text(
                            'المتجر: ${order.shopName}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            order.statusLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ الإنشاء: $dateStr',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.gray500),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Status Timeline Card
                Text(
                  'مراحل توصيل الشحنة',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      _buildTimelineStep(
                        context: context,
                        title: 'تم استلام الطلب',
                        subtitle: 'تم تأكيد طلبك وإرساله للمتجر بنجاح',
                        isCompleted: currentStep > 1,
                        isCurrent: currentStep == 1,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        context: context,
                        title: 'جاري تجهيز الملابس',
                        subtitle: 'المتجر يقوم بتجهيز وتغليف المقاسات والألوان المطلوبة',
                        isCompleted: currentStep > 2,
                        isCurrent: currentStep == 2,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        context: context,
                        title: 'تم الشحن مع مندوب التوصيل',
                        subtitle: 'الشحنة في طريقها إلى عنوانك المحدد',
                        isCompleted: currentStep > 3,
                        isCurrent: currentStep == 3,
                        isLast: false,
                      ),
                      _buildTimelineStep(
                        context: context,
                        title: 'تم الاستلام والتسليم',
                        subtitle: 'تم تسليم الملابس للمشتري بنجاح',
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
                  'القطع المشتراة (${order.items.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: [
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (item.variantInfo != null)
                                      Text(
                                        'المواصفات: ${item.variantInfo}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppColors.gray500),
                                      ),
                                    Text(
                                      'الكمية: ${item.quantity}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${item.totalPrice.toStringAsFixed(2)} ر.س',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي المدفوع'),
                          Text(
                            '${order.total.toStringAsFixed(2)} ر.س',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
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
      loading: () => const CustomerScaffold(
        title: 'جاري التحميل...',
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => CustomerScaffold(
        title: 'خطأ',
        body: Center(child: Text('تعذر تحميل تفاصيل الطلب: $err')),
      ),
    );
  }
}
