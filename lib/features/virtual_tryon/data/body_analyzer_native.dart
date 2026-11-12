import 'package:flutter/services.dart';

import '../domain/capture_quality.dart';
import 'body_analysis_failure.dart';

class BodyAnalyzer {
  static const _channel = MethodChannel('fashion/body_analysis');
  Future<List<List<BodyPoint>>> analyze(Uint8List bytes) async {
    try {
      final result = await _channel.invokeListMethod<dynamic>('analyze', bytes);
      if (result == null) throw StateError('Body analysis unavailable');
      return result
          .map(
            (pose) =>
                (pose as List).map((p) => BodyPoint.fromMap(p as Map)).toList(),
          )
          .toList();
    } on MissingPluginException {
      throw BodyAnalysisFailure('unsupported');
    } on PlatformException catch (error) {
      throw BodyAnalysisFailure(
        error.code == 'invalid_frame' ? 'frame_decode' : 'inference',
      );
    }
  }

  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on PlatformException {
      // The activity may already have been destroyed.
    } on MissingPluginException {
      /* Unsupported platforms stay gated. */
    }
  }
}
