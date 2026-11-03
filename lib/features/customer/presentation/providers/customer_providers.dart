import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// Banners Provider
final customerBannersProvider = FutureProvider.autoDispose<List<AdminBanner>>((ref) async {
  return ref.watch(customerRepositoryProvider).getBanners();
});

// Categories Provider
final customerCategoriesProvider = FutureProvider.autoDispose<List<CatalogCategory>>((ref) async {
  return ref.watch(customerRepositoryProvider).getCategories();
});

// Shops Provider
final customerShopsProvider = FutureProvider.autoDispose<List<CustomerShop>>((ref) async {
  return ref.watch(customerRepositoryProvider).getShops();
});

// Single Shop Details Provider
final customerShopDetailsProvider =
    FutureProvider.autoDispose.family<CustomerShop?, String>((ref, shopId) async {
  return ref.watch(customerRepositoryProvider).getShopDetails(shopId);
});

// Filter State Model for Catalog
class ProductFilter {
  const ProductFilter({
    this.categoryId,
    this.shopId,
    this.search,
    this.minPrice,
    this.maxPrice,
    this.color,
    this.size,
  });

  final String? categoryId;
  final String? shopId;
  final String? search;
  final double? minPrice;
  final double? maxPrice;
  final String? color;
  final String? size;

  ProductFilter copyWith({
    String? categoryId,
    String? shopId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? color,
    String? size,
    bool clearCategory = false,
    bool clearShop = false,
    bool clearColor = false,
    bool clearSize = false,
  }) {
    return ProductFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      shopId: clearShop ? null : (shopId ?? this.shopId),
      search: search ?? this.search,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      color: clearColor ? null : (color ?? this.color),
      size: clearSize ? null : (size ?? this.size),
    );
  }

  bool get hasActiveFilters =>
      (categoryId != null && categoryId!.isNotEmpty) ||
      (shopId != null && shopId!.isNotEmpty) ||
      (search != null && search!.isNotEmpty) ||
      minPrice != null ||
      maxPrice != null ||
      (color != null && color!.isNotEmpty) ||
      (size != null && size!.isNotEmpty);
}

// Current Filter State Provider
final productFilterProvider = StateProvider<ProductFilter>((ref) {
  return const ProductFilter();
});

// Filtered Products Provider
final customerProductsProvider = FutureProvider.autoDispose<List<CustomerProduct>>((ref) async {
  final filter = ref.watch(productFilterProvider);
  return ref.watch(customerRepositoryProvider).getProducts(
        categoryId: filter.categoryId,
        shopId: filter.shopId,
        search: filter.search,
        minPrice: filter.minPrice,
        maxPrice: filter.maxPrice,
        color: filter.color,
        size: filter.size,
      );
});

// Single Product Details Provider
final customerProductDetailsProvider =
    FutureProvider.autoDispose.family<CustomerProduct?, String>((ref, productId) async {
  return ref.watch(customerRepositoryProvider).getProductDetails(productId);
});

// Product Reviews Provider
final productReviewsProvider =
    FutureProvider.autoDispose.family<List<ProductReview>, String>((ref, productId) async {
  return ref.watch(customerRepositoryProvider).getProductReviews(productId);
});

// Favorites Provider
final customerFavoritesProvider =
    FutureProvider.autoDispose<List<CustomerProduct>>((ref) async {
  return ref.watch(customerRepositoryProvider).getFavorites();
});

// Cart State Notifier
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

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

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final newQty = (existing.quantity + quantity).clamp(1, maxStock);
      final updated = List<CartItem>.from(state);
      updated[existingIndex] = existing.copyWith(quantity: newQty);
      state = updated;
    } else {
      final newItem = CartItem(
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
      state = [...state, newItem];
    }
  }

  void updateQuantity(String cartItemId, int newQty) {
    if (newQty <= 0) {
      removeItem(cartItemId);
      return;
    }
    state = state.map((item) {
      if (item.id == cartItemId) {
        return item.copyWith(quantity: newQty.clamp(1, item.maxStock));
      }
      return item;
    }).toList();
  }

  void removeItem(String cartItemId) {
    state = state.where((item) => item.id != cartItemId).toList();
  }

  void clearCart() {
    state = [];
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
  return CartNotifier();
});

// Product Comparison State Notifier
class ProductComparisonNotifier extends StateNotifier<List<CustomerProduct>> {
  ProductComparisonNotifier() : super([]);

  bool addProduct(CustomerProduct product) {
    if (state.length >= 3) {
      return false; // Max 3 products to compare side-by-side
    }
    if (state.any((p) => p.id == product.id)) {
      return true;
    }
    state = [...state, product];
    return true;
  }

  void removeProduct(String productId) {
    state = state.where((p) => p.id != productId).toList();
  }

  void clear() {
    state = [];
  }
}

final productComparisonProvider =
    StateNotifierProvider<ProductComparisonNotifier, List<CustomerProduct>>((ref) {
  return ProductComparisonNotifier();
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
