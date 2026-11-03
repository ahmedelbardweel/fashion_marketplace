import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class PickedBytes {
  const PickedBytes({
    required this.bytes,
    required this.fileName,
    this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String? contentType;
}

class MediaPicker {
  MediaPicker._();

  static final ImagePicker _imagePicker = ImagePicker();

  static Future<PickedBytes?> pickImage() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedBytes(
      bytes: bytes,
      fileName: file.name,
      contentType: file.mimeType,
    );
  }

  static Future<PickedBytes?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) return null;
    return PickedBytes(
      bytes: file.bytes!,
      fileName: file.name,
      contentType: null,
    );
  }
}
