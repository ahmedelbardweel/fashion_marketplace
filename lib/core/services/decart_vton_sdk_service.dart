import 'dart:async';

import 'package:decart_vton_flutter/decart_vton_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../features/virtual_tryon/data/decart_session_config.dart';
import '../../features/virtual_tryon/data/tryon_errors.dart';
import '../../features/virtual_tryon/domain/tryon_session.dart';
import '../l10n/app_translations.dart';
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

/// Validates a short-lived Decart client token minted by `decart-session`.
///
/// Decart `/v1/client/tokens` returns JWT tokens (`eyJ...`) as well as `ek_...`
/// keys; `decart_vton_flutter: ^1.0.1` rejects JWTs in Dart because it checks
/// `startsWith('ek_')`, whereas the native Android/iOS SDKs accept any valid
/// client token. Still rejects empty strings and permanent `dct_` keys.
@visibleForTesting
String validateVtonClientToken(String raw) {
  final token = raw.trim();
  if (token.isEmpty || token.startsWith('dct_')) {
    throw const DecartVtonException.local(
      VtonErrorCode.invalidApiKey,
      'Invalid or permanent credential returned from client token endpoint.',
    );
  }
  return token;
}

class _LiveVtonClient implements VtonClient {
  _LiveVtonClient({
    MethodChannel? methods,
    EventChannel? eventsChannel,
  }) : _methods = methods ?? const MethodChannel('ai.decart.vton/methods'),
       _eventsChannel =
           eventsChannel ?? const EventChannel('ai.decart.vton/events');

  final MethodChannel _methods;
  final EventChannel _eventsChannel;
  final StreamController<VtonEvent> _eventsController =
      StreamController<VtonEvent>.broadcast();

  StreamSubscription<dynamic>? _nativeEvents;
  Future<void> _tail = Future<void>.value();
  VtonClientTokenProvider? _tokenProvider;
  VtonLogLevel _logLevel = VtonLogLevel.warn;
  bool _initialized = false;
  bool _disposed = false;
  bool _credentialUnused = false;
  VtonConnectionState _connectionState = VtonConnectionState.disconnected;
  VtonCameraFacing _facing = VtonCameraFacing.front;

  @override
  Stream<VtonEvent> get events => _eventsController.stream;

  @override
  bool get isInitialized => _initialized;

  @override
  VtonConnectionState get connectionState => _connectionState;

  @override
  VtonCameraFacing get cameraFacing => _facing;

  Future<T> _serialize<T>(Future<T> Function() op) {
    final res = _tail.then((_) => op());
    _tail = res.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return res;
  }

  @override
  Future<void> initialize({
    required VtonClientTokenProvider clientTokenProvider,
    VtonLogLevel logLevel = VtonLogLevel.warn,
    bool force = false,
  }) => _serialize(() async {
    if (_disposed) return;
    if (_initialized && !force) return;
    _tokenProvider = clientTokenProvider;
    _logLevel = logLevel;
    await _refreshNativeClient();
    _attachNativeEvents();
  });

  Future<void> _refreshNativeClient() async {
    final provider = _tokenProvider;
    if (provider == null) {
      throw const DecartVtonException.local(
        VtonErrorCode.notInitialized,
        'Client token provider is not configured.',
      );
    }
    final token = validateVtonClientToken(await provider());
    if (_initialized) {
      await _invokeVoid('release', const <String, Object?>{});
      _initialized = false;
      _credentialUnused = false;
    }
    try {
      await _invokeVoid('initialize', <String, Object?>{
        'clientToken': token,
        'signalingBaseUrl': 'wss://api.decart.ai',
        'httpBaseUrl': 'https://api.decart.ai',
        'logLevel': _logLevel.name,
      });
      _initialized = true;
      _credentialUnused = true;
    } catch (_) {
      _initialized = false;
      _credentialUnused = false;
      rethrow;
    }
  }

  void _attachNativeEvents() {
    if (_nativeEvents != null) return;
    _nativeEvents = _eventsChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (Object error, StackTrace _) {
        final vtonError = error is PlatformException
            ? _convert(error)
            : DecartVtonException(VtonErrorCode.unknown, error.toString());
        if (!_eventsController.isClosed) {
          _eventsController.add(VtonErrorOccurred(vtonError));
        }
      },
    );
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final map = raw.cast<Object?, Object?>();
    final VtonEvent? event = switch (map['type'] as String?) {
      'connectionState' => VtonConnectionStateChanged(
        VtonConnectionState.fromWire(map['state'] as String?),
      ),
      'sessionStarted' => map['sessionId'] is String
          ? VtonSessionStarted(
              sessionId: map['sessionId'] as String,
              subscribeToken: map['subscribeToken'] as String?,
            )
          : null,
      'generationTick' => VtonGenerationTick(
        Duration(
          milliseconds: (((map['seconds'] as num?)?.toDouble() ?? 0) * 1000)
              .round(),
        ),
      ),
      'remoteStreamUpdated' => const VtonRemoteStreamUpdated(),
      'localStreamUpdated' => const VtonLocalStreamUpdated(),
      'connectionQuality' => VtonConnectionQualityChanged(
        quality: VtonConnectionQuality.fromWire(map['quality'] as String?),
        roundTripMs: (map['roundTripMs'] as num?)?.round(),
        packetLoss: (map['packetLoss'] as num?)?.toDouble(),
        jitterMs: (map['jitterMs'] as num?)?.round(),
      ),
      'error' => VtonErrorOccurred(
        DecartVtonException(
          VtonErrorCode.fromNative(map['code'] as String?),
          (map['message'] as String?) ?? 'Unknown native error',
          nativeCode: map['code'] as String?,
          details: map['details'],
        ),
      ),
      _ => null,
    };
    if (event == null) return;
    if (event is VtonConnectionStateChanged) {
      _connectionState = event.state;
    }
    if (!_eventsController.isClosed) _eventsController.add(event);
  }

  @override
  Future<void> connect({
    required VtonModel model,
    VtonOutfit? initialOutfit,
    VtonCameraFacing camera = VtonCameraFacing.front,
  }) => _serialize(() async {
    if (_disposed) return;
    if (!_initialized) {
      throw const DecartVtonException.local(
        VtonErrorCode.notInitialized,
        'Native client is not initialized.',
      );
    }

    var reusedInitial = false;
    if (_credentialUnused) {
      _credentialUnused = false;
      reusedInitial = true;
    } else {
      await _refreshNativeClient();
      _credentialUnused = false;
    }

    _facing = camera;
    final args = <String, Object?>{
      'model': model.id,
      'width': model.width,
      'height': model.height,
      'fps': model.fps,
      'supportsReferenceImage': model.supportsReferenceImage,
      'facing': camera.name,
      'mirror': VtonMirrorMode.auto.name,
      'resolution': VtonResolution.p720.wireValue,
      'connectTimeoutMs': 45000,
      'video': VtonVideoConfig(
        maxBitrate: 2000000,
        maxFramerate: model.fps,
        preferredCodec: defaultTargetPlatform == TargetPlatform.iOS
            ? 'h264'
            : 'vp8',
        simulcast: false,
      ).toMap(),
      'prompt': initialOutfit?.prompt,
      'referenceImage': initialOutfit?.referenceImage,
      'referenceImagePath': initialOutfit?.hasReferenceImagePath == true
          ? initialOutfit!.referenceImagePath!.trim()
          : null,
      'enhance': initialOutfit?.enhance ?? false,
    };

    try {
      await _invoke<Map<Object?, Object?>>('connect', args);
    } on DecartVtonException catch (error) {
      if (!reusedInitial || error.code != VtonErrorCode.invalidApiKey) rethrow;
      await _refreshNativeClient();
      _credentialUnused = false;
      await _invoke<Map<Object?, Object?>>('connect', args);
    }
    if (!_connectionState.isLive) {
      _connectionState = VtonConnectionState.connected;
    }
  });

  @override
  Future<void> setOutfit({required VtonOutfit outfit}) => _serialize(() async {
    if (_disposed) return;
    await _invokeVoid('setOutfit', <String, Object?>{
      'prompt': outfit.hasPrompt ? outfit.prompt!.trim() : null,
      'referenceImage': outfit.hasReferenceImageBytes
          ? outfit.referenceImage
          : null,
      'referenceImagePath': outfit.hasReferenceImagePath
          ? outfit.referenceImagePath!.trim()
          : null,
      'enhance': outfit.enhance,
      'timeoutMs': 30000,
    });
  });

  @override
  Future<VtonCameraFacing> switchCamera() => _serialize(() async {
    final target = _facing.flipped;
    final res = await _invoke<Map<Object?, Object?>>(
      'switchCamera',
      <String, Object?>{'facing': target.name},
    );
    _facing = res?['facing'] == VtonCameraFacing.back.name
        ? VtonCameraFacing.back
        : VtonCameraFacing.front;
    return _facing;
  });

  @override
  Future<void> disconnect() => _serialize(() async {
    if (_disposed || !_initialized) return;
    await _invokeVoid('disconnect', const <String, Object?>{});
    _connectionState = VtonConnectionState.disconnected;
  });

  @override
  Future<void> dispose() => _serialize(() async {
    if (_disposed) return;
    _disposed = true;
    await _nativeEvents?.cancel();
    _nativeEvents = null;
    if (_initialized) {
      try {
        await _invokeVoid('release', const <String, Object?>{});
      } on DecartVtonException {
        // Best-effort native release on teardown.
      }
    }
    _initialized = false;
    await _eventsController.close();
  });

  Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e, s) {
      Error.throwWithStackTrace(_convert(e), s);
    } on MissingPluginException catch (e, s) {
      Error.throwWithStackTrace(
        DecartVtonException(
          VtonErrorCode.notInitialized,
          'decart_vton_flutter plugin is not registered. (${e.message})',
        ),
        s,
      );
    }
  }

  Future<void> _invokeVoid(String method, Map<String, Object?> args) async {
    await _invoke<void>(method, args);
  }

  static DecartVtonException _convert(PlatformException e) =>
      DecartVtonException(
        VtonErrorCode.fromNative(e.code),
        e.message ?? 'Platform error',
        nativeCode: e.code,
        details: e.details,
      );
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
  GarmentSelection? _lastGarment;
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
      throw TryonFailure(
        'التجربة المباشرة بتقنية Lucy VTON متاحة على هواتف أندرويد وآيفون فقط.'.tr,
      );
    }

    garment.validate();
    _lastGarment = garment;
    _emit(DecartSessionStatus.initializing);

    final granted = await _ensureCameraPermission();
    if (_disposed || gen != _generation) return;
    if (!granted) {
      final failure = TryonFailure(
        'يلزم منح إذن الكاميرا لتشغيل تجربة الملابس المباشرة.'.tr,
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
          : TryonFailure(
              'تعذر بدء جلسة التجربة المباشرة. تحقق من الاتصال وأعد المحاولة.'.tr,
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
      throw TryonFailure('الجلسة غير متصلة حالياً.'.tr);
    }
    garment.validate();
    _lastGarment = garment;
    try {
      final outfit = await _buildOutfit(garment);
      await client.setOutfit(outfit: outfit);
    } on TryonFailure {
      rethrow;
    } on DecartVtonException catch (error) {
      throw vtonExceptionToFailure(error);
    } catch (_) {
      throw TryonFailure('تعذر تحديث القطعة على البث المباشر.'.tr);
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_disposed) return;
    final client = _client;
    if (client == null || !client.connectionState.isLive) {
      _front = !_front;
      return;
    }
    try {
      final facing = await client.switchCamera();
      _front = facing == VtonCameraFacing.front;
      _emit(DecartSessionStatus.connected);
    } on DecartVtonException catch (error) {
      // Fallback for iOS/Android camera drivers where in-place LiveKit lens
      // switching is unsupported: reconnect seamlessly with the opposite lens.
      final garment = _lastGarment;
      if (garment == null) throw vtonExceptionToFailure(error);
      _front = !_front;
      try {
        await client.disconnect();
      } catch (_) {}
      await start(garment);
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

  /// Builds a concise, zone-specific prompt recommended by Lucy VTON.
  /// Uses "Substitute" for garments and "Add" for watches, jewelry, eyewear,
  /// headwear, and bags so every clothing and accessory type applies accurately.
  @visibleForTesting
  static String buildSdkPrompt(GarmentSelection garment) {
    final cleanName = garment.name.replaceAll(RegExp(r'\s+'), ' ').trim();
    final shortName = cleanName.length <= 50
        ? cleanName
        : cleanName.substring(0, 50);
    final meta = '${garment.category ?? ''} $cleanName'.toLowerCase();
    return switch (garment.effectiveZone) {
      TryonBodyZone.upperBody =>
        'Substitute only the upper-body top with $shortName from the reference '
            'garment image. Keep pants, legs, shoes, hands, face identity, '
            'natural body shape, and background 100% unchanged.',
      TryonBodyZone.lowerPants =>
        'Substitute only the full-length pants with $shortName from the '
            'reference garment image. Keep the upper-body top, shoes, hands, '
            'face identity, natural body shape, and background 100% unchanged.',
      TryonBodyZone.lowerShorts =>
        'Substitute only the above-knee shorts with $shortName from the '
            'reference garment image. Keep lower legs, top, shoes, hands, '
            'face identity, natural body shape, and background 100% unchanged.',
      TryonBodyZone.fullBody =>
        'Substitute the full-body outfit with $shortName from the reference '
            'garment image. Keep shoes, hands, neck, face identity, natural '
            'body shape, and background 100% unchanged.',
      TryonBodyZone.footwear =>
        'Substitute only the footwear on both feet with $shortName from the '
            'reference garment image. Keep pants, legs, upper clothing, hands, '
            'face identity, natural body shape, and background 100% unchanged.',
      TryonBodyZone.wristHand => _buildWristHandPrompt(shortName, meta),
      TryonBodyZone.headFace => _buildHeadFacePrompt(shortName, meta),
      TryonBodyZone.bags => _buildBagPrompt(shortName, meta),
    };
  }

  static String _buildWristHandPrompt(String shortName, String meta) {
    if (RegExp(r'\b(?:smart)?watch(?:es)?\b|ساع(?:ة|ات)').hasMatch(meta)) {
      return 'Add the wristwatch ($shortName) from the reference image strapped '
          'naturally onto the person\'s visible wrist. Match the exact dial and '
          'strap. Keep face identity, natural body shape, clothing, and '
          'background unchanged.';
    }
    if (RegExp(r'\brings?\b|خاتم|خواتم|دبل').hasMatch(meta)) {
      return 'Add the ring ($shortName) from the reference image naturally onto '
          'the person\'s visible finger. Keep face identity, natural body '
          'shape, clothing, and background unchanged.';
    }
    if (RegExp(
      r'\bbracelets?\b|\bbangles?\b|(?:^|\s)(?:ال)?(?:سوار|أسور|اسور|أساور|اساور)',
    ).hasMatch(meta)) {
      return 'Add the bracelet ($shortName) from the reference image around '
          'the person\'s visible wrist. Keep face identity, natural body '
          'shape, clothing, and background unchanged.';
    }
    if (RegExp(r'\bgloves?\b|قفاز').hasMatch(meta)) {
      return 'Put the gloves ($shortName) from the reference image onto the '
          'person\'s hands. Keep face identity, natural body shape, clothing, '
          'and background unchanged.';
    }
    return 'Add the wrist accessory ($shortName) from the reference image '
        'naturally onto the person\'s visible wrist. Keep face identity, '
        'natural body shape, clothing, and background unchanged.';
  }

  static String _buildHeadFacePrompt(String shortName, String meta) {
    if (RegExp(r'\bsunglass|\bglasses\b|\beyewear\b|نظار').hasMatch(meta)) {
      return 'Add the glasses ($shortName) from the reference image onto the '
          'person\'s face resting naturally on the nose. Keep face identity, '
          'natural body shape, clothing, and background unchanged.';
    }
    if (RegExp(r'\bearrings?\b|حلق|أقراط|اقراط').hasMatch(meta)) {
      return 'Add the earrings ($shortName) from the reference image onto the '
          'person\'s ears. Keep face identity, natural body shape, clothing, '
          'and background unchanged.';
    }
    if (RegExp(r'\bnecklaces?\b|\bpendants?\b|\bchains?\b|\bchokers?\b|\bscarf|\bscarves\b|شال|وشاح|عقد|سلسل|قلاد')
        .hasMatch(meta)) {
      return 'Add the neck accessory ($shortName) from the reference image '
          'naturally around the person\'s neck. Keep face identity, natural '
          'body shape, clothing, and background unchanged.';
    }
    return 'Add the headwear ($shortName) from the reference image naturally '
        'onto the person\'s head. Keep face identity, natural body shape, '
        'clothing, and background unchanged.';
  }

  static String _buildBagPrompt(String shortName, String meta) {
    if (RegExp(r'\bbackpacks?\b|ظهر').hasMatch(meta)) {
      return 'Add the backpack ($shortName) from the reference image worn '
          'naturally on the person\'s shoulders. Keep face identity, natural '
          'body shape, clothing, and background unchanged.';
    }
    return 'Add the bag ($shortName) from the reference image carried '
        'naturally on the person\'s shoulder or in hand. Keep face identity, '
        'natural body shape, clothing, and background unchanged.';
  }

  Future<VtonOutfit> _buildOutfit(GarmentSelection garment) async {
    final customResolver = _resolveOutfit;
    if (customResolver != null) return customResolver(garment);

    final prompt = buildSdkPrompt(garment);
    final cached = await OfflineImageCacheService.instance.getOrDownloadFile(
      garment.imageUrl,
    );
    if (cached != null && await cached.exists() && await cached.length() > 0) {
      return VtonOutfit(
        prompt: prompt,
        referenceImagePath: cached.path,
        enhance: false,
      );
    }

    final uri = Uri.tryParse(garment.imageUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw TryonFailure('رابط صورة القطعة غير صالح للتجربة.'.tr);
    }

    final client = _http ?? http.Client();
    final ownsClient = _http == null;
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw TryonFailure('تعذر تحميل صورة القطعة للتجربة.'.tr);
      }
      if (response.bodyBytes.length > _maxGarmentBytes) {
        throw TryonFailure('حجم صورة القطعة كبير جداً للتجربة.'.tr);
      }
      return VtonOutfit(
        prompt: prompt,
        referenceImage: response.bodyBytes,
        enhance: false,
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
              'انقطع الاتصال بخادم التجربة. أعد المحاولة.'.tr,
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
