import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/supabase_config.dart';
import '../network/network_guard.dart';
import '../network/tryon_bandwidth_guard.dart';

/// Real-time network connectivity monitor with active Supabase reachability probe.
/// Distinguishes between mere Wi-Fi association and actual internet connectivity
/// to the Supabase backend.
class NetworkMonitorService {
  NetworkMonitorService._();

  static final NetworkMonitorService instance = NetworkMonitorService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicCheckTimer;

  bool _isOnline = true;
  bool _initialized = false;
  DateTime? _lastVerifiedAt;

  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChange => _statusController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await checkNow(force: true);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _updateOnlineStatus(false);
      } else {
        unawaited(checkNow(force: true));
      }
    });

    // Periodic silent verification so captive portal / restored ISP routing
    // is detected promptly even if the OS interface state didn't change.
    _periodicCheckTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) {
        if (TryonNetworkFocus.instance.isActive) return;
        unawaited(checkNow());
      },
    );
  }

  /// Fast OS-level check for whether any network interface (Wi-Fi / Cellular / Ethernet) is active.
  Future<bool> hasNetworkInterface() async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 2),
      );
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return _isOnline;
    }
  }

  /// Ensures real connectivity before executing an online-only action.
  /// Throws [AppNetworkException.noInternet] if interfaces are OFF, or
  /// [AppNetworkException.unreachable] if interface is UP but Supabase cannot be reached.
  Future<void> ensureConnected({bool forceProbe = false}) async {
    final hasInterface = await hasNetworkInterface();
    if (!hasInterface) {
      _lastVerifiedAt = DateTime.now();
      _updateOnlineStatus(false);
      throw AppNetworkException.noInternet();
    }

    // If recently verified online within the last 4 seconds and not forced, avoid extra latency.
    if (!forceProbe &&
        _isOnline &&
        _lastVerifiedAt != null &&
        DateTime.now().difference(_lastVerifiedAt!) <
            const Duration(seconds: 4)) {
      return;
    }

    final reachable = await _probeSupabaseReachability();
    _lastVerifiedAt = DateTime.now();
    _updateOnlineStatus(reachable);
    if (!reachable) {
      throw AppNetworkException.unreachable();
    }
  }

  /// Performs an active check of network interfaces and Supabase REST endpoint reachability.
  Future<bool> checkNow({bool force = false}) async {
    if (!force &&
        _lastVerifiedAt != null &&
        DateTime.now().difference(_lastVerifiedAt!) <
            const Duration(seconds: 4)) {
      return _isOnline;
    }

    try {
      final hasInterface = await hasNetworkInterface();
      if (!hasInterface) {
        _lastVerifiedAt = DateTime.now();
        _updateOnlineStatus(false);
        return false;
      }

      final reachable = await _probeSupabaseReachability();
      _lastVerifiedAt = DateTime.now();
      _updateOnlineStatus(reachable);
      return reachable;
    } catch (_) {
      _lastVerifiedAt = DateTime.now();
      _updateOnlineStatus(false);
      return false;
    }
  }

  /// Marks network as offline immediately when a request fails with a transport/timeout error.
  void reportNetworkFailure() {
    _lastVerifiedAt = DateTime.now();
    _updateOnlineStatus(false);
  }

  /// Marks network as online immediately when any HTTP response succeeds.
  void reportNetworkSuccess() {
    _lastVerifiedAt = DateTime.now();
    _updateOnlineStatus(true);
  }

  Future<bool> _probeSupabaseReachability() async {
    try {
      final baseUrl = SupabaseConfig.url.trim();
      final anonKey = SupabaseConfig.anonKey.trim();
      if (baseUrl.isEmpty) return false;

      final uri = Uri.parse('$baseUrl/rest/v1/');
      final response = await http
          .head(
            uri,
            headers: {
              if (anonKey.isNotEmpty) 'apikey': anonKey,
            },
          )
          .timeout(AppTimeouts.connectivityProbe);

      // Any HTTP response from Supabase gateway (200, 401, 404) confirms internet + server reachability
      return response.statusCode > 0 && response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void _updateOnlineStatus(bool nextStatus) {
    if (_isOnline == nextStatus) return;
    _isOnline = nextStatus;
    debugPrint(
      '[NetworkMonitorService] Connectivity changed -> ${nextStatus ? "ONLINE" : "OFFLINE"}',
    );
    if (!_statusController.isClosed) {
      _statusController.add(nextStatus);
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _periodicCheckTimer?.cancel();
  }
}
