import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fashion_marketplace/core/theme/app_theme.dart';
import 'package:fashion_marketplace/features/auth/presentation/screens/onboarding_screen.dart';

void main() {
  testWidgets(
    'onboarding starts directly with shopper slides and finishes cleanly without overflow',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var finished = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: OnboardingScreen(onFinished: () => finished = true),
            ),
          ),
        ),
      );

      // Starts directly on slide 1 with no role picker or shop option
      expect(find.text('اختر نوع الحساب'), findsNothing);
      expect(find.text('صاحب محل'), findsNothing);
      expect(find.text('تسجيل الدخول بجوجل'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('تصفّح الأقسام في الرئيسية'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('البحث وفلترة المنتجات'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('اختيار القطعة والمقاس'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('مراجعة سلة المشتريات'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('تأكيد الطلب والدفع'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('إتمام الطلب'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('متابعة الطلب والاستلام'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('👋'), findsOneWidget);
      expect(find.text('مرحباً'), findsOneWidget);
      expect(find.text('بس هيك خلصنا'), findsNothing);
      expect(find.text('ابدأ الآن'), findsOneWidget);

      await tester.tap(find.text('ابدأ الآن'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, isTrue);
      expect(AppPreferences.initialOnboardingCompleted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
