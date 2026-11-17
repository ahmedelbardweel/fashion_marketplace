import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../config/supabase_config.dart';
import '../../features/admin/domain/models/catalog_models.dart';

enum PushPermissionStatus {
  unknown,
  granted,
  provisional,
  denied,
  permanentlyDenied,
}

extension PushPermissionStatusX on PushPermissionStatus {
  bool get isGranted =>
      this == PushPermissionStatus.granted ||
      this == PushPermissionStatus.provisional;
}

const String _bgSyncUniqueName = 'shopy_notifications_bg_sync';
const String _bgSyncTaskName = 'shopyNotificationsSync';
const String _lastSyncIsoKey = 'app_notifications_last_sync_iso';
const String _shownNotifIdsKey = 'app_notifications_shown_ids';

/// Top-level Workmanager entry point for Android background notification sync
/// without Firebase.
@pragma('vm:entry-point')
void pushNotificationsBackgroundDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _bgSyncTaskName) return true;
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    try {
      try {
        Supabase.instance.client;
      } catch (_) {
        await SupabaseConfig.initialize();
      }
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return true;

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('app_push_notifications_enabled') ?? true;
      if (!enabled) return true;

      await PushNotificationService.instance.initialize(
        registerBackgroundWorker: false,
      );
      await PushNotificationService.instance.checkAndNotifyMissed(
        client,
        userId: user.id,
        prefs: prefs,
      );
    } catch (_) {}
    return true;
  });
}

/// Coordinates runtime notification permissions (iOS & Android 13+),
/// local OS notification banners, Supabase Realtime foreground alerts,
/// Android Workmanager background checks, and native iOS APNs token sync.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String androidChannelId = 'shopy_notifications';
  static const String androidChannelName = 'إشعارات Shopy';
  static const String androidChannelDescription =
      'تنبيهات الطلبات والعروض وإشعارات المتاجر والإدارة';

  static const MethodChannel _apnsChannel = MethodChannel('fashion/apns');

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _apnsListenerRegistered = false;
  bool _workmanagerInitialized = false;
  String? _currentApnsToken;
  String? _lastSyncedUserId;
  bool _lastSyncedEnabled = true;

  final Set<String> _recentlyDisplayedIds = <String>{};
  RealtimeChannel? _realtimeChannel;

  final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _incomingRefreshController =
      StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap => _tapController.stream;
  Stream<void> get onIncomingNotification => _incomingRefreshController.stream;

  String? get currentToken => _currentApnsToken;

  static String get currentPlatformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'android';
    }
  }

  Future<void> initialize({bool registerBackgroundWorker = true}) async {
    if (_initialized) return;
    _initialized = true;

    await _initializeLocalPlugin();
    _setupApnsBridge();

    if (registerBackgroundWorker &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      await _initializeAndroidBackgroundWorker();
    }
  }

  Future<void> _initializeLocalPlugin() async {
    if (kIsWeb) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) {
            _tapController.add(const <String, dynamic>{});
            return;
          }
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map) {
              _tapController.add(Map<String, dynamic>.from(decoded));
              return;
            }
          } catch (_) {}
          _tapController.add(<String, dynamic>{'payload': payload});
        },
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            androidChannelId,
            androidChannelName,
            description: androidChannelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload != null &&
          launchPayload.isNotEmpty) {
        try {
          final decoded = jsonDecode(launchPayload);
          if (decoded is Map) {
            _tapController.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _setupApnsBridge() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_apnsListenerRegistered) return;
    _apnsListenerRegistered = true;

    _apnsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onToken' && call.arguments is String) {
        final token = (call.arguments as String).trim();
        if (token.isNotEmpty) {
          _currentApnsToken = token;
          if (_lastSyncedUserId != null) {
            try {
              await _registerTokenRpc(
                Supabase.instance.client,
                token: token,
                enabled: _lastSyncedEnabled,
              );
            } catch (_) {}
          }
        }
      } else if (call.method == 'onMessage') {
        _incomingRefreshController.add(null);
      }
    });
  }

  Future<void> _initializeAndroidBackgroundWorker() async {
    if (_workmanagerInitialized) return;
    try {
      await Workmanager().initialize(pushNotificationsBackgroundDispatcher);
      _workmanagerInitialized = true;
    } catch (_) {}
  }

  Future<void> ensureBackgroundSyncScheduled({required bool enabled}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _initializeAndroidBackgroundWorker();
    if (!_workmanagerInitialized) return;
    try {
      if (!enabled) {
        await Workmanager().cancelByUniqueName(_bgSyncUniqueName);
        return;
      }
      await Workmanager().registerPeriodicTask(
        _bgSyncUniqueName,
        _bgSyncTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  Future<void> cancelBackgroundSync() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().cancelByUniqueName(_bgSyncUniqueName);
    } catch (_) {}
  }

  void _rememberDisplayedId(String id) {
    if (id.isEmpty) return;
    _recentlyDisplayedIds.add(id);
    if (_recentlyDisplayedIds.length > 100) {
      _recentlyDisplayedIds.remove(_recentlyDisplayedIds.first);
    }
  }

  /// Checks current OS permission without triggering a user prompt.
  Future<PushPermissionStatus> checkPermissionStatus() async {
    if (kIsWeb) return PushPermissionStatus.unknown;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final enabled = await androidPlugin?.areNotificationsEnabled();
        if (enabled == true) return PushPermissionStatus.granted;
        if (enabled == false) return PushPermissionStatus.denied;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final options = await iosPlugin?.checkPermissions();
        if (options != null) {
          if (options.isEnabled) return PushPermissionStatus.granted;
          if (options.isProvisionalEnabled) {
            return PushPermissionStatus.provisional;
          }
          return PushPermissionStatus.denied;
        }
      }
    } catch (_) {}

    return PushPermissionStatus.unknown;
  }

  /// Requests OS notification permission on Android 13+ and iOS.
  Future<PushPermissionStatus> requestPermissions() async {
    await initialize();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await androidPlugin?.requestNotificationsPermission();
        if (granted == true) return PushPermissionStatus.granted;
        final alreadyEnabled = await androidPlugin?.areNotificationsEnabled();
        if (alreadyEnabled == true) return PushPermissionStatus.granted;
        return PushPermissionStatus.denied;
      } catch (_) {}
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted == true) {
          try {
            await _apnsChannel.invokeMethod<void>('register');
          } catch (_) {}
          return PushPermissionStatus.granted;
        }
        return PushPermissionStatus.denied;
      } catch (_) {}
    }

    return PushPermissionStatus.unknown;
  }

  /// Displays a local OS notification banner unless this notification ID was
  /// already displayed recently.
  Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (kIsWeb) return;
    if (title.trim().isEmpty && body.trim().isEmpty) return;
    if (id.isNotEmpty && _recentlyDisplayedIds.contains(id)) return;
    _rememberDisplayedId(id);

    await initialize(registerBackgroundWorker: false);

    const androidDetails = AndroidNotificationDetails(
      androidChannelId,
      androidChannelName,
      channelDescription: androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final numericId = id.isEmpty
        ? DateTime.now().millisecondsSinceEpoch & 0x7fffffff
        : id.hashCode & 0x7fffffff;

    try {
      await _localNotifications.show(
        id: numericId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: data == null ? null : jsonEncode(data),
      );
    } catch (_) {}
  }

  /// Fetches the native iOS APNs token (when signed with Push capability) and
  /// upserts it into Supabase.
  Future<String?> syncTokenWithSupabase(
    SupabaseClient client, {
    required String userId,
    required bool enabled,
  }) async {
    _lastSyncedUserId = userId;
    _lastSyncedEnabled = enabled;

    await initialize();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;

    try {
      await _apnsChannel.invokeMethod<void>('register');
      final token = (await _apnsChannel.invokeMethod<String>('getToken'))
          ?.trim();
      if (token == null || token.isEmpty) return null;
      _currentApnsToken = token;
      await _registerTokenRpc(client, token: token, enabled: enabled);
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _registerTokenRpc(
    SupabaseClient client, {
    required String token,
    required bool enabled,
  }) async {
    await client.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': currentPlatformName,
        'p_enabled': enabled,
      },
    );
  }

  Future<void> setNotificationsEnabledOnServer(
    SupabaseClient client, {
    required bool enabled,
  }) async {
    _lastSyncedEnabled = enabled;
    try {
      await client.rpc(
        'set_push_notifications_enabled',
        params: {'p_enabled': enabled, 'p_token': _currentApnsToken},
      );
    } catch (_) {}
  }

  Future<void> unregisterToken(SupabaseClient client) async {
    final token = _currentApnsToken;
    _lastSyncedUserId = null;
    await stopRealtimeListener(client);
    await cancelBackgroundSync();
    if (token == null || token.isEmpty) return;
    try {
      await client.rpc('unregister_push_token', params: {'p_token': token});
    } catch (_) {}
  }

  /// Queries Supabase for newly created notifications since the last background
  /// check and displays local OS banners for unseen items.
  Future<void> checkAndNotifyMissed(
    SupabaseClient client, {
    required String userId,
    SharedPreferences? prefs,
  }) async {
    try {
      final storage = prefs ?? await SharedPreferences.getInstance();
      final lastSyncIso = storage.getString('${_lastSyncIsoKey}_$userId');
      final shownList =
          storage.getStringList('${_shownNotifIdsKey}_$userId') ?? <String>[];
      final shownIds = shownList.toSet();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // First run establishes baseline without flooding historical alerts.
      if (lastSyncIso == null || lastSyncIso.isEmpty) {
        await storage.setString('${_lastSyncIsoKey}_$userId', nowIso);
        return;
      }

      final rows = await client
          .from('notifications')
          .select()
          .gt('created_at', lastSyncIso)
          .order('created_at', ascending: true)
          .limit(10);

      final list = rows as List;
      for (final raw in list) {
        final map = Map<String, dynamic>.from(raw as Map);
        final notif = AdminNotification.fromMap(map);
        final createdBy = map['created_by'] as String?;
        if (createdBy == userId || shownIds.contains(notif.id)) continue;

        shownIds.add(notif.id);
        await showLocalNotification(
          id: notif.id,
          title: notif.title,
          body: notif.body,
          data: <String, dynamic>{
            'notification_id': notif.id,
            'audience': notif.audience,
            'sender_role': notif.senderRole,
          },
        );
      }

      if (list.isNotEmpty) {
        _incomingRefreshController.add(null);
      }

      final trimmed = shownIds.toList();
      if (trimmed.length > 100) {
        trimmed.removeRange(0, trimmed.length - 100);
      }
      await storage.setStringList('${_shownNotifIdsKey}_$userId', trimmed);
      await storage.setString('${_lastSyncIsoKey}_$userId', nowIso);
    } catch (_) {}
  }

  /// Listens to new rows in `public.notifications` via Supabase Realtime so
  /// foreground banners and unread badges update instantaneously.
  void startRealtimeListener(
    SupabaseClient client, {
    required String userId,
    required String role,
    required bool showForegroundBanner,
  }) {
    unawaited(stopRealtimeListener(client));
    try {
      final channel = client.channel(
        'public:notifications:$userId:${DateTime.now().microsecondsSinceEpoch}',
      );
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final row = payload.newRecord;
              if (row.isEmpty) return;
              final notif = AdminNotification.fromMap(
                Map<String, dynamic>.from(row),
              );

              final createdBy = row['created_by'] as String?;
              if (createdBy == userId) {
                _incomingRefreshController.add(null);
                return;
              }

              final targetUserId = row['target_user_id'] as String?;
              final matchesUser =
                  targetUserId == userId ||
                  (targetUserId == null &&
                      (notif.audience == 'all' || notif.audience == role));
              if (!matchesUser) return;

              _incomingRefreshController.add(null);

              if (showForegroundBanner) {
                unawaited(
                  showLocalNotification(
                    id: notif.id,
                    title: notif.title,
                    body: notif.body,
                    data: <String, dynamic>{
                      'notification_id': notif.id,
                      'audience': notif.audience,
                      'sender_role': notif.senderRole,
                    },
                  ),
                );
              }
            },
          )
          .subscribe();
      _realtimeChannel = channel;
    } catch (_) {}
  }

  Future<void> stopRealtimeListener(SupabaseClient client) async {
    final existing = _realtimeChannel;
    _realtimeChannel = null;
    if (existing != null) {
      try {
        await client.removeChannel(existing);
      } catch (_) {}
    }
  }
}
