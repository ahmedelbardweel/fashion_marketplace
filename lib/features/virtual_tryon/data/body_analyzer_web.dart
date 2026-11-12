import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../domain/capture_quality.dart';
import 'body_analysis_failure.dart';

@JS('fashionBodyAnalyze')
external JSPromise<JSString> _analyze(JSUint8Array bytes);
@JS('fashionBodyClose')
external void _close();

class BodyAnalyzer {
  Future<List<List<BodyPoint>>> analyze(Uint8List bytes) async {
    try {
      final json = (await _analyze(bytes.toJS).toDart).toDart;
      return (jsonDecode(json) as List)
          .map(
            (pose) =>
                (pose as List).map((p) => BodyPoint.fromMap(p as Map)).toList(),
          )
          .toList();
    } catch (error) {
      throw BodyAnalysisFailure.fromBrowser(error);
    }
  }

  Future<void> dispose() async {
    try {
      _close();
    } catch (_) {
      // An older page or blocked worker script may never have installed the bridge.
    }
  }
}
