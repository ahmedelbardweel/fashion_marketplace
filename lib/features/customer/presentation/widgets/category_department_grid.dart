import 'package:flutter/material.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../admin/domain/models/catalog_models.dart';

/// Reference layout: three columns, softly tinted circles and outlined symbols.
class CategoryDepartmentGrid extends StatelessWidget {
  const CategoryDepartmentGrid({
    super.key,
    required this.categories,
    required this.onSelected,
  });
  final List<CatalogCategory> categories;
  final ValueChanged<CatalogCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final roots = categories.where((c) => c.parentId == null).toList();
    if (roots.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              (constraints.maxWidth - (AppSpacing.pageGutter * 2)).clamp(
                0.0,
                double.infinity,
              );
          final minContentWidth =
              (roots.length * HomeDesign.departmentSquareSize) +
              ((roots.length - 1) * 3.0);
          final needsScroll = minContentWidth > availableWidth;

          final row = ConstrainedBox(
            constraints: BoxConstraints(minWidth: availableWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < roots.length; i++) ...[
                  if (needsScroll && i > 0)
                    const SizedBox(width: HomeDesign.departmentGridGap),
                  _tile(context, roots[i]),
                ],
              ],
            ),
          );

          if (!needsScroll) {
            return Padding(padding: AppSpacing.pageHorizontal, child: row);
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.pageHorizontal,
            child: row,
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, CatalogCategory category) {
    final isSkeleton = AppSkeleton.isActive(context);
    final label = category.name.tr;
    final labelStyle = TextStyle(
      fontSize: HomeDesign.departmentLabelSize,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AppColors.text,
    );
    final labelWidget = isSkeleton
        ? Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: labelStyle,
          )
        : label.contains(' ')
        ? Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: labelStyle,
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: labelStyle),
          );

    return SizedBox(
      width: HomeDesign.departmentSquareSize,
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            HomeDesign.departmentCornerRadius,
          ),
          onTap: () => onSelected(category),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isSkeleton
                  ? Bone.square(
                      size: HomeDesign.departmentSquareSize,
                      borderRadius: BorderRadius.circular(
                        HomeDesign.departmentCornerRadius,
                      ),
                    )
                  : Container(
                      width: HomeDesign.departmentSquareSize,
                      height: HomeDesign.departmentSquareSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          HomeDesign.departmentCornerRadius,
                        ),
                        color: AppColors.primary.withValues(
                          alpha: AppColors.isDark ? 0.14 : 0.08,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: HomeDesign.departmentIconSize,
                          height: HomeDesign.departmentIconSize,
                          child: CustomPaint(
                            painter: _DepartmentIcon(
                              category.iconKey ?? '',
                              AppColors.primary,
                              AppColors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: AppSpacing.xs),
              labelWidget,
            ],
          ),
        ),
      ),
    );
  }
}

/// Small vector artwork, so the application palette works in both themes.
class _DepartmentIcon extends CustomPainter {
  _DepartmentIcon(this.kind, this.fill, this.ink);
  final String kind;
  final Color fill, ink;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final outline = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    void shape(Path path) {
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, outline);
    }

    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), outline);
    void box(Rect rect, double radius) {
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
      shape(path);
    }

    switch (kind) {
      case 'clothing':
        shape(
          Path()
            ..moveTo(22, 10)
            ..lineTo(13, 14)
            ..lineTo(4, 25)
            ..lineTo(15, 33)
            ..lineTo(20, 27)
            ..lineTo(20, 55)
            ..lineTo(45, 55)
            ..lineTo(45, 27)
            ..lineTo(50, 33)
            ..lineTo(60, 25)
            ..lineTo(51, 14)
            ..lineTo(42, 10)
            ..quadraticBezierTo(32, 24, 22, 10)
            ..close(),
        );
        break;
      case 'shoes':
        shape(
          Path()
            ..moveTo(7, 42)
            ..quadraticBezierTo(29, 38, 36, 20)
            ..lineTo(46, 26)
            ..lineTo(53, 16)
            ..lineTo(57, 18)
            ..lineTo(58, 53)
            ..lineTo(45, 53)
            ..lineTo(44, 46)
            ..lineTo(31, 53)
            ..lineTo(7, 53)
            ..quadraticBezierTo(2, 48, 7, 42)
            ..close(),
        );
        line(28, 33, 35, 36);
        line(33, 27, 40, 30);
        line(8, 48, 29, 48);
        break;
      case 'accessories':
        box(const Rect.fromLTWH(24, 4, 16, 56), 5);
        box(const Rect.fromLTWH(14, 16, 36, 34), 13);
        canvas.drawCircle(
          const Offset(32, 33),
          11,
          Paint()..color = ink.withValues(alpha: .8),
        );
        final hand = Paint()
          ..color = fill
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(32, 33), const Offset(32, 25), hand);
        canvas.drawLine(const Offset(32, 33), const Offset(38, 36), hand);
        break;
      case 'bags':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(23, 9, 19, 23),
            const Radius.circular(7),
          ),
          outline,
        );
        box(const Rect.fromLTWH(7, 24, 50, 32), 5);
        line(8, 35, 56, 35);
        box(const Rect.fromLTWH(28, 31, 8, 11), 2);
        break;
      case 'electronics':
        box(const Rect.fromLTWH(5, 11, 53, 35), 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(11, 17, 41, 21),
            const Radius.circular(2),
          ),
          Paint()..color = ink.withValues(alpha: .16),
        );
        line(25, 47, 22, 54);
        line(39, 47, 42, 54);
        line(19, 55, 45, 55);
        break;
      case 'beauty':
        box(const Rect.fromLTWH(24, 5, 16, 12), 2);
        box(const Rect.fromLTWH(27, 17, 10, 6), 1);
        box(const Rect.fromLTWH(14, 23, 36, 34), 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(21, 31, 22, 16),
            const Radius.circular(3),
          ),
          Paint()..color = ink.withValues(alpha: .14),
        );
        canvas.drawPath(
          Path()
            ..moveTo(32, 33)
            ..quadraticBezierTo(33, 38, 38, 39)
            ..quadraticBezierTo(33, 40, 32, 45)
            ..quadraticBezierTo(31, 40, 26, 39)
            ..quadraticBezierTo(31, 38, 32, 33)
            ..close(),
          Paint()..color = ink,
        );
        break;
      default:
        for (final x in [9.0, 35.0]) {
          for (final y in [9.0, 35.0]) {
            box(Rect.fromLTWH(x, y, 20, 20), 5);
          }
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DepartmentIcon old) =>
      old.kind != kind || old.fill != fill || old.ink != ink;
}
