enum UserRole {
  admin,
  shop,
  customer;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'shop':
        return UserRole.shop;
      case 'customer':
        return UserRole.customer;
      default:
        return UserRole.customer;
    }
  }

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.shop:
        return 'shop';
      case UserRole.customer:
        return 'customer';
    }
  }

  String get labelAr {
    switch (this) {
      case UserRole.admin:
        return 'الإدارة';
      case UserRole.shop:
        return 'المحل';
      case UserRole.customer:
        return 'المستخدم';
    }
  }
}
