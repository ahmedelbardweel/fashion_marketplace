class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.isActive,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;

  factory CatalogCategory.fromMap(Map<String, dynamic> map) {
    return CatalogCategory(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.status,
    this.description,
    this.shopName,
    this.categoryName,
  });

  final String id;
  final String name;
  final String? description;
  final double price;
  final String status;
  final String? shopName;
  final String? categoryName;

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
    return AdminProduct(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'draft',
      shopName: shop is Map ? shop['name'] as String? : null,
      categoryName: category is Map ? category['name'] as String? : null,
    );
  }
}

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.createdAt,
    this.shopName,
    this.customerEmail,
  });

  final String id;
  final String status;
  final double total;
  final DateTime createdAt;
  final String? shopName;
  final String? customerEmail;

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
    return AdminOrder(
      id: map['id'] as String,
      status: map['status'] as String? ?? 'pending',
      total: (map['total'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      shopName: shop is Map ? shop['name'] as String? : null,
      customerEmail: customer is Map ? customer['email'] as String? : null,
    );
  }
}

class AdminBanner {
  const AdminBanner({
    required this.id,
    required this.title,
    required this.isActive,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
  final bool isActive;

  factory AdminBanner.fromMap(Map<String, dynamic> map) {
    return AdminBanner(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      isActive: map['is_active'] as bool? ?? true,
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
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final DateTime createdAt;

  String get audienceLabel {
    switch (audience) {
      case 'customer':
        return 'المستخدمون';
      case 'shop':
        return 'المحلات';
      default:
        return 'الجميع';
    }
  }

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      audience: map['audience'] as String? ?? 'all',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
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
