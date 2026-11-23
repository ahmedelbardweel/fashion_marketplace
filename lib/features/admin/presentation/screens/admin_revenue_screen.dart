import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../../router/routes.dart';
import '../../domain/models/subscription_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

const _placeholderOverview = AdminSubscriptionPayoutOverview(
  totalSubscriptionRevenue: 360,
  activeSubscriptionsCount: 8,
  expiredSubscriptionsCount: 1,
  pendingSubscriptionsCount: 2,
  totalShopsSales: 4820,
  totalPaidToShops: 3200,
  totalOwedToShops: 1620,
  shops: [
    ShopFinancialSummary(
      shopId: 'sk_shop_1',
      shopName: 'متجر أناقة غزة',
      shopCity: 'غزة',
      subscriptionStatus: 'active',
      subscriptionPlanName: 'الباقة الشهرية',
      subscriptionPrice: 30,
      totalOrders: 16,
      deliveredOrders: 12,
      inProgressOrders: 3,
      cancelledOrders: 1,
      verifiedSales: 1850,
      totalPaidOut: 1200,
      remainingOwed: 650,
    ),
    ShopFinancialSummary(
      shopId: 'sk_shop_2',
      shopName: 'بوتيك الرمال',
      shopCity: 'غزة',
      subscriptionStatus: 'active',
      subscriptionPlanName: 'باقة 3 شهور',
      subscriptionPrice: 80,
      totalOrders: 9,
      deliveredOrders: 8,
      inProgressOrders: 1,
      verifiedSales: 970,
      totalPaidOut: 500,
      remainingOwed: 470,
    ),
  ],
);

class AdminRevenueScreen extends ConsumerStatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  ConsumerState<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends ConsumerState<AdminRevenueScreen> {
  int _selectedTab = 0; // 0: Shops 100% Statements, 1: Subscription Requests
  String _shopSearch = '';
  String _subFilter = 'all'; // 'all' | 'pending' | 'approved' | 'rejected'

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year} • ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _reviewSubscription(
    ShopSubscriptionRecord record, {
    required bool approve,
  }) async {
    String? rejectionReason;

    if (!approve) {
      final reasonCtrl = TextEditingController();
      final formKey = GlobalKey<FormState>();
      final confirmed = await AppBottomSheet.show<bool>(
        context: context,
        isScrollControlled: true,
        child: Builder(
          builder: (sheetCtx) => AppBottomSheetScaffold(
            title: 'رفض إشعار الاشتراك'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'اكتب سبب رفض إشعار اشتراك "${record.shopName}" ليصل للتاجر.'
                        .tr,
                    style: Theme.of(sheetCtx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: reasonCtrl,
                    label: 'سبب الرفض *'.tr,
                    maxLines: 3,
                    validator: (v) =>
                        Validators.required(v, field: 'سبب الرفض'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'تأكيد الرفض'.tr,
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(sheetCtx).pop(true);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'إلغاء'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(sheetCtx).pop(false),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      rejectionReason = reasonCtrl.text.trim();
      reasonCtrl.dispose();
      if (confirmed != true) return;
    }

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.reviewSubscription(
      subscriptionId: record.id,
      approve: approve,
      rejectionReason: rejectionReason,
      shopId: record.shopId,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null
            ? 'تعذر تحديث حالة الاشتراك'.tr
            : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      approve
          ? 'تم اعتماد وتفعيل اشتراك المتجر بنجاح'.tr
          : 'تم رفض إشعار الاشتراك وإشعار التاجر'.tr,
    );
  }

  Future<void> _openRecordPayoutSheet({
    required String shopId,
    required String shopName,
    required double remainingOwed,
  }) async {
    final amountCtrl = TextEditingController(
      text: remainingOwed > 0 ? remainingOwed.toStringAsFixed(2) : '',
    );
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var method = 'bank_transfer';
    PickedBytes? pickedReceipt;
    var saving = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.92,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> pickReceipt({required bool fromCamera}) async {
            try {
              final picked = fromCamera
                  ? await MediaPicker.pickFromCamera()
                  : await MediaPicker.pickImage();
              if (picked == null || !sheetCtx.mounted) return;
              setSheetState(() => pickedReceipt = picked);
            } catch (_) {
              if (!sheetCtx.mounted) return;
              showAppSnackBar(
                sheetCtx,
                'تعذر اختيار صورة الإشعار'.tr,
                isError: true,
              );
            }
          }

          Future<void> submit() async {
            FocusScope.of(sheetCtx).unfocus();
            if (formKey.currentState?.validate() != true) return;
            final amount = double.tryParse(
              amountCtrl.text.trim().replaceAll('٫', '.'),
            );
            if (amount == null || amount <= 0) {
              showAppSnackBar(
                sheetCtx,
                'أدخل مبلغاً صحيحاً أكبر من صفر'.tr,
                isError: true,
              );
              return;
            }

            setSheetState(() => saving = true);
            final actions = ref.read(adminActionProvider.notifier);
            try {
              String? receiptUrl;
              if (pickedReceipt != null) {
                receiptUrl = await ref
                    .read(adminRepositoryProvider)
                    .uploadPayoutReceipt(
                      bytes: pickedReceipt!.bytes,
                      fileName: pickedReceipt!.fileName,
                      contentType: pickedReceipt!.contentType,
                    );
              }
              final ok = await actions.recordShopPayout(
                shopId: shopId,
                amount: amount,
                paymentMethod: method,
                referenceNo: refCtrl.text,
                receiptUrl: receiptUrl,
                notes: notesCtrl.text,
              );
              if (!mounted) return;
              if (!ok) {
                if (sheetCtx.mounted) setSheetState(() => saving = false);
                final err = ref.read(adminActionProvider).error;
                showAppSnackBar(
                  context,
                  err == null
                      ? 'تعذر تسجيل التحويل'.tr
                      : actions.errorMessage(err),
                  isError: true,
                );
                return;
              }
              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              showAppSnackBar(
                context,
                'تم تسجيل تحويل المستحقات للمحل وإشعار التاجر'.tr,
              );
            } catch (error) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              if (mounted) {
                showAppSnackBar(
                  context,
                  actions.errorMessage(error),
                  isError: true,
                );
              }
            }
          }

          return AppBottomSheetScaffold(
            title: '${'تحويل مستحقات'.tr}: $shopName',
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'المتبقي للمحل حالياً (100% بدون عمولة)'.tr,
                            style: Theme.of(sheetCtx).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                        Text(
                          AppFormat.price(remainingOwed),
                          style: Theme.of(sheetCtx).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: AppFont.extraBold,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: amountCtrl,
                    label: 'المبلغ المحوّل للمحل (₪) *'.tr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: !saving,
                    validator: (v) {
                      final n = double.tryParse(
                        (v ?? '').trim().replaceAll('٫', '.'),
                      );
                      if (n == null || n <= 0) {
                        return 'أدخل مبلغاً صحيحاً أكبر من صفر'.tr;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'طريقة التحويل'.tr,
                    style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: Text('تحويل بنكي'.tr),
                        selected: method == 'bank_transfer',
                        onSelected: saving
                            ? null
                            : (_) =>
                                  setSheetState(() => method = 'bank_transfer'),
                      ),
                      ChoiceChip(
                        label: Text('محفظة إلكترونية'.tr),
                        selected: method == 'wallet',
                        onSelected: saving
                            ? null
                            : (_) => setSheetState(() => method = 'wallet'),
                      ),
                      ChoiceChip(
                        label: Text('نقدي'.tr),
                        selected: method == 'cash',
                        onSelected: saving
                            ? null
                            : (_) => setSheetState(() => method = 'cash'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: refCtrl,
                    label: 'رقم الحوالة / المرجع (اختياري)'.tr,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'إرفاق إشعار التحويل للمحل (اختياري)'.tr,
                    style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () => pickReceipt(fromCamera: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: BorderSide(color: AppColors.borderStrong),
                          ),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: Text('من المعرض'.tr),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () => pickReceipt(fromCamera: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: BorderSide(color: AppColors.borderStrong),
                          ),
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            size: 18,
                          ),
                          label: Text('تصوير'.tr),
                        ),
                      ),
                    ],
                  ),
                  if (pickedReceipt != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: Image.memory(
                          pickedReceipt!.bytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: notesCtrl,
                    label: 'ملاحظات للمحل (اختياري)'.tr,
                    maxLines: 2,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'تأكيد وتسجيل التحويل'.tr,
                    isLoading: saving,
                    onPressed: submit,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'إلغاء'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      amountCtrl.dispose();
      refCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Future<void> _openShopStatementSheet(ShopFinancialSummary shop) async {
    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: Consumer(
        builder: (sheetCtx, sheetRef, _) {
          final stmtAsync = sheetRef.watch(
            adminShopFinancialStatementProvider(shop.shopId),
          );
          return AppBottomSheetScaffold(
            title: '${'الكشف المالي'.tr}: ${shop.shopName}',
            child: stmtAsync.when(
              loading: () => const Column(
                children: [
                  AppSkeleton(
                    enabled: true,
                    child: SizedBox(height: 110, width: double.infinity),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeleton(
                    enabled: true,
                    child: SizedBox(height: 80, width: double.infinity),
                  ),
                ],
              ),
              error: (err, _) => AdminNoticeBanner(
                title: 'تعذر تحميل كشف المحل'.tr,
                message: sheetRef.read(adminRepositoryProvider).mapError(err),
                tone: BadgeTone.error,
                actionLabel: 'إعادة المحاولة'.tr,
                onAction: () => sheetRef.invalidate(
                  adminShopFinancialStatementProvider(shop.shopId),
                ),
              ),
              data: (stmt) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary KPIs
                    Row(
                      children: [
                        Expanded(
                          child: AdminKpiCard(
                            label: 'مبيعات معتمدة (100%)',
                            value: AppFormat.price(stmt.verifiedSales),
                            subtitle:
                                '${stmt.deliveredOrders}/${stmt.totalOrders} ${'مكتمل'.tr}',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: AdminKpiCard(
                            label: 'تم تحويله',
                            value: AppFormat.price(stmt.totalPaidOut),
                            subtitle:
                                '${stmt.payouts.length} ${'حوالة'.tr}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'صافي المتبقي للمحل (عمولة 0%)'.tr,
                                  style: Theme.of(sheetCtx).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormat.price(stmt.remainingOwed),
                                  style: Theme.of(sheetCtx)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: AppFont.extraBold,
                                        color: stmt.remainingOwed > 0
                                            ? AppColors.primary
                                            : AppColors.success,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(sheetCtx).pop();
                              _openRecordPayoutSheet(
                                shopId: stmt.shopId,
                                shopName: stmt.shopName,
                                remainingOwed: stmt.remainingOwed,
                              );
                            },
                            child: Text('تسجيل تحويل'.tr),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Payouts History
                    Text(
                      '${'التحويلات المسجلة للمحل'.tr} (${stmt.payouts.length})',
                      style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (stmt.payouts.isEmpty)
                      Text(
                        'لم يتم تسجيل أي تحويلات لهذا المحل بعد.'.tr,
                        style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      for (final p in stmt.payouts.take(15)) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${p.paymentMethodLabel} · ${_formatDateTime(p.paidAt ?? p.createdAt)}',
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: AppFont.semiBold,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    AppFormat.price(p.amount),
                                    style: Theme.of(sheetCtx)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: AppFont.extraBold,
                                          color: AppColors.success,
                                        ),
                                  ),
                                ],
                              ),
                              if (p.referenceNo?.isNotEmpty ?? false)
                                Text(
                                  '${'المرجع'.tr}: ${p.referenceNo!}',
                                  style: Theme.of(sheetCtx).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              if (p.receiptUrl?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 6),
                                ReceiptThumbnailCard(
                                  imageUrl: p.receiptUrl!,
                                  subtitle: 'إشعار تحويل المستحقات'.tr,
                                  height: 110,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    const SizedBox(height: AppSpacing.md),

                    // Orders Breakdown
                    Text(
                      '${'طلبات المحل'.tr} (${stmt.orders.length})',
                      style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (stmt.orders.isEmpty)
                      Text(
                        'لا توجد طلبات مسجلة لهذا المحل بعد.'.tr,
                        style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      for (final o in stmt.orders.take(25)) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.customerName,
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontWeight: AppFont.bold),
                                    ),
                                    Text(
                                      '${_formatDateTime(o.createdAt)} · ${o.statusLabel}',
                                      style: Theme.of(sheetCtx)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                AppFormat.price(o.total),
                                style: Theme.of(sheetCtx).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: AppFont.extraBold,
                                      color: o.isCountedInBalance
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminSubscriptionPayoutOverviewProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'الاشتراكات والكشف المالي'.tr,
      actions: [
        IconButton(
          tooltip: 'باقات الاشتراك'.tr,
          onPressed: () => context.push(AppRoutes.adminSubscriptionPlans),
          icon: Icon(AppIcons.wallet, color: AppBarDesign.iconColor),
        ),
      ],
      body: overviewAsync.skeletonWhen(
        placeholder: _placeholderOverview,
        skipLoadingOnReload: true,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل بيانات الاشتراكات والمالية',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () =>
                  ref.invalidate(adminSubscriptionPayoutOverviewProvider),
            ),
          ],
        ),
        data: (overview) {
          final filteredShops = overview.shops.where((s) {
            final q = _shopSearch.trim().toLowerCase();
            if (q.isEmpty) return true;
            return s.shopName.toLowerCase().contains(q) ||
                (s.shopCity?.toLowerCase().contains(q) ?? false) ||
                (s.ownerName?.toLowerCase().contains(q) ?? false);
          }).toList();

          final filteredSubs = overview.subscriptions.where((sub) {
            if (_subFilter == 'all') return true;
            return sub.status == _subFilter;
          }).toList();

          return AppRefreshIndicator(
            onRefresh: () =>
                ref.refresh(adminSubscriptionPayoutOverviewProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                if (overview.pendingSubscriptionsCount > 0) ...[
                  AdminNoticeBanner(
                    title:
                        '${'إشعارات اشتراك بانتظار المراجعة'.tr} (${overview.pendingSubscriptionsCount})',
                    message:
                        'هناك طلبات اشتراك أو تجديد جديدة مرفق معها إشعار الحوالة بانتظار التحقق والاعتماد.'
                            .tr,
                    tone: BadgeTone.warning,
                    actionLabel: 'مراجعة الإشعارات'.tr,
                    onAction: () => setState(() {
                      _selectedTab = 1;
                      _subFilter = 'pending';
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Top KPIs Row
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'إيرادات الاشتراكات',
                        value: AppFormat.price(
                          overview.totalSubscriptionRevenue,
                        ),
                        subtitle:
                            '${'نشط'.tr}: ${overview.activeSubscriptionsCount} · ${'منتهي'.tr}: ${overview.expiredSubscriptionsCount}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'متبقي للمحلات (100%)',
                        value: AppFormat.price(overview.totalOwedToShops),
                        subtitle:
                            '${'محوّل'.tr}: ${AppFormat.price(overview.totalPaidToShops)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Quick Management Shortcuts
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.adminSubscriptionPlans),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.borderStrong),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                        icon: const Icon(Icons.layers_outlined, size: 18),
                        label: Text('إدارة باقات الاشتراك'.tr),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.adminPaymentMethods),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.borderStrong),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                        ),
                        icon: const Icon(Icons.account_balance_outlined, size: 18),
                        label: Text('حسابات التحويل'.tr),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Segment Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AdminSegmentBtn(
                          label:
                              '${'الكشف المالي للمحلات'.tr} (${overview.shops.length})',
                          selected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _AdminSegmentBtn(
                          label:
                              '${'إشعارات الاشتراكات'.tr} (${overview.subscriptions.length})',
                          selected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (_selectedTab == 0) ...[
                  AppTextField(
                    label: 'بحث باسم المحل أو المدينة...'.tr,
                    prefixIcon: AppIcons.search,
                    onChanged: (v) => setState(() => _shopSearch = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filteredShops.isEmpty)
                    AppEmpty(
                      icon: AppIcons.shop,
                      title: 'لا توجد محلات مطابقة'.tr,
                      message:
                          'سيظهر هنا الكشف المالي الكامل لكل محل (100% من مبيعاته بدون عمولة).'
                              .tr,
                    )
                  else
                    for (final shop in filteredShops) ...[
                      _AdminShopFinanceCard(
                        shop: shop,
                        formatDate: _formatDate,
                        onOpenStatement: () => _openShopStatementSheet(shop),
                        onRecordPayout: busy
                            ? null
                            : () => _openRecordPayoutSheet(
                                shopId: shop.shopId,
                                shopName: shop.shopName,
                                remainingOwed: shop.remainingOwed,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ] else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text('الكل'.tr),
                          selected: _subFilter == 'all',
                          onSelected: (_) => setState(() => _subFilter = 'all'),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ChoiceChip(
                          label: Text(
                            '${'بانتظار المراجعة'.tr} (${overview.pendingSubscriptionsCount})',
                          ),
                          selected: _subFilter == 'pending',
                          onSelected: (_) =>
                              setState(() => _subFilter = 'pending'),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ChoiceChip(
                          label: Text('معتمدة'.tr),
                          selected: _subFilter == 'approved',
                          onSelected: (_) =>
                              setState(() => _subFilter = 'approved'),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ChoiceChip(
                          label: Text('مرفوضة'.tr),
                          selected: _subFilter == 'rejected',
                          onSelected: (_) =>
                              setState(() => _subFilter = 'rejected'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (filteredSubs.isEmpty)
                    AppEmpty(
                      icon: AppIcons.wallet,
                      title: 'لا توجد طلبات اشتراك هنا'.tr,
                      message:
                          'ستظهر هنا جميع طلبات اشتراك وتجديد المحلات مع صور إشعارات التحويل.'
                              .tr,
                    )
                  else
                    for (final sub in filteredSubs) ...[
                      _AdminSubscriptionRequestCard(
                        record: sub,
                        busy: busy,
                        formatDate: _formatDate,
                        formatDateTime: _formatDateTime,
                        onApprove: () =>
                            _reviewSubscription(sub, approve: true),
                        onReject: () =>
                            _reviewSubscription(sub, approve: false),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminShopFinanceCard extends StatelessWidget {
  const _AdminShopFinanceCard({
    required this.shop,
    required this.formatDate,
    required this.onOpenStatement,
    required this.onRecordPayout,
  });

  final ShopFinancialSummary shop;
  final String Function(DateTime?) formatDate;
  final VoidCallback onOpenStatement;
  final VoidCallback? onRecordPayout;

  @override
  Widget build(BuildContext context) {
    final subTone = shop.isSubscriptionActive
        ? BadgeTone.success
        : (shop.isSubscriptionExpired ? BadgeTone.error : BadgeTone.warning);
    final subLabel = shop.isSubscriptionActive
        ? 'اشتراك نشط'.tr
        : (shop.isSubscriptionExpired
              ? 'اشتراك منتهي'.tr
              : (shop.subscriptionStatus == 'pending'
                    ? 'اشتراك قيد المراجعة'.tr
                    : 'غير مشترك'.tr));

    return AppCard(
      onTap: onOpenStatement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.shopName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (shop.shopCity?.isNotEmpty ?? false) shop.shopCity!,
                        if (shop.ownerName?.isNotEmpty ?? false)
                          shop.ownerName!,
                        if (shop.subscriptionPlanName?.isNotEmpty ?? false)
                          shop.subscriptionPlanName!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(label: subLabel, tone: subTone),
            ],
          ),
          if (shop.subscriptionEndsAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '${'ينتهي الاشتراك'.tr}: ${formatDate(shop.subscriptionEndsAt)}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
          const Divider(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'الطلبات'.tr,
                  value: '${shop.totalOrders} (${shop.deliveredOrders} ✓)',
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: 'مبيعات (100%)'.tr,
                  value: AppFormat.price(shop.verifiedSales),
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: 'تم تحويله'.tr,
                  value: AppFormat.price(shop.totalPaidOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'المتبقي للمحل'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                ),
                Text(
                  AppFormat.price(shop.remainingOwed),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: AppFont.extraBold,
                    color: shop.remainingOwed > 0
                        ? AppColors.primary
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenStatement,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: AppColors.borderStrong),
                  ),
                  child: Text('كشف الحساب'.tr),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: onRecordPayout,
                  child: Text('تحويل مستحقات'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminSubscriptionRequestCard extends StatelessWidget {
  const _AdminSubscriptionRequestCard({
    required this.record,
    required this.busy,
    required this.formatDate,
    required this.formatDateTime,
    required this.onApprove,
    required this.onReject,
  });

  final ShopSubscriptionRecord record;
  final bool busy;
  final String Function(DateTime?) formatDate;
  final String Function(DateTime?) formatDateTime;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final tone = switch (record.status) {
      'approved' => BadgeTone.success,
      'rejected' => BadgeTone.error,
      _ => BadgeTone.warning,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.shopName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.planName} · ${AppFormat.price(record.amount)} · ${record.isRenewal ? 'تجديد'.tr : 'تسجيل جديد'.tr}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: AppFont.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(label: record.statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              formatDateTime(record.createdAt),
              if (record.paymentMethodName?.isNotEmpty ?? false)
                record.paymentMethodName!,
              if (record.ownerPhone?.isNotEmpty ?? false) record.ownerPhone!,
            ].join(' · '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          if (record.startsAt != null && record.endsAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '${'الصلاحية'.tr}: ${formatDate(record.startsAt)} → ${formatDate(record.endsAt)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.success),
            ),
          ],
          if (record.notes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              '${'ملاحظة التاجر'.tr}: ${record.notes!.trim()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (record.rejectionReason?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              '${'سبب الرفض'.tr}: ${record.rejectionReason!.trim()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
          if (record.receiptUrl.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ReceiptThumbnailCard(
              imageUrl: record.receiptUrl.trim(),
              subtitle:
                  '${record.shopName} — ${record.planName} (${AppFormat.price(record.amount)})',
              height: 170,
            ),
          ],
          if (record.isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text('رفض'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: busy ? null : onApprove,
                    child: Text('اعتماد وتفعيل الاشتراك'.tr),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: AppFont.bold),
        ),
      ],
    );
  }
}

class _AdminSegmentBtn extends StatelessWidget {
  const _AdminSegmentBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSkeleton = AppSkeleton.isActive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isSkeleton ? SkeletonDesign.base : AppColors.primary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: AppFont.bold,
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
