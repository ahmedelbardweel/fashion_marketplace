import 'package:flutter/material.dart';
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
import '../../domain/models/subscription_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

const List<SubscriptionPlan> _kPlanPlaceholders = [
  SubscriptionPlan(
    id: 'sk_1',
    name: 'الباقة الشهرية',
    description: 'اشتراك شهري بدون عمولة على المبيعات (0%)',
    price: 30,
    durationDays: 30,
    isActive: true,
    sortOrder: 1,
  ),
  SubscriptionPlan(
    id: 'sk_2',
    name: 'باقة 3 شهور',
    description: 'اشتراك ربع سنوي موفر للمتاجر النشطة',
    price: 80,
    durationDays: 90,
    isActive: true,
    sortOrder: 2,
  ),
  SubscriptionPlan(
    id: 'sk_3',
    name: 'الباقة السنوية',
    description: 'سنة كاملة بدون أي عمولة على الطلبات',
    price: 300,
    durationDays: 365,
    isActive: true,
    sortOrder: 3,
  ),
];

class AdminSubscriptionPlansScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionPlansScreen({super.key});

  @override
  ConsumerState<AdminSubscriptionPlansScreen> createState() =>
      _AdminSubscriptionPlansScreenState();
}

class _AdminSubscriptionPlansScreenState
    extends ConsumerState<AdminSubscriptionPlansScreen> {
  Future<void> _openPlanSheet({SubscriptionPlan? plan}) async {
    final nameCtrl = TextEditingController(text: plan?.name ?? '');
    final nameEnCtrl = TextEditingController(text: plan?.nameEn ?? '');
    final descCtrl = TextEditingController(text: plan?.description ?? '');
    final priceCtrl = TextEditingController(
      text: plan != null ? plan.price.toStringAsFixed(2) : '30',
    );
    final durationCtrl = TextEditingController(
      text: (plan?.durationDays ?? 30).toString(),
    );
    final sortCtrl = TextEditingController(
      text: (plan?.sortOrder ?? 1).toString(),
    );

    var isActive = plan?.isActive ?? true;
    var saving = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.92,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> save() async {
            FocusScope.of(sheetCtx).unfocus();
            if (formKey.currentState?.validate() != true) return;
            final price = double.tryParse(
              priceCtrl.text.trim().replaceAll('٫', '.'),
            );
            final days = int.tryParse(durationCtrl.text.trim());
            final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
            if (price == null || price < 0) {
              showAppSnackBar(
                sheetCtx,
                'يرجى إدخال سعر اشتراك صحيح'.tr,
                isError: true,
              );
              return;
            }
            if (days == null || days < 1) {
              showAppSnackBar(
                sheetCtx,
                'يرجى إدخال مدة صحيحة بالأيام (يوم واحد على الأقل)'.tr,
                isError: true,
              );
              return;
            }

            setSheetState(() => saving = true);
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.upsertSubscriptionPlan(
              id: plan?.id,
              name: nameCtrl.text,
              nameEn: nameEnCtrl.text,
              description: descCtrl.text,
              price: price,
              durationDays: days,
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
                    ? 'تعذر حفظ باقة الاشتراك'.tr
                    : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حفظ باقة الاشتراك بنجاح'.tr);
          }

          Future<void> remove() async {
            if (plan == null) return;
            setSheetState(() => saving = true);
            final actions = ref.read(adminActionProvider.notifier);
            final ok = await actions.deleteSubscriptionPlan(plan.id);
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => saving = false);
              final err = ref.read(adminActionProvider).error;
              showAppSnackBar(
                context,
                err == null
                    ? 'تعذر حذف باقة الاشتراك'.tr
                    : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم حذف باقة الاشتراك'.tr);
          }

          return AppBottomSheetScaffold(
            title: plan == null
                ? 'إضافة باقة اشتراك جديدة'.tr
                : 'تعديل باقة الاشتراك'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: nameCtrl,
                    label: 'اسم الباقة (مثال: الباقة الشهرية) *'.tr,
                    enabled: !saving,
                    validator: (v) =>
                        Validators.required(v, field: 'اسم الباقة'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: nameEnCtrl,
                    label: 'الاسم بالإنجليزية (اختياري)'.tr,
                    enabled: !saving,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: priceCtrl,
                          label: 'قيمة الاشتراك (₪) *'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: !saving,
                          validator: (v) {
                            final n = double.tryParse(
                              (v ?? '').trim().replaceAll('٫', '.'),
                            );
                            if (n == null || n < 0) {
                              return 'أدخل سعراً صحيحاً'.tr;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: durationCtrl,
                          label: 'المدة بالأيام *'.tr,
                          keyboardType: TextInputType.number,
                          enabled: !saving,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n < 1) {
                              return 'يوم على الأقل'.tr;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      ActionChip(
                        label: Text('30 يوم'.tr),
                        onPressed: saving
                            ? null
                            : () => setSheetState(
                                () => durationCtrl.text = '30',
                              ),
                      ),
                      ActionChip(
                        label: Text('90 يوم'.tr),
                        onPressed: saving
                            ? null
                            : () => setSheetState(
                                () => durationCtrl.text = '90',
                              ),
                      ),
                      ActionChip(
                        label: Text('180 يوم'.tr),
                        onPressed: saving
                            ? null
                            : () => setSheetState(
                                () => durationCtrl.text = '180',
                              ),
                      ),
                      ActionChip(
                        label: Text('365 يوم'.tr),
                        onPressed: saving
                            ? null
                            : () => setSheetState(
                                () => durationCtrl.text = '365',
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: descCtrl,
                    label: 'وصف ومزايا الباقة (اختياري)'.tr,
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
                      'تفعيل الباقة للمحلات'.tr,
                      style: const TextStyle(fontWeight: AppFont.bold),
                    ),
                    subtitle: Text(
                      isActive
                          ? 'ظاهرة ومتاحة للمحلات عند التسجيل والتجديد'.tr
                          : 'مخفية وموقفة مؤقتاً عن المحلات'.tr,
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
                    label: 'حفظ الباقة'.tr,
                    isLoading: saving,
                    onPressed: save,
                  ),
                  if (plan != null) ...[
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
                      child: Text('حذف الباقة'.tr),
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
      descCtrl.dispose();
      priceCtrl.dispose();
      durationCtrl.dispose();
      sortCtrl.dispose();
    });
  }

  Future<void> _togglePlan(SubscriptionPlan plan, bool nextActive) async {
    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.toggleSubscriptionPlan(
      id: plan.id,
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
          ? '${'تم تفعيل'.tr} ${plan.displayName}'
          : '${'تم إيقاف'.tr} ${plan.displayName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(adminSubscriptionPlansProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'باقات اشتراك المحلات'.tr,
      actions: [
        IconButton(
          tooltip: 'إضافة باقة اشتراك'.tr,
          onPressed: busy ? null : () => _openPlanSheet(),
          icon: Icon(AppIcons.add, color: AppBarDesign.iconColor),
        ),
      ],
      body: plansAsync.skeletonWhen(
        placeholder: _kPlanPlaceholders,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل باقات الاشتراك',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminSubscriptionPlansProvider),
            ),
          ],
        ),
        data: (plans) {
          final activeCount = plans.where((p) => p.isActive).length;
          final pausedCount = plans.length - activeCount;

          return AppRefreshIndicator(
            onRefresh: () => ref.refresh(adminSubscriptionPlansProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'كل الباقات',
                        value: '${plans.length}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'مفعّلة',
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
                AppButton(
                  label: 'إضافة باقة اشتراك جديدة'.tr,
                  onPressed: busy ? null : () => _openPlanSheet(),
                ),
                const SizedBox(height: AppSpacing.md),
                if (plans.isEmpty)
                  AppEmpty(
                    icon: AppIcons.wallet,
                    title: 'لا توجد باقات اشتراك بعد'.tr,
                    message:
                        'أضف باقات الاشتراك (مثل 30 ₪ شهرياً) لتظهر للمحلات عند التسجيل والتجديد.'
                            .tr,
                  )
                else
                  for (final plan in plans) ...[
                    AppCard(
                      onTap: busy ? null : () => _openPlanSheet(plan: plan),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Icon(
                                  AppIcons.wallet,
                                  size: 20,
                                  color: plan.isActive
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: AppFont.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        AppStatusBadge(
                                          label: plan.durationLabel,
                                          tone: BadgeTone.neutral,
                                        ),
                                        const SizedBox(width: 6),
                                        AppStatusBadge(
                                          label: plan.isActive
                                              ? 'مفعّلة'
                                              : 'موقفة',
                                          tone: plan.isActive
                                              ? BadgeTone.success
                                              : BadgeTone.warning,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: plan.isActive,
                                onChanged: busy
                                    ? null
                                    : (val) => _togglePlan(plan, val),
                              ),
                            ],
                          ),
                          const Divider(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  plan.description?.trim().isNotEmpty == true
                                      ? plan.description!.trim()
                                      : 'اشتراك ثابت بدون أي عمولة على المبيعات (0%)'
                                            .tr,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                AppFormat.price(plan.price),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: AppFont.extraBold,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}
