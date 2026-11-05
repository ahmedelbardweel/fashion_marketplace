import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../providers/admin_providers.dart';

class DecartSettingsCard extends ConsumerStatefulWidget {
  const DecartSettingsCard({super.key});

  @override
  ConsumerState<DecartSettingsCard> createState() => _DecartSettingsCardState();
}

class _DecartSettingsCardState extends ConsumerState<DecartSettingsCard> {
  final _keyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _message;
  bool _failed = false;

  String _saveErrorMessage(Object error) {
    // Only display recognized code shapes, never upstream messages or details.
    if (error is PostgrestException) {
      final message = switch (error.code) {
        '42501' => 'هذا الإعداد متاح للأدمن النشط فقط.',
        'PGRST202' || '42883' || '42P01' => 'خدمة حفظ المفتاح غير مكتملة على السيرفر. يلزم مراجعة تحديثات قاعدة البيانات.',
        '22023' => 'رفض السيرفر صيغة المفتاح. تأكد من صحة المفتاح وتطبيق تحديث قاعدة البيانات 011.',
        '2201B' => 'يوجد خطأ في قاعدة التحقق من المفتاح على السيرفر. يلزم تطبيق تحديث قاعدة البيانات 011 ثم إعادة الحفظ.',
        'PGRST301' || 'PGRST303' =>
          'جلسة تسجيل الدخول غير صالحة. سجّل الدخول مجدداً ثم أعد المحاولة.',
        _ => 'رفض السيرفر حفظ المفتاح. يلزم فحص الخطأ في قاعدة البيانات.',
      };
      final code = error.code;
      if (code != null &&
          code.trim() == code &&
          RegExp(r'^(?:[A-Z0-9]{5}|PGRST[0-9]{3})$').hasMatch(code)) {
        return '$message (رمز الخطأ: $code)';
      }
      return message;
    }
    return switch (error) {
      AuthException() =>
        'تعذر التحقق من جلسة الدخول. سجّل الدخول مجدداً ثم أعد المحاولة.',
      TimeoutException() => 'انتهت مهلة الحفظ دون تأكيد النتيجة. حدّث حالة الإعداد قبل المحاولة مجدداً.',
      http.ClientException() =>
        'تعذر الاتصال بالسيرفر لتأكيد الحفظ. تحقق من الاتصال وحاول مجدداً.',
      _ => 'تعذر تأكيد حفظ المفتاح بسبب خطأ غير متوقع في التطبيق.',
    };
  }

  @override
  void dispose() {
    _keyController.clear();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _formKey.currentState?.validate() != true) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .setDecartApiKey(_keyController.text);
      if (!mounted) return;
      _keyController.clear();
      ref.invalidate(adminDecartStatusProvider);
      setState(() {
        _failed = false;
        _message = 'تم حفظ المفتاح. سيُستخدم في جلسات تجربة الملابس الجديدة.';
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

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(adminDecartStatusProvider);
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تجربة الملابس — Decart',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Row(
                children: [
                  const Expanded(child: Text('تعذر قراءة حالة إعداد المفتاح.')),
                  IconButton(
                    tooltip: 'إعادة المحاولة',
                    onPressed: () => ref.invalidate(adminDecartStatusProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              data: (value) => Text(
                value.configured
                    ? 'يوجد مفتاح محفوظ بأمان. يمكنك استبداله أدناه.'
                    : 'لم يُحفظ مفتاح من إعدادات الأدمن بعد.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _keyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [],
              textDirection: TextDirection.ltr,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'مفتاح Decart الجديد',
                hintText: 'dct_new-app_…',
              ),
              validator: (value) =>
                  RegExp(r'^dct_(app|new-app)_[A-Za-z0-9]{20,512}$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'أدخل مفتاح Decart صالحاً يبدأ بـ dct_app_ أو dct_new-app_',
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'يُحفظ المفتاح مشفّراً على السيرفر ولا يظهر بعد الحفظ. '
              'الحفظ لا يتحقق من رصيد Decart أو صلاحية الاشتراك.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _saving ? 'جارٍ الحفظ…' : 'حفظ المفتاح',
              onPressed: _saving ? null : _save,
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
      ),
    );
  }
}
