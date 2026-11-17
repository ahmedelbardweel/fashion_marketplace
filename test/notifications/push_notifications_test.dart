import 'package:fashion_marketplace/core/notifications/push_notification_provider.dart';
import 'package:fashion_marketplace/core/notifications/push_notification_service.dart';
import 'package:fashion_marketplace/core/notifications/push_notification_settings_card.dart';
import 'package:fashion_marketplace/features/admin/domain/models/catalog_models.dart';
import 'package:fashion_marketplace/features/shop/data/shop_catalog_repository.dart';
import 'package:fashion_marketplace/features/shop/domain/models/shop.dart';
import 'package:fashion_marketplace/features/shop/presentation/providers/shop_catalog_providers.dart';
import 'package:fashion_marketplace/features/shop/presentation/providers/shop_providers.dart';
import 'package:fashion_marketplace/features/shop/presentation/screens/shop_notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePushController extends PushNotificationController {
  _FakePushController(super.ref, PushNotificationState initial) {
    state = initial;
  }

  bool requested = false;
  bool? lastToggledEnabled;

  @override
  Future<PushPermissionStatus> requestPermissionAndEnable() async {
    requested = true;
    state = state.copyWith(
      permissionStatus: PushPermissionStatus.granted,
      notificationsEnabled: true,
    );
    return PushPermissionStatus.granted;
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    lastToggledEnabled = enabled;
    state = state.copyWith(notificationsEnabled: enabled);
  }
}

class _FakeShopCatalogActionController extends ShopCatalogActionController {
  _FakeShopCatalogActionController(super.ref);

  String? lastTitle;
  String? lastBody;
  String? lastScope;

  @override
  Future<bool> sendNotification({
    required String title,
    required String body,
    String scope = 'shop_customers',
  }) async {
    lastTitle = title;
    lastBody = body;
    lastScope = scope;
    return true;
  }
}

class _FakeShopCatalogRepository extends Fake implements ShopCatalogRepository {
  @override
  String mapError(Object error) => error.toString();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AdminNotification parses shop sender fields and audience labels', () {
    final shopCustomers = AdminNotification.fromMap({
      'id': 'n-1',
      'title': 'عرض خاص',
      'body': 'خصم 20% لعملائنا',
      'audience': 'customer',
      'shop_id': 'shop-1',
      'sender_role': 'shop',
      'target_scope': 'shop_customers',
      'created_at': '2026-11-17T10:00:00Z',
    });
    expect(shopCustomers.isSentByShop, isTrue);
    expect(shopCustomers.shopId, 'shop-1');
    expect(shopCustomers.targetScope, 'shop_customers');
    expect(shopCustomers.audienceLabel, 'عملاء المحل');

    final allCustomers = AdminNotification.fromMap({
      'id': 'n-2',
      'title': 'تشكيلة جديدة',
      'body': 'وصلت الآن',
      'audience': 'customer',
      'sender_role': 'shop',
      'target_scope': 'all_customers',
      'created_at': '2026-11-17T10:00:00Z',
    });
    expect(allCustomers.audienceLabel, 'جميع العملاء');
  });

  testWidgets('PushNotificationSettingsRow shows enable button and toggles', (
    tester,
  ) async {
    late _FakePushController controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationControllerProvider.overrideWith((ref) {
            controller = _FakePushController(
              ref,
              const PushNotificationState(
                permissionStatus: PushPermissionStatus.denied,
                notificationsEnabled: false,
              ),
            );
            return controller;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PushNotificationSettingsCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إشعارات الهاتف'), findsOneWidget);
    expect(find.text('تفعيل'), findsOneWidget);

    await tester.tap(find.text('تفعيل'));
    await tester.pumpAndSettle();

    expect(controller.requested, isTrue);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets(
    'ShopNotificationsScreen allows approved shop owner to send notifications',
    (tester) async {
      late _FakeShopCatalogActionController actionController;
      final approvedShop = Shop(
        id: 'shop-1',
        ownerId: 'owner-1',
        name: 'متجر الأناقة',
        status: ShopStatus.approved,
        visibleStatus: ShopStatus.approved,
      );
      final notifications = [
        AdminNotification(
          id: 'n-shop-1',
          title: 'تخفيضات نهاية الأسبوع',
          body: 'خصومات تصل إلى 30%',
          audience: 'customer',
          createdAt: DateTime(2026, 11, 17, 12, 0),
          shopId: 'shop-1',
          senderRole: 'shop',
          targetScope: 'shop_customers',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopCatalogRepositoryProvider.overrideWithValue(
              _FakeShopCatalogRepository(),
            ),
            myShopProvider.overrideWith((ref) async => approvedShop),
            shopNotificationsProvider.overrideWith(
              (ref) async => notifications,
            ),
            shopCatalogActionProvider.overrideWith((ref) {
              actionController = _FakeShopCatalogActionController(ref);
              return actionController;
            }),
          ],
          child: const MaterialApp(home: ShopNotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مرسل من محلك'), findsOneWidget);
      expect(find.text('إرسال إشعار للعملاء'), findsOneWidget);

      await tester.tap(find.text('إرسال إشعار للعملاء'));
      await tester.pumpAndSettle();

      expect(find.text('عملاء المحل'), findsWidgets);
      expect(find.text('جميع العملاء'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'عرض جديد');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'تخفيض على المعاطف الشتوية',
      );
      await tester.tap(find.text('جميع العملاء'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إرسال'));
      await tester.pumpAndSettle();

      expect(actionController.lastTitle, 'عرض جديد');
      expect(actionController.lastBody, 'تخفيض على المعاطف الشتوية');
      expect(actionController.lastScope, 'all_customers');
    },
  );
}
