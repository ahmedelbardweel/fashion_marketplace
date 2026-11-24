import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/network_guard.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../../router/routes.dart';
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

  BadgeTone _statusTone(String status) {
    switch (status) {
      case 'delivered':
        return BadgeTone.success;
      case 'cancelled':
        return BadgeTone.error;
      case 'pending':
        return BadgeTone.warning;
      default:
        return BadgeTone.primary;
    }
  }

  BadgeTone _paymentTone(CustomerOrder order) {
    if (order.isPaymentVerified) return BadgeTone.success;
    if (order.hasPaymentIssue) return BadgeTone.error;
    if (order.isPaymentPending) return BadgeTone.warning;
    return BadgeTone.neutral;
  }

  String _currentStageHeadline(CustomerOrder order) {
    if (order.isCancelled) return 'تم إلغاء هذا الطلب'.tr;
    if (order.hasPaymentIssue) return 'يلزم تحديث إشعار الحوالة'.tr;
    switch (order.status) {
      case 'pending':
        return order.isPaymentPending
            ? 'بانتظار مراجعة الحوالة وتأكيد المحل'.tr
            : 'تم إرسال طلبك للمحل وبانتظار التأكيد'.tr;
      case 'confirmed':
        return 'أكد المحل طلبك وسيبدأ التجهيز قريباً'.tr;
      case 'processing':
        return 'المحل يجهّز ويغلّف طلبك حالياً'.tr;
      case 'shipped':
        return order.isCustomerPickup
            ? 'طلبك جاهز للاستلام من المحل'.tr
            : 'طلبك في الطريق إليك الآن'.tr;
      case 'delivered':
        return 'تم تسليم طلبك بنجاح'.tr;
      default:
        return order.statusLabel.tr;
    }
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
      await repo.resubmitPaymentReceipt(orderId: order.id, receiptUrl: url);
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

  Future<void> _openInquirySheet(CustomerOrder order, String shortId) async {
    const topics = [
      'تأخر في تأكيد الطلب',
      'تأخر في التوصيل',
      'استفسار عن موعد التسليم',
      'مشكلة أو استفسار آخر',
    ];
    var selectedTopic = topics.first;
    var escalateAdmin = false;
    var sending = false;
    final msgCtrl = TextEditingController();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return AppBottomSheetScaffold(
            title: 'استفسار أو متابعة الطلب'.tr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'اختر السبب وسيصل تنبيه مباشر للمحل لمتابعة طلبك #$shortId'
                      .tr,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final topic in topics)
                      ChoiceChip(
                        label: Text(topic.tr),
                        selected: selectedTopic == topic,
                        onSelected: sending
                            ? null
                            : (_) =>
                                  setSheetState(() => selectedTopic = topic),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: msgCtrl,
                  label: 'تفاصيل إضافية (اختياري)'.tr,
                  hint: 'اكتب رسالتك للمحل باختصار...'.tr,
                  maxLines: 3,
                  enabled: !sending,
                ),
                const SizedBox(height: AppSpacing.xs),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: escalateAdmin,
                  onChanged: sending
                      ? null
                      : (v) => setSheetState(() => escalateAdmin = v),
                  title: Text(
                    'إرسال نسخة لإدارة التطبيق'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.semiBold,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    'في حال تأخر رد المحل أو وجود مشكلة لم تُحل'.tr,
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'إرسال المتابعة'.tr,
                  isLoading: sending,
                  onPressed: () async {
                    setSheetState(() => sending = true);
                    try {
                      await ref
                          .read(customerRepositoryProvider)
                          .sendOrderInquiry(
                            orderId: order.id,
                            topic: selectedTopic,
                            message: msgCtrl.text,
                            escalateAdmin: escalateAdmin,
                          );
                      if (!mounted) return;
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      AppHaptics.success();
                      showAppSnackBar(
                        context,
                        escalateAdmin
                            ? 'تم إرسال رسالتك للمحل وللإدارة للمتابعة'.tr
                            : 'تم إرسال استفسارك للمحل بنجاح'.tr,
                      );
                    } catch (err) {
                      if (sheetCtx.mounted) {
                        setSheetState(() => sending = false);
                      }
                      if (mounted) {
                        showAppSnackBar(
                          context,
                          ref.read(customerRepositoryProvider).mapError(err),
                          isError: true,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    msgCtrl.dispose();
  }

  Widget _buildTimelineStep({
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
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? OrderDetailsDesign.timelineActive
                    : AppColors.surfaceAlt,
                border: Border.all(
                  color: active
                      ? OrderDetailsDesign.timelineActive
                      : OrderDetailsDesign.timelineInactive,
                  width: 1.8,
                ),
              ),
              child: isCompleted
                  ? Icon(AppIcons.check, size: 12, color: AppColors.white)
                  : (isCurrent
                        ? Center(
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.white,
                              ),
                            ),
                          )
                        : null),
            ),
            if (!isLast)
              Container(
                width: 1.8,
                height: 28,
                color: isCompleted
                    ? OrderDetailsDesign.timelineActive
                    : OrderDetailsDesign.timelineInactive,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? AppFont.bold : AppFont.medium,
                    color: active ? AppColors.text : AppColors.textMuted,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
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

        final step = order.statusStep;
        final dateStr = DateFormat('yyyy/MM/dd · hh:mm a').format(
          order.createdAt,
        );
        final shortId = order.id.length > 8
            ? order.id.substring(0, 8).toUpperCase()
            : order.id.toUpperCase();
        final scheduleSummary = formatDeliveryScheduleSummary(
          scheduledAt: order.scheduledDeliveryAt,
          timeWindow: order.deliveryTimeWindow,
        );
        final shopLocation = [
          if (order.shopCity?.trim().isNotEmpty ?? false)
            order.shopCity!.trim(),
          if (order.shopAddress?.trim().isNotEmpty ?? false)
            order.shopAddress!.trim(),
        ].join(' · ');

        return CustomerScaffold(
          title: 'طلب #$shortId'.tr,
          showBottomNav: false,
          body: AppRefreshIndicator(
            onRefresh: () => ref.refresh(
              customerOrderDetailsProvider(widget.orderId).future,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1) تنبيه مشكلة الحوالة (إن وجدت) ───────────────────────
                  if (order.hasPaymentIssue && order.isActive) ...[
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      backgroundColor: AppColors.errorSoft,
                      borderColor: AppColors.error.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'توجد مشكلة في إشعار الحوالة'.tr,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: AppFont.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (order.paymentIssueNote?.trim().isNotEmpty ?? false)
                                ? order.paymentIssueNote!.trim()
                                : 'يرجى مراجعة المبلغ المحوّل ورفع صورة واضحة لإشعار الحوالة.'
                                      .tr,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.text,
                              height: 1.4,
                            ),
                          ),
                          if (order.paymentAccountNumber != null &&
                              order.paymentAccountNumber!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => copyTextWithFeedback(
                                context,
                                text: order.paymentAccountNumber!,
                                label: 'رقم الحساب'.tr,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
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
                                    Text(
                                      'نسخ'.tr,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: AppFont.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'رفع من المعرض'.tr,
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
                            const SizedBox(height: 6),
                            Text(
                              order.isGroupedPayment
                                  ? (AppLang.isEn
                                        ? 'Combined transfer (${order.groupShopsCount} shops): ${AppFormat.price(order.effectiveGroupTotal)}'
                                        : 'الحوالة المجمّعة (${order.groupShopsCount} متاجر): ${AppFormat.price(order.effectiveGroupTotal)}')
                                  : '${'المبلغ المطلوب'.tr}: ${AppFormat.price(order.total)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ── 2) حالة الطلب ومراحل التنفيذ ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'حالة الطلب'.tr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      AppStatusBadge(
                        label: order.statusLabel,
                        tone: _statusTone(order.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: order.isCancelled
                                ? AppColors.errorSoft
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            border: Border.all(
                              color: order.isCancelled
                                  ? AppColors.error.withValues(alpha: 0.3)
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentStageHeadline(order),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: AppFont.bold,
                                  color: order.isCancelled
                                      ? AppColors.error
                                      : AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$dateStr · ${order.deliveryModeLabel.tr}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!order.isCancelled) ...[
                          const SizedBox(height: 12),
                          _buildTimelineStep(
                            title: 'استلام الطلب'.tr,
                            subtitle: order.isPaymentPending
                                ? 'بانتظار مراجعة الحوالة من المحل'.tr
                                : 'تم تسجيل طلبك لدى ${order.shopName}'.tr,
                            isCompleted: step > 1 || order.isPaymentVerified,
                            isCurrent: step == 1 && !order.isPaymentVerified,
                            isLast: false,
                          ),
                          _buildTimelineStep(
                            title: 'تأكيد المحل'.tr,
                            subtitle: 'مراجعة توفر القطع وتحديد موعد التسليم'.tr,
                            isCompleted: step > 2,
                            isCurrent:
                                step == 2 ||
                                (step == 1 && order.isPaymentVerified),
                            isLast: false,
                          ),
                          _buildTimelineStep(
                            title: 'تجهيز الطلب'.tr,
                            subtitle: 'تجهيز وتغليف المقاسات المطلوبة'.tr,
                            isCompleted: step > 3,
                            isCurrent: step == 3,
                            isLast: false,
                          ),
                          _buildTimelineStep(
                            title: order.isCustomerPickup
                                ? 'جاهز للاستلام'.tr
                                : 'في الطريق إليك'.tr,
                            subtitle: order.isCustomerPickup
                                ? 'يمكنك الاستلام من المحل'.tr
                                : 'الطلب مع مندوب التوصيل'.tr,
                            isCompleted: step > 4,
                            isCurrent: step == 4,
                            isLast: false,
                          ),
                          _buildTimelineStep(
                            title: 'تم التسليم'.tr,
                            subtitle: 'اكتمل الطلب بنجاح'.tr,
                            isCompleted: step >= 5,
                            isCurrent: false,
                            isLast: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 3) موعد التسليم (يحدده المحل) ──────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'موعد التسليم'.tr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      AppStatusBadge(
                        label: order.hasDeliverySchedule
                            ? 'محدد من المحل'
                            : 'بانتظار التحديد',
                        tone: order.hasDeliverySchedule
                            ? BadgeTone.success
                            : BadgeTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    borderColor: order.hasDeliverySchedule
                        ? AppColors.success.withValues(alpha: 0.35)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 17,
                              color: order.hasDeliverySchedule
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order.hasDeliverySchedule
                                    ? scheduleSummary
                                    : 'سيحدد المحل موعد التسليم فور تأكيد طلبك وسيصلك إشعار مباشرة.'
                                          .tr,
                                style: TextStyle(
                                  fontSize: order.hasDeliverySchedule
                                      ? 13.5
                                      : 12,
                                  fontWeight: order.hasDeliverySchedule
                                      ? AppFont.bold
                                      : AppFont.regular,
                                  color: order.hasDeliverySchedule
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (order.hasShopNote) ...[
                          const Divider(height: 16),
                          Text(
                            'ملاحظة من المحل'.tr,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: AppFont.bold,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.shopOrderNote!.trim(),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.text,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 4) المحل والتواصل لحل أي مشكلة أو تأخير ─────────────────
                  Text(
                    'المحل والتواصل'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          onTap: order.shopId.isEmpty
                              ? null
                              : () => context.push(
                                  AppRoutes.customerShopProfilePath(
                                    order.shopId,
                                  ),
                                ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  size: 17,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.shopName,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: AppFont.bold,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    if (shopLocation.isNotEmpty)
                                      Text(
                                        shopLocation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                AppIcons.forward,
                                size: 15,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (order.hasShopPhone) ...[
                              Expanded(
                                child: _CompactActionTile(
                                  label: 'واتساب'.tr,
                                  icon: Icons.chat_bubble_outline_rounded,
                                  accent: const Color(0xFF16A34A),
                                  onTap: () => launchWhatsAppChat(
                                    context,
                                    phone: order.shopPhone!,
                                    message:
                                        'مرحباً ${order.shopName}، أستفسر بخصوص الطلب رقم #$shortId',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _CompactActionTile(
                                  label: 'اتصال'.tr,
                                  icon: AppIcons.phone,
                                  onTap: () => launchPhoneCall(
                                    context,
                                    order.shopPhone!,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: _CompactActionTile(
                                label: 'تأخر / مشكلة؟'.tr,
                                icon: Icons.help_outline_rounded,
                                onTap: () => _openInquirySheet(order, shortId),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 5) بيانات التوصيل والحوالة ──────────────────────────────
                  Text(
                    'التوصيل والدفع'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (order.deliveryAddress != null &&
                            order.deliveryAddress!.trim().isNotEmpty)
                          _SummaryRow(
                            label: 'العنوان'.tr,
                            value: order.deliveryAddress!.trim(),
                          ),
                        if (order.phone != null &&
                            order.phone!.trim().isNotEmpty) ...[
                          if (order.deliveryAddress != null &&
                              order.deliveryAddress!.trim().isNotEmpty)
                            const SizedBox(height: 6),
                          _SummaryRow(
                            label: 'الهاتف'.tr,
                            value: order.phone!.trim(),
                          ),
                        ],
                        if (order.notes != null &&
                            order.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _SummaryRow(
                            label: 'ملاحظاتك'.tr,
                            value: order.notes!.trim(),
                          ),
                        ],
                        if (order.paymentStatus != 'not_required' ||
                            order.hasReceipt) ...[
                          const Divider(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.paymentMethodName ??
                                      'حوالة بنكية / محفظة'.tr,
                                  style: TextStyle(
                                    fontSize: 12.5,
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
                          if (order.hasReceipt) ...[
                            const SizedBox(height: 8),
                            ReceiptThumbnailCard(
                              imageUrl: order.paymentReceiptUrl!,
                              subtitle: '${'إشعار حوالة طلب'.tr} #$shortId',
                              height: 136,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 6) القطع والملخص المالي ─────────────────────────────────
                  Text(
                    '${'القطع المطلوبة'.tr} (${order.items.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      children: [
                        for (var i = 0; i < order.items.length; i++) ...[
                          if (i > 0) const Divider(height: 14),
                          _OrderItemRow(
                            name: order.items[i].productName,
                            variantInfo: order.items[i].variantInfo,
                            quantity: order.items[i].quantity,
                            totalPrice: order.items[i].totalPrice,
                            imageUrl: order.items[i].imagePath,
                          ),
                        ],
                        const Divider(height: 18),
                        _SummaryRow(
                          label: 'قيمة المنتجات'.tr,
                          value: AppFormat.price(order.effectiveSubtotal),
                        ),
                        if (order.isShopDelivery) ...[
                          const SizedBox(height: 5),
                          _SummaryRow(
                            label: 'التوصيل'.tr,
                            value: order.deliveryFee > 0
                                ? AppFormat.price(order.deliveryFee)
                                : 'مجاناً'.tr,
                            valueColor: order.deliveryFee > 0
                                ? AppColors.text
                                : AppColors.success,
                          ),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الإجمالي'.tr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: AppFont.bold,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              AppFormat.price(order.total),
                              style: TextStyle(
                                fontSize: 16.5,
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
          message: AppErrorMapper.message(
            err,
            fallback: 'تعذر تحميل تفاصيل الطلب حالياً. حاول مرة أخرى.',
          ),
        ),
      ),
    );
  }
}

class _CompactActionTile extends StatelessWidget {
  const _CompactActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? AppColors.text;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: AppHaptics.action(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: accent != null
                ? accent!.withValues(alpha: 0.32)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.bold,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: AppFont.semiBold,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.name,
    required this.quantity,
    required this.totalPrice,
    this.variantInfo,
    this.imageUrl,
  });

  final String name;
  final String? variantInfo;
  final int quantity;
  final double totalPrice;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl!.trim(),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (variantInfo != null && variantInfo!.trim().isNotEmpty)
                    variantInfo!.trim(),
                  '${'الكمية'.tr}: $quantity',
                ].join(' · '),
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          AppFormat.price(totalPrice),
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFont.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
