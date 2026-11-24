import 'dart:convert';

import '../../../../core/notifications/notification_models.dart';

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.isActive,
    this.description,
    this.parentId,
    this.iconKey,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final String? parentId;
  final String? iconKey;

  factory CatalogCategory.fromMap(Map<String, dynamic> map) {
    return CatalogCategory(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      parentId: map['parent_id'] as String?,
      iconKey: map['icon_key'] as String?,
    );
  }
}

/// Includes the selected category and all descendants, with cycle protection.
Set<String> categoryBranchIds(List<CatalogCategory> categories, String id) {
  final ids = <String>{id};
  var changed = true;
  while (changed) {
    changed = false;
    for (final category in categories) {
      if (ids.contains(category.parentId) && ids.add(category.id)) {
        changed = true;
      }
    }
  }
  return ids;
}

typedef CategoryOption = ({CatalogCategory category, CatalogCategory? parent});

/// Orders categories cleanly as parent department followed by its sub-categories.
List<CategoryOption> hierarchicalCategoryOptions(
  List<CatalogCategory> categories,
) {
  final byId = {for (final c in categories) c.id: c};
  final roots = <CatalogCategory>[];
  final childrenByParent = <String, List<CatalogCategory>>{};
  final orphans = <CatalogCategory>[];

  for (final c in categories) {
    if (c.parentId == null) {
      roots.add(c);
    } else if (byId.containsKey(c.parentId)) {
      (childrenByParent[c.parentId!] ??= []).add(c);
    } else {
      orphans.add(c);
    }
  }

  final ordered = <CategoryOption>[];
  for (final root in roots) {
    ordered.add((category: root, parent: null));
    for (final child in childrenByParent[root.id] ?? const <CatalogCategory>[]) {
      ordered.add((category: child, parent: root));
    }
  }
  for (final orphan in orphans) {
    ordered.add((category: orphan, parent: byId[orphan.parentId]));
  }
  return ordered;
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.status,
    this.description,
    this.shopId,
    this.shopName,
    this.shopCity,
    this.categoryName,
    this.originalPrice,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.offerTitle,
    this.offerEndsAt,
    this.coverImage,
  });

  final String id;
  final String name;
  final String? description;
  final double price;
  final String status;
  final String? shopId;
  final String? shopName;
  final String? shopCity;
  final String? categoryName;
  final double? originalPrice;
  final double discountAmount;
  final int discountPercent;
  final String? offerTitle;
  final DateTime? offerEndsAt;
  final String? coverImage;

  bool get isOfferExpired =>
      discountPercent > 0 &&
      offerEndsAt != null &&
      !offerEndsAt!.isAfter(DateTime.now());

  bool get hasOffer =>
      discountPercent > 0 &&
      originalPrice != null &&
      originalPrice! > 0 &&
      !isOfferExpired;

  String get statusLabel {
    switch (status) {
      case 'published':
        return 'منشور';
      case 'hidden':
        return 'مخفي';
      case 'deleted':
        return 'محذوف';
      default:
        return 'مسودة';
    }
  }

  factory AdminProduct.fromMap(Map<String, dynamic> map) {
    final shop = map['shops'];
    final category = map['categories'];
    final details = map['details'] is Map
        ? Map<String, dynamic>.from(map['details'] as Map)
        : const <String, dynamic>{};
    final imagesRaw = map['product_images'];
    String? cover;
    if (imagesRaw is List && imagesRaw.isNotEmpty) {
      final sorted = List<dynamic>.from(imagesRaw)
        ..sort(
          (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
            (b['sort_order'] as num?) ?? 0,
          ),
        );
      cover = sorted.first['file_path'] as String?;
    }
    return AdminProduct(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'draft',
      shopId: map['shop_id'] as String?,
      shopName: shop is Map ? shop['name'] as String? : null,
      shopCity: shop is Map ? shop['city'] as String? : null,
      categoryName: category is Map ? category['name'] as String? : null,
      originalPrice:
          (map['original_price'] as num?)?.toDouble() ??
          (details['original_price'] as num?)?.toDouble(),
      discountAmount:
          (map['discount_amount'] as num?)?.toDouble() ??
          (details['discount_amount'] as num?)?.toDouble() ??
          0,
      discountPercent:
          (map['discount_percent'] as num?)?.toInt() ??
          (details['discount_percent'] as num?)?.toInt() ??
          0,
      offerTitle:
          (map['offer_title'] as String?) ??
          (details['offer_title'] as String?),
      offerEndsAt: DateTime.tryParse(
        (map['offer_ends_at'] ?? details['offer_ends_at'])?.toString() ?? '',
      )?.toLocal(),
      coverImage: cover,
    );
  }
}

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.createdAt,
    this.subtotal,
    this.deliveryFee = 0,
    this.deliveryMode = 'shop_delivery',
    this.paymentMethodName,
    this.paymentAccountNumber,
    this.paymentReceiptUrl,
    this.paymentStatus = 'not_required',
    this.paymentIssueNote,
    this.shopName,
    this.shopCity,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.shippingCity,
    this.shippingAddress,
    this.checkoutGroupId,
    this.groupTotal,
    this.groupShopsCount = 1,
  });

  final String id;
  final String status;
  final double total;
  final double? subtotal;
  final double deliveryFee;
  final String deliveryMode;
  final String? paymentMethodName;
  final String? paymentAccountNumber;
  final String? paymentReceiptUrl;
  final String paymentStatus;
  final String? paymentIssueNote;
  final DateTime createdAt;
  final String? shopName;
  final String? shopCity;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? shippingCity;
  final String? shippingAddress;
  final String? checkoutGroupId;
  final double? groupTotal;
  final int groupShopsCount;

  bool get isCustomerPickup => deliveryMode == 'customer_pickup';
  bool get hasReceipt =>
      paymentReceiptUrl != null && paymentReceiptUrl!.trim().isNotEmpty;
  bool get isPaymentPending => paymentStatus == 'pending_verification';
  bool get isPaymentVerified => paymentStatus == 'verified';
  bool get hasPaymentIssue => paymentStatus == 'issue_reported';
  bool get requiresPaymentVerification =>
      paymentStatus == 'pending_verification' ||
      paymentStatus == 'issue_reported';
  bool get isGroupedPayment =>
      checkoutGroupId != null &&
      checkoutGroupId!.trim().isNotEmpty &&
      groupShopsCount > 1;
  double get effectiveGroupTotal =>
      (groupTotal != null && groupTotal! > 0) ? groupTotal! : total;
  String get deliveryModeLabel =>
      isCustomerPickup ? 'توصيل من الزبون' : 'توصيل من المحل';

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'pending_verification':
        return 'إشعار بانتظار المراجعة';
      case 'verified':
        return 'حوالة مؤكدة';
      case 'issue_reported':
        return 'مشكلة في الحوالة';
      default:
        return 'دفع عادي';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'مؤكد';
      case 'processing':
        return 'قيد التجهيز';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'قيد الانتظار';
    }
  }

  factory AdminOrder.fromMap(Map<String, dynamic> map) {
    final shop = map['shops'];
    final customer = map['profiles'];
    final total = (map['total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (map['delivery_fee'] as num?)?.toDouble() ?? 0;
    final rawSubtotal = (map['subtotal'] as num?)?.toDouble();
    return AdminOrder(
      id: map['id'] as String,
      status: map['status'] as String? ?? 'pending',
      total: total,
      subtotal: (rawSubtotal != null && rawSubtotal > 0)
          ? rawSubtotal
          : (total - deliveryFee).clamp(0.0, total),
      deliveryFee: deliveryFee,
      deliveryMode: map['delivery_mode']?.toString() == 'customer_pickup'
          ? 'customer_pickup'
          : 'shop_delivery',
      paymentMethodName: map['payment_method_name'] as String?,
      paymentAccountNumber: map['payment_account_number'] as String?,
      paymentReceiptUrl: map['payment_receipt_url'] as String?,
      paymentStatus: map['payment_status'] as String? ?? 'not_required',
      paymentIssueNote: map['payment_issue_note'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      shopName: shop is Map ? shop['name'] as String? : null,
      shopCity: shop is Map ? shop['city'] as String? : null,
      customerName: customer is Map ? customer['full_name'] as String? : null,
      customerEmail: customer is Map ? customer['email'] as String? : null,
      customerPhone:
          (map['phone'] as String?) ??
          (customer is Map ? customer['phone'] as String? : null),
      shippingCity:
          (map['shipping_city'] as String?) ??
          (customer is Map ? customer['city'] as String? : null),
      shippingAddress:
          (map['delivery_address'] as String?) ??
          (map['shipping_address'] as String?) ??
          (customer is Map ? customer['address'] as String? : null),
      checkoutGroupId: map['checkout_group_id']?.toString(),
      groupTotal: (map['group_total'] as num?)?.toDouble(),
      groupShopsCount: (map['group_shops_count'] as num?)?.toInt() ?? 1,
    );
  }
}

class AdminBanner {
  const AdminBanner({
    required this.id,
    required this.title,
    required this.isActive,
    this.subtitle,
    this.imagePath,
    this.sortOrder = 0,
    this.shopId,
    this.isAutoOffer = false,
    this.ctaLabel,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imagePath;
  final bool isActive;
  final int sortOrder;
  final String? shopId;
  final bool isAutoOffer;
  final String? ctaLabel;

  bool get isShopBanner => shopId != null && shopId!.trim().isNotEmpty;

  factory AdminBanner.fromMap(Map<String, dynamic> map) {
    return AdminBanner(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      imagePath: map['image_path'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      shopId: map['shop_id'] as String?,
      isAutoOffer: map['is_auto_offer'] as bool? ?? false,
      ctaLabel: map['cta_label'] as String?,
    );
  }
}

class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.createdAt,
    this.shopId,
    this.senderRole = 'system',
    this.targetScope = 'audience',
    this.targetRegion,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final DateTime createdAt;
  final String? shopId;
  final String senderRole;
  final String targetScope;
  final String? targetRegion;
  final Map<String, dynamic> metadata;

  bool get isSentByShop => senderRole == 'shop';

  String? get route {
    final raw = metadata['route']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  String? get eventType {
    final raw = metadata['event_type']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  String? get imageUrl {
    final raw = metadata['image_url']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  String? get orderId {
    final raw = metadata['order_id']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  String? get productId {
    final raw = metadata['product_id']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  bool get hasDeepLink => route != null;

  NotificationCategory get category => NotificationCategory.resolve(
    explicitCategory: metadata['category']?.toString(),
    eventType: eventType,
    senderRole: senderRole,
    audience: audience,
    title: title,
  );

  String get audienceLabel {
    if (targetRegion != null && targetRegion!.trim().isNotEmpty) {
      return 'منطقة: ${targetRegion!.trim()}';
    }
    if (targetScope == 'shop_customers') {
      return 'عملاء المحل';
    }
    if (targetScope == 'all_customers') {
      return 'جميع العملاء';
    }
    switch (audience) {
      case 'customer':
        return 'المستخدمون';
      case 'shop':
        return 'المحلات';
      default:
        return 'الجميع';
    }
  }

  static Map<String, dynamic> _parseMetadata(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      audience: map['audience'] as String? ?? 'all',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      shopId: map['shop_id'] as String?,
      senderRole: map['sender_role'] as String? ?? 'system',
      targetScope: map['target_scope'] as String? ?? 'audience',
      targetRegion: map['target_region'] as String?,
      metadata: _parseMetadata(map['metadata']),
    );
  }
}

class PlatformSetting {
  const PlatformSetting({
    required this.key,
    required this.value,
    required this.label,
  });

  final String key;
  final String value;
  final String label;

  factory PlatformSetting.fromMap(Map<String, dynamic> map) {
    return PlatformSetting(
      key: map['key'] as String,
      value: map['value'] as String? ?? '',
      label: map['label'] as String? ?? '',
    );
  }
}

class ShopDocument {
  const ShopDocument({
    required this.id,
    required this.docType,
    required this.filePath,
  });

  final String id;
  final String docType;
  final String filePath;

  factory ShopDocument.fromMap(Map<String, dynamic> map) {
    return ShopDocument(
      id: map['id'] as String,
      docType: map['doc_type'] as String? ?? '',
      filePath: map['file_path'] as String? ?? '',
    );
  }
}
