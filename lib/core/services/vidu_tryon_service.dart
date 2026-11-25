import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

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
    required this.clientSecret,
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
  final String clientSecret;
  final String renderUid;
  final String rtcToken;
  final String rtcChannelId;
  final String rtcUserId;
  final int sessionDurationSeconds;
  final int dailyLimit;
  final int usedToday;
  final int remainingToday;
}

/// Real-time live camera Virtual Try-On client powered by Vidu S2-Editing:
/// 1) Mints a session-scoped `clientSecret` + AliRTC token from Supabase `vidu-tryon`
///    (permanent `vda_` keys never leave Supabase Vault).
/// 2) Connects directly to `wss://api.vidu.com/live/ws/live/connect` using `clientSecret`
///    for `conn_init`, free live `switch_prompt` garment swaps, and `hangup`.
/// 3) Streams live video via native Android AliRTC (`AliVCSDK_ARTC`).
class ViduLiveService {
  ViduLiveService({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  static const MethodChannel _rtcMethods = MethodChannel(
    'fashion/vidu_rtc/methods',
  );
  static const EventChannel _rtcEvents = EventChannel(
    'fashion/vidu_rtc/events',
  );
  static const String _viduWsBase = 'wss://api.vidu.com/live/ws/live/connect';

  final SupabaseClient _client;
  final Random _random = Random();

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

  String? _activeLiveId;
  String _activeConnId = '';
  int _seqId = 0;
  bool _wentLive = false;
  bool _disposed = false;
  bool _active = false;
  int _generation = 0;

  void Function(String reason)? onServerEnded;

  String _generateConnId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randA = _random.nextInt(0x7fffffff).toRadixString(16);
    final randB = _random.nextInt(0x7fffffff).toRadixString(16);
    return '$ts-$randA-$randB';
  }

  void _sendViduSignal(int type, Map<String, dynamic> payload) {
    final ws = _socket;
    final liveId = _activeLiveId;
    if (ws == null || ws.readyState != io.WebSocket.open || liveId == null) {
      return;
    }
    try {
      ws.add(
        jsonEncode({
          'type': type,
          'live_id': liveId,
          'conn_id': _activeConnId,
          'seq_id': ++_seqId,
          'payload': payload,
        }),
      );
    } catch (_) {}
  }

  Future<ViduLiveSessionData> startSession({
    required String garmentImageUrl,
    required TryonBandwidthMode bandwidthMode,
  }) async {
    if (kIsWeb || !(io.Platform.isAndroid || io.Platform.isIOS)) {
      throw const ViduTryonException(
        'البث المباشر لـ Vidu متاح على هواتف أندرويد وآيفون فقط.',
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
    _wentLive = false;
    _activeLiveId = null;
    _seqId = 0;
    hasRemoteFrame.value = false;
    errorMessage.value = null;
    status.value = ViduLiveStatus.creatingSession;
    stageMessage.value = 'جارٍ إنشاء جلسة البث المباشر...';

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
    final clientSecret = created['clientSecret']?.toString().trim() ?? '';
    final renderUid = created['renderUid']?.toString().trim() ?? '';
    final rtcToken = rtcMap['token']?.toString().trim() ?? '';
    final rtcChannelId = rtcMap['channelId']?.toString().trim() ?? '';
    final rtcUserId = rtcMap['userId']?.toString().trim() ?? '';

    if (liveId.isEmpty ||
        clientSecret.isEmpty ||
        rtcToken.isEmpty ||
        renderUid.isEmpty) {
      const msg =
          'يلزم إعادة نشر دالة vidu-tryon على Supabase لتفعيل البث المباشر.';
      _fail(gen, msg);
      throw const ViduTryonException(msg, code: 'invalid_response');
    }

    _activeLiveId = liveId;
    _activeConnId = _generateConnId();

    final sessionData = ViduLiveSessionData(
      liveId: liveId,
      clientSecret: clientSecret,
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

    // Connect DIRECTLY to Vidu control WebSocket using session-scoped client_secret.
    status.value = ViduLiveStatus.warmingUp;
    stageMessage.value = 'جارٍ تجهيز البث المباشر...';
    await _connectDirectViduWebSocket(gen, liveId, clientSecret);

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

  Future<void> _connectDirectViduWebSocket(
    int gen,
    String liveId,
    String clientSecret,
  ) async {
    final wsUri = Uri.parse(_viduWsBase).replace(
      queryParameters: {
        'live_id': liveId,
        'conn_id': _activeConnId,
        'client_secret': clientSecret,
      },
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
          final msgType = (msg['type'] as num?)?.toInt();
          final payload = msg['payload'] is Map
              ? asStringMap(msg['payload'])
              : const <String, dynamic>{};

          // type 2: conn_init_ack
          if (msgType == 2 && payload['conn_init_ack'] is Map) {
            final ack = asStringMap(payload['conn_init_ack']);
            if (ack['success'] == true) {
              _initDeadline?.cancel();
              _wentLive = true;
              if (!completer.isCompleted) completer.complete();
            } else if (ack['error_code']?.toString() == 'NOT_READY') {
              stageMessage.value = 'محرك البث قيد الإحماء (ثوانٍ قليلة)...';
            } else {
              final errMsg =
                  ack['error_msg']?.toString().trim().isNotEmpty == true
                  ? 'تعذر تجهيز البث المباشر. حاول مجدداً.'
                  : 'فشل بدء جلسة البث المباشر.';
              if (!completer.isCompleted) {
                completer.completeError(
                  ViduTryonException(
                    errMsg,
                    code: ack['error_code']?.toString() ?? 'conn_init_failed',
                  ),
                );
              }
            }
            return;
          }

          // type 6: server forced hangup
          if (msgType == 6) {
            final hangup = payload['hangup'] is Map
                ? asStringMap(payload['hangup'])
                : const <String, dynamic>{};
            final reason = hangup['hangup_reason']?.toString() ?? 'ended';
            if (!completer.isCompleted) {
              completer.completeError(
                ViduTryonException(
                  _friendlyHangupReason(reason),
                  code: reason,
                ),
              );
            } else {
              onServerEnded?.call(_friendlyHangupReason(reason));
              unawaited(stopSession());
            }
            return;
          }

          // type 14: switch_prompt_ack (only sent on failure)
          if (msgType == 14 && payload['switch_prompt_ack'] is Map) {
            final ack = asStringMap(payload['switch_prompt_ack']);
            if (ack['success'] == false) {
              isSwitchingGarment.value = false;
              errorMessage.value = 'تعذر تبديل القطعة حالياً. حاول مجدداً.';
            }
          }
        },
        onError: (_) {
          if (!completer.isCompleted) {
            completer.completeError(
              const ViduTryonException(
                'تعذر الاتصال بخادم البث المباشر.',
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

      // Immediately send Vidu conn_init (type: 1) after WebSocket opens.
      _sendViduSignal(1, const {
        'conn_init': {'version': 1},
      });

      await completer.future;
    } catch (e) {
      _initDeadline?.cancel();
      if (e is ViduTryonException) {
        _fail(gen, e.message);
        rethrow;
      }
      const msg = 'تعذر الاتصال بخادم البث المباشر.';
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
    _sendViduSignal(13, {
      'switch_prompt': {
        'prompts': [
          {'type': 'image', 'content': clean},
        ],
        'editing_type': 'virtual_tryon',
      },
    });
    _switchIndicatorTimer?.cancel();
    _switchIndicatorTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed) isSwitchingGarment.value = false;
    });
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
    final endingLiveId = _activeLiveId;
    final failedBeforeLive = endingLiveId != null && !_wentLive;

    _active = false;
    _activeLiveId = null;
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

    if (endingLiveId != null && _socket?.readyState == io.WebSocket.open) {
      try {
        _socket!.add(
          jsonEncode({
            'type': 5,
            'live_id': endingLiveId,
            'conn_id': _activeConnId,
            'seq_id': ++_seqId,
            'payload': {
              'hangup': {'hangup_reason': 'user_end'},
            },
          }),
        );
      } catch (_) {}
    }

    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    await _rtcSub?.cancel();
    _rtcSub = null;

    if (!kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS)) {
      try {
        await _rtcMethods.invokeMethod<void>('leave');
      } catch (_) {}
    }

    // Best-effort notify Supabase to refresh key balance & refund if init never reached live.
    if (endingLiveId != null) {
      unawaited(
        _client.functions
            .invoke(
              'vidu-tryon',
              body: {
                'action': 'end_live',
                'liveId': endingLiveId,
                'failedBeforeLive': failedBeforeLive,
              },
            )
            .catchError((_) => FunctionResponse(status: 200)),
      );
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
        'دالة البث المباشر غير منشورة بعد على السيرفر.',
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

  Future<void> prewarmGarmentImage(String? url) async {}

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
