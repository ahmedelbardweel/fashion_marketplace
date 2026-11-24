import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
export '../../../../core/filtering/filter_models.dart';
import '../../../../core/notifications/read_notifications_provider.dart';
export '../../../../core/notifications/read_notifications_provider.dart';
import '../../../../core/pagination/paginated_state.dart';
export '../../../../core/pagination/paginated_state.dart';
import '../../../../core/search/smart_search_sheets.dart';
import '../../../../core/search/visual_search_service.dart';

import '../../../admin/domain/models/catalog_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/customer_repository.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/customer_order.dart';
import '../../domain/models/customer_product.dart';
import '../../domain/models/customer_shop.dart';

// Repository Provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

// Profile Completion Controller
final completeCustomerProfileProvider =
    StateNotifierProvider<CompleteCustomerProfileController, AsyncValue<void>>(
  (ref) => CompleteCustomerProfileController(ref),
);

class CompleteCustomerProfileController extends StateNotifier<AsyncValue<void>> {
  CompleteCustomerProfileController(this._ref)
      : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> submit({
    required String fullName,
    required String phone,
    required String city,
    required String address,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _ref.read(customerRepositoryProvider).completeProfile(
            fullName: fullName,
            phone: phone,
            city: city,
            address: address,
          );
      _ref.read(authControllerProvider.notifier).setUser(user);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  String errorMessage(Object error) {
    return _ref.read(customerRepositoryProvider).mapError(error);
  }
}

extension _AutoDisposeCacheFor on Ref<dynamic> {
  /// Keeps an autoDispose provider alive in memory for [duration] after the
  /// last listener unmounts so switching tabs never triggers redundant fetches.
  void cacheFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;
    onCancel(() {
      timer?.cancel();
      timer = Timer(duration, link.close);
    });
    onResume(() {
      timer?.cancel();
    });
    onDispose(() {
      timer?.cancel();
    });
  }
}

// Single-request Home Bootstrap Provider (coalesced in AppMemoryCache)
final homeBootstrapProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.cacheFor(const Duration(minutes: 3));
  return ref.watch(customerRepositoryProvider).warmHomeBootstrap();
});

// Banners Provider (kept warm across tab switches)
final customerBannersProvider = FutureProvider.autoDispose<List<AdminBanner>>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(customerRepositoryProvider);
  await repo.warmHomeBootstrap();
  return repo.getBanners();
});

// Categories Provider (kept warm across tab switches)
final customerCategoriesProvider = FutureProvider.autoDispose<List<CatalogCategory>>((ref) async {
  ref.cacheFor(const Duration(minutes: 10));
  final repo = ref.watch(customerRepositoryProvider);
  await repo.warmHomeBootstrap();
  return repo.getCategories();
});

// Shops Provider (kept warm across tab switches)
final customerShopsProvider = FutureProvider.autoDispose<List<CustomerShop>>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(customerRepositoryProvider);
  await repo.warmHomeBootstrap();
  return repo.getShops();
});

// Single Shop Details Provider (kept warm across navigation)
final customerShopDetailsProvider =
    FutureProvider.autoDispose.family<CustomerShop?, String>((ref, shopId) async {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(customerRepositoryProvider).getShopDetails(shopId);
});

// Current Filter State Provider (Catalog)
final productFilterProvider = StateProvider<ProductFilter>((ref) {
  return const ProductFilter();
});

// Quick Filter State Provider for Home Feed (kept independent from Catalog)
final homeProductFilterProvider = StateProvider<ProductFilter>((ref) {
  return const ProductFilter();
});

// Shop Public Profile Filter State Provider
final shopPublicProductFilterProvider =
    StateProvider.autoDispose.family<ProductFilter, String>((ref, shopId) {
      return const ProductFilter();
    });

/// Paginated product controller fetching [kProductPageSize] items per
/// request with Stale-While-Revalidate cache hydration, generation-safe
/// filter resets, and 350ms search debouncing.
class PaginatedCustomerProductsNotifier
    extends PaginatedListNotifier<CustomerProduct> {
  PaginatedCustomerProductsNotifier({
    required CustomerRepository repository,
    ProductFilter initialFilter = const ProductFilter(),
    this.shopId,
    this.useHomeBootstrap = false,
  }) : _repository = repository,
       _filter = initialFilter,
       super(
         fetcher: (offset, limit) => _fetchFilterPage(
           repository: repository,
           shopId: shopId,
           filter: initialFilter,
           offset: offset,
           limit: limit,
           useHomeBootstrap: useHomeBootstrap,
         ),
         initialCacheLoader: (limit) => _loadCachedFirstPage(
           repository: repository,
           shopId: shopId,
           filter: initialFilter,
           limit: limit,
         ),
         itemId: (item) => item.id,
       ) {
    ActiveVisualSearchStore.instance.currentQuery.addListener(
      _onVisualSearchChanged,
    );
  }

  final bool useHomeBootstrap;

  final CustomerRepository _repository;
  final String? shopId;
  ProductFilter _filter;
  VisualSearchQuery? _lastVisualQuery =
      ActiveVisualSearchStore.instance.currentQuery.value;
  Timer? _searchDebounce;

  void _onVisualSearchChanged() {
    scheduleMicrotask(() {
      if (!mounted) return;
      final current = ActiveVisualSearchStore.instance.currentQuery.value;
      if (!identical(current, _lastVisualQuery)) {
        _lastVisualQuery = current;
        _searchDebounce?.cancel();
        _resetForCurrentFilter();
      }
    });
  }

  static Future<PaginatedPage<CustomerProduct>?> _loadCachedFirstPage({
    required CustomerRepository repository,
    required String? shopId,
    required ProductFilter filter,
    required int limit,
  }) {
    return repository.getCachedProductsPage(
      categoryId: filter.categoryId,
      shopId: shopId ?? filter.shopId,
      search: filter.search,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      color: filter.color,
      size: filter.size,
      inStockOnly: filter.inStockOnly,
      minRating: filter.minRating,
      sort: filter.sort,
      limit: limit,
      offset: 0,
    );
  }

  static Future<PaginatedPage<CustomerProduct>> _fetchFilterPage({
    required CustomerRepository repository,
    required String? shopId,
    required ProductFilter filter,
    required int offset,
    required int limit,
    bool useHomeBootstrap = false,
    bool forceRefresh = false,
  }) async {
    if (useHomeBootstrap &&
        offset == 0 &&
        shopId == null &&
        !filter.hasActiveFilters &&
        filter.sort == ProductSortOption.newest) {
      await repository.warmHomeBootstrap(
        productsLimit: limit,
        forceRefresh: forceRefresh,
      );
    }
    return repository.getProductsPage(
      categoryId: filter.categoryId,
      shopId: shopId ?? filter.shopId,
      search: filter.search,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      color: filter.color,
      size: filter.size,
      inStockOnly: filter.inStockOnly,
      minRating: filter.minRating,
      sort: filter.sort,
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
  }

  ProductFilter get filter => _filter;

  void updateFilter(ProductFilter next, {bool force = false}) {
    final activeVisual = ActiveVisualSearchStore.instance.currentQuery.value;
    final visualChanged = !identical(activeVisual, _lastVisualQuery);
    if (!force && !visualChanged && next == _filter) return;
    final searchChanged = next.search != _filter.search;
    _filter = next;
    _lastVisualQuery = activeVisual;
    _searchDebounce?.cancel();

    if (!visualChanged &&
        searchChanged &&
        (next.search?.trim().isNotEmpty ?? false)) {
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
      (offset, limit) => _fetchFilterPage(
        repository: _repository,
        shopId: shopId,
        filter: activeFilter,
        offset: offset,
        limit: limit,
        useHomeBootstrap: useHomeBootstrap,
      ),
      nextCacheLoader: (limit) => _loadCachedFirstPage(
        repository: _repository,
        shopId: shopId,
        filter: activeFilter,
        limit: limit,
      ),
    );
  }

  @override
  Future<void> refresh() {
    final activeFilter = _filter;
    _repository.invalidateCatalogCache();
    return resetWithFetcher(
      (offset, limit) => _fetchFilterPage(
        repository: _repository,
        shopId: shopId,
        filter: activeFilter,
        offset: offset,
        limit: limit,
        useHomeBootstrap: useHomeBootstrap,
        forceRefresh: offset == 0,
      ),
      nextCacheLoader: null,
      preserveItemsWhileLoading: true,
    );
  }

  void setProductFavorite(String productId, bool isFavorite) {
    updateWhere(
      (item) => item.id == productId,
      (item) => item.copyWith(isFavorite: isFavorite),
    );
  }

  @override
  void dispose() {
    ActiveVisualSearchStore.instance.currentQuery.removeListener(
      _onVisualSearchChanged,
    );
    _searchDebounce?.cancel();
    super.dispose();
  }
}

/// Paginated favorites controller fetching [kProductPageSize] (6) items per request.
class PaginatedCustomerFavoritesNotifier
    extends PaginatedListNotifier<CustomerProduct> {
  PaginatedCustomerFavoritesNotifier({required CustomerRepository repository})
    : super(
        fetcher: (offset, limit) =>
            repository.getFavoritesPage(limit: limit, offset: offset),
        itemId: (item) => item.id,
      );

  void applyFavoriteChange(CustomerProduct product, bool isFavorite) {
    if (isFavorite) {
      updateWhere(
        (item) => item.id == product.id,
        (item) => item.copyWith(isFavorite: true),
      );
      if (!state.items.any((item) => item.id == product.id)) {
        refresh();
      }
    } else {
      removeWhere((item) => item.id == product.id);
    }
  }
}

// Paginated Products Provider (Catalog — kept warm across tab switches)
final catalogProductsProvider = StateNotifierProvider.autoDispose<
  PaginatedCustomerProductsNotifier,
  PaginatedListState<CustomerProduct>
>((ref) {
  ref.cacheFor(const Duration(minutes: 5));
  final repository = ref.watch(customerRepositoryProvider);
  final initialFilter = ref.read(productFilterProvider);
  final notifier = PaginatedCustomerProductsNotifier(
    repository: repository,
    initialFilter: initialFilter,
  );
  ref.listen<ProductFilter>(
    productFilterProvider,
    (previous, next) => notifier.updateFilter(next),
  );
  return notifier;
});

// Paginated Products Provider (Home Quick Feed — kept warm & bootstrapped in 1 RPC)
final homeProductsProvider = StateNotifierProvider.autoDispose<
  PaginatedCustomerProductsNotifier,
  PaginatedListState<CustomerProduct>
>((ref) {
  ref.cacheFor(const Duration(minutes: 5));
  final repository = ref.watch(customerRepositoryProvider);
  final initialFilter = ref.read(homeProductFilterProvider);
  final notifier = PaginatedCustomerProductsNotifier(
    repository: repository,
    initialFilter: initialFilter,
    useHomeBootstrap: true,
  );
  ref.listen<ProductFilter>(
    homeProductFilterProvider,
    (previous, next) => notifier.updateFilter(next),
  );
  return notifier;
});

// Paginated Products Provider (Shop Public Profile — kept warm briefly)
final shopPublicProductsProvider = StateNotifierProvider.autoDispose.family<
  PaginatedCustomerProductsNotifier,
  PaginatedListState<CustomerProduct>,
  String
>((ref, shopId) {
  ref.cacheFor(const Duration(minutes: 3));
  final repository = ref.watch(customerRepositoryProvider);
  final initialFilter = ref.read(shopPublicProductFilterProvider(shopId));
  final notifier = PaginatedCustomerProductsNotifier(
    repository: repository,
    initialFilter: initialFilter,
    shopId: shopId,
  );
  ref.listen<ProductFilter>(
    shopPublicProductFilterProvider(shopId),
    (previous, next) => notifier.updateFilter(next),
  );
  return notifier;
});

// Single Product Details Provider (kept warm for instant revisits)
final customerProductDetailsProvider =
    FutureProvider.autoDispose.family<CustomerProduct?, String>((ref, productId) async {
  ref.cacheFor(const Duration(minutes: 2));
  return ref.watch(customerRepositoryProvider).getProductDetails(productId);
});

// Product Reviews Provider (coalesced with getProductDetails & kept warm)
final productReviewsProvider =
    FutureProvider.autoDispose.family<List<ProductReview>, String>((ref, productId) async {
  ref.cacheFor(const Duration(minutes: 2));
  return ref.watch(customerRepositoryProvider).getProductReviews(productId);
});

// Paginated Favorites Provider
final customerFavoritesPaginatedProvider = StateNotifierProvider.autoDispose<
  PaginatedCustomerFavoritesNotifier,
  PaginatedListState<CustomerProduct>
>((ref) {
  ref.cacheFor(const Duration(minutes: 3));
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  final repository = ref.watch(customerRepositoryProvider);
  return PaginatedCustomerFavoritesNotifier(repository: repository);
});

/// Updates loaded paginated product lists in place without losing scroll
/// position or fetched pages when the user toggles a favorite heart.
void syncFavoriteAcrossProductLists(
  WidgetRef ref,
  CustomerProduct product,
  bool isFavorite,
) {
  if (ref.exists(catalogProductsProvider)) {
    ref
        .read(catalogProductsProvider.notifier)
        .setProductFavorite(product.id, isFavorite);
  }
  if (ref.exists(homeProductsProvider)) {
    ref
        .read(homeProductsProvider.notifier)
        .setProductFavorite(product.id, isFavorite);
  }
  if (product.shopId != null &&
      ref.exists(shopPublicProductsProvider(product.shopId!))) {
    ref
        .read(shopPublicProductsProvider(product.shopId!).notifier)
        .setProductFavorite(product.id, isFavorite);
  }
  if (ref.exists(customerFavoritesPaginatedProvider)) {
    ref
        .read(customerFavoritesPaginatedProvider.notifier)
        .applyFavoriteChange(product, isFavorite);
  }
}

// Cart State Notifier (Backed by Supabase public.cart_items)
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier(this._ref) : super([]) {
    final initialUserId = _ref.read(authControllerProvider).user?.id;
    if (initialUserId != null) {
      Future.microtask(loadFromRemote);
    }
    _ref.listen<String?>(
      authControllerProvider.select((s) => s.user?.id),
      (previous, next) {
        if (next == null) {
          // Clear local memory only on sign-out so Supabase keeps the user's cart
          state = [];
        } else if (next != previous) {
          loadFromRemote();
        }
      },
    );
  }

  final Ref _ref;

  CustomerRepository get _repo => _ref.read(customerRepositoryProvider);

  Future<void> loadFromRemote() async {
    final remoteItems = await _repo.getCartItems();
    if (!mounted) return;
    state = remoteItems;
  }

  void addItem({
    required CustomerProduct product,
    String? variantId,
    required String color,
    required String size,
    int quantity = 1,
    int maxStock = 999,
  }) {
    final cartItemId = '${product.id}_${color}_$size';
    final existingIndex = state.indexWhere((item) => item.id == cartItemId);
    late final CartItem targetItem;

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final newQty = (existing.quantity + quantity).clamp(1, maxStock);
      targetItem = existing.copyWith(quantity: newQty);
      final updated = List<CartItem>.from(state);
      updated[existingIndex] = targetItem;
      state = updated;
    } else {
      targetItem = CartItem(
        id: cartItemId,
        productId: product.id,
        productName: product.name,
        shopId: product.shopId,
        shopName: product.shopName,
        variantId: variantId,
        color: color,
        size: size,
        unitPrice: product.price,
        quantity: quantity.clamp(1, maxStock),
        imagePath: product.coverImage,
        maxStock: maxStock,
      );
      state = [...state, targetItem];
    }

    _repo.upsertCartItem(
      productId: targetItem.productId,
      variantId: targetItem.variantId,
      color: targetItem.color,
      size: targetItem.size,
      quantity: targetItem.quantity,
    );
  }

  void updateQuantity(String cartItemId, int newQty) {
    if (newQty <= 0) {
      removeItem(cartItemId);
      return;
    }
    CartItem? updatedItem;
    state = state.map((item) {
      if (item.id == cartItemId) {
        updatedItem = item.copyWith(quantity: newQty.clamp(1, item.maxStock));
        return updatedItem!;
      }
      return item;
    }).toList();

    if (updatedItem != null) {
      _repo.upsertCartItem(
        productId: updatedItem!.productId,
        variantId: updatedItem!.variantId,
        color: updatedItem!.color,
        size: updatedItem!.size,
        quantity: updatedItem!.quantity,
      );
    }
  }

  void removeItem(String cartItemId) {
    CartItem? removed;
    for (final item in state) {
      if (item.id == cartItemId) {
        removed = item;
        break;
      }
    }
    state = state.where((item) => item.id != cartItemId).toList();
    if (removed != null) {
      _repo.removeCartItem(
        productId: removed.productId,
        color: removed.color,
        size: removed.size,
      );
    }
  }

  void clearCart() {
    state = [];
    _repo.clearCartItems();
  }

  double get totalAmount => state.fold(0.0, (sum, item) => sum + item.totalPrice);

  int get totalItemCount => state.fold(0, (sum, item) => sum + item.quantity);

  Map<String, List<CartItem>> get itemsByShop {
    final map = <String, List<CartItem>>{};
    for (final item in state) {
      map.putIfAbsent(item.shopId, () => []).add(item);
    }
    return map;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier(ref);
});

// Product Comparison State Notifier (Backed by Supabase public.comparison_items)
class ProductComparisonNotifier extends StateNotifier<List<CustomerProduct>> {
  ProductComparisonNotifier(this._ref) : super([]) {
    final initialUserId = _ref.read(authControllerProvider).user?.id;
    if (initialUserId != null) {
      Future.microtask(loadFromRemote);
    }
    _ref.listen<String?>(
      authControllerProvider.select((s) => s.user?.id),
      (previous, next) {
        if (next == null) {
          state = [];
        } else if (next != previous) {
          loadFromRemote();
        }
      },
    );
  }

  final Ref _ref;

  CustomerRepository get _repo => _ref.read(customerRepositoryProvider);

  Future<void> loadFromRemote() async {
    final remoteProducts = await _repo.getComparisonProducts();
    if (!mounted) return;
    state = remoteProducts.take(3).toList();
  }

  bool addProduct(CustomerProduct product) {
    if (state.length >= 3) {
      return false; // Max 3 products to compare side-by-side
    }
    if (state.any((p) => p.id == product.id)) {
      return true;
    }
    state = [...state, product];
    _repo.addComparisonProduct(product.id);
    return true;
  }

  void removeProduct(String productId) {
    state = state.where((p) => p.id != productId).toList();
    _repo.removeComparisonProduct(productId);
  }

  void clear() {
    state = [];
    _repo.clearComparisonProducts();
  }
}

final productComparisonProvider =
    StateNotifierProvider<ProductComparisonNotifier, List<CustomerProduct>>((ref) {
  return ProductComparisonNotifier(ref);
});

// Customer Orders Provider
final customerOrdersProvider = FutureProvider.autoDispose<List<CustomerOrder>>((ref) async {
  return ref.watch(customerRepositoryProvider).getCustomerOrders();
});

// Single Order Details Provider
final customerOrderDetailsProvider =
    FutureProvider.autoDispose.family<CustomerOrder?, String>((ref, orderId) async {
  return ref.watch(customerRepositoryProvider).getOrderDetails(orderId);
});

// Notifications Provider
final customerNotificationsProvider =
    FutureProvider.autoDispose<List<AdminNotification>>((ref) async {
  return ref.watch(customerRepositoryProvider).getCustomerNotifications();
});

// Unread Customer Notifications Count
final customerUnreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final readIds = ref.watch(readNotificationIdsProvider);
  final notifications = ref.watch(customerNotificationsProvider).valueOrNull;
  return countUnreadNotifications(notifications, readIds);
});
