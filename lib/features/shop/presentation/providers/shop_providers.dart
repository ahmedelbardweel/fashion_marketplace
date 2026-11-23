import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/domain/models/subscription_models.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/shop_repository.dart';
import '../../domain/models/shop.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository();
});

/// Watches ONLY identity & role so unrelated auth state changes (like busy flags
/// or profile name updates) never tear down and refetch the shop mid-submission.
final myShopProvider = FutureProvider<Shop?>((ref) async {
  final authKey = ref.watch(
    authControllerProvider.select(
      (s) => (s.isAuthenticated, s.user?.id, s.user?.role),
    ),
  );
  if (!authKey.$1 || authKey.$3 != UserRole.shop) {
    return null;
  }
  return ref.read(shopRepositoryProvider).fetchMyShop();
});

final activeSubscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
  return ref.read(shopRepositoryProvider).fetchActiveSubscriptionPlans();
});

final myShopFinancialStatementProvider =
    FutureProvider.autoDispose<ShopFinancialStatement?>((ref) async {
  final authKey = ref.watch(
    authControllerProvider.select(
      (s) => (s.isAuthenticated, s.user?.id, s.user?.role),
    ),
  );
  if (!authKey.$1 || authKey.$3 != UserRole.shop) {
    return null;
  }
  return ref.read(shopRepositoryProvider).fetchMyFinancialStatement();
});

final adminShopApplicationsProvider =
    FutureProvider.autoDispose<List<Shop>>((ref) async {
  final authKey = ref.watch(
    authControllerProvider.select((s) => (s.isAuthenticated, s.user?.role)),
  );
  if (!authKey.$1 || authKey.$2 != UserRole.admin) {
    return const [];
  }
  return ref.watch(shopRepositoryProvider).fetchAllApplications();
});

final adminShopByIdProvider =
    FutureProvider.autoDispose.family<Shop?, String>((ref, shopId) async {
  final authKey = ref.watch(
    authControllerProvider.select((s) => (s.isAuthenticated, s.user?.role)),
  );
  if (!authKey.$1 || authKey.$2 != UserRole.admin) {
    return null;
  }
  return ref.watch(shopRepositoryProvider).fetchShopById(shopId);
});

final shopActionProvider =
    StateNotifierProvider<ShopActionController, AsyncValue<void>>(
  (ref) => ShopActionController(ref),
);

class ShopActionController extends StateNotifier<AsyncValue<void>> {
  ShopActionController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> completeProfile({
    required String shopName,
    required String description,
    required String city,
    required String address,
    required String commercialRegister,
    required String ownerName,
    required String phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(shopRepositoryProvider).completeShopProfile(
            shopName: shopName,
            description: description,
            city: city,
            address: address,
            commercialRegister: commercialRegister,
            ownerName: ownerName,
            phone: phone,
          );
      final currentUser = _ref.read(authControllerProvider).user;
      if (currentUser != null) {
        _ref.read(authControllerProvider.notifier).setUser(
              currentUser.copyWith(
                fullName: ownerName.trim(),
                phone: phone.trim(),
                city: city.trim(),
                address: address.trim(),
              ),
            );
      }
      try {
        await _ref.refresh(myShopProvider.future);
      } catch (_) {
        _ref.invalidate(myShopProvider);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  Future<bool> submitApplication() async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(shopRepositoryProvider).submitApplication();
      final currentUser = _ref.read(authControllerProvider).user;
      if (currentUser != null && !currentUser.profileCompleted) {
        _ref.read(authControllerProvider.notifier).setUser(
              currentUser.copyWith(profileCompleted: true),
            );
      }
      try {
        await _ref.refresh(myShopProvider.future);
      } catch (_) {
        _ref.invalidate(myShopProvider);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  /// Atomic single-loading-cycle save + submit to prevent double refreshes and
  /// routing stalls on [ShopCompleteProfileScreen].
  Future<bool> saveAndSubmitProfile({
    required String shopName,
    required String description,
    required String city,
    required String address,
    required String commercialRegister,
    required String ownerName,
    required String phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(shopRepositoryProvider);
      await repo.completeShopProfile(
        shopName: shopName,
        description: description,
        city: city,
        address: address,
        commercialRegister: commercialRegister,
        ownerName: ownerName,
        phone: phone,
      );
      await repo.submitApplication();
      final currentUser = _ref.read(authControllerProvider).user;
      if (currentUser != null) {
        _ref.read(authControllerProvider.notifier).setUser(
              currentUser.copyWith(
                fullName: ownerName.trim(),
                phone: phone.trim(),
                city: city.trim(),
                address: address.trim(),
                profileCompleted: true,
              ),
            );
      }
      try {
        await _ref.refresh(myShopProvider.future);
      } catch (_) {
        _ref.invalidate(myShopProvider);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  Future<bool> saveAndSubmitProfileWithSubscription({
    required String shopName,
    required String description,
    required String city,
    required String address,
    required String commercialRegister,
    required String ownerName,
    required String phone,
    required String planId,
    required String paymentMethodId,
    required String receiptUrl,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(shopRepositoryProvider);
      await repo.completeShopProfile(
        shopName: shopName,
        description: description,
        city: city,
        address: address,
        commercialRegister: commercialRegister,
        ownerName: ownerName,
        phone: phone,
      );
      await repo.submitApplicationWithSubscription(
        planId: planId,
        paymentMethodId: paymentMethodId,
        receiptUrl: receiptUrl,
        notes: notes,
      );
      final currentUser = _ref.read(authControllerProvider).user;
      if (currentUser != null) {
        _ref.read(authControllerProvider.notifier).setUser(
              currentUser.copyWith(
                fullName: ownerName.trim(),
                phone: phone.trim(),
                city: city.trim(),
                address: address.trim(),
                profileCompleted: true,
              ),
            );
      }
      try {
        await _ref.refresh(myShopProvider.future);
      } catch (_) {
        _ref.invalidate(myShopProvider);
      }
      _ref.invalidate(myShopFinancialStatementProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  Future<bool> submitSubscriptionRenewal({
    required String planId,
    required String paymentMethodId,
    required String receiptUrl,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(shopRepositoryProvider).submitSubscriptionRenewal(
            planId: planId,
            paymentMethodId: paymentMethodId,
            receiptUrl: receiptUrl,
            notes: notes,
          );
      _ref.invalidate(myShopProvider);
      _ref.invalidate(myShopFinancialStatementProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  Future<bool> review({
    required String shopId,
    required bool approve,
    String? rejectionReason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(shopRepositoryProvider).reviewApplication(
            shopId: shopId,
            approve: approve,
            rejectionReason: rejectionReason,
          );
      _ref.invalidate(adminShopApplicationsProvider);
      _ref.invalidate(adminShopByIdProvider(shopId));
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  String errorMessage(Object error) {
    return _ref.read(shopRepositoryProvider).mapError(error);
  }
}
