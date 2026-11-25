import 'dart:async';

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/network_guard.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../domain/models/decart_settings_status.dart';
import '../providers/admin_providers.dart';

/// Inline banner showing live aggregated Vidu balance across ALL active keys.
class ViduCreditsInlineBanner extends ConsumerWidget {
  const ViduCreditsInlineBanner({super.key});

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(adminViduCreditsProvider);
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
      statusText = 'يلزم نشر الدالة';
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
                      ? 'إجمالي توكن Vidu المتبقية (كل المفاتيح)'.tr
                      : 'الرصيد المتبقي في Vidu API'.tr,
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
                              '${'بث مباشر (1 توكن/ثانية · Vidu S2)'.tr}${balance!.totalKeys > 1 ? ' · ${'تبديل تلقائي ذكي'.tr}' : ''}${balance.checkedAt != null ? ' · ${_formatTime(balance.checkedAt!)}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            )
                          else if (balance?.needsFunctionDeploy == true)
                            Text(
                              'انشر Edge Function (vidu-tryon) في Supabase لقراءة الرصيد المباشر وتشغيل Vidu.'
                                  .tr,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            )
                          else if (balance?.isInvalidKey == true)
                            Text(
                              'رفض Vidu المفاتيح الحالية. يرجى إضافة مفتاح vda_ صالح أدناه.'
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
                        ref.invalidate(adminViduCreditsProvider);
                        ref.invalidate(adminViduKeysProvider);
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

class ViduSettingsCard extends ConsumerStatefulWidget {
  const ViduSettingsCard({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ViduSettingsCard> createState() => _ViduSettingsCardState();
}

class _ViduSettingsCardState extends ConsumerState<ViduSettingsCard> {
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _mutatingKey = false;
  String? _message;
  bool _failed = false;

  String _saveErrorMessage(Object error) {
    if (error is AppNetworkException || AppErrorMapper.isNetworkError(error)) {
      return AppErrorMapper.message(error);
    }
    if (error is PostgrestException) {
      final message = switch (error.code) {
        '42501' => 'هذا الإعداد متاح للأدمن النشط فقط.'.tr,
        'PGRST202' || '42883' || '42P01' =>
          'يلزم تطبيق تحديث قاعدة البيانات 041 في Supabase أولاً لتفعيل مفاتيح Vidu.'
              .tr,
        '22023' =>
          'رفض السيرفر صيغة مفتاح Vidu. تأكد أن المفتاح يبدأ بـ vda_ وصحيح.'
              .tr,
        'PGRST301' || 'PGRST303' =>
          'جلسة تسجيل الدخول غير صالحة. سجّل الدخول مجدداً ثم أعد المحاولة.'.tr,
        _ => 'رفض السيرفر حفظ المفتاح. يلزم فحص الخطأ في قاعدة البيانات.'.tr,
      };
      final code = error.code;
      if (code != null &&
          code.trim() == code &&
          RegExp(r'^(?:[A-Z0-9]{5}|PGRST[0-9]{3})$').hasMatch(code)) {
        return '$message (رمز الخطأ: $code)'.tr;
      }
      return message;
    }
    return switch (error) {
      AuthException() =>
        'تعذر التحقق من جلسة الدخول. سجّل الدخول مجدداً ثم أعد المحاولة.'.tr,
      TimeoutException() =>
        'انتهت مهلة الحفظ دون تأكيد النتيجة. حدّث حالة الإعداد قبل المحاولة مجدداً.'
            .tr,
      http.ClientException() =>
        'تعذر الاتصال بالسيرفر لتأكيد الحفظ. تحقق من الاتصال وحاول مجدداً.'.tr,
      _ => 'تعذر تأكيد حفظ المفتاح بسبب خطأ غير متوقع في التطبيق.'.tr,
    };
  }

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.clear();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _addKey() async {
    if (_saving || _formKey.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .addViduApiKey(
            apiKey: _keyController.text,
            label: _labelController.text,
          );
      if (!mounted) return;
      _keyController.clear();
      _labelController.clear();
      ref.invalidate(adminViduStatusProvider);
      ref.invalidate(adminViduKeysProvider);
      ref.invalidate(adminViduCreditsProvider);
      setState(() {
        _failed = false;
        _message =
            'تمت إضافة مفتاح Vidu بنجاح وتفعيله ضمن التبديل التلقائي الذكي.'.tr;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = _saveErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleKey(DecartApiKeyEntry entry, bool active) async {
    final id = entry.id;
    if (id == null || _mutatingKey) return;
    setState(() => _mutatingKey = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .toggleViduApiKey(id: id, isActive: active);
      ref.invalidate(adminViduStatusProvider);
      ref.invalidate(adminViduKeysProvider);
      ref.invalidate(adminViduCreditsProvider);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppErrorMapper.message(error, fallback: 'تعذر تحديث حالة المفتاح'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _mutatingKey = false);
    }
  }

  Future<void> _deleteKey(DecartApiKeyEntry entry) async {
    final id = entry.id;
    if (id == null || _mutatingKey) return;
    setState(() => _mutatingKey = true);
    try {
      await ref.read(adminRepositoryProvider).deleteViduApiKey(id);
      ref.invalidate(adminViduStatusProvider);
      ref.invalidate(adminViduKeysProvider);
      ref.invalidate(adminViduCreditsProvider);
      if (mounted) {
        showAppSnackBar(context, 'تم حذف مفتاح Vidu من القائمة'.tr);
      }
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppErrorMapper.message(error, fallback: 'تعذر حذف المفتاح'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _mutatingKey = false);
    }
  }

  BadgeTone _badgeTone(DecartApiKeyEntry entry) {
    if (!entry.isActive) return BadgeTone.neutral;
    switch (entry.status) {
      case 'active':
        return BadgeTone.success;
      case 'low':
        return BadgeTone.warning;
      case 'depleted':
      case 'invalid':
        return BadgeTone.error;
      default:
        return BadgeTone.primary;
    }
  }

  String _badgeLabel(DecartApiKeyEntry entry) {
    if (!entry.isActive) return 'موقوف';
    switch (entry.status) {
      case 'active':
        return 'نشط';
      case 'low':
        return 'منخفض';
      case 'depleted':
        return 'نفد الرصيد';
      case 'invalid':
        return 'غير صالح';
      default:
        return 'محفوظ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditsAsync = ref.watch(adminViduCreditsProvider);
    final keysAsync = ref.watch(adminViduKeysProvider);

    final liveKeys = creditsAsync.asData?.value.keys ?? const [];
    final dbKeys = keysAsync.asData?.value ?? const [];
    final displayKeys = liveKeys.isNotEmpty ? liveKeys : dbKeys;

    final content = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded) ...[
            Text(
              'تجربة الملابس — Vidu AI'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const ViduCreditsInlineBanner(),
          const SizedBox(height: AppSpacing.md),

          if (displayKeys.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${'مفاتيح Vidu المضافة'.tr} (${displayKeys.length})',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
                  ),
                ),
                Text(
                  'تبديل تلقائي عند النفاد'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: AppFont.semiBold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < displayKeys.length; i++) ...[
              _ViduKeyPoolRow(
                index: i + 1,
                entry: displayKeys[i],
                badgeLabel: _badgeLabel(displayKeys[i]),
                badgeTone: _badgeTone(displayKeys[i]),
                busy: _mutatingKey,
                onToggle: displayKeys[i].id == null
                    ? null
                    : (v) => _toggleKey(displayKeys[i], v),
                onDelete: displayKeys[i].id == null
                    ? null
                    : () => _deleteKey(displayKeys[i]),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.md),
          ],

          Text(
            'إضافة مفتاح Vidu API جديد'.tr,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: _labelController,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'اسم تعريفي للمفتاح (اختياري)'.tr,
              hintText: 'مثال: حساب Vidu أساسي / احتياطي 2'.tr,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _keyController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [],
            textDirection: TextDirection.ltr,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'مفتاح Vidu الجديد'.tr,
              hintText: 'vda_…',
            ),
            validator: (value) =>
                RegExp(
                  r'^vda_[A-Za-z0-9][A-Za-z0-9_-]{2,63}_[A-Za-z0-9_-]{16,512}$',
                ).hasMatch(value?.trim() ?? '')
                ? null
                : 'أدخل مفتاح Vidu رسمي صالح يبدأ بـ vda_'.tr,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'تُحفظ جميع مفاتيح Vidu مشفّرة في السيرفر (Vault)، ويقوم النظام تلقائياً بقراءة مجموع التوكن والانتقال للمفتاح التالي فور نفاد أي مفتاح دون انقطاع للعميل.'
                .tr,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _saving ? 'جارٍ الحفظ…'.tr : 'إضافة مفتاح Vidu للقائمة'.tr,
            onPressed: _saving ? null : _addKey,
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: TextStyle(
                  color: _failed ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return widget.embedded ? content : AppCard(child: content);
  }
}

class _ViduKeyPoolRow extends StatelessWidget {
  const _ViduKeyPoolRow({
    required this.index,
    required this.entry,
    required this.badgeLabel,
    required this.badgeTone,
    required this.busy,
    this.onToggle,
    this.onDelete,
  });

  final int index;
  final DecartApiKeyEntry entry;
  final String badgeLabel;
  final BadgeTone badgeTone;
  final bool busy;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$index · ${entry.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.keyHint,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppStatusBadge(label: badgeLabel, tone: badgeTone),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.credits != null
                      ? '${entry.formattedCredits} ${'توكن'.tr}'
                      : 'الرصيد: --'.tr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFont.extraBold,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (onToggle != null)
                Switch.adaptive(
                  value: entry.isActive,
                  activeTrackColor: AppColors.primary,
                  onChanged: busy ? null : AppHaptics.change(onToggle!),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'حذف المفتاح'.tr,
                  onPressed: busy ? null : AppHaptics.action(onDelete!),
                  icon: Icon(AppIcons.delete, size: 18, color: AppColors.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
