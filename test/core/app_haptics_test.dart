import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:fashion_marketplace/core/widgets/app_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    AppHaptics.resetThrottle();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate')
            calls.add(call.arguments as String);
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('native tap and result patterns on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      var actions = 0;
      AppHaptics.action(() => actions++)!();
      AppHaptics.action(() => actions++)!();
      AppHaptics.success();
      await Future<void>.delayed(Duration.zero);
      expect(actions, 2);
      expect(calls, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
      AppHaptics.resetThrottle();
      String? selected;
      AppHaptics.change<String>((v) => selected = v)!('M');
      AppHaptics.error();
      await Future<void>.delayed(Duration.zero);
      expect(selected, 'M');
      expect(calls.sublist(2), [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.heavyImpact',
      ]);
    });
  }
  test('disabled callbacks remain null and desktop does not vibrate', () async {
    expect(AppHaptics.action(null), isNull);
    expect(AppHaptics.change<String>(null), isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var called = false;
    AppHaptics.action(() => called = true)!();
    await Future<void>.delayed(Duration.zero);
    expect(called, isTrue);
    expect(calls, isEmpty);
  });
  test(
    'unavailable haptics never prevent the action and async refresh is awaited',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (_) async => throw PlatformException(code: 'unavailable'),
          );
      var called = false;
      await AppHaptics.refresh(() async {
        await Future<void>.delayed(Duration.zero);
        called = true;
      })();
      expect(called, isTrue);
    },
  );
  testWidgets(
    'shared buttons vibrate once and loading buttons do not vibrate',
    (tester) async {
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(label: 'حفظ', onPressed: () => actions++),
          ),
        ),
      );
      await tester.tap(find.text('حفظ'));
      await tester.pump();
      expect(actions, 1);
      expect(calls, ['HapticFeedbackType.lightImpact']);
      AppHaptics.resetThrottle();
      calls.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'حفظ',
              isLoading: true,
              onPressed: () => actions++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('حفظ'), warnIfMissed: false);
      await tester.pump();
      expect(actions, 1);
      expect(calls, isEmpty);
    },
  );
}
