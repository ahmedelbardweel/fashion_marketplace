import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/contact_launcher.dart';
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
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopOrderDetailsScreen extends ConsumerStatefulWidget {
  const ShopOrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ShopOrderDetailsScreen> createState() =>
      _ShopOrderDetailsScreenState();
}

class _ShopOrderDetailsScreenState
    extends ConsumerState<ShopOrderDetailsScreen> {
  Future<void> _updateStatus(ShopOrder order, String nextStatus) async {
    if (nextStatus == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text('إلغاء الطلب'.tr),
          content: Text(
            'هل أنت متأكد من إلغاء الطلب ${shortOrderCode(order.id)}؟ سيتم إشعار العميل بذلك.'
                .tr,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('تراجع'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(
                'تأكيد الإلغاء'.tr,
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.updateOrderStatus(
      orderId: order.id,
      status: nextStatus,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث حالة الطلب'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    AppHaptics.success();
    showAppSnackBar(context, 'تم تحديث حالة الطلب بنجاح'.tr);
  }

  Future<void> _verifyPayment(ShopOrder order, {required bool approved}) async {
    String? issueNote;
    if (!approved) {
      final ctrl = TextEditingController();
      final result = await AppBottomSheet.show<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        child: AppBottomSheetScaffold(
          title: 'الإبلاغ عن مشكلة في الحوالة'.tr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: ctrl,
                label: 'سبب المشكلة للعميل *'.tr,
                hint: 'مثال: المبلغ المحوّل ناقص أو صورة الإشعار غير واضحة'.tr,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'إرسال للعميل'.tr,
                onPressed: () {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) {
                    showAppSnackBar(
                      context,
                      'يرجى كتابة سبب المشكلة'.tr,
                      isError: true,
                    );
                    return;
                  }
                  Navigator.of(context).pop(text);
                },
              ),
            ],
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
      ctrl.dispose();
      if (result == null || !mounted) return;
      issueNote = result;
    }

    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.verifyOrderPayment(
      orderId: order.id,
      approved: approved,
      issueNote: issueNote,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث حالة الحوالة'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    AppHaptics.success();
    showAppSnackBar(
      context,
      approved
          ? 'تم تأكيد استلام الحوالة بنجاح'.tr
          : 'تم إشعار العميل بالمشكلة لإعادة رفع الإشعار'.tr,
    );
  }

  Future<void> _openScheduleSheet(ShopOrder order) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? selectedDate = order.scheduledDeliveryAt != null
        ? DateTime(
            order.scheduledDeliveryAt!.year,
            order.scheduledDeliveryAt!.month,
            order.scheduledDeliveryAt!.day,
          )
        : today;
    String selectedWindow = order.deliveryTimeWindow?.trim() ?? '';
    final noteCtrl = TextEditingController(
      text: order.shopOrderNote?.trim() ?? '',
    );
    var saving = false;

    const windows = [
      'خلال ساعتين',
      'صباحاً (10 ص - 1 م)',
      'ظهراً (1 م - 4 م)',
      'مساءً (4 م - 8 م)',
    ];

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          bool isSameDay(DateTime? a, DateTime b) =>
              a != null && a.year == b.year && a.month == b.month && a.day == b.day;

          final tomorrow = today.add(const Duration(days: 1));
          final afterTomorrow = today.add(const Duration(days: 2));
          final isCustomDate =
              selectedDate != null &&
              !isSameDay(selectedDate, today) &&
              !isSameDay(selectedDate, tomorrow) &&
              !isSameDay(selectedDate, afterTomorrow);

          return AppBottomSheetScaffold(
            title: 'تحديد موعد التسليم'.tr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'يوم التسليم'.tr,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text('اليوم'.tr),
                      selected: isSameDay(selectedDate, today),
                      onSelected: saving
                          ? null
                          : (_) => setSheetState(() => selectedDate = today),
                    ),
                    ChoiceChip(
                      label: Text('غداً'.tr),
                      selected: isSameDay(selectedDate, tomorrow),
                      onSelected: saving
                          ? null
                          : (_) => setSheetState(() => selectedDate = tomorrow),
                    ),
                    ChoiceChip(
                      label: Text('بعد غد'.tr),
                      selected: isSameDay(selectedDate, afterTomorrow),
                      onSelected: saving
                          ? null
                          : (_) => setSheetState(
                              () => selectedDate = afterTomorrow,
                            ),
                    ),
                    ChoiceChip(
                      label: Text(
                        isCustomDate
                            ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                            : 'تاريخ آخر'.tr,
                      ),
                      selected: isCustomDate,
                      onSelected: saving
                          ? null
                          : (_) async {
                              final picked = await showDatePicker(
                                context: sheetCtx,
                                initialDate: selectedDate ?? today,
                                firstDate: today,
                                lastDate: today.add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'الفترة الزمنية'.tr,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in windows)
                      ChoiceChip(
                        label: Text(w.tr),
                        selected: selectedWindow == w,
                        onSelected: saving
                            ? null
                            : (_) => setSheetState(() {
                                selectedWindow = selectedWindow == w ? '' : w;
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: noteCtrl,
                  label: 'ملاحظة للعميل (اختياري)'.tr,
                  hint: 'مثال: سيتواصل معك المندوب قبل الوصول بنصف ساعة'.tr,
                  maxLines: 2,
                  enabled: !saving,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'حفظ وإشعار العميل'.tr,
                  isLoading: saving,
                  onPressed: () async {
                    setSheetState(() => saving = true);
                    final actions = ref.read(
                      shopCatalogActionProvider.notifier,
                    );
                    final ok = await actions.setOrderDeliverySchedule(
                      orderId: order.id,
                      scheduledAt: selectedDate,
                      timeWindow: selectedWindow,
                      shopNote: noteCtrl.text,
                    );
                    if (!mounted) return;
                    if (!ok) {
                      if (sheetCtx.mounted) {
                        setSheetState(() => saving = false);
                      }
                      final err = ref.read(shopCatalogActionProvider).error;
                      showAppSnackBar(
                        context,
                        err == null
                            ? 'تعذر حفظ موعد التسليم'.tr
                            : actions.errorMessage(err),
                        isError: true,
                      );
                      return;
                    }
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    AppHaptics.success();
                    showAppSnackBar(
                      context,
                      'تم حفظ موعد التسليم وإشعار العميل'.tr,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    noteCtrl.dispose();
  }

  Future<void> _openOtherStatusSheet(ShopOrder order) async {
    const steps = [
      ('confirmed', 'تأكيد الطلب'),
      ('processing', 'جاري التجهيز'),
      ('shipped', 'تم الشحن / جاهز للاستلام'),
      ('delivered', 'تم التسليم'),
    ];

    final chosen = await AppBottomSheet.show<String>(
      context: context,
      useSafeArea: true,
      child: AppBottomSheetScaffold(
        title: 'تغيير حالة الطلب'.tr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final step in steps)
              if (step.$1 != order.status)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    step.$2.tr,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: AppFont.semiBold,
                      color: AppColors.text,
                    ),
                  ),
                  trailing: Icon(
                    AppIcons.forward,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => Navigator.of(context).pop(step.$1),
                ),
            if (order.isActive) ...[
              const Divider(height: 16),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  'إلغاء الطلب'.tr,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: AppFont.bold,
                    color: AppColors.error,
                  ),
                ),
                onTap: () => Navigator.of(context).pop('cancelled'),
              ),
            ],
          ],
        ),
      ),
    );

    if (chosen != null && mounted) {
      await _updateStatus(order, chosen);
    }
  }

  String _nextStepLabel(ShopOrder order, String nextStep) {
    switch (nextStep) {
      case 'confirmed':
        return 'تأكيد الطلب'.tr;
      case 'processing':
        return 'بدء التجهيز'.tr;
      case 'shipped':
        return order.isCustomerPickup
            ? 'تحديد كجاهز للاستلام'.tr
            : 'تم الشحن مع المندوب'.tr;
      case 'delivered':
        return 'تأكيد التسليم'.tr;
      default:
        return nextStep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(shopOrderDetailsProvider(widget.orderId));
    final busy = ref.watch(shopCatalogActionProvider).isLoading;

    return orderAsync.skeletonWhen(
      placeholder: LoadingFixtures.shopOrders.first,
      error: (err, _) => ShopScaffold(
        title: 'إدارة الطلب'.tr,
        showBottomNav: false,
        showNotifications: false,
        body: ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل تفاصيل الطلب',
              message: ref.read(shopCatalogRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () =>
                  ref.invalidate(shopOrderDetailsProvider(widget.orderId)),
            ),
          ],
        ),
      ),
      data: (order) {
        if (order == null) {
          return ShopScaffold(
            title: 'إدارة الطلب'.tr,
            showBottomNav: false,
            showNotifications: false,
            body: AppEmpty(
              icon: AppIcons.orders,
              message: 'الطلب غير موجود'.tr,
            ),
          );
        }

        final shortId = order.id.length > 8
            ? order.id.substring(0, 8).toUpperCase()
            : order.id.toUpperCase();
        final customerName = (order.customerName?.trim().isNotEmpty ?? false)
            ? order.customerName!.trim()
            : (order.customerEmail?.trim().isNotEmpty ?? false)
            ? order.customerEmail!.trim()
            : 'عميل'.tr;
        final customerPhone = order.phone?.trim() ?? '';
        final customerAddress = order.deliveryAddress?.trim() ?? '';
        final nextStep = nextLogicalOrderStatus(order.status);
        final needsPaymentCheck =
            order.requiresPaymentVerification && order.isActive;
        final scheduleSummary = formatDeliveryScheduleSummary(
          scheduledAt: order.scheduledDeliveryAt,
          timeWindow: order.deliveryTimeWindow,
        );

        return ShopScaffold(
          title: 'طلب #$shortId'.tr,
          showBottomNav: false,
          showNotifications: false,
          bottom: order.isActive
              ? _ShopOrderStickyBar(
                  order: order,
                  busy: busy,
                  needsPaymentCheck: needsPaymentCheck,
                  primaryLabel: needsPaymentCheck
                      ? 'تأكيد استلام الحوالة'.tr
                      : (nextStep != null
                            ? _nextStepLabel(order, nextStep)
                            : null),
                  onPrimaryPressed: needsPaymentCheck
                      ? () => _verifyPayment(order, approved: true)
                      : (nextStep != null
                            ? () => _updateStatus(order, nextStep)
                            : null),
                  onMorePressed: () => _openOtherStatusSheet(order),
                )
              : null,
          body: AppRefreshIndicator(
            onRefresh: () => ref.refresh(
              shopOrderDetailsProvider(widget.orderId).future,
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
                  // ── 1) حالة الطلب والمراحل ─────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'مراحل الطلب'.tr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      AppStatusBadge(
                        label: order.statusLabel,
                        tone: orderStatusTone(order.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ShopOrderProgressBar(
                          currentStep: order.statusStep,
                          isCancelled: order.isCancelled,
                          isPickup: order.isCustomerPickup,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatShopDateTime(order.createdAt),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              order.deliveryModeLabel.tr,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: AppFont.semiBold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 2) موعد التسليم وملاحظة للعميل ──────────────────────────
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
                      if (order.hasDeliverySchedule)
                        AppStatusBadge(
                          label: 'محدد',
                          tone: BadgeTone.success,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: EdgeInsets.zero,
                    onTap: busy || !order.isActive
                        ? null
                        : () => _openScheduleSheet(order),
                    borderColor: order.hasDeliverySchedule
                        ? AppColors.success.withValues(alpha: 0.35)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                      : 'اضغط لتحديد يوم وفترة التسليم وإشعار العميل'
                                            .tr,
                                  style: TextStyle(
                                    fontSize: order.hasDeliverySchedule
                                        ? 13
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
                              if (order.isActive) ...[
                                const SizedBox(width: 6),
                                Text(
                                  (order.hasDeliverySchedule ? 'تعديل' : 'تحديد')
                                      .tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: AppFont.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (order.hasShopNote) ...[
                            const Divider(height: 14),
                            Text(
                              order.shopOrderNote!.trim(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 3) بيانات العميل والتواصل ──────────────────────────────
                  Text(
                    'العميل والتواصل'.tr,
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
                        Text(
                          customerName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                        if (customerAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            customerAddress,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            customerPhone,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        if (order.notes != null &&
                            order.notes!.trim().isNotEmpty) ...[
                          const Divider(height: 16),
                          Text(
                            '${'ملاحظة العميل'.tr}: ${order.notes!.trim()}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                        if (customerPhone.isNotEmpty ||
                            customerAddress.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (customerPhone.isNotEmpty) ...[
                                Expanded(
                                  child: _ShopContactBtn(
                                    label: 'واتساب'.tr,
                                    icon: Icons.chat_bubble_outline_rounded,
                                    accent: const Color(0xFF16A34A),
                                    onTap: () => launchWhatsAppChat(
                                      context,
                                      phone: customerPhone,
                                      message:
                                          'مرحباً $customerName، نتواصل معك بخصوص طلبك رقم #$shortId',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _ShopContactBtn(
                                    label: 'اتصال'.tr,
                                    icon: AppIcons.phone,
                                    onTap: () => launchPhoneCall(
                                      context,
                                      customerPhone,
                                    ),
                                  ),
                                ),
                              ],
                              if (customerAddress.isNotEmpty) ...[
                                if (customerPhone.isNotEmpty)
                                  const SizedBox(width: 6),
                                Expanded(
                                  child: _ShopContactBtn(
                                    label: 'نسخ العنوان'.tr,
                                    icon: Icons.copy_rounded,
                                    onTap: () => copyTextWithFeedback(
                                      context,
                                      text: customerAddress,
                                      label: 'العنوان'.tr,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── 4) الحوالة المالية وإشعار الدفع ─────────────────────────
                  if (order.hasReceipt ||
                      order.paymentStatus != 'not_required') ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الحوالة المالية'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        AppStatusBadge(
                          label: order.paymentStatusLabel,
                          tone: order.isPaymentVerified
                              ? BadgeTone.success
                              : order.hasPaymentIssue
                              ? BadgeTone.error
                              : BadgeTone.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      borderColor: order.hasPaymentIssue
                          ? AppColors.error.withValues(alpha: 0.4)
                          : order.isPaymentVerified
                          ? AppColors.success.withValues(alpha: 0.35)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (order.paymentMethodName?.trim().isNotEmpty ??
                              false)
                            Text(
                              order.paymentMethodName!.trim(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: AppFont.bold,
                                color: AppColors.text,
                              ),
                            ),
                          if (order.isGroupedPayment) ...[
                            const SizedBox(height: 4),
                            Text(
                              AppLang.isEn
                                  ? 'Combined transfer (${order.groupShopsCount} shops): ${AppFormat.price(order.effectiveGroupTotal)} · Your share: ${AppFormat.price(order.total)}'
                                  : 'حوالة مجمّعة (${order.groupShopsCount} متاجر): ${AppFormat.price(order.effectiveGroupTotal)} · حصتك: ${AppFormat.price(order.total)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (order.hasReceipt) ...[
                            const SizedBox(height: 8),
                            ReceiptThumbnailCard(
                              imageUrl: order.paymentReceiptUrl!,
                              subtitle: '${'إشعار حوالة طلب'.tr} #$shortId',
                              height: 150,
                            ),
                          ],
                          if (order.hasPaymentIssue &&
                              (order.paymentIssueNote?.trim().isNotEmpty ??
                                  false)) ...[
                            const SizedBox(height: 8),
                            Text(
                              order.paymentIssueNote!.trim(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                          if (needsPaymentCheck) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'تأكيد الحوالة'.tr,
                                    isLoading: busy,
                                    onPressed: () =>
                                        _verifyPayment(order, approved: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppButton(
                                    label: 'مشكلة في الإشعار'.tr,
                                    variant: AppButtonVariant.secondary,
                                    onPressed: busy
                                        ? null
                                        : () => _verifyPayment(
                                            order,
                                            approved: false,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // ── 5) القطع المطلوبة والملخص المالي ───────────────────────
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
                        if (order.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'تفاصيل القطع غير متوفرة حالياً'.tr,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        else
                          for (var i = 0; i < order.items.length; i++) ...[
                            if (i > 0) const Divider(height: 14),
                            _ShopOrderItemRow(item: order.items[i]),
                          ],
                        const Divider(height: 18),
                        _ShopSummaryRow(
                          label: 'قيمة المنتجات'.tr,
                          value: AppFormat.price(order.effectiveSubtotal),
                        ),
                        if (order.isShopDelivery) ...[
                          const SizedBox(height: 5),
                          _ShopSummaryRow(
                            label: 'التوصيل'.tr,
                            value: order.deliveryFee > 0
                                ? AppFormat.price(order.deliveryFee)
                                : 'مجاناً'.tr,
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
    );
  }
}

class _ShopOrderProgressBar extends StatelessWidget {
  const _ShopOrderProgressBar({
    required this.currentStep,
    required this.isCancelled,
    required this.isPickup,
  });

  final int currentStep;
  final bool isCancelled;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Text(
          'هذا الطلب ملغي'.tr,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: AppFont.bold,
            color: AppColors.error,
          ),
        ),
      );
    }

    final labels = [
      'انتظار'.tr,
      'مؤكد'.tr,
      'تجهيز'.tr,
      isPickup ? 'استلام'.tr : 'شحن'.tr,
      'تسليم'.tr,
    ];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: (i + 1) <= currentStep
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: (i + 1) == currentStep
                        ? AppFont.bold
                        : AppFont.medium,
                    color: (i + 1) <= currentStep
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ShopOrderStickyBar extends StatelessWidget {
  const _ShopOrderStickyBar({
    required this.order,
    required this.busy,
    required this.needsPaymentCheck,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.onMorePressed,
  });

  final ShopOrder order;
  final bool busy;
  final bool needsPaymentCheck;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback onMorePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (primaryLabel != null && onPrimaryPressed != null)
          Expanded(
            child: AppButton(
              label: primaryLabel!,
              isLoading: busy,
              onPressed: onPrimaryPressed,
            ),
          ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: busy ? null : AppHaptics.action(onMorePressed),
            child: Text(
              'المزيد'.tr,
              style: const TextStyle(fontSize: 13, fontWeight: AppFont.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopContactBtn extends StatelessWidget {
  const _ShopContactBtn({
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

class _ShopOrderItemRow extends StatelessWidget {
  const _ShopOrderItemRow({required this.item});

  final ShopOrderItem item;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imagePath != null && item.imagePath!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imagePath!.trim(),
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
                item.productName,
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
                  if (item.variantInfo != null &&
                      item.variantInfo!.trim().isNotEmpty)
                    item.variantInfo!.trim(),
                  '${'الكمية'.tr}: ${item.quantity}',
                ].join(' · '),
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          AppFormat.price(item.totalPrice),
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

class _ShopSummaryRow extends StatelessWidget {
  const _ShopSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: AppFont.semiBold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
