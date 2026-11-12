import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/body_analysis_failure.dart';

void main() {
  test('unknown errors never leak engine details or URLs into the UI', () {
    final failure = BodyAnalysisFailure.fromBrowser(
      Exception('https://example.com/private?token=secret'),
    );
    expect(failure.message, isNot(contains('secret')));
    expect(failure.message, isNot(contains('https')));
  });
  test(
    'old pages get a refresh instruction rather than a camera diagnosis',
    () {
      final failure = BodyAnalysisFailure.fromBrowser(
        Exception('ReferenceError: fashionBodyAnalyze is not defined'),
      );
      expect(failure.code, 'bridge_missing');
      expect(failure.message, contains('حدّث الصفحة'));
    },
  );
}
