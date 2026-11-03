import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shop/domain/models/shop.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../../../shop/domain/models/shop_product.dart';
import '../../data/admin_repository.dart';
import '../../domain/models/admin_stats.dart';
import '../../domain/models/catalog_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

bool _isAdmin(Ref ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.isAuthenticated && auth.user?.role == UserRole.admin;
}

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  if (!_isAdmin(ref)) {
    return const AdminStats(
      customers: 0,
      shops: 0,
      pendingShops: 0,
      approvedShops: 0,
      suspendedShops: 0,
      products: 0,
      hiddenProducts: 0,
      orders: 0,
      categories: 0,
      banners: 0,
      notifications: 0,
    );
  }
  return ref.watch(adminRepositoryProvider).fetchStats();
});

final adminUsersProvider =
    FutureProvider.autoDispose<List<AppUser>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final adminManagedShopsProvider =
    FutureProvider.autoDispose<List<Shop>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchManagedShops();
});

final adminCategoriesProvider =
    FutureProvider.autoDispose<List<CatalogCategory>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchCategories();
});

final adminProductsProvider =
    FutureProvider.autoDispose<List<AdminProduct>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchProducts();
});

final adminOrdersProvider =
    FutureProvider.autoDispose<List<AdminOrder>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchOrders();
});

final adminBannersProvider =
    FutureProvider.autoDispose<List<AdminBanner>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchBanners();
});

final adminNotificationsProvider =
    FutureProvider.autoDispose<List<AdminNotification>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchNotifications();
});

final adminSettingsProvider =
    FutureProvider.autoDispose<List<PlatformSetting>>((ref) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchSettings();
});

final adminShopDocumentsProvider =
    FutureProvider.autoDispose.family<List<ShopDocument>, String>(
  (ref, shopId) async {
    if (!_isAdmin(ref)) return const [];
    return ref.watch(adminRepositoryProvider).fetchShopDocuments(shopId);
  },
);

final adminShopImagesProvider =
    FutureProvider.autoDispose.family<List<ShopMediaItem>, String>(
  (ref, shopId) async {
    if (!_isAdmin(ref)) return const [];
    return ref.watch(adminRepositoryProvider).fetchShopImages(shopId);
  },
);

final adminActionProvider =
    StateNotifierProvider<AdminActionController, AsyncValue<void>>(
  (ref) => AdminActionController(ref),
);

class AdminActionController extends StateNotifier<AsyncValue<void>> {
  AdminActionController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  AdminRepository get _repo => _ref.read(adminRepositoryProvider);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  String errorMessage(Object error) => _repo.mapError(error);

  Future<bool> setUserActive({
    required String userId,
    required bool isActive,
  }) {
    return _run(() async {
      await _repo.setUserActive(userId: userId, isActive: isActive);
      _ref.invalidate(adminUsersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> setShopSuspended({
    required String shopId,
    required bool suspend,
  }) {
    return _run(() async {
      await _repo.setShopSuspended(shopId: shopId, suspend: suspend);
      _ref.invalidate(adminManagedShopsProvider);
      _ref.invalidate(adminShopApplicationsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> upsertCategory({
    required String name,
    String? description,
    bool isActive = true,
    String? id,
  }) {
    return _run(() async {
      await _repo.upsertCategory(
        name: name,
        description: description,
        isActive: isActive,
        id: id,
      );
      _ref.invalidate(adminCategoriesProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> setProductStatus({
    required String productId,
    required String status,
  }) {
    return _run(() async {
      await _repo.setProductStatus(productId: productId, status: status);
      _ref.invalidate(adminProductsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> upsertBanner({
    required String title,
    String? subtitle,
    bool isActive = true,
    String? id,
  }) {
    return _run(() async {
      await _repo.upsertBanner(
        title: title,
        subtitle: subtitle,
        isActive: isActive,
        id: id,
      );
      _ref.invalidate(adminBannersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> deleteBanner(String id) {
    return _run(() async {
      await _repo.deleteBanner(id);
      _ref.invalidate(adminBannersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> sendNotification({
    required String title,
    required String body,
    required String audience,
  }) {
    return _run(() async {
      await _repo.sendNotification(
        title: title,
        body: body,
        audience: audience,
      );
      _ref.invalidate(adminNotificationsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> updateSetting({
    required String key,
    required String value,
  }) {
    return _run(() async {
      await _repo.updateSetting(key: key, value: value);
      _ref.invalidate(adminSettingsProvider);
    });
  }
}
