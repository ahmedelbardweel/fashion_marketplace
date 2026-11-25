import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:decart_vton_flutter/decart_vton_flutter.dart'
    show VtonConnectionQuality;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../features/virtual_tryon/data/decart_session_config.dart';
import '../../features/virtual_tryon/domain/tryon_quota.dart';
import '../../features/virtual_tryon/domain/tryon_session.dart';
import '../network/network_guard.dart';
import '../network/tryon_bandwidth_guard.dart';
import '../utils/map_utils.dart';

enum ViduLiveStatus {
  idle,
  creatingSession,
  warmingUp,
  joiningRtc,
  live,
  ending,
  error,
}

class ViduTryonException implements Exception {
  const ViduTryonException(
    this.message, {
    this.code,
    this.dailyLimit,
  });

  final String message;
  final String? code;
  final int? dailyLimit;

  @override
  String toString() => message;
}

class ViduLiveSessionData {
  const ViduLiveSessionData({
    required this.liveId,
    required this.renderUid,
    required this.rtcToken,
    required this.rtcChannelId,
    required this.rtcUserId,
    required this.sessionDurationSeconds,
    required this.dailyLimit,
    required this.usedToday,
    required this.remainingToday,
  });

  final String liveId;
  final String renderUid;
  final String rtcToken;
  final String rtcChannelId;
  final String rtcUserId;
  final int sessionDurationSeconds;
  final int dailyLimit;
  final int usedToday;
  final int remainingToday;
}

/// Real-time live camera Virtual Try-On client powered by Vidu S2-Editing
/// (`POST /live/s_editing/realtime` + control WebSocket + native AliRTC).
class ViduLiveService {
  ViduLiveService({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  static const MethodChannel _rtcMethods = MethodChannel(
    'fashion/vidu_rtc/methods',
  );
  static const EventChannel _rtcEvents = EventChannel(
    'fashion/vidu_rtc/events',
  );

  final SupabaseClient _client;

  final ValueNotifier<ViduLiveStatus> status = ValueNotifier(
    ViduLiveStatus.idle,
  );
  final ValueNotifier<String> stageMessage = ValueNotifier('');
  final ValueNotifier<bool> hasRemoteFrame = ValueNotifier(false);
  final ValueNotifier<bool> isFrontCamera = ValueNotifier(true);
  final ValueNotifier<bool> isSwitchingGarment = ValueNotifier(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  io.WebSocket? _socket;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<dynamic>? _rtcSub;
  Completer<void>? _onLiveCompleter;
  Timer? _initDeadline;
  Timer? _switchIndicatorTimer;
  bool _disposed = false;
  bool _active = false;
  int _generation = 0;

  void Function(String reason)? onServerEnded;

  Future<ViduLiveSessionData> startSession({
    required String garmentImageUrl,
    required TryonBandwidthMode bandwidthMode,
  }) async {
    if (kIsWeb || !io.Platform.isAndroid) {
      throw const ViduTryonException(
        'البث المباشر لـ Vidu متاح حالياً على أجهزة أندرويد.',
        code: 'unsupported_platform',
      );
    }

    await NetworkGuard.ensureOnline();

    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      throw const ViduTryonException(
        'يرجى السماح بالوصول إلى الكاميرا لتشغيل التجربة المباشرة.',
        code: 'camera_denied',
      );
    }

    await stopSession();
    if (_disposed) {
      throw const ViduTryonException('تم إغلاق الشاشة.', code: 'cancelled');
    }

    final gen = ++_generation;
    _active = true;
    hasRemoteFrame.value = false;
    errorMessage.value = null;
    status.value = ViduLiveStatus.creatingSession;
    stageMessage.value = 'جارٍ إنشاء جلسة البث المباشر (Vidu Live)...';

    late final Map<String, dynamic> created;
    try {
      final response = await NetworkGuard.run(
        () => _client.functions.invoke(
          'vidu-tryon',
          body: {
            'action': 'create_live',
            'garmentImage': garmentImageUrl.trim(),
          },
        ),
        timeout: const Duration(seconds: 35),
      );
      created = asStringMap(response.data);
    } on AppNetworkException catch (e) {
      _fail(gen, e.userMessage);
      throw ViduTryonException(e.userMessage, code: 'network');
    } on FunctionException catch (e) {
      final mapped = _mapFunctionError(e);
      _fail(gen, mapped.message);
      throw mapped;
    }

    if (!_isCurrent(gen)) {
      throw const ViduTryonException('تم إلغاء الجلسة.', code: 'cancelled');
    }

    final rtcMap = asStringMap(created['rtc']);
    final liveId = created['liveId']?.toString().trim() ?? '';
    final renderUid = created['renderUid']?.toString().trim() ?? '';
    final rtcToken = rtcMap['token']?.toString().trim() ?? '';
    final rtcChannelId = rtcMap['channelId']?.toString().trim() ?? '';
    final rtcUserId = rtcMap['userId']?.toString().trim() ?? '';

    if (liveId.isEmpty || rtcToken.isEmpty || renderUid.isEmpty) {
      const msg = 'تعذر الحصول على بيانات البث المباشر من Vidu.';
      _fail(gen, msg);
      throw const ViduTryonException(msg, code: 'invalid_response');
    }

    final sessionData = ViduLiveSessionData(
      liveId: liveId,
      renderUid: renderUid,
      rtcToken: rtcToken,
      rtcChannelId: rtcChannelId,
      rtcUserId: rtcUserId,
      sessionDurationSeconds:
          ((created['sessionDurationSeconds'] as num?)?.toInt() ?? 30).clamp(
            10,
            300,
          ),
      dailyLimit: (created['dailyLimit'] as num?)?.toInt() ?? 3,
      usedToday: (created['usedToday'] as num?)?.toInt() ?? 1,
      remainingToday: (created['remainingToday'] as num?)?.toInt() ?? 2,
    );

    // Connect control WebSocket to Supabase Edge Function proxy and wait for `on_live`.
    status.value = ViduLiveStatus.warmingUp;
    stageMessage.value = 'جارٍ تجهيز محرك Vidu المباشر...';
    await _connectControlWebSocket(gen, liveId);

    if (!_isCurrent(gen)) {
      throw const ViduTryonException('تم إلغاء الجلسة.', code: 'cancelled');
    }

    // Join AliRTC channel natively on Android.
    status.value = ViduLiveStatus.joiningRtc;
    stageMessage.value = 'جارٍ تشغيل الكاميرا والاتصال بالبث المباشر...';
    _attachRtcEvents(gen);

    try {
      await _rtcMethods.invokeMethod<dynamic>('join', <String, dynamic>{
        'token': rtcToken,
        'channelId': rtcChannelId,
        'userId': rtcUserId,
        'renderUid': renderUid,
        'dataSaver': bandwidthMode == TryonBandwidthMode.dataSaver,
        'useFrontCamera': isFrontCamera.value,
      });
    } on PlatformException catch (e) {
      final msg = e.message ?? 'تعذر تشغيل محرك الكاميرا المباشرة.';
      _fail(gen, msg);
      throw ViduTryonException(msg, code: e.code);
    }

    if (!_isCurrent(gen)) {
      throw const ViduTryonException('تم إلغاء الجلسة.', code: 'cancelled');
    }

    status.value = ViduLiveStatus.live;
    stageMessage.value = 'بث مباشر نشط';
    return sessionData;
  }

  Future<void> _connectControlWebSocket(int gen, String liveId) async {
    final accessToken = _client.auth.currentSession?.accessToken ?? '';
    final supabaseUrl = SupabaseConfig.url.trim();
    final anonKey = SupabaseConfig.anonKey.trim();
    if (accessToken.isEmpty || supabaseUrl.isEmpty) {
      throw const ViduTryonException(
        'انتهت جلسة الدخول. يرجى تسجيل الدخول مجدداً.',
        code: 'unauthorized',
      );
    }

    final wsUri = Uri.parse(supabaseUrl).replace(
      scheme: supabaseUrl.startsWith('https') ? 'wss' : 'ws',
      path: '/functions/v1/vidu-tryon',
      queryParameters: {'live_id': liveId, 'access_token': accessToken},
    );

    final completer = Completer<void>();
    _onLiveCompleter = completer;

    _initDeadline?.cancel();
    _initDeadline = Timer(const Duration(seconds: 75), () {
      if (!completer.isCompleted) {
        completer.completeError(
          const ViduTryonException(
            'انتهت مهلة تجهيز البث المباشر. يرجى المحاولة مجدداً.',
            code: 'init_timeout',
          ),
        );
      }
    });

    try {
      final ws = await io.WebSocket.connect(
        wsUri.toString(),
        headers: {
          'Authorization': 'Bearer $accessToken',
          if (anonKey.isNotEmpty) 'apikey': anonKey,
        },
      ).timeout(const Duration(seconds: 20));

      if (!_isCurrent(gen)) {
        await ws.close();
        throw const ViduTryonException('تم إلغاء الجلسة.', code: 'cancelled');
      }

      _socket = ws;
      ws.pingInterval = const Duration(seconds: 12);

      _wsSub = ws.listen(
        (raw) {
          if (!_isCurrent(gen)) return;
          if (raw is! String) return;
          Map<String, dynamic> msg;
          try {
            msg = asStringMap(jsonDecode(raw));
          } catch (_) {
            return;
          }
          final event = msg['event']?.toString() ?? '';
          switch (event) {
            case 'not_ready':
              stageMessage.value = 'محرك Vidu قيد الإحماء (ثوانٍ قليلة)...';
            case 'on_live':
              _initDeadline?.cancel();
              if (!completer.isCompleted) completer.complete();
            case 'switch_prompt_sent':
              _switchIndicatorTimer?.cancel();
              _switchIndicatorTimer = Timer(const Duration(seconds: 3), () {
                if (!_disposed) isSwitchingGarment.value = false;
              });
            case 'switch_prompt_error':
            case 'action_error':
              isSwitchingGarment.value = false;
              errorMessage.value =
                  msg['message']?.toString() ?? 'تعذر تبديل القطعة.';
            case 'server_hangup':
              final reason = msg['reason']?.toString() ?? 'ended';
              if (!completer.isCompleted) {
                completer.completeError(
                  ViduTryonException(_friendlyHangupReason(reason), code: reason),
                );
              } else {
                onServerEnded?.call(_friendlyHangupReason(reason));
                unawaited(stopSession());
              }
            case 'fatal':
              final message =
                  msg['message']?.toString() ?? 'تعذر بدء جلسة البث المباشر.';
              if (!completer.isCompleted) {
                completer.completeError(
                  ViduTryonException(message, code: msg['code']?.toString()),
                );
              } else {
                _fail(gen, message);
                unawaited(stopSession());
              }
            case 'remote_closed':
              if (!completer.isCompleted) {
                completer.completeError(
                  const ViduTryonException(
                    'أغلق الخادم اتصال البث المباشر. حاول مجدداً.',
                    code: 'remote_closed',
                  ),
                );
              } else if (_active) {
                onServerEnded?.call('انتهت جلسة البث المباشر.');
                unawaited(stopSession());
              }
          }
        },
        onError: (_) {
          if (!completer.isCompleted) {
            completer.completeError(
              const ViduTryonException(
                'تعذر الاتصال بخادم التحكم في البث المباشر.',
                code: 'ws_error',
              ),
            );
          } else if (_isCurrent(gen)) {
            _fail(gen, 'انقطع الاتصال بخادم البث المباشر.');
            unawaited(stopSession());
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(
              const ViduTryonException(
                'أُغلق اتصال البث قبل جاهزية الكاميرا. حاول مجدداً.',
                code: 'ws_closed',
              ),
            );
          } else if (_isCurrent(gen) && _active) {
            onServerEnded?.call('انتهت جلسة البث المباشر.');
            unawaited(stopSession());
          }
        },
      );

      await completer.future;
    } catch (e) {
      _initDeadline?.cancel();
      if (e is ViduTryonException) {
        _fail(gen, e.message);
        rethrow;
      }
      const msg = 'تعذر الاتصال بخادم البث المباشر لـ Vidu.';
      _fail(gen, msg);
      throw const ViduTryonException(msg, code: 'ws_failed');
    }
  }

  void _attachRtcEvents(int gen) {
    _rtcSub?.cancel();
    _rtcSub = _rtcEvents.receiveBroadcastStream().listen((event) {
      if (!_isCurrent(gen) || event is! Map) return;
      final type = event['type']?.toString();
      switch (type) {
        case 'remoteFirstFrame':
          hasRemoteFrame.value = true;
          isSwitchingGarment.value = false;
        case 'remoteOffline':
          hasRemoteFrame.value = false;
        case 'error':
          final msg = event['message']?.toString() ?? 'حدث خطأ في البث المباشر.';
          errorMessage.value = msg;
      }
    });
  }

  /// Dynamically swaps the worn garment on the LIVE video stream (free of extra charge).
  Future<void> switchGarment(String garmentImageUrl) async {
    final ws = _socket;
    if (ws == null || ws.readyState != io.WebSocket.open) return;
    final clean = garmentImageUrl.trim();
    if (clean.isEmpty) return;
    isSwitchingGarment.value = true;
    errorMessage.value = null;
    try {
      ws.add(
        jsonEncode({'action': 'switch_prompt', 'image_url': clean}),
      );
    } catch (_) {
      isSwitchingGarment.value = false;
    }
  }

  Future<void> switchCamera() async {
    try {
      final front = await _rtcMethods.invokeMethod<bool>('switchCamera');
      if (front != null && !_disposed) {
        isFrontCamera.value = front;
      }
    } catch (_) {}
  }

  Future<void> setShowOriginal(bool showOriginal) async {
    try {
      await _rtcMethods.invokeMethod<void>('setShowOriginal', {
        'showOriginal': showOriginal,
      });
    } catch (_) {}
  }

  Future<void> setBandwidthMode(TryonBandwidthMode mode) async {
    try {
      await _rtcMethods.invokeMethod<void>('setBandwidthMode', {
        'dataSaver': mode == TryonBandwidthMode.dataSaver,
      });
    } catch (_) {}
  }

  Future<void> stopSession() async {
    _active = false;
    ++_generation;
    _initDeadline?.cancel();
    _initDeadline = null;
    _switchIndicatorTimer?.cancel();
    _switchIndicatorTimer = null;

    if (_onLiveCompleter != null && !_onLiveCompleter!.isCompleted) {
      _onLiveCompleter!.completeError(
        const ViduTryonException('تم إنهاء الجلسة.', code: 'cancelled'),
      );
    }
    _onLiveCompleter = null;

    try {
      if (_socket?.readyState == io.WebSocket.open) {
        _socket!.add(jsonEncode({'action': 'hangup'}));
      }
    } catch (_) {}

    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    await _rtcSub?.cancel();
    _rtcSub = null;

    if (!kIsWeb && io.Platform.isAndroid) {
      try {
        await _rtcMethods.invokeMethod<void>('leave');
      } catch (_) {}
    }

    if (!_disposed) {
      hasRemoteFrame.value = false;
      isSwitchingGarment.value = false;
      if (status.value != ViduLiveStatus.error) {
        status.value = ViduLiveStatus.idle;
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopSession();
    status.dispose();
    stageMessage.dispose();
    hasRemoteFrame.dispose();
    isFrontCamera.dispose();
    isSwitchingGarment.dispose();
    errorMessage.dispose();
  }

  bool _isCurrent(int gen) => !_disposed && _active && gen == _generation;

  void _fail(int gen, String message) {
    if (_disposed || gen != _generation) return;
    errorMessage.value = message;
    status.value = ViduLiveStatus.error;
  }

  ViduTryonException _mapFunctionError(FunctionException error) {
    final details = error.details;
    String? code;
    int? dailyLimit;
    if (details is Map) {
      code = details['code']?.toString();
      dailyLimit = (details['dailyLimit'] as num?)?.toInt();
    }
    if (error.status == 404 && code == null) {
      return const ViduTryonException(
        'دالة البث المباشر لـ Vidu غير منشورة بعد على السيرفر (vidu-tryon).',
        code: 'function_missing',
      );
    }
    if (code == 'provider_not_active') {
      return const ViduTryonException(
        'قامت الإدارة بتبديل محرك التجربة الافتراضية. أعد فتح الصفحة.',
        code: 'provider_not_active',
      );
    }
    if (code == 'tryon_disabled') {
      return const ViduTryonException(
        'ميزة تجربة الملابس الافتراضية متوقفة مؤقتاً من قبل الإدارة.',
        code: 'tryon_disabled',
      );
    }
    if (code == 'daily_limit_reached') {
      return ViduTryonException(
        'استهلكت جميع محاولاتك اليومية لتجربة الملابس. ستعود محاولاتك تلقائياً غداً.',
        code: 'daily_limit_reached',
        dailyLimit: dailyLimit,
      );
    }
    if (code == 'all_keys_depleted' || error.status == 503) {
      return const ViduTryonException(
        'خدمة التجربة الافتراضية متوقفة مؤقتاً لنفاد الرصيد في التطبيق.',
        code: 'all_keys_depleted',
      );
    }
    if (error.status == 401) {
      return const ViduTryonException(
        'يرجى تسجيل الدخول مجدداً لاستخدام التجربة الافتراضية.',
        code: 'unauthorized',
      );
    }
    return const ViduTryonException(
      'تعذر بدء البث المباشر حالياً. يرجى المحاولة مجدداً.',
      code: 'upstream_failed',
    );
  }

  String _friendlyHangupReason(String reason) {
    return switch (reason) {
      'timeout' => 'انتهت مدة جلسة التجربة المباشرة.',
      'credit_insufficient' => 'توقفت الجلسة لنفاد رصيد التوكن في التطبيق.',
      'audit_violation' => 'توقفت الجلسة بسبب فحص المحتوى التلقائي.',
      _ => 'انتهت جلسة البث المباشر.',
    };
  }
}

TryonBlockReason? blockReasonFromViduCode(String? code) {
  return switch (code) {
    'tryon_disabled' => TryonBlockReason.disabledByAdmin,
    'all_keys_depleted' => TryonBlockReason.tokensDepleted,
    'daily_limit_reached' => TryonBlockReason.dailyLimitReached,
    _ => null,
  };
}

/// Adapts [ViduLiveService] to the shared [TryonSession] domain contract used by
/// [DecartTryonNotifier] and [DecartTryonScreen], so both Decart and Vidu run on
/// the exact same customer UI, guidelines, measurements, warmup, zoom, and dock.
class ViduLiveTryonSession implements TryonSession {
  ViduLiveTryonSession({
    ViduLiveService? liveService,
    this.onQuotaUpdated,
    this.onQuotaBlocked,
  }) : _live = liveService ?? ViduLiveService() {
    _live.hasRemoteFrame.addListener(_syncState);
    _live.isSwitchingGarment.addListener(_syncState);
    _live.status.addListener(_syncState);
    TryonNetworkFocus.instance.bandwidthMode.addListener(_bandwidthChanged);
    _live.onServerEnded = (reason) {
      if (_disposed) return;
      _emit(DecartSessionStatus.disconnected, reason);
    };
  }

  final ViduLiveService _live;
  final void Function(DecartSessionConfig cfg)? onQuotaUpdated;
  final void Function(TryonBlockReason reason, {int? dailyLimit})?
      onQuotaBlocked;

  final _events = StreamController<TryonSessionEvent>.broadcast();

  final ValueNotifier<bool> isGenerating = ValueNotifier<bool>(false);
  final ValueNotifier<VtonConnectionQuality> connectionQuality = ValueNotifier(
    VtonConnectionQuality.good,
  );
  final ValueNotifier<DecartSessionConfig?> sessionConfig = ValueNotifier(null);

  bool _disposed = false;
  bool _connectedReported = false;

  @override
  Stream<TryonSessionEvent> get events => _events.stream;

  @override
  bool get isUsingFrontCamera => _live.isFrontCamera.value;

  void _emit(DecartSessionStatus status, [String? error]) {
    if (!_disposed && !_events.isClosed) {
      _events.add(TryonSessionEvent(status, error: error));
    }
  }

  void _syncState() {
    if (_disposed) return;
    final st = _live.status.value;
    final hasFrame = _live.hasRemoteFrame.value;
    final switching = _live.isSwitchingGarment.value;

    isGenerating.value =
        (st == ViduLiveStatus.live && (!hasFrame || switching)) ||
        st == ViduLiveStatus.warmingUp ||
        st == ViduLiveStatus.joiningRtc;

    if (st == ViduLiveStatus.live && hasFrame && !_connectedReported) {
      _connectedReported = true;
      connectionQuality.value = VtonConnectionQuality.good;
      _emit(DecartSessionStatus.connected);
    }
  }

  void _bandwidthChanged() {
    if (_disposed) return;
    if (_live.status.value == ViduLiveStatus.live) {
      unawaited(
        _live.setBandwidthMode(TryonNetworkFocus.instance.bandwidthMode.value),
      );
    }
  }

  Future<void> setShowOriginal(bool showOriginal) =>
      _live.setShowOriginal(showOriginal);

  Future<void> prewarmGarmentImage(String? url) async {
    // Vidu accepts the garment URL directly on the server; no local prewarm needed.
  }

  @override
  Future<void> start(GarmentSelection garment) async {
    if (_disposed) return;
    garment.validate();
    _connectedReported = false;
    _emit(DecartSessionStatus.initializing);
    try {
      final mode = TryonNetworkFocus.instance.bandwidthMode.value;
      final session = await _live.startSession(
        garmentImageUrl: garment.imageUrl,
        bandwidthMode: mode,
      );
      if (_disposed) return;

      final cfg = DecartSessionConfig(
        clientToken: 'vidu_live',
        model: 'vidu-s2-editing',
        iceServers: const [],
        relayOnly: false,
        sessionDurationSeconds: session.sessionDurationSeconds,
        dailyLimit: session.dailyLimit,
        usedToday: session.usedToday,
        remainingToday: session.remainingToday,
      );
      sessionConfig.value = cfg;
      onQuotaUpdated?.call(cfg);

      _emit(DecartSessionStatus.connecting);
      // Mark connected immediately once RTC is joined (first frame overlay fades in smoothly).
      if (!_connectedReported) {
        _connectedReported = true;
        _emit(DecartSessionStatus.connected);
      }
    } on ViduTryonException catch (error) {
      if (error.code == 'cancelled') return;
      final blocked = blockReasonFromViduCode(error.code);
      if (blocked != null) {
        onQuotaBlocked?.call(blocked, dailyLimit: error.dailyLimit);
      }
      _emit(DecartSessionStatus.error, error.message);
      throw TryonFailure(error.message);
    } catch (_) {
      const msg = 'تعذر بدء البث المباشر حالياً. يرجى المحاولة مجدداً.';
      _emit(DecartSessionStatus.error, msg);
      throw const TryonFailure(msg);
    }
  }

  @override
  Future<void> select(GarmentSelection garment) async {
    if (_disposed) return;
    garment.validate();
    await _live.switchGarment(garment.imageUrl);
  }

  @override
  Future<void> switchCamera() => _live.switchCamera();

  @override
  Future<void> stop() async {
    _connectedReported = false;
    await _live.stopSession();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    TryonNetworkFocus.instance.bandwidthMode.removeListener(_bandwidthChanged);
    _live.hasRemoteFrame.removeListener(_syncState);
    _live.isSwitchingGarment.removeListener(_syncState);
    _live.status.removeListener(_syncState);
    await _live.dispose();
    isGenerating.dispose();
    connectionQuality.dispose();
    sessionConfig.dispose();
    await _events.close();
  }
}
