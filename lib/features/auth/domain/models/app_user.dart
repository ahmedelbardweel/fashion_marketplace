import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.isActive,
    required this.profileCompleted,
    this.fullName,
    this.phone,
    this.city,
    this.address,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? city;
  final String? address;
  final UserRole role;
  final bool isActive;
  final bool profileCompleted;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      city: map['city'] as String?,
      address: map['address'] as String?,
      role: UserRole.fromString(map['role'] as String?),
      isActive: map['is_active'] as bool? ?? true,
      profileCompleted: map['profile_completed'] as bool? ?? false,
    );
  }

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email;
  }

  AppUser copyWith({
    String? fullName,
    String? phone,
    String? city,
    String? address,
    bool? profileCompleted,
  }) {
    return AppUser(
      id: id,
      email: email,
      role: role,
      isActive: isActive,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}
