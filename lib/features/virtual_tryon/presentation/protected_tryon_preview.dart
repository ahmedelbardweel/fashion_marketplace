import 'package:flutter/widgets.dart';

import '../domain/capture_quality.dart';
import 'tryon_preparation.dart';

/// Both videos must use unmirrored, contained frames. Keep the remote view
/// mounted even while clipped away so its first-frame callback can still fire.
class ProtectedTryonPreview extends StatelessWidget {
  const ProtectedTryonPreview({
    super.key,
    required this.original,
    required this.generated,
    required this.points,
    required this.outputPoints,
    required this.sourceAspect,
    required this.outputAspect,
    required this.observationAspect,
    required this.region,
    required this.enabled,
  });

  final Widget original, generated;
  final List<BodyPoint> points, outputPoints;
  final double sourceAspect, outputAspect, observationAspect;
  final String region;
  final bool enabled;

  bool get canComposite =>
      enabled && framesAlign(sourceAspect, outputAspect, observationAspect);

  static bool framesAlign(double source, double output, double observation) =>
      _sameAspect(source, output) && _sameAspect(source, observation);

  static bool _sameAspect(double a, double b) =>
      a.isFinite && b.isFinite && a > 0 && b > 0 && (a / b - 1).abs() < .015;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      original,
      // No fade-out: invalid generated pixels must disappear in this frame.
      IgnorePointer(
        child: ClipPath(
          clipBehavior: Clip.hardEdge,
          clipper: GarmentRegionClipper(
            points: points,
            aspect: sourceAspect,
            region: region,
            enabled: canComposite,
          ),
          child: ClipPath(
            clipBehavior: Clip.hardEdge,
            clipper: GarmentRegionClipper(
              points: outputPoints,
              aspect: outputAspect,
              region: region,
              enabled: canComposite,
            ),
            child: generated,
          ),
        ),
      ),
    ],
  );
}
