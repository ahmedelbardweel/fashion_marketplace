import 'package:fashion_marketplace/core/l10n/app_translations.dart';
Map<String, dynamic> asStringMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is List && data.isNotEmpty) {
    return asStringMap(data.first);
  }
  throw StateError('استجابة غير صالحة من الخادم'.tr);
}
