import 'dart:math';
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'landmark_smoother.dart';

/// Direction the user's body is facing relative to the camera.
enum BodyFacing {
  front,
  back,
  sideLeft,
  sideRight,
}

/// Describes how the garment image should be transformed in 3D to fit the body.
class GarmentTransform {
  const GarmentTransform({
    required this.center,
    required this.width,
    required this.height,
    required this.roll,
    required this.yaw,
    required this.pitch,
    required this.facing,
    required this.estimatedSize,
    required this.isDetected,
    required this.confidence,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
    required this.bodyMidpoint,
    required this.shoulderWidth,
  });

  /// Center position of the garment on screen.
  final Offset center;

  /// Target display width.
  final double width;

  /// Target display height.
  final double height;

  /// Roll angle in radians (shoulder tilt along Z axis).
  final double roll;

  /// Yaw angle in radians (3D rotation around vertical Y axis - when user turns).
  final double yaw;

  /// Pitch angle in radians (tilt forward/backward around X axis).
  final double pitch;

  /// Detected orientation of the body (front, back, side).
  final BodyFacing facing;

  /// Suggested size (S, M, L, XL) computed from body proportions.
  final String estimatedSize;

  /// Whether a valid body pose was detected.
  final bool isDetected;

  /// Average detection confidence [0–1].
  final double confidence;

  /// Smoothed landmark coordinates for debug & HUD rendering.
  final Offset leftShoulder;
  final Offset rightShoulder;
  final Offset leftHip;
  final Offset rightHip;
  final Offset bodyMidpoint;
  final double shoulderWidth;

  static const empty = GarmentTransform(
    center: Offset.zero,
    width: 0,
    height: 0,
    roll: 0,
    yaw: 0,
    pitch: 0,
    facing: BodyFacing.front,
    estimatedSize: 'M',
    isDetected: false,
    confidence: 0,
    leftShoulder: Offset.zero,
    rightShoulder: Offset.zero,
    leftHip: Offset.zero,
    rightHip: Offset.zero,
    bodyMidpoint: Offset.zero,
    shoulderWidth: 0,
  );
}

/// Calculates real-time 3D garment positioning and fitting from ML Kit pose landmarks.
class GarmentFitter {
  GarmentFitter() : _smoother = LandmarkSmoother(alpha: 0.35);

  final LandmarkSmoother _smoother;

  /// Extra width multiplier for garment shoulder fit.
  static const _widthPadding = 1.52;

  /// How much below hips the shirt extends.
  static const _lengthPadding = 1.32;

  /// Vertical offset ratio from shoulder toward hips for garment center.
  static const _verticalCenterRatio = 0.42;

  /// Minimum confidence to accept a landmark.
  static const _minLandmarkConfidence = 0.35;

  /// Key IDs for smoothing scalar values.
  static const _kRoll = 9000;
  static const _kWidth = 9001;
  static const _kHeight = 9002;
  static const _kYaw = 9003;
  static const _kPitch = 9004;

  void reset() => _smoother.reset();

  /// Compute full 3D garment transform from a detected pose.
  GarmentTransform fitGarment({
    required Pose pose,
    required Size imageSize,
    required Size canvasSize,
    required InputImageRotation rotation,
    required bool isFrontCamera,
  }) {
    // 1. Key body landmarks
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rEar = pose.landmarks[PoseLandmarkType.rightEar];

    // Must detect at least both shoulders
    if (lShoulder == null || rShoulder == null) {
      return GarmentTransform.empty;
    }

    if (lShoulder.likelihood < _minLandmarkConfidence ||
        rShoulder.likelihood < _minLandmarkConfidence) {
      return GarmentTransform.empty;
    }

    // 2. Convert to canvas coordinates
    final ls = _toCanvas(lShoulder, imageSize, canvasSize, rotation, isFrontCamera);
    final rs = _toCanvas(rShoulder, imageSize, canvasSize, rotation, isFrontCamera);

    Offset lh, rh;
    bool hasHips = false;
    if (lHip != null &&
        rHip != null &&
        lHip.likelihood >= _minLandmarkConfidence &&
        rHip.likelihood >= _minLandmarkConfidence) {
      lh = _toCanvas(lHip, imageSize, canvasSize, rotation, isFrontCamera);
      rh = _toCanvas(rHip, imageSize, canvasSize, rotation, isFrontCamera);
      hasHips = true;
    } else {
      // Estimate hips if lower body is cut off
      final midS = (ls + rs) / 2;
      final sw = (rs - ls).distance;
      lh = Offset(midS.dx - sw * 0.45, midS.dy + sw * 1.30);
      rh = Offset(midS.dx + sw * 0.45, midS.dy + sw * 1.30);
    }

    // 3. Smooth landmarks to prevent jitter
    final sLS = _smoother.smooth(11, ls);
    final sRS = _smoother.smooth(12, rs);
    final sLH = _smoother.smooth(23, lh);
    final sRH = _smoother.smooth(24, rh);

    // 4. Calculate shoulder & torso geometry
    final shoulderMid = (sLS + sRS) / 2;
    final hipMid = (sLH + sRH) / 2;
    final shoulderWidth = (sRS - sLS).distance;
    final torsoHeight = (hipMid - shoulderMid).distance;

    // 5. Detect body facing direction (Front vs Back vs Side)
    BodyFacing facing = BodyFacing.front;
    final bool noseVisible = nose != null && nose.likelihood > 0.40;
    final bool earsVisible = (lEar != null && lEar.likelihood > 0.40) ||
        (rEar != null && rEar.likelihood > 0.40);

    if (!noseVisible && earsVisible) {
      facing = BodyFacing.back;
    } else if (nose != null) {
      // Check depth z of nose vs shoulders
      final avgShoulderZ = (lShoulder.z + rShoulder.z) / 2;
      // When facing camera, nose is closer to camera (negative z compared to shoulders)
      if (nose.z > avgShoulderZ + 0.15 && nose.likelihood < 0.50) {
        facing = BodyFacing.back;
      }
    }

    // 6. Calculate 3D Yaw (rotation around vertical axis)
    // Depth difference between shoulders gives 3D turn angle
    final deltaZ = (rShoulder.z - lShoulder.z);
    double rawYaw = 0.0;
    if (shoulderWidth > 10) {
      // Invert deltaZ for mirrored front camera if needed
      final directedDeltaZ = isFrontCamera ? -deltaZ : deltaZ;
      rawYaw = atan2(directedDeltaZ * 0.0035, 1.0).clamp(-0.8, 0.8);

      if (rawYaw > 0.35) {
        if (facing != BodyFacing.back) facing = BodyFacing.sideRight;
      } else if (rawYaw < -0.35) {
        if (facing != BodyFacing.back) facing = BodyFacing.sideLeft;
      }
    }
    final smoothedYaw = _smoother.smoothScalar(_kYaw, rawYaw);

    // 7. Calculate 2D Roll (shoulder tilt)
    final rawRoll = atan2(sRS.dy - sLS.dy, sRS.dx - sLS.dx);
    final smoothedRoll = _smoother.smoothScalar(_kRoll, rawRoll);

    // 8. Pitch (lean forward or backward)
    final rawPitch = ((shoulderMid.dy - hipMid.dy) / max(torsoHeight, 1.0)) * 0.1;
    final smoothedPitch = _smoother.smoothScalar(_kPitch, rawPitch);

    // 9. Dynamic garment dimensions
    final rawWidth = shoulderWidth * _widthPadding;
    final rawHeight = torsoHeight * _lengthPadding;
    final garmentWidth = _smoother.smoothScalar(_kWidth, rawWidth);
    final garmentHeight = _smoother.smoothScalar(_kHeight, rawHeight);

    // 10. Center position on body
    final garmentCenter = Offset(
      shoulderMid.dx,
      shoulderMid.dy + torsoHeight * _verticalCenterRatio,
    );

    // 11. Suggest size from shoulder ratio
    final shoulderRatio = shoulderWidth / max(canvasSize.width, 1.0);
    final String estimatedSize;
    if (shoulderRatio < 0.32) {
      estimatedSize = 'S';
    } else if (shoulderRatio < 0.40) {
      estimatedSize = 'M';
    } else if (shoulderRatio < 0.48) {
      estimatedSize = 'L';
    } else {
      estimatedSize = 'XL';
    }

    // Average confidence calculation
    final confValues = [
      lShoulder.likelihood,
      rShoulder.likelihood,
      if (hasHips && lHip != null) lHip.likelihood,
      if (hasHips && rHip != null) rHip.likelihood,
    ];
    final avgConf = confValues.reduce((a, b) => a + b) / confValues.length;

    return GarmentTransform(
      center: garmentCenter,
      width: garmentWidth,
      height: garmentHeight,
      roll: smoothedRoll,
      yaw: smoothedYaw,
      pitch: smoothedPitch,
      facing: facing,
      estimatedSize: estimatedSize,
      isDetected: true,
      confidence: avgConf,
      leftShoulder: sLS,
      rightShoulder: sRS,
      leftHip: sLH,
      rightHip: sRH,
      bodyMidpoint: Offset(
        (shoulderMid.dx + hipMid.dx) / 2,
        (shoulderMid.dy + hipMid.dy) / 2,
      ),
      shoulderWidth: shoulderWidth,
    );
  }

  /// Maps an ML Kit landmark from image space to canvas space.
  Offset _toCanvas(
    PoseLandmark lm,
    Size imageSize,
    Size canvasSize,
    InputImageRotation imgRotation,
    bool isFrontCamera,
  ) {
    double x = lm.x;
    double y = lm.y;

    final double effectiveW;
    final double effectiveH;

    switch (imgRotation) {
      case InputImageRotation.rotation0deg:
        effectiveW = imageSize.width;
        effectiveH = imageSize.height;
        break;
      case InputImageRotation.rotation90deg:
        effectiveW = imageSize.height;
        effectiveH = imageSize.width;
        break;
      case InputImageRotation.rotation180deg:
        effectiveW = imageSize.width;
        effectiveH = imageSize.height;
        break;
      case InputImageRotation.rotation270deg:
        effectiveW = imageSize.height;
        effectiveH = imageSize.width;
        break;
    }

    final scaleX = canvasSize.width / effectiveW;
    final scaleY = canvasSize.height / effectiveH;

    x *= scaleX;
    y *= scaleY;

    if (isFrontCamera) {
      x = canvasSize.width - x;
    }

    return Offset(x, y);
  }
}
