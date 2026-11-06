import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/utils/map_utils.dart';
import '../../admin/domain/models/catalog_models.dart';
import '../../auth/domain/models/app_user.dart';
import '../domain/models/cart_item.dart';
import '../domain/models/customer_order.dart';
import '../domain/models/customer_product.dart';
import '../domain/models/customer_shop.dart';

class CustomerRepository {
  CustomerRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // Complete customer profile
  Future<AppUser> completeProfile({
    required String fullName,
    required String phone,
    required String city,
    required String address,
  }) async {
    final data = await _client.rpc(
      'complete_customer_profile',
      params: {
        'p_full_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_city': city.trim(),
        'p_address': address.trim(),
      },
    );

    return AppUser.fromMap(asStringMap(data));
  }

  // Update profile
  Future<AppUser> updateProfile({
    required String fullName,
    required String phone,
    required String city,
    required String address,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    final updated = await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'city': city.trim(),
          'address': address.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();

    return AppUser.fromMap(asStringMap(updated));
  }

  // Fetch Banners
  Future<List<AdminBanner>> getBanners() async {
    try {
      final rows = await _client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (rows as List).map((row) => AdminBanner.fromMap(asStringMap(row))).toList();
    } catch (_) {
      return const [];
    }
  }

  // Fetch Categories
  Future<List<CatalogCategory>> getCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (rows as List).map((row) => CatalogCategory.fromMap(asStringMap(row))).toList();
    } catch (_) {
      return const [];
    }
  }

  // Fetch Approved Shops
  Future<List<CustomerShop>> getShops() async {
    try {
      final rows = await _client
          .from('shops')
          .select('*, products:products(count)')
          .eq('status', 'approved')
          .order('name', ascending: true);

      return (rows as List).map((row) {
        final map = asStringMap(row);
        final productsData = row['products'];
        int count = 0;
        if (productsData is List && productsData.isNotEmpty) {
          count = (productsData.first['count'] as num?)?.toInt() ?? 0;
        }
        return CustomerShop.fromMap(map, productsCount: count);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  // Fetch Single Shop Details
  Future<CustomerShop?> getShopDetails(String shopId) async {
    try {
      final row = await _client
          .from('shops')
          .select()
          .eq('id', shopId)
          .single();
      return CustomerShop.fromMap(asStringMap(row));
    } catch (_) {
      return null;
    }
  }

  // Fetch Products with Filters & Pagination
  Future<List<CustomerProduct>> getProducts({
    String? categoryId,
    String? shopId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? color,
    String? size,
    int? limit,
    int? offset,
    String? excludeProductId,
  }) async {
    try {
      var query = _client.from('products').select('''
        id, shop_id, category_id, name, description, details, price, status,
        shops:shop_id(name),
        categories:category_id(name),
        variants:product_variants(*),
        images:product_images(*)
      ''').eq('status', 'published');

      if (excludeProductId != null && excludeProductId.isNotEmpty) {
        query = query.neq('id', excludeProductId);
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }
      if (shopId != null && shopId.isNotEmpty) {
        query = query.eq('shop_id', shopId);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('name', '%${search.trim()}%');
      }
      if (minPrice != null) {
        query = query.gte('price', minPrice);
      }
      if (maxPrice != null) {
        query = query.lte('price', maxPrice);
      }

      var orderedQuery = query.order('created_at', ascending: false);

      if (limit != null) {
        final from = offset ?? 0;
        final to = from + limit - 1;
        orderedQuery = orderedQuery.range(from, to);
      }

      final rows = await orderedQuery;

      // Get user's favorites set
      final favoriteIds = await _getUserFavoriteIds();

      final products = (rows as List).map((row) {
        final map = asStringMap(row);
        final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
        final catMap = row['categories'] is Map ? asStringMap(row['categories']) : null;

        map['shop_name'] = shopMap?['name'] ?? 'متجر';
        map['category_name'] = catMap?['name'];

        final variantsList = (row['variants'] as List? ?? [])
            .map((v) => ProductVariant.fromMap(asStringMap(v)))
            .toList();

        final imagesList = (row['images'] as List? ?? [])
            .map((img) => ProductImage.fromMap(asStringMap(img)))
            .toList();

        final pid = map['id']?.toString() ?? '';
        return CustomerProduct.fromMap(
          map,
          variants: variantsList,
          images: imagesList,
          isFavorite: favoriteIds.contains(pid),
        );
      }).toList();

      // Client-side filtering for color and size if requested
      if (color != null && color.isNotEmpty) {
        return products
            .where((p) => p.variants.any((v) => v.color.toLowerCase() == color.toLowerCase()))
            .toList();
      }
      if (size != null && size.isNotEmpty) {
        return products
            .where((p) => p.variants.any((v) => v.size.toLowerCase() == size.toLowerCase()))
            .toList();
      }

      return products;
    } catch (_) {
      return const [];
    }
  }

  // Fetch Product Details
  Future<CustomerProduct?> getProductDetails(String productId) async {
    try {
      final row = await _client.from('products').select('''
        id, shop_id, category_id, name, description, details, price, status,
        shops:shop_id(name),
        categories:category_id(name),
        variants:product_variants(*),
        images:product_images(*)
      ''').eq('id', productId).single();

      final map = asStringMap(row);
      final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
      final catMap = row['categories'] is Map ? asStringMap(row['categories']) : null;

      map['shop_name'] = shopMap?['name'] ?? 'متجر';
      map['category_name'] = catMap?['name'];

      final variantsList = (row['variants'] as List? ?? [])
          .map((v) => ProductVariant.fromMap(asStringMap(v)))
          .toList();

      final imagesList = (row['images'] as List? ?? [])
          .map((img) => ProductImage.fromMap(asStringMap(img)))
          .toList();

      final favoriteIds = await _getUserFavoriteIds();

      // Fetch reviews stats
      final reviews = await getProductReviews(productId);
      double ratingAvg = 5.0;
      if (reviews.isNotEmpty) {
        final sum = reviews.fold(0, (s, r) => s + r.rating);
        ratingAvg = sum / reviews.length;
      }

      return CustomerProduct.fromMap(
        map,
        variants: variantsList,
        images: imagesList,
        isFavorite: favoriteIds.contains(productId),
        ratingAvg: ratingAvg,
        ratingCount: reviews.length,
      );
    } catch (_) {
      return null;
    }
  }

  // Favorites helpers
  Future<Set<String>> _getUserFavoriteIds() async {
    final userId = currentUserId;
    if (userId == null) return const {};
    try {
      final rows = await _client
          .from('favorites')
          .select('product_id')
          .eq('customer_id', userId);
      return (rows as List).map((r) => r['product_id'].toString()).toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<bool> toggleFavorite(String productId) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    try {
      final existing = await _client
          .from('favorites')
          .select('id')
          .eq('customer_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('favorites')
            .delete()
            .eq('customer_id', userId)
            .eq('product_id', productId);
        return false;
      } else {
        await _client.from('favorites').insert({
          'customer_id': userId,
          'product_id': productId,
        });
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  Future<List<CustomerProduct>> getFavorites() async {
    final userId = currentUserId;
    if (userId == null) return const [];
    try {
      final rows = await _client.from('favorites').select('''
        product:products(
          id, shop_id, category_id, name, description, details, price, status,
          shops:shop_id(name),
          categories:category_id(name),
          variants:product_variants(*),
          images:product_images(*)
        )
      ''').eq('customer_id', userId);

      final list = <CustomerProduct>[];
      for (final row in rows as List) {
        final pData = row['product'];
        if (pData == null || pData is! Map) continue;
        final map = asStringMap(pData);
        final shopMap = pData['shops'] is Map ? asStringMap(pData['shops']) : null;
        final catMap = pData['categories'] is Map ? asStringMap(pData['categories']) : null;

        map['shop_name'] = shopMap?['name'] ?? 'متجر';
        map['category_name'] = catMap?['name'];

        final variants = (pData['variants'] as List? ?? [])
            .map((v) => ProductVariant.fromMap(asStringMap(v)))
            .toList();

        final images = (pData['images'] as List? ?? [])
            .map((img) => ProductImage.fromMap(asStringMap(img)))
            .toList();

        list.add(CustomerProduct.fromMap(
          map,
          variants: variants,
          images: images,
          isFavorite: true,
        ));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  // Reviews
  Future<List<ProductReview>> getProductReviews(String productId) async {
    try {
      final rows = await _client.from('product_reviews').select('''
        id, product_id, customer_id, rating, comment, created_at,
        profiles:customer_id(full_name)
      ''').eq('product_id', productId).order('created_at', ascending: false);

      return (rows as List).map((row) {
        final map = asStringMap(row);
        final profile = row['profiles'] is Map ? asStringMap(row['profiles']) : null;
        map['customer_name'] = profile?['full_name'] ?? 'عميل';
        return ProductReview.fromMap(map);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addReview({
    required String productId,
    required int rating,
    String? comment,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    await _client.from('product_reviews').upsert(
      {
        'customer_id': userId,
        'product_id': productId,
        'rating': rating,
        'comment': comment?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'customer_id,product_id',
    );
  }

  // Orders
  Future<CustomerOrder> placeOrder({
    required String shopId,
    required List<CartItem> items,
    required String deliveryAddress,
    required String phone,
  }) async {
    final payload = items.map((i) => i.toOrderPayload()).toList();

    final result = await _client.rpc(
      'customer_place_order',
      params: {
        'p_shop_id': shopId,
        'p_items': payload,
        'p_delivery_address': deliveryAddress.trim(),
        'p_phone': phone.trim(),
      },
    );

    return CustomerOrder.fromMap(asStringMap(result));
  }

  Future<List<CustomerOrder>> getCustomerOrders() async {
    final userId = currentUserId;
    if (userId == null) return const [];
    try {
      final rows = await _client.from('orders').select('''
        id, customer_id, shop_id, status, total, created_at,
        shops:shop_id(name),
        items:order_items(*)
      ''').eq('customer_id', userId).order('created_at', ascending: false);

      return (rows as List).map((row) {
        final map = asStringMap(row);
        final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
        map['shop_name'] = shopMap?['name'] ?? 'متجر';

        final itemsList = (row['items'] as List? ?? [])
            .map((item) => CustomerOrderItem.fromMap(asStringMap(item)))
            .toList();

        return CustomerOrder.fromMap(map, items: itemsList);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<CustomerOrder?> getOrderDetails(String orderId) async {
    try {
      final row = await _client.from('orders').select('''
        id, customer_id, shop_id, status, total, created_at,
        shops:shop_id(name),
        items:order_items(*)
      ''').eq('id', orderId).single();

      final map = asStringMap(row);
      final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
      map['shop_name'] = shopMap?['name'] ?? 'متجر';

      final itemsList = (row['items'] as List? ?? [])
          .map((item) => CustomerOrderItem.fromMap(asStringMap(item)))
          .toList();

      return CustomerOrder.fromMap(map, items: itemsList);
    } catch (_) {
      return null;
    }
  }

  // Notifications
  Future<List<AdminNotification>> getCustomerNotifications() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .inFilter('audience', ['all', 'customers'])
          .order('created_at', ascending: false);
      return (rows as List).map((r) => AdminNotification.fromMap(asStringMap(r))).toList();
    } catch (_) {
      return const [];
    }
  }

  String mapError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return 'حدث خطأ. حاول مرة أخرى';
  }
}
