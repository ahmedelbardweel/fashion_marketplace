import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../customer/domain/models/customer_product.dart';
import '../domain/capture_quality.dart';
import '../domain/tryon_session.dart';

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
                  ['مكان اللبس'.tr, 'فحص الإضاءة'.tr, 'التجربة'.tr][i],
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

// =============================================================================
// NEW 3-STAGE ENGINEERED VIRTUAL TRY-ON WIDGETS:
// 1. InteractiveBodyZoneSelector + ColorCodedBodyMap (Stage 1)
// 2. LightingOnlyChecklist + ZoneFramedGuidePainter (Stage 2)
// =============================================================================

class InteractiveBodyZoneSelector extends StatelessWidget {
  const InteractiveBodyZoneSelector({
    super.key,
    required this.selectedZone,
    required this.onZoneSelected,
    required this.onContinue,
    this.selectedProduct,
    this.availableProducts = const [],
    this.onProductSelected,
  });

  final TryonBodyZone selectedZone;
  final ValueChanged<TryonBodyZone> onZoneSelected;
  final VoidCallback onContinue;
  final CustomerProduct? selectedProduct;
  final List<CustomerProduct> availableProducts;
  final ValueChanged<CustomerProduct>? onProductSelected;

  @override
  Widget build(BuildContext context) {
    final activeColor = Color(selectedZone.colorHex);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeColor.withValues(alpha: 0.14),
                            activeColor.withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: activeColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.accessibility_new_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'حدد مكان لبس القطعة على جسمك',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'اضغط على المنطقة الملونة في المجسم أو اختر من القائمة بالأسفل لتركيب القطعة بدقة في مكانها مع الحفاظ التام على الوجه وحجم الجسم.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.45,
                                    color: AppColors.gray700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Selected Product Card (if loaded)
                    if (selectedProduct != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child:
                                    selectedProduct!.tryonReferenceImage != null
                                    ? AppNetworkImage(
                                        selectedProduct!.tryonReferenceImage!,
                                        fit: BoxFit.cover,
                                        cacheWidth: 160,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(AppIcons.garment),
                                      )
                                    : const Icon(AppIcons.garment),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedProduct!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: activeColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'يركب في: ${selectedZone.arabicTitle}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: activeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Interactive Color-Coded Human Body Diagram + Zone Cards
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Face & Body Preservation Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 15,
                                  color: Color(0xFF38BDF8),
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'الوجه وحجم الجسم الأصلي محفوظان 100% • نفس خامات وتفاصيل المنتج',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Interactive Body Diagram
                          SizedBox(
                            height: 290,
                            child: Row(
                              children: [
                                // Left: Interactive Human Silhouette
                                Expanded(
                                  flex: 5,
                                  child: ColorCodedBodyMap(
                                    selectedZone: selectedZone,
                                    onZoneTapped: onZoneSelected,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Right: Quick Color Legend & Direct Toggles
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      for (final zone in TryonBodyZone.values)
                                        _ZoneLegendButton(
                                          zone: zone,
                                          isSelected: selectedZone == zone,
                                          onTap: () => onZoneSelected(zone),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: activeColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: activeColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              selectedZone.bodyPartDescription,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Optional Product Switcher Strip in Step 1
                    if (availableProducts.length > 1 &&
                        onProductSelected != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'أو اختر قطعة أخرى لتجربتها:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: availableProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, index) {
                            final item = availableProducts[index];
                            final isSelected = selectedProduct?.id == item.id;
                            final itemZone = TryonBodyZone.infer(
                              item.name,
                              item.categoryName,
                            );
                            final zoneColor = Color(itemZone.colorHex);
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onProductSelected!(item),
                              child: Container(
                                width: 78,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? zoneColor.withValues(alpha: 0.1)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? zoneColor
                                        : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: item.tryonReferenceImage != null
                                          ? AppNetworkImage(
                                              item.tryonReferenceImage!,
                                              fit: BoxFit.contain,
                                              cacheWidth: 150,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(AppIcons.garment),
                                            )
                                          : const Icon(AppIcons.garment),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom CTA Bar: Proceed to Lighting Check ONLY
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onContinue,
                icon: const Icon(Icons.wb_sunny_outlined, size: 20),
                label: Text(
                  'تأكيد (${selectedZone.shortLabel}) وفحص الإضاءة فقط',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoneLegendButton extends StatelessWidget {
  const _ZoneLegendButton({
    required this.zone,
    required this.isSelected,
    required this.onTap,
  });

  final TryonBodyZone zone;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(zone.colorHex);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.14),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.7),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  zone.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive 2D human body figure with color-coded anatomical zones.
/// Users can tap directly on the chest/arms (upperBody), upper thighs (lowerShorts),
/// calves/legs (lowerPants), or feet (footwear) to select that zone.
class ColorCodedBodyMap extends StatelessWidget {
  const ColorCodedBodyMap({
    super.key,
    required this.selectedZone,
    required this.onZoneTapped,
  });

  final TryonBodyZone selectedZone;
  final ValueChanged<TryonBodyZone> onZoneTapped;

  void _handleTap(Offset localPosition, Size size) {
    if (size.height <= 0 || size.width <= 0) return;
    final ny = (localPosition.dy / size.height).clamp(0.0, 1.0);
    final nx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    // Outer ring / side badge tap toggles fullBody if near the purple aura tab
    if (ny < 0.16) return; // Head is protected
    if (ny >= 0.16 && ny < 0.48) {
      if (nx < 0.16 || nx > 0.84) {
        onZoneTapped(TryonBodyZone.fullBody);
      } else {
        onZoneTapped(TryonBodyZone.upperBody);
      }
    } else if (ny >= 0.48 && ny < 0.65) {
      onZoneTapped(TryonBodyZone.lowerShorts);
    } else if (ny >= 0.65 && ny < 0.86) {
      onZoneTapped(TryonBodyZone.lowerPants);
    } else {
      onZoneTapped(TryonBodyZone.footwear);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleTap(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _ColorCodedBodyPainter(selectedZone: selectedZone),
          ),
        );
      },
    );
  }
}

class _ColorCodedBodyPainter extends CustomPainter {
  const _ColorCodedBodyPainter({required this.selectedZone});
  final TryonBodyZone selectedZone;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final h = size.height;
    final w = size.width;

    final upperColor = Color(TryonBodyZone.upperBody.colorHex);
    final pantsColor = Color(TryonBodyZone.lowerPants.colorHex);
    final shortsColor = Color(TryonBodyZone.lowerShorts.colorHex);
    final fullColor = Color(TryonBodyZone.fullBody.colorHex);
    final footColor = Color(TryonBodyZone.footwear.colorHex);

    final isUpper = selectedZone == TryonBodyZone.upperBody;
    final isPants = selectedZone == TryonBodyZone.lowerPants;
    final isShorts = selectedZone == TryonBodyZone.lowerShorts;
    final isFull = selectedZone == TryonBodyZone.fullBody;
    final isFoot = selectedZone == TryonBodyZone.footwear;

    // 0. Full-Body Aura Frame (Purple) when Full Body is active or as subtle background
    final fullAuraRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.52),
        width: w * 0.78,
        height: h * 0.74,
      ),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      fullAuraRect,
      Paint()
        ..color = fullColor.withValues(alpha: isFull ? 0.22 : 0.05)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      fullAuraRect,
      Paint()
        ..color = fullColor.withValues(alpha: isFull ? 0.95 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFull ? 2.4 : 1.0,
    );

    // 1. Head & Neck (Protected Identity Zone)
    final headCenter = Offset(cx, h * 0.095);
    final headRadius = math.min(w * 0.13, h * 0.058);
    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, h * 0.165),
          width: w * 0.10,
          height: h * 0.035,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF475569),
    );

    // 2. Upper Body Zone (Torso + Shoulders + Arms) — Teal (#00ACC1) or Purple if fullBody
    final topActive = isUpper || isFull;
    final topDrawColor = isFull ? fullColor : upperColor;
    final torsoPath = Path()
      ..moveTo(cx - w * 0.24, h * 0.19) // Left shoulder
      ..lineTo(cx + w * 0.24, h * 0.19) // Right shoulder
      ..lineTo(cx + w * 0.34, h * 0.42) // Right arm outer
      ..lineTo(cx + w * 0.25, h * 0.44) // Right wrist
      ..lineTo(cx + w * 0.18, h * 0.27) // Right armpit
      ..lineTo(cx + w * 0.16, h * 0.47) // Right waist
      ..lineTo(cx - w * 0.16, h * 0.47) // Left waist
      ..lineTo(cx - w * 0.18, h * 0.27) // Left armpit
      ..lineTo(cx - w * 0.25, h * 0.44) // Left wrist
      ..lineTo(cx - w * 0.34, h * 0.42) // Left arm outer
      ..close();

    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = topDrawColor.withValues(alpha: topActive ? 0.88 : 0.32)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = topActive
            ? Colors.white
            : topDrawColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = topActive ? 2.2 : 1.2,
    );

    // 3. Lower Body — Upper Thighs / Shorts Zone (Waist to Knees) — Amber/Orange (#F59E0B)
    final shortsActive = isShorts || isPants || isFull;
    final shortsDrawColor = isFull
        ? fullColor
        : isPants
        ? pantsColor
        : shortsColor;
    final shortsPath = Path()
      ..moveTo(cx - w * 0.16, h * 0.475) // Left waist
      ..lineTo(cx + w * 0.16, h * 0.475) // Right waist
      ..lineTo(cx + w * 0.18, h * 0.64) // Right outer knee
      ..lineTo(cx + w * 0.04, h * 0.64) // Right inner knee
      ..lineTo(cx, h * 0.54) // Crotch
      ..lineTo(cx - w * 0.04, h * 0.64) // Left inner knee
      ..lineTo(cx - w * 0.18, h * 0.64) // Left outer knee
      ..close();

    canvas.drawPath(
      shortsPath,
      Paint()
        ..color = shortsDrawColor.withValues(alpha: shortsActive ? 0.88 : 0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      shortsPath,
      Paint()
        ..color = isShorts
            ? Colors.white
            : shortsDrawColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isShorts ? 2.2 : 1.2,
    );

    // 4. Lower Legs (Knees to Ankles — Full Pants Zone) — Royal Blue (#3B82F6)
    final calvesActive = isPants || isFull;
    final calvesDrawColor = isFull ? fullColor : pantsColor;
    final leftCalf = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w * 0.175, h * 0.645, cx - w * 0.045, h * 0.855),
      const Radius.circular(6),
    );
    final rightCalf = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx + w * 0.045, h * 0.645, cx + w * 0.175, h * 0.855),
      const Radius.circular(6),
    );
    for (final calf in [leftCalf, rightCalf]) {
      canvas.drawRRect(
        calf,
        Paint()
          ..color = calvesDrawColor.withValues(
            alpha: calvesActive ? 0.88 : 0.32,
          )
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        calf,
        Paint()
          ..color = calvesActive
              ? Colors.white
              : calvesDrawColor.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = calvesActive ? 2.2 : 1.2,
      );
    }

    // 5. Footwear / Boots Zone (Feet & Ankles) — Emerald Green (#10B981)
    final leftBoot = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w * 0.21, h * 0.865, cx - w * 0.035, h * 0.96),
      const Radius.circular(8),
    );
    final rightBoot = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx + w * 0.035, h * 0.865, cx + w * 0.21, h * 0.96),
      const Radius.circular(8),
    );
    for (final boot in [leftBoot, rightBoot]) {
      canvas.drawRRect(
        boot,
        Paint()
          ..color = footColor.withValues(alpha: isFoot ? 0.92 : 0.38)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        boot,
        Paint()
          ..color = isFoot ? Colors.white : footColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isFoot ? 2.2 : 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_ColorCodedBodyPainter oldDelegate) =>
      oldDelegate.selectedZone != selectedZone;
}

/// Stage 2 Widget: Lighting-Only Check without body size or pose restrictions.
class LightingOnlyChecklist extends StatelessWidget {
  const LightingOnlyChecklist({
    super.key,
    required this.assessment,
    required this.selectedZone,
    required this.onSkipLighting,
    required this.onChangeZone,
  });

  final CaptureAssessment assessment;
  final TryonBodyZone selectedZone;
  final VoidCallback onSkipLighting;
  final VoidCallback onChangeZone;

  @override
  Widget build(BuildContext context) {
    final zoneColor = Color(selectedZone.colorHex);
    final issue = assessment.issue;
    final statusText = assessment.ready
        ? 'الإضاءة ممتازة! جارٍ تركيب القطعة الآن…'
        : issue == CaptureIssue.dark
        ? 'الإضاءة ضعيفة قليلاً — وجّه ضوءاً نحوك أو اضغط متابعة'
        : issue == CaptureIssue.overexposed
        ? 'الضوء ساطع جداً — خفف الضوء المباشر أو اضغط متابعة'
        : issue == CaptureIssue.backlit
        ? 'الضوء خلفك — استدر قليلاً أو اضغط متابعة'
        : 'جارٍ فحص الإضاءة فقط (بدون مقاسات)…';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onChangeZone,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: zoneColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: zoneColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: zoneColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedZone.shortLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: zoneColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 13, color: zoneColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedZone.framingInstruction,
            style: TextStyle(fontSize: 12, color: AppColors.gray500),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: assessment.progress > 0 ? assessment.progress : null,
              minHeight: 5,
              backgroundColor: AppColors.gray100,
              color: zoneColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                assessment.lightOk
                    ? Icons.wb_sunny_rounded
                    : Icons.wb_twilight_rounded,
                size: 16,
                color: assessment.lightOk ? zoneColor : AppColors.gray500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'فحص الإضاءة فقط — لا يتطلب قياسات الجسم أو الوقوف بوضعية محددة.',
                  style: TextStyle(fontSize: 11, color: AppColors.gray700),
                ),
              ),
              TextButton.icon(
                onPressed: onSkipLighting,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text(
                  'البدء فوراً',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Clean camera overlay frame colored with the user's chosen TryonBodyZone.
class ZoneFramedGuidePainter extends CustomPainter {
  const ZoneFramedGuidePainter({required this.zone});
  final TryonBodyZone zone;

  @override
  void paint(Canvas canvas, Size size) {
    final color = Color(zone.colorHex);
    final rect = switch (zone) {
      TryonBodyZone.upperBody => Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.44),
        width: size.width * 0.72,
        height: size.height * 0.56,
      ),
      TryonBodyZone.lowerPants => Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.60),
        width: size.width * 0.66,
        height: size.height * 0.64,
      ),
      TryonBodyZone.lowerShorts => Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.54),
        width: size.width * 0.68,
        height: size.height * 0.48,
      ),
      TryonBodyZone.fullBody => Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.50),
        width: size.width * 0.76,
        height: size.height * 0.78,
      ),
      TryonBodyZone.footwear => Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.70),
        width: size.width * 0.68,
        height: size.height * 0.36,
      ),
    };

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(ZoneFramedGuidePainter oldDelegate) =>
      oldDelegate.zone != zone;
}
