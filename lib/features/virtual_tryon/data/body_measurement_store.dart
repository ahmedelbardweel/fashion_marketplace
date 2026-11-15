import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/body_measurements.dart';

/// Local, account-scoped storage. No measurements are sent to the try-on service.
class BodyMeasurementStore {
  BodyMeasurementStore(this.profileId);
  final String profileId;
  String get storageKey =>
      'body_measurements.v1.${Uri.encodeComponent(profileId)}';

  Future<BodyMeasurements?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(storageKey);
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      return json is Map<String, dynamic>
          ? BodyMeasurements.fromJson(json)?.customerOnly
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(BodyMeasurements value) async {
    if (!value.isValid) throw const FormatException('Invalid measurements');
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey,
      jsonEncode(value.customerOnly.toJson()),
    )) {
      throw StateError('Could not save measurements');
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(storageKey)) {
      throw StateError('Could not clear measurements');
    }
  }
}
