import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native system haptics; does not intercept gestures or delay app actions.
class AppHaptics {
  AppHaptics._();
  static final _clock = Stopwatch()..start();
  static int _lastTap = -1000;
  static int _lastResult = -1000;
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static void _emit(Future<void> Function() effect, {bool result = false}) {
    if (!_supported) return;
    final now = _clock.elapsedMilliseconds;
    if (now - (result ? _lastResult : _lastTap) < (result ? 250 : 80)) return;
    if (result) {
      _lastResult = now;
    } else {
      _lastTap = now;
    }
    unawaited(_tryEffect(effect));
  }

  static Future<void> _tryEffect(Future<void> Function() effect) async {
    try {
      await effect();
    } on PlatformException {
      /* Unsupported device/engine. */
    } on MissingPluginException {
      /* Desktop tests and unavailable native host. */
    }
  }

  static void tap() => _emit(HapticFeedback.lightImpact);
  static void selection() => _emit(HapticFeedback.selectionClick);
  static void success() => _emit(HapticFeedback.mediumImpact, result: true);
  static void error() => _emit(HapticFeedback.heavyImpact, result: true);

  static VoidCallback? action(VoidCallback? callback) => callback == null
      ? null
      : () {
          tap();
          callback();
        };
  static ValueChanged<T>? change<T>(ValueChanged<T>? callback) =>
      callback == null
      ? null
      : (value) {
          selection();
          callback(value);
        };
  static Future<void> Function() refresh(Future<void> Function() callback) =>
      () async {
        selection();
        await callback();
      };
  @visibleForTesting
  static void resetThrottle() {
    _lastTap = -1000;
    _lastResult = -1000;
  }
}
