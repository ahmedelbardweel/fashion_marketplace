import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_background_remover/image_background_remover.dart';

class BackgroundRemovalService {
  BackgroundRemovalService._();

  static final BackgroundRemovalService instance =
      BackgroundRemovalService._();

  bool _initialized = false;

  /// Ensures that ONNX runtime is initialized before processing.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await BackgroundRemover.instance.initializeOrt();
      _initialized = true;
      log('BackgroundRemover ONNX initialized successfully',
          name: 'BackgroundRemovalService');
    } catch (e) {
      log('Failed to initialize BackgroundRemover: $e',
          name: 'BackgroundRemovalService');
      rethrow;
    }
  }

  /// Removes image background completely (transparent PNG).
  Future<Uint8List> removeBackground(Uint8List imageBytes) async {
    await ensureInitialized();
    return await BackgroundRemover.instance.removeBgBytes(imageBytes);
  }

  /// Removes image background and replaces it with a clean background color.
  Future<Uint8List> removeBackgroundWithColor({
    required Uint8List imageBytes,
    Color backgroundColor = Colors.white,
  }) async {
    await ensureInitialized();
    final transparentBytes =
        await BackgroundRemover.instance.removeBgBytes(imageBytes);
    return await BackgroundRemover.instance.addBackground(
      image: transparentBytes,
      bgColor: backgroundColor,
    );
  }
}
