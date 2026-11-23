import 'dart:math' as math;

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_skeleton.dart';

/// Completion reflects entered data, independently of the selected step.
class ProductFormSteps extends StatelessWidget {
  const ProductFormSteps({
    super.key,
    required this.labels,
    required this.progress,
    required this.current,
    required this.onSelected,
    this.compact = false,
  });

  final List<String> labels;
  final List<double> progress;
  final int current;
  final ValueChanged<int> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isSkeleton = AppSkeleton.isActive(context);
    final rowHeight = compact ? 32.0 : 46.0;
    final tapSize = compact ? 32.0 : 42.0;
    final circleRadius = compact ? 11.5 : 16.0;
    final haloGap = compact ? 2.5 : 3.5;
    final connOffset = compact ? 15.0 : 21.0;
    final numberFontSize = compact ? 11.0 : 13.0;
    final labelFontSize = compact ? 9.8 : 10.5;
    final activeColor = isSkeleton
        ? SkeletonDesign.highlight
        : SellerDesign.stepActive;
    final primaryFill = isSkeleton ? SkeletonDesign.base : AppColors.primary;
    final primarySoft = isSkeleton ? SkeletonDesign.base : AppColors.primarySoft;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / labels.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: rowHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _Connections(
                        progress: progress,
                        direction: Directionality.of(context),
                        activeColor: activeColor,
                        inactiveColor: AppColors.divider,
                        circleOffset: connOffset,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      labels.length,
                      (i) => SizedBox(
                        width: width,
                        child: Center(
                          child: Semantics(
                            label: 'المرحلة ${i + 1}: ${labels[i]}'.tr,
                            value: '${(progress[i] * 100).round()}٪ مكتمل'.tr,
                            selected: i == current,
                            button: true,
                            child: InkResponse(
                              onTap: AppHaptics.action(() => onSelected(i)),
                              radius: compact ? 17 : 22,
                              child: SizedBox(
                                width: tapSize,
                                height: tapSize,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(end: progress[i].clamp(0, 1)),
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  builder: (context, value, _) {
                                    final isDone = value >= 1;
                                    final isSelected = i == current;
                                    return CustomPaint(
                                      painter: _StepCircle(
                                        progress: value,
                                        selected: isSelected,
                                        radius: circleRadius,
                                        haloGap: haloGap,
                                        surfaceColor: AppColors.surface,
                                        fillStart: AppColors.surfaceAlt,
                                        fillEnd: isDone
                                            ? primaryFill
                                            : primarySoft,
                                        borderActive: activeColor,
                                        borderInactive: AppColors.borderStrong,
                                        haloColor: AppColors.primaryBorder,
                                      ),
                                      child: Center(
                                        child: ExcludeSemantics(
                                          child: Text(
                                            isDone ? '✓' : '${i + 1}',
                                            style: TextStyle(
                                              fontSize: numberFontSize,
                                              fontWeight: AppFont.bold,
                                              color: isDone
                                                  ? AppColors.onPrimary
                                                  : isSelected
                                                  ? (isSkeleton
                                                        ? AppColors.textMuted
                                                        : AppColors.primaryDark)
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 3 : 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                labels.length,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: AppHaptics.action(() => onSelected(i)),
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: labelFontSize,
                          height: 1.3,
                          fontWeight: current == i
                              ? AppFont.bold
                              : AppFont.regular,
                          color: current == i
                              ? AppColors.text
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepCircle extends CustomPainter {
  _StepCircle({
    required this.progress,
    required this.selected,
    required this.radius,
    required this.haloGap,
    required this.surfaceColor,
    required this.fillStart,
    required this.fillEnd,
    required this.borderActive,
    required this.borderInactive,
    required this.haloColor,
  });

  final double progress;
  final bool selected;
  final double radius;
  final double haloGap;
  final Color surfaceColor;
  final Color fillStart;
  final Color fillEnd;
  final Color borderActive;
  final Color borderInactive;
  final Color haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final circle = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, Paint()..color = surfaceColor);

    if (progress > 0) {
      canvas.save();
      canvas.clipPath(Path()..addOval(circle));
      canvas.drawRect(
        Rect.fromLTRB(
          circle.left,
          circle.bottom - circle.height * progress,
          circle.right,
          circle.bottom,
        ),
        Paint()..color = Color.lerp(fillStart, fillEnd, progress)!,
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 1.1
        ..color = (selected || progress >= 1) ? borderActive : borderInactive,
    );

    if (selected) {
      canvas.drawCircle(
        center,
        radius + haloGap,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = haloColor,
      );
    }
  }

  @override
  bool shouldRepaint(_StepCircle old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.radius != radius ||
      old.surfaceColor != surfaceColor ||
      old.fillEnd != fillEnd ||
      old.borderActive != borderActive;
}

class _Connections extends CustomPainter {
  _Connections({
    required this.progress,
    required this.direction,
    required this.activeColor,
    required this.inactiveColor,
    required this.circleOffset,
  });

  final List<double> progress;
  final TextDirection direction;
  final Color activeColor;
  final Color inactiveColor;
  final double circleOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / progress.length;
    final y = size.height / 2;
    for (var i = 0; i < progress.length - 1; i++) {
      final start = cell * (i + .5) + circleOffset;
      final end = cell * (i + 1.5) - circleOffset;
      final left = direction == TextDirection.rtl ? size.width - end : start;
      final right = direction == TextDirection.rtl ? size.width - start : end;
      if (right <= left) continue;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..strokeWidth = 1.4
          ..color = inactiveColor,
      );
      final length = math.max(0, right - left) * progress[i].clamp(0, 1);
      if (length > 0) {
        canvas.drawLine(
          Offset(direction == TextDirection.rtl ? right : left, y),
          Offset(
            direction == TextDirection.rtl ? right - length : left + length,
            y,
          ),
          Paint()
            ..strokeWidth = 1.4
            ..color = activeColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Connections old) =>
      old.progress != progress ||
      old.direction != direction ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor ||
      old.circleOffset != circleOffset;
}
