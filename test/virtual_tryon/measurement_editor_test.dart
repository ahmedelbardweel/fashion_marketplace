import 'package:fashion_marketplace/core/theme/app_colors.dart';
import 'package:fashion_marketplace/core/widgets/app_text_field.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/body_measurement_store.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/body_measurements.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/body_zone_selector.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/measurement_editor.dart';
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
    testWidgets(
      'enter, save, reopen and delete measurements (${english ? 'en' : 'ar'})',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppLang.isEn = english;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(english ? 'en' : 'ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: InteractiveBodyZoneSelector(
                measurementProfileId: 'customer',
                selectedZone: TryonBodyZone.footwear,
                onZoneSelected: (_) {},
                onContinue: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('edit-measurements')),
        );
        await tester.tap(find.byKey(const ValueKey('edit-measurements')));
        await tester.pumpAndSettle();
        expect(find.byType(MeasurementEditor), findsOneWidget);
        expect(find.byType(AppTextField), findsNWidgets(3));
        expect(
          find.byType(DropdownButtonFormField<ShoeSizeSystem>),
          findsNothing,
        );
        expect(find.byType(ExpansionTile), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.text(english ? 'Save measurements' : 'حفظ القياسات'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MeasurementEditor), findsOneWidget);
        for (final entry in {
          'height': '٦٠',
          'weight': '١٥٠',
          'foot_length': '٣٠',
        }.entries) {
          final input = find.byKey(ValueKey('measurement-${entry.key}'));
          await tester.ensureVisible(input);
          await tester.enterText(input, entry.value);
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.text(english ? 'Save measurements' : 'حفظ القياسات'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MeasurementEditor), findsNothing);
        final stored = await BodyMeasurementStore('customer').load();
        expect(stored![BodyMeasure.height], 60);
        expect(stored[BodyMeasure.weight], 150);
        expect(stored[BodyMeasure.footLength], 30);
        expect(stored.shoeSize, isNull);
        expect(
          stored.values.keys.toSet(),
          BodyMeasurements.customerFields.toSet(),
        );
        expect(
          tester
              .widget<ColorCodedBodyMap>(find.byType(ColorCodedBodyMap))
              .measurements![BodyMeasure.weight],
          150,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('edit-measurements')),
        );
        await tester.tap(find.byKey(const ValueKey('edit-measurements')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AppTextField>(
                find.byKey(const ValueKey('measurement-height')),
              )
              .controller!
              .text,
          '60',
        );
        await tester.tap(find.byTooltip(english ? 'Close' : 'إغلاق'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byTooltip(
            english ? 'Delete saved measurements' : 'حذف القياسات المحفوظة',
          ),
        );
        await tester.tap(
          find.byTooltip(
            english ? 'Delete saved measurements' : 'حذف القياسات المحفوظة',
          ),
        );
        await tester.pumpAndSettle();
        expect(await BodyMeasurementStore('customer').load(), isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('invalid edits cannot save or mutate the original profile', (
    tester,
  ) async {
    final original = BodyMeasurements(
      values: {BodyMeasure.height: 175, BodyMeasure.weight: 70},
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeasurementEditor(
            initial: original,
            onSave: (_) async {
              calls++;
            },
            previewBuilder: (_) => const SizedBox(),
          ),
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('measurement-weight')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('measurement-weight')),
      'bad',
    );
    await tester.tap(find.text('Save measurements'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(original[BodyMeasure.weight], 70);
  });
}
