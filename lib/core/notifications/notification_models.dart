import 'package:flutter/material.dart';

import '../l10n/app_translations.dart';

/// Semantic categories for notifications across Customer, Shop, and Admin roles.
enum NotificationCategory {
  orders,
  offers,
  catalog,
  system;

  String get key => name;

  String get androidChannelId => switch (this) {
    NotificationCategory.orders => 'wasla_orders',
    NotificationCategory.offers => 'wasla_offers',
    NotificationCategory.catalog => 'wasla_catalog',
    NotificationCategory.system => 'wasla_system',
  };

  String get channelName => switch (this) {
    NotificationCategory.orders => 'الطلبات والمدفوعات',
    NotificationCategory.offers => 'العروض والخصومات',
    NotificationCategory.catalog => 'المنتجات والتقييمات',
    NotificationCategory.system => 'النظام والإدارة',
  };

  String get channelDescription => switch (this) {
    NotificationCategory.orders =>
      'تنبيهات الطلبات الجديدة وتحديثات الشحن وإيصالات الدفع والتسويات',
    NotificationCategory.offers =>
      'الخصومات الحصرية والعروض المؤقتة والبنرات الترويجية',
    NotificationCategory.catalog =>
      'وصول المنتجات الجديدة وتقييمات العملاء على القطع',
    NotificationCategory.system =>
      'إشعارات الإدارة وحالة المتجر والاشتراكات وتنبيهات المنصة',
  };

  String get shortLabel => switch (this) {
    NotificationCategory.orders => 'الطلبات',
    NotificationCategory.offers => 'العروض',
    NotificationCategory.catalog => 'المنتجات',
    NotificationCategory.system => 'النظام',
  };

  IconData get icon => switch (this) {
    NotificationCategory.orders => Icons.local_shipping_outlined,
    NotificationCategory.offers => Icons.local_offer_outlined,
    NotificationCategory.catalog => Icons.auto_awesome_outlined,
    NotificationCategory.system => Icons.campaign_outlined,
  };

  Color get accentColor => switch (this) {
    NotificationCategory.orders => const Color(0xFF10B981),
    NotificationCategory.offers => const Color(0xFFF59E0B),
    NotificationCategory.catalog => const Color(0xFF6366F1),
    NotificationCategory.system => const Color(0xFF3B82F6),
  };

  static NotificationCategory resolve({
    String? explicitCategory,
    String? eventType,
    String? senderRole,
    String? audience,
    String? title,
  }) {
    final clean = (explicitCategory ?? '').trim().toLowerCase();
    switch (clean) {
      case 'orders':
        return NotificationCategory.orders;
      case 'offers':
        return NotificationCategory.offers;
      case 'catalog':
        return NotificationCategory.catalog;
      case 'system':
        return NotificationCategory.system;
    }

    final ev = (eventType ?? '').trim().toLowerCase();
    if (ev.contains('order') ||
        ev.contains('receipt') ||
        ev.contains('payment') ||
        ev.contains('settlement') ||
        ev.contains('payout') ||
        ev.contains('delivery')) {
      return NotificationCategory.orders;
    }
    if (ev.contains('offer') ||
        ev.contains('banner') ||
        ev.contains('discount') ||
        ev.contains('promo')) {
      return NotificationCategory.offers;
    }
    if (ev.contains('product') ||
        ev.contains('review') ||
        ev.contains('catalog')) {
      return NotificationCategory.catalog;
    }

    final t = (title ?? '').trim();
    if (t.contains('طلب') ||
        t.contains('حوالة') ||
        t.contains('إيصال') ||
        t.contains('تسوية') ||
        t.contains('شحن')) {
      return NotificationCategory.orders;
    }
    if (t.contains('عرض') || t.contains('خصم') || t.contains('تخفيض')) {
      return NotificationCategory.offers;
    }
    if (t.contains('تقييم') || t.contains('قطعة جديدة') || t.contains('منتج')) {
      return NotificationCategory.catalog;
    }
    if (senderRole == 'shop' && audience == 'customer') {
      return NotificationCategory.offers;
    }
    return NotificationCategory.system;
  }
}

/// Per-category notification preferences synced with Supabase.
class NotificationPreferences {
  const NotificationPreferences({
    this.ordersEnabled = true,
    this.offersEnabled = true,
    this.catalogEnabled = true,
    this.systemEnabled = true,
  });

  final bool ordersEnabled;
  final bool offersEnabled;
  final bool catalogEnabled;
  final bool systemEnabled;

  bool isCategoryEnabled(NotificationCategory category) => switch (category) {
    NotificationCategory.orders => ordersEnabled,
    NotificationCategory.offers => offersEnabled,
    NotificationCategory.catalog => catalogEnabled,
    NotificationCategory.system => systemEnabled,
  };

  NotificationPreferences copyWith({
    bool? ordersEnabled,
    bool? offersEnabled,
    bool? catalogEnabled,
    bool? systemEnabled,
  }) {
    return NotificationPreferences(
      ordersEnabled: ordersEnabled ?? this.ordersEnabled,
      offersEnabled: offersEnabled ?? this.offersEnabled,
      catalogEnabled: catalogEnabled ?? this.catalogEnabled,
      systemEnabled: systemEnabled ?? this.systemEnabled,
    );
  }

  Map<String, dynamic> toRpcParams() => {
    'p_orders_enabled': ordersEnabled,
    'p_offers_enabled': offersEnabled,
    'p_catalog_enabled': catalogEnabled,
    'p_system_enabled': systemEnabled,
  };

  Map<String, dynamic> toJson() => {
    'orders_enabled': ordersEnabled,
    'offers_enabled': offersEnabled,
    'catalog_enabled': catalogEnabled,
    'system_enabled': systemEnabled,
  };

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      ordersEnabled: map['orders_enabled'] != false,
      offersEnabled: map['offers_enabled'] != false,
      catalogEnabled: map['catalog_enabled'] != false,
      systemEnabled: map['system_enabled'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          ordersEnabled == other.ordersEnabled &&
          offersEnabled == other.offersEnabled &&
          catalogEnabled == other.catalogEnabled &&
          systemEnabled == other.systemEnabled;

  @override
  int get hashCode =>
      Object.hash(ordersEnabled, offersEnabled, catalogEnabled, systemEnabled);
}

/// Payload for showing a live in-app floating notification banner.
class InAppNotificationAlert {
  const InAppNotificationAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.data = const {},
    this.imageUrl,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final Map<String, dynamic> data;
  final String? imageUrl;
}

/// Returns human-friendly relative time in Arabic / English.
String formatNotificationRelativeTime(DateTime dateTime, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = dateTime.toLocal();
  final diff = current.difference(local);

  if (diff.isNegative || diff.inSeconds < 60) {
    return 'الآن'.tr;
  }
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    if (AppLang.isEn) return '${m}m ago';
    if (m == 1) return 'منذ دقيقة';
    if (m == 2) return 'منذ دقيقتين';
    if (m <= 10) return 'منذ $m دقائق';
    return 'منذ $m دقيقة';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    if (AppLang.isEn) return '${h}h ago';
    if (h == 1) return 'منذ ساعة';
    if (h == 2) return 'منذ ساعتين';
    if (h <= 10) return 'منذ $h ساعات';
    return 'منذ $h ساعة';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    if (AppLang.isEn) return '${d}d ago';
    if (d == 1) return 'أمس';
    if (d == 2) return 'منذ يومين';
    return 'منذ $d أيام';
  }
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

/// Groups a timestamp into Today / Yesterday / This Week / Earlier.
String notificationDateSectionTitle(DateTime dateTime, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final todayStart = DateTime(current.year, current.month, current.day);
  final local = dateTime.toLocal();
  final itemDay = DateTime(local.year, local.month, local.day);
  final dayDiff = todayStart.difference(itemDay).inDays;

  if (dayDiff <= 0) return 'اليوم'.tr;
  if (dayDiff == 1) return 'أمس'.tr;
  if (dayDiff < 7) return 'هذا الأسبوع'.tr;
  return 'سابقاً'.tr;
}
