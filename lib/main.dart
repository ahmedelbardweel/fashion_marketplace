import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/offline/background_preloader_service.dart';
import 'core/offline/local_database.dart';
import 'core/offline/network_monitor_service.dart';
import 'core/offline/offline_security_service.dart';
import 'core/offline/offline_sync_engine.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/config_error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppPreferences.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Initialize hardware-backed AES-256-GCM encryption & local SQLite tables
  await OfflineSecurityService.instance.initialize();
  await LocalDatabase.instance.initialize();

  try {
    await dotenv.load(fileName: '.env');
    await SupabaseConfig.initialize();
  } catch (error) {
    runApp(ConfigErrorScreen(message: error.toString()));
    return;
  }

  // Initialize real-time network monitor & offline outbox sync engine
  await NetworkMonitorService.instance.initialize();
  await OfflineSyncEngine.instance.initialize();

  // Silently preload all tables from Supabase into local SQLite in the background
  unawaited(BackgroundPreloaderService.instance.preloadAllSilently());

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: FashionMarketplaceApp(),
    ),
  );
}
