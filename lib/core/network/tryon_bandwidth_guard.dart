import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../notifications/push_notification_service.dart';
import '../offline/offline_image_cache_service.dart';
import '../offline/offline_sync_engine.dart';

/// Bandwidth profile for live Virtual Try-On sessions.
///
/// [dataSaver] is the default so weak/metered networks (e.g. mobile 3G/4G)
/// stay stable with >60% less upload bandwidth than full 2 Mbps / 30 fps.
enum TryonBandwidthMode {
  dataSaver(
    maxBitrate: 800000,
    maxFramerate: 15,
    connectTimeoutMs: 60000,
  ),
  highQuality(
    maxBitrate: 1800000,
    maxFramerate: 24,
    connectTimeoutMs: 45000,
  );

  const TryonBandwidthMode({
    required this.maxBitrate,
    required this.maxFramerate,
    required this.connectTimeoutMs,
  });

  final int maxBitrate;
  final int maxFramerate;
  final int connectTimeoutMs;
}

/// Coordinates exclusive in-app network priority while a live Virtual Try-On
/// WebRTC session is running.
///
/// While active:
/// - Background image prefetching ([OfflineImageCacheService]) pauses.
/// - Periodic connectivity probes ([NetworkMonitorService]) pause.
/// - Background offline DB preloading ([BackgroundPreloaderService]) pauses.
/// - Background outbox sync ([OfflineSyncEngine]) pauses.
/// - Supabase Realtime notification channel pauses temporarily and resumes
///   automatically once the session ends.
class TryonNetworkFocus {
  TryonNetworkFocus._();

  static final TryonNetworkFocus instance = TryonNetworkFocus._();

  static const int _fastWifiRttThresholdMs = 380;

  int _activeCount = 0;
  bool _pausedRealtime = false;
  String? _realtimeUserId;
  String? _realtimeRole;
  bool _manualOverride = false;
  bool _probing = false;

  final ValueNotifier<TryonBandwidthMode> bandwidthMode =
      ValueNotifier<TryonBandwidthMode>(TryonBandwidthMode.dataSaver);

  bool get isActive => _activeCount > 0;

  /// Lightweight, zero-payload network check run ONLY BEFORE starting Try-On
  /// (never during an active session).
  ///
  /// Defaults safely to [TryonBandwidthMode.dataSaver]. Upgrades to
  /// [TryonBandwidthMode.highQuality] only when connected over Wi-Fi/Ethernet
  /// with a fast, low-latency HEAD probe (<= 380 ms).
  Future<TryonBandwidthMode> autoDetectBandwidthMode({
    bool resetManualOverride = false,
  }) async {
    if (resetManualOverride) {
      _manualOverride = false;
      bandwidthMode.value = TryonBandwidthMode.dataSaver;
    }
    if (isActive || _manualOverride || _probing) {
      return bandwidthMode.value;
    }

    _probing = true;
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      final isFastInterface =
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);

      // On cellular or offline/unknown interfaces, always stay on Data Saver.
      if (!isFastInterface) {
        if (!_manualOverride && !isActive) {
          bandwidthMode.value = TryonBandwidthMode.dataSaver;
        }
        return bandwidthMode.value;
      }

      // Single 0-byte HEAD probe to measure real link latency without downloading data.
      final baseUrl = SupabaseConfig.url.trim();
      if (baseUrl.isEmpty) return bandwidthMode.value;
      final anonKey = SupabaseConfig.anonKey.trim();
      final sw = Stopwatch()..start();
      final response = await http
          .head(
            Uri.parse('$baseUrl/rest/v1/'),
            headers: {if (anonKey.isNotEmpty) 'apikey': anonKey},
          )
          .timeout(const Duration(milliseconds: 1500));
      sw.stop();

      if (!_manualOverride && !isActive) {
        final fastLink =
            response.statusCode > 0 &&
            response.statusCode < 500 &&
            sw.elapsedMilliseconds <= _fastWifiRttThresholdMs;
        bandwidthMode.value = fastLink
            ? TryonBandwidthMode.highQuality
            : TryonBandwidthMode.dataSaver;
      }
    } catch (_) {
      // Any timeout or jitter keeps the safe Data Saver default.
      if (!_manualOverride && !isActive) {
        bandwidthMode.value = TryonBandwidthMode.dataSaver;
      }
    } finally {
      _probing = false;
    }
    return bandwidthMode.value;
  }

  void setManualBandwidthMode(TryonBandwidthMode mode) {
    _manualOverride = true;
    bandwidthMode.value = mode;
  }

  /// Grants exclusive in-app bandwidth focus to the active Try-On session.
  void acquire({
    String? userId,
    String? userRole,
  }) {
    _activeCount++;
    if (_activeCount > 1) return;

    // Temporarily pause Supabase Realtime WebSocket so all upload/download
    // packets go strictly to the live Decart WebRTC stream.
    if (userId != null && userId.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        _realtimeUserId = userId;
        _realtimeRole = userRole;
        _pausedRealtime = true;
        unawaited(PushNotificationService.instance.stopRealtimeListener(client));
      } catch (_) {
        _pausedRealtime = false;
      }
    }
  }

  /// Releases bandwidth focus and smoothly resumes background app services.
  void release() {
    if (_activeCount <= 0) return;
    _activeCount--;
    if (_activeCount > 0) return;

    if (_pausedRealtime && _realtimeUserId != null) {
      final uid = _realtimeUserId!;
      final role = _realtimeRole ?? 'customer';
      _pausedRealtime = false;
      _realtimeUserId = null;
      _realtimeRole = null;
      try {
        final client = Supabase.instance.client;
        PushNotificationService.instance.startRealtimeListener(
          client,
          userId: uid,
          role: role,
          showForegroundBanner: true,
        );
      } catch (_) {}
    }

    // Defer resuming background sync/prefetch slightly so leaving Try-On
    // never drops frames during screen navigation transitions.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (isActive) return;
      OfflineImageCacheService.instance.resumePrefetch();
      unawaited(OfflineSyncEngine.instance.syncPendingActions());
    });
  }
}
