import '../../../../core/theme/app_design.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    this.nameEn,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? nameEn;
  final String? description;
  final double price;
  final int durationDays;
  final bool isActive;
  final int sortOrder;

  String get displayName =>
      (AppLang.isEn && (nameEn?.trim().isNotEmpty ?? false))
      ? nameEn!.trim()
      : name;

  String get durationLabel {
    if (durationDays == 30) return 'شهر واحد (30 يوم)'.tr;
    if (durationDays == 90) return '3 شهور (90 يوم)'.tr;
    if (durationDays == 180) return '6 شهور (180 يوم)'.tr;
    if (durationDays == 365) return 'سنة كاملة (365 يوم)'.tr;
    return AppLang.isEn ? '$durationDays days' : '$durationDays يوم';
  }

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      nameEn: map['name_en']?.toString(),
      description: map['description']?.toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      durationDays: (map['duration_days'] as num?)?.toInt() ?? 30,
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShopSubscriptionRecord {
  const ShopSubscriptionRecord({
    required this.id,
    required this.shopId,
    required this.planName,
    required this.amount,
    required this.durationDays,
    required this.receiptUrl,
    required this.status,
    this.shopName = '',
    this.shopCity,
    this.ownerName,
    this.ownerPhone,
    this.planId,
    this.paymentMethodName,
    this.paymentAccountNumber,
    this.isRenewal = false,
    this.notes,
    this.rejectionReason,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String shopId;
  final String shopName;
  final String? shopCity;
  final String? ownerName;
  final String? ownerPhone;
  final String? planId;
  final String planName;
  final double amount;
  final int durationDays;
  final String? paymentMethodName;
  final String? paymentAccountNumber;
  final String receiptUrl;
  final String status; // 'pending' | 'approved' | 'rejected' | 'expired'
  final bool isRenewal;
  final String? notes;
  final String? rejectionReason;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'معتمد ومفعّل'.tr;
      case 'rejected':
        return 'مرفوض'.tr;
      case 'expired':
        return 'منتهي'.tr;
      default:
        return 'بانتظار المراجعة'.tr;
    }
  }

  factory ShopSubscriptionRecord.fromMap(Map<String, dynamic> map) {
    return ShopSubscriptionRecord(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? '',
      shopCity: map['shop_city']?.toString(),
      ownerName: map['owner_name']?.toString(),
      ownerPhone: map['owner_phone']?.toString(),
      planId: map['plan_id']?.toString(),
      planName: map['plan_name']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      durationDays: (map['duration_days'] as num?)?.toInt() ?? 30,
      paymentMethodName: map['payment_method_name']?.toString(),
      paymentAccountNumber: map['payment_account_number']?.toString(),
      receiptUrl: map['receipt_url']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      isRenewal: map['is_renewal'] as bool? ?? false,
      notes: map['notes']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      startsAt: map['starts_at'] == null
          ? null
          : DateTime.tryParse(map['starts_at'].toString())?.toLocal(),
      endsAt: map['ends_at'] == null
          ? null
          : DateTime.tryParse(map['ends_at'].toString())?.toLocal(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
      reviewedAt: map['reviewed_at'] == null
          ? null
          : DateTime.tryParse(map['reviewed_at'].toString())?.toLocal(),
    );
  }
}

class ShopPayoutRecord {
  const ShopPayoutRecord({
    required this.id,
    required this.shopId,
    required this.amount,
    required this.paymentMethod,
    this.referenceNo,
    this.receiptUrl,
    this.notes,
    this.paidAt,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final double amount;
  final String paymentMethod;
  final String? referenceNo;
  final String? receiptUrl;
  final String? notes;
  final DateTime? paidAt;
  final DateTime? createdAt;

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'bank_transfer':
        return 'تحويل بنكي'.tr;
      case 'wallet':
        return 'محفظة إلكترونية'.tr;
      case 'cash':
        return 'نقدي'.tr;
      default:
        return paymentMethod;
    }
  }

  factory ShopPayoutRecord.fromMap(Map<String, dynamic> map) {
    return ShopPayoutRecord(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method']?.toString() ?? 'bank_transfer',
      referenceNo: map['reference_no']?.toString(),
      receiptUrl: map['receipt_url']?.toString(),
      notes: map['notes']?.toString(),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.tryParse(map['paid_at'].toString())?.toLocal(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
    );
  }
}

class ShopStatementOrder {
  const ShopStatementOrder({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.paymentStatus,
    this.deliveryMode,
    this.paymentMethodName,
    this.customerName = '',
    this.createdAt,
  });

  final String id;
  final String status;
  final String? paymentStatus;
  final String? deliveryMode;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String? paymentMethodName;
  final String customerName;
  final DateTime? createdAt;

  bool get isCountedInBalance =>
      status != 'cancelled' &&
      (paymentStatus == 'verified' || status == 'delivered');

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'بانتظار التأكيد'.tr;
      case 'confirmed':
        return 'تم التأكيد'.tr;
      case 'preparing':
        return 'قيد التجهيز'.tr;
      case 'out_for_delivery':
        return 'في الطريق'.tr;
      case 'delivered':
        return 'تم التسليم'.tr;
      case 'cancelled':
        return 'ملغي'.tr;
      default:
        return status;
    }
  }

  factory ShopStatementOrder.fromMap(Map<String, dynamic> map) {
    return ShopStatementOrder(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      paymentStatus: map['payment_status']?.toString(),
      deliveryMode: map['delivery_mode']?.toString(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethodName: map['payment_method_name']?.toString(),
      customerName: map['customer_name']?.toString() ?? 'عميل'.tr,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
    );
  }
}

class ShopFinancialSummary {
  const ShopFinancialSummary({
    required this.shopId,
    required this.shopName,
    this.shopCity,
    this.shopStatus = 'approved',
    this.ownerName,
    this.ownerPhone,
    this.subscriptionStatus = 'none',
    this.subscriptionPlanName,
    this.subscriptionPrice = 0,
    this.subscriptionStartsAt,
    this.subscriptionEndsAt,
    this.hasPendingSubscription = false,
    this.totalOrders = 0,
    this.deliveredOrders = 0,
    this.inProgressOrders = 0,
    this.cancelledOrders = 0,
    this.verifiedSales = 0,
    this.inProgressSales = 0,
    this.totalPaidOut = 0,
    this.remainingOwed = 0,
    this.payoutsCount = 0,
    this.lastPayoutAt,
  });

  final String shopId;
  final String shopName;
  final String? shopCity;
  final String shopStatus;
  final String? ownerName;
  final String? ownerPhone;
  final String subscriptionStatus;
  final String? subscriptionPlanName;
  final double subscriptionPrice;
  final DateTime? subscriptionStartsAt;
  final DateTime? subscriptionEndsAt;
  final bool hasPendingSubscription;
  final int totalOrders;
  final int deliveredOrders;
  final int inProgressOrders;
  final int cancelledOrders;
  final double verifiedSales;
  final double inProgressSales;
  final double totalPaidOut;
  final double remainingOwed;
  final int payoutsCount;
  final DateTime? lastPayoutAt;

  bool get isSubscriptionActive =>
      subscriptionStatus == 'active' &&
      (subscriptionEndsAt == null ||
          subscriptionEndsAt!.isAfter(DateTime.now()));

  bool get isSubscriptionExpired =>
      subscriptionStatus == 'expired' ||
      (subscriptionStatus == 'active' &&
          subscriptionEndsAt != null &&
          !subscriptionEndsAt!.isAfter(DateTime.now()));

  factory ShopFinancialSummary.fromMap(Map<String, dynamic> map) {
    return ShopFinancialSummary(
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? '',
      shopCity: map['shop_city']?.toString(),
      shopStatus: map['shop_status']?.toString() ?? 'approved',
      ownerName: map['owner_name']?.toString(),
      ownerPhone: map['owner_phone']?.toString(),
      subscriptionStatus: map['subscription_status']?.toString() ?? 'none',
      subscriptionPlanName: map['subscription_plan_name']?.toString(),
      subscriptionPrice:
          (map['subscription_price'] as num?)?.toDouble() ?? 0.0,
      subscriptionStartsAt: map['subscription_starts_at'] == null
          ? null
          : DateTime.tryParse(
              map['subscription_starts_at'].toString(),
            )?.toLocal(),
      subscriptionEndsAt: map['subscription_ends_at'] == null
          ? null
          : DateTime.tryParse(
              map['subscription_ends_at'].toString(),
            )?.toLocal(),
      hasPendingSubscription: map['has_pending_subscription'] as bool? ?? false,
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (map['delivered_orders'] as num?)?.toInt() ?? 0,
      inProgressOrders: (map['in_progress_orders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (map['cancelled_orders'] as num?)?.toInt() ?? 0,
      verifiedSales: (map['verified_sales'] as num?)?.toDouble() ?? 0.0,
      inProgressSales: (map['in_progress_sales'] as num?)?.toDouble() ?? 0.0,
      totalPaidOut: (map['total_paid_out'] as num?)?.toDouble() ?? 0.0,
      remainingOwed: (map['remaining_owed'] as num?)?.toDouble() ?? 0.0,
      payoutsCount: (map['payouts_count'] as num?)?.toInt() ?? 0,
      lastPayoutAt: map['last_payout_at'] == null
          ? null
          : DateTime.tryParse(map['last_payout_at'].toString())?.toLocal(),
    );
  }
}

class AdminSubscriptionPayoutOverview {
  const AdminSubscriptionPayoutOverview({
    this.totalSubscriptionRevenue = 0,
    this.activeSubscriptionsCount = 0,
    this.expiredSubscriptionsCount = 0,
    this.pendingSubscriptionsCount = 0,
    this.totalShopsSales = 0,
    this.totalPaidToShops = 0,
    this.totalOwedToShops = 0,
    this.shops = const [],
    this.subscriptions = const [],
  });

  final double totalSubscriptionRevenue;
  final int activeSubscriptionsCount;
  final int expiredSubscriptionsCount;
  final int pendingSubscriptionsCount;
  final double totalShopsSales;
  final double totalPaidToShops;
  final double totalOwedToShops;
  final List<ShopFinancialSummary> shops;
  final List<ShopSubscriptionRecord> subscriptions;

  factory AdminSubscriptionPayoutOverview.fromMap(Map<String, dynamic> map) {
    final shopsRaw = map['shops'] is List ? map['shops'] as List : const [];
    final subsRaw = map['subscriptions'] is List
        ? map['subscriptions'] as List
        : const [];
    return AdminSubscriptionPayoutOverview(
      totalSubscriptionRevenue:
          (map['total_subscription_revenue'] as num?)?.toDouble() ?? 0.0,
      activeSubscriptionsCount:
          (map['active_subscriptions_count'] as num?)?.toInt() ?? 0,
      expiredSubscriptionsCount:
          (map['expired_subscriptions_count'] as num?)?.toInt() ?? 0,
      pendingSubscriptionsCount:
          (map['pending_subscriptions_count'] as num?)?.toInt() ?? 0,
      totalShopsSales: (map['total_shops_sales'] as num?)?.toDouble() ?? 0.0,
      totalPaidToShops: (map['total_paid_to_shops'] as num?)?.toDouble() ?? 0.0,
      totalOwedToShops: (map['total_owed_to_shops'] as num?)?.toDouble() ?? 0.0,
      shops: shopsRaw
          .map(
            (e) => ShopFinancialSummary.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      subscriptions: subsRaw
          .map(
            (e) => ShopSubscriptionRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class ShopFinancialStatement {
  const ShopFinancialStatement({
    required this.shopId,
    required this.shopName,
    this.shopCity,
    this.ownerName,
    this.ownerPhone,
    this.subscriptionStatus = 'none',
    this.subscriptionPlanName,
    this.subscriptionPrice = 0,
    this.subscriptionStartsAt,
    this.subscriptionEndsAt,
    this.daysRemaining = 0,
    this.totalOrders = 0,
    this.deliveredOrders = 0,
    this.inProgressOrders = 0,
    this.cancelledOrders = 0,
    this.verifiedSales = 0,
    this.inProgressSales = 0,
    this.totalPaidOut = 0,
    this.remainingOwed = 0,
    this.orders = const [],
    this.payouts = const [],
    this.subscriptions = const [],
  });

  final String shopId;
  final String shopName;
  final String? shopCity;
  final String? ownerName;
  final String? ownerPhone;
  final String subscriptionStatus;
  final String? subscriptionPlanName;
  final double subscriptionPrice;
  final DateTime? subscriptionStartsAt;
  final DateTime? subscriptionEndsAt;
  final int daysRemaining;
  final int totalOrders;
  final int deliveredOrders;
  final int inProgressOrders;
  final int cancelledOrders;
  final double verifiedSales;
  final double inProgressSales;
  final double totalPaidOut;
  final double remainingOwed;
  final List<ShopStatementOrder> orders;
  final List<ShopPayoutRecord> payouts;
  final List<ShopSubscriptionRecord> subscriptions;

  bool get isSubscriptionActive =>
      subscriptionStatus == 'active' &&
      (subscriptionEndsAt == null ||
          subscriptionEndsAt!.isAfter(DateTime.now()));

  bool get isSubscriptionExpired =>
      subscriptionStatus == 'expired' ||
      (subscriptionStatus == 'active' &&
          subscriptionEndsAt != null &&
          !subscriptionEndsAt!.isAfter(DateTime.now()));

  bool get hasPendingRenewal => subscriptions.any((s) => s.isPending);

  factory ShopFinancialStatement.fromMap(Map<String, dynamic> map) {
    final ordersRaw = map['orders'] is List ? map['orders'] as List : const [];
    final payoutsRaw = map['payouts'] is List
        ? map['payouts'] as List
        : const [];
    final subsRaw = map['subscriptions'] is List
        ? map['subscriptions'] as List
        : const [];
    return ShopFinancialStatement(
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? '',
      shopCity: map['shop_city']?.toString(),
      ownerName: map['owner_name']?.toString(),
      ownerPhone: map['owner_phone']?.toString(),
      subscriptionStatus: map['subscription_status']?.toString() ?? 'none',
      subscriptionPlanName: map['subscription_plan_name']?.toString(),
      subscriptionPrice:
          (map['subscription_price'] as num?)?.toDouble() ?? 0.0,
      subscriptionStartsAt: map['subscription_starts_at'] == null
          ? null
          : DateTime.tryParse(
              map['subscription_starts_at'].toString(),
            )?.toLocal(),
      subscriptionEndsAt: map['subscription_ends_at'] == null
          ? null
          : DateTime.tryParse(
              map['subscription_ends_at'].toString(),
            )?.toLocal(),
      daysRemaining: (map['days_remaining'] as num?)?.toInt() ?? 0,
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (map['delivered_orders'] as num?)?.toInt() ?? 0,
      inProgressOrders: (map['in_progress_orders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (map['cancelled_orders'] as num?)?.toInt() ?? 0,
      verifiedSales: (map['verified_sales'] as num?)?.toDouble() ?? 0.0,
      inProgressSales: (map['in_progress_sales'] as num?)?.toDouble() ?? 0.0,
      totalPaidOut: (map['total_paid_out'] as num?)?.toDouble() ?? 0.0,
      remainingOwed: (map['remaining_owed'] as num?)?.toDouble() ?? 0.0,
      orders: ordersRaw
          .map(
            (e) =>
                ShopStatementOrder.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      payouts: payoutsRaw
          .map(
            (e) =>
                ShopPayoutRecord.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      subscriptions: subsRaw
          .map(
            (e) => ShopSubscriptionRecord.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}
