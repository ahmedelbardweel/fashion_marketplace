import '../domain/tryon_session.dart';
import 'body_analysis_failure.dart';

enum CaptureReadStage {
  cameraFrame,
  cameraAnalysis,
  outputFrame,
  outputAnalysis,
}

String captureReadFailure(Object failure, CaptureReadStage stage) {
  if (stage == CaptureReadStage.outputFrame ||
      (stage == CaptureReadStage.outputAnalysis &&
          failure is BodyAnalysisFailure &&
          failure.code == 'frame_decode')) {
    return 'تعذر قراءة الفيديو المعالج من خدمة التجربة. أعد الاتصال ثم جرّب مجدداً.';
  }
  if (stage == CaptureReadStage.outputAnalysis) {
    return 'تعذر فحص الفيديو المعالج. أُخفيت النتيجة؛ أعد الاتصال ثم جرّب مجدداً.';
  }
  if (stage == CaptureReadStage.cameraFrame) {
    return BodyAnalysisFailure('frame_decode').message;
  }
  return failure is TryonFailure
      ? failure.message
      : BodyAnalysisFailure('inference').message;
}
