import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/models/decart_settings_status.dart';
import '../providers/admin_providers.dart';

class TryonCostControlsCard extends ConsumerStatefulWidget {
  const TryonCostControlsCard({super.key});

  @override
  ConsumerState<TryonCostControlsCard> createState() =>
      _TryonCostControlsCardState();
}

class _TryonCostControlsCardState extends ConsumerState<TryonCostControlsCard> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController(text: '30');
  final _dailyLimitController = TextEditingController(text: '3');
  bool _enabled = true;
  bool _hydrated = false;
  bool _saving = false;
  String? _message;
  bool _failed = false;

  void _hydrateFrom(TryonCostControls controls) {
    if (_hydrated) return;
    _hydrated = true;
    _enabled = controls.enabled;
    _durationController.text = controls.sessionDurationSeconds.toString();
    _dailyLimitController.text = controls.dailyAttemptsLimit.toString();
  }

  @override
  void dispose() {
    _durationController.dispose();
    _dailyLimitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _formKey.currentState?.validate() != true) return;
    final duration = int.tryParse(_durationController.text.trim()) ?? 30;
    final dailyLimit = int.tryParse(_dailyLimitController.text.trim()) ?? 3;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final updated = await ref
          .read(adminRepositoryProvider)
          .updateTryonControls(
            enabled: _enabled,
            sessionDurationSeconds: duration,
            dailyAttemptsLimit: dailyLimit,
          );
      if (!mounted) return;
      _enabled = updated.enabled;
      _durationController.text = updated.sessionDurationSeconds.toString();
      _dailyLimitController.text = updated.dailyAttemptsLimit.toString();
      ref.invalidate(adminTryonControlsProvider);
      setState(() {
        _failed = false;
        _message = 'تم حفظ إعدادات التحكم في تكلفة التجربة بنجاح.'.tr;
      });
    } catch (error) {
      if (!mounted) return;
      final text = error is PostgrestException && error.code == 'PGRST202'
          ? 'يلزم تطبيق تحديث قاعدة البيانات 019 في Supabase أولاً.'.tr
          : 'تعذر حفظ إعدادات التحكم في التكلفة. حاول مجدداً.'.tr;
      setState(() {
        _failed = true;
        _message = text;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncControls = ref.watch(adminTryonControlsProvider);

    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'التحكم في تكلفة التجربة الافتراضية'.tr,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            asyncControls.when(
              loading: () => AppSkeleton(
                child: Text('جارٍ تحميل إعدادات التكلفة…'.tr),
              ),
              error: (_, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'تعذر قراءة إعدادات التكلفة من السيرفر (تأكد من تطبيق تحديث 019).'
                          .tr,
                    ),
                  ),
                  IconButton(
                    tooltip: 'إعادة المحاولة'.tr,
                    onPressed: () {
                      _hydrated = false;
                      ref.invalidate(adminTryonControlsProvider);
                    },
                    icon: const Icon(AppIcons.refresh),
                  ),
                ],
              ),
              data: (controls) {
                _hydrateFrom(controls);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        value: _enabled,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _enabled = value),
                        contentPadding: EdgeInsets.zero,
                        activeTrackColor: AppColors.primary,
                        title: Text(
                          'تفعيل ميزة التجربة الافتراضية'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          _enabled
                              ? 'الخدمة متاحة حالياً للمستخدمين.'.tr
                              : 'الخدمة متوقفة مؤقتاً لتوفير التكلفة.'.tr,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _durationController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'مدة جلسة التجربة (بالثواني)'.tr,
                        helperText: 'القيمة المسموحة بين 10 و300 ثانية (الافتراضي 30).'.tr,
                      ),
                      validator: (value) {
                        final n = int.tryParse(value?.trim() ?? '');
                        if (n == null || n < 10 || n > 300) {
                          return 'أدخل مدة بين 10 و300 ثانية.'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _dailyLimitController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'الحد اليومي للمحاولات لكل مستخدم'.tr,
                        helperText: 'القيمة المسموحة بين 1 و100 محاولة يومياً (الافتراضي 3).'.tr,
                      ),
                      validator: (value) {
                        final n = int.tryParse(value?.trim() ?? '');
                        if (n == null || n < 1 || n > 100) {
                          return 'أدخل عدداً بين 1 و100 محاولة يومياً.'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: _saving
                          ? 'جارٍ الحفظ…'.tr
                          : 'حفظ إعدادات التكلفة'.tr,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                );
              },
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _message!,
                style: TextStyle(
                  color: _failed ? Theme.of(context).colorScheme.error : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
