import 'package:fashion_marketplace/core/l10n/app_translations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static String get url {
    final value = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    if (value.isEmpty || value.contains('YOUR_PROJECT')) {
      throw StateError(
        'SUPABASE_URL غير مضبوط. حدّث ملف .env بقيم مشروعك.'.tr,
      );
    }
    return value;
  }

  static String get anonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (value.isEmpty || value.contains('YOUR_ANON_KEY')) {
      throw StateError(
        'SUPABASE_ANON_KEY غير مضبوط. حدّث ملف .env بقيم مشروعك.'.tr,
      );
    }
    return value;
  }

  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';

  static String get googleIosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim() ?? '';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
