class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    required this.status,
    this.description,
    this.categoryId,
    this.categoryName,
    this.variants = const [],
    this.images = const [],
    this.details = const {},
  });

  final String id;
  final String shopId;
  final String name;
  final String? description;
  final double price;
  final String status;
  final String? categoryId;
  final String? categoryName;
  final List<ProductVariant> variants;
  final List<ProductImage> images;
  final Map<String, dynamic> details;

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

  int get totalStock => variants.fold<int>(0, (sum, item) => sum + item.stock);

  List<ProductImage> get galleryImages =>
      images.where((item) => item.kind != 'ar').toList();

  List<ProductImage> get arImages =>
      images.where((item) => item.kind == 'ar').toList();

  List<ProductImage> get model3dImages => images.where((item) {
    final path = item.filePath.toLowerCase();
    return item.kind == '3d_model' ||
        path.endsWith('.glb') ||
        path.endsWith('.gltf') ||
        path.endsWith('.deepar') ||
        path.endsWith('.fbx');
  }).toList();

  String? get model3dUrl =>
      model3dImages.isNotEmpty ? model3dImages.first.filePath : null;

  bool get has3dModel => model3dUrl != null;

  String? get coverImage {
    if (galleryImages.isNotEmpty) return galleryImages.first.filePath;
    if (images.isNotEmpty) return images.first.filePath;
    return null;
  }

  factory ShopProduct.fromMap(Map<String, dynamic> map) {
    final category = map['categories'];
    final variantsRaw = map['product_variants'];
    final imagesRaw = map['product_images'] is List
        ? List<dynamic>.from(map['product_images'] as List)
        : null;
    imagesRaw?.sort(
      (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
        (b['sort_order'] as num?) ?? 0,
      ),
    );

    return ShopProduct(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'draft',
      categoryId: map['category_id'] as String?,
      details: Map<String, dynamic>.from(map['details'] as Map? ?? {}),
      categoryName: category is Map ? category['name'] as String? : null,
      variants: variantsRaw is List
          ? variantsRaw
                .map(
                  (row) => ProductVariant.fromMap(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
      images: imagesRaw is List
          ? imagesRaw
                .map(
                  (row) => ProductImage.fromMap(
                    Map<String, dynamic>.from(row as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.color,
    required this.size,
    required this.stock,
    this.isActive = true,
  });

  final String id;
  final String productId;
  final String color;
  final String size;
  final int stock;
  final bool isActive;

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      color: map['color'] as String? ?? '',
      size: map['size'] as String? ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.filePath,
    required this.kind,
  });

  final String id;
  final String productId;
  final String filePath;
  final String kind;

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      filePath: map['file_path'] as String? ?? '',
      kind: map['kind'] as String? ?? 'gallery',
    );
  }
}

class ShopStats {
  const ShopStats({
    required this.products,
    required this.publishedProducts,
    required this.orders,
    required this.pendingOrders,
    required this.salesTotal,
    required this.stockUnits,
  });

  final int products;
  final int publishedProducts;
  final int orders;
  final int pendingOrders;
  final double salesTotal;
  final int stockUnits;

  factory ShopStats.fromMap(Map<String, dynamic> map) {
    return ShopStats(
      products: (map['products'] as num?)?.toInt() ?? 0,
      publishedProducts: (map['published_products'] as num?)?.toInt() ?? 0,
      orders: (map['orders'] as num?)?.toInt() ?? 0,
      pendingOrders: (map['pending_orders'] as num?)?.toInt() ?? 0,
      salesTotal: (map['sales_total'] as num?)?.toDouble() ?? 0,
      stockUnits: (map['stock_units'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.createdAt,
    this.customerEmail,
    this.customerName,
  });

  final String id;
  final String status;
  final double total;
  final DateTime createdAt;
  final String? customerEmail;
  final String? customerName;

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

  factory ShopOrder.fromMap(Map<String, dynamic> map) {
    final customer = map['profiles'] ?? map['customer'];
    Map<String, dynamic>? customerMap;
    if (customer is Map) {
      customerMap = Map<String, dynamic>.from(customer);
    }
    return ShopOrder(
      id: map['id'] as String,
      status: map['status'] as String? ?? 'pending',
      total: (map['total'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      customerEmail: customerMap?['email'] as String?,
      customerName: customerMap?['full_name'] as String?,
    );
  }
}

class ShopMediaItem {
  const ShopMediaItem({
    required this.id,
    required this.filePath,
    required this.kind,
  });

  final String id;
  final String filePath;
  final String kind;

  factory ShopMediaItem.fromMap(Map<String, dynamic> map) {
    return ShopMediaItem(
      id: map['id'] as String,
      filePath: map['file_path'] as String? ?? '',
      kind: map['kind'] as String? ?? map['doc_type'] as String? ?? 'gallery',
    );
  }
}
