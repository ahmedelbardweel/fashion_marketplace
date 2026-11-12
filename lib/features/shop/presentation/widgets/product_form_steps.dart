import 'package:fashion_marketplace/core/utils/app_haptics.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_design.dart';

/// Completion reflects entered data, independently of the selected step.
class ProductFormSteps extends StatelessWidget {
  const ProductFormSteps({
    super.key,
    required this.labels,
    required this.progress,
    required this.current,
    required this.onSelected,
  });
  final List<String> labels;
  final List<double> progress;
  final int current;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth / labels.length;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _Connections(progress, Directionality.of(context)),
                  ),
                ),
                Row(
                  children: List.generate(
                    labels.length,
                    (i) => SizedBox(
                      width: width,
                      child: Center(
                        child: Semantics(
                          label: 'المرحلة ${i + 1}: ${labels[i]}',
                          value: '${(progress[i] * 100).round()}٪ مكتمل',
                          selected: i == current,
                          button: true,
                          child: InkResponse(
                            onTap: AppHaptics.action(() => onSelected(i)),
                            radius: 26,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: progress[i].clamp(0, 1)),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 250),
                                builder: (context, value, _) => CustomPaint(
                                  painter: _StepCircle(value, i == current),
                                  child: Center(
                                    child: ExcludeSemantics(
                                      child: value >= 1
                                          ? const Icon(
                                              AppIcons.check,
                                              size: 20,
                                              color: AppColors.icon,
                                            )
                                          : Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: AppFont.bold,
                                                color: AppColors.text,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              labels.length,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: AppHaptics.action(() => onSelected(i)),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        fontWeight: current == i
                            ? FontWeight.w700
                            : FontWeight.w400,
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

class _StepCircle extends CustomPainter {
  _StepCircle(this.progress, this.selected);
  final double progress;
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final circle = Rect.fromCircle(center: center, radius: 19);
    canvas.drawCircle(center, 19, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(
      Rect.fromLTRB(
        circle.left,
        circle.bottom - circle.height * progress,
        circle.right,
        circle.bottom,
      ),
      Paint()
        ..color = Color.lerp(
          AppColors.surfaceAlt,
          AppColors.primarySoft,
          progress,
        )!,
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      19,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = selected ? SellerDesign.stepActive : AppColors.borderStrong,
    );
    if (selected) {
      canvas.drawCircle(
        center,
        23,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.primaryBorder,
      );
    }
  }

  @override
  bool shouldRepaint(_StepCircle old) =>
      old.progress != progress || old.selected != selected;
}

class _Connections extends CustomPainter {
  _Connections(this.progress, this.direction);
  final List<double> progress;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / progress.length;
    final y = size.height / 2;
    for (var i = 0; i < progress.length - 1; i++) {
      final start = cell * (i + .5) + 25;
      final end = cell * (i + 1.5) - 25;
      final left = direction == TextDirection.rtl ? size.width - end : start;
      final right = direction == TextDirection.rtl ? size.width - start : end;
      if (right <= left) continue;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..strokeWidth = 1.5
          ..color = SellerDesign.stepInactive,
      );
      final length = math.max(0, right - left) * progress[i].clamp(0, 1);
      canvas.drawLine(
        Offset(direction == TextDirection.rtl ? right : left, y),
        Offset(
          direction == TextDirection.rtl ? right - length : left + length,
          y,
        ),
        Paint()
          ..strokeWidth = 1.5
          ..color = SellerDesign.stepActive,
      );
    }
  }

  @override
  bool shouldRepaint(_Connections old) =>
      old.progress != progress || old.direction != direction;
}
