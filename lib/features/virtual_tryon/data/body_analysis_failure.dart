import '../domain/tryon_session.dart';

class BodyAnalysisFailure extends TryonFailure {
  BodyAnalysisFailure(this.code) : super(_message(code));
  final String code;

  static const codes = [
    'runtime_load',
    'model_load',
    'worker_load',
    'unsupported',
    'frame_decode',
    'inference',
    'timeout',
    'cancelled',
    'bridge_missing',
  ];

  factory BodyAnalysisFailure.fromBrowser(Object error) {
    final text = error.toString();
    final code = codes
        .where((value) => text.contains('[body-analysis:$value]'))
        .firstOrNull;
    return BodyAnalysisFailure(
      code ??
          (text.contains('fashionBodyAnalyze')
              ? 'bridge_missing'
              : 'inference'),
    );
  }

  static String _message(String code) => switch (code) {
    'bridge_missing' => 'لم تُحمّل أدوات فحص الجسم في هذه الصفحة. حدّث الصفحة بالكامل ثم أعد المحاولة.',
    'runtime_load' =>
      'تعذر تنزيل أدوات فحص الجسم. تحقق من الاتصال ثم أعد الفحص.',
    'model_load' =>
      'تعذر تحميل نموذج فحص الجسم. حدّث الصفحة أو التطبيق ثم أعد الفحص.',
    'worker_load' => 'تعذر بدء كاشف الجسم. حدّث الصفحة بالكامل ثم أعد الفحص.',
    'unsupported' => 'فحص الجسم غير متاح في هذا المتصفح أو هذه النسخة. استخدم متصفحاً حديثاً أو أحدث نسخة من التطبيق.',
    'frame_decode' =>
      'تعذر قراءة صورة الكاميرا. أعد تشغيل الكاميرا ثم أعد الفحص.',
    'timeout' =>
      'استغرق تجهيز كاشف الجسم وقتاً طويلاً. تحقق من الاتصال وأعد الفحص.',
    'cancelled' => 'تم إلغاء فحص الجسم.',
    _ => 'تعذر تحليل صورة الجسم. أعد الفحص؛ إذا تكرر الخطأ، حدّث التطبيق أو المتصفح.',
  };
}
