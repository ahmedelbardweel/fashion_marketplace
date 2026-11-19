import 'dart:math' as math;

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

/// Clothing & shoe size estimated directly from user weight, height, and foot length.
class EstimatedBodySize {
  const EstimatedBodySize({
    required this.primary,
    this.alternative,
    this.shoeEu,
    this.matchedStockSize,
  });

  final String primary;
  final String? alternative;
  final int? shoeEu;
  final String? matchedStockSize;

  String get clothingLabel =>
      alternative == null ? primary : '$primary / $alternative';
}

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
      TryonBodyZone.headFace ||
      TryonBodyZone.wristHand ||
      TryonBodyZone.bags => <BodyMeasure>{},
      TryonBodyZone.upperBody => {BodyMeasure.chest},
      TryonBodyZone.lowerPants ||
      TryonBodyZone.lowerShorts => {BodyMeasure.waist, BodyMeasure.hips},
      TryonBodyZone.fullBody => {
        BodyMeasure.chest,
        BodyMeasure.waist,
        BodyMeasure.hips,
      },
    };
    if (requiredFields.isEmpty) {
      return const SizeRecommendation(SizeMatchStatus.noChart);
    }
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

  /// Converts measured foot length (cm) into standard EU shoe sizing.
  static int estimateShoeSizeEu(double footLengthCm) =>
      ((footLengthCm + 1.5) * 1.5).round().clamp(34, 50);

  /// Estimates clothing (XS..4XL) and EU shoe sizes directly from body
  /// height, weight, and foot length without requiring a seller size chart.
  static EstimatedBodySize? estimateFromBody(
    BodyMeasurements measurements, {
    TryonBodyZone zone = TryonBodyZone.upperBody,
    Set<String> availableSizes = const {},
  }) {
    final height = measurements[BodyMeasure.height];
    final weight = measurements[BodyMeasure.weight];
    if (height == null || weight == null || !measurements.hasBasics) {
      return null;
    }

    final foot = measurements[BodyMeasure.footLength];
    final shoeEu = foot != null ? estimateShoeSizeEu(foot) : null;

    // Height-adjusted weight with comfort allowance reflecting typical regional cuts.
    final heightAdj = math.max(-4.0, (175.0 - height) * 0.25);
    final lengthBoost = height >= 184 ? 3.0 : (height >= 178 ? 1.5 : 0.0);
    final score = weight + heightAdj + lengthBoost;

    late final String primary;
    String? alternative;

    if (score < 52) {
      primary = 'XS';
      if (score >= 49) alternative = 'S';
    } else if (score < 60) {
      primary = 'S';
      if (score >= 57) alternative = 'M';
    } else if (score < 68) {
      primary = 'M';
      if (score >= 65) alternative = 'L';
    } else if (score < 77) {
      primary = 'L';
      if (score >= 74) alternative = 'XL';
    } else if (score < 83) {
      primary = 'XL';
      if (score >= 80) alternative = 'XXL';
    } else if (score < 95) {
      primary = 'XXL';
      if (score >= 83) alternative = 'XXXL';
    } else if (score < 110) {
      primary = 'XXXL';
      if (score >= 104) alternative = '4XL';
    } else {
      primary = '4XL';
    }

    String? matchedStock;
    if (availableSizes.isNotEmpty) {
      if (zone == TryonBodyZone.footwear && shoeEu != null) {
        final euStr = '$shoeEu';
        for (final s in availableSizes) {
          if (s.contains(euStr)) {
            matchedStock = s;
            break;
          }
        }
      } else {
        matchedStock = _matchStockSize(
          primary: primary,
          alternative: alternative,
          availableSizes: availableSizes,
        );
      }
    }

    return EstimatedBodySize(
      primary: primary,
      alternative: alternative,
      shoeEu: shoeEu,
      matchedStockSize: matchedStock,
    );
  }

  static String? _matchStockSize({
    required String primary,
    String? alternative,
    required Set<String> availableSizes,
  }) {
    String norm(String s) {
      var u = s.trim().toUpperCase().replaceAll(' ', '');
      if (u == '2XL') u = 'XXL';
      if (u == '3XL') u = 'XXXL';
      if (u == '4XL') u = 'XXXXL';
      return u;
    }

    final candidates = [norm(primary), if (alternative != null) norm(alternative)];
    for (final want in candidates) {
      for (final raw in availableSizes) {
        if (norm(raw) == want) return raw;
      }
    }
    return null;
  }
}
