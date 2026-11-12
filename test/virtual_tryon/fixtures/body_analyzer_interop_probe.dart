// Compiled by browser_body_analysis_smoke.mjs, then executed in real Chrome.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:fashion_marketplace/features/virtual_tryon/data/body_analysis_failure.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/body_analyzer_web.dart';

@JS('bodyInteropReport')
external void _report(JSString result);
@JS('__bodyTestBytes')
external JSUint8Array get _frame;

Future<void> main() async {
  final analyzer = BodyAnalyzer();
  try {
    final poses = await analyzer.analyze(_frame.toDart);
    String? code;
    try {
      await analyzer.analyze(Uint8List.fromList([1, 2, 3]));
    } on BodyAnalysisFailure catch (error) {
      code = error.code;
    }
    _report(jsonEncode({'empty': poses.isEmpty, 'errorCode': code}).toJS);
  } catch (error) {
    _report(jsonEncode({'failure': error.toString()}).toJS);
  } finally {
    await analyzer.dispose();
  }
}
