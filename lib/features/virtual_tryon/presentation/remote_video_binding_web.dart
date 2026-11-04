import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
// Explicit web type: the analyzer otherwise resolves the native conditional export.
// ignore: implementation_imports
import 'package:flutter_webrtc/src/web/rtc_video_renderer_impl.dart';

/// flutter_webrtc 0.12.x exposes onFirstFrameRendered on web but never invokes
/// it. Observe the HTML video frame instead; SDP/track metadata is not readiness.
class RemoteVideoBinding {
  RemoteVideoBinding(this.renderer, this.onFirstFrame);
  final RTCVideoRenderer renderer;
  final VoidCallback onFirstFrame;
  Timer? _poll;
  VoidCallback? _cancelFrame;
  int _generation = 0;
  bool _disposed = false;

  void attach(MediaStream? stream) {
    if (_disposed) return;
    final generation = ++_generation;
    _cancel();
    renderer.srcObject = stream;
    if (stream == null) return;

    // RTCVideoView mounts its HTML element after renderVideo changes. Poll only
    // during startup, then cancel after subscribing to the first browser frame.
    _poll = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_disposed || generation != _generation) return;
      final video = renderer.findHtmlView();
      if (video == null || video.srcObject == null) return;
      final callback = video.getProperty<JSAny?>(
        'requestVideoFrameCallback'.toJS,
      );
      if (callback != null && callback.typeofEquals('function')) {
        _poll?.cancel();
        _poll = null;
        final requestId = video.requestVideoFrameCallback(
          ((double timestamp, JSObject metadata) {
            if (_disposed || generation != _generation) return;
            _cancelFrame = null;
            onFirstFrame();
          }).toJS,
        );
        _cancelFrame = () => video.cancelVideoFrameCallback(requestId);
      } else if (video.readyState >= 2 &&
          video.videoWidth > 0 &&
          video.videoHeight > 0) {
        // Older browsers: HAVE_CURRENT_DATA means an actual current frame is
        // available, unlike renderVideo which is set as soon as a track arrives.
        _poll?.cancel();
        _poll = null;
        onFirstFrame();
      }
    });
  }

  void _cancel() {
    _poll?.cancel();
    _poll = null;
    _cancelFrame?.call();
    _cancelFrame = null;
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    _cancel();
  }
}
