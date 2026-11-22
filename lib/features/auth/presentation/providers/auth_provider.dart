import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/offline/local_database.dart';
import '../../../../core/offline/network_monitor_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

enum RegistrationOutcome {
  authenticated,
  needsEmailVerification,
  failed,
}

enum LoginOutcome {
  authenticated,
  needsEmailVerification,
  failed,
}

class AuthSessionState {
  const AuthSessionState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isBusy = false,
    this.isGoogleBusy = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;
  final bool isBusy;
  final bool isGoogleBusy;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  UserRole? get role => user?.role;

  AuthSessionState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
    bool? isBusy,
    bool? isGoogleBusy,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthSessionState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isBusy: isBusy ?? this.isBusy,
      isGoogleBusy: isGoogleBusy ?? this.isGoogleBusy,
    );
  }
}

class AuthController extends StateNotifier<AuthSessionState> {
  AuthController(this._repository)
      : super(const AuthSessionState(status: AuthStatus.unknown)) {
    _init();
  }

  final AuthRepository _repository;
  bool _listening = false;

  /// Prevents [authStateChanges] from firing a competing [restoreSession]
  /// while [signIn], [signInWithGoogle], [registerCustomer], or [registerShop]
  /// is actively running.
  bool _manualAuthInProgress = false;

  /// Serializes [restoreSession] calls so overlapping token refreshes never
  /// overwrite freshly completed profile state.
  Future<void>? _restoreInFlight;

  /// Held strictly in memory while the user verifies their email OTP so ZERO
  /// rows are written to `auth.users` / `profiles` / `shops` before verification.
  PendingSignupData? _pendingSignup;

  /// Held strictly in memory while the user verifies their first-install login OTP.
  PendingLoginData? _pendingLogin;

  Future<void> _init() async {
    _listenAuthChanges();
    await restoreSession();
  }

  void _listenAuthChanges() {
    if (_listening) return;
    _listening = true;
    _repository.authStateChanges.listen((data) async {
      final event = data.event;
      if (_manualAuthInProgress) {
        return;
      }
      if (event == AuthChangeEvent.signedOut) {
        if (!NetworkMonitorService.instance.isOnline) {
          // Preserve offline session if token refresh failed due to no internet
          final cachedUser = await LocalDatabase.instance
              .getActiveSessionProfile();
          if (cachedUser != null && cachedUser.isActive) {
            state = AuthSessionState(
              status: AuthStatus.authenticated,
              user: cachedUser,
            );
            return;
          }
        }
        state = const AuthSessionState(status: AuthStatus.unauthenticated);
        return;
      }
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        await restoreSession();
      }
    });
  }

  Future<void> restoreSession() {
    final existing = _restoreInFlight;
    if (existing != null) return existing;
    final task = _doRestoreSession().whenComplete(() {
      _restoreInFlight = null;
    });
    _restoreInFlight = task;
    return task;
  }

  Future<void> _doRestoreSession() async {
    try {
      final session = _repository.currentSession;
      if (session == null) {
        if (!NetworkMonitorService.instance.isOnline) {
          final offlineProfile = await LocalDatabase.instance
              .getActiveSessionProfile();
          if (offlineProfile != null && offlineProfile.isActive) {
            state = AuthSessionState(
              status: AuthStatus.authenticated,
              user: offlineProfile,
            );
            return;
          }
        }
        state = const AuthSessionState(status: AuthStatus.unauthenticated);
        return;
      }

      final profile = await _repository.fetchCurrentProfile();
      if (_manualAuthInProgress) return;

      if (profile == null) {
        final offlineProfile =
            await LocalDatabase.instance.getUserProfile(session.user.id) ??
            await LocalDatabase.instance.getActiveSessionProfile();
        if (offlineProfile != null && offlineProfile.isActive) {
          state = AuthSessionState(
            status: AuthStatus.authenticated,
            user: offlineProfile,
          );
          return;
        }
        if (NetworkMonitorService.instance.isOnline) {
          await _repository.signOut();
        }
        state = const AuthSessionState(status: AuthStatus.unauthenticated);
        return;
      }

      if (!profile.isActive) {
        await _repository.signOut();
        state = const AuthSessionState(status: AuthStatus.unauthenticated);
        return;
      }

      // Never allow a stale background restore to downgrade a user who has
      // just completed their profile in this session.
      final currentUser = state.user;
      final resolvedProfile =
          (currentUser != null &&
              currentUser.id == profile.id &&
              currentUser.profileCompleted &&
              !profile.profileCompleted)
          ? currentUser
          : profile;

      state = AuthSessionState(
        status: AuthStatus.authenticated,
        user: resolvedProfile,
      );
    } catch (_) {
      final offlineProfile = await LocalDatabase.instance
          .getActiveSessionProfile();
      if (offlineProfile != null && offlineProfile.isActive) {
        state = AuthSessionState(
          status: AuthStatus.authenticated,
          user: offlineProfile,
        );
        return;
      }
      state = const AuthSessionState(status: AuthStatus.unauthenticated);
    }
  }

  Future<LoginOutcome> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    _manualAuthInProgress = true;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final isTrusted = await _repository.isEmailTrustedOnThisInstall(
        cleanEmail,
      );
      if (!isTrusted) {
        await _repository.requestLoginOtp(
          email: cleanEmail,
          password: password,
        );
        _pendingLogin = PendingLoginData(email: cleanEmail, password: password);
        state = state.copyWith(isBusy: false, clearError: true);
        return LoginOutcome.needsEmailVerification;
      }

      final user = await _repository.signIn(
        email: cleanEmail,
        password: password,
      );
      state = AuthSessionState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return LoginOutcome.authenticated;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        status: AuthStatus.unauthenticated,
        clearUser: true,
        errorMessage: _repository.mapAuthError(error),
      );
      return LoginOutcome.failed;
    } finally {
      _manualAuthInProgress = false;
    }
  }

  Future<bool> verifyLoginOtp({
    required String email,
    required String code,
  }) async {
    final pending = _pendingLogin;
    final cleanEmail = email.trim().toLowerCase();
    if (pending == null || pending.email != cleanEmail) {
      state = state.copyWith(
        isBusy: false,
        errorMessage:
            'انتهت جلسة الدخول المؤقتة. يرجى الرجوع وإعادة إدخال بياناتك.',
      );
      return false;
    }

    _manualAuthInProgress = true;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _repository.completeLoginWithOtp(
        pending: pending,
        code: code,
      );
      _pendingLogin = null;
      state = AuthSessionState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _repository.mapAuthError(error),
      );
      return false;
    } finally {
      _manualAuthInProgress = false;
    }
  }

  Future<bool> resendLoginOtp({required String email}) async {
    final pending = _pendingLogin;
    final cleanEmail = email.trim().toLowerCase();
    if (pending == null || pending.email != cleanEmail) {
      state = state.copyWith(
        errorMessage:
            'انتهت جلسة الدخول المؤقتة. يرجى الرجوع وإعادة إدخال بياناتك.',
      );
      return false;
    }
    state = state.copyWith(clearError: true);
    try {
      await _repository.resendLoginOtp(
        email: cleanEmail,
        password: pending.password,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _repository.mapAuthError(error),
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _manualAuthInProgress = true;
    state = state.copyWith(isGoogleBusy: true, clearError: true);
    try {
      final user = await _repository.signInWithGoogle();
      if (user == null) {
        // User dismissed the native bottom sheet without error
        state = state.copyWith(isGoogleBusy: false, clearError: true);
        return true;
      }
      state = AuthSessionState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isGoogleBusy: false,
        errorMessage: _repository.mapAuthError(error),
      );
      return false;
    } finally {
      _manualAuthInProgress = false;
    }
  }

  Future<RegistrationOutcome> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _manualAuthInProgress = true;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final pending = PendingSignupData(
        email: email.trim().toLowerCase(),
        password: password,
        role: UserRole.customer,
        fullName: fullName.trim(),
        phone: phone.trim(),
      );
      await _repository.requestSignupOtp(pending: pending);
      _pendingSignup = pending;
      state = state.copyWith(isBusy: false, clearError: true);
      return RegistrationOutcome.needsEmailVerification;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _repository.mapAuthError(error),
      );
      return RegistrationOutcome.failed;
    } finally {
      _manualAuthInProgress = false;
    }
  }

  Future<RegistrationOutcome> registerShop({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String shopName,
  }) async {
    _manualAuthInProgress = true;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final pending = PendingSignupData(
        email: email.trim().toLowerCase(),
        password: password,
        role: UserRole.shop,
        fullName: fullName.trim(),
        phone: phone.trim(),
        shopName: shopName.trim(),
      );
      await _repository.requestSignupOtp(pending: pending);
      _pendingSignup = pending;
      state = state.copyWith(isBusy: false, clearError: true);
      return RegistrationOutcome.needsEmailVerification;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _repository.mapAuthError(error),
      );
      return RegistrationOutcome.failed;
    } finally {
      _manualAuthInProgress = false;
    }
  }

  Future<bool> verifySignupOtp({
    required String email,
    required String code,
  }) async {
    final pending = _pendingSignup;
    final cleanEmail = email.trim().toLowerCase();
    if (pending == null || pending.email != cleanEmail) {
      state = state.copyWith(
        isBusy: false,
        errorMessage:
            'انتهت جلسة التسجيل المؤقتة. يرجى الرجوع وإعادة إدخال بياناتك.',
      );
      return false;
    }

    _manualAuthInProgress = true;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _repository.completeSignupWithOtp(
        pending: pending,
        code: code,
      );
      _pendingSignup = null;
      state = AuthSessionState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: _repository.mapAuthError(error),
      );
      return false;
    } finally {
      _manualAuthInProgress = false;
    }
  }

  Future<bool> resendSignupOtp({required String email}) async {
    state = state.copyWith(clearError: true);
    try {
      await _repository.resendSignupOtp(email: email);
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _repository.mapAuthError(error),
      );
      return false;
    }
  }

  void clearPendingSignup() {
    _pendingSignup = null;
    _pendingLogin = null;
  }

  Future<void> signOut() async {
    _pendingSignup = null;
    _pendingLogin = null;
    _manualAuthInProgress = true;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _repository.signOut();
    } finally {
      _manualAuthInProgress = false;
      state = const AuthSessionState(status: AuthStatus.unauthenticated);
    }
  }

  void setUser(AppUser user) {
    LocalDatabase.instance.saveUserProfile(user, isCurrentSession: true);
    state = AuthSessionState(
      status: AuthStatus.authenticated,
      user: user,
    );
  }

  Future<void> refreshProfile() async {
    final profile = await _repository.fetchCurrentProfile();
    if (profile == null) return;
    setUser(profile);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSessionState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
