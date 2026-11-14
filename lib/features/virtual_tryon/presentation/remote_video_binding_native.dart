import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemoteVideoBinding {
  RemoteVideoBinding(this.renderer, this.onFirstFrame);
  final RTCVideoRenderer renderer;
  final VoidCallback onFirstFrame;
  int _generation = 0;
  bool _disposed = false;
  Timer? _fallbackTimer;

  void attach(MediaStream? stream) {
    if (_disposed) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    final generation = ++_generation;
    var reported = false;
    void report() {
      if (!_disposed && generation == _generation && !reported) {
        reported = true;
        _fallbackTimer?.cancel();
        _fallbackTimer = null;
        onFirstFrame();
      }
    }

    if (stream == null) {
      renderer.onFirstFrameRendered = null;
      renderer.onResize = null;
      renderer.srcObject = null;
      return;
    }

    renderer.onFirstFrameRendered = report;
    renderer.onResize = () {
      if (renderer.videoWidth > 0 || renderer.videoHeight > 0) {
        report();
      }
    };
    renderer.srcObject = stream;
    // Fallback for iOS/Android WebRTC surfaces where onFirstFrameRendered may not fire
    if (stream.getVideoTracks().isNotEmpty) {
      _fallbackTimer = Timer(const Duration(milliseconds: 500), report);
    }
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    renderer.onFirstFrameRendered = null;
    renderer.onResize = null;
  }
}
