import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/shop_repository.dart';
import '../../domain/models/shop.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository();
});

final myShopProvider = FutureProvider<Shop?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || auth.user?.role != UserRole.shop) {
    return null;
  }
  return ref.read(shopRepositoryProvider).fetchMyShop();
});

final adminShopApplicationsProvider =
    FutureProvider.autoDispose<List<Shop>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || auth.user?.role.name != 'admin') {
    return const [];
  }
  return ref.watch(shopRepositoryProvider).fetchAllApplications();
});

final adminShopByIdProvider =
    FutureProvider.autoDispose.family<Shop?, String>((ref, shopId) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || auth.user?.role.name != 'admin') {
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
      await _ref.read(authControllerProvider.notifier).refreshProfile();
      _ref.invalidate(myShopProvider);
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
      await _ref.read(authControllerProvider.notifier).refreshProfile();
      _ref.invalidate(myShopProvider);
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
