import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/garment_fitter.dart';
import '../theme/app_design.dart';

/// Paints the garment fitted to the detected body with realistic 3D perspective.
/// Stays completely invisible until a valid body pose is detected.
class GarmentOverlayPainter extends CustomPainter {
  GarmentOverlayPainter({
    required this.transform,
    required this.garmentImage,
    this.garmentBackImage,
    this.opacity = 0.96,
    this.showDebugOverlay = false,
  });

  final GarmentTransform transform;
  final ui.Image garmentImage;
  final ui.Image? garmentBackImage;
  final double opacity;
  final bool showDebugOverlay;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Strict guard: Draw NOTHING if body is not detected
    if (!transform.isDetected) return;

    final garmentW = transform.width;
    final garmentH = transform.height;

    if (garmentW <= 10 || garmentH <= 10) return;

    final center = transform.center;

    // Pick front or back image based on body orientation
    final bool isBackFacing = transform.facing == BodyFacing.back;
    final ui.Image activeImage =
        (isBackFacing && garmentBackImage != null) ? garmentBackImage! : garmentImage;

    canvas.save();

    // ──────────────────────────────────────────────────────────
    // 3D Perspective Matrix (Tilts and rotates with shoulders)
    // ──────────────────────────────────────────────────────────
    final matrix = Matrix4.translationValues(center.dx, center.dy, 0.0)
      ..setEntry(3, 2, 0.0012)
      ..rotateZ(transform.roll)
      ..rotateY(transform.yaw)
      ..rotateX(transform.pitch);

    canvas.transform(matrix.storage);

    // Source rect
    final srcRect = Rect.fromLTWH(
      0,
      0,
      activeImage.width.toDouble(),
      activeImage.height.toDouble(),
    );

    // Destination rect centered on shoulders/torso
    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: garmentW,
      height: garmentH,
    );

    // High quality anti-aliased paint
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, opacity)
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    if (isBackFacing && garmentBackImage == null) {
      paint.colorFilter = const ColorFilter.mode(
        Color(0x33000000),
        BlendMode.darken,
      );
    }

    canvas.drawImageRect(activeImage, srcRect, dstRect, paint);

    canvas.restore();

    // Optional debug overlay (only if explicitly enabled)
    if (showDebugOverlay) {
      _drawDebug(canvas, size, center);
    }
  }

  void _drawDebug(Canvas canvas, Size size, Offset center) {
    final linePaint = Paint()
      ..color = TryOnDesign.detectedStroke
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(transform.leftShoulder, transform.rightShoulder, linePaint);
  }

  @override
  bool shouldRepaint(covariant GarmentOverlayPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.garmentImage != garmentImage ||
        oldDelegate.garmentBackImage != garmentBackImage ||
        oldDelegate.opacity != opacity ||
        oldDelegate.showDebugOverlay != showDebugOverlay;
  }
}
