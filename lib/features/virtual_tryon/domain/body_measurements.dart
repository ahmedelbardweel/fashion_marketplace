import 'dart:math' as math;

/// User-entered measurements, never measurements inferred from the camera.
enum BodyMeasure {
  height('height', 'الطول', 'Height', 50, 250),
  weight('weight', 'الوزن', 'Weight', 5, 350),
  footLength('foot_length', 'طول القدم', 'Foot length', 8, 40),
  footWidth('foot_width', 'عرض القدم', 'Foot width', 3, 20),
  chest('chest', 'محيط الصدر', 'Chest circumference', 40, 220),
  waist('waist', 'محيط الخصر', 'Waist circumference', 30, 240),
  hips('hips', 'محيط الورك', 'Hip circumference', 40, 240),
  shoulders('shoulders', 'عرض الكتفين', 'Shoulder width', 15, 80),
  inseam('inseam', 'طول الساق الداخلي', 'Inside leg length', 15, 130),
  sleeve('sleeve', 'طول الذراع', 'Arm length', 15, 100),
  neck('neck', 'محيط الرقبة', 'Neck circumference', 15, 80),
  thigh('thigh', 'محيط الفخذ', 'Thigh circumference', 15, 140),
  calf('calf', 'محيط الساق', 'Calf circumference', 10, 90);

  const BodyMeasure(this.key, this.ar, this.en, this.min, this.max);
  final String key, ar, en;
  final double min, max;
  bool accepts(double value) => value.isFinite && value >= min && value <= max;
}

enum ShoeSizeSystem {
  eu('EU', 15, 55),
  uk('UK', 1, 20),
  usMen('US Men', 1, 22),
  usWomen('US Women', 1, 22);

  const ShoeSizeSystem(this.label, this.min, this.max);
  final String label;
  final double min, max;
}

double? parseMeasurement(String input) {
  var normalized = input.trim().replaceAll('٫', '.').replaceAll(',', '.');
  for (var i = 0; i < 10; i++) {
    normalized = normalized
        .replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i')
        .replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
  }
  final value = double.tryParse(normalized);
  return value != null && value.isFinite ? value : null;
}

String measurementNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

class BodyMeasurements {
  static const customerFields = [
    BodyMeasure.height,
    BodyMeasure.weight,
    BodyMeasure.footLength,
  ];

  /// Restrict customer profiles to the three measurements collected by the UI.
  BodyMeasurements get customerOnly => BodyMeasurements(
    values: {
      for (final field in customerFields)
        if (values[field] case final value?) field: value,
    },
  );

  BodyMeasurements({
    Map<BodyMeasure, double> values = const {},
    this.shoeSize,
    this.shoeSystem = ShoeSizeSystem.eu,
  }) : values = Map.unmodifiable(values);
  final Map<BodyMeasure, double> values;
  final double? shoeSize;
  final ShoeSizeSystem shoeSystem;
  double? operator [](BodyMeasure field) => values[field];
  bool get hasBasics =>
      this[BodyMeasure.height] != null && this[BodyMeasure.weight] != null;
  bool get isValid =>
      hasBasics &&
      values.entries.every((e) => e.key.accepts(e.value)) &&
      (shoeSize == null ||
          (shoeSize!.isFinite &&
              shoeSize! >= shoeSystem.min &&
              shoeSize! <= shoeSystem.max));

  Map<String, dynamic> toJson() => {
    'version': 1,
    'measurements': {for (final e in values.entries) e.key.key: e.value},
    'shoe_size': shoeSize,
    'shoe_system': shoeSystem.name,
  };

  static BodyMeasurements? fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['measurements'] is! Map) return null;
    final raw = json['measurements'] as Map;
    final values = <BodyMeasure, double>{};
    for (final field in BodyMeasure.values) {
      final value = raw[field.key];
      if (value != null) {
        if (value is! num || !field.accepts(value.toDouble())) return null;
        values[field] = value.toDouble();
      }
    }
    final system = ShoeSizeSystem.values
        .where((s) => s.name == json['shoe_system'])
        .firstOrNull;
    final shoe = json['shoe_size'];
    if (system == null || (shoe != null && shoe is! num)) return null;
    final result = BodyMeasurements(
      values: values,
      shoeSize: (shoe as num?)?.toDouble(),
      shoeSystem: system,
    );
    return result.isValid ? result : null;
  }
}

/// Bounded illustration proportions, not an anatomical or size prediction model.
/// Explicit tape measurements take precedence over weight-based visual estimates.
class BodyProportions {
  BodyProportions(this.measurements);
  final BodyMeasurements? measurements;
  double get heightRatio => (measurements?[BodyMeasure.height] ?? 175) / 175;
  // Compress extreme height differences to keep the illustration legible.
  double get heightScale =>
      math.pow(heightRatio, .65).toDouble().clamp(.65, 1.25);
  double get _girth =>
      math.sqrt((measurements?[BodyMeasure.weight] ?? 70) / 70 / heightRatio);
  double _width(
    BodyMeasure field,
    double reference, {
    double power = 1,
    double maximum = 2.1,
  }) =>
      ((measurements?[field] != null
                  ? measurements![field]! / reference
                  : math.pow(_girth, power).toDouble()) /
              math.sqrt(heightRatio))
          .clamp(.65, maximum);

  double widthAt(double y) {
    if (measurements == null) return 1;
    final anchors = <(double, double)>[
      (80, heightScale),
      (
        105,
        ((measurements?[BodyMeasure.shoulders] ?? 40 * math.pow(_girth, .35)) /
                40 /
                math.sqrt(heightRatio))
            .clamp(.7, 1.9),
      ),
      (165, _width(BodyMeasure.chest, 98)),
      (235, _width(BodyMeasure.waist, 84, power: 1.5, maximum: 2.4)),
      (275, _width(BodyMeasure.hips, 100)),
      (320, _width(BodyMeasure.thigh, 56)),
      (410, _width(BodyMeasure.calf, 37)),
      (492, math.pow(_width(BodyMeasure.hips, 100), .55).toDouble()),
    ];
    if (y <= anchors.first.$1) return anchors.first.$2;
    for (var i = 1; i < anchors.length; i++) {
      final a = anchors[i - 1], b = anchors[i];
      if (y <= b.$1) {
        final t = (y - a.$1) / (b.$1 - a.$1);
        final smooth = t * t * (3 - 2 * t);
        return a.$2 + (b.$2 - a.$2) * smooth;
      }
    }
    return anchors.last.$2;
  }

  double get footScale {
    final length = measurements?[BodyMeasure.footLength];
    // Shoe numbers remain in their own system; they are never treated as cm.
    final rawShoe = measurements?.shoeSize;
    final shoe = rawShoe != null && rawShoe > 0 && rawShoe.isFinite
        ? rawShoe
        : null;
    final shoeReference = switch (measurements?.shoeSystem) {
      ShoeSizeSystem.eu => 42.0,
      ShoeSizeSystem.uk => 8.0,
      ShoeSizeSystem.usMen => 9.0,
      ShoeSizeSystem.usWomen => 10.0,
      null => 42.0,
    };
    return (length != null
            ? length / 26
            : shoe != null
            ? math.pow(shoe / shoeReference, .5).toDouble()
            : 1.0)
        .clamp(.65, 1.55);
  }
}
