import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/network/network_guard.dart';
import '../../../core/utils/background_removal_service.dart';

class ShopStorageRepository {
  ShopStorageRepository({
    SupabaseClient? client,
    Future<Uint8List> Function(Uint8List bytes)? removeBackground,
  }) : _client = client ?? SupabaseConfig.client,
       _removeBackground =
           removeBackground ?? BackgroundRemovalService.instance.removeBackground;

  final SupabaseClient _client;
  final Future<Uint8List> Function(Uint8List bytes) _removeBackground;

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

    await NetworkGuard.ensureOnline();

    var uploadData = bytes;
    var uploadName = fileName;
    var uploadContentType = contentType;
    if (folder == 'logo') {
      try {
        final cutout = await _removeBackground(
          bytes,
        ).timeout(AppTimeouts.backgroundCutout);
        if (cutout.isNotEmpty) {
          uploadData = cutout;
          uploadName = '${p.basenameWithoutExtension(fileName)}.png';
          uploadContentType = 'image/png';
        }
      } catch (_) {
        // Silent fallback so logo uploads never block if cutout fails or times out.
      }
    }

    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(uploadName)}';
    final path = '$userId/$folder/$safeName';

    await NetworkGuard.run(
      () => _client.storage.from(bucket).uploadBinary(
            path,
            uploadData,
            fileOptions: FileOptions(
              upsert: true,
              contentType: uploadContentType,
            ),
          ),
      timeout: AppTimeouts.upload,
      requireConnection: false, // already checked above
    );

    if (bucket == 'shop-documents') {
      return path;
    }
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String mapError(Object error) =>
      AppErrorMapper.message(error, fallback: 'تعذر رفع الملف');
}
