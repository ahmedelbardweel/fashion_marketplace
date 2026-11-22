import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'core/network/network_guard.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/offline/background_preloader_service.dart';
import 'core/offline/local_database.dart';
import 'core/offline/network_monitor_service.dart';
import 'core/offline/offline_security_service.dart';
import 'core/offline/offline_sync_engine.dart';
import 'core/theme/app_design.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/config_error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run only the tiny local prerequisites in parallel so Flutter renders
  // frame #1 immediately on both iOS & Android with zero launch lag.
  await Future.wait([
    AppPreferences.init(),
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    dotenv.load(fileName: '.env').catchError((_) {}),
  ]);

  final isDark = AppColors.isDark;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  try {
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env');
    }
    await SupabaseConfig.initialize();
  } catch (error) {
    runApp(
      ConfigErrorScreen(
        message: AppErrorMapper.message(
          error,
          fallback:
              'تعذر تشغيل التطبيق حالياً. تحقق من اتصالك بالإنترنت وأعد المحاولة.',
        ),
      ),
    );
    return;
  }

  // Register background FCM handler synchronously, then paint the UI first!
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: FashionMarketplaceApp()));

  // Defer all heavy local/network/push services until after frame #1 is queued
  // so nothing can ever block or stall the splash screen.
  unawaited(_bootstrapBackgroundServices());
}

Future<void> _bootstrapBackgroundServices() async {
  try {
    await Future.wait([
      OfflineSecurityService.instance.initialize().catchError((_) {}),
      LocalDatabase.instance.initialize().catchError((_) {}),
    ]);
  } catch (_) {}

  unawaited(
    NetworkMonitorService.instance
        .initialize()
        .then((_) async {
          await OfflineSyncEngine.instance.initialize();
          unawaited(BackgroundPreloaderService.instance.preloadAllSilently());
        })
        .catchError((_) {}),
  );

  unawaited(
    PushNotificationService.instance
        .initialize()
        .timeout(const Duration(seconds: 6), onTimeout: () {})
        .catchError((_) {}),
  );
}
