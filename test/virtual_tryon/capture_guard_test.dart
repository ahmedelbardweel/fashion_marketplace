import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/capture_guard.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/capture_quality.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';

import 'capture_quality_test.dart' show body, frame, top;

class _Track extends Fake implements MediaStreamTrack {
  @override
  Future<ByteBuffer> captureFrame() async => Uint8List(1).buffer;
}

class _Stream extends Fake implements MediaStream {
  final track = _Track();
  @override
  List<MediaStreamTrack> getVideoTracks() => [track];
}

void main() {
  testWidgets(
    'automatically validates only after continuous good frames; rechecks each garment',
    (tester) async {
      var elapsed = Duration.zero;
      var observation = frame(light: 20);
      final guard = CaptureGuardController(
        analyzeFrame: (_) async => observation.poses,
        inspectFrame: (_, _) async => observation,
        elapsed: () => elapsed,
      );
      addTearDown(guard.dispose);
      var completions = 0;
      final unsafe = <String>[];
      final stream = _Stream();
      var validation = guard
          .validate(stream, top, unsafe.add)
          .then((_) => completions++);
      Future<void> samples(int count) async {
        for (var i = 0; i < count; i++) {
          elapsed += const Duration(milliseconds: 450);
          await tester.pump(const Duration(milliseconds: 450));
        }
      }

      await samples(8);
      expect(completions, 0, reason: 'Darkness never auto-advances');
      observation = frame();
      await samples(4);
      expect(completions, 0, reason: 'Still needs two seconds');
      observation = frame(poses: [body(), body()]);
      await samples(1);
      expect(guard.assessment.issue, CaptureIssue.multiplePeople);
      observation = frame();
      await samples(5);
      expect(
        completions,
        0,
        reason: 'A second person resets continuous stability',
      );
      await samples(1);
      await validation;
      expect(completions, 1);
      expect(guard.approved, isTrue);
      await samples(2);
      expect(completions, 1, reason: 'Completes exactly once');

      validation = guard
          .validate(stream, top, unsafe.add)
          .then((_) => completions++);
      expect(guard.approved, isFalse);
      await samples(5);
      expect(completions, 1, reason: 'Previous validation is never reused');
      await samples(1);
      await validation;
      expect(completions, 2);
      expect(unsafe, isEmpty);
    },
  );

  testWidgets('cancellation cannot auto-approve a late analysis', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    final guard = CaptureGuardController(
      analyzeFrame: (_) async => [body()],
      inspectFrame: (_, _) async => frame(),
      elapsed: () => elapsed,
    );
    addTearDown(guard.dispose);
    final validation = guard.validate(_Stream(), top, (_) {});
    final cancelled = expectLater(validation, throwsA(isA<TryonFailure>()));
    elapsed = const Duration(milliseconds: 450);
    await tester.pump(elapsed);
    guard.cancel();
    elapsed += const Duration(seconds: 5);
    await tester.pump(const Duration(seconds: 5));
    await cancelled;
    expect(guard.approved, isFalse);
    expect(guard.analyzing, isFalse);
  });
}
