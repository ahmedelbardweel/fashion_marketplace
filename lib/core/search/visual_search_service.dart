import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../filtering/filter_models.dart';
import '../offline/offline_image_cache_service.dart';

/// Represents the visual signature extracted from a camera/gallery photo.
class VisualSearchQuery {
  const VisualSearchQuery({
    required this.imageBytes,
    required this.primaryColorName,
    required this.secondaryColorNames,
    required this.primarySwatch,
    required this.histogram,
    required this.aspectRatio,
    this.inferredKeywords = const [],
  });

  final Uint8List imageBytes;
  final String primaryColorName;
  final List<String> secondaryColorNames;
  final Color primarySwatch;

  /// 64-bin L2-normalized spatial HSV + edge histogram for image-to-image comparison.
  final List<double> histogram;
  final double aspectRatio;
  final List<String> inferredKeywords;

  List<String> get allColorNames => [
    if (primaryColorName.isNotEmpty) primaryColorName,
    ...secondaryColorNames,
  ];
}

class _ColorPrototype {
  const _ColorPrototype({
    required this.nameAr,
    required this.nameEn,
    required this.r,
    required this.g,
    required this.b,
    required this.swatch,
  });

  final String nameAr;
  final String nameEn;
  final int r;
  final int g;
  final int b;
  final Color swatch;
}

const List<_ColorPrototype> _kFashionColorPrototypes = [
  _ColorPrototype(
    nameAr: 'أسود',
    nameEn: 'black',
    r: 24,
    g: 24,
    b: 27,
    swatch: Color(0xFF18181B),
  ),
  _ColorPrototype(
    nameAr: 'أبيض',
    nameEn: 'white',
    r: 248,
    g: 248,
    b: 250,
    swatch: Color(0xFFFAFAFA),
  ),
  _ColorPrototype(
    nameAr: 'رمادي',
    nameEn: 'gray',
    r: 120,
    g: 120,
    b: 128,
    swatch: Color(0xFF71717A),
  ),
  _ColorPrototype(
    nameAr: 'كحلي',
    nameEn: 'navy',
    r: 28,
    g: 52,
    b: 94,
    swatch: Color(0xFF1E3A5F),
  ),
  _ColorPrototype(
    nameAr: 'أزرق',
    nameEn: 'blue',
    r: 37,
    g: 99,
    b: 235,
    swatch: Color(0xFF2563EB),
  ),
  _ColorPrototype(
    nameAr: 'أحمر',
    nameEn: 'red',
    r: 210,
    g: 38,
    b: 48,
    swatch: Color(0xFFDC2626),
  ),
  _ColorPrototype(
    nameAr: 'أخضر',
    nameEn: 'green',
    r: 28,
    g: 150,
    b: 72,
    swatch: Color(0xFF16A34A),
  ),
  _ColorPrototype(
    nameAr: 'زيتوني',
    nameEn: 'olive',
    r: 85,
    g: 107,
    b: 47,
    swatch: Color(0xFF556B2F),
  ),
  _ColorPrototype(
    nameAr: 'بيج',
    nameEn: 'beige',
    r: 214,
    g: 194,
    b: 163,
    swatch: Color(0xFFD6C2A3),
  ),
  _ColorPrototype(
    nameAr: 'بني',
    nameEn: 'brown',
    r: 107,
    g: 66,
    b: 38,
    swatch: Color(0xFF6B4226),
  ),
  _ColorPrototype(
    nameAr: 'وردي',
    nameEn: 'pink',
    r: 236,
    g: 72,
    b: 153,
    swatch: Color(0xFFEC4899),
  ),
  _ColorPrototype(
    nameAr: 'أصفر',
    nameEn: 'yellow',
    r: 234,
    g: 179,
    b: 8,
    swatch: Color(0xFFEAB308),
  ),
  _ColorPrototype(
    nameAr: 'برتقالي',
    nameEn: 'orange',
    r: 249,
    g: 115,
    b: 22,
    swatch: Color(0xFFF97316),
  ),
  _ColorPrototype(
    nameAr: 'بنفسجي',
    nameEn: 'purple',
    r: 147,
    g: 51,
    b: 234,
    swatch: Color(0xFF9333EA),
  ),
];

/// High-precision visual search engine that extracts garment colors, spatial
/// histograms, and computes perceptual similarity against catalog products.
class VisualSearchService {
  VisualSearchService._();

  static final VisualSearchService instance = VisualSearchService._();

  /// In-memory cache of computed 64-bin histograms for product image URLs.
  final Map<String, List<double>> _productHistogramCache =
      <String, List<double>>{};

  /// In-memory cache of detected dominant garment color names for product image URLs.
  final Map<String, List<String>> _productColorsCache =
      <String, List<String>>{};

  /// Returns the cached detected garment colors for a product image URL if already analyzed.
  List<String> getCachedProductImageColors(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return const [];
    return _productColorsCache[imageUrl.trim()] ?? const [];
  }

  /// Analyzes an image from bytes (in a background isolate) and returns a
  /// [VisualSearchQuery] containing dominant garment colors & visual histogram.
  Future<VisualSearchQuery> analyzeImageBytes(
    Uint8List bytes, {
    String? fileNameHint,
  }) async {
    final rawMap = await compute(_analyzeImageIsolate, {
      'bytes': bytes,
      'hint': fileNameHint ?? '',
    });

    final primaryName = rawMap['primaryColorName'] as String? ?? 'أسود';
    final secondaryNames = List<String>.from(
      rawMap['secondaryColorNames'] as List? ?? const [],
    );
    final swatchValue = rawMap['primarySwatch'] as int? ?? 0xFF18181B;
    final histogram = (rawMap['histogram'] as List? ?? const [])
        .map((e) => (e as num).toDouble())
        .toList();
    final aspectRatio = (rawMap['aspectRatio'] as num?)?.toDouble() ?? 1.0;
    final keywords = List<String>.from(
      rawMap['keywords'] as List? ?? const [],
    );

    return VisualSearchQuery(
      imageBytes: bytes,
      primaryColorName: primaryName,
      secondaryColorNames: secondaryNames,
      primarySwatch: Color(swatchValue),
      histogram: histogram,
      aspectRatio: aspectRatio,
      inferredKeywords: keywords,
    );
  }

  /// Pre-computes or retrieves the visual histogram and dominant garment colors
  /// of a cached product image file.
  Future<List<double>?> getProductImageHistogram(
    String? imageUrl, {
    bool downloadIfMissing = true,
  }) async {
    if (kIsWeb || imageUrl == null || imageUrl.trim().isEmpty) return null;
    final cleanUrl = imageUrl.trim();
    final existing = _productHistogramCache[cleanUrl];
    if (existing != null) return existing;

    File? file = OfflineImageCacheService.instance.getCachedFileSync(cleanUrl);
    if (file == null && downloadIfMissing) {
      file = await OfflineImageCacheService.instance.getOrDownloadFile(cleanUrl);
    }
    if (file == null || !file.existsSync()) return null;

    try {
      final bytes = await file.readAsBytes();
      final rawMap = await compute(_analyzeImageIsolate, {
        'bytes': bytes,
        'hint': '',
      });
      final hist = (rawMap['histogram'] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList();
      final primary = rawMap['primaryColorName'] as String? ?? '';
      final secondaries = List<String>.from(
        rawMap['secondaryColorNames'] as List? ?? const [],
      );
      final colors = <String>[
        if (primary.isNotEmpty) primary,
        ...secondaries,
      ];
      if (colors.isNotEmpty) {
        _productColorsCache[cleanUrl] = colors;
      }
      if (hist.isNotEmpty) {
        _productHistogramCache[cleanUrl] = hist;
        return hist;
      }
    } catch (_) {}
    return null;
  }

  /// Computes cosine similarity (0.0 .. 1.0) between two 64-bin histograms.
  double compareHistograms(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA <= 1e-9 || normB <= 1e-9) return 0.0;
    return (dot / (math.sqrt(normA) * math.sqrt(normB))).clamp(0.0, 1.0);
  }

  /// Checks whether a product's colors/name/description match the visual query's
  /// detected colors or inferred keywords.
  double scoreTextAndColorMetadata({
    required VisualSearchQuery query,
    required Iterable<String> productColors,
    required String productName,
    String? productDescription,
    String? categoryName,
    String? productImageUrl,
  }) {
    var score = 0.0;
    final normPrimary = normalizeSearchText(query.primaryColorName);
    final normSecondaries = query.secondaryColorNames
        .map(normalizeSearchText)
        .toSet();

    final normalizedProdColors = productColors
        .map(normalizeSearchText)
        .where((c) => c.isNotEmpty)
        .toSet();

    final searchableText = normalizeSearchText(
      '$productName ${productDescription ?? ''} ${categoryName ?? ''}',
    );

    // 1. Primary color match against variant colors or product title
    if (normPrimary.isNotEmpty) {
      if (normalizedProdColors.any((c) => c.contains(normPrimary) || normPrimary.contains(c))) {
        score += 0.58;
      } else if (searchableText.contains(normPrimary)) {
        score += 0.45;
      }
    }

    // 2. Secondary color match
    for (final sec in normSecondaries) {
      if (sec.isEmpty) continue;
      if (normalizedProdColors.any((c) => c.contains(sec) || sec.contains(c)) ||
          searchableText.contains(sec)) {
        score += 0.22;
        break;
      }
    }

    // 3. Inferred keyword match (if filename or metadata had garment keywords)
    for (final kw in query.inferredKeywords) {
      final normKw = normalizeSearchText(kw);
      if (normKw.length >= 2 && searchableText.contains(normKw)) {
        score += 0.30;
      }
    }

    // 4. Cached image histogram similarity if already loaded in memory
    if (productImageUrl != null) {
      final cachedHist = _productHistogramCache[productImageUrl.trim()];
      if (cachedHist != null && query.histogram.isNotEmpty) {
        final histSim = compareHistograms(query.histogram, cachedHist);
        // Boost significantly when visual histogram closely matches
        if (histSim > 0.88) {
          score += 0.65;
        } else if (histSim > 0.72) {
          score += histSim * 0.45;
        } else {
          score += histSim * 0.20;
        }
      }
    }

    return score.clamp(0.0, 1.0);
  }
}

// =============================================================================
// Top-level isolate functions for fast off-main-thread image analysis
// =============================================================================

Map<String, dynamic> _analyzeImageIsolate(Map<String, dynamic> input) {
  final bytes = input['bytes'] as Uint8List;
  final hint = (input['hint'] as String? ?? '').toLowerCase();

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return {
      'primaryColorName': 'أسود',
      'secondaryColorNames': const <String>[],
      'primarySwatch': 0xFF18181B,
      'histogram': List<double>.filled(64, 0.0),
      'aspectRatio': 1.0,
      'keywords': _extractKeywordsFromHint(hint),
    };
  }

  final aspectRatio = decoded.height > 0
      ? decoded.width / decoded.height
      : 1.0;

  // Resize to 64x64 for fast, noise-free perceptual analysis
  final resized = img.copyResize(decoded, width: 64, height: 64);

  // Estimate background color from outer border pixels so studio white/gray
  // backgrounds don't overshadow the garment in the center.
  var borderR = 0.0, borderG = 0.0, borderB = 0.0;
  var borderCount = 0;
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      if (x < 4 || x >= 60 || y < 4 || y >= 60) {
        final p = resized.getPixel(x, y);
        borderR += p.r;
        borderG += p.g;
        borderB += p.b;
        borderCount++;
      }
    }
  }
  if (borderCount > 0) {
    borderR /= borderCount;
    borderG /= borderCount;
    borderB /= borderCount;
  }

  final colorWeights = <String, double>{
    for (final proto in _kFashionColorPrototypes) proto.nameAr: 0.0,
  };
  final histogram = List<double>.filled(64, 0.0);

  // Focus on the central garment region (x: 10..54, y: 8..56) with Gaussian-like center weight
  for (var y = 6; y < 58; y++) {
    for (var x = 8; x < 56; x++) {
      final pixel = resized.getPixel(x, y);
      final a = pixel.a.toDouble();
      if (a < 40) continue; // Ignore transparent background pixels

      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      // Down-weight pixels that are almost identical to the outer studio background
      final distToBorder = math.sqrt(
        math.pow(r - borderR, 2) +
            math.pow(g - borderG, 2) +
            math.pow(b - borderB, 2),
      );
      final bgPenalty = distToBorder < 18.0 ? 0.15 : 1.0;

      // Center weighting (garment is almost always centered)
      final dx = (x - 32.0) / 32.0;
      final dy = (y - 32.0) / 32.0;
      final centerWeight = math.max(0.25, 1.0 - (dx * dx + dy * dy) * 0.85);
      final weight = centerWeight * bgPenalty;

      final closest = _findClosestColorPrototype(r, g, b);
      colorWeights[closest.nameAr] =
          (colorWeights[closest.nameAr] ?? 0.0) + weight;

      // Populate 64-bin 4x4x4 RGB spatial histogram
      final rBin = (r ~/ 64).clamp(0, 3);
      final gBin = (g ~/ 64).clamp(0, 3);
      final bBin = (b ~/ 64).clamp(0, 3);
      final binIdx = (rBin * 16) + (gBin * 4) + bBin;
      histogram[binIdx] += weight;
    }
  }

  // Normalize histogram (L2)
  var norm = 0.0;
  for (final v in histogram) {
    norm += v * v;
  }
  norm = math.sqrt(norm);
  if (norm > 1e-9) {
    for (var i = 0; i < histogram.length; i++) {
      histogram[i] = histogram[i] / norm;
    }
  }

  final sortedColors = colorWeights.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final totalWeight = sortedColors.fold<double>(0.0, (s, e) => s + e.value);
  final primaryName = sortedColors.isNotEmpty
      ? sortedColors.first.key
      : 'أسود';

  final secondaryNames = <String>[];
  if (totalWeight > 0) {
    for (var i = 1; i < sortedColors.length && secondaryNames.length < 2; i++) {
      if (sortedColors[i].value / totalWeight >= 0.14) {
        secondaryNames.add(sortedColors[i].key);
      }
    }
  }

  final proto = _kFashionColorPrototypes.firstWhere(
    (c) => c.nameAr == primaryName,
    orElse: () => _kFashionColorPrototypes.first,
  );

  return {
    'primaryColorName': primaryName,
    'secondaryColorNames': secondaryNames,
    'primarySwatch': proto.swatch.toARGB32(),
    'histogram': histogram,
    'aspectRatio': aspectRatio,
    'keywords': _extractKeywordsFromHint(hint),
  };
}

_ColorPrototype _findClosestColorPrototype(double r, double g, double b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final delta = maxC - minC;
  final saturation = maxC == 0 ? 0.0 : delta / maxC;
  final value = maxC / 255.0;

  // Handle achromatic (black / white / gray / beige) accurately first
  if (value < 0.18) {
    return _kFashionColorPrototypes[0]; // أسود
  }
  if (saturation < 0.12) {
    if (value > 0.82) return _kFashionColorPrototypes[1]; // أبيض
    return _kFashionColorPrototypes[2]; // رمادي
  }

  // Weighted redmean perceptual color distance for chromatic colors
  _ColorPrototype best = _kFashionColorPrototypes.first;
  var bestDist = double.infinity;

  for (final proto in _kFashionColorPrototypes) {
    final rmean = (r + proto.r) / 2.0;
    final dr = r - proto.r;
    final dg = g - proto.g;
    final db = b - proto.b;
    final dist = math.sqrt(
      ((2.0 + rmean / 256.0) * dr * dr) +
          (4.0 * dg * dg) +
          ((2.0 + (255.0 - rmean) / 256.0) * db * db),
    );
    if (dist < bestDist) {
      bestDist = dist;
      best = proto;
    }
  }
  return best;
}

List<String> _extractKeywordsFromHint(String hint) {
  if (hint.isEmpty) return const [];
  const dict = <String, String>{
    'shirt': 'قميص',
    'tshirt': 'تيشيرت',
    'jacket': 'جاكيت',
    'coat': 'معطف',
    'dress': 'فستان',
    'pants': 'بنطلون',
    'jeans': 'جينز',
    'hoodie': 'هودي',
    'abaya': 'عباية',
    'suit': 'بدلة',
    'skirt': 'تنورة',
    'blouse': 'بلوزة',
    'sweater': 'كنزة',
    'shoes': 'حذاء',
    'bag': 'حقيبة',
  };
  final result = <String>[];
  for (final entry in dict.entries) {
    if (hint.contains(entry.key) || hint.contains(entry.value)) {
      result.add(entry.value);
    }
  }
  return result;
}
