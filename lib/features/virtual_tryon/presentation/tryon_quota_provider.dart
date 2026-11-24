import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../../../core/offline/network_monitor_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/decart_session_config.dart';
import '../domain/tryon_quota.dart';

final tryonQuotaProvider =
    AsyncNotifierProvider<TryonQuotaNotifier, TryonQuota>(
      TryonQuotaNotifier.new,
    );

class TryonQuotaNotifier extends AsyncNotifier<TryonQuota> {
  DateTime? _lastFetchedAt;

  bool get isFresh {
    final ts = _lastFetchedAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < const Duration(seconds: 15);
  }

  @override
  Future<TryonQuota> build() async {
    // Re-evaluate automatically when the signed-in user changes.
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (userId == null) {
      _lastFetchedAt = null;
      return const TryonQuota();
    }
    return _fetchFromServer();
  }

  Future<TryonQuota> _fetchFromServer() async {
    if (!NetworkMonitorService.instance.isOnline) {
      return state.valueOrNull ?? const TryonQuota();
    }
    final hasInterface =
        await NetworkMonitorService.instance.hasNetworkInterface();
    if (!hasInterface) {
      NetworkMonitorService.instance.reportNetworkFailure();
      return state.valueOrNull ?? const TryonQuota();
    }
    try {
      final data = await SupabaseConfig.client
          .rpc('get_my_tryon_quota')
          .timeout(const Duration(seconds: 6));
      if (data is Map) {
        final loaded = TryonQuota.fromMap(Map<String, dynamic>.from(data));
        _lastFetchedAt = DateTime.now();
        return loaded;
      }
    } catch (_) {
      // Graceful fallback when offline or before migration deployment.
    }
    return state.valueOrNull ?? const TryonQuota();
  }

  Future<TryonQuota> refresh({bool force = true}) async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) {
      const guest = TryonQuota();
      state = const AsyncData(guest);
      return guest;
    }
    if (!force && isFresh && state.hasValue) {
      return state.requireValue;
    }
    final fresh = await _fetchFromServer();
    state = AsyncData(fresh);
    return fresh;
  }

  void updateFromQuota(TryonQuota quota) {
    _lastFetchedAt = DateTime.now();
    state = AsyncData(quota);
  }

  void updateFromSessionConfig(DecartSessionConfig cfg) {
    final remaining =
        cfg.remainingToday ??
        (cfg.dailyLimit - cfg.usedToday).clamp(0, cfg.dailyLimit);
    final updated = TryonQuota(
      enabled: true,
      tokensAvailable: true,
      sessionDurationSeconds: cfg.sessionDurationSeconds,
      dailyLimit: cfg.dailyLimit,
      usedToday: cfg.usedToday,
      remainingToday: remaining,
    );
    _lastFetchedAt = DateTime.now();
    state = AsyncData(updated);
  }

  void markBlocked(TryonBlockReason reason, {int? dailyLimit}) {
    final current = state.valueOrNull ?? const TryonQuota();
    final updated = switch (reason) {
      TryonBlockReason.disabledByAdmin => current.copyWith(
        enabled: false,
        blockReasonOverride: TryonBlockReason.disabledByAdmin,
      ),
      TryonBlockReason.tokensDepleted => current.copyWith(
        tokensAvailable: false,
        blockReasonOverride: TryonBlockReason.tokensDepleted,
      ),
      TryonBlockReason.dailyLimitReached => current.copyWith(
        dailyLimit: dailyLimit ?? current.dailyLimit,
        usedToday: dailyLimit ?? current.dailyLimit,
        remainingToday: 0,
        blockReasonOverride: TryonBlockReason.dailyLimitReached,
      ),
    };
    _lastFetchedAt = DateTime.now();
    state = AsyncData(updated);
  }
}
