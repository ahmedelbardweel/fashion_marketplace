import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';

class ShopStorageRepository {
  ShopStorageRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<String> uploadBytes({
    required String bucket,
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('يجب تسجيل الدخول أولاً');
    }

    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
    final path = '$userId/$folder/$safeName';

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    if (bucket == 'shop-documents') {
      return path;
    }
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String mapError(Object error) {
    if (error is StorageException) return error.message;
    return 'تعذر رفع الملف';
  }
}
