import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/subscription_models.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';
import '../widgets/subscription_payment_section.dart';

const _placeholderStatement = ShopFinancialStatement(
  shopId: 'skeleton-shop',
  shopName: 'متجر نموذجي',
  subscriptionStatus: 'active',
  subscriptionPlanName: 'الباقة الشهرية',
  subscriptionPrice: 30,
  daysRemaining: 22,
  totalOrders: 14,
  deliveredOrders: 10,
  inProgressOrders: 3,
  cancelledOrders: 1,
  verifiedSales: 1450,
  inProgressSales: 320,
  totalPaidOut: 900,
  remainingOwed: 550,
);

class ShopSalesScreen extends ConsumerStatefulWidget {
  const ShopSalesScreen({super.key});

  @override
  ConsumerState<ShopSalesScreen> createState() => _ShopSalesScreenState();
}

class _ShopSalesScreenState extends ConsumerState<ShopSalesScreen> {
  int _selectedTab = 0; // 0: Orders, 1: Payouts, 2: Subscriptions

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

  Future<void> _openRenewSubscriptionSheet() async {
    String? selectedPlanId;
    String? selectedPaymentMethodId;
    PickedBytes? pickedReceipt;
    final notesCtrl = TextEditingController();
    var submitting = false;

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.92,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> submitRenewal() async {
            if (submitting) return;
            FocusScope.of(sheetCtx).unfocus();
            if (selectedPlanId == null || selectedPlanId!.isEmpty) {
              showAppSnackBar(
                sheetCtx,
                'يرجى اختيار باقة الاشتراك أولاً'.tr,
                isError: true,
              );
              return;
            }
            if (selectedPaymentMethodId == null ||
                selectedPaymentMethodId!.isEmpty) {
              showAppSnackBar(
                sheetCtx,
                'يرجى اختيار حساب التحويل أولاً'.tr,
                isError: true,
              );
              return;
            }
            if (pickedReceipt == null) {
              showAppSnackBar(
                sheetCtx,
                'يرجى إرفاق صورة إشعار تحويل الاشتراك'.tr,
                isError: true,
              );
              return;
            }

            setSheetState(() => submitting = true);
            final actions = ref.read(shopActionProvider.notifier);
            try {
              final receiptUrl = await ref
                  .read(shopRepositoryProvider)
                  .uploadSubscriptionReceipt(
                    bytes: pickedReceipt!.bytes,
                    fileName: pickedReceipt!.fileName,
                    contentType: pickedReceipt!.contentType,
                  );

              final ok = await actions.submitSubscriptionRenewal(
                planId: selectedPlanId!,
                paymentMethodId: selectedPaymentMethodId!,
                receiptUrl: receiptUrl,
                notes: notesCtrl.text,
              );
              if (!mounted) return;
              if (!ok) {
                if (sheetCtx.mounted) setSheetState(() => submitting = false);
                final err = ref.read(shopActionProvider).error;
                showAppSnackBar(
                  context,
                  err == null
                      ? 'تعذر إرسال طلب التجديد'.tr
                      : actions.errorMessage(err),
                  isError: true,
                );
                return;
              }
              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              showAppSnackBar(
                context,
                'تم إرسال إشعار تجديد الاشتراك وستقوم الإدارة بمراجعته'.tr,
              );
            } catch (error) {
              if (sheetCtx.mounted) setSheetState(() => submitting = false);
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
            title: 'تجديد اشتراك المتجر'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SubscriptionPaymentSection(
                  selectedPlanId: selectedPlanId,
                  onPlanSelected: (p) =>
                      setSheetState(() => selectedPlanId = p.id),
                  selectedPaymentMethodId: selectedPaymentMethodId,
                  onPaymentMethodSelected: (m) =>
                      setSheetState(() => selectedPaymentMethodId = m.id),
                  pickedReceiptBytes: pickedReceipt?.bytes,
                  pickedReceiptName: pickedReceipt?.fileName,
                  existingReceiptUrl: null,
                  onReceiptPicked: (picked) =>
                      setSheetState(() => pickedReceipt = picked),
                  onReceiptCleared: () =>
                      setSheetState(() => pickedReceipt = null),
                  notesController: notesCtrl,
                  enabled: !submitting,
                  title: 'اختر باقة التجديد وأرفق الإشعار'.tr,
                  subtitle:
                      'بعد التحويل، سيتم تفعيل أو تمديد اشتراكك فور مراجعة الإدارة.'
                          .tr,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'إرسال طلب تجديد الاشتراك'.tr,
                  isLoading: submitting,
                  onPressed: submitting ? null : submitRenewal,
                ),
              ],
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statementAsync = ref.watch(myShopFinancialStatementProvider);

    return ShopScaffold(
      title: 'الاشتراك والكشف المالي'.tr,
      showBottomNav: false,
      body: statementAsync.skeletonWhen(
        placeholder: _placeholderStatement,
        skipLoadingOnReload: true,
        error: (error, _) => ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل الكشف المالي'.tr,
              message: ref.read(shopRepositoryProvider).mapError(error),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة'.tr,
              onAction: () => ref.invalidate(myShopFinancialStatementProvider),
            ),
          ],
        ),
        data: (raw) {
          final stmt = raw ?? _placeholderStatement;

          return AppRefreshIndicator(
            onRefresh: () => Future.wait([
              ref.refresh(myShopProvider.future),
              ref.refresh(myShopFinancialStatementProvider.future),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                // 1) Subscription Status Card
                _SubscriptionStatusCard(
                  statement: stmt,
                  formatDate: _formatDate,
                  onRenew: _openRenewSubscriptionSheet,
                ),
                const SizedBox(height: AppSpacing.md),

                // 2) 100% Zero-Commission Financial Hero Card
                Builder(
                  builder: (heroCtx) {
                    final isSkeleton = AppSkeleton.isActive(heroCtx);
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isSkeleton
                            ? SellerDesign.statCardBackground
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(
                          SellerDesign.statCardRadius,
                        ),
                        border: isSkeleton
                            ? Border.all(color: SellerDesign.statCardBorder)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'المتبقي لك لدى المنصة (100%)'.tr,
                                  style: Theme.of(heroCtx).textTheme.titleSmall
                                      ?.copyWith(
                                        color: isSkeleton
                                            ? AppColors.textMuted
                                            : AppColors.onPrimary.withValues(
                                                alpha: 0.9,
                                              ),
                                        fontWeight: AppFont.semiBold,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isSkeleton
                                      ? SkeletonDesign.base
                                      : Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                                child: Text(
                                  'عمولة 0%'.tr,
                                  style: TextStyle(
                                    color: isSkeleton
                                        ? AppColors.textMuted
                                        : AppColors.onPrimary,
                                    fontSize: AppFont.tiny,
                                    fontWeight: AppFont.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              AppFormat.price(stmt.remainingOwed),
                              style: TextStyle(
                                fontSize: AppFont.display,
                                fontWeight: AppFont.extraBold,
                                color: isSkeleton
                                    ? AppColors.text
                                    : AppColors.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _HeroMetaItem(
                                  label: 'مبيعات معتمدة (100% لك)'.tr,
                                  value: AppFormat.price(stmt.verifiedSales),
                                ),
                              ),
                              Expanded(
                                child: _HeroMetaItem(
                                  label: 'تم تحويله لك'.tr,
                                  value: AppFormat.price(stmt.totalPaidOut),
                                ),
                              ),
                            ],
                          ),
                          if (stmt.inProgressSales > 0) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${'طلبات قيد التنفيذ (غير مكتملة بعد)'.tr}: ${AppFormat.price(stmt.inProgressSales)}',
                              style: TextStyle(
                                fontSize: AppFont.tiny,
                                color: isSkeleton
                                    ? AppColors.textMuted
                                    : AppColors.onPrimary.withValues(
                                        alpha: 0.85,
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // 3) Orders Breakdown Strip
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatBox(
                        label: 'الطلبات'.tr,
                        value: '${stmt.totalOrders}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _MiniStatBox(
                        label: 'مكتملة'.tr,
                        value: '${stmt.deliveredOrders}',
                        valueColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _MiniStatBox(
                        label: 'قيد التنفيذ'.tr,
                        value: '${stmt.inProgressOrders}',
                        valueColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _MiniStatBox(
                        label: 'ملغاة'.tr,
                        value: '${stmt.cancelledOrders}',
                        valueColor: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 4) Tabs Switcher: Orders | Payouts | Subscriptions
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
                        child: _TabPill(
                          label: '${'الطلبات'.tr} (${stmt.orders.length})',
                          selected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _TabPill(
                          label: '${'التحويلات'.tr} (${stmt.payouts.length})',
                          selected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                      Expanded(
                        child: _TabPill(
                          label:
                              '${'الاشتراكات'.tr} (${stmt.subscriptions.length})',
                          selected: _selectedTab == 2,
                          onTap: () => setState(() => _selectedTab = 2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (_selectedTab == 0) ...[
                  if (stmt.orders.isEmpty)
                    ShopEmptyState(
                      title: 'لا توجد طلبات مسجلة بعد'.tr,
                      message:
                          'ستظهر هنا جميع طلبات متجرك وتفاصيل مستحقاتك الكاملة (100% بدون عمولة).'
                              .tr,
                    )
                  else
                    for (final order in stmt.orders) ...[
                      _OrderStatementTile(
                        order: order,
                        formatDateTime: _formatDateTime,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                ] else if (_selectedTab == 1) ...[
                  if (stmt.payouts.isEmpty)
                    ShopEmptyState(
                      title: 'لا توجد تحويلات مستحقات بعد'.tr,
                      message:
                          'عندما تقوم الإدارة بتحويل مستحقات مبيعاتك إلى حسابك ستظهر جميع التحويلات وإشعاراتها هنا.'
                              .tr,
                    )
                  else
                    for (final payout in stmt.payouts) ...[
                      _PayoutTile(
                        payout: payout,
                        formatDateTime: _formatDateTime,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                ] else ...[
                  if (stmt.subscriptions.isEmpty)
                    ShopEmptyState(
                      title: 'لا يوجد سجل اشتراكات بعد'.tr,
                      message:
                          'ستظهر هنا جميع باقات الاشتراك والتجديدات مع حالة كل إشعار.'
                              .tr,
                    )
                  else
                    for (final sub in stmt.subscriptions) ...[
                      _SubscriptionHistoryTile(
                        record: sub,
                        formatDate: _formatDate,
                        formatDateTime: _formatDateTime,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                ],

                const SizedBox(height: AppSpacing.lg),
                ShopFeatureTile(
                  title: 'متابعة الطلبات',
                  subtitle: 'تحديث حالات الطلبات قيد المعالجة والشحن',
                  trailingValue: '${stmt.totalOrders}',
                  onTap: () => context.go(AppRoutes.shopOrders),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({
    required this.statement,
    required this.formatDate,
    required this.onRenew,
  });

  final ShopFinancialStatement statement;
  final String Function(DateTime?) formatDate;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final isExpired = statement.isSubscriptionExpired;
    final isActive = statement.isSubscriptionActive;
    final hasPending = statement.hasPendingRenewal;

    final badgeTone = isExpired
        ? BadgeTone.error
        : (isActive ? BadgeTone.success : BadgeTone.warning);
    final badgeLabel = isExpired
        ? 'منتهي — يحتاج تجديد'.tr
        : (isActive
              ? 'فعّال'.tr
              : (statement.subscriptionStatus == 'pending'
                    ? 'بانتظار المراجعة'.tr
                    : 'غير مفعّل'.tr));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
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
                      'حالة اشتراك المتجر'.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    if (statement.subscriptionPlanName?.trim().isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${statement.subscriptionPlanName!} · ${AppFormat.price(statement.subscriptionPrice)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppStatusBadge(label: badgeLabel, tone: badgeTone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (statement.subscriptionEndsAt != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    isExpired
                        ? '${'انتهى بتاريخ'.tr}: ${formatDate(statement.subscriptionEndsAt)}'
                        : '${'ينتهي بتاريخ'.tr}: ${formatDate(statement.subscriptionEndsAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (isActive && statement.daysRemaining > 0)
                  Text(
                    AppLang.isEn
                        ? '${statement.daysRemaining}d left'
                        : 'متبقي ${statement.daysRemaining} يوم',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: AppFont.bold,
                      color: statement.daysRemaining <= 5
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
              ],
            ),
          if (hasPending) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'لديك طلب تجديد اشتراك قيد المراجعة من الإدارة حالياً.'.tr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: AppFont.semiBold,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: isExpired
                ? 'تجديد الاشتراك الآن'.tr
                : 'تجديد أو ترقية الباقة'.tr,
            variant: isExpired
                ? AppButtonVariant.filled
                : AppButtonVariant.secondary,
            onPressed: onRenew,
          ),
        ],
      ),
    );
  }
}

class _OrderStatementTile extends StatelessWidget {
  const _OrderStatementTile({
    required this.order,
    required this.formatDateTime,
  });

  final ShopStatementOrder order;
  final String Function(DateTime?) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final tone = switch (order.status) {
      'delivered' => BadgeTone.success,
      'cancelled' => BadgeTone.error,
      _ => BadgeTone.warning,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.customerName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
                ),
              ),
              AppStatusBadge(label: order.statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateTime(order.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
              Text(
                AppFormat.price(order.total),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: AppFont.extraBold,
                  color: order.isCountedInBalance
                      ? AppColors.success
                      : AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${'المنتجات'.tr}: ${AppFormat.price(order.subtotal)} · ${'التوصيل'.tr}: ${AppFormat.price(order.deliveryFee)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
              Text(
                order.isCountedInBalance
                    ? 'محتسب في رصيدك (100%)'.tr
                    : (order.status == 'cancelled'
                          ? 'ملغي'.tr
                          : 'بانتظار التأكيد/التسليم'.tr),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: order.isCountedInBalance
                      ? AppColors.success
                      : AppColors.textMuted,
                  fontWeight: AppFont.semiBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout, required this.formatDateTime});

  final ShopPayoutRecord payout;
  final String Function(DateTime?) formatDateTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
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
                      payout.paymentMethodLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDateTime(payout.paidAt ?? payout.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+ ${AppFormat.price(payout.amount)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: AppFont.extraBold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (payout.referenceNo?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              '${'رقم المرجع'.tr}: ${payout.referenceNo!.trim()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (payout.notes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              payout.notes!.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (payout.receiptUrl?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            ReceiptThumbnailCard(
              imageUrl: payout.receiptUrl!.trim(),
              subtitle: 'إشعار تحويل المستحقات'.tr,
              height: 130,
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionHistoryTile extends StatelessWidget {
  const _SubscriptionHistoryTile({
    required this.record,
    required this.formatDate,
    required this.formatDateTime,
  });

  final ShopSubscriptionRecord record;
  final String Function(DateTime?) formatDate;
  final String Function(DateTime?) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final tone = switch (record.status) {
      'approved' => BadgeTone.success,
      'rejected' => BadgeTone.error,
      _ => BadgeTone.warning,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${record.planName} · ${AppFormat.price(record.amount)}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
                ),
              ),
              AppStatusBadge(label: record.statusLabel, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${record.isRenewal ? 'تجديد اشتراك'.tr : 'اشتراك تأسيس'.tr} · ${formatDateTime(record.createdAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          if (record.startsAt != null && record.endsAt != null) ...[
            const SizedBox(height: 2),
            Text(
              '${'الفترة'.tr}: ${formatDate(record.startsAt)} → ${formatDate(record.endsAt)}',
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
              subtitle: 'إشعار تحويل الاشتراك'.tr,
              height: 120,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: AppFont.extraBold,
              color: valueColor ?? AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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

class _HeroMetaItem extends StatelessWidget {
  const _HeroMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: AppFont.tiny,
            color: AppColors.onPrimary.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: AppFont.subtitle,
            fontWeight: AppFont.bold,
            color: AppColors.onPrimary,
          ),
        ),
      ],
    );
  }
}
