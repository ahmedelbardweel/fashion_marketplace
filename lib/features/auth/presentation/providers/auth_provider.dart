import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _init() async {
    _listenAuthChanges();
    await restoreSession();
  }

  void _listenAuthChanges() {
    if (_listening) return;
    _listening = true;
    _repository.authStateChanges.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
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

  Future<void> restoreSession() async {
    try {
      final session = _repository.currentSession;
      if (session == null) {
        state = const AuthSessionState(status: AuthStatus.unauthenticated);
        return;
      }

      final profile = await _repository.fetchCurrentProfile();
      if (profile == null || !profile.isActive) {
        await _repository.signOut();
        state = const AuthSessionState(status: AuthStatus.unauthenticated);
        return;
      }

      state = AuthSessionState(
        status: AuthStatus.authenticated,
        user: profile,
      );
    } catch (_) {
      state = const AuthSessionState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _repository.signIn(
        email: email,
        password: password,
      );
      state = AuthSessionState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        status: AuthStatus.unauthenticated,
        clearUser: true,
        errorMessage: _repository.mapAuthError(error),
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isGoogleBusy: true, clearError: true);
    try {
      await _repository.signInWithGoogle();
      // Keep isGoogleBusy false once external browser opens; authStateChanges
      // will update state to authenticated when callback returns.
      state = state.copyWith(isGoogleBusy: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isGoogleBusy: false,
        errorMessage: _repository.mapAuthError(error),
      );
      return false;
    }
  }

  Future<bool> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _repository.registerCustomer(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
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
    }
  }

  Future<bool> registerShop({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String shopName,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _repository.registerShop(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        shopName: shopName,
      );
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
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _repository.signOut();
    } finally {
      state = const AuthSessionState(status: AuthStatus.unauthenticated);
    }
  }

  void setUser(AppUser user) {
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
