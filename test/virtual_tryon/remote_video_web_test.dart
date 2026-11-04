@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
// ignore: implementation_imports
import 'package:flutter_webrtc/src/web/rtc_video_renderer_impl.dart';
import 'package:web/web.dart' as web;
import 'package:fashion_marketplace/features/virtual_tryon/presentation/remote_video_binding_web.dart';

class _Stream extends Fake implements MediaStream {}

class _Renderer extends RTCVideoRenderer {
  _Renderer(this.video);
  final web.HTMLVideoElement video;
  MediaStream? _stream;
  @override
  MediaStream? get srcObject => _stream;
  @override
  set srcObject(MediaStream? stream) {
    _stream = stream;
  }

  @override
  web.HTMLVideoElement? findHtmlView() => video;
}

void main() {
  test(
    'real browser frame reports readiness without plugin first-frame callback',
    () async {
      final canvas = web.HTMLCanvasElement()
        ..width = 160
        ..height = 90;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      final frames = canvas.captureStream(30);
      final video = web.HTMLVideoElement()
        ..muted = true
        ..autoplay = true
        ..srcObject = frames;
      video.setAttribute('playsinline', 'true');
      web.document.body!.append(video);
      final renderer = _Renderer(video);
      var nativeCallbacks = 0;
      renderer.onFirstFrameRendered = () => nativeCallbacks++;
      final ready = Completer<void>();
      var reports = 0;
      final binding = RemoteVideoBinding(renderer, () {
        reports++;
        if (!ready.isCompleted) ready.complete();
      });
      var red = false;
      final draw = Timer.periodic(const Duration(milliseconds: 33), (_) {
        red = !red;
        context.fillStyle = (red ? 'red' : 'blue').toJS;
        context.fillRect(0, 0, 160, 90);
      });
      try {
        binding.attach(_Stream());
        await video.play().toDart;
        await ready.future.timeout(const Duration(seconds: 8));
        expect(video.videoWidth, 160);
        expect(nativeCallbacks, 0);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(reports, 1);
      } finally {
        binding.dispose();
        draw.cancel();
        for (final track in frames.getTracks().toDart) {
          track.stop();
        }
        video.srcObject = null;
        video.remove();
      }
    },
  );

  test('retry and disposal cancel pending browser callbacks and ignore stale frames', () async {
    final video = web.HTMLVideoElement()..srcObject = web.MediaStream();
    final callbacks = <JSFunction>[];
    final cancellations = <int>[];
    video.setProperty(
      'requestVideoFrameCallback'.toJS,
      ((JSFunction callback) {
        callbacks.add(callback);
        return callbacks.length;
      }).toJS,
    );
    video.setProperty(
      'cancelVideoFrameCallback'.toJS,
      ((int id) {
        cancellations.add(id);
      }).toJS,
    );
    var reports = 0;
    final binding = RemoteVideoBinding(_Renderer(video), () => reports++);
    try {
      binding.attach(_Stream());
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(callbacks.length, 1);
      binding.attach(_Stream());
      callbacks[0].callAsFunction(null, 0.toJS, JSObject());
      expect(reports, 0);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(callbacks.length, 2);
      binding.dispose();
      callbacks[1].callAsFunction(null, 0.toJS, JSObject());
      expect(reports, 0);
      expect(cancellations, [1, 2]);
    } finally {
      binding.dispose();
      video.srcObject = null;
    }
  });
}
