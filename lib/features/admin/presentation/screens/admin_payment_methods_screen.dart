import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/payment_method.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

enum _MethodTypeFilter { all, bank, wallet }

const List<PaymentMethod> _kAdminPaymentMethodPlaceholders = [
  PaymentMethod(
    id: 'sk_1',
    name: 'بنك فلسطين',
    type: 'bank',
    accountNumber: '0458-000000-001',
    iban: 'PS00PALS0458000000000001',
    accountHolder: 'منصة وصلة للتجارة',
    isActive: true,
  ),
  PaymentMethod(
    id: 'sk_2',
    name: 'محفظة بال باي (PalPay)',
    type: 'wallet',
    accountNumber: '0599000001',
    accountHolder: 'منصة وصلة',
    isActive: true,
  ),
  PaymentMethod(
    id: 'sk_3',
    name: 'محفظة جوال باي (Jawwal Pay)',
    type: 'wallet',
    accountNumber: '0599000002',
    accountHolder: 'منصة وصلة',
    isActive: true,
  ),
];

class AdminPaymentMethodsScreen extends ConsumerStatefulWidget {
  const AdminPaymentMethodsScreen({super.key});

  @override
  ConsumerState<AdminPaymentMethodsScreen> createState() =>
      _AdminPaymentMethodsScreenState();
}

class _AdminPaymentMethodsScreenState
    extends ConsumerState<AdminPaymentMethodsScreen> {
  _MethodTypeFilter _typeFilter = _MethodTypeFilter.all;

  Future<void> _openMethodSheet({PaymentMethod? method}) async {
    final nameCtrl = TextEditingController(text: method?.name ?? '');
    final nameEnCtrl = TextEditingController(text: method?.nameEn ?? '');
    final accountCtrl = TextEditingController(
      text: method?.accountNumber ?? '',
    );
    final ibanCtrl = TextEditingController(text: method?.iban ?? '');
    final holderCtrl = TextEditingController(
      text: method?.accountHolder ?? 'منصة وصلة للتجارة',
    );
    final instructionsCtrl = TextEditingController(
      text: method?.instructions ?? '',
    );
    final sortCtrl = TextEditingController(
      text: (method?.sortOrder ?? 1).toString(),
    );

    var type = method?.type ?? 'bank';
    var isActive = method?.isActive ?? true;
    var saving = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> save() async {
            FocusScope.of(sheetCtx).unfocus();
            if (formKey.currentState?.validate() != true) return;
            setSheetState(() => saving = true);

            final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.upsertPaymentMethod(
              id: method?.id,
              name: nameCtrl.text,
              nameEn: nameEnCtrl.text,
              type: type,
              accountNumber: accountCtrl.text,
              iban: ibanCtrl.text,
              accountHolder: holderCtrl.text,
              instructions: instructionsCtrl.text,
              isActive: isActive,
              sortOrder: sort,
            );
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(adminActionProvider).error;
              showAppSnackBar(
                context,
                err == null
                    ? 'تعذر حفظ وسيلة الدفع'.tr
                    : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حفظ وسيلة الدفع بنجاح'.tr);
          }

          Future<void> remove() async {
            if (method == null) return;
            setSheetState(() => saving = true);
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.deletePaymentMethod(method.id);
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(adminActionProvider).error;
              showAppSnackBar(
                context,
                err == null
                    ? 'تعذر حذف وسيلة الدفع'.tr
                    : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حذف وسيلة الدفع'.tr);
          }

          return AppBottomSheetScaffold(
            title: method == null
                ? 'إضافة بنك أو محفظة إلكترونية'.tr
                : 'تعديل وسيلة الدفع'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'نوع وسيلة الدفع'.tr,
                    style: Theme.of(sheetCtx).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('حساب بنكي'.tr)),
                          selected: type == 'bank',
                          onSelected: saving
                              ? null
                              : (_) => setSheetState(() => type = 'bank'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(child: Text('محفظة إلكترونية'.tr)),
                          selected: type == 'wallet',
                          onSelected: saving
                              ? null
                              : (_) => setSheetState(() => type = 'wallet'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: nameCtrl,
                    label: type == 'wallet'
                        ? 'اسم المحفظة (مثال: محفظة بال باي / جوال باي) *'.tr
                        : 'اسم البنك (مثال: بنك فلسطين) *'.tr,
                    prefixIcon: type == 'wallet'
                        ? IconsaxPlusLinear.wallet_2
                        : IconsaxPlusLinear.bank,
                    enabled: !saving,
                    validator: (v) => Validators.required(
                      v,
                      field: 'اسم البنك أو المحفظة'.tr,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: nameEnCtrl,
                    label: 'الاسم بالإنجليزية (اختياري)'.tr,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: accountCtrl,
                    label: type == 'wallet'
                        ? 'رقم المحفظة للتحويل *'.tr
                        : 'رقم الحساب البنكي *'.tr,
                    prefixIcon: AppIcons.payment,
                    enabled: !saving,
                    validator: (v) =>
                        Validators.required(v, field: 'رقم الحساب / المحفظة'.tr),
                  ),
                  if (type == 'bank') ...[
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: ibanCtrl,
                      label: 'رقم IBAN (اختياري)'.tr,
                      enabled: !saving,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: holderCtrl,
                    label: 'اسم المستفيد / صاحب الحساب'.tr,
                    prefixIcon: AppIcons.user,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: instructionsCtrl,
                    label: 'تعليمات التحويل للزبون (اختياري)'.tr,
                    maxLines: 2,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: sortCtrl,
                    label: 'ترتيب الظهور (الأصغر يظهر أولاً)'.tr,
                    keyboardType: TextInputType.number,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'تفعيل وسيلة الدفع للعملاء'.tr,
                      style: const TextStyle(fontWeight: AppFont.bold),
                    ),
                    subtitle: Text(
                      isActive
                          ? 'ظاهرة ومتاحة للتحويل في شاشة إتمام الشراء'.tr
                          : 'مخفية وموقفة مؤقتاً عن العملاء'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: isActive,
                    onChanged: saving
                        ? null
                        : (v) => setSheetState(() => isActive = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'حفظ التغييرات'.tr,
                    isLoading: saving,
                    onPressed: save,
                  ),
                  if (method != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.errorSoft,
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.25),
                        ),
                        minimumSize: const Size(
                          double.infinity,
                          ButtonDesign.height,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ButtonDesign.radius,
                          ),
                        ),
                      ),
                      onPressed: saving ? null : AppHaptics.action(remove),
                      child: Text('حذف وسيلة الدفع'.tr),
                    ),
                  ],
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
      nameCtrl.dispose();
      nameEnCtrl.dispose();
      accountCtrl.dispose();
      ibanCtrl.dispose();
      holderCtrl.dispose();
      instructionsCtrl.dispose();
      sortCtrl.dispose();
    });
  }

  Future<void> _toggleMethod(PaymentMethod method, bool nextActive) async {
    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.togglePaymentMethod(
      id: method.id,
      isActive: nextActive,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تحديث الحالة'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      nextActive
          ? '${'تم تفعيل'.tr} ${method.displayName}'
          : '${'تم إيقاف'.tr} ${method.displayName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(adminPaymentMethodsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'طرق الدفع والحوالات (غزة)'.tr,
      actions: [
        IconButton(
          tooltip: 'إضافة بنك أو محفظة'.tr,
          onPressed: busy ? null : () => _openMethodSheet(),
          icon: Icon(AppIcons.add, color: AppBarDesign.iconColor),
        ),
      ],
      body: methodsAsync.skeletonWhen(
        placeholder: _kAdminPaymentMethodPlaceholders,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل طرق الدفع',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminPaymentMethodsProvider),
            ),
          ],
        ),
        data: (items) {
          final activeCount = items.where((m) => m.isActive).length;
          final pausedCount = items.length - activeCount;

          final filtered = items.where((m) {
            return switch (_typeFilter) {
              _MethodTypeFilter.all => true,
              _MethodTypeFilter.bank => m.isBank,
              _MethodTypeFilter.wallet => m.isWallet,
            };
          }).toList();

          return AppRefreshIndicator(
            onRefresh: () => ref.refresh(adminPaymentMethodsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                // Summary Row
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'الكل',
                        value: '${items.length}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'مفعّلة للعملاء',
                        value: '$activeCount',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'موقفة',
                        value: '$pausedCount',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Quick Add CTA + Filter Chips
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          ChoiceChip(
                            label: Text('الكل'.tr),
                            selected: _typeFilter == _MethodTypeFilter.all,
                            onSelected: (_) => setState(
                              () => _typeFilter = _MethodTypeFilter.all,
                            ),
                          ),
                          ChoiceChip(
                            label: Text('البنوك'.tr),
                            selected: _typeFilter == _MethodTypeFilter.bank,
                            onSelected: (_) => setState(
                              () => _typeFilter = _MethodTypeFilter.bank,
                            ),
                          ),
                          ChoiceChip(
                            label: Text('المحافظ'.tr),
                            selected: _typeFilter == _MethodTypeFilter.wallet,
                            onSelected: (_) => setState(
                              () => _typeFilter = _MethodTypeFilter.wallet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'إضافة بنك أو محفظة جديدة'.tr,
                  onPressed: busy ? null : () => _openMethodSheet(),
                ),
                const SizedBox(height: AppSpacing.md),

                if (filtered.isEmpty)
                  AppEmpty(
                    icon: AppIcons.payment,
                    title: 'لا توجد وسائل دفع بعد'.tr,
                    message:
                        'أضف أرقام حسابات بنك فلسطين والمحافظ الإلكترونية في غزة لتظهر للعملاء عند الدفع.'
                            .tr,
                  )
                else
                  ...filtered.map((method) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: busy
                            ? null
                            : () => _openMethodSheet(method: method),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: method.isActive
                                        ? AppColors.primarySoft
                                        : AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.sm,
                                    ),
                                  ),
                                  child: Icon(
                                    method.isWallet
                                        ? IconsaxPlusLinear.wallet_2
                                        : IconsaxPlusLinear.bank,
                                    color: method.isActive
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        method.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: AppFont.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          AppStatusBadge(
                                            label: method.typeLabel,
                                            tone: BadgeTone.neutral,
                                          ),
                                          const SizedBox(width: 6),
                                          AppStatusBadge(
                                            label: method.isActive
                                                ? 'مفعّلة'
                                                : 'موقفة',
                                            tone: method.isActive
                                                ? BadgeTone.success
                                                : BadgeTone.warning,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: method.isActive,
                                  onChanged: busy
                                      ? null
                                      : (val) => _toggleMethod(method, val),
                                ),
                              ],
                            ),
                            const Divider(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        method.accountHolder.isNotEmpty
                                            ? method.accountHolder
                                            : 'رقم الحساب / المحفظة'.tr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          method.accountNumber,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: AppFont.extraBold,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (method.iban != null &&
                                          method.iban!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            'IBAN: ${method.iban}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'نسخ الرقم'.tr,
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: method.accountNumber),
                                    );
                                    AppHaptics.selection();
                                    if (context.mounted) {
                                      showAppSnackBar(
                                        context,
                                        'تم نسخ الرقم بنجاح'.tr,
                                      );
                                    }
                                  },
                                  icon: Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Icon(
                                  AppIcons.edit,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
