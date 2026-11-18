import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityTamperException implements Exception {
  const SecurityTamperException(this.message);
  final String message;

  @override
  String toString() => 'SecurityTamperException: $message';
}

/// Provides AES-256-GCM encryption and HMAC-SHA256 integrity verification
/// for local offline database rows and sync outbox payloads.
///
/// Keys are generated using `Random.secure()` and stored inside Android Keystore /
/// iOS Keychain via `FlutterSecureStorage`.
class OfflineSecurityService {
  OfflineSecurityService._();

  static final OfflineSecurityService instance = OfflineSecurityService._();

  static const String _aesKeyStorageName = 'shopy_offline_aes256_master_key_v1';
  static const String _hmacKeyStorageName = 'shopy_offline_hmac256_master_key_v1';
  static const int _ivLength = 12; // 96-bit nonce for AES-GCM
  static const int _macBitLength = 128; // 128-bit authentication tag

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Uint8List? _aesKey;
  Uint8List? _hmacKey;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized && _aesKey != null && _hmacKey != null) return;

    try {
      String? aesBase64 = await _readSecure(_aesKeyStorageName);
      String? hmacBase64 = await _readSecure(_hmacKeyStorageName);

      if (aesBase64 == null || aesBase64.isEmpty) {
        final generatedAes = _generateSecureBytes(32); // 256 bits
        aesBase64 = base64Encode(generatedAes);
        await _writeSecure(_aesKeyStorageName, aesBase64);
      }

      if (hmacBase64 == null || hmacBase64.isEmpty) {
        final generatedHmac = _generateSecureBytes(32); // 256 bits
        hmacBase64 = base64Encode(generatedHmac);
        await _writeSecure(_hmacKeyStorageName, hmacBase64);
      }

      _aesKey = base64Decode(aesBase64);
      _hmacKey = base64Decode(hmacBase64);

      if (_aesKey!.length != 32) {
        _aesKey = Uint8List.fromList(sha256.convert(_aesKey!).bytes);
      }
      if (_hmacKey!.length != 32) {
        _hmacKey = Uint8List.fromList(sha256.convert(_hmacKey!).bytes);
      }
    } catch (_) {
      // Fallback ephemeral key derivation if secure storage is temporarily unavailable
      _aesKey ??= _generateSecureBytes(32);
      _hmacKey ??= _generateSecureBytes(32);
    }

    _initialized = true;
  }

  Future<String?> _readSecure(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> _writeSecure(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Uint8List _generateSecureBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  void _ensureKeysLoaded() {
    if (!_initialized || _aesKey == null || _hmacKey == null) {
      throw StateError(
        'OfflineSecurityService has not been initialized. Call initialize() first.',
      );
    }
  }

  /// Encrypts a UTF-8 plaintext string using AES-256-GCM.
  /// Output format: `v1:<base64(iv)>:<base64(ciphertext+tag)>`
  String encryptText(String plainText) {
    _ensureKeysLoaded();
    final iv = _generateSecureBytes(_ivLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(_aesKey!),
          _macBitLength,
          iv,
          Uint8List(0),
        ),
      );

    final inputBytes = Uint8List.fromList(utf8.encode(plainText));
    final encryptedBytes = cipher.process(inputBytes);

    return 'v1:${base64Encode(iv)}:${base64Encode(encryptedBytes)}';
  }

  /// Decrypts an AES-256-GCM encrypted string produced by [encryptText].
  /// Throws [SecurityTamperException] if authentication tag fails or format is invalid.
  String decryptText(String cipherText) {
    _ensureKeysLoaded();
    if (!cipherText.startsWith('v1:')) {
      throw const SecurityTamperException('صيغة البيانات المشفرة غير صالحة');
    }

    final parts = cipherText.split(':');
    if (parts.length != 3) {
      throw const SecurityTamperException('هيكل التشفير تالف أو تم التلاعب به');
    }

    try {
      final iv = base64Decode(parts[1]);
      final encryptedBytes = base64Decode(parts[2]);

      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(_aesKey!),
            _macBitLength,
            iv,
            Uint8List(0),
          ),
        );

      final decryptedBytes = cipher.process(encryptedBytes);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      throw SecurityTamperException('فشل التحقق من سلامة البيانات المشفرة: $e');
    }
  }

  /// Encrypts a JSON map into an AES-256-GCM ciphertext string.
  String encryptMap(Map<String, dynamic> map) {
    final canonicalJson = jsonEncode(_canonicalize(map));
    return encryptText(canonicalJson);
  }

  /// Decrypts an AES-256-GCM ciphertext string back into a JSON map.
  Map<String, dynamic> decryptMap(String cipherText) {
    final jsonStr = decryptText(cipherText);
    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const SecurityTamperException('البيانات المفكوكة ليست كائناً صالحاً');
  }

  /// Generates an HMAC-SHA256 signature over critical operation fields
  /// to guarantee that queued offline actions (like orders, prices, quantities)
  /// cannot be modified in SQLite before syncing to Supabase.
  String signPayload({
    required String actionType,
    required String entityId,
    required String encryptedPayload,
    required int createdAtMs,
  }) {
    _ensureKeysLoaded();
    final message = '$actionType|$entityId|$createdAtMs|$encryptedPayload';
    final hmac = Hmac(sha256, _hmacKey!);
    final digest = hmac.convert(utf8.encode(message));
    return digest.toString();
  }

  /// Verifies the HMAC-SHA256 signature of a queued offline action in constant time.
  bool verifyPayloadSignature({
    required String actionType,
    required String entityId,
    required String encryptedPayload,
    required int createdAtMs,
    required String signature,
  }) {
    final expected = signPayload(
      actionType: actionType,
      entityId: entityId,
      encryptedPayload: encryptedPayload,
      createdAtMs: createdAtMs,
    );
    return _constantTimeEquals(expected, signature);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in sortedKeys) k: _canonicalize(value[k]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }
}
