import 'dart:async';

import 'package:fashion_marketplace/core/theme/app_design.dart';
import 'package:fashion_marketplace/core/widgets/app_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AppRefreshIndicator.resetNavTapTracker);

  testWidgets(
    'shows AppLogoMark without CircularProgressIndicator while pulling and refreshing',
    (tester) async {
      final completer = Completer<void>();
      var refreshCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppRefreshIndicator(
              onRefresh: () {
                refreshCalls++;
                return completer.future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120, child: Center(child: Text('Item 1'))),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppLogoMark), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.fling(
        find.byType(ListView),
        const Offset(0, 320),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(refreshCalls, 1);
      expect(find.byType(AppLogoMark), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AppLogoMark), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'double-tapping active bottom nav tab triggers AppRefreshIndicator with AppLogoMark',
    (tester) async {
      final completer = Completer<void>();
      var refreshCalls = 0;
      var navCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppRefreshIndicator(
              onRefresh: () {
                refreshCalls++;
                return completer.future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 1200, child: Text('Top content')),
                ],
              ),
            ),
            bottomNavigationBar: TextButton(
              onPressed: () => AppRefreshIndicator.handleBottomNavTap(
                targetRoute: '/customer/home',
                selected: true,
                currentLocation: '/customer/home',
                onNavigate: () => navCalls++,
              ),
              child: const Text('الرئيسية'),
            ),
          ),
        ),
      );

      // Single tap on already-selected tab should not trigger refresh.
      await tester.tap(find.text('الرئيسية'));
      await tester.pump();
      expect(refreshCalls, 0);
      expect(navCalls, 0);
      expect(find.byType(AppLogoMark), findsNothing);

      // Second quick tap triggers AppRefreshIndicator with AppLogoMark.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('الرئيسية'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(refreshCalls, 1);
      expect(navCalls, 0);
      expect(find.byType(AppLogoMark), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AppLogoMark), findsNothing);
    },
  );
}
