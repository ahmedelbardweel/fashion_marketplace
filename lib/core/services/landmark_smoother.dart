import 'dart:ui';

/// Exponential Moving Average (EMA) smoother for pose landmarks.
/// Reduces jitter in real-time pose detection by smoothing
/// landmark positions across consecutive frames.
class LandmarkSmoother {
  LandmarkSmoother({this.alpha = 0.35, this.velocityDamping = 0.7});

  /// Smoothing factor (0–1). Lower = smoother but more lag.
  final double alpha;

  /// Velocity damping factor for predictive smoothing.
  final double velocityDamping;

  final Map<int, Offset> _smoothed = {};
  final Map<int, Offset> _velocity = {};

  /// Smooths a landmark position using EMA with velocity prediction.
  Offset smooth(int landmarkType, Offset raw) {
    final prev = _smoothed[landmarkType];
    if (prev == null) {
      _smoothed[landmarkType] = raw;
      _velocity[landmarkType] = Offset.zero;
      return raw;
    }

    // Calculate velocity
    final prevVel = _velocity[landmarkType] ?? Offset.zero;
    final instantVel = raw - prev;
    final smoothedVel = Offset(
      prevVel.dx * velocityDamping + instantVel.dx * (1 - velocityDamping),
      prevVel.dy * velocityDamping + instantVel.dy * (1 - velocityDamping),
    );
    _velocity[landmarkType] = smoothedVel;

    // Adaptive alpha: increase responsiveness for large movements
    final displacement = (raw - prev).distance;
    final adaptiveAlpha = displacement > 30 ? (alpha * 1.8).clamp(0.0, 0.9) : alpha;

    // EMA with velocity prediction
    final predicted = Offset(
      prev.dx + smoothedVel.dx * 0.5,
      prev.dy + smoothedVel.dy * 0.5,
    );
    final smoothed = Offset(
      predicted.dx + adaptiveAlpha * (raw.dx - predicted.dx),
      predicted.dy + adaptiveAlpha * (raw.dy - predicted.dy),
    );

    _smoothed[landmarkType] = smoothed;
    return smoothed;
  }

  /// Smooth a scalar value (e.g., scale, rotation).
  double smoothScalar(int key, double raw) {
    final offset = smooth(key, Offset(raw, 0));
    return offset.dx;
  }

  void reset() {
    _smoothed.clear();
    _velocity.clear();
  }
}
