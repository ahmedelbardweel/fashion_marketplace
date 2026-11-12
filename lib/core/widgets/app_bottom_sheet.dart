import 'package:flutter/material.dart';

import '../theme/app_design.dart';

/// Professional bottom sheet helper.
/// Top radius is controlled only by [AppRadii.bottomSheet].
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
    double? maxHeightFactor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: SheetDesign.scrim,
      builder: (context) {
        final media = MediaQuery.of(context);
        final maxHeight =
            media.size.height * (maxHeightFactor ?? SheetDesign.maxHeightFactor);

        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Material(
                color: SheetDesign.background,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(SheetDesign.topRadius),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Standard sheet chrome: handle + optional title + body.
class AppBottomSheetScaffold extends StatelessWidget {
  const AppBottomSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
    this.padding,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                width: SheetDesign.handleWidth,
                height: SheetDesign.handleHeight,
                decoration: BoxDecoration(
                  color: SheetDesign.handle,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: SheetDesign.titleSize,
                  fontWeight: SheetDesign.titleWeight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
          ],
          Flexible(
            child: SingleChildScrollView(
              padding: padding ??
                  const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
