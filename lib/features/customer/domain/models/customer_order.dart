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
    this.imagePath,
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
      imagePath: map['image_path']?.toString(),
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
  final String? imagePath;
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
    this.checkoutGroupId,
    this.groupTotal,
    this.groupShopsCount = 1,
    this.items = const [],
  });

  factory CustomerOrder.fromMap(
    Map<String, dynamic> map, {
    List<CustomerOrderItem>? items,
  }) {
    final total = (map['total'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (map['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final rawSubtotal = (map['subtotal'] as num?)?.toDouble();
    final subtotal = (rawSubtotal != null && rawSubtotal > 0)
        ? rawSubtotal
        : (total - deliveryFee).clamp(0.0, total);
    return CustomerOrder(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? 'متجر',
      status: map['status']?.toString() ?? 'pending',
      total: total,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      deliveryMode: map['delivery_mode']?.toString() == 'customer_pickup'
          ? 'customer_pickup'
          : 'shop_delivery',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      deliveryAddress: map['delivery_address']?.toString(),
      phone: map['phone']?.toString(),
      notes: map['notes']?.toString(),
      paymentMethodId: map['payment_method_id']?.toString(),
      paymentMethodName: map['payment_method_name']?.toString(),
      paymentAccountNumber: map['payment_account_number']?.toString(),
      paymentReceiptUrl: map['payment_receipt_url']?.toString(),
      paymentStatus: map['payment_status']?.toString() ?? 'not_required',
      paymentIssueNote: map['payment_issue_note']?.toString(),
      paymentVerifiedAt: map['payment_verified_at'] == null
          ? null
          : DateTime.tryParse(map['payment_verified_at'].toString())?.toLocal(),
      checkoutGroupId: map['checkout_group_id']?.toString(),
      groupTotal: (map['group_total'] as num?)?.toDouble(),
      groupShopsCount: (map['group_shops_count'] as num?)?.toInt() ?? 1,
      items: items ?? const [],
    );
  }

  final String id;
  final String customerId;
  final String shopId;
  final String shopName;
  final String status;
  final double total;
  final double? subtotal;
  final double deliveryFee;
  final String deliveryMode;
  final DateTime createdAt;
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
  final String? checkoutGroupId;
  final double? groupTotal;
  final int groupShopsCount;
  final List<CustomerOrderItem> items;

  double get effectiveSubtotal =>
      subtotal ?? (total - deliveryFee).clamp(0.0, total);

  bool get isGroupedPayment =>
      checkoutGroupId != null &&
      checkoutGroupId!.trim().isNotEmpty &&
      groupShopsCount > 1;
  double get effectiveGroupTotal =>
      (groupTotal != null && groupTotal! > 0) ? groupTotal! : total;

  bool get isCustomerPickup => deliveryMode == 'customer_pickup';
  bool get isShopDelivery => !isCustomerPickup;
  bool get isPaymentPending => paymentStatus == 'pending_verification';
  bool get isPaymentVerified => paymentStatus == 'verified';
  bool get hasPaymentIssue => paymentStatus == 'issue_reported';
  bool get hasReceipt =>
      paymentReceiptUrl != null && paymentReceiptUrl!.trim().isNotEmpty;

  String get deliveryModeLabel =>
      isCustomerPickup ? 'توصيل من الزبون' : 'توصيل من المحل';

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'pending_verification':
        return 'بانتظار مراجعة الإشعار';
      case 'verified':
        return 'تم تأكيد الحوالة';
      case 'issue_reported':
        return 'مشكلة في إشعار الحوالة';
      default:
        return 'دفع عادي';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'تم التأكيد';
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
      case 'confirmed':
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
