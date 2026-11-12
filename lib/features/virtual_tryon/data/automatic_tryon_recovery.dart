import '../domain/capture_quality.dart';
import 'body_analysis_failure.dart';
import 'capture_read_failure.dart';

/// Retry only known transient failures. Unknown/configuration/permission errors
/// need a user or deployment change, and must never repeatedly open the camera.
class AutomaticTryonRecovery {
  static const maxAttempts = 3;
  int attempts = 0;

  Duration? nextDelay(String? message) {
    if (attempts >= maxAttempts || !_recoverable(message)) return null;
    return Duration(seconds: 2 << attempts++);
  }

  bool _recoverable(String? message) {
    if (message == null) return false;
    if (CaptureIssue.values.any((issue) => issue.message == message)) {
      return true;
    }
    for (final code in [
      'runtime_load',
      'frame_decode',
      'inference',
      'timeout',
    ]) {
      if (message == BodyAnalysisFailure(code).message) return true;
    }
    for (final stage in [
      CaptureReadStage.outputFrame,
      CaptureReadStage.outputAnalysis,
    ]) {
      if (message == captureReadFailure(StateError('unavailable'), stage))
        return true;
    }
    return const {
      'توقف فحص الكاميرا. أعد الفحص قبل المتابعة.',
      'الفحص بطيء على هذا الجهاز. أعد المحاولة.',
      'أعد تثبيت وضعيتك.',
      'تعذر التأكد من وجود شخص واحد في النتيجة. أعد الفحص.',
      'لم تتطابق نتيجة القطعة مع وضعية جسمك. أُخفيت النتيجة؛ أعد الفحص.',
      'تم تغيير الكاميرا. أعد فحص الجسم قبل التجربة.',
      'تعذر إرسال بيانات الاتصال.',
      'انقطع اتصال الفيديو. أعد المحاولة.',
      'تعذر إنشاء اتصال الفيديو. تحقق من الشبكة وخادم TURN.',
      'تعذر الاتصال بخادم التجربة.',
      'أُغلق اتصال الخادم. أعد المحاولة.',
      'لم يصل فيديو معالج من الخادم ضمن المهلة.',
      'تعذر عرض الفيديو المرتجع.',
      'لم يؤكد الخادم تحديث القطعة. أعد الاتصال.',
      'تعذر فتح قناة الاتصال بخادم التجربة. تحقق من الشبكة ثم أعد المحاولة.',
    }.contains(message);
  }
}
