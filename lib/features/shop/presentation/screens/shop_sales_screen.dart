import 'package:fashion_marketplace/core/utils/app_haptics.dart';
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
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/revenue_models.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopSalesScreen extends ConsumerStatefulWidget {
  const ShopSalesScreen({super.key});

  @override
  ConsumerState<ShopSalesScreen> createState() => _ShopSalesScreenState();
}

class _ShopSalesScreenState extends ConsumerState<ShopSalesScreen> {
  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year} • ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptAgreement() async {
    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.acceptCommissionAgreement();
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر توثيق الموافقة'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم توثيق موافقتك على اتفاقية العمولة'.tr);
  }

  Future<void> _openSubmitSettlementSheet(ShopFinancialAccount account) async {
    final amountCtrl = TextEditingController(
      text: account.outstandingBalance > 0
          ? account.outstandingBalance.toStringAsFixed(2)
          : '',
    );
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var method = 'cash';
    var receiptUrl = '';
    var uploading = false;
    var saving = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.92,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> uploadReceipt() async {
            final picked = await MediaPicker.pickImage();
            if (picked == null || !sheetCtx.mounted) return;
            setSheetState(() => uploading = true);
            try {
              final url = await ref
                  .read(shopStorageRepositoryProvider)
                  .uploadBytes(
                    bucket: 'shop-media',
                    folder: 'receipts',
                    fileName: picked.fileName,
                    bytes: picked.bytes,
                    contentType: picked.contentType,
                  );
              if (!sheetCtx.mounted) return;
              setSheetState(() {
                receiptUrl = url;
                uploading = false;
              });
            } catch (error) {
              if (!sheetCtx.mounted) return;
              setSheetState(() => uploading = false);
              if (mounted) {
                showAppSnackBar(
                  context,
                  ref.read(shopStorageRepositoryProvider).mapError(error),
                  isError: true,
                );
              }
            }
          }

          return AppBottomSheetScaffold(
            title: 'تقديم طلب سداد وتسوية'.tr,
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
                            'المستحق الحالي للمنصة'.tr,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                        Text(
                          AppFormat.price(account.outstandingBalance),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: AppFont.extraBold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: amountCtrl,
                    label: 'مبلغ السداد (₪) *'.tr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    'طريقة الدفع'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: Text('نقداً (كاش)'.tr),
                        selected: method == 'cash',
                        onSelected: (_) => setSheetState(() => method = 'cash'),
                      ),
                      ChoiceChip(
                        label: Text('تحويل بنكي'.tr),
                        selected: method == 'bank_transfer',
                        onSelected: (_) =>
                            setSheetState(() => method = 'bank_transfer'),
                      ),
                      ChoiceChip(
                        label: Text('جوال باي'.tr),
                        selected: method == 'jawwal_pay',
                        onSelected: (_) =>
                            setSheetState(() => method = 'jawwal_pay'),
                      ),
                      ChoiceChip(
                        label: Text('بال باي'.tr),
                        selected: method == 'palpay',
                        onSelected: (_) =>
                            setSheetState(() => method = 'palpay'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: refCtrl,
                    label: 'رقم الحوالة أو الإيصال (اختياري)'.tr,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: receiptUrl.isEmpty
                        ? 'إرفاق صورة الإيصال (اختياري)'.tr
                        : 'تم إرفاق الإيصال — تغيير الصورة'.tr,
                    variant: AppButtonVariant.secondary,
                    isLoading: uploading,
                    onPressed: saving ? null : uploadReceipt,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: notesCtrl,
                    label: 'ملاحظات للإدارة (اختياري)'.tr,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'إرسال طلب التسوية للمراجعة'.tr,
                    isLoading: saving,
                    onPressed: uploading
                        ? null
                        : () async {
                            FocusScope.of(sheetCtx).unfocus();
                            if (formKey.currentState?.validate() != true) {
                              return;
                            }
                            setSheetState(() => saving = true);
                            final amount = double.parse(
                              amountCtrl.text.trim().replaceAll('٫', '.'),
                            );
                            final actions = ref.read(
                              shopCatalogActionProvider.notifier,
                            );
                            final ok = await actions.submitSettlement(
                              amount: amount,
                              paymentMethod: method,
                              referenceNumber: refCtrl.text,
                              receiptUrl: receiptUrl,
                              notes: notesCtrl.text,
                            );
                            if (!mounted) return;
                            if (!ok) {
                              if (sheetCtx.mounted) {
                                setSheetState(() => saving = false);
                              }
                              final err = ref
                                  .read(shopCatalogActionProvider)
                                  .error;
                              showAppSnackBar(
                                context,
                                err == null
                                    ? 'تعذر إرسال طلب التسوية'.tr
                                    : actions.errorMessage(err),
                                isError: true,
                              );
                              return;
                            }
                            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                            showAppSnackBar(
                              context,
                              'تم إرسال طلب التسوية وستقوم الإدارة بمراجعته'.tr,
                            );
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    amountCtrl.dispose();
    refCtrl.dispose();
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(shopStatsProvider);
    final financeAsync = ref.watch(shopFinanceSummaryProvider);
    final busy = ref.watch(shopCatalogActionProvider).isLoading;

    return ShopScaffold(
      title: 'المبيعات والأرباح'.tr,
      showBottomNav: false,
      body: statsAsync.skeletonWhen(
        placeholder: LoadingFixtures.shopStats,
        skipLoadingOnReload: true,
        error: (error, _) => ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل بيانات المبيعات',
              message: ref.read(shopCatalogRepositoryProvider).mapError(error),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(shopStatsProvider),
            ),
          ],
        ),
        data: (stats) {
          final finance = financeAsync.asData?.value;
          final account = finance?.account;

          return AppRefreshIndicator(
            onRefresh: () => Future.wait([
              ref.refresh(shopStatsProvider.future),
              ref.refresh(shopFinanceSummaryProvider.future),
            ]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                if (account != null && !account.isAgreementAccepted) ...[
                  ShopNoticeBanner(
                    title: 'موافقة مطلوبة على اتفاقية العمولة',
                    message:
                        '${'نسبة المنصة المتفق عليها'.tr}: ${account.agreementSummaryLabel} · ${'سقف الذمة'.tr}: ${AppFormat.price(account.creditLimit)} · ${'التسوية'.tr}: ${account.cycleLabel.tr}.',
                    tone: BadgeTone.primary,
                    actionLabel: 'أوافق على اتفاقية العمولة',
                    onAction: busy ? null : _acceptAgreement,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (account != null && account.financialHold) ...[
                  ShopNoticeBanner(
                    title: 'المتجر في حالة تجميد مالي مؤقت',
                    message:
                        'تجاوزت المستحقات سقف الذمة المسموح. يرجى تقديم طلب تسوية لإعادة تفعيل المتجر فور التأكيد.',
                    tone: BadgeTone.error,
                    actionLabel: 'تقديم طلب سداد الآن',
                    onAction: busy
                        ? null
                        : () => _openSubmitSettlementSheet(account),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else if (account != null && account.isNearLimit) ...[
                  ShopNoticeBanner(
                    title: 'اقتربت من سقف الذمة المالية',
                    message:
                        'رصيد المستحقات الحالي يقارب السقف المسموح (${AppFormat.price(account.creditLimit)}). يرجى التسوية قريباً.',
                    tone: BadgeTone.warning,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 1) Hero Sales & Net Profit Summary
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(
                      SellerDesign.statCardRadius,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'صافي أرباح المحل (المسلّمة)'.tr,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.9),
                          fontWeight: AppFont.semiBold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          AppFormat.price(
                            account?.netShopEarnings ?? stats.salesTotal,
                          ),
                          style: TextStyle(
                            fontSize: AppFont.display,
                            fontWeight: AppFont.extraBold,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroMetaItem(
                              label: 'إجمالي المبيعات'.tr,
                              value: AppFormat.price(
                                account?.deliveredSales ?? stats.salesTotal,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _HeroMetaItem(
                              label: 'حصة المنصة'.tr,
                              value: AppFormat.price(
                                account?.commissionEarned ?? 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2) Commission Agreement & Outstanding Dues Card
                if (account != null) ...[
                  Container(
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
                                'اتفاقية العمولة والمستحقات'.tr,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: AppFont.bold),
                              ),
                            ),
                            AppStatusBadge(
                              label: account.agreementSummaryLabel,
                              tone: BadgeTone.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ShopFinanceLine(
                          label: 'دورة التسوية'.tr,
                          value: account.cycleLabel.tr,
                        ),
                        const SizedBox(height: 6),
                        _ShopFinanceLine(
                          label: 'تم سداده للمنصة'.tr,
                          value: AppFormat.price(account.totalPaid),
                        ),
                        const SizedBox(height: 6),
                        _ShopFinanceLine(
                          label: 'المستحق الحالي للسداد'.tr,
                          value: AppFormat.price(account.outstandingBalance),
                          bold: true,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: LinearProgressIndicator(
                            value: account.limitUsageRatio,
                            minHeight: 7,
                            backgroundColor: AppColors.surfaceAlt,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              account.financialHold || account.isOverLimit
                                  ? AppColors.error
                                  : (account.isNearLimit
                                        ? AppColors.warning
                                        : AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${'سقف الذمة المسموح'.tr}: ${AppFormat.price(account.creditLimit)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'تقديم طلب سداد / تسوية'.tr,
                          onPressed: busy
                              ? null
                              : () => _openSubmitSettlementSheet(account),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 3) Settlement Requests
                  if (finance!.settlements.isNotEmpty) ...[
                    AppSectionHeader(
                      title: 'طلبات التسوية المرسلة'.tr,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final stl in finance.settlements.take(10)) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: SellerDesign.statCardBackground,
                          borderRadius: BorderRadius.circular(
                            CardDesign.radius,
                          ),
                          border: Border.all(
                            color: SellerDesign.statCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppFormat.price(stl.amount)} · ${stl.methodLabel.tr}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: AppFont.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(stl.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                  ),
                                  if (stl.adminNote?.trim().isNotEmpty ??
                                      false) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      stl.adminNote!.trim(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            AppStatusBadge(
                              label: stl.statusLabel,
                              tone: switch (stl.status) {
                                'approved' => BadgeTone.success,
                                'rejected' => BadgeTone.error,
                                _ => BadgeTone.warning,
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 4) Ledger Movements
                  AppSectionHeader(
                    title: 'كشف الحركات المالية'.tr,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (finance.ledger.isEmpty)
                    const ShopEmptyState(
                      title: 'لا توجد حركات مالية بعد',
                      message:
                          'تُسجّل عمولة كل طلب تلقائياً هنا فور تسليم الطلب للعميل.',
                    )
                  else
                    for (final entry in finance.ledger.take(20)) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: SellerDesign.statCardBackground,
                          borderRadius: BorderRadius.circular(
                            CardDesign.radius,
                          ),
                          border: Border.all(
                            color: SellerDesign.statCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.note?.trim().isNotEmpty == true
                                        ? entry.note!.trim()
                                        : entry.typeLabel.tr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: AppFont.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(entry.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${entry.isDebit ? '+' : '-'}${AppFormat.price(entry.amount)}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: AppFont.extraBold,
                                    color: entry.isDebit
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Quick links
                ShopFeatureTile(
                  title: 'متابعة الطلبات',
                  subtitle: 'تحديث حالات الطلبات قيد المعالجة والشحن',
                  trailingValue: '${stats.orders}',
                  onTap: () => context.go(AppRoutes.shopOrders),
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopFeatureTile(
                  title: 'إدارة المنتجات والمخزون',
                  subtitle: 'مراجعة الأسعار والكميات المتوفرة ونشر المسودات',
                  trailingValue: '${stats.products}',
                  onTap: () => context.go(AppRoutes.shopProducts),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopFinanceLine extends StatelessWidget {
  const _ShopFinanceLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? AppFont.extraBold : AppFont.semiBold,
            color: AppColors.text,
          ),
        ),
      ],
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
