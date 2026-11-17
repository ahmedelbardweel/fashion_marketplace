import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/presentation/providers/admin_providers.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/customer/presentation/providers/customer_providers.dart';
import '../../features/shop/presentation/providers/shop_catalog_providers.dart';
import '../theme/app_theme.dart';
import 'push_notification_service.dart';

class PushNotificationState {
  const PushNotificationState({
    this.permissionStatus = PushPermissionStatus.unknown,
    this.notificationsEnabled = true,
    this.isRequesting = false,
    this.fcmReady = false,
    this.hasToken = false,
  });

  final PushPermissionStatus permissionStatus;
  final bool notificationsEnabled;
  final bool isRequesting;
  final bool fcmReady;
  final bool hasToken;

  bool get isEffectivelyActive =>
      permissionStatus.isGranted && notificationsEnabled;

  PushNotificationState copyWith({
    PushPermissionStatus? permissionStatus,
    bool? notificationsEnabled,
    bool? isRequesting,
    bool? fcmReady,
    bool? hasToken,
  }) {
    return PushNotificationState(
      permissionStatus: permissionStatus ?? this.permissionStatus,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isRequesting: isRequesting ?? this.isRequesting,
      fcmReady: fcmReady ?? this.fcmReady,
      hasToken: hasToken ?? this.hasToken,
    );
  }
}

final pushNotificationControllerProvider =
    StateNotifierProvider<PushNotificationController, PushNotificationState>(
      (ref) => PushNotificationController(ref),
    );

class PushNotificationController extends StateNotifier<PushNotificationState>
    with WidgetsBindingObserver {
  PushNotificationController(this._ref)
    : super(
        PushNotificationState(
          notificationsEnabled: AppPreferences.getNotificationsEnabled(),
        ),
      ) {
    WidgetsBinding.instance.addObserver(this);
    _incomingSub = PushNotificationService.instance.onIncomingNotification
        .listen((_) => _refreshNotificationsForCurrentUser());
  }

  final Ref _ref;
  StreamSubscription<void>? _incomingSub;
  String? _activeUserId;
  bool _syncInFlight = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshStatus());
      final client = _client;
      final user = _ref.read(authControllerProvider).user;
      if (client != null &&
          user != null &&
          this.state.isEffectivelyActive) {
        unawaited(
          PushNotificationService.instance.checkAndNotifyMissed(
            client,
            userId: user.id,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_incomingSub?.cancel());
    super.dispose();
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshStatus() async {
    await PushNotificationService.instance.initialize();
    final status = await PushNotificationService.instance
        .checkPermissionStatus();
    if (!mounted) return;
    state = state.copyWith(
      permissionStatus: status,
      fcmReady: PushNotificationService.instance.isFirebaseReady,
      hasToken: PushNotificationService.instance.currentToken != null,
    );
  }

  /// Syncs notification permission, FCM/APNs token registration, Realtime
  /// alerts, and Android fallback background sync whenever auth state changes.
  Future<void> handleAuthUser(AppUser? user) async {
    final client = _client;
    if (user == null) {
      if (_activeUserId != null && client != null) {
        await PushNotificationService.instance.unregisterToken(client);
      }
      _activeUserId = null;
      if (mounted) {
        state = state.copyWith(hasToken: false);
      }
      return;
    }

    if (_syncInFlight && _activeUserId == user.id) return;
    _syncInFlight = true;
    _activeUserId = user.id;

    try {
      await PushNotificationService.instance.initialize();
      var status = await PushNotificationService.instance
          .checkPermissionStatus();

      final alreadyPrompted = AppPreferences.getNotificationPrompted();
      if (!alreadyPrompted && !status.isGranted) {
        status = await PushNotificationService.instance.requestPermissions();
        await AppPreferences.setNotificationPrompted(true);
        if (status.isGranted && !state.notificationsEnabled) {
          await AppPreferences.setNotificationsEnabled(true);
          if (mounted) {
            state = state.copyWith(notificationsEnabled: true);
          }
        }
      }

      String? token;
      if (client != null && status.isGranted) {
        token = await PushNotificationService.instance.syncTokenWithSupabase(
          client,
          userId: user.id,
          enabled: state.notificationsEnabled,
        );
        await PushNotificationService.instance.checkAndNotifyMissed(
          client,
          userId: user.id,
        );
      }

      await PushNotificationService.instance.ensureBackgroundSyncScheduled(
        enabled: status.isGranted && state.notificationsEnabled,
      );

      if (client != null) {
        PushNotificationService.instance.startRealtimeListener(
          client,
          userId: user.id,
          role: user.role.name,
          showForegroundBanner: status.isGranted && state.notificationsEnabled,
        );
      }

      if (mounted) {
        state = state.copyWith(
          permissionStatus: status,
          fcmReady: PushNotificationService.instance.isFirebaseReady,
          hasToken: token != null,
        );
      }
    } finally {
      _syncInFlight = false;
    }
  }

  /// Prompts the user explicitly (from Profile / Settings) and registers token.
  Future<PushPermissionStatus> requestPermissionAndEnable() async {
    if (state.isRequesting) return state.permissionStatus;
    state = state.copyWith(isRequesting: true);
    try {
      final status = await PushNotificationService.instance
          .requestPermissions();
      await AppPreferences.setNotificationPrompted(true);

      final enabled = status.isGranted;
      await AppPreferences.setNotificationsEnabled(enabled);

      final client = _client;
      final user = _ref.read(authControllerProvider).user;
      String? token;
      if (client != null && user != null && status.isGranted) {
        token = await PushNotificationService.instance.syncTokenWithSupabase(
          client,
          userId: user.id,
          enabled: true,
        );
        PushNotificationService.instance.startRealtimeListener(
          client,
          userId: user.id,
          role: user.role.name,
          showForegroundBanner: true,
        );
      }

      await PushNotificationService.instance.ensureBackgroundSyncScheduled(
        enabled: status.isGranted,
      );

      if (mounted) {
        state = state.copyWith(
          permissionStatus: status,
          notificationsEnabled: enabled ? true : state.notificationsEnabled,
          isRequesting: false,
          fcmReady: PushNotificationService.instance.isFirebaseReady,
          hasToken: token != null || state.hasToken,
        );
      }
      return status;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isRequesting: false);
      }
      return state.permissionStatus;
    }
  }

  /// Toggles notifications delivery preference for the current device/user.
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled && !state.permissionStatus.isGranted) {
      await requestPermissionAndEnable();
      return;
    }

    await AppPreferences.setNotificationsEnabled(enabled);
    if (mounted) {
      state = state.copyWith(notificationsEnabled: enabled);
    }

    await PushNotificationService.instance.ensureBackgroundSyncScheduled(
      enabled: state.permissionStatus.isGranted && enabled,
    );

    final client = _client;
    final user = _ref.read(authControllerProvider).user;
    if (client != null && user != null) {
      await PushNotificationService.instance.setNotificationsEnabledOnServer(
        client,
        enabled: enabled,
      );
      PushNotificationService.instance.startRealtimeListener(
        client,
        userId: user.id,
        role: user.role.name,
        showForegroundBanner: state.permissionStatus.isGranted && enabled,
      );
    }
  }

  void _refreshNotificationsForCurrentUser() {
    final user = _ref.read(authControllerProvider).user;
    if (user == null) return;
    switch (user.role) {
      case UserRole.customer:
        _ref.invalidate(customerNotificationsProvider);
      case UserRole.shop:
        _ref.invalidate(shopNotificationsProvider);
      case UserRole.admin:
        _ref.invalidate(adminNotificationsProvider);
    }
  }
}
