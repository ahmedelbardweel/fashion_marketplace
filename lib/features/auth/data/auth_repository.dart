import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../domain/models/app_user.dart';
import '../domain/models/user_role.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const String oauthRedirectUrl = 'io.supabase.shopy://login-callback/';

  Session? get currentSession => _client.auth.currentSession;
  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AppUser?> fetchCurrentProfile() async {
    final user = currentAuthUser;
    if (user == null) return null;

    Map<String, dynamic>? data;
    for (var attempt = 0; attempt < 5; attempt++) {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        data = Map<String, dynamic>.from(res);
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (data == null) return null;

    final currentFullName = (data['full_name'] as String?)?.trim();
    if (currentFullName == null || currentFullName.isEmpty) {
      final meta = user.userMetadata;
      final googleName =
          (meta?['full_name'] as String?)?.trim() ??
          (meta?['name'] as String?)?.trim();
      if (googleName != null && googleName.isNotEmpty) {
        data['full_name'] = googleName;
      }
    }

    return AppUser.fromMap(data);
  }

  Future<bool> signInWithGoogle() async {
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw AuthException('تعذر فتح صفحة تسجيل الدخول عبر Google');
    }
    return true;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user == null) {
      throw AuthException('تعذر تسجيل الدخول');
    }

    final profile = await fetchCurrentProfile();
    if (profile == null) {
      await signOut();
      throw AuthException('لم يتم العثور على ملف المستخدم');
    }
    if (!profile.isActive) {
      await signOut();
      throw AuthException('هذا الحساب موقوف. تواصل مع الإدارة');
    }
    return profile;
  }

  Future<AppUser> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'role': UserRole.customer.value,
        'full_name': fullName.trim(),
        'phone': phone.trim(),
      },
    );

    if (response.user == null) {
      throw AuthException('تعذر إنشاء الحساب');
    }

    // If email confirmation is enabled, session may be null.
    if (response.session == null) {
      throw AuthException(
        'تم إنشاء الحساب. تحقق من بريدك لتفعيل الحساب ثم سجّل الدخول',
      );
    }

    final profile = await _waitForProfile(response.user!.id);
    return profile;
  }

  Future<AppUser> registerShop({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String shopName,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'role': UserRole.shop.value,
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'shop_name': shopName.trim(),
      },
    );

    if (response.user == null) {
      throw AuthException('تعذر إنشاء حساب المحل');
    }

    if (response.session == null) {
      throw AuthException(
        'تم إنشاء الحساب. تحقق من بريدك لتفعيل الحساب ثم سجّل الدخول',
      );
    }

    final profile = await _waitForProfile(response.user!.id);
    return profile;
  }

  Future<AppUser> _waitForProfile(String userId) async {
    // Trigger may take a brief moment after signup.
    for (var attempt = 0; attempt < 8; attempt++) {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        return AppUser.fromMap(Map<String, dynamic>.from(data));
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw AuthException('تم التسجيل لكن تعذر تحميل الملف الشخصي');
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  String mapAuthError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'البريد أو كلمة المرور غير صحيحة';
      }
      if (message.contains('email not confirmed')) {
        return 'يجب تأكيد البريد الإلكتروني أولاً';
      }
      if (message.contains('user already registered')) {
        return 'هذا البريد مسجل مسبقاً';
      }
      if (message.contains('password')) {
        return 'كلمة المرور غير مقبولة';
      }
      return error.message;
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى';
  }
}
