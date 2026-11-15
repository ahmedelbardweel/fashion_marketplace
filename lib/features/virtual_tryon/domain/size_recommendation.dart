import 'body_measurements.dart';
import 'tryon_session.dart';

class SizeChartRow {
  const SizeChartRow(this.size, this.ranges);
  final String size;
  final Map<BodyMeasure, (double, double)> ranges;
  Map<String, dynamic> toJson() => {
    'size': size,
    for (final entry in ranges.entries)
      entry.key.key: [entry.value.$1, entry.value.$2],
  };
}

/// Rows describe BODY measurement ranges in cm, never flat garment dimensions.
List<SizeChartRow> readSizeChart(dynamic chart) {
  if (chart is! Map ||
      chart['unit'] != 'cm' ||
      chart['measurement_type'] != 'body' ||
      chart['rows'] is! List) {
    return [];
  }
  final result = <SizeChartRow>[];
  for (final raw in chart['rows'] as List) {
    if (raw is! Map ||
        raw['size'] is! String ||
        (raw['size'] as String).trim().isEmpty) {
      continue;
    }
    final ranges = <BodyMeasure, (double, double)>{};
    var valid = true;
    for (final field in BodyMeasure.values.where(
      (f) => f != BodyMeasure.weight,
    )) {
      final range = raw[field.key];
      if (range == null) continue;
      if (range is! List || range.length != 2 || range.any((v) => v is! num)) {
        valid = false;
        break;
      }
      final low = (range[0] as num).toDouble(),
          high = (range[1] as num).toDouble();
      if (!field.accepts(low) || !field.accepts(high) || low > high) {
        valid = false;
        break;
      }
      ranges[field] = (low, high);
    }
    if (valid && ranges.isNotEmpty) {
      result.add(SizeChartRow((raw['size'] as String).trim(), ranges));
    }
  }
  return result;
}

Map<String, dynamic> writeSizeChart(List<SizeChartRow> rows) => {
  'unit': 'cm',
  'measurement_type': 'body',
  'rows': rows.map((r) => r.toJson()).toList(),
};

enum SizeMatchStatus {
  matched,
  noChart,
  missingMeasurements,
  noMatch,
  outOfStock,
}

class SizeRecommendation {
  const SizeRecommendation(this.status, {this.size, this.missing = const {}});
  final SizeMatchStatus status;
  final String? size;
  final Set<BodyMeasure> missing;

  static SizeRecommendation evaluate({
    required BodyMeasurements measurements,
    required dynamic chart,
    required Set<String> availableSizes,
    required TryonBodyZone zone,
  }) {
    final requiredFields = switch (zone) {
      TryonBodyZone.footwear => {BodyMeasure.footLength},
      TryonBodyZone.upperBody => {BodyMeasure.chest},
      TryonBodyZone.lowerPants ||
      TryonBodyZone.lowerShorts => {BodyMeasure.waist, BodyMeasure.hips},
      TryonBodyZone.fullBody => {
        BodyMeasure.chest,
        BodyMeasure.waist,
        BodyMeasure.hips,
      },
    };
    final rows = readSizeChart(
      chart,
    ).where((r) => r.ranges.keys.toSet().containsAll(requiredFields)).toList();
    if (rows.isEmpty) return const SizeRecommendation(SizeMatchStatus.noChart);
    final candidates = <(SizeChartRow, double)>[];
    final missing = <BodyMeasure>{};
    var incompleteCouldFit = false;
    for (final row in rows) {
      var score = 0.0;
      var mismatch = false;
      final absent = <BodyMeasure>{};
      for (final entry in row.ranges.entries) {
        final value = measurements[entry.key];
        if (value == null) {
          absent.add(entry.key);
          continue;
        }
        final (low, high) = entry.value;
        if (value < low || value > high) mismatch = true;
        score +=
            (value - (low + high) / 2).abs() /
            (high - low == 0 ? 1 : high - low);
      }
      if (!mismatch && absent.isNotEmpty) {
        incompleteCouldFit = true;
        missing.addAll(absent);
      }
      if (!mismatch && absent.isEmpty) {
        candidates.add((row, score / row.ranges.length));
      }
    }
    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    final available = candidates
        .where((c) => availableSizes.contains(c.$1.size))
        .firstOrNull;
    if (available != null) {
      return SizeRecommendation(
        SizeMatchStatus.matched,
        size: available.$1.size,
      );
    }
    if (candidates.isNotEmpty) {
      return const SizeRecommendation(SizeMatchStatus.outOfStock);
    }
    if (incompleteCouldFit) {
      return SizeRecommendation(
        SizeMatchStatus.missingMeasurements,
        missing: missing,
      );
    }
    return const SizeRecommendation(SizeMatchStatus.noMatch);
  }
}
