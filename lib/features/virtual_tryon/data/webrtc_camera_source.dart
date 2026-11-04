import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/tryon_session.dart';
import 'tryon_errors.dart';

class WebRtcCameraSource {
  WebRtcCameraSource({
    this.useWebCapture = kIsWeb,
    Future<List<CameraDescription>> Function()? discoverCameras,
    Future<MediaStream> Function(Map<String, dynamic>)? capture,
  }) : _discoverCameras = discoverCameras ?? availableCameras,
       _capture =
           capture ??
           ((constraints) => navigator.mediaDevices.getUserMedia(constraints));

  final bool useWebCapture;
  final Future<List<CameraDescription>> Function() _discoverCameras;
  final Future<MediaStream> Function(Map<String, dynamic>) _capture;
  bool front = true;

  Future<MediaStream> open() async {
    try {
      if (useWebCapture) {
        // camera_web.availableCameras() itself opens cameras to enumerate them.
        // Open once through WebRTC, with standard browser constraints only.
        front = true;
        return await _capture({
          'audio': false,
          'video': {
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
            'frameRate': {'ideal': 30, 'max': 30},
            'facingMode': {'ideal': 'user'},
          },
        });
      }
      // On mobile camera is used only for discovery; WebRTC owns capture.
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
