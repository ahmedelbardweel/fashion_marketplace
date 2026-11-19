import 'package:fashion_marketplace/core/theme/app_colors.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/body_zone_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    AppLang.isEn = false;
    AppColors.isDark = false;
  });

  for (final english in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('selector fits narrow screen, language=$english dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppLang.isEn = english;
        AppColors.isDark = dark;
        var selected = TryonBodyZone.upperBody;
        var continued = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(english ? 'en' : 'ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => InteractiveBodyZoneSelector(
                  selectedZone: selected,
                  onZoneSelected: (zone) => setState(() => selected = zone),
                  onContinue: () => continued = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(
            tester.element(find.byType(InteractiveBodyZoneSelector)),
          ),
          english ? TextDirection.ltr : TextDirection.rtl,
        );
        if (english) {
          for (final text in tester.widgetList<Text>(find.byType(Text))) {
            expect(text.data ?? '', isNot(matches(RegExp(r'[\u0600-\u06ff]'))));
          }
        }
        final outfit = find.widgetWithText(
          ChoiceChip,
          english ? 'Full outfit / dress' : 'طقم كامل / فستان',
        );
        await tester.ensureVisible(outfit);
        await tester.tap(outfit);
        await tester.pumpAndSettle();
        expect(selected, TryonBodyZone.fullBody);
        expect(tester.widget<ChoiceChip>(outfit).selected, isTrue);
        await tester.tap(find.byType(FilledButton));
        expect(continued, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(240, 550), const Size(360, 300)]) {
    testWidgets('body taps match visible silhouette at $size', (tester) async {
      TryonBodyZone? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: size,
                child: ColorCodedBodyMap(
                  selectedZone: TryonBodyZone.upperBody,
                  onZoneTapped: (zone) => selected = zone,
                ),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(ColorCodedBodyMap));
      final scale = size.width / 240 < size.height / 550
          ? size.width / 240
          : size.height / 550;
      final origin =
          rect.topLeft +
          Offset(size.width / 2, (size.height - 550 * scale) / 2);
      for (final entry in {
        const Offset(0, 180): TryonBodyZone.upperBody,
        const Offset(-67, 240): TryonBodyZone.upperBody,
        const Offset(20, 320): TryonBodyZone.lowerShorts,
        const Offset(-22, 420): TryonBodyZone.lowerPants,
        const Offset(25, 515): TryonBodyZone.footwear,
        const Offset(0, 45): TryonBodyZone.headFace,
        const Offset(-78, 295): TryonBodyZone.wristHand,
      }.entries) {
        selected = null;
        await tester.tapAt(origin + entry.key * scale);
        expect(selected, entry.value);
      }
      for (final point in [
        // Head and hand taps are now valid accessory zones above.
        const Offset(90, 200),
        const Offset(0, 420),
        // Empty space outside the silhouette remains null.
      ]) {
        selected = null;
        await tester.tapAt(origin + point * scale);
        expect(
          selected,
          isNull,
          reason: 'Empty space outside the silhouette is not a try-on zone',
        );
      }
    });
  }
}
