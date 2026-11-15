import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/notifications/read_notifications_provider.dart';
export '../../../../core/notifications/read_notifications_provider.dart';
import '../../../../core/pagination/paginated_state.dart';
export '../../../../core/pagination/paginated_state.dart';

import '../../../admin/domain/models/catalog_models.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/shop_catalog_repository.dart';
import '../../data/shop_storage_repository.dart';
import '../../domain/models/shop_product.dart';
import 'shop_providers.dart';

final shopCatalogRepositoryProvider = Provider<ShopCatalogRepository>((ref) {
  return ShopCatalogRepository();
});

final shopStorageRepositoryProvider = Provider<ShopStorageRepository>((ref) {
  return ShopStorageRepository();
});

bool _isShop(Ref ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.isAuthenticated && auth.user?.role == UserRole.shop;
}

final shopStatsProvider = FutureProvider.autoDispose<ShopStats>((ref) async {
  if (!_isShop(ref)) {
    return const ShopStats(
      products: 0,
      publishedProducts: 0,
      orders: 0,
      pendingOrders: 0,
      salesTotal: 0,
      stockUnits: 0,
    );
  }
  return ref.watch(shopCatalogRepositoryProvider).fetchStats();
});

final shopCategoriesProvider =
    FutureProvider.autoDispose<List<CatalogCategory>>((ref) async {
      if (!_isShop(ref)) return const [];
      return ref.watch(shopCatalogRepositoryProvider).fetchActiveCategories();
    });

final shopProductFilterProvider = StateProvider<ShopProductFilterState>((ref) {
  return ShopProductFilterState.empty;
});

/// Paginated shop product controller fetching [kProductPageSize] (6) items per
/// request with server-pushed filters and debounced search.
class PaginatedShopProductsNotifier extends PaginatedListNotifier<ShopProduct> {
  PaginatedShopProductsNotifier({
    required ShopCatalogRepository repository,
    required bool isShop,
    ShopProductFilterState initialFilter = ShopProductFilterState.empty,
  }) : _repository = repository,
       _isShop = isShop,
       _filter = initialFilter,
       super(
         fetcher: (offset, limit) => _fetchFilteredPage(
           repository: repository,
           isShop: isShop,
           offset: offset,
           limit: limit,
           filter: initialFilter,
         ),
         itemId: (item) => item.id,
       );

  final ShopCatalogRepository _repository;
  final bool _isShop;
  ShopProductFilterState _filter;
  Timer? _searchDebounce;

  static Future<PaginatedPage<ShopProduct>> _fetchFilteredPage({
    required ShopCatalogRepository repository,
    required bool isShop,
    required int offset,
    required int limit,
    required ShopProductFilterState filter,
  }) async {
    if (!isShop) {
      return const PaginatedPage<ShopProduct>(items: [], rawCount: 0);
    }
    final page = await repository.fetchMyProductsPage(
      limit: limit,
      offset: offset,
      status: filter.status,
      categoryId: filter.categoryId,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      search: filter.search,
      sort: filter.sort,
    );
    final refined = filterShopProducts(page.items, filter);
    return PaginatedPage<ShopProduct>(
      items: refined,
      rawCount: page.rawCount ?? page.items.length,
      totalCount: page.totalCount,
    );
  }

  void updateFilter(ShopProductFilterState next, {bool force = false}) {
    if (!force && next == _filter) return;
    final searchChanged = next.search != _filter.search;
    _filter = next;
    _searchDebounce?.cancel();

    if (searchChanged && next.search.trim().isNotEmpty) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _resetForCurrentFilter();
      });
    } else {
      _resetForCurrentFilter();
    }
  }

  void _resetForCurrentFilter() {
    final activeFilter = _filter;
    resetWithFetcher(
      (offset, limit) => _fetchFilteredPage(
        repository: _repository,
        isShop: _isShop,
        offset: offset,
        limit: limit,
        filter: activeFilter,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final shopProductsPaginatedProvider = StateNotifierProvider.autoDispose<
  PaginatedShopProductsNotifier,
  PaginatedListState<ShopProduct>
>((ref) {
  final isShop = _isShop(ref);
  final repository = ref.watch(shopCatalogRepositoryProvider);
  final initialFilter = ref.read(shopProductFilterProvider);
  final notifier = PaginatedShopProductsNotifier(
    repository: repository,
    isShop: isShop,
    initialFilter: initialFilter,
  );
  ref.listen<ShopProductFilterState>(
    shopProductFilterProvider,
    (previous, next) => notifier.updateFilter(next),
  );
  return notifier;
});

final shopProductProvider = FutureProvider.autoDispose
    .family<ShopProduct?, String>((ref, id) async {
      if (!_isShop(ref)) return null;
      return ref.watch(shopCatalogRepositoryProvider).fetchProduct(id);
    });

final shopOrdersProvider = FutureProvider.autoDispose<List<ShopOrder>>((
  ref,
) async {
  if (!_isShop(ref)) return const [];
  return ref.watch(shopCatalogRepositoryProvider).fetchOrders();
});

final shopNotificationsProvider =
    FutureProvider.autoDispose<List<AdminNotification>>((ref) async {
      if (!_isShop(ref)) return const [];
      return ref.watch(shopCatalogRepositoryProvider).fetchNotifications();
    });

final shopUnreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final readIds = ref.watch(readNotificationIdsProvider);
  final notifications = ref.watch(shopNotificationsProvider).valueOrNull;
  return countUnreadNotifications(notifications, readIds);
});

final shopImagesProvider = FutureProvider.autoDispose<List<ShopMediaItem>>((
  ref,
) async {
  if (!_isShop(ref)) return const [];
  return ref.watch(shopCatalogRepositoryProvider).fetchShopImages();
});

final shopDocumentsProvider = FutureProvider.autoDispose<List<ShopMediaItem>>((
  ref,
) async {
  if (!_isShop(ref)) return const [];
  return ref.watch(shopCatalogRepositoryProvider).fetchDocuments();
});

final shopCatalogActionProvider =
    StateNotifierProvider<ShopCatalogActionController, AsyncValue<void>>(
      (ref) => ShopCatalogActionController(ref),
    );

class ShopCatalogActionController extends StateNotifier<AsyncValue<void>> {
  ShopCatalogActionController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  ShopCatalogRepository get _repo => _ref.read(shopCatalogRepositoryProvider);

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

  Future<ShopProduct?> saveProductForm(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final product = await _repo.saveProductForm(data);
      if (_ref.exists(shopProductsPaginatedProvider)) {
        _ref.read(shopProductsPaginatedProvider.notifier).refresh();
      }
      _ref.invalidate(shopStatsProvider);
      _ref.invalidate(shopCategoriesProvider);
      _ref.invalidate(shopProductProvider(product.id));
      state = const AsyncValue.data(null);
      return product;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return null;
    }
  }

  Future<bool> setProductStatus({
    required String productId,
    required String status,
  }) {
    return _run(() async {
      await _repo.setProductStatus(productId: productId, status: status);
      if (_ref.exists(shopProductsPaginatedProvider)) {
        _ref.read(shopProductsPaginatedProvider.notifier).refresh();
      }
      _ref.invalidate(shopStatsProvider);
      _ref.invalidate(shopProductProvider(productId));
    });
  }

  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
  }) {
    return _run(() async {
      await _repo.updateOrderStatus(orderId: orderId, status: status);
      _ref.invalidate(shopOrdersProvider);
      _ref.invalidate(shopStatsProvider);
    });
  }

  Future<bool> updateProfile({
    required String shopName,
    required String description,
    required String city,
    required String address,
    required String commercialRegister,
    required String ownerName,
    required String phone,
  }) {
    return _run(() async {
      await _repo.updateProfile(
        shopName: shopName,
        description: description,
        city: city,
        address: address,
        commercialRegister: commercialRegister,
        ownerName: ownerName,
        phone: phone,
      );
      _ref.invalidate(myShopProvider);
      await _ref.read(authControllerProvider.notifier).refreshProfile();
    });
  }

  Future<bool> setLogo(String url) {
    return _run(() async {
      await _repo.setMedia(logoPath: url);
      _ref.invalidate(myShopProvider);
    });
  }

  Future<bool> setCover(String url) {
    return _run(() async {
      await _repo.setMedia(coverPath: url);
      _ref.invalidate(myShopProvider);
    });
  }

  Future<bool> addShopImage(String url) {
    return _run(() async {
      await _repo.addShopImage(filePath: url);
      _ref.invalidate(shopImagesProvider);
    });
  }

  Future<bool> addDocument({required String docType, required String path}) {
    return _run(() async {
      await _repo.addDocument(docType: docType, filePath: path);
      _ref.invalidate(shopDocumentsProvider);
    });
  }
}
