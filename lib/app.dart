import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/push_notification_provider.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_design.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/models/user_role.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _tapSub = PushNotificationService.instance.onNotificationTap.listen((_) {
      _openNotificationsForCurrentRole();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      if (auth.isAuthenticated && auth.user != null) {
        unawaited(
          ref
              .read(pushNotificationControllerProvider.notifier)
              .handleAuthUser(auth.user),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_tapSub?.cancel());
    super.dispose();
  }

  void _openNotificationsForCurrentRole() {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    final user = auth.user;
    if (!auth.isAuthenticated || user == null) return;
    final router = ref.read(goRouterProvider);
    switch (user.role) {
      case UserRole.admin:
        router.push(AppRoutes.adminNotifications);
      case UserRole.shop:
        router.push(AppRoutes.shopNotifications);
      case UserRole.customer:
        router.push(AppRoutes.customerNotifications);
    }
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
      }
    });

    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final isDark = themeMode == ThemeMode.dark;
    AppColors.isDark = isDark;
    AppLang.isEn = locale.languageCode == 'en';

    return MaterialApp.router(
      title: 'Shopy',
      onGenerateTitle: (_) => 'Shopy',
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
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
