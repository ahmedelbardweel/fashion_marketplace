import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Preset compression profiles balancing crisp fashion detail with minimal
/// upload/download size for weak or metered internet connections.
enum ImageCompressPreset {
  /// Product photos, covers, gallery & catalog images (max 1200px, JPEG 82).
  product(maxDimension: 1200, jpegQuality: 82, preserveAlphaIfTransparent: true),

  /// Home & promo banners (max 1440px, JPEG 82).
  banner(maxDimension: 1440, jpegQuality: 82, preserveAlphaIfTransparent: false),

  /// Transfer receipts & verification documents (max 1280px, JPEG 80 — text stays crisp).
  receipt(maxDimension: 1280, jpegQuality: 80, preserveAlphaIfTransparent: false),

  /// Shop logos (max 512px, preserves transparent PNG cutouts).
  logo(maxDimension: 512, jpegQuality: 85, preserveAlphaIfTransparent: true),

  /// Virtual Try-On garment reference sent to Lucy VTON (max 768px, JPEG 82 -> ~60-90 KB).
  tryonGarment(
    maxDimension: 768,
    jpegQuality: 82,
    preserveAlphaIfTransparent: false,
  ),

  /// Downloaded images cached locally on disk (max 1080px, JPEG 80 when opaque).
  diskCache(
    maxDimension: 1080,
    jpegQuality: 80,
    preserveAlphaIfTransparent: true,
  );

  const ImageCompressPreset({
    required this.maxDimension,
    required this.jpegQuality,
    required this.preserveAlphaIfTransparent,
  });

  final int maxDimension;
  final int jpegQuality;
  final bool preserveAlphaIfTransparent;
}

class CompressedImageResult {
  const CompressedImageResult({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.wasCompressed,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final bool wasCompressed;
}

class _CompressJob {
  const _CompressJob({
    required this.bytes,
    required this.maxDimension,
    required this.jpegQuality,
    required this.preserveAlphaIfTransparent,
    required this.preferPng,
  });

  final Uint8List bytes;
  final int maxDimension;
  final int jpegQuality;
  final bool preserveAlphaIfTransparent;
  final bool preferPng;
}

class _CompressOutput {
  const _CompressOutput({
    required this.bytes,
    required this.isPng,
    required this.changed,
  });

  final Uint8List bytes;
  final bool isPng;
  final bool changed;
}

/// Top-level isolate worker for `compute()` so heavy image decoding/encoding
/// never drops frames on the UI thread.
_CompressOutput _compressInIsolate(_CompressJob job) {
  try {
    final decodedRaw = img.decodeImage(job.bytes);
    if (decodedRaw == null) {
      return _CompressOutput(bytes: job.bytes, isPng: job.preferPng, changed: false);
    }

    // Normalize phone camera EXIF rotation so photos never upload sideways.
    var image = img.bakeOrientation(decodedRaw);

    final longest = image.width > image.height ? image.width : image.height;
    if (longest > job.maxDimension) {
      if (image.width >= image.height) {
        image = img.copyResize(
          image,
          width: job.maxDimension,
          interpolation: img.Interpolation.average,
        );
      } else {
        image = img.copyResize(
          image,
          height: job.maxDimension,
          interpolation: img.Interpolation.average,
        );
      }
    }

    final keepPng =
        job.preserveAlphaIfTransparent &&
        job.preferPng &&
        _hasMeaningfulTransparency(image);

    final Uint8List encoded;
    if (keepPng) {
      encoded = Uint8List.fromList(img.encodePng(image, level: 6));
    } else {
      // Composite transparent pixels cleanly on pure white before JPEG encoding.
      if (image.hasAlpha) {
        final flattened = img.Image(
          width: image.width,
          height: image.height,
          numChannels: 3,
        );
        img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(flattened, image);
        image = flattened;
      }
      encoded = Uint8List.fromList(
        img.encodeJpg(image, quality: job.jpegQuality),
      );
    }

    // Never inflate an already tiny optimized image.
    if (encoded.isEmpty ||
        (encoded.length >= job.bytes.length && longest <= job.maxDimension)) {
      return _CompressOutput(
        bytes: job.bytes,
        isPng: job.preferPng,
        changed: false,
      );
    }

    return _CompressOutput(bytes: encoded, isPng: keepPng, changed: true);
  } catch (_) {
    return _CompressOutput(
      bytes: job.bytes,
      isPng: job.preferPng,
      changed: false,
    );
  }
}

/// Samples a fast grid across the image to check whether it genuinely uses
/// transparency (e.g. cutout logos) rather than being an opaque PNG screenshot.
bool _hasMeaningfulTransparency(img.Image image) {
  if (!image.hasAlpha) return false;
  final stepX = (image.width / 24).ceil().clamp(1, image.width);
  final stepY = (image.height / 24).ceil().clamp(1, image.height);
  for (var y = 0; y < image.height; y += stepY) {
    for (var x = 0; x < image.width; x += stepX) {
      final pixel = image.getPixel(x, y);
      if (pixel.a < 245) return true;
    }
  }
  return false;
}

/// Unified image compressor used across all Supabase uploads, downloaded disk
/// cache files, and Virtual Try-On garment references.
class AppImageCompressor {
  AppImageCompressor._();

  static const Set<String> _nonImageExts = {
    '.pdf',
    '.glb',
    '.gltf',
    '.usdz',
    '.obj',
    '.mp4',
    '.mov',
    '.zip',
    '.json',
  };

  /// Minimum byte size below which disk-cache downloads are already compact
  /// enough to store directly without burning CPU on re-encoding.
  static const int diskCacheSkipBytes = 160 * 1024;

  static bool isCompressibleImage({
    String? fileName,
    String? contentType,
  }) {
    final ct = contentType?.toLowerCase().trim() ?? '';
    if (ct.isNotEmpty) {
      if (ct.contains('svg') || ct.contains('gif')) return false;
      if (!ct.startsWith('image/')) return false;
    }
    final ext = p.extension(fileName ?? '').toLowerCase();
    if (ext.isNotEmpty && _nonImageExts.contains(ext)) return false;
    if (ext == '.svg' || ext == '.gif') return false;
    return true;
  }

  /// Compresses [bytes] off the UI thread according to [preset] and returns
  /// updated bytes, normalized filename extension, and MIME content type.
  static Future<CompressedImageResult> compressForUpload({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
    ImageCompressPreset preset = ImageCompressPreset.product,
  }) async {
    final fallbackContentType =
        (contentType?.trim().isNotEmpty ?? false)
        ? contentType!.trim()
        : _guessContentType(fileName);

    if (bytes.isEmpty ||
        !isCompressibleImage(fileName: fileName, contentType: contentType)) {
      return CompressedImageResult(
        bytes: bytes,
        fileName: fileName,
        contentType: fallbackContentType,
        wasCompressed: false,
      );
    }

    final ext = p.extension(fileName).toLowerCase();
    final preferPng = ext == '.png' || fallbackContentType == 'image/png';

    final output = await _runJob(
      _CompressJob(
        bytes: bytes,
        maxDimension: preset.maxDimension,
        jpegQuality: preset.jpegQuality,
        preserveAlphaIfTransparent: preset.preserveAlphaIfTransparent,
        preferPng: preferPng,
      ),
    );

    if (!output.changed) {
      return CompressedImageResult(
        bytes: bytes,
        fileName: fileName,
        contentType: fallbackContentType,
        wasCompressed: false,
      );
    }

    final base = p.basenameWithoutExtension(fileName);
    final safeBase = base.isEmpty ? 'image' : base;
    final nextExt = output.isPng ? '.png' : '.jpg';
    final nextMime = output.isPng ? 'image/png' : 'image/jpeg';

    return CompressedImageResult(
      bytes: output.bytes,
      fileName: '$safeBase$nextExt',
      contentType: nextMime,
      wasCompressed: true,
    );
  }

  /// Compresses raw image bytes (used for Virtual Try-On garment references
  /// and downloaded disk-cache optimization). Returns original bytes on fallback.
  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    required ImageCompressPreset preset,
    bool preferPng = false,
  }) async {
    if (bytes.isEmpty) return bytes;
    if (preset == ImageCompressPreset.diskCache &&
        bytes.length <= diskCacheSkipBytes) {
      return bytes;
    }
    final output = await _runJob(
      _CompressJob(
        bytes: bytes,
        maxDimension: preset.maxDimension,
        jpegQuality: preset.jpegQuality,
        preserveAlphaIfTransparent: preset.preserveAlphaIfTransparent,
        preferPng: preferPng,
      ),
    );
    return output.bytes;
  }

  static Future<_CompressOutput> _runJob(_CompressJob job) async {
    if (kIsWeb) {
      return _compressInIsolate(job);
    }
    try {
      return await compute(_compressInIsolate, job);
    } catch (_) {
      return _compressInIsolate(job);
    }
  }

  static String _guessContentType(String fileName) {
    return switch (p.extension(fileName).toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.jpg' || '.jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }
}
