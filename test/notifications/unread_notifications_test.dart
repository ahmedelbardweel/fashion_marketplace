import 'package:fashion_marketplace/core/notifications/read_notifications_provider.dart';
import 'package:fashion_marketplace/features/admin/domain/models/catalog_models.dart';
import 'package:fashion_marketplace/features/customer/presentation/providers/customer_providers.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/customer_notifications_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/widgets/customer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  List<AdminNotification> sampleNotifications(int count) => [
    for (var i = 0; i < count; i++)
      AdminNotification(
        id: 'notif-$i',
        title: 'Title $i',
        body: 'Body $i',
        audience: 'customer',
        createdAt: DateTime(2026, 1, 1, 10, i),
      ),
  ];

  test('countUnreadNotifications excludes read notification IDs', () {
    final items = sampleNotifications(3);
    expect(countUnreadNotifications(items, <String>{}), 3);
    expect(countUnreadNotifications(items, {'notif-0'}), 2);
    expect(
      countUnreadNotifications(items, {'notif-0', 'notif-1', 'notif-2'}),
      0,
    );
  });

  testWidgets(
    'CustomerAppBar shows unread count badge and clears after viewing notifications',
    (tester) async {
      final items = sampleNotifications(3);
      final container = ProviderContainer(
        overrides: [
          customerNotificationsProvider.overrideWith((ref) async => items),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              appBar: CustomerAppBar(title: 'الرئيسية', showBack: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CustomerNotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(customerUnreadNotificationsCountProvider), 0);
    },
  );
}
