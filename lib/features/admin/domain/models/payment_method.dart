import '../../../../core/theme/app_design.dart';

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.accountNumber,
    this.nameEn,
    this.type = 'bank',
    this.iban,
    this.accountHolder = '',
    this.instructions,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? nameEn;
  final String type; // 'bank' | 'wallet'
  final String accountNumber;
  final String? iban;
  final String accountHolder;
  final String? instructions;
  final bool isActive;
  final int sortOrder;

  bool get isWallet => type == 'wallet';
  bool get isBank => !isWallet;

  String get displayName =>
      (AppLang.isEn && (nameEn?.trim().isNotEmpty ?? false))
      ? nameEn!.trim()
      : name;

  String get typeLabel => isWallet ? 'محفظة إلكترونية'.tr : 'حساب بنكي'.tr;

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      nameEn: map['name_en']?.toString(),
      type: map['type']?.toString() == 'wallet' ? 'wallet' : 'bank',
      accountNumber: map['account_number']?.toString() ?? '',
      iban: map['iban']?.toString(),
      accountHolder: map['account_holder']?.toString() ?? '',
      instructions: map['instructions']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'name_en': nameEn,
    'type': type,
    'account_number': accountNumber,
    'iban': iban,
    'account_holder': accountHolder,
    'instructions': instructions,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}
