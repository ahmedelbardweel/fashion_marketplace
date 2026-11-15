import 'package:fashion_marketplace/features/shop/presentation/widgets/product_size_chart_editor.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/body_measurements.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/size_recommendation.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('seller adds a body range that can recommend an in-stock size', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductSizeChartEditor(
              sizes: const {'M'},
              chart: null,
              onChanged: (value) => saved = value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Product measurement chart'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit measurement chart'));
    await tester.pumpAndSettle();
    for (final entry in {
      'size-range-chest-0': '94',
      'size-range-chest-1': '100',
    }.entries) {
      final input = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(input);
      await tester.enterText(input, entry.value);
    }
    await tester.tap(find.text('Save measurement ranges'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    final match = SizeRecommendation.evaluate(
      measurements: BodyMeasurements(
        values: {
          BodyMeasure.height: 175,
          BodyMeasure.weight: 70,
          BodyMeasure.chest: 97,
        },
      ),
      chart: saved,
      availableSizes: {'M'},
      zone: TryonBodyZone.upperBody,
    );
    expect(match.size, 'M');
    expect(tester.takeException(), isNull);
  });
}
