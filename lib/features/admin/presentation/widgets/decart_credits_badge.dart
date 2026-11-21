import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../domain/models/decart_settings_status.dart';
import '../providers/admin_providers.dart';
import 'decart_settings_card.dart';
import 'tryon_cost_controls_card.dart';

/// Compact live Decart remaining tokens pill for the top Admin AppBar.
/// Displays the combined remaining tokens across ALL active Decart API keys.
class DecartCreditsAppBarChip extends ConsumerWidget {
  const DecartCreditsAppBarChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(adminDecartCreditsProvider);

    return creditsAsync.when(
      loading: () => _ChipContainer(
        bg: AppColors.surfaceAlt,
        border: AppColors.border,
        fg: AppColors.textMuted,
        label: '...',
        onTap: () => showDecartCreditsSheet(context),
      ),
      error: (_, _) => _ChipContainer(
        bg: AppColors.surfaceAlt,
        border: AppColors.border,
        fg: AppColors.textMuted,
        label: 'Decart',
        onTap: () => showDecartCreditsSheet(context),
      ),
      data: (balance) {
        final Color bg;
        final Color border;
        final Color fg;
        final String label;

        if (balance.needsFunctionDeploy) {
          bg = AppColors.warningSoft;
          border = AppColors.warning.withValues(alpha: 0.3);
          fg = AppColors.warning;
          label = 'Decart !';
        } else if (!balance.configured) {
          bg = AppColors.surfaceAlt;
          border = AppColors.border;
          fg = AppColors.textMuted;
          label = 'Decart --';
        } else if (balance.isInvalidKey || balance.isDepleted) {
          bg = AppColors.errorSoft;
          border = AppColors.error.withValues(alpha: 0.3);
          fg = AppColors.error;
          label = balance.isInvalidKey ? 'مفتاح منتهي'.tr : '0 ${'توكن'.tr}';
        } else if (balance.hasBalance) {
          if (balance.isLow) {
            bg = AppColors.warningSoft;
            border = AppColors.warning.withValues(alpha: 0.3);
            fg = AppColors.warning;
          } else {
            bg = AppColors.primarySoft;
            border = AppColors.primaryBorder;
            fg = AppColors.primaryDark;
          }
          label = '${balance.formattedCredits} ${'توكن'.tr}';
        } else {
          bg = AppColors.surfaceAlt;
          border = AppColors.border;
          fg = AppColors.textMuted;
          label = 'Decart --';
        }

        return _ChipContainer(
          bg: bg,
          border: border,
          fg: fg,
          label: label,
          onTap: () => showDecartCreditsSheet(context),
        );
      },
    );
  }
}

class _ChipContainer extends StatelessWidget {
  const _ChipContainer({
    required this.bg,
    required this.border,
    required this.fg,
    required this.label,
    required this.onTap,
  });

  final Color bg;
  final Color border;
  final Color fg;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'إجمالي توكن Decart API'.tr,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: AppHaptics.action(onTap),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.sparkles, size: 14, color: fg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFont.bold,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline banner showing aggregated Decart balance across ALL keys.
class DecartCreditsInlineBanner extends ConsumerWidget {
  const DecartCreditsInlineBanner({super.key});

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(adminDecartCreditsProvider);
    final isLoading = creditsAsync.isLoading || creditsAsync.isRefreshing;
    final balance = creditsAsync.asData?.value;

    final Color bg;
    final Color border;
    final BadgeTone tone;
    final String statusText;

    if (balance == null) {
      bg = AppColors.surfaceAlt;
      border = AppColors.border;
      tone = BadgeTone.neutral;
      statusText = 'جارٍ فحص الرصيد...';
    } else if (balance.needsFunctionDeploy) {
      bg = AppColors.warningSoft;
      border = AppColors.warning.withValues(alpha: 0.3);
      tone = BadgeTone.warning;
      statusText = 'يلزم تحديث الدالة';
    } else if (!balance.configured) {
      bg = AppColors.surfaceAlt;
      border = AppColors.border;
      tone = BadgeTone.neutral;
      statusText = 'غير مُعدّ';
    } else if (balance.isInvalidKey) {
      bg = AppColors.errorSoft;
      border = AppColors.error.withValues(alpha: 0.3);
      tone = BadgeTone.error;
      statusText = 'مفتاح غير صالح';
    } else if (balance.isDepleted) {
      bg = AppColors.errorSoft;
      border = AppColors.error.withValues(alpha: 0.3);
      tone = BadgeTone.error;
      statusText = 'نفد الرصيد';
    } else if (balance.isLow) {
      bg = AppColors.warningSoft;
      border = AppColors.warning.withValues(alpha: 0.3);
      tone = BadgeTone.warning;
      statusText = 'رصيد منخفض';
    } else if (balance.hasBalance) {
      bg = AppColors.primarySoft;
      border = AppColors.primaryBorder;
      tone = BadgeTone.success;
      statusText = balance.totalKeys > 1
          ? '${balance.activeKeys}/${balance.totalKeys} ${'مفاتيح نشطة'.tr}'
          : 'الرصيد نشط';
    } else {
      bg = AppColors.surfaceAlt;
      border = AppColors.border;
      tone = BadgeTone.neutral;
      statusText = 'تعذر الفحص';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  balance != null && balance.totalKeys > 1
                      ? 'إجمالي التوكن المتبقية (كل المفاتيح)'.tr
                      : 'الرصيد المتبقي في Decart API'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: AppFont.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              AppStatusBadge(label: statusText, tone: tone),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: isLoading && balance == null
                    ? Text(
                        '...',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: AppFont.extraBold,
                          color: AppColors.text,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            balance?.hasBalance == true
                                ? '${balance!.formattedCredits} ${'توكن'.tr}'
                                : '--',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: AppFont.extraBold,
                              color: AppColors.text,
                            ),
                          ),
                          if (balance?.hasBalance == true)
                            Text(
                              '${'يعادل تقريباً'.tr} ${balance!.formattedUsd}${balance.totalKeys > 1 ? ' · ${'تبديل تلقائي ذكي'.tr}' : ''}${balance.checkedAt != null ? ' · ${_formatTime(balance.checkedAt!)}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            )
                          else if (balance?.needsFunctionDeploy == true)
                            Text(
                              'أعد نشر Edge Function (decart-session) في Supabase لقراءة الرصيد المباشر.'
                                  .tr,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            )
                          else if (balance?.isInvalidKey == true)
                            Text(
                              'رفض Decart المفاتيح الحالية. يرجى إضافة مفتاح جديد أدناه.'
                                  .tr,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                        ],
                      ),
              ),
              IconButton(
                tooltip: 'تحديث الرصيد'.tr,
                onPressed: isLoading
                    ? null
                    : AppHaptics.action(() {
                        ref.invalidate(adminDecartCreditsProvider);
                        ref.invalidate(adminDecartKeysProvider);
                      }),
                icon: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(AppIcons.refresh, color: AppColors.icon, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet displaying live aggregated Decart balance + per-key breakdown + quick actions.
Future<void> showDecartCreditsSheet(BuildContext context) {
  return AppBottomSheet.show<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    maxHeightFactor: 0.9,
    child: Consumer(
      builder: (sheetCtx, sheetRef, _) {
        final controls = sheetRef
            .watch(adminTryonControlsProvider)
            .asData
            ?.value;
        final balance = sheetRef
            .watch(adminDecartCreditsProvider)
            .asData
            ?.value;
        final keys = balance?.keys ?? const <DecartApiKeyEntry>[];

        return AppBottomSheetScaffold(
          title: 'رصيد Decart API والقياس الافتراضي'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DecartCreditsInlineBanner(),
              if (keys.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${'توزيع الرصيد حسب المفاتيح'.tr} (${keys.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final k in keys) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
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
                                k.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: AppFont.bold),
                              ),
                              Text(
                                k.keyHint,
                                textDirection: TextDirection.ltr,
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
                              k.credits != null
                                  ? '${k.formattedCredits} ${'توكن'.tr}'
                                  : '--',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: AppFont.extraBold),
                            ),
                            Text(
                              _keyStatusText(k).tr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: AppFont.bold,
                                color: _keyStatusColor(k),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
              if (controls != null) ...[
                const SizedBox(height: AppSpacing.sm),
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
                          'إعدادات الجلسة الحالية'.tr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                      Text(
                        '${controls.sessionDurationSeconds} ${'ثانية'.tr} · ${controls.dailyAttemptsLimit} ${'محاولة/يوم'.tr}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: AppFont.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'إدارة وإضافة مفاتيح Decart API'.tr,
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  AppBottomSheet.show<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    maxHeightFactor: 0.94,
                    child: AppBottomSheetScaffold(
                      title: 'إدارة مفاتيح Decart API'.tr,
                      child: const DecartSettingsCard(embedded: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'التحكم في تكلفة التجربة الافتراضية'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  AppBottomSheet.show<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    child: AppBottomSheetScaffold(
                      title: 'التحكم في تكلفة التجربة الافتراضية'.tr,
                      child: const TryonCostControlsCard(embedded: true),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

String _keyStatusText(DecartApiKeyEntry k) {
  if (!k.isActive) return 'موقوف';
  switch (k.status) {
    case 'active':
      return 'نشط';
    case 'low':
      return 'رصيد منخفض';
    case 'depleted':
      return 'نفد الرصيد';
    case 'invalid':
      return 'غير صالح';
    default:
      return 'قيد الفحص';
  }
}

Color _keyStatusColor(DecartApiKeyEntry k) {
  if (!k.isActive) return AppColors.textMuted;
  switch (k.status) {
    case 'active':
      return AppColors.success;
    case 'low':
      return AppColors.warning;
    case 'depleted':
    case 'invalid':
      return AppColors.error;
    default:
      return AppColors.textMuted;
  }
}
