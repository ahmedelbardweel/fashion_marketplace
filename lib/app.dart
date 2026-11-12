import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_design.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class FashionMarketplaceApp extends ConsumerWidget {
  const FashionMarketplaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final isDark = themeMode == ThemeMode.dark;
    AppColors.isDark = isDark;
    AppLang.isEn = locale.languageCode == 'en';

    return MaterialApp.router(
      title: locale.languageCode == 'en' ? 'MALABSI' : 'ملابسي',
      onGenerateTitle: (_) =>
          locale.languageCode == 'en' ? 'MALABSI' : 'ملابسي',
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
