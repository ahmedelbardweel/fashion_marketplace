import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/in_app_notification_overlay.dart';
import 'core/notifications/push_notification_provider.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/offline/background_preloader_service.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/offline_sync_engine.dart';
import 'core/theme/app_design.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/providers/admin_providers.dart';
import 'features/auth/domain/models/user_role.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/customer/presentation/providers/customer_providers.dart';
import 'features/shop/presentation/providers/shop_catalog_providers.dart';
import 'router/app_router.dart';
import 'router/routes.dart';

class FashionMarketplaceApp extends ConsumerStatefulWidget {
  const FashionMarketplaceApp({super.key});

  @override
  ConsumerState<FashionMarketplaceApp> createState() =>
      _FashionMarketplaceAppState();
}

class _FashionMarketplaceAppState extends ConsumerState<FashionMarketplaceApp> {
  StreamSubscription<Map<String, dynamic>>? _tapSub;
  Map<String, dynamic>? _deferredTapData;

  @override
  void initState() {
    super.initState();
    _tapSub = PushNotificationService.instance.onNotificationTap.listen((data) {
      _handleNotificationTap(data);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pendingTap =
          PushNotificationService.instance.consumePendingLaunchTap();
      if (pendingTap != null) {
        _handleNotificationTap(pendingTap);
      }
      final auth = ref.read(authControllerProvider);
      if (auth.isAuthenticated && auth.user != null) {
        unawaited(
          ref
              .read(pushNotificationControllerProvider.notifier)
              .handleAuthUser(auth.user),
        );
        unawaited(
          BackgroundPreloaderService.instance.preloadAllSilently(
            currentUser: auth.user,
          ),
        );
        unawaited(OfflineSyncEngine.instance.syncPendingActions());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_tapSub?.cancel());
    super.dispose();
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    final splashDone = ref.read(splashCompletedProvider);
    final user = auth.user;
    if (!auth.isAuthenticated || user == null || !splashDone) {
      // App was cold-launched from a terminated state via notification tap;
      // defer navigation until both session restore and Splash finish so
      // GoRouter never redirects the deep-link back to /splash.
      _deferredTapData = data;
      return;
    }
    _deferredTapData = null;

    final notifId = (data['notification_id'] as String?)?.trim() ?? '';
    if (notifId.isNotEmpty) {
      ref.read(readNotificationIdsProvider.notifier).markRead(notifId);
    }

    // Refresh relevant screens so the user sees fresh order/notification data.
    switch (user.role) {
      case UserRole.customer:
        ref.invalidate(customerNotificationsProvider);
        ref.invalidate(customerOrdersProvider);
      case UserRole.shop:
        ref.invalidate(shopNotificationsProvider);
        ref.invalidate(shopOrdersProvider);
      case UserRole.admin:
        ref.invalidate(adminNotificationsProvider);
        ref.invalidate(adminOrdersProvider);
    }

    final router = ref.read(goRouterProvider);

    final rawRoute = (data['route'] as String?)?.trim() ?? '';
    final rolePrefix = switch (user.role) {
      UserRole.admin => AppRoutes.adminRoot,
      UserRole.shop => AppRoutes.shopRoot,
      UserRole.customer => AppRoutes.customerRoot,
    };

    if (rawRoute.isNotEmpty && rawRoute.startsWith(rolePrefix)) {
      router.push(rawRoute);
      return;
    }

    switch (user.role) {
      case UserRole.admin:
        router.push(AppRoutes.adminNotifications);
      case UserRole.shop:
        router.push(AppRoutes.shopNotifications);
      case UserRole.customer:
        router.push(AppRoutes.customerNotifications);
    }
  }

  void _flushDeferredTapIfReady() {
    final deferred =
        _deferredTapData ??
        PushNotificationService.instance.consumePendingLaunchTap();
    if (deferred == null) return;
    final auth = ref.read(authControllerProvider);
    final splashDone = ref.read(splashCompletedProvider);
    if (!auth.isAuthenticated || auth.user == null || !splashDone) {
      _deferredTapData = deferred;
      return;
    }
    _deferredTapData = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleNotificationTap(deferred);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthSessionState>(authControllerProvider, (previous, next) {
      final prevId = previous?.isAuthenticated == true
          ? previous?.user?.id
          : null;
      final nextUser = next.isAuthenticated ? next.user : null;
      if (prevId != nextUser?.id) {
        unawaited(
          ref
              .read(pushNotificationControllerProvider.notifier)
              .handleAuthUser(nextUser),
        );
        if (nextUser != null) {
          unawaited(
            BackgroundPreloaderService.instance.preloadAllSilently(
              currentUser: nextUser,
              force: true,
            ),
          );
          unawaited(OfflineSyncEngine.instance.syncPendingActions());

          // Complete deferred deep-link navigation once both Auth & Splash finish.
          _flushDeferredTapIfReady();
        }
      }
    });

    ref.listen<bool>(splashCompletedProvider, (previous, next) {
      if (next && previous != true) {
        _flushDeferredTapIfReady();
      }
    });

    // When offline sync finishes pushing queued actions to Supabase,
    // refresh active providers so official server IDs & states are reflected.
    ref.listen<AsyncValue<SyncStatusSnapshot>>(syncStatusProvider, (
      previous,
      next,
    ) {
      final wasSyncing = previous?.valueOrNull?.isSyncing ?? false;
      final nowSyncing = next.valueOrNull?.isSyncing ?? false;
      if (wasSyncing && !nowSyncing) {
        ref.invalidate(customerOrdersProvider);
        ref.invalidate(customerBannersProvider);
        ref.invalidate(customerCategoriesProvider);
        ref.invalidate(customerShopsProvider);
        unawaited(ref.read(cartProvider.notifier).loadFromRemote());
        unawaited(
          ref.read(productComparisonProvider.notifier).loadFromRemote(),
        );
      }
    });

    ref.watch(pushNotificationControllerProvider);
    ref.watch(syncStatusProvider);
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final isDark = themeMode == ThemeMode.dark;
    AppColors.isDark = isDark;
    AppLang.isEn = locale.languageCode == 'en';

    return MaterialApp.router(
      title: 'وصلة',
      onGenerateTitle: (_) => 'وصلة',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        AppColors.isDark = isDark;
        AppLang.isEn = locale.languageCode == 'en';
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: Directionality(
            textDirection: locale.languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: KeyedSubtree(
              key: ValueKey('${themeMode.name}_${locale.languageCode}'),
              child: InAppNotificationOverlay(
                onNotificationTap: _handleNotificationTap,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
