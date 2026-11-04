import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/tryon_session.dart';
import 'tryon_errors.dart';

class WebRtcCameraSource {
  WebRtcCameraSource({
    this.useWebCapture = kIsWeb,
    bool? portraitWebCapture,
    Future<List<CameraDescription>> Function()? discoverCameras,
    Future<MediaStream> Function(Map<String, dynamic>)? capture,
  }) : portraitWebCapture =
           portraitWebCapture ??
           (defaultTargetPlatform == TargetPlatform.android ||
               defaultTargetPlatform == TargetPlatform.iOS),
       _discoverCameras = discoverCameras ?? availableCameras,
       _capture =
           capture ??
           ((constraints) => navigator.mediaDevices.getUserMedia(constraints));

  final bool useWebCapture;
  final bool portraitWebCapture;
  final Future<List<CameraDescription>> Function() _discoverCameras;
  final Future<MediaStream> Function(Map<String, dynamic>) _capture;
  bool front = true;

  /// Reset to the widest unzoomed view supported by the active native capturer.
  Future<void> resetZoom(MediaStreamTrack track) async {
    if (useWebCapture) return;
    try {
      // Camera1 uses index 0; Camera2/iOS clamp 0 to the minimum 1x ratio.
      await Helper.setZoom(track, 0).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Fixed-focus/front cameras may not expose zoom. Keep their default view.
    }
  }

  Future<MediaStream> open() async {
    try {
      if (useWebCapture) {
        // camera_web.availableCameras() itself opens cameras to enumerate them.
        // Open once through WebRTC, with standard browser constraints only.
        front = true;
        return await _capture({
          'audio': false,
          'video': {
            'width': {'ideal': portraitWebCapture ? 720 : 1280},
            'height': {'ideal': portraitWebCapture ? 1280 : 720},
            'frameRate': {'ideal': 30, 'max': 30},
            'facingMode': {'ideal': 'user'},
            'resizeMode': {'ideal': 'none'},
            'zoom': {'ideal': 1.0},
          },
        });
      }
      // Native capture dimensions describe the landscape sensor format.
      // WebRTC rotates frames using the portrait device orientation; swapping
      // sensor width/height would select an unsuitable format on iOS/Android.
      final cameras = await _discoverCameras();
      if (cameras.isEmpty) throw const TryonFailure('لا توجد كاميرا متاحة.');
      front = cameras.any((c) => c.lensDirection == CameraLensDirection.front);
      return await _capture({
        'audio': false,
        'video': {
          'width': 1280,
          'height': 720,
          'frameRate': 30,
          'facingMode': front ? 'user' : 'environment',
          'optional': <Map<String, dynamic>>[],
        },
      });
    } catch (error) {
      throw cameraFailure(error);
    }
  }
}
