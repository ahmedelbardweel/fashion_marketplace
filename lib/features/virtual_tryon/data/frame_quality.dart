import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/capture_quality.dart';

/// Low resolution, body-local exposure and focus statistics. No frames are saved.
Future<CaptureObservation> observeFrame(
  Uint8List bytes,
  List<List<BodyPoint>> poses,
) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('Unreadable frame');
    final pixels = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final w = image.width, h = image.height;
    final gray = Float64List(w * h);
    for (var i = 0; i < gray.length; i++) {
      gray[i] =
          .2126 * pixels[i * 4] +
          .7152 * pixels[i * 4 + 1] +
          .0722 * pixels[i * 4 + 2];
    }
    // Prefer visible face detail so a black shirt does not look like bad lighting.
    // Otherwise use visible body landmarks, never hallucinated off-frame hips.
    final p = poses.length == 1 && poses.single.length == 33
        ? poses.single
        : null;
    final face = p?.take(11).where((v) => v.visible).toList() ?? <BodyPoint>[];
    final focus = face.length >= 3
        ? face
        : p?.where((v) => v.visible).toList() ?? <BodyPoint>[];
    final x0 = focus.isEmpty
        ? .25
        : focus.map((v) => v.x).reduce(math.min) - .04;
    final x1 = focus.isEmpty
        ? .75
        : focus.map((v) => v.x).reduce(math.max) + .04;
    final y0 = focus.isEmpty
        ? .15
        : focus.map((v) => v.y).reduce(math.min) - .04;
    final y1 = focus.isEmpty
        ? .85
        : focus.map((v) => v.y).reduce(math.max) + .06;
    final left = (x0.isFinite ? x0 * w : 0).round().clamp(1, w - 2);
    final right = (x1.isFinite ? x1 * w : w - 1).round().clamp(left, w - 2);
    final top = (y0.isFinite ? y0 * h : 0).round().clamp(1, h - 2);
    final bottom = (y1.isFinite ? y1 * h : h - 1).round().clamp(top, h - 2);
    var sum = 0.0, dark = 0, bright = 0, n = 0;
    var lapSum = 0.0, lapSquares = 0.0;
    var background = 0.0, backgroundCount = 0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x, v = gray[i];
        if (x >= left && x <= right && y >= top && y <= bottom) {
          sum += v;
          n++;
          if (v < 35) dark++;
          if (v > 245) bright++;
          final lap =
              4 * v - gray[i - 1] - gray[i + 1] - gray[i - w] - gray[i + w];
          lapSum += lap;
          lapSquares += lap * lap;
        } else {
          background += v;
          backgroundCount++;
        }
      }
    }
    if (n == 0) throw StateError('Empty subject');
    return CaptureObservation(
      poses: poses,
      width: w,
      height: h,
      luminance: sum / n,
      darkFraction: dark / n,
      brightFraction: bright / n,
      backlight: backgroundCount == 0
          ? 0
          : background / backgroundCount - sum / n,
      sharpness: math.max(0, lapSquares / n - math.pow(lapSum / n, 2)),
    );
  } finally {
    image.dispose();
  }
}
