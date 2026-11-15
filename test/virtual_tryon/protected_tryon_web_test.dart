@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

// The installed WebRTC renderer accepts this browser MediaStream adapter.
// ignore: depend_on_referenced_packages
import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_webrtc/src/web/rtc_video_renderer_impl.dart';
// ignore: implementation_imports
import 'package:flutter_webrtc/src/web/rtc_video_view_impl.dart';
import 'package:web/web.dart' as web;
import 'package:fashion_marketplace/features/virtual_tryon/presentation/protected_tryon_preview.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/remote_video_binding_web.dart';

void main() {
  testWidgets('clipped remote HTML video still renders its first frame', (
    tester,
  ) async {
    final canvas = web.HTMLCanvasElement()
      ..width = 160
      ..height = 90;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    final frames = canvas.captureStream(30);
    final renderer = RTCVideoRenderer();
    final ready = Completer<void>();
    final binding = RemoteVideoBinding(renderer, () {
      if (!ready.isCompleted) ready.complete();
    });
    try {
      await tester.runAsync(() async {
        await renderer.initialize();
        binding.attach(MediaStreamWeb(frames, 'synthetic-test'));
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 320,
            height: 180,
            child: ProtectedTryonPreview(
              original: const ColoredBox(color: Color(0xff0000ff)),
              generated: RTCVideoView(renderer),
              points: const [],
              outputPoints: const [],
              sourceAspect: 16 / 9,
              outputAspect: 16 / 9,
              observationAspect: 16 / 9,
              region: 'upper body garment',
              enabled: false,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        var red = false;
        final draw = Timer.periodic(const Duration(milliseconds: 33), (_) {
          red = !red;
          context.fillStyle = (red ? 'red' : 'green').toJS;
          context.fillRect(0, 0, 160, 90);
        });
        try {
          await ready.future.timeout(const Duration(seconds: 8));
        } finally {
          draw.cancel();
        }
      });
      expect(ready.isCompleted, isTrue);
      expect(renderer.findHtmlView()?.videoWidth, 160);
      expect(renderer.findHtmlView()?.style.objectFit, 'contain');
    } finally {
      binding.dispose();
      renderer.srcObject = null;
      await tester.pumpWidget(const SizedBox.shrink());
      for (final track in frames.getTracks().toDart) {
        track.stop();
      }
      await tester.runAsync(renderer.dispose);
    }
  });
}
