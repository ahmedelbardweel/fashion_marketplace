enum ShopStatus {
  draft,
  pending,
  approved,
  rejected,
  suspended;

  static ShopStatus fromString(String? value) {
    switch (value) {
      case 'draft':
        return ShopStatus.draft;
      case 'pending':
        return ShopStatus.pending;
      case 'approved':
        return ShopStatus.approved;
      case 'rejected':
        return ShopStatus.rejected;
      case 'suspended':
        return ShopStatus.suspended;
      default:
        return ShopStatus.draft;
    }
  }

  String get value {
    switch (this) {
      case ShopStatus.draft:
        return 'draft';
      case ShopStatus.pending:
        return 'pending';
      case ShopStatus.approved:
        return 'approved';
      case ShopStatus.rejected:
        return 'rejected';
      case ShopStatus.suspended:
        return 'suspended';
    }
  }

  String get labelAr {
    switch (this) {
      case ShopStatus.draft:
        return 'مسودة';
      case ShopStatus.pending:
        return 'قيد المراجعة';
      case ShopStatus.approved:
        return 'مقبول';
      case ShopStatus.rejected:
        return 'مرفوض';
      case ShopStatus.suspended:
        return 'موقوف';
    }
  }
}

class Shop {
  const Shop({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.status,
    required this.visibleStatus,
    this.description,
    this.city,
    this.address,
    this.commercialRegister,
    this.logoPath,
    this.coverPath,
    this.rejectionReason,
    this.visibleRejectionReason,
    this.decisionAt,
    this.decisionVisibleAt,
    this.submittedAt,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? city;
  final String? address;
  final String? commercialRegister;
  final String? logoPath;
  final String? coverPath;
  final ShopStatus status;
  final ShopStatus visibleStatus;
  final String? rejectionReason;
  final String? visibleRejectionReason;
  final DateTime? decisionAt;
  final DateTime? decisionVisibleAt;
  final DateTime? submittedAt;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;

  bool get isApprovedVisible => visibleStatus == ShopStatus.approved;

  bool get isProfileReady {
    return name.trim().isNotEmpty &&
        (description?.trim().isNotEmpty ?? false) &&
        (city?.trim().isNotEmpty ?? false) &&
        (address?.trim().isNotEmpty ?? false) &&
        (commercialRegister?.trim().isNotEmpty ?? false);
  }

  bool get canSubmit =>
      isProfileReady &&
      (status == ShopStatus.draft || status == ShopStatus.rejected);

  bool get canEdit =>
      status == ShopStatus.draft ||
      status == ShopStatus.approved ||
      (status == ShopStatus.rejected &&
          visibleStatus == ShopStatus.rejected);

  factory Shop.fromMap(Map<String, dynamic> map, {bool forOwner = false}) {
    final status = ShopStatus.fromString(map['status'] as String?);
    final decisionVisibleAt = map['decision_visible_at'] == null
        ? null
        : DateTime.tryParse(map['decision_visible_at'] as String)?.toLocal();

    var visibleStatus = status;
    if (forOwner &&
        (status == ShopStatus.approved || status == ShopStatus.rejected) &&
        decisionVisibleAt != null &&
        decisionVisibleAt.isAfter(DateTime.now())) {
      visibleStatus = ShopStatus.pending;
    }

    final owner = map['profiles'] ?? map['owner'];
    Map<String, dynamic>? ownerMap;
    if (owner is Map) {
      ownerMap = Map<String, dynamic>.from(owner);
    }

    return Shop(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      city: map['city'] as String?,
      address: map['address'] as String?,
      commercialRegister: map['commercial_register'] as String?,
      logoPath: map['logo_path'] as String?,
      coverPath: map['cover_path'] as String?,
      status: status,
      visibleStatus: visibleStatus,
      rejectionReason: map['rejection_reason'] as String?,
      visibleRejectionReason: visibleStatus == ShopStatus.rejected
          ? map['rejection_reason'] as String?
          : null,
      decisionAt: map['decision_at'] == null
          ? null
          : DateTime.tryParse(map['decision_at'] as String)?.toLocal(),
      decisionVisibleAt: decisionVisibleAt,
      submittedAt: map['submitted_at'] == null
          ? null
          : DateTime.tryParse(map['submitted_at'] as String)?.toLocal(),
      ownerName: ownerMap?['full_name'] as String?,
      ownerEmail: ownerMap?['email'] as String?,
      ownerPhone: ownerMap?['phone'] as String?,
    );
  }
}
