class CustomerOrderItem {
  const CustomerOrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    this.variantId,
    required this.productName,
    this.variantInfo,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  factory CustomerOrderItem.fromMap(Map<String, dynamic> map) {
    return CustomerOrderItem(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      variantId: map['variant_id']?.toString(),
      productName: map['product_name']?.toString() ?? 'منتج',
      variantInfo: map['variant_info']?.toString(),
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String id;
  final String orderId;
  final String productId;
  final String? variantId;
  final String productName;
  final String? variantInfo;
  final double unitPrice;
  final int quantity;
  final double totalPrice;
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.shopName,
    required this.status,
    required this.total,
    required this.createdAt,
    this.items = const [],
  });

  factory CustomerOrder.fromMap(Map<String, dynamic> map, {List<CustomerOrderItem>? items}) {
    return CustomerOrder(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? 'متجر',
      status: map['status']?.toString() ?? 'pending',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      items: items ?? const [],
    );
  }

  final String id;
  final String customerId;
  final String shopId;
  final String shopName;
  final String status;
  final double total;
  final DateTime createdAt;
  final List<CustomerOrderItem> items;

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'processing':
        return 'جاري التجهيز';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التوصيل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  int get statusStep {
    switch (status) {
      case 'pending':
        return 1;
      case 'processing':
        return 2;
      case 'shipped':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 0;
    }
  }
}
