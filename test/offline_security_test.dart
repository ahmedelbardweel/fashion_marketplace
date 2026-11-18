import 'package:fashion_marketplace/core/offline/offline_security_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OfflineSecurityService.instance.initialize();
  });

  group('OfflineSecurityService (AES-256-GCM & HMAC-SHA256)', () {
    test('encrypts and decrypts maps accurately with unique nonces', () {
      final original = {
        'shop_id': 'shop_123',
        'total': 250.5,
        'delivery_address': 'دمشق - المزة',
        'items': [
          {'product_id': 'prod_1', 'quantity': 2, 'unit_price': 125.25},
        ],
      };

      final cipher1 = OfflineSecurityService.instance.encryptMap(original);
      final cipher2 = OfflineSecurityService.instance.encryptMap(original);

      expect(cipher1, startsWith('v1:'));
      expect(cipher2, startsWith('v1:'));
      // Different random 96-bit IVs produce distinct ciphertexts
      expect(cipher1, isNot(equals(cipher2)));

      final decrypted1 = OfflineSecurityService.instance.decryptMap(cipher1);
      final decrypted2 = OfflineSecurityService.instance.decryptMap(cipher2);

      expect(decrypted1['shop_id'], equals('shop_123'));
      expect(decrypted1['total'], equals(250.5));
      expect(decrypted1['delivery_address'], equals('دمشق - المزة'));
      expect(decrypted2, equals(decrypted1));
    });

    test('detects tampering in AES-256-GCM ciphertext and throws SecurityTamperException', () {
      final cipher = OfflineSecurityService.instance.encryptMap({
        'order_id': 'ord_1',
        'total': 500.0,
      });

      final tampered = '${cipher.substring(0, cipher.length - 4)}AAAA';
      expect(
        () => OfflineSecurityService.instance.decryptMap(tampered),
        throwsA(isA<SecurityTamperException>()),
      );
    });

    test('verifies HMAC-SHA256 outbox signatures and rejects modified metadata', () {
      final encryptedPayload = OfflineSecurityService.instance.encryptMap({
        'shop_id': 'shop_1',
        'total': 100.0,
      });
      const createdAtMs = 1700000000000;

      final signature = OfflineSecurityService.instance.signPayload(
        actionType: 'place_order',
        entityId: 'offline_ord_1',
        encryptedPayload: encryptedPayload,
        createdAtMs: createdAtMs,
      );

      expect(
        OfflineSecurityService.instance.verifyPayloadSignature(
          actionType: 'place_order',
          entityId: 'offline_ord_1',
          encryptedPayload: encryptedPayload,
          createdAtMs: createdAtMs,
          signature: signature,
        ),
        isTrue,
      );

      // Tampering with entityId or actionType invalidates HMAC signature
      expect(
        OfflineSecurityService.instance.verifyPayloadSignature(
          actionType: 'place_order',
          entityId: 'offline_ord_2',
          encryptedPayload: encryptedPayload,
          createdAtMs: createdAtMs,
          signature: signature,
        ),
        isFalse,
      );
    });
  });
}
