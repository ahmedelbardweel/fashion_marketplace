import 'package:shared_preferences/shared_preferences.dart';

/// Persists first-time Virtual Try-On guidelines & terms acceptance per account.
class TryonOnboardingStore {
  TryonOnboardingStore._();

  static const _prefix = 'tryon_guidelines_accepted_v1_';

  static String _key(String userId) {
    final normalized = userId.trim();
    return '$_prefix${normalized.isEmpty ? 'guest' : normalized}';
  }

  static Future<bool> hasAccepted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  static Future<void> markAccepted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }
}
