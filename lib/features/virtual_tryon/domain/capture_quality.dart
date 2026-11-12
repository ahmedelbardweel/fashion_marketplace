import 'dart:math' as math;

import 'tryon_session.dart';

/// Normalized, unmirrored coordinates in the captured image, never centimeters.
class BodyPoint {
  const BodyPoint(this.x, this.y, this.z, this.confidence);
  final double x, y, z, confidence;
  factory BodyPoint.fromMap(Map<dynamic, dynamic> value) => BodyPoint(
    (value['x'] as num).toDouble(),
    (value['y'] as num).toDouble(),
    (value['z'] as num? ?? 0).toDouble(),
    (value['visibility'] as num? ?? 0).toDouble(),
  );
  bool get visible =>
      x.isFinite &&
      y.isFinite &&
      z.isFinite &&
      confidence.isFinite &&
      confidence >= .7 &&
      x > .025 &&
      x < .975 &&
      y > .025 &&
      y < .975;
}

class CaptureObservation {
  const CaptureObservation({
    required this.poses,
    required this.width,
    required this.height,
    required this.luminance,
    required this.darkFraction,
    required this.brightFraction,
    required this.backlight,
    required this.sharpness,
  });
  final List<List<BodyPoint>> poses;
  final int width, height;
  final double luminance, darkFraction, brightFraction, backlight, sharpness;
}

enum CaptureIssue {
  unavailable,
  noPerson,
  multiplePeople,
  dark,
  overexposed,
  backlit,
  blurred,
  cropped,
  tooFar,
  moving,
  stabilizing,
}

extension CaptureIssueMessage on CaptureIssue {
  String get message => switch (this) {
    CaptureIssue.unavailable => 'تعذر فحص الصورة. أعد المحاولة في مكان مضاء.',
    CaptureIssue.noPerson => 'أظهر المنطقة المطلوبة من جسمك أمام الكاميرا.',
    CaptureIssue.multiplePeople => 'ظهر أكثر من شخص. ابقَ وحدك داخل الإطار.',
    CaptureIssue.dark => 'الإضاءة ضعيفة. وجّه ضوءاً ناعماً نحوك.',
    CaptureIssue.overexposed => 'الضوء قوي جداً. ابتعد عن الضوء المباشر.',
    CaptureIssue.backlit => 'الضوء خلفك. استدر ليصبح الضوء أمامك.',
    CaptureIssue.blurred => 'الصورة غير واضحة. ثبّت الهاتف ونظّف العدسة.',
    CaptureIssue.cropped => 'ابتعد قليلاً حتى تظهر الأجزاء المطلوبة من جسمك.',
    CaptureIssue.tooFar => 'اقترب قليلاً لتظهر تفاصيل جسمك بوضوح.',
    CaptureIssue.moving => 'نتابع حركتك… تمهّل لحظة حتى تتطابق القطعة.',
    CaptureIssue.stabilizing => 'ممتاز، حافظ على وضعيتك حتى يكتمل الفحص.',
  };
}

/// Only landmarks belonging to the selected clothing region are mandatory.
/// Seated, tilted, cropped portraits are valid for tops when shoulders are clear.
List<int> requiredBodyPoints(String region) => switch (region) {
  'upper body garment' => const [11, 12],
  'lower body garment' => const [23, 24, 25, 26, 27, 28],
  'footwear' => const [27, 28, 29, 30, 31, 32],
  'outfit' => const [11, 12, 23, 24, 25, 26, 27, 28],
  _ => const [11, 12],
};

String framingHint(String region) => switch (region) {
  'upper body garment' =>
    'يكفي ظهور الكتفين بوضوح. يمكنك الجلوس أو الوقوف بوضعيتك الطبيعية.',
  'lower body garment' =>
    'أظهر منطقة البنطال من الوركين حتى الكاحلين؛ لا يلزم ظهور الوجه.',
  'footwear' =>
    'وجّه الكاميرا نحو القدمين والكاحلين؛ لا يلزم ظهور الجسم كاملاً.',
  'outfit' => 'أظهر الكتفين ومنطقة القطعة حتى الكاحلين.',
  _ => 'يكفي ظهور الكتفين بوضوح. يمكنك الجلوس أو الوقوف بوضعيتك الطبيعية.',
};

class CaptureAssessment {
  const CaptureAssessment({
    this.issue,
    this.points = const [],
    this.progress = 0,
    this.peopleOk = false,
    this.lightOk = false,
    this.poseOk = false,
    this.clarityOk = false,
  });
  final CaptureIssue? issue;
  final List<BodyPoint> points;
  final double progress;
  final bool peopleOk, lightOk, poseOk, clarityOk;
  bool get ready => issue == null && progress >= 1;
}

/// Conservative capture heuristics, deliberately separate from clothing sizing.
/// Unknown/invalid observations fail closed; one good frame never unlocks try-on.
class CaptureQualityGate {
  Duration? _stableSince;
  Duration? _lastSample;
  List<BodyPoint>? _previous;
  String? _region;
  static const stableDuration = Duration(seconds: 2);

  void reset() {
    _stableSince = null;
    _lastSample = null;
    _previous = null;
  }

  CaptureAssessment evaluate(
    CaptureObservation frame,
    GarmentSelection garment,
    Duration now,
  ) {
    if (_region != garment.region) {
      reset();
      _region = garment.region;
    }
    if (_lastSample != null &&
        (now <= _lastSample! ||
            now - _lastSample! > const Duration(seconds: 2))) {
      reset();
    }
    _lastSample = now;
    final peopleOk = frame.poses.length == 1;
    final points = peopleOk ? frame.poses.single : <BodyPoint>[];
    var lightOk = false, clarityOk = false, poseOk = false;
    CaptureAssessment fail(CaptureIssue issue) {
      _stableSince = null;
      _previous = null;
      return CaptureAssessment(
        issue: issue,
        points: points,
        peopleOk: peopleOk,
        lightOk: lightOk,
        clarityOk: clarityOk,
        poseOk: poseOk,
      );
    }

    if (frame.width < 120 ||
        frame.height < 120 ||
        [
          frame.luminance,
          frame.darkFraction,
          frame.brightFraction,
          frame.backlight,
          frame.sharpness,
        ].any((v) => !v.isFinite)) {
      return fail(CaptureIssue.unavailable);
    }
    if (frame.poses.isEmpty) return fail(CaptureIssue.noPerson);
    if (!peopleOk) return fail(CaptureIssue.multiplePeople);
    if (frame.luminance < 45 || frame.darkFraction > .6) {
      return fail(CaptureIssue.dark);
    }
    if (frame.luminance > 230 || frame.brightFraction > .5) {
      return fail(CaptureIssue.overexposed);
    }
    if (frame.backlight > 65 && frame.luminance < 100) {
      return fail(CaptureIssue.backlit);
    }
    lightOk = true;
    if (frame.sharpness < 18) return fail(CaptureIssue.blurred);
    clarityOk = true;
    final required = requiredBodyPoints(garment.region);
    if (points.length != 33 || required.any((i) => !points[i].visible)) {
      return fail(CaptureIssue.cropped);
    }
    final anchorA = points[required[0]], anchorB = points[required[1]];
    final dx = (anchorA.x - anchorB.x) * frame.width;
    final dy = (anchorA.y - anchorB.y) * frame.height;
    if (math.sqrt(dx * dx + dy * dy) < 22) return fail(CaptureIssue.tooFar);
    poseOk = true;
    final previous = _previous;
    _previous = points;
    if (previous != null &&
        required.any(
          (i) =>
              (points[i].x - previous[i].x).abs() > .025 ||
              (points[i].y - previous[i].y).abs() > .025,
        )) {
      _stableSince = null;
      return CaptureAssessment(
        issue: CaptureIssue.moving,
        points: points,
        peopleOk: true,
        lightOk: true,
        clarityOk: true,
        poseOk: true,
      );
    }
    _stableSince ??= now;
    final progress =
        ((now - _stableSince!).inMilliseconds / stableDuration.inMilliseconds)
            .clamp(0.0, 1.0);
    return CaptureAssessment(
      issue: progress < 1 ? CaptureIssue.stabilizing : null,
      points: points,
      progress: progress,
      peopleOk: true,
      lightOk: true,
      clarityOk: true,
      poseOk: true,
    );
  }
}

/// Reject a shifted/reframed or grossly distorted result before compositing it.
/// This checks geometry, not biometric identity or garment fidelity.
bool outputMatchesBody(
  List<BodyPoint> source,
  List<List<BodyPoint>> output,
  GarmentSelection garment,
) {
  if (source.length != 33 || output.length != 1 || output.single.length != 33) {
    return false;
  }
  final target = output.single;
  final anchors = requiredBodyPoints(garment.region);
  return anchors.every(
    (i) =>
        source[i].visible &&
        target[i].visible &&
        (source[i].x - target[i].x).abs() < .055 &&
        (source[i].y - target[i].y).abs() < .055,
  );
}
