import 'package:flutter/material.dart';

import '../theme/app_design.dart';
import 'app_haptics.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (isError) {
    AppHaptics.error();
  } else {
    AppHaptics.success();
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? SnackBarDesign.errorBackground
            : SnackBarDesign.background,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: SnackBarDesign.action,
                onPressed: onAction,
              )
            : null,
      ),
    );
}
