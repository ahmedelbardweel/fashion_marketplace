import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/screens/config_error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await dotenv.load(fileName: '.env');
    await SupabaseConfig.initialize();
  } catch (error) {
    runApp(ConfigErrorScreen(message: error.toString()));
    return;
  }

  runApp(
    const ProviderScope(
      child: FashionMarketplaceApp(),
    ),
  );
}
