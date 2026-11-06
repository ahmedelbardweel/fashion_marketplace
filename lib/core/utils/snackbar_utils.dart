import 'package:flutter/material.dart';

import 'app_haptics.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
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
        backgroundColor: isError ? Colors.black : Colors.black,
      ),
    );
}
