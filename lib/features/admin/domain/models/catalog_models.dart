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
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
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
    this.imagePath,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imagePath;
  final bool isActive;
  final int sortOrder;

  factory AdminBanner.fromMap(Map<String, dynamic> map) {
    return AdminBanner(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      imagePath: map['image_path'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
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
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final DateTime createdAt;
  final String? shopId;
  final String senderRole;
  final String targetScope;

  bool get isSentByShop => senderRole == 'shop';

  String get audienceLabel {
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

  factory AdminNotification.fromMap(Map<String, dynamic> map) {
    return AdminNotification(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      audience: map['audience'] as String? ?? 'all',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      shopId: map['shop_id'] as String?,
      senderRole: map['sender_role'] as String? ?? 'system',
      targetScope: map['target_scope'] as String? ?? 'audience',
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
