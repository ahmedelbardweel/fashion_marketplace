import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/remote_frame_gate.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/body_analysis_failure.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/capture_read_failure.dart';

void main() {
  test(
    'announced video cannot be sampled until a real first frame arrives',
    () {
      final gate = RemoteFrameGate<Object>();
      final stream = Object();
      gate.attach(stream);
      expect(gate.readyStream, isNull);
      gate.markRendered(stream);
      expect(gate.readyStream, same(stream));
      gate.attach(null);
      expect(gate.readyStream, isNull);
      gate.markRendered(stream);
      expect(gate.readyStream, isNull);
    },
  );
  test('late callbacks from an old stream never unlock its replacement', () {
    final gate = RemoteFrameGate<Object>();
    final old = Object(), current = Object();
    gate.attach(old);
    gate.markRendered(old);
    gate.attach(current);
    gate.markRendered(old);
    expect(gate.readyStream, isNull);
    gate.markRendered(current);
    expect(gate.readyStream, same(current));
  });
  test('remote frame failures never tell users to restart their camera', () {
    final failure = BodyAnalysisFailure('frame_decode');
    for (final stage in [
      CaptureReadStage.outputFrame,
      CaptureReadStage.outputAnalysis,
    ]) {
      final message = captureReadFailure(failure, stage);
      expect(message, contains('الفيديو المعالج'));
      expect(message, isNot(contains('أعد تشغيل الكاميرا')));
    }
    expect(
      captureReadFailure(failure, CaptureReadStage.cameraFrame),
      contains('صورة الكاميرا'),
    );
  });
}
