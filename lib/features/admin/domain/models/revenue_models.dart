class ShopFinancialAccount {
  const ShopFinancialAccount({
    required this.shopId,
    required this.shopName,
    this.shopCity,
    this.status = 'approved',
    this.commissionType = 'percentage',
    this.commissionRate = 5,
    this.commissionFixedFee = 0,
    this.creditLimit = 300,
    this.settlementCycle = 'weekly',
    this.autoSuspendOnLimit = true,
    this.financialHold = false,
    this.agreementVersion = 1,
    this.agreementAcceptedVersion = 0,
    this.agreementAcceptedAt,
    this.agreementNotes,
    this.totalOrders = 0,
    this.deliveredOrders = 0,
    this.cancelledOrders = 0,
    this.deliveredSales = 0,
    this.commissionEarned = 0,
    this.totalPaid = 0,
    this.outstandingBalance = 0,
    this.pendingSettlementsCount = 0,
    this.pendingSettlementsAmount = 0,
  });

  final String shopId;
  final String shopName;
  final String? shopCity;
  final String status;
  final String commissionType;
  final double commissionRate;
  final double commissionFixedFee;
  final double creditLimit;
  final String settlementCycle;
  final bool autoSuspendOnLimit;
  final bool financialHold;
  final int agreementVersion;
  final int agreementAcceptedVersion;
  final DateTime? agreementAcceptedAt;
  final String? agreementNotes;
  final int totalOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final double deliveredSales;
  final double commissionEarned;
  final double totalPaid;
  final double outstandingBalance;
  final int pendingSettlementsCount;
  final double pendingSettlementsAmount;

  bool get isAgreementAccepted =>
      agreementAcceptedVersion >= agreementVersion && agreementVersion > 0;

  double get netShopEarnings =>
      (deliveredSales - commissionEarned).clamp(0.0, double.infinity);

  double get limitUsageRatio => creditLimit > 0
      ? (outstandingBalance / creditLimit).clamp(0.0, 1.0)
      : 0.0;

  bool get isNearLimit => creditLimit > 0 && limitUsageRatio >= 0.8;

  bool get isOverLimit => creditLimit > 0 && outstandingBalance >= creditLimit;

  double get cancellationRate =>
      totalOrders >= 4 ? (cancelledOrders / totalOrders) * 100 : 0.0;

  bool get isHighCancellationRisk => cancellationRate >= 25;

  String get agreementSummaryLabel {
    final rateStr = commissionRate.truncateToDouble() == commissionRate
        ? commissionRate.toStringAsFixed(0)
        : commissionRate.toStringAsFixed(1);
    final fixedStr =
        commissionFixedFee.truncateToDouble() == commissionFixedFee
        ? commissionFixedFee.toStringAsFixed(0)
        : commissionFixedFee.toStringAsFixed(2);
    switch (commissionType) {
      case 'fixed':
        return '$fixedStr ₪ / طلب';
      case 'hybrid':
        return '$rateStr% + $fixedStr ₪';
      default:
        return '$rateStr%';
    }
  }

  String get cycleLabel {
    switch (settlementCycle) {
      case 'biweekly':
        return 'كل أسبوعين';
      case 'monthly':
        return 'شهرياً';
      default:
        return 'أسبوعياً';
    }
  }

  factory ShopFinancialAccount.fromMap(Map<String, dynamic> map) {
    return ShopFinancialAccount(
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString() ?? '',
      shopCity: map['shop_city']?.toString(),
      status: map['status']?.toString() ?? 'approved',
      commissionType: map['commission_type']?.toString() ?? 'percentage',
      commissionRate: (map['commission_rate'] as num?)?.toDouble() ?? 5,
      commissionFixedFee:
          (map['commission_fixed_fee'] as num?)?.toDouble() ?? 0,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 300,
      settlementCycle: map['settlement_cycle']?.toString() ?? 'weekly',
      autoSuspendOnLimit: map['auto_suspend_on_limit'] as bool? ?? true,
      financialHold: map['financial_hold'] as bool? ?? false,
      agreementVersion: (map['agreement_version'] as num?)?.toInt() ?? 1,
      agreementAcceptedVersion:
          (map['agreement_accepted_version'] as num?)?.toInt() ?? 0,
      agreementAcceptedAt: DateTime.tryParse(
        map['agreement_accepted_at']?.toString() ?? '',
      )?.toLocal(),
      agreementNotes: map['agreement_notes']?.toString(),
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (map['delivered_orders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (map['cancelled_orders'] as num?)?.toInt() ?? 0,
      deliveredSales: (map['delivered_sales'] as num?)?.toDouble() ?? 0,
      commissionEarned: (map['commission_earned'] as num?)?.toDouble() ?? 0,
      totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0,
      outstandingBalance: (map['outstanding_balance'] as num?)?.toDouble() ?? 0,
      pendingSettlementsCount:
          (map['pending_settlements_count'] as num?)?.toInt() ?? 0,
      pendingSettlementsAmount:
          (map['pending_settlements_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CommissionLedgerEntry {
  const CommissionLedgerEntry({
    required this.id,
    required this.shopId,
    required this.entryType,
    required this.direction,
    required this.amount,
    required this.createdAt,
    this.orderId,
    this.settlementId,
    this.note,
  });

  final String id;
  final String shopId;
  final String? orderId;
  final String? settlementId;
  final String entryType;
  final String direction;
  final double amount;
  final String? note;
  final DateTime createdAt;

  bool get isDebit => direction == 'debit';

  String get typeLabel {
    switch (entryType) {
      case 'settlement_payment':
        return 'دفعة سداد';
      case 'admin_adjustment':
        return 'تعديل إداري';
      default:
        return 'عمولة طلب';
    }
  }

  factory CommissionLedgerEntry.fromMap(Map<String, dynamic> map) {
    return CommissionLedgerEntry(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      orderId: map['order_id']?.toString(),
      settlementId: map['settlement_id']?.toString(),
      entryType: map['entry_type']?.toString() ?? 'order_commission',
      direction: map['direction']?.toString() ?? 'debit',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      note: map['note']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class ShopSettlement {
  const ShopSettlement({
    required this.id,
    required this.shopId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.shopName,
    this.referenceNumber,
    this.receiptUrl,
    this.notes,
    this.adminNote,
    this.reviewedAt,
  });

  final String id;
  final String shopId;
  final String? shopName;
  final double amount;
  final String paymentMethod;
  final String? referenceNumber;
  final String? receiptUrl;
  final String? notes;
  final String status;
  final String? adminNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  String get methodLabel {
    switch (paymentMethod) {
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'jawwal_pay':
        return 'جوال باي';
      case 'palpay':
        return 'بال باي';
      default:
        return 'نقداً (كاش)';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'مؤكد';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'بانتظار التأكيد';
    }
  }

  factory ShopSettlement.fromMap(Map<String, dynamic> map) {
    return ShopSettlement(
      id: map['id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['payment_method']?.toString() ?? 'cash',
      referenceNumber: map['reference_number']?.toString(),
      receiptUrl: map['receipt_url']?.toString(),
      notes: map['notes']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      adminNote: map['admin_note']?.toString(),
      reviewedAt: DateTime.tryParse(
        map['reviewed_at']?.toString() ?? '',
      )?.toLocal(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class AdminRevenueOverview {
  const AdminRevenueOverview({
    this.totalDeliveredSales = 0,
    this.totalCommissionEarned = 0,
    this.totalCollected = 0,
    this.totalOutstanding = 0,
    this.pendingSettlementsCount = 0,
    this.pendingSettlementsAmount = 0,
    this.shopsOnHold = 0,
    this.shops = const [],
    this.pendingSettlements = const [],
  });

  final double totalDeliveredSales;
  final double totalCommissionEarned;
  final double totalCollected;
  final double totalOutstanding;
  final int pendingSettlementsCount;
  final double pendingSettlementsAmount;
  final int shopsOnHold;
  final List<ShopFinancialAccount> shops;
  final List<ShopSettlement> pendingSettlements;

  factory AdminRevenueOverview.fromMap(Map<String, dynamic> map) {
    final shopsRaw = map['shops'] is List ? map['shops'] as List : const [];
    final pendingRaw = map['pending_settlements'] is List
        ? map['pending_settlements'] as List
        : const [];
    return AdminRevenueOverview(
      totalDeliveredSales:
          (map['total_delivered_sales'] as num?)?.toDouble() ?? 0,
      totalCommissionEarned:
          (map['total_commission_earned'] as num?)?.toDouble() ?? 0,
      totalCollected: (map['total_collected'] as num?)?.toDouble() ?? 0,
      totalOutstanding: (map['total_outstanding'] as num?)?.toDouble() ?? 0,
      pendingSettlementsCount:
          (map['pending_settlements_count'] as num?)?.toInt() ?? 0,
      pendingSettlementsAmount:
          (map['pending_settlements_amount'] as num?)?.toDouble() ?? 0,
      shopsOnHold: (map['shops_on_hold'] as num?)?.toInt() ?? 0,
      shops: shopsRaw
          .map(
            (e) =>
                ShopFinancialAccount.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      pendingSettlements: pendingRaw
          .map(
            (e) => ShopSettlement.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

class ShopFinanceSummary {
  const ShopFinanceSummary({
    required this.account,
    this.ledger = const [],
    this.settlements = const [],
  });

  final ShopFinancialAccount account;
  final List<CommissionLedgerEntry> ledger;
  final List<ShopSettlement> settlements;

  factory ShopFinanceSummary.fromMap(Map<String, dynamic> map) {
    final accountMap = map['account'] is Map
        ? Map<String, dynamic>.from(map['account'] as Map)
        : const <String, dynamic>{};
    final ledgerRaw = map['ledger'] is List ? map['ledger'] as List : const [];
    final settlementsRaw = map['settlements'] is List
        ? map['settlements'] as List
        : const [];
    return ShopFinanceSummary(
      account: ShopFinancialAccount.fromMap(accountMap),
      ledger: ledgerRaw
          .map(
            (e) => CommissionLedgerEntry.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      settlements: settlementsRaw
          .map(
            (e) => ShopSettlement.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}
