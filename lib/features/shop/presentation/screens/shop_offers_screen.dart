import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_pagination_footer.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

enum _OfferFilter { all, withOffer, withoutOffer }

enum _OfferStartMode { now, scheduled }

enum _OfferDurationPreset {
  oneDay,
  threeDays,
  oneWeek,
  twoWeeks,
  oneMonth,
  custom,
}

const List<String> _offerTitlePresets = [
  'عرض محدود',
  'تخفيضات الموسم',
  'عرض نهاية الأسبوع',
  'عرض فلاش',
];

class ShopOffersScreen extends ConsumerStatefulWidget {
  const ShopOffersScreen({super.key});

  @override
  ConsumerState<ShopOffersScreen> createState() => _ShopOffersScreenState();
}

class _ShopOffersScreenState extends ConsumerState<ShopOffersScreen> {
  _OfferFilter _offerFilter = _OfferFilter.all;
  String _search = '';

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $hh:$mm';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays >= 1) {
      return duration.inDays == 1
          ? 'يوم واحد'.tr
          : '${duration.inDays} ${'أيام'.tr}';
    }
    final hours = duration.inHours.clamp(1, 23);
    return hours == 1 ? 'ساعة واحدة'.tr : '$hours ${'ساعات'.tr}';
  }

  DateTime _computeEndForPreset(DateTime start, _OfferDurationPreset preset) {
    return switch (preset) {
      _OfferDurationPreset.oneDay => start.add(const Duration(days: 1)),
      _OfferDurationPreset.threeDays => start.add(const Duration(days: 3)),
      _OfferDurationPreset.oneWeek => start.add(const Duration(days: 7)),
      _OfferDurationPreset.twoWeeks => start.add(const Duration(days: 14)),
      _OfferDurationPreset.oneMonth => start.add(const Duration(days: 30)),
      _OfferDurationPreset.custom => start.add(const Duration(days: 7)),
    };
  }

  String _presetLabel(_OfferDurationPreset preset) {
    return switch (preset) {
      _OfferDurationPreset.oneDay => '24 ساعة'.tr,
      _OfferDurationPreset.threeDays => '3 أيام'.tr,
      _OfferDurationPreset.oneWeek => 'أسبوع'.tr,
      _OfferDurationPreset.twoWeeks => 'أسبوعين'.tr,
      _OfferDurationPreset.oneMonth => 'شهر'.tr,
      _OfferDurationPreset.custom => 'تاريخ مخصص'.tr,
    };
  }

  Future<DateTime?> _pickDateTime({
    required BuildContext sheetContext,
    required DateTime initial,
    required DateTime firstDate,
  }) async {
    final safeInitial = initial.isBefore(firstDate) ? firstDate : initial;
    final pickedDate = await showDatePicker(
      context: sheetContext,
      initialDate: safeInitial,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !sheetContext.mounted) return null;

    final pickedTime = await showTimePicker(
      context: sheetContext,
      initialTime: TimeOfDay.fromDateTime(safeInitial),
    );
    if (pickedTime == null) {
      return DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        23,
        59,
      );
    }
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _openOfferSheet(ShopProduct product) async {
    final basePrice = product.basePrice;
    final hasExisting = product.hasAnyOfferConfig;
    final discountCtrl = TextEditingController(
      text: hasExisting
          ? product.discountAmount.toStringAsFixed(
              product.discountAmount.truncateToDouble() ==
                      product.discountAmount
                  ? 0
                  : 2,
            )
          : '',
    );
    final titleCtrl = TextEditingController(text: product.offerTitle ?? '');

    var startMode = product.isOfferScheduled && product.offerStartsAt != null
        ? _OfferStartMode.scheduled
        : _OfferStartMode.now;
    var customStart =
        product.isOfferScheduled && product.offerStartsAt != null
        ? product.offerStartsAt!
        : DateTime.now().add(const Duration(hours: 1));
    var durationPreset = hasExisting && product.offerEndsAt != null
        ? _OfferDurationPreset.custom
        : _OfferDurationPreset.oneWeek;
    var customEnd =
        hasExisting && product.offerEndsAt != null
        ? product.offerEndsAt!
        : DateTime.now().add(const Duration(days: 7));

    var confirming = false;
    var saving = false;
    String? errorText;

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final parsed = double.tryParse(
            discountCtrl.text.trim().replaceAll('٫', '.'),
          );
          final validDiscount =
              parsed != null &&
              parsed.isFinite &&
              parsed > 0 &&
              parsed < basePrice;
          final newPrice = validDiscount
              ? (basePrice - parsed).clamp(0.01, basePrice)
              : basePrice;
          final percent = validDiscount && basePrice > 0
              ? ((parsed / basePrice) * 100).round().clamp(1, 99)
              : 0;

          final now = DateTime.now();
          final effectiveStart = startMode == _OfferStartMode.now
              ? now
              : customStart;
          final effectiveEnd = durationPreset == _OfferDurationPreset.custom
              ? customEnd
              : _computeEndForPreset(effectiveStart, durationPreset);
          final effectiveDuration = effectiveEnd.difference(effectiveStart);
          final cleanTitle = titleCtrl.text.trim();

          Future<void> applyOffer({
            required double amount,
            DateTime? startsAt,
            DateTime? endsAt,
            String? offerTitle,
          }) async {
            setSheetState(() {
              saving = true;
              errorText = null;
            });
            final actions = ref.read(shopCatalogActionProvider.notifier);
            final ok = await actions.setProductOffer(
              productId: product.id,
              discountAmount: amount,
              startsAt: startsAt,
              endsAt: endsAt,
              offerTitle: offerTitle,
            );
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) {
                setSheetState(() => saving = false);
              }
              final err = ref.read(shopCatalogActionProvider).error;
              showAppSnackBar(
                context,
                err == null ? 'تعذر حفظ العرض'.tr : actions.errorMessage(err),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(
              context,
              amount > 0
                  ? (startMode == _OfferStartMode.scheduled
                        ? 'تمت جدولة العرض بنجاح'.tr
                        : 'تم تفعيل العرض بنجاح'.tr)
                  : 'تمت إزالة العرض'.tr,
            );
          }

          return AppBottomSheetScaffold(
            title: confirming ? 'تأكيد بيانات العرض'.tr : 'إعداد عرض المنتج'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product summary header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        child: Container(
                          width: 58,
                          height: 58,
                          color: AppColors.surface,
                          child:
                              product.coverImage != null &&
                                  product.coverImage!.isNotEmpty
                              ? AppNetworkImage(
                                  product.coverImage!,
                                  fit: BoxFit.cover,
                                  width: 58,
                                  height: 58,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: AppFont.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${'السعر الأساسي'.tr}: ${AppFormat.price(basePrice)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            if (product.hasOffer &&
                                product.offerRemainingLabel != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                product.offerRemainingLabel!.tr,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: AppFont.semiBold,
                                    ),
                              ),
                            ] else if (product.isOfferScheduled &&
                                product.offerStartsAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${'يبدأ في'.tr}: ${_formatDateTime(product.offerStartsAt!)}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: AppFont.semiBold,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (product.hasOffer)
                        AppStatusBadge(
                          label: '-${product.discountPercent}%',
                          tone: BadgeTone.error,
                        )
                      else if (product.isOfferScheduled)
                        AppStatusBadge(
                          label: 'مجدول'.tr,
                          tone: BadgeTone.warning,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (!confirming) ...[
                  // 1) Discount Amount
                  AppTextField(
                    controller: discountCtrl,
                    label: 'قيمة الخصم (₪)'.tr,
                    hint: 'أدخل مبلغ الخصم بالشيكل'.tr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setSheetState(() => errorText = null),
                  ),
                  if (validDiscount) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _OfferSummaryRow(
                            label: 'نسبة العرض المحسوبة'.tr,
                            value: '-$percent%',
                            highlight: true,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _OfferSummaryRow(
                            label: 'السعر قبل العرض'.tr,
                            value: AppFormat.price(basePrice),
                            strikethrough: true,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _OfferSummaryRow(
                            label: 'السعر بعد العرض'.tr,
                            value: AppFormat.price(newPrice),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // 2) Start Time Mode
                  Text(
                    'وقت بداية العرض'.tr,
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
                        label: Text('يبدأ فوراً'.tr),
                        selected: startMode == _OfferStartMode.now,
                        onSelected: (_) => setSheetState(() {
                          startMode = _OfferStartMode.now;
                          errorText = null;
                        }),
                      ),
                      ChoiceChip(
                        label: Text('تحديد وقت لاحق'.tr),
                        selected: startMode == _OfferStartMode.scheduled,
                        onSelected: (_) async {
                          final picked = await _pickDateTime(
                            sheetContext: sheetCtx,
                            initial: customStart.isAfter(DateTime.now())
                                ? customStart
                                : DateTime.now().add(const Duration(hours: 1)),
                            firstDate: DateTime.now(),
                          );
                          if (!sheetCtx.mounted) return;
                          setSheetState(() {
                            startMode = _OfferStartMode.scheduled;
                            if (picked != null) {
                              customStart = picked;
                              if (durationPreset ==
                                      _OfferDurationPreset.custom &&
                                  !customEnd.isAfter(customStart)) {
                                customEnd = customStart.add(
                                  const Duration(days: 7),
                                );
                              }
                            }
                            errorText = null;
                          });
                        },
                      ),
                    ],
                  ),
                  if (startMode == _OfferStartMode.scheduled) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _OfferDateField(
                      label: 'تاريخ ووقت البداية'.tr,
                      value: _formatDateTime(customStart),
                      onTap: () async {
                        final picked = await _pickDateTime(
                          sheetContext: sheetCtx,
                          initial: customStart,
                          firstDate: DateTime.now(),
                        );
                        if (picked == null || !sheetCtx.mounted) return;
                        setSheetState(() {
                          customStart = picked;
                          if (durationPreset == _OfferDurationPreset.custom &&
                              !customEnd.isAfter(customStart)) {
                            customEnd = customStart.add(
                              const Duration(days: 7),
                            );
                          }
                          errorText = null;
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // 3) Offer Duration / Expiry
                  Text(
                    'مدة العرض'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _OfferDurationPreset.values.map((preset) {
                      final selected = durationPreset == preset;
                      return ChoiceChip(
                        label: Text(_presetLabel(preset)),
                        selected: selected,
                        onSelected: (_) async {
                          if (preset == _OfferDurationPreset.custom) {
                            final minEnd = effectiveStart.add(
                              const Duration(hours: 1),
                            );
                            final picked = await _pickDateTime(
                              sheetContext: sheetCtx,
                              initial: customEnd.isAfter(minEnd)
                                  ? customEnd
                                  : effectiveStart.add(
                                      const Duration(days: 7),
                                    ),
                              firstDate: effectiveStart,
                            );
                            if (!sheetCtx.mounted) return;
                            if (picked != null) {
                              setSheetState(() {
                                durationPreset = _OfferDurationPreset.custom;
                                customEnd = picked;
                                errorText = null;
                              });
                            }
                            return;
                          }
                          setSheetState(() {
                            durationPreset = preset;
                            errorText = null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (durationPreset == _OfferDurationPreset.custom) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _OfferDateField(
                      label: 'تاريخ ووقت الانتهاء'.tr,
                      value: _formatDateTime(customEnd),
                      onTap: () async {
                        final picked = await _pickDateTime(
                          sheetContext: sheetCtx,
                          initial: customEnd,
                          firstDate: effectiveStart,
                        );
                        if (picked == null || !sheetCtx.mounted) return;
                        setSheetState(() {
                          customEnd = picked;
                          errorText = null;
                        });
                      },
                    ),
                  ],

                  // Schedule preview box
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OfferSummaryRow(
                          label: 'بداية العرض'.tr,
                          value: startMode == _OfferStartMode.now
                              ? 'فوراً'.tr
                              : _formatDateTime(effectiveStart),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _OfferSummaryRow(
                          label: 'نهاية العرض'.tr,
                          value: _formatDateTime(effectiveEnd),
                          bold: true,
                        ),
                        if (effectiveDuration.inMinutes > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          _OfferSummaryRow(
                            label: 'المدة الإجمالية'.tr,
                            value: _formatDuration(effectiveDuration),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'ينتهي العرض تلقائياً ويعود السعر الأصلي عند انتهاء المدة.'
                              .tr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 4) Optional Offer Label / Title
                  Text(
                    'عنوان العرض (اختياري)'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _offerTitlePresets.map((preset) {
                      final translated = preset.tr;
                      final selected =
                          cleanTitle == preset || cleanTitle == translated;
                      return ChoiceChip(
                        label: Text(translated),
                        selected: selected,
                        onSelected: (isSelected) {
                          setSheetState(() {
                            titleCtrl.text = isSelected ? translated : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppTextField(
                    controller: titleCtrl,
                    label: 'وسم أو عنوان مخصص للعرض'.tr,
                    hint: 'مثال: عرض نهاية الأسبوع أو خصم الموسم'.tr,
                    onChanged: (_) => setSheetState(() {}),
                  ),

                  if (errorText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      errorText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: AppFont.semiBold,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'متابعة لتأكيد العرض'.tr,
                    onPressed: saving
                        ? null
                        : () {
                            if (!validDiscount) {
                              setSheetState(
                                () => errorText =
                                    'أدخل قيمة خصم صحيحة أقل من سعر المنتج'.tr,
                              );
                              return;
                            }
                            final checkNow = DateTime.now();
                            final checkStart =
                                startMode == _OfferStartMode.now
                                ? checkNow
                                : customStart;
                            final checkEnd =
                                durationPreset == _OfferDurationPreset.custom
                                ? customEnd
                                : _computeEndForPreset(
                                    checkStart,
                                    durationPreset,
                                  );
                            if (startMode == _OfferStartMode.scheduled &&
                                !checkStart.isAfter(checkNow)) {
                              setSheetState(
                                () => errorText =
                                    'وقت بداية العرض المجدول يجب أن يكون في المستقبل'
                                        .tr,
                              );
                              return;
                            }
                            if (!checkEnd.isAfter(checkStart) ||
                                !checkEnd.isAfter(checkNow)) {
                              setSheetState(
                                () => errorText =
                                    'تاريخ نهاية العرض يجب أن يكون بعد وقت البداية وفي المستقبل'
                                        .tr,
                              );
                              return;
                            }
                            FocusScope.of(sheetCtx).unfocus();
                            setSheetState(() {
                              errorText = null;
                              confirming = true;
                            });
                          },
                  ),
                  if (hasExisting) ...[
                    const SizedBox(height: AppSpacing.sm),
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
                      onPressed: saving
                          ? null
                          : AppHaptics.action(() => applyOffer(amount: 0)),
                      child: Text('إزالة العرض'.tr),
                    ),
                  ],
                ] else ...[
                  // Step 2: Professional Offer Confirmation Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          alignment: WrapAlignment.center,
                          children: [
                            AppStatusBadge(
                              label: '-$percent%',
                              tone: BadgeTone.error,
                            ),
                            if (cleanTitle.isNotEmpty)
                              AppStatusBadge(
                                label: cleanTitle,
                                tone: BadgeTone.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'هل توافق على تفعيل خصم $percent% على هذا المنتج؟'.tr,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: AppFont.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppFormat.price(newPrice),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: AppFont.extraBold,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              AppFormat.price(basePrice),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: AppColors.textMuted,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.sm),
                        _OfferSummaryRow(
                          label: 'قيمة الخصم'.tr,
                          value: AppFormat.price(parsed ?? 0),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _OfferSummaryRow(
                          label: 'بداية العرض'.tr,
                          value: startMode == _OfferStartMode.now
                              ? 'فوراً'.tr
                              : _formatDateTime(effectiveStart),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _OfferSummaryRow(
                          label: 'نهاية العرض'.tr,
                          value: _formatDateTime(effectiveEnd),
                          bold: true,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _OfferSummaryRow(
                          label: 'المدة الإجمالية'.tr,
                          value: _formatDuration(effectiveDuration),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'سيعود المنتج لسعره الأصلي تلقائياً بعد انتهاء مدة العرض.'
                              .tr,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: startMode == _OfferStartMode.scheduled
                        ? 'تأكيد وجدولة العرض'.tr
                        : 'تأكيد وتفعيل العرض'.tr,
                    isLoading: saving,
                    onPressed: parsed == null
                        ? null
                        : () {
                            final finalStart = startMode == _OfferStartMode.now
                                ? DateTime.now()
                                : customStart;
                            final finalEnd =
                                durationPreset == _OfferDurationPreset.custom
                                ? customEnd
                                : _computeEndForPreset(
                                    finalStart,
                                    durationPreset,
                                  );
                            applyOffer(
                              amount: parsed,
                              startsAt: finalStart,
                              endsAt: finalEnd,
                              offerTitle: cleanTitle,
                            );
                          },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'تعديل بيانات العرض'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: saving
                        ? null
                        : () => setSheetState(() => confirming = false),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    discountCtrl.dispose();
    titleCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(myShopProvider);
    final shop = shopState.asData?.value;
    final awaitingShop = shopState.isLoading && !shopState.hasValue;
    final productsState = awaitingShop
        ? const PaginatedListState<ShopProduct>(isInitialLoading: true)
        : ref.watch(shopProductsPaginatedProvider);
    final busy = ref.watch(shopCatalogActionProvider).isLoading;
    final approved = shop?.visibleStatus == ShopStatus.approved;

    return ShopScaffold(
      title: 'العروض'.tr,
      showBack: false,
      body: !approved && !awaitingShop
          ? ListView(
              padding: AppSpacing.page,
              children: [
                ShopNoticeBanner(
                  title: 'العروض غير مفعّلة بعد',
                  message:
                      'يمكنك إنشاء العروض على منتجاتك بعد موافقة الإدارة على متجرك.',
                  tone: BadgeTone.warning,
                  actionLabel: 'متابعة حالة الطلب',
                  onAction: () => context.push(AppRoutes.shopStatus),
                ),
              ],
            )
          : productsState.skeletonWhen(
              placeholder: LoadingFixtures.shopProducts,
              error: (error) => ListView(
                padding: AppSpacing.page,
                children: [
                  ShopNoticeBanner(
                    title: 'تعذر تحميل المنتجات',
                    message: ref
                        .read(shopCatalogRepositoryProvider)
                        .mapError(error),
                    tone: BadgeTone.error,
                    actionLabel: 'إعادة المحاولة',
                    onAction: ref
                        .read(shopProductsPaginatedProvider.notifier)
                        .refresh,
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty &&
                    !productsState.isInitialLoading &&
                    !productsState.hasMore) {
                  return ShopCenteredEmptyView(
                    onRefresh: ref
                        .read(shopProductsPaginatedProvider.notifier)
                        .refresh,
                    title: 'لا توجد منتجات لعمل عروض عليها بعد',
                    message:
                        'أضف منتجاتك أولاً ثم اضغط على أي منتج هنا لتحديد قيمة الخصم.',
                  );
                }

                final withOfferCount = items
                    .where((p) => p.hasAnyOfferConfig)
                    .length;
                final withoutOfferCount = items.length - withOfferCount;
                final q = _search.trim().toLowerCase();
                final filtered = items.where((item) {
                  if (_offerFilter == _OfferFilter.withOffer &&
                      !item.hasAnyOfferConfig) {
                    return false;
                  }
                  if (_offerFilter == _OfferFilter.withoutOffer &&
                      item.hasAnyOfferConfig) {
                    return false;
                  }
                  if (q.isNotEmpty && !item.name.toLowerCase().contains(q)) {
                    return false;
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    AppFilterToolbar(
                      searchValue: _search,
                      searchHint: 'ابحث باسم المنتج لإضافة عرض...',
                      onSearchChanged: (val) => setState(() => _search = val),
                      quickOptions: [
                        AppQuickFilterOption(
                          id: 'shop_offers_all',
                          label: 'الكل',
                          count: items.length,
                          selected: _offerFilter == _OfferFilter.all,
                          onTap: () =>
                              setState(() => _offerFilter = _OfferFilter.all),
                        ),
                        AppQuickFilterOption(
                          id: 'shop_offers_active',
                          label: 'عليها عرض',
                          count: withOfferCount,
                          selected: _offerFilter == _OfferFilter.withOffer,
                          onTap: () => setState(
                            () => _offerFilter = _OfferFilter.withOffer,
                          ),
                        ),
                        AppQuickFilterOption(
                          id: 'shop_offers_none',
                          label: 'بدون عرض',
                          count: withoutOfferCount,
                          selected: _offerFilter == _OfferFilter.withoutOffer,
                          onTap: () => setState(
                            () => _offerFilter = _OfferFilter.withoutOffer,
                          ),
                        ),
                      ],
                      totalCount: items.length,
                      filteredCount: filtered.length,
                      hasActiveCustomization:
                          _offerFilter != _OfferFilter.all ||
                          _search.trim().isNotEmpty,
                      onClearAll: () => setState(() {
                        _offerFilter = _OfferFilter.all;
                        _search = '';
                      }),
                      showCountWhenUnfiltered: true,
                    ),
                    Expanded(
                      child: filtered.isEmpty && !productsState.isInitialLoading
                          ? ShopCenteredEmptyView(
                              onRefresh: ref
                                  .read(shopProductsPaginatedProvider.notifier)
                                  .refresh,
                              title: _offerFilter == _OfferFilter.withOffer
                                  ? 'لا توجد عروض مفعّلة حالياً'
                                  : 'لا توجد نتائج مطابقة',
                              message:
                                  'اضغط على أي منتج من قائمة الكل لتحديد قيمة الخصم وتفعيل العرض.',
                            )
                          : AppRefreshIndicator(
                              onRefresh: ref
                                  .read(shopProductsPaginatedProvider.notifier)
                                  .refresh,
                              child: AppPaginationScrollListener(
                                hasMore: productsState.hasMore,
                                isLoadingMore: productsState.isLoadingMore,
                                onLoadMore: ref
                                    .read(
                                      shopProductsPaginatedProvider.notifier,
                                    )
                                    .loadMore,
                                child: CustomScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    SliverPadding(
                                      padding: AppSpacing.page,
                                      sliver: SliverGrid(
                                        gridDelegate: ProductGridDelegate(
                                          textScale:
                                              MediaQuery.textScalerOf(
                                                context,
                                              ).scale(14) /
                                              14,
                                        ),
                                        delegate: SliverChildBuilderDelegate((
                                          context,
                                          index,
                                        ) {
                                          final item = filtered[index];
                                          return ProductGridCard(
                                            imageUrl: item.coverImage,
                                            meta: AppFormat.price(
                                              item.effectivePrice,
                                            ),
                                            originalMeta: item.hasOffer
                                                ? AppFormat.price(
                                                    item.originalPrice!,
                                                  )
                                                : null,
                                            discountPercent: item.hasOffer
                                                ? item.discountPercent
                                                : null,
                                            inStock: item.totalStock > 0,
                                            showFavorite: false,
                                            onTap: busy
                                                ? null
                                                : () => _openOfferSheet(item),
                                          );
                                        }, childCount: filtered.length),
                                      ),
                                    ),
                                    if (!productsState.isInitialLoading)
                                      SliverToBoxAdapter(
                                        child: AppLoadMoreFooter(
                                          isLoadingMore:
                                              productsState.isLoadingMore,
                                          hasMore: productsState.hasMore,
                                          itemsCount: filtered.length,
                                          loadMoreError:
                                              productsState.loadMoreError,
                                          onLoadMore: ref
                                              .read(
                                                shopProductsPaginatedProvider
                                                    .notifier,
                                              )
                                              .loadMore,
                                          useProductGridSkeleton: true,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _OfferDateField extends StatelessWidget {
  const _OfferDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
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
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'تغيير'.tr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: AppFont.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferSummaryRow extends StatelessWidget {
  const _OfferSummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.strikethrough = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool strikethrough;
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
        if (highlight)
          AppStatusBadge(label: value, tone: BadgeTone.error)
        else
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? AppFont.extraBold : AppFont.semiBold,
              color: strikethrough ? AppColors.textMuted : AppColors.text,
              decoration: strikethrough ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.textMuted,
            ),
          ),
      ],
    );
  }
}
