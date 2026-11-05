class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.color,
    required this.size,
    required this.stock,
    required this.isActive,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      color: map['color']?.toString() ?? '',
      size: map['size']?.toString() ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String productId;
  final String color;
  final String size;
  final int stock;
  final bool isActive;
}

class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.filePath,
    required this.kind,
    required this.sortOrder,
  });

  factory ProductImage.fromMap(Map<String, dynamic> map) {
    return ProductImage(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      filePath: map['file_path']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'gallery',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String productId;
  final String filePath;
  final String kind;
  final int sortOrder;
}

class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromMap(Map<String, dynamic> map) {
    return ProductReview(
      id: map['id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? 'عميل',
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      comment: map['comment']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String productId;
  final String customerId;
  final String customerName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
}

class CustomerProduct {
  const CustomerProduct({
    required this.id,
    required this.shopId,
    required this.shopName,
    this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.price,
    required this.status,
    required this.variants,
    required this.images,
    this.ratingAvg = 5.0,
    this.ratingCount = 0,
    this.isFavorite = false,
  });

  factory CustomerProduct.fromMap(
    Map<String, dynamic> map, {
    List<ProductVariant>? variants,
    List<ProductImage>? images,
    bool isFavorite = false,
    double ratingAvg = 5.0,
    int ratingCount = 0,
  }) {
    return CustomerProduct(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? 'متجر أزياء',
      categoryId: map['category_id']?.toString(),
      categoryName: map['category_name']?.toString(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? 'published',
      variants: variants ?? const [],
      images: images ?? const [],
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      isFavorite: isFavorite,
    );
  }

  final String id;
  final String shopId;
  final String shopName;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final double price;
  final String status;
  final List<ProductVariant> variants;
  final List<ProductImage> images;
  final double ratingAvg;
  final int ratingCount;
  final bool isFavorite;

  String? get coverImage {
    final gallery = images.where((img) => img.kind == 'gallery').toList();
    if (gallery.isNotEmpty) return gallery.first.filePath;
    if (images.isNotEmpty) return images.first.filePath;
    return null;
  }

  String? get arImage {
    final ar = images.where((img) => img.kind == 'ar').toList();
    if (ar.isNotEmpty) return ar.first.filePath;
    return coverImage;
  }

  String? get arFrontImage {
    final ar = images.where((img) => img.kind == 'ar').toList();
    final front = ar
        .where((img) => !img.filePath.toLowerCase().contains('back'))
        .toList();
    if (front.isNotEmpty) return front.first.filePath;
    return arImage;
  }

  String? get arBackImage {
    final ar = images.where((img) => img.kind == 'ar').toList();
    final back = ar
        .where((img) => img.filePath.toLowerCase().contains('back'))
        .toList();
    if (back.isNotEmpty) return back.first.filePath;
    if (ar.length > 1) return ar[1].filePath;
    return null;
  }

  /// Prefer an explicit front reference; never send a 3D asset or rear image.
  String? get tryonReferenceImage {
    final candidates =
        images.where((image) {
          final uri = Uri.tryParse(image.filePath);
          final path = uri?.path.toLowerCase() ?? '';
          return uri?.scheme == 'https' &&
              (image.kind == 'ar' || image.kind == 'gallery') &&
              !RegExp(r'(^|[-_./])(back|rear)([-_./]|$)').hasMatch(path) &&
              !RegExp(r'\.(glb|gltf|fbx|deepar)$').hasMatch(path);
        }).toList()..sort((a, b) {
          final priority = (a.kind == 'ar' ? 0 : 1).compareTo(
            b.kind == 'ar' ? 0 : 1,
          );
          return priority != 0 ? priority : a.sortOrder.compareTo(b.sortOrder);
        });
    return candidates.firstOrNull?.filePath;
  }

  /// 3D Model file URL (.glb, .gltf, .deepar) for 3D Mesh AR Virtual Try-On
  String? get model3dUrl {
    final models = images.where((img) {
      final path = img.filePath.toLowerCase();
      return img.kind == '3d_model' ||
          path.endsWith('.glb') ||
          path.endsWith('.gltf') ||
          path.endsWith('.deepar') ||
          path.endsWith('.fbx');
    }).toList();
    if (models.isNotEmpty) return models.first.filePath;
    return null;
  }

  bool get has3dModel => model3dUrl != null && model3dUrl!.isNotEmpty;

  int get totalStock => variants.fold(0, (sum, v) => sum + v.stock);

  Set<String> get availableColors =>
      variants.where((v) => v.stock > 0).map((v) => v.color).toSet();

  Set<String> get availableSizes =>
      variants.where((v) => v.stock > 0).map((v) => v.size).toSet();

  CustomerProduct copyWith({
    bool? isFavorite,
    double? ratingAvg,
    int? ratingCount,
  }) {
    return CustomerProduct(
      id: id,
      shopId: shopId,
      shopName: shopName,
      categoryId: categoryId,
      categoryName: categoryName,
      name: name,
      description: description,
      price: price,
      status: status,
      variants: variants,
      images: images,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
