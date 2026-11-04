import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/webrtc_camera_source.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/tryon_errors.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';

class _Stream extends Fake implements MediaStream {}

void main() {
  test('web opens one stream without camera plugin discovery or legacy constraints', () async {
    var captures = 0;
    final stream = _Stream();
    final source = WebRtcCameraSource(
      useWebCapture: true,
      portraitWebCapture: false,
      discoverCameras: () =>
          throw StateError('Browser must not probe every camera'),
      capture: (constraints) async {
        captures++;
        expect(constraints['audio'], false);
        final video = constraints['video'] as Map;
        expect(video.containsKey('optional'), false);
        expect(video.containsKey('mandatory'), false);
        expect(video['width'], {'ideal': 1280});
        expect(video['height'], {'ideal': 720});
        expect(video['frameRate'], {'ideal': 30, 'max': 30});
        expect(video['facingMode'], {'ideal': 'user'});
        return stream;
      },
    );
    expect(await source.open(), same(stream));
    expect(captures, 1);
  });

  test('mobile web requests portrait capture without digital crop', () async {
    final source = WebRtcCameraSource(
      useWebCapture: true,
      portraitWebCapture: true,
      capture: (constraints) async {
        final video = constraints['video'] as Map;
        expect(video['width'], {'ideal': 720});
        expect(video['height'], {'ideal': 1280});
        expect(video['resizeMode'], {'ideal': 'none'});
        expect(video['zoom'], {'ideal': 1.0});
        return _Stream();
      },
    );
    await source.open();
  });

  test('native path still discovers the camera before capturing', () async {
    var discovered = false;
    final source = WebRtcCameraSource(
      useWebCapture: false,
      discoverCameras: () async {
        discovered = true;
        return [
          const CameraDescription(
            name: 'back',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90,
          ),
        ];
      },
      capture: (constraints) async {
        expect(discovered, true);
        expect((constraints['video'] as Map)['facingMode'], 'environment');
        return _Stream();
      },
    );
    await source.open();
    expect(source.front, false);
  });

  test(
    'permission denial is actionable and never retried automatically',
    () async {
      var attempts = 0;
      final source = WebRtcCameraSource(
        useWebCapture: true,
        capture: (_) async {
          attempts++;
          throw 'Unable to getUserMedia: NotAllowedError: Permission denied';
        },
      );
      await expectLater(
        source.open(),
        throwsA(
          isA<TryonFailure>().having(
            (e) => e.message,
            'message',
            contains('إذن الكاميرا مرفوض'),
          ),
        ),
      );
      expect(attempts, 1);
    },
  );

  test(
    'known camera errors remain distinct and do not echo raw diagnostics',
    () {
      expect(
        cameraFailure(CameraException('cameraNotFound', 'raw')).message,
        contains('لم يعثر المتصفح على كاميرا'),
      );
      expect(
        cameraFailure('NotReadableError').message,
        contains('قد تكون مستخدمة'),
      );
      expect(
        cameraFailure('OverconstrainedError').message,
        contains('إعدادات الفيديو'),
      );
      expect(
        cameraFailure(TimeoutException('raw')).message,
        contains('انتهت مهلة'),
      );
      final unknown = startupFailure(
        StateError('secret-token=https://private.example'),
        TryonStartupStage.peer,
      );
      expect(unknown.message, contains('WebRTC'));
      expect(unknown.message, isNot(contains('secret-token')));
    },
  );

  test(
    'missing backend, expired login and upstream rejection are distinguishable',
    () {
      expect(sessionHttpFailure(404).message, contains('غير منشورة'));
      expect(sessionHttpFailure(401).message, contains('سجّل الدخول'));
      expect(sessionHttpFailure(502).message, contains('إصدار رمز جلسة'));
      expect(sessionHttpFailure(503).message, contains('غير مهيأة'));
      const failure = TryonFailure('known failure');
      expect(startupFailure(failure, TryonStartupStage.session), same(failure));
    },
  );
}
