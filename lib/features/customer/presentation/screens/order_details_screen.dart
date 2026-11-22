import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../domain/models/customer_order.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _resubmitting = false;

  BadgeTone _paymentTone(CustomerOrder order) {
    if (order.isPaymentVerified) return BadgeTone.success;
    if (order.hasPaymentIssue) return BadgeTone.error;
    if (order.isPaymentPending) return BadgeTone.warning;
    return BadgeTone.neutral;
  }

  Future<void> _resubmitReceipt({
    required CustomerOrder order,
    required bool fromCamera,
  }) async {
    if (_resubmitting) return;
    final picked = fromCamera
        ? await MediaPicker.pickFromCamera()
        : await MediaPicker.pickImage();
    if (picked == null || !mounted) return;

    setState(() => _resubmitting = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final url = await repo.uploadPaymentReceipt(
        bytes: picked.bytes,
        fileName: picked.fileName,
        contentType: picked.contentType,
      );
      await repo.resubmitPaymentReceipt(
        orderId: order.id,
        receiptUrl: url,
      );
      ref.invalidate(customerOrderDetailsProvider(widget.orderId));
      ref.invalidate(customerOrdersProvider);
      if (!mounted) return;
      AppHaptics.success();
      showAppSnackBar(
        context,
        'تم رفع إشعار الحوالة الجديد وإرساله للمتجر للمراجعة'.tr,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(customerRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _resubmitting = false);
    }
  }

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
                  ? Icon(AppIcons.check, size: 14, color: AppColors.white)
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
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(customerOrderDetailsProvider(widget.orderId));
    final activeMethods =
        ref.watch(activePaymentMethodsProvider).asData?.value ?? const [];

    return orderAsync.skeletonWhen(
      placeholder: LoadingFixtures.order,
      data: (order) {
        if (order == null) {
          return CustomerScaffold(
            title: 'تفاصيل الطلب'.tr,
            body: AppEmpty(
              icon: AppIcons.orders,
              message: 'الطلب غير موجود'.tr,
            ),
          );
        }

        final currentStep = order.statusStep;
        final dateStr = DateFormat('yyyy/MM/dd – hh:mm a').format(
          order.createdAt,
        );
        final shortId = order.id.length > 8
            ? order.id.substring(0, 8).toUpperCase()
            : order.id.toUpperCase();

        return CustomerScaffold(
          title: 'طلب #$shortId'.tr,
          body: AppRefreshIndicator(
            onRefresh: () => ref.refresh(
              customerOrderDetailsProvider(widget.orderId).future,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Payment Issue Alert + Quick Re-upload
                  if (order.hasPaymentIssue &&
                      order.status != 'cancelled' &&
                      order.status != 'delivered') ...[
                    AppCard(
                      backgroundColor: AppColors.errorSoft,
                      borderColor: AppColors.error.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                IconsaxPlusLinear.warning_2,
                                color: AppColors.error,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'توجد مشكلة في إشعار الحوالة'.tr,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: AppFont.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            (order.paymentIssueNote?.trim().isNotEmpty ?? false)
                                ? order.paymentIssueNote!.trim()
                                : 'يرجى مراجعة المبلغ المحوّل ورفع صورة واضحة لإشعار الحوالة.'
                                      .tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.text,
                              height: 1.45,
                            ),
                          ),
                          if (order.paymentAccountNumber != null &&
                              order.paymentAccountNumber!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            InkWell(
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: order.paymentAccountNumber!.trim(),
                                  ),
                                );
                                AppHaptics.selection();
                                if (context.mounted) {
                                  showAppSnackBar(
                                    context,
                                    'تم نسخ رقم الحساب / المحفظة'.tr,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${order.paymentMethodName ?? ''}: ${order.paymentAccountNumber}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: AppFont.bold,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'رفع إشعار من المعرض'.tr,
                                  isLoading: _resubmitting,
                                  onPressed: () => _resubmitReceipt(
                                    order: order,
                                    fromCamera: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: AppButton(
                                  label: 'تصوير الإشعار'.tr,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: _resubmitting
                                      ? null
                                      : () => _resubmitReceipt(
                                          order: order,
                                          fromCamera: true,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (activeMethods.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'المبلغ الإجمالي المطلوب: ${AppFormat.price(order.total)}'
                                  .tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: AppFont.semiBold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

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
                                '${'المتجر'.tr}: ${order.shopName}',
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
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            AppStatusBadge(
                              label: order.deliveryModeLabel,
                              tone: order.isCustomerPickup
                                  ? BadgeTone.neutral
                                  : BadgeTone.primary,
                            ),
                            if (order.paymentStatus != 'not_required')
                              AppStatusBadge(
                                label: order.paymentStatusLabel,
                                tone: _paymentTone(order),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${'تاريخ الإنشاء'.tr}: $dateStr',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (order.deliveryAddress != null &&
                            order.deliveryAddress!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${'عنوان التوصيل'.tr}: ${order.deliveryAddress}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (order.phone != null &&
                            order.phone!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${'رقم الهاتف'.tr}: ${order.phone}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (order.notes != null &&
                            order.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${'ملاحظات'.tr}: ${order.notes}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Transfer Receipt Card
                  if (order.hasReceipt ||
                      (order.paymentMethodName?.trim().isNotEmpty ??
                          false)) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'الحوالة المالية وإشعار الدفع'.tr,
                      style: TextStyle(
                        fontSize: SectionDesign.titleSize,
                        fontWeight: SectionDesign.titleWeight,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  order.paymentMethodName ??
                                      'حوالة بنكية / محفظة'.tr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: AppFont.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              AppStatusBadge(
                                label: order.paymentStatusLabel,
                                tone: _paymentTone(order),
                              ),
                            ],
                          ),
                          if (order.paymentAccountNumber != null &&
                              order.paymentAccountNumber!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${'رقم الحساب / المحفظة'.tr}: ${order.paymentAccountNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          if (order.hasReceipt) ...[
                            const SizedBox(height: AppSpacing.sm),
                            ReceiptThumbnailCard(
                              imageUrl: order.paymentReceiptUrl!,
                              subtitle: '${'إشعار حوالة طلب'.tr} #$shortId',
                              height: 156,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Status Timeline Card
                  Text(
                    order.isCustomerPickup
                        ? 'مراحل تجهيز واستلام الطلب'.tr
                        : 'مراحل توصيل الشحنة'.tr,
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
                          title: order.isPaymentPending
                              ? 'بانتظار تأكيد إشعار الحوالة'.tr
                              : order.hasPaymentIssue
                              ? 'بانتظار تحديث إشعار الحوالة'.tr
                              : 'تم تأكيد الحوالة والطلب'.tr,
                          subtitle: order.isPaymentPending
                              ? 'يراجع المتجر إشعار الحوالة المالية الآن'.tr
                              : order.hasPaymentIssue
                              ? 'يرجى رفع إشعار حوالة واضح لإكمال الطلب'.tr
                              : 'تم تأكيد طلبك وحوالتك بنجاح'.tr,
                          isCompleted:
                              currentStep > 1 || order.isPaymentVerified,
                          isCurrent:
                              currentStep == 1 && !order.isPaymentVerified,
                          isLast: false,
                        ),
                        _buildTimelineStep(
                          context: context,
                          title: 'جاري تجهيز الملابس'.tr,
                          subtitle:
                              'المتجر يقوم بتجهيز وتغليف المقاسات والألوان المطلوبة'
                                  .tr,
                          isCompleted: currentStep > 2,
                          isCurrent: currentStep == 2,
                          isLast: false,
                        ),
                        _buildTimelineStep(
                          context: context,
                          title: order.isCustomerPickup
                              ? 'جاهز للاستلام من المتجر'.tr
                              : 'تم الشحن مع مندوب التوصيل'.tr,
                          subtitle: order.isCustomerPickup
                              ? 'الطلب جاهز ويمكن لمندوبك استلامه من المتجر'.tr
                              : 'الشحنة في طريقها إلى عنوانك المحدد'.tr,
                          isCompleted: currentStep > 3,
                          isCurrent: currentStep == 3,
                          isLast: false,
                        ),
                        _buildTimelineStep(
                          context: context,
                          title: 'تم الاستلام والتسليم'.tr,
                          subtitle: 'تم تسليم الملابس بنجاح'.tr,
                          isCompleted: currentStep >= 4,
                          isCurrent: currentStep == 4,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Items List + Price Breakdown
                  Text(
                    '${'القطع المشتراة'.tr} (${order.items.length})',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          '${'المواصفات'.tr}: ${item.variantInfo}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      Text(
                                        '${'الكمية'.tr}: ${item.quantity}',
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
                              'قيمة المنتجات'.tr,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              AppFormat.price(order.effectiveSubtotal),
                              style: TextStyle(
                                fontWeight: AppFont.semiBold,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        if (order.isShopDelivery) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'التوصيل (من المحل)'.tr,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                order.deliveryFee > 0
                                    ? AppFormat.price(order.deliveryFee)
                                    : 'مجاناً'.tr,
                                style: TextStyle(
                                  fontWeight: AppFont.bold,
                                  color: order.deliveryFee > 0
                                      ? AppColors.text
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الإجمالي'.tr,
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
          ),
        );
      },
      error: (err, _) => CustomerScaffold(
        title: 'تفاصيل الطلب'.tr,
        body: AppEmpty(
          icon: AppIcons.error,
          message: 'تعذر تحميل تفاصيل الطلب: $err'.tr,
        ),
      ),
    );
  }
}
