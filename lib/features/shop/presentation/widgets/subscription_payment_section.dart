import 'dart:typed_data';

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../admin/domain/models/payment_method.dart';
import '../../../admin/domain/models/subscription_models.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../providers/shop_providers.dart';

/// Standalone subscription plan selector used in Step 3 of onboarding and renewals.
class SubscriptionPlanPicker extends ConsumerWidget {
  const SubscriptionPlanPicker({
    super.key,
    required this.selectedPlanId,
    required this.onPlanSelected,
    this.enabled = true,
  });

  final String? selectedPlanId;
  final ValueChanged<SubscriptionPlan> onPlanSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(activeSubscriptionPlansProvider);

    return plansAsync.when(
      loading: () => const AppSkeleton(
        enabled: true,
        child: Column(
          children: [
            SizedBox(height: 92, width: double.infinity),
            SizedBox(height: AppSpacing.xs),
            SizedBox(height: 92, width: double.infinity),
          ],
        ),
      ),
      error: (_, _) => Container(
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
                'تعذر تحميل باقات الاشتراك'.tr,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(activeSubscriptionPlansProvider),
              child: Text('إعادة المحاولة'.tr),
            ),
          ],
        ),
      ),
      data: (plans) {
        if (plans.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'لا توجد باقات اشتراك مفعّلة حالياً. يرجى التواصل مع الإدارة.'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          );
        }

        if (selectedPlanId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onPlanSelected(plans.first);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final plan in plans) ...[
              _PlanOptionCard(
                plan: plan,
                selected: plan.id == selectedPlanId,
                enabled: enabled,
                onTap: () => onPlanSelected(plan),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

/// Standalone Admin transfer account picker (Bank / E-Wallet) with one-tap copy.
class AdminPaymentAccountsPicker extends ConsumerStatefulWidget {
  const AdminPaymentAccountsPicker({
    super.key,
    required this.selectedPaymentMethodId,
    required this.onPaymentMethodSelected,
    this.enabled = true,
  });

  final String? selectedPaymentMethodId;
  final ValueChanged<PaymentMethod> onPaymentMethodSelected;
  final bool enabled;

  @override
  ConsumerState<AdminPaymentAccountsPicker> createState() =>
      _AdminPaymentAccountsPickerState();
}

class _AdminPaymentAccountsPickerState
    extends ConsumerState<AdminPaymentAccountsPicker> {
  String _accountTypeFilter = 'bank';

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    AppHaptics.selection();
    if (!mounted) return;
    showAppSnackBar(context, '${'تم نسخ'.tr} $label');
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(activePaymentMethodsProvider);

    return methodsAsync.when(
      loading: () => const AppSkeleton(
        enabled: true,
        child: SizedBox(height: 120, width: double.infinity),
      ),
      error: (_, _) => Row(
        children: [
          Expanded(
            child: Text(
              'تعذر تحميل أرقام البنوك والمحافظ'.tr,
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(activePaymentMethodsProvider),
            child: Text('إعادة المحاولة'.tr),
          ),
        ],
      ),
      data: (methods) {
        if (methods.isEmpty) {
          return Text(
            'لا توجد وسائل دفع مفعّلة حالياً من الإدارة. يرجى المحاولة لاحقاً.'
                .tr,
            style: TextStyle(fontSize: 12, color: AppColors.warning),
          );
        }

        final banks = methods.where((m) => m.isBank).toList();
        final wallets = methods.where((m) => m.isWallet).toList();
        final hasBoth = banks.isNotEmpty && wallets.isNotEmpty;
        final activeType = _accountTypeFilter == 'wallet'
            ? (wallets.isNotEmpty ? 'wallet' : 'bank')
            : (banks.isNotEmpty ? 'bank' : 'wallet');
        final visibleMethods = activeType == 'wallet' ? wallets : banks;

        final activeSelected =
            visibleMethods.cast<PaymentMethod?>().firstWhere(
              (m) => m?.id == widget.selectedPaymentMethodId,
              orElse: () => null,
            ) ??
            (visibleMethods.isNotEmpty ? visibleMethods.first : null);

        if (activeSelected != null &&
            activeSelected.id != widget.selectedPaymentMethodId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                activeSelected.id != widget.selectedPaymentMethodId) {
              widget.onPaymentMethodSelected(activeSelected);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasBoth) ...[
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CheckoutSegmentedTab(
                        label: 'بنك'.tr,
                        selected: activeType == 'bank',
                        onTap: !widget.enabled
                            ? null
                            : () {
                                AppHaptics.selection();
                                setState(() => _accountTypeFilter = 'bank');
                                if (banks.isNotEmpty) {
                                  widget.onPaymentMethodSelected(banks.first);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _CheckoutSegmentedTab(
                        label: 'محفظة'.tr,
                        selected: activeType == 'wallet',
                        onTap: !widget.enabled
                            ? null
                            : () {
                                AppHaptics.selection();
                                setState(() => _accountTypeFilter = 'wallet');
                                if (wallets.isNotEmpty) {
                                  widget.onPaymentMethodSelected(wallets.first);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: visibleMethods.map((m) {
                  final isSelected = activeSelected?.id == m.id;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: InkWell(
                      onTap: !widget.enabled
                          ? null
                          : () {
                              AppHaptics.selection();
                              widget.onPaymentMethodSelected(m);
                            },
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CheckoutDesign.optionSelectedBackground
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          m.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? AppFont.bold
                                : AppFont.medium,
                            color: isSelected
                                ? AppColors.text
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (activeSelected != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _CheckoutAccountRow(
                label: activeSelected.accountHolder.trim().isNotEmpty
                    ? activeSelected.accountHolder.trim()
                    : (activeSelected.isWallet
                          ? 'رقم المحفظة'.tr
                          : 'رقم الحساب'.tr),
                value: activeSelected.accountNumber,
                onCopy: () => _copyText(
                  activeSelected.isWallet ? 'رقم المحفظة'.tr : 'رقم الحساب'.tr,
                  activeSelected.accountNumber,
                ),
              ),
              if (activeSelected.iban != null &&
                  activeSelected.iban!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                _CheckoutAccountRow(
                  label: 'IBAN',
                  value: activeSelected.iban!.trim(),
                  onCopy: () => _copyText('IBAN', activeSelected.iban!.trim()),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Standalone transfer receipt uploader matching Customer Checkout style.
class TransferReceiptUploader extends StatelessWidget {
  const TransferReceiptUploader({
    super.key,
    required this.pickedReceiptBytes,
    required this.pickedReceiptName,
    required this.existingReceiptUrl,
    required this.onReceiptPicked,
    required this.onReceiptCleared,
    this.notesController,
    this.enabled = true,
  });

  final Uint8List? pickedReceiptBytes;
  final String? pickedReceiptName;
  final String? existingReceiptUrl;
  final ValueChanged<PickedBytes> onReceiptPicked;
  final VoidCallback onReceiptCleared;
  final TextEditingController? notesController;
  final bool enabled;

  Future<void> _pick(BuildContext context, {required bool fromCamera}) async {
    if (!enabled) return;
    try {
      final picked = fromCamera
          ? await MediaPicker.pickFromCamera()
          : await MediaPicker.pickImage();
      if (picked == null || !context.mounted) return;
      onReceiptPicked(picked);
    } catch (_) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'تعذر اختيار صورة الإشعار، حاول مرة أخرى'.tr,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = existingReceiptUrl?.trim().isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _CheckoutReceiptAction(
                icon: AppIcons.addPhoto,
                label: 'من المعرض'.tr,
                onTap: enabled ? () => _pick(context, fromCamera: false) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CheckoutReceiptAction(
                icon: IconsaxPlusLinear.camera,
                label: 'تصوير الإشعار'.tr,
                onTap: enabled ? () => _pick(context, fromCamera: true) : null,
              ),
            ),
          ],
        ),
        if (pickedReceiptBytes != null || hasExisting) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: (pickedReceiptBytes == null && hasExisting)
                ? () => showReceiptImageViewer(
                    context,
                    imageUrl: existingReceiptUrl!.trim(),
                    title: 'إشعار الحوالة المرفق'.tr,
                  )
                : null,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (pickedReceiptBytes != null)
                    Image.memory(pickedReceiptBytes!, fit: BoxFit.contain)
                  else
                    AppNetworkImage(
                      existingReceiptUrl!.trim(),
                      fit: BoxFit.contain,
                    ),
                  if (pickedReceiptBytes != null && enabled)
                    PositionedDirectional(
                      top: 8,
                      end: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onReceiptCleared,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (notesController != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: notesController,
              enabled: enabled,
              minLines: 2,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: AppColors.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                hintText: 'ملاحظات إضافية حول الحوالة (اختياري)'.tr,
                hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Icon(
                    AppIcons.notes,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Combined subscription plan + Admin transfer + receipt section (used in Renewal sheet).
class SubscriptionPaymentSection extends StatelessWidget {
  const SubscriptionPaymentSection({
    super.key,
    required this.selectedPlanId,
    required this.onPlanSelected,
    required this.selectedPaymentMethodId,
    required this.onPaymentMethodSelected,
    required this.pickedReceiptBytes,
    required this.pickedReceiptName,
    required this.existingReceiptUrl,
    required this.onReceiptPicked,
    required this.onReceiptCleared,
    this.notesController,
    this.enabled = true,
    this.title,
    this.subtitle,
  });

  final String? selectedPlanId;
  final ValueChanged<SubscriptionPlan> onPlanSelected;
  final String? selectedPaymentMethodId;
  final ValueChanged<PaymentMethod> onPaymentMethodSelected;
  final Uint8List? pickedReceiptBytes;
  final String? pickedReceiptName;
  final String? existingReceiptUrl;
  final ValueChanged<PickedBytes> onReceiptPicked;
  final VoidCallback onReceiptCleared;
  final TextEditingController? notesController;
  final bool enabled;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  AppIcons.wallet,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? 'باقة الاشتراك وتحويل الرسوم'.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle ??
                          'اشتراك ثابت بدون أي عمولة على المبيعات (0% عمولة)'.tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '1. اختر باقة الاشتراك'.tr,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          SubscriptionPlanPicker(
            selectedPlanId: selectedPlanId,
            onPlanSelected: onPlanSelected,
            enabled: enabled,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '2. حوّل قيمة الاشتراك إلى أحد حسابات الإدارة'.tr,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          AdminPaymentAccountsPicker(
            selectedPaymentMethodId: selectedPaymentMethodId,
            onPaymentMethodSelected: onPaymentMethodSelected,
            enabled: enabled,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '3. أرفق صورة إشعار التحويل *'.tr,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'التقط صورة واضحة أو اختر لقطة شاشة لإشعار الحوالة ليتم اعتماد اشتراكك بسرعة.'
                .tr,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          TransferReceiptUploader(
            pickedReceiptBytes: pickedReceiptBytes,
            pickedReceiptName: pickedReceiptName,
            existingReceiptUrl: existingReceiptUrl,
            onReceiptPicked: onReceiptPicked,
            onReceiptCleared: onReceiptCleared,
            notesController: notesController,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({
    required this.plan,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  String _formatWholeOrDecimal(double amount) {
    final isWhole = amount == amount.roundToDouble();
    final numStr = isWhole
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '$numStr ₪';
  }

  String _periodSuffix() {
    if (plan.durationDays == 30) return '/ شهر'.tr;
    if (plan.durationDays == 90) return '/ 3 شهور'.tr;
    if (plan.durationDays == 180) return '/ 6 شهور'.tr;
    if (plan.durationDays == 365) return '/ سنة'.tr;
    return AppLang.isEn
        ? '/ ${plan.durationDays}d'
        : '/ ${plan.durationDays} يوم';
  }

  String? _monthlyEquivalentLabel() {
    if (plan.durationDays <= 30 || plan.price <= 0) return null;
    final months = plan.durationDays / 30.0;
    final perMonth = plan.price / months;
    final formatted = perMonth == perMonth.roundToDouble()
        ? perMonth.toInt().toString()
        : perMonth.toStringAsFixed(1);
    return AppLang.isEn
        ? '~$formatted ₪ / month'
        : 'يعادل $formatted ₪ شهرياً';
  }

  @override
  Widget build(BuildContext context) {
    final monthlyEq = _monthlyEquivalentLabel();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceAlt : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: selected ? AppColors.borderStrong : AppColors.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) Clean Header Row: Selection Check + Title/Duration | Prominent Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.borderStrong,
                        width: 1.6,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: AppColors.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                plan.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: AppFont.extraBold),
                              ),
                            ),
                            if (plan.durationDays >= 365) ...[
                              const SizedBox(width: 6),
                              AppStatusBadge(
                                label: 'الأوفر'.tr,
                                tone: BadgeTone.success,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          monthlyEq != null
                              ? '${plan.durationLabel} · $monthlyEq'
                              : plan.durationLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatWholeOrDecimal(plan.price),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: AppFont.extraBold,
                          color: AppColors.primary,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _periodSuffix(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: AppFont.semiBold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.sm),

              // 2) Clear Description + Key Benefits
              if (plan.description?.trim().isNotEmpty ?? false) ...[
                Text(
                  plan.description!.trim(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],

              _PlanFeatureLine(
                text: 'عمولة 0% على المبيعات — 100% من أرباح طلباتك لك'.tr,
              ),
              const SizedBox(height: 4),
              _PlanFeatureLine(
                text: 'نشر المنتجات واستقبال الطلبات وكشف مالي متكامل'.tr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanFeatureLine extends StatelessWidget {
  const _PlanFeatureLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutSegmentedTab extends StatelessWidget {
  const _CheckoutSegmentedTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSkeleton = AppSkeleton.isActive(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isSkeleton
                    ? SkeletonDesign.base
                    : CheckoutDesign.optionSelectedBackground)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.xs),
          border: Border.all(
            color: selected ? AppColors.border : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? AppFont.bold : AppFont.medium,
            color: selected ? AppColors.text : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CheckoutAccountRow extends StatelessWidget {
  const _CheckoutAccountRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
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
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: AppFont.extraBold,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                'نسخ'.tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutReceiptAction extends StatelessWidget {
  const _CheckoutReceiptAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : AppHaptics.action(onTap!),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: AppFont.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
