import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Top-level background handler required by firebase_messaging when the app is
/// terminated or in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await PushNotificationService.initializeFirebaseIfConfigured();
}

/// Coordinates FCM remote push notifications, local OS notification banners,
/// runtime permission prompts (iOS & Android 13+), and Supabase token sync.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String androidChannelId = 'shopy_notifications';
  static const String androidChannelName = 'إشعارات Shopy';
  static const String androidChannelDescription =
      'تنبيهات الطلبات والعروض وإشعارات المتاجر والإدارة';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _firebaseReady = false;
  String? _currentToken;
  String? _lastSyncedUserId;
  bool _lastSyncedEnabled = true;

  final Set<String> _recentlyDisplayedIds = <String>{};

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  RealtimeChannel? _realtimeChannel;

  final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _incomingRefreshController =
      StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap => _tapController.stream;
  Stream<void> get onIncomingNotification => _incomingRefreshController.stream;

  bool get isFirebaseReady => _firebaseReady;
  String? get currentToken => _currentToken;

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

  /// Reads optional FirebaseOptions from `.env` so both Android & iOS can
  /// initialize FCM cleanly without requiring native config files in git.
  static FirebaseOptions? firebaseOptionsFromEnv() {
    if (!dotenv.isInitialized) return null;
    final env = dotenv.env;
    final projectId = (env['FIREBASE_PROJECT_ID'] ?? '').trim();
    final senderId = (env['FIREBASE_MESSAGING_SENDER_ID'] ?? '').trim();
    if (projectId.isEmpty || senderId.isEmpty) return null;

    final storageBucket = (env['FIREBASE_STORAGE_BUCKET'] ?? '').trim();
    final bucket = storageBucket.isEmpty ? null : storageBucket;

    if (kIsWeb) {
      final apiKey = (env['FIREBASE_WEB_API_KEY'] ?? '').trim();
      final appId = (env['FIREBASE_WEB_APP_ID'] ?? '').trim();
      if (apiKey.isEmpty || appId.isEmpty) return null;
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: bucket,
        authDomain: (env['FIREBASE_AUTH_DOMAIN'] ?? '').trim().isEmpty
            ? null
            : env['FIREBASE_AUTH_DOMAIN']!.trim(),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final apiKey = (env['FIREBASE_IOS_API_KEY'] ?? '').trim();
      final appId = (env['FIREBASE_IOS_APP_ID'] ?? '').trim();
      if (apiKey.isEmpty || appId.isEmpty) return null;
      final bundleId = (env['FIREBASE_IOS_BUNDLE_ID'] ?? '').trim();
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: bucket,
        iosBundleId: bundleId.isEmpty
            ? 'com.example.fashionMarketplace'
            : bundleId,
      );
    }

    final apiKey = (env['FIREBASE_ANDROID_API_KEY'] ?? '').trim();
    final appId = (env['FIREBASE_ANDROID_APP_ID'] ?? '').trim();
    if (apiKey.isEmpty || appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: bucket,
    );
  }

  /// Initializes Firebase Core if env options or native GoogleService files are present.
  static Future<bool> initializeFirebaseIfConfigured() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;
      final options = firebaseOptionsFromEnv();
      if (options != null) {
        await Firebase.initializeApp(options: options);
        return true;
      }
      await Firebase.initializeApp();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _initializeLocalPlugin();

    _firebaseReady = await initializeFirebaseIfConfigured();
    if (_firebaseReady) {
      await _setupFirebaseMessagingListeners();
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

  Future<void> _setupFirebaseMessagingListeners() async {
    try {
      final messaging = FirebaseMessaging.instance;

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      await _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
        _incomingRefreshController.add(null);
        final title = message.notification?.title ??
            (message.data['title'] as String?) ??
            'Shopy';
        final body = message.notification?.body ??
            (message.data['body'] as String?) ??
            '';
        final notifId =
            (message.data['notification_id'] as String?) ??
            message.messageId ??
            '${title}_${body}_${DateTime.now().millisecondsSinceEpoch}';

        // On iOS, APNs foreground banner is shown via setForegroundNotificationPresentationOptions.
        // On Android, FCM does not display a banner while foregrounded, so we show a local notification.
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          unawaited(
            showLocalNotification(
              id: notifId,
              title: title,
              body: body,
              data: message.data,
            ),
          );
        } else {
          _rememberDisplayedId(notifId);
        }
      });

      await _onOpenedSub?.cancel();
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _tapController.add(message.data);
      });

      await _onTokenRefreshSub?.cancel();
      _onTokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        if (_lastSyncedUserId != null) {
          try {
            unawaited(
              _registerTokenRpc(
                Supabase.instance.client,
                token: newToken,
                enabled: _lastSyncedEnabled,
              ),
            );
          } catch (_) {}
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _tapController.add(initialMessage.data);
      }
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
    if (kIsWeb) {
      if (_firebaseReady) {
        try {
          final settings = await FirebaseMessaging.instance
              .getNotificationSettings();
          return _mapAuthorizationStatus(settings.authorizationStatus);
        } catch (_) {}
      }
      return PushPermissionStatus.unknown;
    }

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

      if (_firebaseReady) {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        return _mapAuthorizationStatus(settings.authorizationStatus);
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
        if (granted == true) {
          if (_firebaseReady) {
            await FirebaseMessaging.instance.requestPermission();
          }
          return PushPermissionStatus.granted;
        }
        final alreadyEnabled = await androidPlugin?.areNotificationsEnabled();
        if (alreadyEnabled == true) return PushPermissionStatus.granted;
        return PushPermissionStatus.denied;
      } catch (_) {}
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        if (_firebaseReady) {
          final settings = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          final mapped = _mapAuthorizationStatus(settings.authorizationStatus);
          if (mapped.isGranted) return mapped;
        }

        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted == true) return PushPermissionStatus.granted;
        return PushPermissionStatus.denied;
      } catch (_) {}
    }

    if (_firebaseReady) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        return _mapAuthorizationStatus(settings.authorizationStatus);
      } catch (_) {}
    }

    return PushPermissionStatus.unknown;
  }

  PushPermissionStatus _mapAuthorizationStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return PushPermissionStatus.granted;
      case AuthorizationStatus.provisional:
        return PushPermissionStatus.provisional;
      case AuthorizationStatus.denied:
        return PushPermissionStatus.denied;
      case AuthorizationStatus.deniedPermanently:
        return PushPermissionStatus.permanentlyDenied;
      case AuthorizationStatus.notDetermined:
        return PushPermissionStatus.unknown;
    }
  }

  /// Displays a local notification banner unless this notification ID was
  /// already displayed recently (deduplicating FCM + Realtime).
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

    await initialize();

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

  /// Fetches the current FCM token and upserts it into Supabase.
  Future<String?> syncTokenWithSupabase(
    SupabaseClient client, {
    required String userId,
    required bool enabled,
  }) async {
    _lastSyncedUserId = userId;
    _lastSyncedEnabled = enabled;

    await initialize();
    if (!_firebaseReady) return null;

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Wait briefly for APNs token if available; FCM still returns token once APNs is ready.
        await FirebaseMessaging.instance.getAPNSToken();
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return null;
      _currentToken = token;
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
        params: {'p_enabled': enabled, 'p_token': _currentToken},
      );
    } catch (_) {}
  }

  Future<void> unregisterToken(SupabaseClient client) async {
    final token = _currentToken;
    _lastSyncedUserId = null;
    await stopRealtimeListener(client);
    if (token == null || token.isEmpty) return;
    try {
      await client.rpc('unregister_push_token', params: {'p_token': token});
    } catch (_) {}
  }

  /// Listens to new rows in `public.notifications` via Supabase Realtime so
  /// foreground banners and unread badges update instantaneously even before
  /// Firebase keys are configured.
  void startRealtimeListener(
    SupabaseClient client, {
    required String userId,
    required String role,
    required bool showForegroundBanner,
  }) {
    unawaited(stopRealtimeListener(client));
    try {
      final channel = client.channel('public:notifications:$userId:${DateTime.now().microsecondsSinceEpoch}');
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

              // Skip notifications authored by the current user themselves.
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
