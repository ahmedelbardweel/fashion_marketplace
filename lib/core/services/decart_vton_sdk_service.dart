import 'dart:async';

import 'package:decart_vton_flutter/decart_vton_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../features/virtual_tryon/data/decart_session_config.dart';
import '../../features/virtual_tryon/data/tryon_errors.dart';
import '../../features/virtual_tryon/domain/tryon_session.dart';
import '../offline/offline_image_cache_service.dart';

/// Abstraction over [DecartVton] so [DecartVtonSdkService] can be tested in
/// pure Dart without requiring native platform channels.
abstract class VtonClient {
  Stream<VtonEvent> get events;
  bool get isInitialized;
  VtonConnectionState get connectionState;
  VtonCameraFacing get cameraFacing;

  Future<void> initialize({
    required VtonClientTokenProvider clientTokenProvider,
    VtonLogLevel logLevel = VtonLogLevel.warn,
    bool force = false,
  });

  Future<void> connect({
    required VtonModel model,
    VtonOutfit? initialOutfit,
    VtonCameraFacing camera = VtonCameraFacing.front,
  });

  Future<void> setOutfit({required VtonOutfit outfit});
  Future<VtonCameraFacing> switchCamera();
  Future<void> disconnect();
  Future<void> dispose();
}

class _LiveVtonClient implements VtonClient {
  _LiveVtonClient() : _sdk = DecartVton();

  final DecartVton _sdk;

  @override
  Stream<VtonEvent> get events => _sdk.events;

  @override
  bool get isInitialized => _sdk.isInitialized;

  @override
  VtonConnectionState get connectionState => _sdk.connectionState;

  @override
  VtonCameraFacing get cameraFacing => _sdk.cameraFacing;

  @override
  Future<void> initialize({
    required VtonClientTokenProvider clientTokenProvider,
    VtonLogLevel logLevel = VtonLogLevel.warn,
    bool force = false,
  }) => _sdk.initialize(
    clientTokenProvider: clientTokenProvider,
    logLevel: logLevel,
    force: force,
  );

  @override
  Future<void> connect({
    required VtonModel model,
    VtonOutfit? initialOutfit,
    VtonCameraFacing camera = VtonCameraFacing.front,
  }) => _sdk.connect(
    model: model,
    initialOutfit: initialOutfit,
    camera: camera,
  );

  @override
  Future<void> setOutfit({required VtonOutfit outfit}) =>
      _sdk.setOutfit(outfit: outfit);

  @override
  Future<VtonCameraFacing> switchCamera() => _sdk.switchCamera();

  @override
  Future<void> disconnect() => _sdk.disconnect();

  @override
  Future<void> dispose() => _sdk.dispose();
}

bool get isVtonNativePlatformSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Realtime try-on session powered by the native `decart_vton_flutter` SDK
/// and Lucy VTON models, using Admin-managed tokens minted by `decart-session`.
class DecartVtonSdkService implements TryonSession {
  DecartVtonSdkService({
    required this.loadConfig,
    VtonClient Function()? createClient,
    Future<bool> Function()? ensureCameraPermission,
    this._resolveOutfit,
    this.isPlatformSupported,
    http.Client? httpClient,
  }) : _createClient = createClient ?? _LiveVtonClient.new,
       _ensureCameraPermission =
           ensureCameraPermission ?? _defaultCameraPermission,
       _http = httpClient;

  static const int _maxGarmentBytes = 5 * 1024 * 1024;

  final Future<DecartSessionConfig> Function() loadConfig;
  final VtonClient Function() _createClient;
  final Future<bool> Function() _ensureCameraPermission;
  final Future<VtonOutfit> Function(GarmentSelection garment)? _resolveOutfit;
  final bool? isPlatformSupported;
  final http.Client? _http;

  final StreamController<TryonSessionEvent> _events =
      StreamController<TryonSessionEvent>.broadcast();
  final ValueNotifier<bool> isGenerating = ValueNotifier<bool>(false);
  final ValueNotifier<VtonConnectionQuality> connectionQuality =
      ValueNotifier<VtonConnectionQuality>(VtonConnectionQuality.unknown);

  VtonClient? _client;
  StreamSubscription<VtonEvent>? _sdkEvents;
  DecartSessionConfig? _latestConfig;
  bool _front = true;
  bool _disposed = false;
  int _generation = 0;

  @override
  Stream<TryonSessionEvent> get events => _events.stream;

  @override
  bool get isUsingFrontCamera => _front;

  @override
  Future<void> start(GarmentSelection garment) async {
    if (_disposed) return;
    final gen = ++_generation;

    final supported = isPlatformSupported ?? isVtonNativePlatformSupported;
    if (!supported) {
      throw const TryonFailure(
        'التجربة المباشرة بتقنية Lucy VTON متاحة على هواتف أندرويد وآيفون فقط.',
      );
    }

    garment.validate();
    _emit(DecartSessionStatus.initializing);

    final granted = await _ensureCameraPermission();
    if (_disposed || gen != _generation) return;
    if (!granted) {
      const failure = TryonFailure(
        'يلزم منح إذن الكاميرا لتشغيل تجربة الملابس المباشرة.',
      );
      _emit(DecartSessionStatus.error, failure.message);
      throw failure;
    }

    try {
      final client = _ensureClient();
      final outfit = await _buildOutfit(garment);
      if (_disposed || gen != _generation) return;

      _emit(DecartSessionStatus.connecting);

      if (!client.isInitialized) {
        await client.initialize(
          clientTokenProvider: _provideClientToken,
          logLevel: kDebugMode ? VtonLogLevel.info : VtonLogLevel.warn,
        );
      }
      if (_disposed || gen != _generation) return;

      final model = _resolveTargetModel(_latestConfig?.model);
      await client.connect(
        model: model,
        initialOutfit: outfit,
        camera: _front ? VtonCameraFacing.front : VtonCameraFacing.back,
      );
      if (_disposed || gen != _generation) return;

      _front = client.cameraFacing == VtonCameraFacing.front;
      _emit(DecartSessionStatus.connected);
    } on TryonFailure catch (failure) {
      if (_disposed || gen != _generation) return;
      _emit(DecartSessionStatus.error, failure.message);
      rethrow;
    } on DecartVtonException catch (error) {
      if (_disposed || gen != _generation) return;
      final failure = vtonExceptionToFailure(error);
      _emit(DecartSessionStatus.error, failure.message);
      throw failure;
    } catch (error) {
      if (_disposed || gen != _generation) return;
      final failure = error is TryonFailure
          ? error
          : const TryonFailure(
              'تعذر بدء جلسة التجربة المباشرة. تحقق من الاتصال وأعد المحاولة.',
            );
      _emit(DecartSessionStatus.error, failure.message);
      throw failure;
    }
  }

  @override
  Future<void> select(GarmentSelection garment) async {
    if (_disposed) return;
    final client = _client;
    if (client == null || !client.connectionState.isLive) {
      throw const TryonFailure('الجلسة غير متصلة حالياً.');
    }
    garment.validate();
    try {
      final outfit = await _buildOutfit(garment);
      await client.setOutfit(outfit: outfit);
    } on TryonFailure {
      rethrow;
    } on DecartVtonException catch (error) {
      throw vtonExceptionToFailure(error);
    } catch (_) {
      throw const TryonFailure('تعذر تحديث القطعة على البث المباشر.');
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_disposed) return;
    final client = _client;
    if (client == null || !client.connectionState.isLive) return;
    try {
      final facing = await client.switchCamera();
      _front = facing == VtonCameraFacing.front;
      _emit(DecartSessionStatus.connected);
    } on DecartVtonException catch (error) {
      throw vtonExceptionToFailure(error);
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    isGenerating.value = false;
    connectionQuality.value = VtonConnectionQuality.unknown;
    final client = _client;
    if (client != null) {
      try {
        await client.disconnect();
      } catch (_) {}
    }
    if (!_disposed) _emit(DecartSessionStatus.disconnected);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    await _sdkEvents?.cancel();
    _sdkEvents = null;
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        await client.disconnect();
      } catch (_) {}
      try {
        await client.dispose();
      } catch (_) {}
    }
    isGenerating.dispose();
    connectionQuality.dispose();
    await _events.close();
  }

  VtonClient _ensureClient() {
    final existing = _client;
    if (existing != null) return existing;
    final client = _createClient();
    _client = client;
    _sdkEvents = client.events.listen(_handleSdkEvent);
    return client;
  }

  Future<String> _provideClientToken() async {
    final config = await loadConfig();
    _latestConfig = config;
    return config.clientToken;
  }

  /// Resolves backend-advertised model id to `decart_vton_flutter`'s `VtonModel`.
  /// When the backend targets `lucy-vton-3.6` or `lucy-vton-latest`, maps to
  /// `VtonModel.lucyVtonLatest` (the SDK's newest 720p VTON model).
  VtonModel _resolveTargetModel(String? configuredModel) {
    if (configuredModel == null || configuredModel.isEmpty) {
      return VtonModel.lucyVtonLatest;
    }
    return VtonModel.fromId(configuredModel) ?? VtonModel.lucyVtonLatest;
  }

  Future<VtonOutfit> _buildOutfit(GarmentSelection garment) async {
    final customResolver = _resolveOutfit;
    if (customResolver != null) return customResolver(garment);

    final cached = await OfflineImageCacheService.instance.getOrDownloadFile(
      garment.imageUrl,
    );
    if (cached != null && await cached.exists() && await cached.length() > 0) {
      return VtonOutfit(
        prompt: garment.prompt,
        referenceImagePath: cached.path,
        enhance: true,
      );
    }

    final uri = Uri.tryParse(garment.imageUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const TryonFailure('رابط صورة القطعة غير صالح للتجربة.');
    }

    final client = _http ?? http.Client();
    final ownsClient = _http == null;
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw const TryonFailure('تعذر تحميل صورة القطعة للتجربة.');
      }
      if (response.bodyBytes.length > _maxGarmentBytes) {
        throw const TryonFailure('حجم صورة القطعة كبير جداً للتجربة.');
      }
      return VtonOutfit(
        prompt: garment.prompt,
        referenceImage: response.bodyBytes,
        enhance: true,
      );
    } finally {
      if (ownsClient) client.close();
    }
  }

  void _handleSdkEvent(VtonEvent event) {
    if (_disposed) return;
    switch (event) {
      case VtonConnectionStateChanged(:final state):
        isGenerating.value = state == VtonConnectionState.generating;
        switch (state) {
          case VtonConnectionState.idle:
          case VtonConnectionState.disconnected:
            _emit(DecartSessionStatus.disconnected);
          case VtonConnectionState.connecting:
          case VtonConnectionState.reconnecting:
            _emit(DecartSessionStatus.connecting);
          case VtonConnectionState.connected:
          case VtonConnectionState.generating:
            _front = _client?.cameraFacing == VtonCameraFacing.front;
            _emit(DecartSessionStatus.connected);
          case VtonConnectionState.error:
            _emit(
              DecartSessionStatus.error,
              'انقطع الاتصال بخادم التجربة. أعد المحاولة.',
            );
        }
      case VtonErrorOccurred(:final error):
        if (error.code == VtonErrorCode.cancelled) return;
        _emit(DecartSessionStatus.error, vtonExceptionToFailure(error).message);
      case VtonConnectionQualityChanged(:final quality):
        connectionQuality.value = quality;
      case VtonSessionStarted():
      case VtonGenerationTick():
      case VtonRemoteStreamUpdated():
      case VtonLocalStreamUpdated():
        break;
    }
  }

  void _emit(DecartSessionStatus status, [String? error]) {
    if (!_events.isClosed) {
      _events.add(TryonSessionEvent(status, error: error));
    }
  }

  static Future<bool> _defaultCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}
