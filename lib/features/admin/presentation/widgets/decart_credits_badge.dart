import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/network_guard.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../domain/models/decart_settings_status.dart';
import '../providers/admin_providers.dart';
import 'decart_settings_card.dart';
import 'tryon_cost_controls_card.dart';
import 'vidu_settings_card.dart';

/// Compact live Try-On tokens pill for the top Admin AppBar.
/// Automatically tracks the currently active Try-On provider (Decart or Vidu)
/// and displays the combined remaining tokens across all active keys for it.
class DecartCreditsAppBarChip extends ConsumerWidget {
  const DecartCreditsAppBarChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controls = ref.watch(adminTryonControlsProvider).asData?.value;
    final activeProvider = controls?.activeProvider ?? TryonProvider.decart;
    final creditsAsync = activeProvider == TryonProvider.vidu
        ? ref.watch(adminViduCreditsProvider)
        : ref.watch(adminDecartCreditsProvider);
    final shortName = activeProvider.shortLabel;

    return creditsAsync.when(
      loading: () => _ChipContainer(
        bg: AppColors.surfaceAlt,
        border: AppColors.border,
        fg: AppColors.textMuted,
        label: '$shortName …',
        tooltip: '${'إجمالي توكن'.tr} ${activeProvider.displayName}',
        onTap: () => showDecartCreditsSheet(context),
      ),
      error: (_, _) => _ChipContainer(
        bg: AppColors.surfaceAlt,
        border: AppColors.border,
        fg: AppColors.textMuted,
        label: shortName,
        tooltip: '${'إجمالي توكن'.tr} ${activeProvider.displayName}',
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
          label = '$shortName !';
        } else if (!balance.configured) {
          bg = AppColors.surfaceAlt;
          border = AppColors.border;
          fg = AppColors.textMuted;
          label = '$shortName --';
        } else if (balance.isInvalidKey || balance.isDepleted) {
          bg = AppColors.errorSoft;
          border = AppColors.error.withValues(alpha: 0.3);
          fg = AppColors.error;
          label = balance.isInvalidKey
              ? '$shortName · ${'منتهي'.tr}'
              : '$shortName · 0';
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
          label = '$shortName · ${balance.formattedCredits}';
        } else {
          bg = AppColors.surfaceAlt;
          border = AppColors.border;
          fg = AppColors.textMuted;
          label = '$shortName --';
        }

        return _ChipContainer(
          bg: bg,
          border: border,
          fg: fg,
          label: label,
          tooltip: '${'المحرك النشط:'.tr} ${activeProvider.displayName}',
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
    required this.tooltip,
    required this.onTap,
  });

  final Color bg;
  final Color border;
  final Color fg;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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

/// Interactive Admin switcher to toggle the active Virtual Try-On engine
/// between Decart AI (real-time camera) and Vidu AI (high-res photo try-on).
class TryonProviderSwitcherWidget extends ConsumerStatefulWidget {
  const TryonProviderSwitcherWidget({super.key});

  @override
  ConsumerState<TryonProviderSwitcherWidget> createState() =>
      _TryonProviderSwitcherWidgetState();
}

class _TryonProviderSwitcherWidgetState
    extends ConsumerState<TryonProviderSwitcherWidget> {
  bool _switching = false;

  Future<void> _selectProvider(
    TryonProvider target,
    TryonProvider current,
  ) async {
    if (_switching || target == current) return;
    setState(() => _switching = true);
    try {
      await ref.read(adminRepositoryProvider).setTryonProvider(target);
      ref.invalidate(adminTryonControlsProvider);
      if (mounted) {
        showAppSnackBar(
          context,
          '${'تم تحويل محرك التجربة الافتراضية إلى'.tr} ${target.displayName}',
        );
      }
    } catch (error) {
      if (mounted) {
        final msg = error is PostgrestException &&
                (error.code == 'PGRST202' || error.code == '42883')
            ? 'يلزم تطبيق تحديث قاعدة البيانات 041 في Supabase أولاً.'.tr
            : AppErrorMapper.message(
                error,
                fallback: 'تعذر تبديل محرك التجربة الافتراضية',
              );
        showAppSnackBar(context, msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controls = ref.watch(adminTryonControlsProvider).asData?.value;
    final active = controls?.activeProvider ?? TryonProvider.decart;
    final decartBalance = ref.watch(adminDecartCreditsProvider).asData?.value;
    final viduBalance = ref.watch(adminViduCreditsProvider).asData?.value;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'محرك التجربة الافتراضية النشط'.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
                ),
              ),
              if (_switching)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                AppStatusBadge(
                  label: active.displayName,
                  tone: BadgeTone.primary,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'التبديل يدوي من الإدارة؛ يعمل التطبيق على المحرك المختار فقط.'.tr,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ProviderOptionTile(
                  title: 'Decart AI',
                  subtitle: 'كاميرا مباشرة'.tr,
                  creditsText: decartBalance?.hasBalance == true
                      ? '${decartBalance!.formattedCredits} ${'توكن'.tr}'
                      : '--',
                  selected: active == TryonProvider.decart,
                  disabled: _switching,
                  onTap: () => _selectProvider(TryonProvider.decart, active),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ProviderOptionTile(
                  title: 'Vidu AI',
                  subtitle: 'صور عالية الدقة'.tr,
                  creditsText: viduBalance?.hasBalance == true
                      ? '${viduBalance!.formattedCredits} ${'توكن'.tr}'
                      : '--',
                  selected: active == TryonProvider.vidu,
                  disabled: _switching,
                  onTap: () => _selectProvider(TryonProvider.vidu, active),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderOptionTile extends StatelessWidget {
  const _ProviderOptionTile({
    required this.title,
    required this.subtitle,
    required this.creditsText,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String creditsText;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: disabled ? null : AppHaptics.action(onTap),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.extraBold,
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.text,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                creditsText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: AppFont.bold,
                  color: selected ? AppColors.primaryDark : AppColors.text,
                ),
              ),
            ],
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
                              '${balance!.hasUsd ? '${'يعادل تقريباً'.tr} ${balance.formattedUsd}' : 'بث مباشر (Decart)'}${balance.totalKeys > 1 ? ' · ${'تبديل تلقائي ذكي'.tr}' : ''}${balance.checkedAt != null ? ' · ${_formatTime(balance.checkedAt!)}' : ''}',
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

/// Bottom sheet displaying the Active Provider Switcher (Decart / Vidu),
/// live aggregated balance + per-key breakdown + quick management actions.
Future<void> showDecartCreditsSheet(BuildContext context) {
  return AppBottomSheet.show<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    maxHeightFactor: 0.92,
    child: Consumer(
      builder: (sheetCtx, sheetRef, _) {
        final controls = sheetRef
            .watch(adminTryonControlsProvider)
            .asData
            ?.value;
        final activeProvider = controls?.activeProvider ?? TryonProvider.decart;
        final activeBalance = activeProvider == TryonProvider.vidu
            ? sheetRef.watch(adminViduCreditsProvider).asData?.value
            : sheetRef.watch(adminDecartCreditsProvider).asData?.value;
        final keys = activeBalance?.keys ?? const <DecartApiKeyEntry>[];

        return AppBottomSheetScaffold(
          title: 'الذكاء الاصطناعي والقياس الافتراضي'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TryonProviderSwitcherWidget(),
              const SizedBox(height: AppSpacing.md),
              if (activeProvider == TryonProvider.vidu)
                const ViduCreditsInlineBanner()
              else
                const DecartCreditsInlineBanner(),
              if (keys.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${'توزيع الرصيد —'.tr} ${activeProvider.shortLabel} (${keys.length})',
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
                          'إعدادات الجلسة والحد اليومي'.tr,
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
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'مفاتيح Decart'.tr,
                      variant: activeProvider == TryonProvider.decart
                          ? AppButtonVariant.filled
                          : AppButtonVariant.secondary,
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
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'مفاتيح Vidu'.tr,
                      variant: activeProvider == TryonProvider.vidu
                          ? AppButtonVariant.filled
                          : AppButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        AppBottomSheet.show<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          maxHeightFactor: 0.94,
                          child: AppBottomSheetScaffold(
                            title: 'إدارة مفاتيح Vidu API'.tr,
                            child: const ViduSettingsCard(embedded: true),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
