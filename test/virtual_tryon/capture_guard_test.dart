import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/capture_guard.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/capture_quality.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';

import 'capture_quality_test.dart' show body, frame, top;

class _Track extends Fake implements MediaStreamTrack {
  _Track(this.marker);
  final int marker;
  @override
  Future<ByteBuffer> captureFrame() async =>
      Uint8List.fromList([marker]).buffer;
}

class _Stream extends Fake implements MediaStream {
  _Stream([int id = 1]) : track = _Track(id);
  final _Track track;
  @override
  List<MediaStreamTrack> getVideoTracks() => [track];
}

void main() {
  testWidgets(
    'continuous protection pauses on motion, distance and lost framing, then recovers',
    (tester) async {
      var elapsed = Duration.zero;
      var source = body();
      var output = body();
      final unsafe = <String>[];
      final guard = CaptureGuardController(
        analyzeFrame: (bytes) async => [bytes.first == 1 ? source : output],
        inspectFrame: (_, poses) async => frame(poses: poses),
        elapsed: () => elapsed,
      );
      addTearDown(guard.dispose);
      Future<void> sample([int count = 1]) async {
        for (var i = 0; i < count; i++) {
          elapsed += const Duration(milliseconds: 450);
          await tester.pump(const Duration(milliseconds: 450));
        }
      }

      final validation = guard.validate(_Stream(), top, unsafe.add);
      await sample(6);
      await validation;
      expect(guard.approved, isTrue);
      expect(
        guard.canShowOverlay,
        isFalse,
        reason: 'Local approval is not output approval',
      );
      guard.outputStream = _Stream(2);
      await sample();
      expect(guard.canShowOverlay, isTrue);

      // A moving face is dangerous even with stationary shoulders.
      source = body()..[0] = const BodyPoint(.5, .3, 0, .99);
      await sample();
      expect(guard.assessment.issue, CaptureIssue.moving);
      expect(guard.canShowOverlay, isFalse);
      expect(guard.approved, isTrue);
      source = body();
      await sample(7);
      expect(guard.canShowOverlay, isTrue);

      // Stepping away changes scale; the old generated body must not be shown.
      source = body()
          .map(
            (p) => BodyPoint(
              .5 + (p.x - .5) * .7,
              .5 + (p.y - .5) * .7,
              p.z,
              p.confidence,
            ),
          )
          .toList();
      await sample(7);
      expect(guard.canShowOverlay, isFalse);
      output = source;
      await sample();
      expect(guard.canShowOverlay, isTrue);

      source = List.of(source)..[11] = const BodyPoint(-1, -1, 0, 0);
      await sample();
      expect(guard.canShowOverlay, isFalse);
      expect(
        guard.approved,
        isTrue,
        reason: 'Recover without tearing down the session',
      );
      source = output;
      await sample(6);
      expect(guard.canShowOverlay, isTrue);
      expect(unsafe, isEmpty);

      guard.outputStream = _Stream(3);
      expect(
        guard.canShowOverlay,
        isFalse,
        reason: 'Replacement streams require a new match',
      );
      await sample();
      expect(guard.canShowOverlay, isTrue);
      guard.cancel();
      expect(guard.canShowOverlay, isFalse);
      expect(guard.overlayPoints, isEmpty);
    },
  );

  testWidgets('stale and detached output analyses cannot unlock the overlay', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    Completer<List<List<BodyPoint>>>? delayed;
    final guard = CaptureGuardController(
      analyzeFrame: (bytes) => bytes.first == 2 && delayed != null
          ? delayed.future
          : Future.value([body()]),
      inspectFrame: (_, poses) async => frame(poses: poses),
      elapsed: () => elapsed,
    );
    addTearDown(guard.dispose);
    Future<void> sample([int count = 1]) async {
      for (var i = 0; i < count; i++) {
        elapsed += const Duration(milliseconds: 450);
        await tester.pump(const Duration(milliseconds: 450));
      }
    }

    final validation = guard.validate(_Stream(), top, (_) {});
    await sample(6);
    await validation;
    guard.outputStream = _Stream(2);
    await sample();
    expect(guard.canShowOverlay, isTrue);
    delayed = Completer();
    await sample(3);
    expect(guard.canShowOverlay, isFalse);
    delayed.complete([body()]);
    await tester.pump();
    expect(
      guard.canShowOverlay,
      isFalse,
      reason: 'Slow results are never marked fresh',
    );
    delayed = null;
    await sample();
    expect(guard.canShowOverlay, isTrue);
    delayed = Completer();
    await sample();
    guard.outputStream = null;
    delayed.complete([body()]);
    await tester.pump();
    expect(guard.canShowOverlay, isFalse);
    expect(guard.outputPoints, isEmpty);
    guard.cancel();
  });

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
      guard.cancel();
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
