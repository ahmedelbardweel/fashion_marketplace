import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/network/network_guard.dart';
import '../../../core/offline/background_preloader_service.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/network_monitor_service.dart';
import '../../../core/offline/offline_sync_engine.dart';
import '../domain/models/app_user.dart';
import '../domain/models/user_role.dart';

class PendingSignupData {
  const PendingSignupData({
    required this.email,
    required this.password,
    required this.role,
    required this.fullName,
    required this.phone,
    this.shopName,
  });

  final String email;
  final String password;
  final UserRole role;
  final String fullName;
  final String phone;
  final String? shopName;
}

class PendingLoginData {
  const PendingLoginData({required this.email, required this.password});

  final String email;
  final String password;
}

class RegistrationResult {
  const RegistrationResult({
    required this.email,
    required this.requiresEmailVerification,
    this.user,
  });

  final String email;
  final bool requiresEmailVerification;
  final AppUser? user;
}

class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  static const _trustedLoginEmailsKey = 'trusted_login_emails_v1';

  final SupabaseClient _client;
  final LocalDatabase _localDb = LocalDatabase.instance;

  /// Returns true if [email] has already completed email OTP verification on
  /// this app installation. Uninstalling and reinstalling the app clears
  /// SharedPreferences (with `android:allowBackup="false"`), requiring a
  /// one-time verification code on the first login after reinstall.
  Future<bool> isEmailTrustedOnThisInstall(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final trusted = prefs.getStringList(_trustedLoginEmailsKey) ?? const [];
    return trusted.contains(clean);
  }

  Future<void> markEmailTrustedOnThisInstall(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(
      prefs.getStringList(_trustedLoginEmailsKey) ?? const [],
    );
    if (!current.contains(clean)) {
      current.add(clean);
      await prefs.setStringList(_trustedLoginEmailsKey, current);
    }
  }

  Session? get currentSession => _client.auth.currentSession;
  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AppUser?> fetchCurrentProfile() async {
    final user = currentAuthUser;
    if (user == null) {
      // Offline session fallback if encrypted profile exists locally
      if (!NetworkMonitorService.instance.isOnline) {
        return _localDb.getActiveSessionProfile();
      }
      return null;
    }

    if (!NetworkMonitorService.instance.isOnline) {
      final cached =
          await _localDb.getUserProfile(user.id) ??
          await _localDb.getActiveSessionProfile();
      if (cached != null) return cached;
    }

    Map<String, dynamic>? data;
    try {
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
    } catch (_) {
      NetworkMonitorService.instance.reportNetworkFailure();
      final cached =
          await _localDb.getUserProfile(user.id) ??
          await _localDb.getActiveSessionProfile();
      if (cached != null) return cached;
      return null;
    }

    if (data == null) {
      return await _localDb.getUserProfile(user.id);
    }

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

    final profile = AppUser.fromMap(data);
    await _localDb.saveUserProfile(profile, isCurrentSession: true);
    unawaited(
      BackgroundPreloaderService.instance.preloadAllSilently(
        currentUser: profile,
      ),
    );
    unawaited(OfflineSyncEngine.instance.syncPendingActions());
    return profile;
  }

  /// يفتح نافذة اختيار حساب Google الأصلية (Bottom Sheet داخل التطبيق) على أندرويد وآيفون
  /// ويسجل الدخول مباشرة في Supabase عبر ID Token بدون الخروج إلى المتصفح.
  Future<AppUser?> signInWithGoogle() async {
    await NetworkGuard.ensureOnline();

    final webClientId = SupabaseConfig.googleWebClientId;
    final iosClientId = SupabaseConfig.googleIosClientId;

    if (!kIsWeb && webClientId.isEmpty) {
      throw const AuthException(
        'يرجى إضافة GOOGLE_WEB_CLIENT_ID في ملف .env لتفعيل الدخول المباشر عبر Google',
      );
    }

    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: webClientId.isEmpty ? null : webClientId,
      clientId: (!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.iOS &&
              iosClientId.isNotEmpty)
          ? iosClientId
          : null,
    );

    try {
      // ضمان ظهور نافذة اختيار الحساب السفلية (Bottom Sheet) دائماً
      await googleSignIn.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}

    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn().timeout(
        AppTimeouts.googleSignIn,
      );
    } on TimeoutException {
      throw AppNetworkException.timeout(timeout: AppTimeouts.googleSignIn);
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('canceled') || code.contains('cancelled')) {
        return null;
      }
      if (code.contains('network_error') || (e.message?.contains('7:') ?? false)) {
        throw AppNetworkException.noInternet();
      }
      if (code.contains('sign_in_failed') ||
          (e.message?.contains('10:') ?? false)) {
        throw const AuthException(
          'تأكد من إضافة بصمة SHA-1 و Web Client ID في إعدادات Google Cloud Console',
        );
      }
      throw AuthException(e.message ?? 'تعذر تسجيل الدخول عبر Google');
    }

    // إذا أغلق المستخدم النافذة السفلية بدون اختيار حساب
    if (googleUser == null) {
      return null;
    }

    final account = googleUser;
    final googleAuth = await NetworkGuard.run(
      () => account.authentication,
      timeout: AppTimeouts.auth,
      requireConnection: false,
    );
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException(
        'تعذر الحصول على رمز المصادقة (ID Token) من Google. تأكد من صحة GOOGLE_WEB_CLIENT_ID',
      );
    }

    final response = await NetworkGuard.run(
      () => _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      ),
      timeout: AppTimeouts.auth,
    );

    if (response.user == null) {
      throw const AuthException('تعذر تسجيل الدخول عبر Google');
    }

    final profile = await fetchCurrentProfile();
    if (profile == null) {
      await signOut();
      throw const AuthException('لم يتم العثور على ملف المستخدم');
    }
    if (!profile.isActive) {
      await signOut();
      throw const AuthException('هذا الحساب موقوف. تواصل مع الإدارة');
    }
    await markEmailTrustedOnThisInstall(profile.email);
    return profile;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await NetworkGuard.run(
      () => _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ),
      timeout: AppTimeouts.auth,
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

  Future<Map<String, dynamic>> _invokeSignupOtp(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await NetworkGuard.run(
        () => _client.functions.invoke('signup-otp', body: body),
        timeout: AppTimeouts.auth,
      );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      if (res.status >= 400 || data['error'] != null) {
        final msg = (data['error'] as String?)?.trim();
        throw AuthException(
          (msg != null && msg.isNotEmpty)
              ? msg
              : 'تعذر معالجة رمز التحقق. حاول مجدداً.',
        );
      }
      return data;
    } on FunctionException catch (e) {
      String? serverMsg;
      if (e.details is Map) {
        serverMsg = ((e.details as Map)['error'] as String?)?.trim();
      } else if (e.details is String && (e.details as String).trim().isNotEmpty) {
        serverMsg = (e.details as String).trim();
      }
      throw AuthException(
        (serverMsg != null && serverMsg.isNotEmpty)
            ? serverMsg
            : 'تعذر الاتصال بخدمة التحقق من البريد. حاول مجدداً.',
      );
    }
  }

  /// Sends a 6-digit OTP to [pending.email] WITHOUT creating any row in
  /// `auth.users`, `profiles`, or `shops`. Account creation only happens in
  /// [completeSignupWithOtp] after the code is verified.
  Future<RegistrationResult> requestSignupOtp({
    required PendingSignupData pending,
  }) async {
    final cleanEmail = pending.email.trim().toLowerCase();
    await _invokeSignupOtp({
      'action': 'send',
      'email': cleanEmail,
      'phone': pending.phone.trim(),
    });
    return RegistrationResult(
      email: cleanEmail,
      requiresEmailVerification: true,
    );
  }

  /// Verifies the 6-digit OTP on the server, creates the confirmed account in
  /// `auth.users` + `profiles` (+ draft `shops` for shop accounts), and signs
  /// the user into their live session.
  Future<AppUser> completeSignupWithOtp({
    required PendingSignupData pending,
    required String code,
  }) async {
    final cleanEmail = pending.email.trim().toLowerCase();
    await _invokeSignupOtp({
      'action': 'verify',
      'email': cleanEmail,
      'code': code.trim(),
      'password': pending.password,
      'role': pending.role.value,
      'full_name': pending.fullName.trim(),
      'phone': pending.phone.trim(),
      if (pending.role == UserRole.shop && pending.shopName != null)
        'shop_name': pending.shopName!.trim(),
    });

    // Account is now created and email-confirmed -> mark this install trusted
    // and sign in to start session.
    await markEmailTrustedOnThisInstall(cleanEmail);
    return signIn(email: cleanEmail, password: pending.password);
  }

  Future<void> resendSignupOtp({required String email}) async {
    await _invokeSignupOtp({
      'action': 'resend',
      'email': email.trim().toLowerCase(),
    });
  }

  /// Verifies login credentials server-side and sends a 6-digit login OTP for
  /// the first sign-in on a fresh install without opening a session yet.
  Future<void> requestLoginOtp({
    required String email,
    required String password,
  }) async {
    await _invokeSignupOtp({
      'action': 'login_send',
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  Future<void> resendLoginOtp({
    required String email,
    required String password,
  }) async {
    await _invokeSignupOtp({
      'action': 'login_resend',
      'email': email.trim().toLowerCase(),
      'password': password,
    });
  }

  /// Confirms the 6-digit login OTP, marks this install trusted for [pending.email],
  /// and signs the user in cleanly.
  Future<AppUser> completeLoginWithOtp({
    required PendingLoginData pending,
    required String code,
  }) async {
    final cleanEmail = pending.email.trim().toLowerCase();
    await _invokeSignupOtp({
      'action': 'login_verify',
      'email': cleanEmail,
      'code': code.trim(),
    });
    await markEmailTrustedOnThisInstall(cleanEmail);
    return signIn(email: cleanEmail, password: pending.password);
  }

  Future<void> signOut() async {
    await _localDb.clearActiveSession();
    try {
      await _client.auth.signOut().timeout(AppTimeouts.signOut);
    } catch (_) {}
  }

  String mapAuthError(Object error) => AppErrorMapper.message(error);
}
