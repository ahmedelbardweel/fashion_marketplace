class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    required this.status,
    this.originalPrice,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.offerTitle,
    this.offerStartsAt,
    this.offerEndsAt,
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
  final double? originalPrice;
  final double discountAmount;
  final int discountPercent;
  final String? offerTitle;
  final DateTime? offerStartsAt;
  final DateTime? offerEndsAt;
  final String status;
  final String? categoryId;
  final String? categoryName;
  final List<ProductVariant> variants;
  final List<ProductImage> images;
  final Map<String, dynamic> details;

  double get basePrice =>
      (originalPrice != null && originalPrice! > 0) ? originalPrice! : price;

  bool get isOfferExpired =>
      discountPercent > 0 &&
      offerEndsAt != null &&
      !offerEndsAt!.isAfter(DateTime.now());

  bool get isOfferScheduled =>
      discountPercent > 0 &&
      offerStartsAt != null &&
      offerStartsAt!.isAfter(DateTime.now()) &&
      !isOfferExpired;

  bool get hasOffer =>
      discountPercent > 0 &&
      originalPrice != null &&
      originalPrice! > 0 &&
      discountAmount > 0 &&
      !isOfferExpired &&
      !isOfferScheduled;

  bool get hasAnyOfferConfig => hasOffer || isOfferScheduled;

  double get effectivePrice {
    if (isOfferExpired && originalPrice != null && originalPrice! > 0) {
      return originalPrice!;
    }
    if (hasOffer && originalPrice != null && discountAmount > 0) {
      return (originalPrice! - discountAmount).clamp(0.01, originalPrice!);
    }
    return price;
  }

  String? get offerRemainingLabel {
    if (offerEndsAt == null || isOfferExpired) return null;
    final diff = offerEndsAt!.difference(DateTime.now());
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? 'متبقي يوم واحد' : 'متبقي ${diff.inDays} أيام';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1
          ? 'متبقي ساعة واحدة'
          : 'متبقي ${diff.inHours} ساعات';
    }
    return 'ينتهي قريباً';
  }

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

    final detailsMap = Map<String, dynamic>.from(map['details'] as Map? ?? {});
    final parsedPrice = (map['price'] as num?)?.toDouble() ?? 0;
    final parsedOriginal =
        (map['original_price'] as num?)?.toDouble() ??
        (detailsMap['original_price'] as num?)?.toDouble();
    final parsedDiscountAmount =
        (map['discount_amount'] as num?)?.toDouble() ??
        (detailsMap['discount_amount'] as num?)?.toDouble() ??
        (parsedOriginal != null && parsedOriginal > parsedPrice
            ? parsedOriginal - parsedPrice
            : 0);
    final parsedDiscountPercent =
        (map['discount_percent'] as num?)?.toInt() ??
        (detailsMap['discount_percent'] as num?)?.toInt() ??
        (parsedOriginal != null &&
                parsedOriginal > parsedPrice &&
                parsedOriginal > 0
            ? ((parsedOriginal - parsedPrice) / parsedOriginal * 100).round()
            : 0);
    final parsedOfferTitle =
        (map['offer_title'] as String?)?.trim() ??
        (detailsMap['offer_title'] as String?)?.trim();
    final parsedOfferStartsAt = DateTime.tryParse(
      (map['offer_starts_at'] ?? detailsMap['offer_starts_at'])?.toString() ??
          '',
    )?.toLocal();
    final parsedOfferEndsAt = DateTime.tryParse(
      (map['offer_ends_at'] ?? detailsMap['offer_ends_at'])?.toString() ?? '',
    )?.toLocal();

    return ShopProduct(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: parsedPrice,
      originalPrice: parsedOriginal,
      discountAmount: parsedDiscountAmount,
      discountPercent: parsedDiscountPercent,
      offerTitle: parsedOfferTitle?.isEmpty ?? true ? null : parsedOfferTitle,
      offerStartsAt: parsedOfferStartsAt,
      offerEndsAt: parsedOfferEndsAt,
      status: map['status'] as String? ?? 'draft',
      categoryId: map['category_id'] as String?,
      details: detailsMap,
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
    this.subtotal,
    this.deliveryFee = 0,
    this.deliveryMode = 'shop_delivery',
    this.deliveryAddress,
    this.phone,
    this.notes,
    this.paymentMethodId,
    this.paymentMethodName,
    this.paymentAccountNumber,
    this.paymentReceiptUrl,
    this.paymentStatus = 'not_required',
    this.paymentIssueNote,
    this.paymentVerifiedAt,
    this.customerId,
    this.customerEmail,
    this.customerName,
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
  final String? deliveryAddress;
  final String? phone;
  final String? notes;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String? paymentAccountNumber;
  final String? paymentReceiptUrl;
  final String paymentStatus;
  final String? paymentIssueNote;
  final DateTime? paymentVerifiedAt;
  final DateTime createdAt;
  final String? customerId;
  final String? customerEmail;
  final String? customerName;
  final String? checkoutGroupId;
  final double? groupTotal;
  final int groupShopsCount;

  double get effectiveSubtotal =>
      subtotal ?? (total - deliveryFee).clamp(0.0, total);
  bool get isCustomerPickup => deliveryMode == 'customer_pickup';
  bool get isShopDelivery => !isCustomerPickup;
  bool get isPaymentPending => paymentStatus == 'pending_verification';
  bool get isPaymentVerified => paymentStatus == 'verified';
  bool get hasPaymentIssue => paymentStatus == 'issue_reported';
  bool get requiresPaymentVerification =>
      paymentStatus == 'pending_verification' ||
      paymentStatus == 'issue_reported';
  bool get hasReceipt =>
      paymentReceiptUrl != null && paymentReceiptUrl!.trim().isNotEmpty;
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

  factory ShopOrder.fromMap(Map<String, dynamic> map) {
    final customer = map['profiles'] ?? map['customer'];
    Map<String, dynamic>? customerMap;
    if (customer is Map) {
      customerMap = Map<String, dynamic>.from(customer);
    }
    final total = (map['total'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (map['delivery_fee'] as num?)?.toDouble() ?? 0;
    final rawSubtotal = (map['subtotal'] as num?)?.toDouble();
    final subtotal = (rawSubtotal != null && rawSubtotal > 0)
        ? rawSubtotal
        : (total - deliveryFee).clamp(0.0, total);
    return ShopOrder(
      id: map['id'] as String,
      status: map['status'] as String? ?? 'pending',
      customerId: map['customer_id'] as String?,
      total: total,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      deliveryMode: map['delivery_mode']?.toString() == 'customer_pickup'
          ? 'customer_pickup'
          : 'shop_delivery',
      deliveryAddress: map['delivery_address'] as String?,
      phone:
          (map['phone'] as String?) ?? (customerMap?['phone'] as String?),
      notes: map['notes'] as String?,
      paymentMethodId: map['payment_method_id']?.toString(),
      paymentMethodName: map['payment_method_name'] as String?,
      paymentAccountNumber: map['payment_account_number'] as String?,
      paymentReceiptUrl: map['payment_receipt_url'] as String?,
      paymentStatus: map['payment_status'] as String? ?? 'not_required',
      paymentIssueNote: map['payment_issue_note'] as String?,
      paymentVerifiedAt: map['payment_verified_at'] == null
          ? null
          : DateTime.tryParse(map['payment_verified_at'].toString())?.toLocal(),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      customerEmail: customerMap?['email'] as String?,
      customerName: customerMap?['full_name'] as String?,
      checkoutGroupId: map['checkout_group_id']?.toString(),
      groupTotal: (map['group_total'] as num?)?.toDouble(),
      groupShopsCount: (map['group_shops_count'] as num?)?.toInt() ?? 1,
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
