import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../customer/domain/models/customer_product.dart';
import '../domain/body_measurements.dart';
import '../domain/tryon_session.dart';

String _zoneLabel(TryonBodyZone zone) => switch (zone) {
  TryonBodyZone.upperBody => 'الجزء العلوي'.tr,
  TryonBodyZone.lowerPants => 'بنطلون'.tr,
  TryonBodyZone.lowerShorts => 'شورت'.tr,
  TryonBodyZone.fullBody => 'طقم كامل / فستان'.tr,
  TryonBodyZone.footwear => 'الأحذية'.tr,
};

class InteractiveBodyZoneSelector extends StatelessWidget {
  const InteractiveBodyZoneSelector({
    super.key,
    required this.selectedZone,
    required this.onZoneSelected,
    required this.onContinue,
    this.selectedProduct,
    this.availableProducts = const [],
    this.onProductSelected,
    this.measurementProfileId = 'guest',
  });

  final TryonBodyZone selectedZone;
  final ValueChanged<TryonBodyZone> onZoneSelected;
  final VoidCallback onContinue;
  final CustomerProduct? selectedProduct;
  final List<CustomerProduct> availableProducts;
  final ValueChanged<CustomerProduct>? onProductSelected;
  final String measurementProfileId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selectedProduct case final product?) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Color(
                                selectedZone.colorHex,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: product.tryonReferenceImage != null
                                      ? AppNetworkImage(
                                          product.tryonReferenceImage!,
                                          fit: BoxFit.cover,
                                          cacheWidth: 144,
                                          errorBuilder: (_, _, _) => Icon(
                                            AppIcons.garment,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Icon(
                                          AppIcons.garment,
                                          color: AppColors.primary,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Color(selectedZone.colorHex),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _zoneLabel(selectedZone),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(
                                                selectedZone.colorHex,
                                              ),
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
                      Text(
                        'اختر منطقة التجربة'.tr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final zone in TryonBodyZone.values)
                            ChoiceChip(
                              avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Color(zone.colorHex),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              label: Text(_zoneLabel(zone)),
                              selected: selectedZone == zone,
                              onSelected: (_) => onZoneSelected(zone),
                              selectedColor: Color(
                                zone.colorHex,
                              ).withValues(alpha: 0.18),
                              backgroundColor: AppColors.surface,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: selectedZone == zone
                                    ? Color(zone.colorHex)
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: selectedZone == zone
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                              side: BorderSide(
                                color: selectedZone == zone
                                    ? Color(zone.colorHex)
                                    : Color(
                                        zone.colorHex,
                                      ).withValues(alpha: 0.35),
                                width: selectedZone == zone ? 1.6 : 1.0,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1325),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Color(
                              selectedZone.colorHex,
                            ).withValues(alpha: 0.55),
                            width: 1.4,
                          ),
                        ),
                        child: SizedBox(
                          height: (constraints.maxHeight * .64).clamp(
                            320.0,
                            450.0,
                          ),
                          child: ColorCodedBodyMap(
                            selectedZone: selectedZone,
                            onZoneTapped: onZoneSelected,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onContinue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'ابدأ التجربة'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(AppIcons.forward, size: 18),
                      ],
                    ),
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

/// Drawing and hit testing share a fixed coordinate system: resizing never
/// stretches the figure or changes which anatomical region receives a tap.
class ColorCodedBodyMap extends StatelessWidget {
  const ColorCodedBodyMap({
    super.key,
    required this.selectedZone,
    required this.onZoneTapped,
    this.measurements,
  });
  final TryonBodyZone selectedZone;
  final ValueChanged<TryonBodyZone> onZoneTapped;
  final BodyMeasurements? measurements;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final geometry = _BodyGeometry(size, measurements);
      return Semantics(
        image: true,
        label: 'دليل مناطق الجسم'.tr,
        value: _zoneLabel(selectedZone),
        child: GestureDetector(
          onTapUp: (details) {
            final zone = geometry.hitTest(details.localPosition);
            if (zone != null) onZoneTapped(zone);
          },
          child: CustomPaint(
            size: size,
            painter: _BodyPainter(
              selectedZone: selectedZone,
              primary: AppColors.primary,
              neutral: AppColors.borderStrong,
              surface: AppColors.surfaceAlt,
              outline: AppColors.textMuted,
              measurements: measurements,
            ),
          ),
        ),
      );
    },
  );
}

class _BodyGeometry {
  _BodyGeometry(this.size, [BodyMeasurements? measurements])
    : proportions = BodyProportions(measurements);
  final Size size;
  final BodyProportions proportions;
  late final Path upperPath = projectPath(upper);
  late final Path shortsPath = projectPath(shorts);
  late final Path calvesPath = projectPath(calves);
  late final Path feetPath = projectPath(feet);
  late final double _drawingWidth = math.max(
    240,
    upperPath.getBounds().width + 40,
  );
  late final double scale = math.min(
    size.width / _drawingWidth,
    size.height / math.max(550, 550 * proportions.heightScale),
  );
  late final Offset origin = Offset(
    size.width / 2,
    (size.height - scale * 550 * proportions.heightScale) / 2,
  );

  Offset project(Offset p) {
    if (proportions.measurements == null) return p;
    var x = p.dx * proportions.widthAt(p.dy);
    if (p.dy > 492) {
      final blend = ((p.dy - 492) / 35).clamp(0.0, 1.0);
      final footX =
          p.dx.sign *
          (22 * proportions.widthAt(492) +
              (p.dx.abs() - 22) *
                  proportions.footScale /
                  proportions.heightRatio);
      x += (footX - x) * blend;
    }
    final inseam = proportions.measurements?[BodyMeasure.inseam];
    final legRatio = inseam == null
        ? 1.0
        : (inseam / (175 * proportions.heightRatio * .45)).clamp(.75, 1.25);
    final crotch = 527 - (527 - 292) * legRatio;
    final y = p.dy < 292
        ? p.dy * crotch / 292
        : crotch + (p.dy - 292) * legRatio;
    return Offset(x, y * proportions.heightScale);
  }

  Path projectPath(Path source) {
    if (proportions.measurements == null) return source;
    final result = Path();
    for (final contour in source.computeMetrics()) {
      final first = project(contour.getTangentForOffset(0)!.position);
      result.moveTo(first.dx, first.dy);
      for (var distance = 2.0; distance < contour.length; distance += 2) {
        final point = project(contour.getTangentForOffset(distance)!.position);
        result.lineTo(point.dx, point.dy);
      }
      final last = project(
        contour.getTangentForOffset(contour.length)!.position,
      );
      result.lineTo(last.dx, last.dy);
      if (contour.isClosed) result.close();
    }
    return result;
  }

  static Path mirror(Path path) => path.transform(
    Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
  );

  static final head = Path()
    ..moveTo(0, 18)
    ..cubicTo(-20, 18, -23, 34, -21, 50)
    ..cubicTo(-20, 65, -12, 78, 0, 80)
    ..cubicTo(12, 78, 20, 65, 21, 50)
    ..cubicTo(23, 34, 20, 18, 0, 18)
    ..close();
  static final neck = Path()
    ..moveTo(-11, 73)
    ..lineTo(-11, 90)
    ..quadraticBezierTo(-15, 98, -23, 101)
    ..quadraticBezierTo(0, 115, 23, 101)
    ..quadraticBezierTo(15, 98, 11, 90)
    ..lineTo(11, 73)
    ..close();

  static final upper = Path()
    ..moveTo(-12, 95)
    ..quadraticBezierTo(-23, 100, -40, 104)
    ..cubicTo(-51, 108, -55, 121, -57, 139)
    ..lineTo(-66, 190)
    ..quadraticBezierTo(-73, 228, -80, 270)
    ..lineTo(-66, 274)
    ..quadraticBezierTo(-51, 234, -49, 206)
    ..lineTo(-39, 157)
    ..cubicTo(-37, 185, -28, 210, -29, 245)
    ..quadraticBezierTo(0, 250, 29, 245)
    ..cubicTo(28, 210, 37, 185, 39, 157)
    ..lineTo(49, 206)
    ..quadraticBezierTo(51, 234, 66, 274)
    ..lineTo(80, 270)
    ..quadraticBezierTo(73, 228, 66, 190)
    ..lineTo(57, 139)
    ..cubicTo(55, 121, 51, 108, 40, 104)
    ..quadraticBezierTo(23, 100, 12, 95)
    ..quadraticBezierTo(0, 105, -12, 95)
    ..close();

  static final hand = Path()
    ..moveTo(-79, 269)
    ..lineTo(-67, 273)
    ..quadraticBezierTo(-64, 282, -63, 290)
    ..quadraticBezierTo(-64, 295, -68, 289)
    ..lineTo(-70, 285)
    ..lineTo(-71, 304)
    ..quadraticBezierTo(-77, 312, -82, 302)
    ..quadraticBezierTo(-87, 291, -79, 269)
    ..close();

  static final shorts = Path()
    ..moveTo(-29, 245)
    ..quadraticBezierTo(0, 250, 29, 245)
    ..cubicTo(36, 264, 37, 282, 35, 303)
    ..lineTo(29, 356)
    ..lineTo(9, 356)
    ..lineTo(5, 306)
    ..quadraticBezierTo(0, 290, -5, 306)
    ..lineTo(-9, 356)
    ..lineTo(-29, 356)
    ..lineTo(-35, 303)
    ..cubicTo(-37, 282, -36, 264, -29, 245)
    ..close();

  static final calf = Path()
    ..moveTo(-29, 356)
    ..lineTo(-9, 356)
    ..cubicTo(-8, 378, -7, 390, -10, 410)
    ..cubicTo(-13, 439, -16, 468, -15, 492)
    ..lineTo(-29, 492)
    ..cubicTo(-28, 468, -34, 439, -35, 413)
    ..cubicTo(-36, 392, -30, 375, -29, 356)
    ..close();

  static final foot = Path()
    ..moveTo(-29, 492)
    ..lineTo(-15, 492)
    ..lineTo(-14, 516)
    ..quadraticBezierTo(-14, 525, -22, 527)
    ..lineTo(-42, 527)
    ..quadraticBezierTo(-49, 525, -45, 518)
    ..quadraticBezierTo(-31, 503, -29, 492)
    ..close();

  static final calves = Path()
    ..addPath(calf, Offset.zero)
    ..addPath(mirror(calf), Offset.zero);
  static final feet = Path()
    ..addPath(foot, Offset.zero)
    ..addPath(mirror(foot), Offset.zero);

  TryonBodyZone? hitTest(Offset position) {
    if (scale <= 0) return null;
    final point = (position - origin) / scale;
    if (upperPath.contains(point)) return TryonBodyZone.upperBody;
    if (shortsPath.contains(point)) return TryonBodyZone.lowerShorts;
    if (calvesPath.contains(point)) return TryonBodyZone.lowerPants;
    if (feetPath.contains(point)) return TryonBodyZone.footwear;
    return null;
  }
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({
    required this.selectedZone,
    required this.primary,
    required this.neutral,
    required this.surface,
    required this.outline,
    this.measurements,
  });
  final TryonBodyZone selectedZone;
  final Color primary, neutral, surface, outline;
  final BodyMeasurements? measurements;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _BodyGeometry(size, measurements);
    canvas.save();
    canvas.translate(geometry.origin.dx, geometry.origin.dy);
    canvas.scale(geometry.scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: geometry.project(const Offset(0, 535)),
        width: 115 * geometry.proportions.widthAt(492),
        height: 10,
      ),
      Paint()..color = neutral.withValues(alpha: .3),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-110, 58, 220, 440),
      Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: .08),
            primary.withValues(alpha: 0),
          ],
        ).createShader(const Rect.fromLTWH(-110, 58, 220, 440)),
    );

    void draw(
      Path path, {
      required Color zoneColor,
      bool active = false,
      bool neutralPart = false,
    }) {
      path = geometry.projectPath(path);
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: neutralPart
                ? [
                    const Color(0xFF475569).withValues(alpha: 0.72),
                    const Color(0xFF334155).withValues(alpha: 0.72),
                  ]
                : active
                ? [
                    Color.lerp(zoneColor, AppPalette.white, .20)!,
                    zoneColor,
                    Color.lerp(zoneColor, AppPalette.ink, .14)!,
                  ]
                : [
                    zoneColor.withValues(alpha: 0.38),
                    zoneColor.withValues(alpha: 0.28),
                    zoneColor.withValues(alpha: 0.22),
                  ],
            stops: neutralPart ? const [0, 1] : const [0, .55, 1],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = neutralPart
              ? const Color(0xFF94A3B8).withValues(alpha: 0.55)
              : active
              ? Colors.white
              : zoneColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.4 : 1.3
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final full = selectedZone == TryonBodyZone.fullBody;
    final fullColor = Color(TryonBodyZone.fullBody.colorHex);
    final upperColor = Color(TryonBodyZone.upperBody.colorHex);
    final shortsColor = Color(TryonBodyZone.lowerShorts.colorHex);
    final pantsColor = Color(TryonBodyZone.lowerPants.colorHex);
    final feetColor = Color(TryonBodyZone.footwear.colorHex);

    // Outer full-body / dress indicator frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-92, 86, 184, 412),
        const Radius.circular(28),
      ),
      Paint()
        ..color = full ? fullColor : fullColor.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = full ? 2.6 : 1.2,
    );

    draw(_BodyGeometry.neck, zoneColor: outline, neutralPart: true);
    draw(_BodyGeometry.head, zoneColor: outline, neutralPart: true);
    draw(_BodyGeometry.hand, zoneColor: outline, neutralPart: true);
    draw(
      _BodyGeometry.mirror(_BodyGeometry.hand),
      zoneColor: outline,
      neutralPart: true,
    );
    draw(
      _BodyGeometry.upper,
      zoneColor: full ? fullColor : upperColor,
      active: full || selectedZone == TryonBodyZone.upperBody,
    );
    draw(
      _BodyGeometry.shorts,
      zoneColor: full
          ? fullColor
          : selectedZone == TryonBodyZone.lowerPants
          ? pantsColor
          : shortsColor,
      active:
          full ||
          selectedZone == TryonBodyZone.lowerShorts ||
          selectedZone == TryonBodyZone.lowerPants,
    );
    draw(
      _BodyGeometry.calves,
      zoneColor: full ? fullColor : pantsColor,
      active: full || selectedZone == TryonBodyZone.lowerPants,
    );
    draw(
      _BodyGeometry.feet,
      zoneColor: feetColor,
      active: selectedZone == TryonBodyZone.footwear,
    );

    // Subtle collarbones and joint contours give the neutral mannequin form.
    final detail = Paint()
      ..color = outline.withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final collar = Path()
      ..moveTo(-30, 115)
      ..quadraticBezierTo(-16, 113, -5, 121);
    canvas.drawPath(geometry.projectPath(collar), detail);
    canvas.drawPath(geometry.projectPath(_BodyGeometry.mirror(collar)), detail);
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        geometry.projectPath(
          Path()
            ..moveTo(12 * side, 367)
            ..quadraticBezierTo(20 * side, 372, 27 * side, 367),
        ),
        detail,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter oldDelegate) =>
      selectedZone != oldDelegate.selectedZone ||
      measurements != oldDelegate.measurements ||
      primary != oldDelegate.primary ||
      neutral != oldDelegate.neutral ||
      surface != oldDelegate.surface ||
      outline != oldDelegate.outline;
}
