import 'dart:convert';
import 'package:fashion_marketplace/features/virtual_tryon/data/body_measurement_store.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/body_measurements.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/size_recommendation.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  BodyMeasurements profile({
    double height = 175,
    double weight = 70,
    Map<BodyMeasure, double> extra = const {},
  }) => BodyMeasurements(
    values: {BodyMeasure.height: height, BodyMeasure.weight: weight, ...extra},
    shoeSize: 42,
  );

  test('parses Arabic and Persian digits, rejects nonfinite input', () {
    expect(parseMeasurement('١٧٥٫٥'), 175.5);
    expect(parseMeasurement('۷۰,۵'), 70.5);
    expect(parseMeasurement('NaN'), isNull);
    expect(parseMeasurement('Infinity'), isNull);
    expect(parseMeasurement('30 cm'), isNull);
  });

  test('saved profile survives reopening and is isolated by account', () async {
    final first = BodyMeasurementStore('user-one');
    await first.save(
      profile(extra: {BodyMeasure.footLength: 30, BodyMeasure.waist: 92}),
    );
    final restored = await BodyMeasurementStore('user-one').load();
    expect(restored![BodyMeasure.footLength], 30);
    expect(restored.shoeSize, isNull);
    expect(restored[BodyMeasure.waist], isNull);
    expect(
      restored.values.keys.toSet(),
      BodyMeasurements.customerFields.toSet(),
    );
    expect(await BodyMeasurementStore('user-two').load(), isNull);
    await first.clear();
    expect(await first.load(), isNull);
  });

  test('invalid values cannot overwrite a valid saved profile', () async {
    final store = BodyMeasurementStore('test');
    await store.save(profile());
    await expectLater(store.save(profile(height: -1)), throwsFormatException);
    expect((await store.load())![BodyMeasure.height], 175);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(store.storageKey, '{bad json');
    expect(await store.load(), isNull);
    await prefs.setString(store.storageKey, jsonEncode({'version': 2}));
    expect(await store.load(), isNull);
  });

  test('short heavy figure becomes shorter and wider with finite bounds', () {
    final regular = BodyProportions(profile());
    final shortHeavy = BodyProportions(
      profile(height: 60, weight: 150, extra: {BodyMeasure.footLength: 30}),
    );
    expect(shortHeavy.heightScale, lessThan(regular.heightScale));
    expect(shortHeavy.widthAt(235), greaterThan(regular.widthAt(235)));
    expect(shortHeavy.footScale, greaterThan(regular.footScale));
    for (var y = 0.0; y <= 550; y += 5) {
      expect(shortHeavy.widthAt(y).isFinite, isTrue);
      expect(shortHeavy.widthAt(y), inInclusiveRange(.65, 2.8));
    }
    final measured = BodyProportions(profile(extra: {BodyMeasure.waist: 120}));
    expect(measured.widthAt(235), greaterThan(regular.widthAt(235)));
  });

  final chart = writeSizeChart([
    const SizeChartRow('M', {
      BodyMeasure.chest: (94, 100),
      BodyMeasure.waist: (78, 86),
    }),
    const SizeChartRow('L', {
      BodyMeasure.chest: (100, 108),
      BodyMeasure.waist: (86, 96),
    }),
  ]);
  SizeRecommendation match(
    BodyMeasurements value, {
    Set<String> sizes = const {'M', 'L'},
    dynamic customChart,
    TryonBodyZone zone = TryonBodyZone.upperBody,
  }) => SizeRecommendation.evaluate(
    measurements: value,
    chart: customChart ?? chart,
    availableSizes: sizes,
    zone: zone,
  );

  test('matches all supplied chart ranges and only stocked sizes', () {
    final value = profile(
      extra: {BodyMeasure.chest: 103, BodyMeasure.waist: 90},
    );
    expect(match(value).size, 'L');
    expect(match(value, sizes: {'M'}).status, SizeMatchStatus.outOfStock);
    expect(
      match(
        profile(extra: {BodyMeasure.chest: 103, BodyMeasure.waist: 130}),
      ).status,
      SizeMatchStatus.noMatch,
    );
  });

  test('does not invent a size from height and weight or partial inputs', () {
    expect(match(profile()).status, SizeMatchStatus.missingMeasurements);
    expect(match(profile(extra: {BodyMeasure.chest: 103})).missing, {
      BodyMeasure.waist,
    });
    expect(match(profile(), customChart: {}).status, SizeMatchStatus.noChart);
    expect(
      match(
        profile(),
        customChart: {
          'unit': 'inch',
          'measurement_type': 'body',
          'rows': chart['rows'],
        },
      ).status,
      SizeMatchStatus.noChart,
    );
    expect(
      match(
        profile(),
        customChart: {
          'unit': 'cm',
          'measurement_type': 'garment',
          'rows': chart['rows'],
        },
      ).status,
      SizeMatchStatus.noChart,
    );
    expect(
      match(
        profile(),
        customChart: writeSizeChart([
          const SizeChartRow('M', {BodyMeasure.height: (160, 190)}),
        ]),
      ).status,
      SizeMatchStatus.noChart,
    );
  });

  test('footwear uses brand foot-length chart, not a guessed conversion', () {
    final shoes = writeSizeChart([
      const SizeChartRow('EU 46', {BodyMeasure.footLength: (29.5, 30.2)}),
    ]);
    expect(
      match(
        profile(extra: {BodyMeasure.footLength: 30}),
        sizes: {'EU 46'},
        customChart: shoes,
        zone: TryonBodyZone.footwear,
      ).size,
      'EU 46',
    );
    expect(
      match(
        profile(),
        sizes: {'EU 46'},
        customChart: shoes,
        zone: TryonBodyZone.footwear,
      ).status,
      SizeMatchStatus.missingMeasurements,
    );
  });
}
