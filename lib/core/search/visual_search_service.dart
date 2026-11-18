import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../offline/offline_image_cache_service.dart';
import 'text_search_engine.dart';

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
    this.shapeSignature = const [],
    this.edgeHistogram = const [],
    this.edgeDensity = 0.0,
    this.objectAspect = 1.0,
    this.spatialColors = const [],
  });

  final Uint8List imageBytes;
  final String primaryColorName;
  final List<String> secondaryColorNames;
  final Color primarySwatch;

  /// 64-bin L2-normalized HSV color histogram of the foreground garment.
  final List<double> histogram;
  final double aspectRatio;
  final List<String> inferredKeywords;

  /// 8x8 silhouette (foreground occupancy inside the garment bounding box).
  final List<double> shapeSignature;

  /// 8-bin L1-normalized gradient orientation histogram (texture/pattern).
  final List<double> edgeHistogram;

  /// Mean gradient magnitude inside the garment (plain vs. patterned).
  final double edgeDensity;

  /// Width / height of the detected garment bounding box.
  final double objectAspect;

  /// 3x3 spatial color layout (27 normalized RGB values across garment zones).
  final List<double> spatialColors;

  List<String> get allColorNames => [
    if (primaryColorName.isNotEmpty) primaryColorName,
    ...secondaryColorNames,
  ];

  _ImageFeatures get _features => _ImageFeatures(
    colorHistogram: histogram,
    shape: shapeSignature,
    edges: edgeHistogram,
    edgeDensity: edgeDensity,
    objectAspect: objectAspect,
    colors: allColorNames,
    spatialColors: spatialColors,
  );
}

/// Cached visual descriptors of a catalog product image.
class _ImageFeatures {
  const _ImageFeatures({
    required this.colorHistogram,
    required this.shape,
    required this.edges,
    required this.edgeDensity,
    required this.objectAspect,
    required this.colors,
    required this.spatialColors,
  });

  factory _ImageFeatures.fromMap(Map<String, dynamic> m) {
    List<double> doubles(String key) => (m[key] as List? ?? const [])
        .map((e) => (e as num).toDouble())
        .toList(growable: false);
    final primary = m['primaryColorName'] as String? ?? '';
    return _ImageFeatures(
      colorHistogram: doubles('histogram'),
      shape: doubles('shape'),
      edges: doubles('edges'),
      edgeDensity: (m['edgeDensity'] as num?)?.toDouble() ?? 0.0,
      objectAspect: (m['objectAspect'] as num?)?.toDouble() ?? 1.0,
      colors: [
        if (primary.isNotEmpty) primary,
        ...List<String>.from(m['secondaryColorNames'] as List? ?? const []),
      ],
      spatialColors: doubles('spatialColors'),
    );
  }

  final List<double> colorHistogram;
  final List<double> shape;
  final List<double> edges;
  final double edgeDensity;
  final double objectAspect;
  final List<String> colors;
  final List<double> spatialColors;
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

/// NOTE: indices 0..2 (black, white, gray) are referenced directly.
const List<_ColorPrototype> _kFashionColorPrototypes = [
  _ColorPrototype(nameAr: 'أسود', nameEn: 'black', r: 24, g: 24, b: 27, swatch: Color(0xFF18181B)),
  _ColorPrototype(nameAr: 'أبيض', nameEn: 'white', r: 248, g: 248, b: 250, swatch: Color(0xFFFAFAFA)),
  _ColorPrototype(nameAr: 'رمادي', nameEn: 'gray', r: 120, g: 120, b: 128, swatch: Color(0xFF71717A)),
  _ColorPrototype(nameAr: 'كحلي', nameEn: 'navy', r: 28, g: 52, b: 94, swatch: Color(0xFF1E3A5F)),
  _ColorPrototype(nameAr: 'أزرق', nameEn: 'blue', r: 37, g: 99, b: 235, swatch: Color(0xFF2563EB)),
  _ColorPrototype(nameAr: 'سماوي', nameEn: 'sky', r: 125, g: 185, b: 232, swatch: Color(0xFF7DB9E8)),
  _ColorPrototype(nameAr: 'تركواز', nameEn: 'teal', r: 20, g: 150, b: 150, swatch: Color(0xFF149696)),
  _ColorPrototype(nameAr: 'أحمر', nameEn: 'red', r: 210, g: 38, b: 48, swatch: Color(0xFFDC2626)),
  _ColorPrototype(nameAr: 'عنابي', nameEn: 'burgundy', r: 120, g: 28, b: 42, swatch: Color(0xFF7F1D1D)),
  _ColorPrototype(nameAr: 'أخضر', nameEn: 'green', r: 28, g: 150, b: 72, swatch: Color(0xFF16A34A)),
  _ColorPrototype(nameAr: 'زيتوني', nameEn: 'olive', r: 85, g: 107, b: 47, swatch: Color(0xFF556B2F)),
  _ColorPrototype(nameAr: 'بيج', nameEn: 'beige', r: 214, g: 194, b: 163, swatch: Color(0xFFD6C2A3)),
  _ColorPrototype(nameAr: 'بني', nameEn: 'brown', r: 107, g: 66, b: 38, swatch: Color(0xFF6B4226)),
  _ColorPrototype(nameAr: 'وردي', nameEn: 'pink', r: 236, g: 72, b: 153, swatch: Color(0xFFEC4899)),
  _ColorPrototype(nameAr: 'زهري', nameEn: 'light pink', r: 244, g: 182, b: 200, swatch: Color(0xFFF4B6C8)),
  _ColorPrototype(nameAr: 'أصفر', nameEn: 'yellow', r: 234, g: 179, b: 8, swatch: Color(0xFFEAB308)),
  _ColorPrototype(nameAr: 'برتقالي', nameEn: 'orange', r: 249, g: 115, b: 22, swatch: Color(0xFFF97316)),
  _ColorPrototype(nameAr: 'بنفسجي', nameEn: 'purple', r: 147, g: 51, b: 234, swatch: Color(0xFF9333EA)),
];

/// High-precision visual search engine that extracts garment colors, HSV
/// histograms, silhouette and texture descriptors, and computes perceptual
/// similarity against catalog products.
class VisualSearchService {
  VisualSearchService._();

  static final VisualSearchService instance = VisualSearchService._();

  /// In-memory cache of computed visual descriptors keyed by product image URL.
  final Map<String, _ImageFeatures> _productFeatureCache =
      <String, _ImageFeatures>{};

  /// De-duplicates concurrent analyses of the same image URL.
  final Map<String, Future<_ImageFeatures?>> _inFlight =
      <String, Future<_ImageFeatures?>>{};

  /// Returns the cached detected garment colors for a product image URL if already analyzed.
  List<String> getCachedProductImageColors(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return const [];
    return _productFeatureCache[imageUrl.trim()]?.colors ?? const [];
  }

  /// Analyzes an image from bytes (in a background isolate) and returns a
  /// [VisualSearchQuery] containing dominant garment colors & visual descriptors.
  Future<VisualSearchQuery> analyzeImageBytes(
    Uint8List bytes, {
    String? fileNameHint,
  }) async {
    final rawMap = await compute(_analyzeImageIsolate, {
      'bytes': bytes,
      'hint': fileNameHint ?? '',
    });

    final primaryName = rawMap['primaryColorName'] as String? ?? 'أسود';
    final features = _ImageFeatures.fromMap(rawMap);

    return VisualSearchQuery(
      imageBytes: bytes,
      primaryColorName: primaryName,
      secondaryColorNames: List<String>.from(
        rawMap['secondaryColorNames'] as List? ?? const [],
      ),
      primarySwatch: Color(rawMap['primarySwatch'] as int? ?? 0xFF18181B),
      histogram: features.colorHistogram,
      aspectRatio: (rawMap['aspectRatio'] as num?)?.toDouble() ?? 1.0,
      inferredKeywords: List<String>.from(
        rawMap['keywords'] as List? ?? const [],
      ),
      shapeSignature: features.shape,
      edgeHistogram: features.edges,
      edgeDensity: features.edgeDensity,
      objectAspect: features.objectAspect,
      spatialColors: features.spatialColors,
    );
  }

  Future<_ImageFeatures?> _getOrComputeFeatures(
    String cleanUrl, {
    required bool downloadIfMissing,
  }) {
    final existing = _productFeatureCache[cleanUrl];
    if (existing != null) return Future.value(existing);
    final pending = _inFlight[cleanUrl];
    if (pending != null) return pending;

    final future = () async {
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
        final features = _ImageFeatures.fromMap(rawMap);
        if (features.colorHistogram.isNotEmpty) {
          _productFeatureCache[cleanUrl] = features;
        }
        return features;
      } catch (_) {
        return null;
      }
    }();

    _inFlight[cleanUrl] = future;
    return future.whenComplete(() => _inFlight.remove(cleanUrl));
  }

  /// Pre-computes or retrieves the visual color histogram and descriptors of a
  /// cached product image file.
  Future<List<double>?> getProductImageHistogram(
    String? imageUrl, {
    bool downloadIfMissing = true,
  }) async {
    if (kIsWeb || imageUrl == null || imageUrl.trim().isEmpty) return null;
    final features = await _getOrComputeFeatures(
      imageUrl.trim(),
      downloadIfMissing: downloadIfMissing,
    );
    final hist = features?.colorHistogram;
    return (hist == null || hist.isEmpty) ? null : hist;
  }

  /// Analyzes many product images with bounded concurrency so visual search
  /// covers a wide catalog without freezing the UI.
  Future<void> warmProductImages(
    Iterable<String?> imageUrls, {
    bool downloadIfMissing = false,
    int maxImages = 80,
    int concurrency = 6,
  }) async {
    if (kIsWeb) return;
    final queue = imageUrls
        .whereType<String>()
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty && !_productFeatureCache.containsKey(u))
        .toSet()
        .take(maxImages)
        .toList();
    if (queue.isEmpty) return;

    var cursor = 0;
    Future<void> worker() async {
      while (cursor < queue.length) {
        final url = queue[cursor++];
        await _getOrComputeFeatures(url, downloadIfMissing: downloadIfMissing);
      }
    }

    await Future.wait(
      List.generate(math.min(concurrency, queue.length), (_) => worker()),
    );
  }

  /// Computes cosine similarity (0.0 .. 1.0) between two histograms.
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

  double _histogramIntersection(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += math.min(a[i], b[i]);
    }
    return sum.clamp(0.0, 1.0);
  }

  /// Image-to-image perceptual similarity (0..1) combining color distribution,
  /// spatial color zones, garment silhouette, texture orientation, and proportions.
  double _compareFeatures(_ImageFeatures a, _ImageFeatures b) {
    final colorSim = compareHistograms(a.colorHistogram, b.colorHistogram);
    final hasShape = a.shape.isNotEmpty && b.shape.isNotEmpty;
    final hasEdges = a.edges.isNotEmpty && b.edges.isNotEmpty;
    if (!hasShape && !hasEdges) return colorSim;

    final shapeSim = hasShape ? compareHistograms(a.shape, b.shape) : colorSim;
    final hasSpatial = a.spatialColors.isNotEmpty && b.spatialColors.isNotEmpty;
    final layoutSim = hasSpatial
        ? compareHistograms(a.spatialColors, b.spatialColors)
        : colorSim;

    var textureSim = hasEdges ? _histogramIntersection(a.edges, b.edges) : 0.5;
    final maxDensity = math.max(a.edgeDensity, b.edgeDensity);
    if (maxDensity > 1e-6) {
      final densitySim = 1.0 - (a.edgeDensity - b.edgeDensity).abs() / maxDensity;
      textureSim = textureSim * 0.6 + densitySim * 0.4;
    }
    final aspectSim =
        1.0 -
        (math.log(math.max(a.objectAspect, 0.05) / math.max(b.objectAspect, 0.05)))
                .abs()
                .clamp(0.0, 1.0);

    return (colorSim * 0.40 +
            layoutSim * 0.15 +
            shapeSim * 0.22 +
            textureSim * 0.13 +
            aspectSim * 0.10)
        .clamp(0.0, 1.0);
  }

  /// Scores (0..1) how well a product matches the visual query using real
  /// image similarity (checked across [productImageUrls] or [productImageUrl])
  /// plus color-name and garment-keyword agreement with seller metadata.
  double scoreTextAndColorMetadata({
    required VisualSearchQuery query,
    required Iterable<String> productColors,
    required String productName,
    String? productDescription,
    String? categoryName,
    String? productImageUrl,
    Iterable<String> productImageUrls = const [],
  }) {
    final prodColors = productColors
        .where((c) => c.trim().isNotEmpty)
        .toList(growable: false);
    final searchableText =
        '$productName ${productDescription ?? ''} ${categoryName ?? ''}';

    // ---- Metadata agreement (color names via synonym groups + keywords) ----
    var meta = 0.0;
    final primary = query.primaryColorName;
    if (primary.isNotEmpty) {
      if (prodColors.any((c) => areSearchTermsEquivalent(c, primary))) {
        meta += 0.6;
      } else if (matchesSearchTokens(primary, [searchableText])) {
        meta += 0.45;
      }
    }
    for (final sec in query.secondaryColorNames) {
      if (prodColors.any((c) => areSearchTermsEquivalent(c, sec))) {
        meta += 0.2;
        break;
      }
    }
    for (final kw in query.inferredKeywords) {
      if (matchesSearchTokens(kw, [searchableText])) {
        meta += 0.3;
        break;
      }
    }
    meta = meta.clamp(0.0, 1.0);

    if (query.histogram.isEmpty) return meta;

    // ---- True image similarity across all cached images of this product ----
    _ImageFeatures? bestCached;
    var bestRaw = -1.0;
    final candidates = <String>{
      if (productImageUrl != null && productImageUrl.trim().isNotEmpty)
        productImageUrl.trim(),
      for (final u in productImageUrls)
        if (u.trim().isNotEmpty) u.trim(),
    };
    for (final url in candidates) {
      final cached = _productFeatureCache[url];
      if (cached == null) continue;
      final sim = _compareFeatures(query._features, cached);
      if (sim > bestRaw) {
        bestRaw = sim;
        bestCached = cached;
      }
    }
    if (bestCached == null) return meta;

    // Unrelated garments typically score ~0.35..0.55; stretch the useful range.
    final visual = ((bestRaw - 0.38) / 0.52).clamp(0.0, 1.0);
    final imageColorsAgree = bestCached.colors.isNotEmpty &&
        primary.isNotEmpty &&
        bestCached.colors.any((c) => areSearchTermsEquivalent(c, primary));

    final combined =
        visual * 0.62 + meta * 0.28 + (imageColorsAgree ? 0.1 : 0.0);
    return math.max(combined, meta * 0.85).clamp(0.0, 1.0);
  }
}

// =============================================================================
// Top-level isolate functions for fast off-main-thread image analysis
// =============================================================================

const int _kGrid = 64;

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
      'shape': const <double>[],
      'edges': const <double>[],
      'edgeDensity': 0.0,
      'spatialColors': const <double>[],
      'objectAspect': 1.0,
      'aspectRatio': 1.0,
      'keywords': _extractKeywordsFromHint(hint),
    };
  }

  final aspectRatio = decoded.height > 0 ? decoded.width / decoded.height : 1.0;

  // Resize to 64x64 for fast, noise-free perceptual analysis.
  final resized = img.copyResize(
    decoded,
    width: _kGrid,
    height: _kGrid,
    interpolation: img.Interpolation.average,
  );

  final n = _kGrid * _kGrid;
  final rs = Float64List(n);
  final gs = Float64List(n);
  final bs = Float64List(n);
  final alpha = Float64List(n);
  for (var y = 0; y < _kGrid; y++) {
    for (var x = 0; x < _kGrid; x++) {
      final p = resized.getPixel(x, y);
      final i = y * _kGrid + x;
      rs[i] = p.r.toDouble();
      gs[i] = p.g.toDouble();
      bs[i] = p.b.toDouble();
      alpha[i] = resized.hasAlpha ? p.a.toDouble() : 255.0;
    }
  }

  // ---- Background estimation from the outer border ----
  var borderR = 0.0, borderG = 0.0, borderB = 0.0;
  var borderCount = 0;
  for (var y = 0; y < _kGrid; y++) {
    for (var x = 0; x < _kGrid; x++) {
      if (x < 4 || x >= _kGrid - 4 || y < 4 || y >= _kGrid - 4) {
        final i = y * _kGrid + x;
        if (alpha[i] < 40) continue;
        borderR += rs[i];
        borderG += gs[i];
        borderB += bs[i];
        borderCount++;
      }
    }
  }
  if (borderCount > 0) {
    borderR /= borderCount;
    borderG /= borderCount;
    borderB /= borderCount;
  }
  var borderVar = 0.0;
  if (borderCount > 0) {
    for (var y = 0; y < _kGrid; y++) {
      for (var x = 0; x < _kGrid; x++) {
        if (x < 4 || x >= _kGrid - 4 || y < 4 || y >= _kGrid - 4) {
          final i = y * _kGrid + x;
          if (alpha[i] < 40) continue;
          final dr = rs[i] - borderR, dg = gs[i] - borderG, db = bs[i] - borderB;
          borderVar += dr * dr + dg * dg + db * db;
        }
      }
    }
    borderVar = math.sqrt(borderVar / borderCount);
  }
  // A uniform (studio) border lets us segment the garment reliably.
  final uniformBackground = borderCount > 0 && borderVar < 38.0;

  // ---- Foreground mask ----
  final fg = Float64List(n);
  var fgCount = 0;
  for (var y = 0; y < _kGrid; y++) {
    for (var x = 0; x < _kGrid; x++) {
      final i = y * _kGrid + x;
      if (alpha[i] < 40) continue;
      if (!uniformBackground) {
        // Real-world camera photos have cluttered borders; focus strongly on
        // the central garment oval so walls/tables don't bias colors or box.
        final nx = (x - _kGrid / 2.0) / (_kGrid / 2.0);
        final ny = (y - _kGrid / 2.0) / (_kGrid / 2.0);
        final r2 = nx * nx + ny * ny;
        fg[i] = r2 <= 0.52 ? 1.0 : math.max(0.08, 1.0 - (r2 - 0.52) * 1.15);
        continue;
      }
      final dr = rs[i] - borderR, dg = gs[i] - borderG, db = bs[i] - borderB;
      final dist = math.sqrt(dr * dr + dg * dg + db * db);
      if (dist >= 30.0) {
        fg[i] = 1.0;
        fgCount++;
      } else if (dist >= 18.0) {
        fg[i] = 0.4;
      }
    }
  }
  // Garment fills the whole frame (border is the garment itself): use central focus.
  if (uniformBackground && fgCount < n * 0.06) {
    for (var i = 0; i < n; i++) {
      if (alpha[i] >= 40) fg[i] = 1.0;
    }
  }

  // ---- Bounding box of the foreground ----
  var minX = _kGrid, minY = _kGrid, maxX = -1, maxY = -1;
  for (var y = 0; y < _kGrid; y++) {
    for (var x = 0; x < _kGrid; x++) {
      if (fg[y * _kGrid + x] >= 0.75) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < minX || maxY < minY) {
    minX = 0;
    minY = 0;
    maxX = _kGrid - 1;
    maxY = _kGrid - 1;
  }
  final boxW = (maxX - minX + 1).toDouble();
  final boxH = (maxY - minY + 1).toDouble();
  final cx = (minX + maxX) / 2.0;
  final cy = (minY + maxY) / 2.0;

  // ---- Color naming + 64-bin HSV histogram ----
  final colorWeights = <String, double>{
    for (final proto in _kFashionColorPrototypes) proto.nameAr: 0.0,
  };
  final histogram = List<double>.filled(64, 0.0);

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final i = y * _kGrid + x;
      final f = fg[i];
      if (f <= 0) continue;
      final r = rs[i], g = gs[i], b = bs[i];

      // Center weighting relative to the garment box.
      final dx = (x - cx) / math.max(boxW / 2.0, 1.0);
      final dy = (y - cy) / math.max(boxH / 2.0, 1.0);
      final centerWeight = math.max(0.3, 1.0 - (dx * dx + dy * dy) * 0.6);
      final weight = centerWeight * f;

      final closest = _findClosestColorPrototype(r, g, b);
      colorWeights[closest.nameAr] = (colorWeights[closest.nameAr] ?? 0.0) + weight;
      histogram[_hsvBin(r, g, b)] += weight;
    }
  }
  _l2Normalize(histogram);

  // ---- Silhouette (8x8) & spatial color layout (3x3x3 RGB) ----
  final shape = List<double>.filled(64, 0.0);
  final shapeCounts = List<double>.filled(64, 0.0);
  final spatialColors = List<double>.filled(27, 0.0);
  final spatialWeights = List<double>.filled(9, 0.0);
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final f = fg[y * _kGrid + x];
      final gx = (((x - minX) / boxW) * 8).floor().clamp(0, 7);
      final gy = (((y - minY) / boxH) * 8).floor().clamp(0, 7);
      final cell = gy * 8 + gx;
      shape[cell] += f;
      shapeCounts[cell] += 1.0;

      if (f > 0) {
        final sx = (((x - minX) / boxW) * 3).floor().clamp(0, 2);
        final sy = (((y - minY) / boxH) * 3).floor().clamp(0, 2);
        final sCell = sy * 3 + sx;
        final idx = y * _kGrid + x;
        spatialColors[sCell * 3] += rs[idx] * f;
        spatialColors[sCell * 3 + 1] += gs[idx] * f;
        spatialColors[sCell * 3 + 2] += bs[idx] * f;
        spatialWeights[sCell] += f;
      }
    }
  }
  for (var i = 0; i < 64; i++) {
    if (shapeCounts[i] > 0) shape[i] /= shapeCounts[i];
  }
  for (var c = 0; c < 9; c++) {
    final w = spatialWeights[c];
    if (w > 1e-6) {
      spatialColors[c * 3] /= w * 255.0;
      spatialColors[c * 3 + 1] /= w * 255.0;
      spatialColors[c * 3 + 2] /= w * 255.0;
    }
  }
  _l2Normalize(shape);
  _l2Normalize(spatialColors);

  // ---- Texture: Sobel gradient orientation histogram on luminance ----
  final lum = Float64List(n);
  for (var i = 0; i < n; i++) {
    lum[i] = 0.299 * rs[i] + 0.587 * gs[i] + 0.114 * bs[i];
  }
  final edges = List<double>.filled(8, 0.0);
  var magSum = 0.0;
  var magCount = 0;
  for (var y = math.max(minY, 1); y <= math.min(maxY, _kGrid - 2); y++) {
    for (var x = math.max(minX, 1); x <= math.min(maxX, _kGrid - 2); x++) {
      final i = y * _kGrid + x;
      if (fg[i] < 1.0) continue;
      double l(int xx, int yy) => lum[yy * _kGrid + xx];
      final gxv = -l(x - 1, y - 1) - 2 * l(x - 1, y) - l(x - 1, y + 1) +
          l(x + 1, y - 1) + 2 * l(x + 1, y) + l(x + 1, y + 1);
      final gyv = -l(x - 1, y - 1) - 2 * l(x, y - 1) - l(x + 1, y - 1) +
          l(x - 1, y + 1) + 2 * l(x, y + 1) + l(x + 1, y + 1);
      final mag = math.sqrt(gxv * gxv + gyv * gyv);
      magSum += mag;
      magCount++;
      if (mag < 24) continue;
      var angle = math.atan2(gyv, gxv); // -pi..pi
      if (angle < 0) angle += math.pi; // orientation 0..pi
      final bin = ((angle / math.pi) * 8).floor().clamp(0, 7);
      edges[bin] += mag;
    }
  }
  final edgeTotal = edges.fold<double>(0.0, (s, v) => s + v);
  if (edgeTotal > 1e-9) {
    for (var i = 0; i < 8; i++) {
      edges[i] /= edgeTotal;
    }
  }
  final edgeDensity = magCount > 0 ? (magSum / magCount) / 255.0 : 0.0;

  // ---- Dominant colors ----
  final sortedColors = colorWeights.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final totalWeight = sortedColors.fold<double>(0.0, (s, e) => s + e.value);
  final primaryName = sortedColors.isNotEmpty && sortedColors.first.value > 0
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
    'shape': shape,
    'edges': edges,
    'edgeDensity': edgeDensity,
    'spatialColors': spatialColors,
    'objectAspect': boxH > 0 ? boxW / boxH : 1.0,
    'aspectRatio': aspectRatio,
    'keywords': _extractKeywordsFromHint(hint),
  };
}

void _l2Normalize(List<double> v) {
  var norm = 0.0;
  for (final x in v) {
    norm += x * x;
  }
  norm = math.sqrt(norm);
  if (norm > 1e-9) {
    for (var i = 0; i < v.length; i++) {
      v[i] = v[i] / norm;
    }
  }
}

/// 64 bins: 4 achromatic (black, dark gray, light gray, white) +
/// 15 hues x 4 (saturation low/high x value low/high). Robust to lighting.
int _hsvBin(double r, double g, double b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final delta = maxC - minC;
  final v = maxC / 255.0;
  final s = maxC == 0 ? 0.0 : delta / maxC;

  if (v < 0.16) return 0;
  if (s < 0.14) {
    if (v < 0.45) return 1;
    if (v < 0.78) return 2;
    return 3;
  }

  double h;
  if (maxC == r) {
    h = 60.0 * (((g - b) / delta) % 6);
  } else if (maxC == g) {
    h = 60.0 * (((b - r) / delta) + 2);
  } else {
    h = 60.0 * (((r - g) / delta) + 4);
  }
  if (h < 0) h += 360;
  final hueBin = (h / 24.0).floor().clamp(0, 14);
  final satBin = s < 0.5 ? 0 : 1;
  final valBin = v < 0.6 ? 0 : 1;
  return 4 + hueBin * 4 + satBin * 2 + valBin;
}

_ColorPrototype _findClosestColorPrototype(double r, double g, double b) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final delta = maxC - minC;
  final saturation = maxC == 0 ? 0.0 : delta / maxC;
  final value = maxC / 255.0;

  // Handle achromatic (black / white / gray) accurately first
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
    'shorts': 'شورت',
    'shoes': 'حذاء',
    'sneaker': 'حذاء',
    'bag': 'حقيبة',
    'cap': 'قبعة',
    'scarf': 'حجاب',
  };
  final result = <String>[];
  for (final entry in dict.entries) {
    if (hint.contains(entry.key) || hint.contains(entry.value)) {
      if (!result.contains(entry.value)) result.add(entry.value);
    }
  }
  return result;
}
