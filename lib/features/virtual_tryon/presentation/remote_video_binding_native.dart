import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemoteVideoBinding {
  RemoteVideoBinding(this.renderer, this.onFirstFrame);
  final RTCVideoRenderer renderer;
  final VoidCallback onFirstFrame;
  int _generation = 0;
  bool _disposed = false;

  void attach(MediaStream? stream) {
    if (_disposed) return;
    final generation = ++_generation;
    var reported = false;
    renderer.onFirstFrameRendered = stream == null
        ? null
        : () {
            if (!_disposed && generation == _generation && !reported) {
              reported = true;
              onFirstFrame();
            }
          };
    renderer.srcObject = stream;
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    renderer.onFirstFrameRendered = null;
  }
}
