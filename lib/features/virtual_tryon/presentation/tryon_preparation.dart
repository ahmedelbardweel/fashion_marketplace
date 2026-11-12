import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../domain/capture_quality.dart';

class TryonSteps extends StatelessWidget {
  const TryonSteps({super.key, required this.current});
  final int current;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppColors.border,
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i <= current
                      ? AppColors.primary
                      : AppColors.gray100,
                  child: i < current
                      ? const Icon(AppIcons.check, size: 14, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: i == current
                                ? Colors.white
                                : AppColors.gray500,
                          ),
                        ),
                ),
                const SizedBox(height: 5),
                Text(
                  ['التجهيز'.tr, 'فحص الجسم'.tr, 'التجربة'.tr][i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: i <= current ? AppColors.primary : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class TryonIntroduction extends StatelessWidget {
  const TryonIntroduction({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    AppIcons.bodyGuide,
                    size: 102,
                    color: AppColors.primary,
                  ),
                  Positioned(
                    bottom: 12,
                    child: Text(
                      'تجربة تبدأ بجسمك'.tr,
                      style: TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'قطعتك، على مقاس صورتك'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'خطوات بسيطة لتجربة أوضح وأكثر ثباتاً.'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray500),
            ),
            const SizedBox(height: 24),
            _Tip(
              AppIcons.sun,
              'ضوء أمامك'.tr,
              'اختر إضاءة متوازنة وتجنّب النافذة خلفك.'.tr,
            ),
            _Tip(
              AppIcons.user,
              'أنت وحدك في الصورة'.tr,
              'وجّه الكاميرا نحو المنطقة التي تريد تجربة القطعة عليها.'.tr,
            ),
            _Tip(
              AppIcons.bodyGuide,
              'بوضعيتك الطبيعية'.tr,
              'جالساً أو واقفاً؛ للقطع العلوية يكفي ظهور الكتفين بوضوح.'.tr,
            ),
            const SizedBox(height: 16),
            Text(
              'نفحص الصورة على جهازك. بعد نجاح الفحص، تبدأ التجربة تلقائياً ويُرسل فيديو الكاميرا إلى خدمة التجربة لمعالجته.'.tr,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'المعاينة تقديرية للشكل؛ لا تقيس محيط الجسم أو تحدد مقاس الشراء من صورة واحدة.'.tr,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 24),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'جارٍ تجهيز الكاميرا والفحص تلقائياً…'.tr,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.gray500,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CaptureChecklist extends StatelessWidget {
  const CaptureChecklist({
    super.key,
    required this.assessment,
    required this.region,
  });
  final CaptureAssessment assessment;
  final String region;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            assessment.ready
                ? 'اكتمل الفحص، جارٍ تجربة القطعة…'.tr
                : assessment.issue == CaptureIssue.cropped &&
                      region == 'upper body garment'
                ? 'أظهر الكتفين بوضوح داخل الصورة؛ لا يلزم ظهور الجسم كاملاً.'.tr
                : assessment.issue?.message ?? 'جارٍ تجهيز فحص الجسم…'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          framingHint(region),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _check('شخص واحد'.tr, assessment.peopleOk),
            _check('إضاءة'.tr, assessment.lightOk),
            _check('وضوح'.tr, assessment.clarityOk),
            _check(
              region == 'upper body garment'
                  ? 'الكتفان واضحان'.tr
                  : 'منطقة القطعة'.tr,
              assessment.poseOk,
            ),
          ],
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: assessment.progress,
          minHeight: 3,
          backgroundColor: AppColors.gray100,
          color: AppColors.primary,
          semanticsLabel: 'ثبات وضعية الجسم'.tr,
        ),
        const SizedBox(height: 14),
        Text(
          'ثبّت وضعيتك لثانيتين؛ تبدأ التجربة تلقائياً عند اكتمال الفحص.'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'الفحص محلي على جهازك. بعد نجاحه يُرسل فيديو الكاميرا إلى خدمة التجربة للمعالجة.'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.gray500),
        ),
      ],
    ),
  );
  Widget _check(String label, bool passed) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        passed ? AppIcons.checkCircleFilled : AppIcons.radioUnchecked,
        size: 16,
        color: passed ? AppColors.primary : AppColors.gray300,
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: passed ? AppColors.primary : AppColors.gray500,
        ),
      ),
    ],
  );
}

Rect captureRect(Size size, double aspect) {
  if (!aspect.isFinite || aspect <= 0) return Rect.zero;
  final width = math.min(size.width, size.height * aspect);
  final height = width / aspect;
  return Rect.fromLTWH(
    (size.width - width) / 2,
    (size.height - height) / 2,
    width,
    height,
  );
}

class BodyGuidePainter extends CustomPainter {
  BodyGuidePainter(
    this.points,
    this.aspect, {
    this.region = 'upper body garment',
  });
  final List<BodyPoint> points;
  final double aspect;
  final String region;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = captureRect(size, aspect);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (points.length != 33) {
      if (requiredBodyPoints(region).length == 2) {
        // Shoulder guide is constrained to the actual video, including webcams.
        final y = rect.top + rect.height * .58;
        canvas.drawPath(
          Path()
            ..moveTo(rect.left + rect.width * .18, y + rect.height * .2)
            ..quadraticBezierTo(
              rect.left + rect.width * .18,
              y,
              rect.left + rect.width * .38,
              y,
            )
            ..moveTo(rect.left + rect.width * .62, y)
            ..quadraticBezierTo(
              rect.left + rect.width * .82,
              y,
              rect.left + rect.width * .82,
              y + rect.height * .2,
            ),
          paint,
        );
        return;
      }
      final center = rect.center.dx;
      final top = rect.top + rect.height * .12;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center, top),
          width: rect.width * .15,
          height: rect.height * .10,
        ),
        paint,
      );
      final path = Path()
        ..moveTo(center - rect.width * .16, top + rect.height * .09)
        ..lineTo(center - rect.width * .28, top + rect.height * .40)
        ..moveTo(center + rect.width * .16, top + rect.height * .09)
        ..lineTo(center + rect.width * .28, top + rect.height * .40)
        ..moveTo(center - rect.width * .16, top + rect.height * .09)
        ..lineTo(center + rect.width * .16, top + rect.height * .09)
        ..lineTo(center + rect.width * .12, top + rect.height * .43)
        ..lineTo(center + rect.width * .14, top + rect.height * .77)
        ..moveTo(center - rect.width * .16, top + rect.height * .09)
        ..lineTo(center - rect.width * .12, top + rect.height * .43)
        ..lineTo(center - rect.width * .14, top + rect.height * .77);
      canvas.drawPath(path, paint);
      return;
    }
    Offset point(int i) => Offset(
      rect.left + points[i].x * rect.width,
      rect.top + points[i].y * rect.height,
    );
    paint.color = AppColors.primary;
    paint.strokeWidth = 2;
    for (final pair in [
      [11, 12],
      [11, 13],
      [13, 15],
      [12, 14],
      [14, 16],
      [11, 23],
      [12, 24],
      [23, 24],
      [23, 25],
      [25, 27],
      [24, 26],
      [26, 28],
    ]) {
      if (points[pair[0]].visible && points[pair[1]].visible) {
        canvas.drawLine(point(pair[0]), point(pair[1]), paint);
      }
    }
    paint.style = PaintingStyle.fill;
    for (final i in [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]) {
      if (points[i].visible) canvas.drawCircle(point(i), 3, paint);
    }
  }

  @override
  bool shouldRepaint(BodyGuidePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.aspect != aspect ||
      oldDelegate.region != region;
}

/// Only the requested clothing area may display generated pixels. Everything
/// outside this conservative landmark mask comes from the original camera.
class GarmentRegionClipper extends CustomClipper<Path> {
  GarmentRegionClipper({
    required this.points,
    required this.aspect,
    required this.region,
    required this.enabled,
  });
  final List<BodyPoint> points;
  final double aspect;
  final String region;
  final bool enabled;
  @override
  Path getClip(Size size) {
    if (!enabled ||
        points.length != 33 ||
        requiredBodyPoints(region).any((i) => !points[i].visible)) {
      return Path();
    }
    final rect = captureRect(size, aspect);
    Offset p(int i) => Offset(
      rect.left + points[i].x * rect.width,
      rect.top + points[i].y * rect.height,
    );
    var mask = Path();
    void limb(int a, int b, double width) {
      if (!points[a].visible || !points[b].visible) return;
      final delta = p(b) - p(a);
      if (delta.distance < 1) return;
      final normal = Offset(-delta.dy, delta.dx) / delta.distance * width;
      mask.addPolygon([
        p(a) + normal,
        p(b) + normal,
        p(b) - normal,
        p(a) - normal,
      ], true);
    }

    if (region == 'footwear') {
      for (final ids in [
        [27, 29, 31],
        [28, 30, 32],
      ]) {
        final offsets = ids.map(p).toList();
        final pad = rect.width * .025;
        mask.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              offsets.map((v) => v.dx).reduce(math.min) - pad,
              offsets.map((v) => v.dy).reduce(math.min) - pad,
              offsets.map((v) => v.dx).reduce(math.max) + pad,
              offsets.map((v) => v.dy).reduce(math.max) + pad,
            ),
            Radius.circular(pad),
          ),
        );
      }
    } else if (region == 'lower body garment') {
      final width = (p(23) - p(24)).distance * .42;
      limb(23, 24, width * .5);
      for (final pair in [
        [23, 25],
        [25, 27],
        [24, 26],
        [26, 28],
      ]) {
        limb(pair[0], pair[1], width);
      }
    } else {
      // Orient the torso from the shoulder line, including seated/tilted portraits.
      final a = p(11).dx <= p(12).dx ? p(11) : p(12);
      final b = p(11).dx <= p(12).dx ? p(12) : p(11);
      final delta = b - a;
      final width = delta.distance;
      if (width < 1) return Path();
      final across = delta / width;
      final down = Offset(-across.dy, across.dx);
      final pad = width * .14;
      final hipsVisible = points[23].visible && points[24].visible;
      final length = hipsVisible
          ? (((p(23) + p(24)) / 2) - ((a + b) / 2)).distance
          : width * 1.7;
      final lowerA = a + down * length;
      final lowerB = b + down * length;
      mask.addPolygon([
        a - across * pad,
        b + across * pad,
        lowerB + across * pad,
        lowerA - across * pad,
      ], true);
      for (final pair in [
        [11, 13],
        [13, 15],
        [12, 14],
        [14, 16],
      ]) {
        limb(pair[0], pair[1], pad);
      }
      if (region == 'outfit') {
        final leftHip = p(23).dx < p(24).dx ? p(23) : p(24);
        final rightHip = p(23).dx < p(24).dx ? p(24) : p(23);
        final leftAnkle = p(27).dx < p(28).dx ? p(27) : p(28);
        final rightAnkle = p(27).dx < p(28).dx ? p(28) : p(27);
        mask.addPolygon([
          leftHip - Offset(pad, 0),
          rightHip + Offset(pad, 0),
          rightAnkle + Offset(pad, pad),
          leftAnkle + Offset(-pad, pad),
        ], true);
      }
      // Clip at the shoulder line, rather than an upright-only horizontal box.
      final reach = size.longestSide * 3;
      mask = Path.combine(
        PathOperation.intersect,
        mask,
        Path()..addPolygon([
          a - across * reach,
          b + across * reach,
          b + across * reach + down * reach,
          a - across * reach + down * reach,
        ], true),
      );
    }
    // Visible head/hand landmarks always subtract original-camera regions.
    final face = [
      for (var i = 0; i <= 10; i++)
        if (points[i].visible) p(i),
    ];
    if (face.length >= 3) {
      final bounds = Rect.fromLTRB(
        face.map((v) => v.dx).reduce(math.min),
        face.map((v) => v.dy).reduce(math.min),
        face.map((v) => v.dx).reduce(math.max),
        face.map((v) => v.dy).reduce(math.max),
      );
      mask = Path.combine(
        PathOperation.difference,
        mask,
        Path()..addOval(
          bounds.inflate(math.max(bounds.width * .35, rect.width * .035)),
        ),
      );
    }
    for (final i in [15, 16, 17, 18, 19, 20, 21, 22]) {
      if (points[i].visible) {
        mask = Path.combine(
          PathOperation.difference,
          mask,
          Path()
            ..addOval(Rect.fromCircle(center: p(i), radius: rect.width * .025)),
        );
      }
    }
    return Path.combine(PathOperation.intersect, mask, Path()..addRect(rect));
  }

  @override
  bool shouldReclip(GarmentRegionClipper oldClipper) => true;
}
