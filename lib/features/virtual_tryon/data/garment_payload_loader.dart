import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/tryon_session.dart';

/// Only reference images cross Dart. Video frames stay in native WebRTC threads.
class GarmentPayloadLoader {
  GarmentPayloadLoader(this.client);
  final http.Client client;
  static const maxImageBytes = 4 * 1024 * 1024;

  Future<String> load(GarmentSelection garment) async {
    garment.validate();
    final response = await client
        .send(http.Request('GET', Uri.parse(garment.imageUrl)))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxImageBytes) {
      throw const TryonFailure('تعذر تحميل صورة القطعة أو تجاوزت 4 ميغابايت.');
    }
    final type = response.headers['content-type']?.split(';').first;
    if (!const ['image/jpeg', 'image/png', 'image/webp'].contains(type)) {
      throw const TryonFailure('صورة القطعة يجب أن تكون PNG أو JPEG أو WebP.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 12),
    )) {
      if (bytes.length + chunk.length > maxImageBytes) {
        throw const TryonFailure('صورة القطعة تتجاوز 4 ميغابايت.');
      }
      bytes.add(chunk);
    }
    if (bytes.length == 0) throw const TryonFailure('صورة القطعة فارغة.');
    // Base64 and JSON encoding run off the UI isolate on Android/iOS.
    return compute(encodeGarmentPayload, {
      'bytes': bytes.takeBytes(),
      'prompt': garment.prompt,
    });
  }
}

String encodeGarmentPayload(Map<String, Object> input) => jsonEncode({
  'type': 'set_image',
  'image_data': base64Encode(input['bytes'] as Uint8List),
  'prompt': input['prompt'],
  'enhance_prompt': false,
});
