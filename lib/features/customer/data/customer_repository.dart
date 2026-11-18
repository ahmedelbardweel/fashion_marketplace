import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/filtering/filter_models.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/network_monitor_service.dart';
import '../../../core/offline/offline_sync_engine.dart';
import '../../../core/pagination/paginated_state.dart';
import '../../../core/search/smart_search_sheets.dart';
import '../../../core/search/visual_search_service.dart';
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
  final LocalDatabase _localDb = LocalDatabase.instance;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<String?> _resolveUserId() async {
    final uid = currentUserId;
    if (uid != null && uid.isNotEmpty) return uid;
    final activeProfile = await _localDb.getActiveSessionProfile();
    return activeProfile?.id;
  }

  // Complete customer profile
  Future<AppUser> completeProfile({
    required String fullName,
    required String phone,
    required String city,
    required String address,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedPhone = phone.trim();
    final trimmedCity = city.trim();
    final trimmedAddress = address.trim();

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc(
          'complete_customer_profile',
          params: {
            'p_full_name': trimmedName,
            'p_phone': trimmedPhone,
            'p_city': trimmedCity,
            'p_address': trimmedAddress,
          },
        );
        final updatedUser = AppUser.fromMap(asStringMap(data));
        await _localDb.saveUserProfile(updatedUser, isCurrentSession: true);
        return updatedUser;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    final existing =
        await _localDb.getUserProfile(userId) ??
        await _localDb.getActiveSessionProfile();
    if (existing == null) throw StateError('يجب تسجيل الدخول');

    final offlineUpdated = existing.copyWith(
      fullName: trimmedName,
      phone: trimmedPhone,
      city: trimmedCity,
      address: trimmedAddress,
      profileCompleted: true,
    );
    await _localDb.saveUserProfile(offlineUpdated, isCurrentSession: true);

    await OfflineSyncEngine.instance.enqueue(
      id: 'complete_profile_$userId',
      userId: userId,
      actionType: 'complete_customer_profile',
      entityId: userId,
      payload: {
        'full_name': trimmedName,
        'phone': trimmedPhone,
        'city': trimmedCity,
        'address': trimmedAddress,
      },
    );

    return offlineUpdated;
  }

  // Update profile
  Future<AppUser> updateProfile({
    required String fullName,
    required String phone,
    required String city,
    required String address,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    final trimmedName = fullName.trim();
    final trimmedPhone = phone.trim();
    final trimmedCity = city.trim();
    final trimmedAddress = address.trim();

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final updated = await _client
            .from('profiles')
            .update({
              'full_name': trimmedName,
              'phone': trimmedPhone,
              'city': trimmedCity,
              'address': trimmedAddress,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId)
            .select()
            .single();

        final user = AppUser.fromMap(asStringMap(updated));
        await _localDb.saveUserProfile(user, isCurrentSession: true);
        return user;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final existing =
        await _localDb.getUserProfile(userId) ??
        await _localDb.getActiveSessionProfile();
    if (existing == null) throw StateError('يجب تسجيل الدخول');

    final offlineUpdated = existing.copyWith(
      fullName: trimmedName,
      phone: trimmedPhone,
      city: trimmedCity,
      address: trimmedAddress,
    );
    await _localDb.saveUserProfile(offlineUpdated, isCurrentSession: true);

    await OfflineSyncEngine.instance.enqueue(
      id: 'update_profile_$userId',
      userId: userId,
      actionType: 'update_customer_profile',
      entityId: userId,
      payload: {
        'full_name': trimmedName,
        'phone': trimmedPhone,
        'city': trimmedCity,
        'address': trimmedAddress,
      },
    );

    return offlineUpdated;
  }

  // Delete / deactivate customer account
  Future<void> deleteAccount() async {
    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    await _client
        .from('profiles')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
    await _localDb.clearActiveSession();
  }

  // Fetch Banners
  Future<List<AdminBanner>> getBanners() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('banners')
            .select()
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        final banners = (rows as List)
            .map((row) => AdminBanner.fromMap(asStringMap(row)))
            .toList();
        unawaited(_localDb.saveBanners(banners));
        return banners;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getBanners(activeOnly: true);
  }

  // Fetch Categories
  Future<List<CatalogCategory>> getCategories({
    bool throwOnError = false,
  }) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('categories')
            .select()
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        final categories = (rows as List)
            .map((row) => CatalogCategory.fromMap(asStringMap(row)))
            .toList();
        unawaited(_localDb.saveCategories(categories));
        return categories;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else if (throwOnError) {
          rethrow;
        }
      }
    }

    final localCategories = await _localDb.getCategories(activeOnly: true);
    return localCategories;
  }

  // Fetch Approved Shops
  Future<List<CustomerShop>> getShops() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('shops')
            .select('*, products:products(count)')
            .eq('status', 'approved')
            .order('name', ascending: true);

        final shops = (rows as List).map((row) {
          final map = asStringMap(row);
          final productsData = row['products'];
          int count = 0;
          if (productsData is List && productsData.isNotEmpty) {
            count = (productsData.first['count'] as num?)?.toInt() ?? 0;
          }
          return CustomerShop.fromMap(map, productsCount: count);
        }).toList();

        unawaited(_localDb.saveCustomerShops(shops));
        return shops;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getCustomerShops();
  }

  // Fetch Single Shop Details
  Future<CustomerShop?> getShopDetails(String shopId) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final row = await _client
            .from('shops')
            .select()
            .eq('id', shopId)
            .single();
        final shop = CustomerShop.fromMap(asStringMap(row));
        unawaited(_localDb.saveCustomerShops([shop]));
        return shop;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getCustomerShopById(shopId);
  }

  // Fetch Paginated Products (strictly [limit] per request, default 6)
  Future<PaginatedPage<CustomerProduct>> getProductsPage({
    String? categoryId,
    String? shopId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? color,
    String? size,
    bool inStockOnly = false,
    double? minRating,
    ProductSortOption sort = ProductSortOption.newest,
    int limit = kProductPageSize,
    int offset = 0,
    String? excludeProductId,
  }) async {
    final userId = await _resolveUserId();
    final hasSearchQuery =
        (search != null && search.trim().isNotEmpty) ||
        ActiveVisualSearchStore.instance.currentQuery.value != null;
    final hasAnyFilter =
        hasSearchQuery ||
        (categoryId != null && categoryId.isNotEmpty) ||
        (color != null && color.isNotEmpty) ||
        (size != null && size.isNotEmpty) ||
        minPrice != null ||
        maxPrice != null ||
        inStockOnly ||
        minRating != null;

    if (NetworkMonitorService.instance.isOnline) {
      try {
        var query = _client
            .from('products')
            .select('''
          id, shop_id, category_id, name, description, details, price, status,
          shops:shop_id(name),
          categories:category_id(name),
          variants:product_variants(*),
          images:product_images(*)
        ''')
            .eq('status', 'published');

        if (excludeProductId != null && excludeProductId.isNotEmpty) {
          query = query.neq('id', excludeProductId);
        }
        if (categoryId != null && categoryId.isNotEmpty) {
          final categories = await getCategories(throwOnError: true);
          query = query.inFilter(
            'category_id',
            categoryBranchIds(categories, categoryId).toList(),
          );
        }
        if (shopId != null && shopId.isNotEmpty) {
          query = query.eq('shop_id', shopId);
        }
        if (!hasSearchQuery && minPrice != null) {
          query = query.gte('price', minPrice);
        }
        if (!hasSearchQuery && maxPrice != null) {
          query = query.lte('price', maxPrice);
        }

        final orderedQuery = switch (sort) {
          ProductSortOption.priceAsc =>
            query
                .order('price', ascending: true)
                .order('created_at', ascending: false),
          ProductSortOption.priceDesc =>
            query
                .order('price', ascending: false)
                .order('created_at', ascending: false),
          ProductSortOption.nameAsc =>
            query
                .order('name', ascending: true)
                .order('created_at', ascending: false),
          _ => query.order('created_at', ascending: false),
        };

        // When searching by text, voice, or image, fetch a broader pool on page 0
        // so variant colors, sizes, descriptions, and visual histograms are matched.
        if (hasSearchQuery && offset > 0) {
          return const PaginatedPage<CustomerProduct>(
            items: [],
            rawCount: 0,
          );
        }

        // Wide search pool: covers the whole catalog for typical store sizes.
        final effectiveLimit = hasSearchQuery ? kSearchPoolSize : limit;
        final from = offset < 0 ? 0 : offset;
        final to = from + effectiveLimit - 1;
        final rawRows = await orderedQuery.range(from, to) as List;
        final favoriteIds = await _getUserFavoriteIds();

        final mapped = _mapProductRows(rawRows, favoriteIds);
        unawaited(_localDb.saveCustomerProducts(mapped));

        if (hasSearchQuery) {
          final isVisual =
              ActiveVisualSearchStore.instance.currentQuery.value != null;
          final warm = VisualSearchService.instance.warmProductImages(
            [
              for (final p in mapped) ...[
                p.coverImage,
                if (isVisual) ...p.images.where((i) => i.kind != '3d_model').map((i) => i.filePath),
              ],
            ],
            downloadIfMissing: isVisual,
            maxImages: isVisual ? 250 : 60,
            concurrency: 8,
          );
          // Image search needs descriptors before ranking; text search only
          // uses them as a bonus, so it never waits for image analysis.
          if (isVisual) {
            await warm;
          } else {
            unawaited(warm);
          }
        }

        final activeFilter = ProductFilter(
          categoryId: categoryId,
          shopId: shopId,
          search: search,
          minPrice: minPrice,
          maxPrice: maxPrice,
          color: color,
          size: size,
          inStockOnly: inStockOnly,
          minRating: minRating,
          sort: sort,
        );

        final refined = applyCustomerProductFilter(
          mapped,
          ProductFilter(
            // Server already filtered the category branch
            shopId: shopId,
            search: search,
            minPrice: minPrice,
            maxPrice: maxPrice,
            color: color,
            size: size,
            inStockOnly: inStockOnly,
            minRating: minRating,
            sort: sort,
          ),
        );

        if (refined.isEmpty && offset == 0 && hasAnyFilter) {
          var fallbackPool = mapped;
          if (fallbackPool.isEmpty) {
            final fallbackRows = await _client
                .from('products')
                .select('''
              id, shop_id, category_id, name, description, details, price, status,
              shops:shop_id(name),
              categories:category_id(name),
              variants:product_variants(*),
              images:product_images(*)
            ''')
                .eq('status', 'published')
                .order('created_at', ascending: false)
                .limit(120) as List;
            fallbackPool = _mapProductRows(fallbackRows, favoriteIds);
            unawaited(_localDb.saveCustomerProducts(fallbackPool));
          }
          final similar = computeSimilarCustomerProducts(
            fallbackPool,
            activeFilter,
            maxResults: limit,
          );
          if (similar.isNotEmpty) {
            return PaginatedPage<CustomerProduct>(
              items: similar,
              rawCount: 0,
              isSimilarFallback: true,
            );
          }
        }

        return PaginatedPage<CustomerProduct>(
          items: refined,
          rawCount: hasSearchQuery ? 0 : rawRows.length,
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }

    return _localDb.getCustomerProductsPage(
      customerId: userId,
      categoryId: categoryId,
      shopId: shopId,
      search: search,
      minPrice: minPrice,
      maxPrice: maxPrice,
      color: color,
      size: size,
      inStockOnly: inStockOnly,
      minRating: minRating,
      sort: sort,
      limit: limit,
      offset: offset,
      excludeProductId: excludeProductId,
    );
  }

  // Fetch Products with Filters & Pagination (non-throwing wrapper)
  Future<List<CustomerProduct>> getProducts({
    String? categoryId,
    String? shopId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? color,
    String? size,
    int limit = kProductPageSize,
    int offset = 0,
    String? excludeProductId,
  }) async {
    try {
      final page = await getProductsPage(
        categoryId: categoryId,
        shopId: shopId,
        search: search,
        minPrice: minPrice,
        maxPrice: maxPrice,
        color: color,
        size: size,
        limit: limit,
        offset: offset,
        excludeProductId: excludeProductId,
      );
      return page.items;
    } catch (_) {
      return const [];
    }
  }

  List<CustomerProduct> _mapProductRows(
    List<dynamic> rows,
    Set<String> favoriteIds,
  ) {
    return rows.map((row) {
      final map = asStringMap(row);
      final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
      final catMap = row['categories'] is Map
          ? asStringMap(row['categories'])
          : null;

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
  }

  // Fetch Product Details
  Future<CustomerProduct?> getProductDetails(String productId) async {
    final userId = await _resolveUserId();

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final row = await _client
            .from('products')
            .select('''
          id, shop_id, category_id, name, description, details, price, status,
          shops:shop_id(name),
          categories:category_id(name),
          variants:product_variants(*),
          images:product_images(*)
        ''')
            .eq('id', productId)
            .single();

        final map = asStringMap(row);
        final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
        final catMap = row['categories'] is Map
            ? asStringMap(row['categories'])
            : null;

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

        final product = CustomerProduct.fromMap(
          map,
          variants: variantsList,
          images: imagesList,
          isFavorite: favoriteIds.contains(productId),
          ratingAvg: ratingAvg,
          ratingCount: reviews.length,
        );
        unawaited(_localDb.saveCustomerProducts([product]));
        return product;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    return _localDb.getCustomerProductById(productId, customerId: userId);
  }

  // Favorites helpers
  Future<Set<String>> _getUserFavoriteIds() async {
    final userId = await _resolveUserId();
    if (userId == null) return const {};

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('favorites')
            .select('product_id')
            .eq('customer_id', userId);
        final ids = (rows as List)
            .map((r) => r['product_id'].toString())
            .toSet();
        unawaited(_localDb.saveFavoriteIds(userId, ids));
        return ids;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getFavoriteProductIds(userId);
  }

  Future<bool> toggleFavorite(String productId) async {
    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    // Always update local state immediately
    final nextLocalFavorite = await _localDb.toggleFavoriteLocal(
      customerId: userId,
      productId: productId,
    );

    if (NetworkMonitorService.instance.isOnline) {
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
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'fav_${userId}_$productId',
      userId: userId,
      actionType: 'favorite_set',
      entityId: productId,
      payload: {
        'product_id': productId,
        'is_favorite': nextLocalFavorite,
      },
    );
    return nextLocalFavorite;
  }

  Future<PaginatedPage<CustomerProduct>> getFavoritesPage({
    int limit = kProductPageSize,
    int offset = 0,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) {
      return const PaginatedPage<CustomerProduct>(items: [], rawCount: 0);
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final from = offset < 0 ? 0 : offset;
        final to = from + limit - 1;
        final rawRows =
            await _client
                    .from('favorites')
                    .select('''
          product:products(
            id, shop_id, category_id, name, description, details, price, status,
            shops:shop_id(name),
            categories:category_id(name),
            variants:product_variants(*),
            images:product_images(*)
          )
        ''')
                    .eq('customer_id', userId)
                    .order('created_at', ascending: false)
                    .range(from, to)
                as List;

        final mapped = _mapFavoriteRows(rawRows);
        unawaited(_localDb.saveCustomerProducts(mapped));

        return PaginatedPage<CustomerProduct>(
          items: mapped,
          rawCount: rawRows.length,
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }

    return _localDb.getFavoritesPage(
      customerId: userId,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<CustomerProduct>> getFavorites() async {
    try {
      final page = await getFavoritesPage();
      return page.items;
    } catch (_) {
      return const [];
    }
  }

  List<CustomerProduct> _mapFavoriteRows(List<dynamic> rows) {
    final list = <CustomerProduct>[];
    for (final row in rows) {
      final pData = row['product'];
      if (pData == null || pData is! Map) continue;
      final map = asStringMap(pData);
      final shopMap = pData['shops'] is Map
          ? asStringMap(pData['shops'])
          : null;
      final catMap = pData['categories'] is Map
          ? asStringMap(pData['categories'])
          : null;

      map['shop_name'] = shopMap?['name'] ?? 'متجر';
      map['category_name'] = catMap?['name'];

      final variants = (pData['variants'] as List? ?? [])
          .map((v) => ProductVariant.fromMap(asStringMap(v)))
          .toList();

      final images = (pData['images'] as List? ?? [])
          .map((img) => ProductImage.fromMap(asStringMap(img)))
          .toList();

      list.add(
        CustomerProduct.fromMap(
          map,
          variants: variants,
          images: images,
          isFavorite: true,
        ),
      );
    }
    return list;
  }

  // Reviews
  Future<List<ProductReview>> getProductReviews(String productId) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('product_reviews')
            .select('''
          id, product_id, customer_id, rating, comment, created_at,
          profiles:customer_id(full_name)
        ''')
            .eq('product_id', productId)
            .order('created_at', ascending: false);

        final reviews = (rows as List).map((row) {
          final map = asStringMap(row);
          final profile = row['profiles'] is Map
              ? asStringMap(row['profiles'])
              : null;
          map['customer_name'] = profile?['full_name'] ?? 'عميل';
          return ProductReview.fromMap(map);
        }).toList();

        unawaited(_localDb.saveProductReviews(productId, reviews));
        return reviews;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getProductReviews(productId);
  }

  Future<void> addReview({
    required String productId,
    required int rating,
    String? comment,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    final profile = await _localDb.getUserProfile(userId);
    final customerName = profile?.displayName ?? 'عميل';
    final cleanComment = comment?.trim();
    final nowIso = DateTime.now().toIso8601String();

    await _localDb.upsertProductReviewLocal(
      productId: productId,
      customerId: userId,
      customerName: customerName,
      rating: rating,
      comment: cleanComment,
    );

    if (NetworkMonitorService.instance.isOnline) {
      try {
        await _client.from('product_reviews').upsert({
          'customer_id': userId,
          'product_id': productId,
          'rating': rating,
          'comment': cleanComment,
          'created_at': nowIso,
        }, onConflict: 'customer_id,product_id');
        return;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'review_${userId}_$productId',
      userId: userId,
      actionType: 'add_review',
      entityId: productId,
      payload: {
        'product_id': productId,
        'rating': rating,
        'comment': cleanComment,
        'created_at': nowIso,
      },
    );
  }

  // Cart persistence in Supabase + Encrypted Local SQLite
  Future<List<CartItem>> getCartItems() async {
    final userId = await _resolveUserId();
    if (userId == null) return const [];

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('cart_items')
            .select('''
              id, product_id, variant_id, color, size, quantity,
              product:products(
                id, shop_id, name, price, status,
                shops:shop_id(name),
                variants:product_variants(*),
                images:product_images(*)
              )
            ''')
            .eq('customer_id', userId)
            .order('created_at', ascending: true);

        final items = <CartItem>[];
        for (final row in rows as List) {
          final r = asStringMap(row);
          final pData = row['product'];
          if (pData == null || pData is! Map) continue;
          final pMap = asStringMap(pData);
          if (pMap['status']?.toString() != 'published') continue;

          final shopMap = pData['shops'] is Map
              ? asStringMap(pData['shops'])
              : null;
          final shopName = shopMap?['name']?.toString() ?? 'متجر';
          final productId =
              pMap['id']?.toString() ?? r['product_id']?.toString() ?? '';
          final shopId = pMap['shop_id']?.toString() ?? '';
          final productName = pMap['name']?.toString() ?? 'منتج';
          final unitPrice = (pMap['price'] as num?)?.toDouble() ?? 0.0;
          final color = r['color']?.toString() ?? '';
          final size = r['size']?.toString() ?? '';
          final variantId = r['variant_id']?.toString();

          final variants = (pData['variants'] as List? ?? [])
              .map((v) => ProductVariant.fromMap(asStringMap(v)))
              .toList();
          final images = (pData['images'] as List? ?? [])
              .map((img) => ProductImage.fromMap(asStringMap(img)))
              .toList();

          String? coverImage;
          for (final img in images) {
            if (img.kind == 'cover') {
              coverImage = img.filePath;
              break;
            }
          }
          coverImage ??= images.isNotEmpty ? images.first.filePath : null;

          int maxStock = 999;
          for (final v in variants) {
            if ((variantId != null && v.id == variantId) ||
                (v.color == color && v.size == size)) {
              maxStock = v.stock > 0 ? v.stock : 1;
              break;
            }
          }

          final qty = ((r['quantity'] as num?)?.toInt() ?? 1).clamp(
            1,
            maxStock,
          );
          final cartItemId = '${productId}_${color}_$size';

          items.add(
            CartItem(
              id: cartItemId,
              productId: productId,
              productName: productName,
              shopId: shopId,
              shopName: shopName,
              variantId: variantId,
              color: color,
              size: size,
              unitPrice: unitPrice,
              quantity: qty,
              imagePath: coverImage,
              maxStock: maxStock,
            ),
          );
        }

        unawaited(_localDb.saveCartItems(userId, items));
        return items;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    return _localDb.getCartItems(userId);
  }

  Future<void> upsertCartItem({
    required String productId,
    String? variantId,
    required String color,
    required String size,
    required int quantity,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) return;

    await _localDb.upsertCartItemLocal(
      customerId: userId,
      productId: productId,
      variantId: variantId,
      color: color,
      size: size,
      quantity: quantity,
    );

    if (NetworkMonitorService.instance.isOnline) {
      try {
        await _client.from('cart_items').upsert({
          'customer_id': userId,
          'product_id': productId,
          'variant_id': (variantId == null || variantId.isEmpty)
              ? null
              : variantId,
          'color': color,
          'size': size,
          'quantity': quantity,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'customer_id,product_id,color,size');
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'cart_${userId}_${productId}_${color}_$size',
      userId: userId,
      actionType: 'cart_upsert',
      entityId: '${productId}_${color}_$size',
      payload: {
        'product_id': productId,
        'variant_id': variantId,
        'color': color,
        'size': size,
        'quantity': quantity,
      },
    );
  }

  Future<void> removeCartItem({
    required String productId,
    required String color,
    required String size,
  }) async {
    final userId = await _resolveUserId();
    if (userId == null) return;

    await _localDb.removeCartItemLocal(
      customerId: userId,
      productId: productId,
      color: color,
      size: size,
    );

    if (NetworkMonitorService.instance.isOnline) {
      try {
        await _client
            .from('cart_items')
            .delete()
            .eq('customer_id', userId)
            .eq('product_id', productId)
            .eq('color', color)
            .eq('size', size);
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'cart_${userId}_${productId}_${color}_$size',
      userId: userId,
      actionType: 'cart_remove',
      entityId: '${productId}_${color}_$size',
      payload: {
        'product_id': productId,
        'color': color,
        'size': size,
      },
    );
  }

  Future<void> clearCartItems() async {
    final userId = await _resolveUserId();
    if (userId == null) return;

    await _localDb.clearCartItemsLocal(userId);

    if (NetworkMonitorService.instance.isOnline) {
      try {
        await _client.from('cart_items').delete().eq('customer_id', userId);
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'cart_clear_${userId}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      actionType: 'cart_clear',
      entityId: userId,
      payload: const {},
    );
  }

  // Comparison persistence in Supabase + Local SQLite
  Future<List<CustomerProduct>> getComparisonProducts() async {
    final userId = await _resolveUserId();
    if (userId == null) return const [];

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('comparison_items')
            .select('''
              product:products(
                id, shop_id, category_id, name, description, details, price, status,
                shops:shop_id(name),
                categories:category_id(name),
                variants:product_variants(*),
                images:product_images(*)
              )
            ''')
            .eq('customer_id', userId)
            .order('created_at', ascending: true);

        final favoriteIds = await _getUserFavoriteIds();
        final list = <CustomerProduct>[];
        for (final row in rows as List) {
          final pData = row['product'];
          if (pData == null || pData is! Map) continue;
          final map = asStringMap(pData);
          if (map['status']?.toString() != 'published') continue;
          final shopMap = pData['shops'] is Map
              ? asStringMap(pData['shops'])
              : null;
          final catMap = pData['categories'] is Map
              ? asStringMap(pData['categories'])
              : null;
          map['shop_name'] = shopMap?['name'] ?? 'متجر';
          map['category_name'] = catMap?['name'];

          final variants = (pData['variants'] as List? ?? [])
              .map((v) => ProductVariant.fromMap(asStringMap(v)))
              .toList();
          final images = (pData['images'] as List? ?? [])
              .map((img) => ProductImage.fromMap(asStringMap(img)))
              .toList();
          final pid = map['id']?.toString() ?? '';

          list.add(
            CustomerProduct.fromMap(
              map,
              variants: variants,
              images: images,
              isFavorite: favoriteIds.contains(pid),
            ),
          );
        }
        unawaited(_localDb.saveComparisonProducts(userId, list));
        return list;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    return _localDb.getComparisonProducts(userId);
  }

  Future<void> addComparisonProduct(String productId) async {
    final userId = await _resolveUserId();
    if (userId == null) return;

    await _localDb.addComparisonProductLocal(userId, productId);

    if (NetworkMonitorService.instance.isOnline) {
      try {
        await _client.from('comparison_items').upsert({
          'customer_id': userId,
          'product_id': productId,
        }, onConflict: 'customer_id,product_id');
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'cmp_${userId}_$productId',
      userId: userId,
      actionType: 'comparison_add',
      entityId: productId,
      payload: {'product_id': productId},
    );
  }

  Future<void> removeComparisonProduct(String productId) async {
    final userId = await _resolveUserId();
    if (userId == null) return;

    await _localDb.removeComparisonProductLocal(userId, productId);

    if (NetworkMonitorService.instance.isOnline) {
      try {
        await _client
            .from('comparison_items')
            .delete()
            .eq('customer_id', userId)
            .eq('product_id', productId);
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'cmp_${userId}_$productId',
      userId: userId,
      actionType: 'comparison_remove',
      entityId: productId,
      payload: {'product_id': productId},
    );
  }

  Future<void> clearComparisonProducts() async {
    final userId = await _resolveUserId();
    if (userId == null) return;

    await _localDb.clearComparisonProductsLocal(userId);

    if (NetworkMonitorService.instance.isOnline) {
      try {
        await _client
            .from('comparison_items')
            .delete()
            .eq('customer_id', userId);
        return;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    await OfflineSyncEngine.instance.enqueue(
      id: 'cmp_clear_${userId}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      actionType: 'comparison_clear',
      entityId: userId,
      payload: const {},
    );
  }

  // Orders (Online RPC + Encrypted Offline Order Creation & Auto-Sync)
  Future<CustomerOrder> placeOrder({
    required String shopId,
    required List<CartItem> items,
    required String deliveryAddress,
    required String phone,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw StateError('السلة فارغة');
    }

    final payload = items.map((i) => i.toOrderPayload()).toList();
    final trimmedAddress = deliveryAddress.trim();
    final trimmedPhone = phone.trim();
    final trimmedNotes = notes?.trim();

    if (NetworkMonitorService.instance.isOnline) {
      try {
        dynamic result;
        try {
          result = await _client.rpc(
            'customer_place_order',
            params: {
              'p_shop_id': shopId,
              'p_items': payload,
              'p_delivery_address': trimmedAddress,
              'p_phone': trimmedPhone,
              'p_notes': trimmedNotes,
            },
          );
        } on PostgrestException catch (e) {
          // Fallback if the 4-argument version of customer_place_order is still installed
          if (e.message.contains('p_notes') || e.code == 'PGRST202') {
            result = await _client.rpc(
              'customer_place_order',
              params: {
                'p_shop_id': shopId,
                'p_items': payload,
                'p_delivery_address': trimmedAddress,
                'p_phone': trimmedPhone,
              },
            );
          } else {
            rethrow;
          }
        }

        final createdOrder = CustomerOrder.fromMap(asStringMap(result));
        await _localDb.saveCustomerOrders([createdOrder]);
        return createdOrder;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    // Offline order creation path (Encrypted & HMAC-signed)
    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final tempOrderId = 'offline_ord_${timestampMs}_$shopId';
    final shopName = items.first.shopName;
    final total = items.fold<double>(0.0, (sum, i) => sum + i.totalPrice);

    final orderItems = items.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      return CustomerOrderItem(
        id: '${tempOrderId}_item_$idx',
        orderId: tempOrderId,
        productId: item.productId,
        variantId: item.variantId,
        productName: item.productName,
        variantInfo: item.variantDescription,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
        totalPrice: item.totalPrice,
        imagePath: item.imagePath,
      );
    }).toList();

    final offlineOrder = CustomerOrder(
      id: tempOrderId,
      customerId: userId,
      shopId: shopId,
      shopName: shopName,
      status: 'pending',
      total: total,
      createdAt: DateTime.now(),
      deliveryAddress: trimmedAddress,
      phone: trimmedPhone,
      notes: trimmedNotes,
      items: orderItems,
    );

    await _localDb.saveCustomerOrders([offlineOrder], isOfflinePending: true);

    await OfflineSyncEngine.instance.enqueue(
      id: 'place_order_$tempOrderId',
      userId: userId,
      actionType: 'place_order',
      entityId: tempOrderId,
      payload: {
        'temp_order_id': tempOrderId,
        'shop_id': shopId,
        'items': payload,
        'delivery_address': trimmedAddress,
        'phone': trimmedPhone,
        'notes': trimmedNotes,
        'total': total,
      },
    );

    return offlineOrder;
  }

  Future<List<CustomerOrder>> getCustomerOrders() async {
    final userId = await _resolveUserId();
    if (userId == null) return const [];

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('orders')
            .select('''
          *,
          shops:shop_id(name),
          items:order_items(*)
        ''')
            .eq('customer_id', userId)
            .order('created_at', ascending: false);

        final remoteOrders = (rows as List).map((row) {
          final map = asStringMap(row);
          final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
          map['shop_name'] = shopMap?['name'] ?? 'متجر';

          final itemsList = (row['items'] as List? ?? [])
              .map((item) => CustomerOrderItem.fromMap(asStringMap(item)))
              .toList();

          return CustomerOrder.fromMap(map, items: itemsList);
        }).toList();

        unawaited(_localDb.saveCustomerOrders(remoteOrders));

        // Merge any offline-pending orders that haven't finished syncing yet
        final localOrders = await _localDb.getCustomerOrders(userId);
        final pendingOfflineOrders = localOrders
            .where((o) => o.id.startsWith('offline_ord_'))
            .toList();
        return [...pendingOfflineOrders, ...remoteOrders];
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    return _localDb.getCustomerOrders(userId);
  }

  Future<CustomerOrder?> getOrderDetails(String orderId) async {
    if (orderId.startsWith('offline_ord_')) {
      return _localDb.getCustomerOrderById(orderId);
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final row = await _client
            .from('orders')
            .select('''
          *,
          shops:shop_id(name),
          items:order_items(*)
        ''')
            .eq('id', orderId)
            .single();

        final map = asStringMap(row);
        final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
        map['shop_name'] = shopMap?['name'] ?? 'متجر';

        final itemsList = (row['items'] as List? ?? [])
            .map((item) => CustomerOrderItem.fromMap(asStringMap(item)))
            .toList();

        final order = CustomerOrder.fromMap(map, items: itemsList);
        unawaited(_localDb.saveCustomerOrders([order]));
        return order;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    return _localDb.getCustomerOrderById(orderId);
  }

  // Notifications
  Future<List<AdminNotification>> getCustomerNotifications() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('notifications')
            .select()
            .inFilter('audience', ['all', 'customer'])
            .order('created_at', ascending: false);
        final notifications = (rows as List)
            .map((r) => AdminNotification.fromMap(asStringMap(r)))
            .toList();
        unawaited(_localDb.saveNotifications(notifications));
        return notifications;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getNotifications(audiences: const ['all', 'customer']);
  }

  bool _isNetworkError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('connection closed') ||
        msg.contains('connection refused') ||
        msg.contains('network is unreachable') ||
        msg.contains('timed out') ||
        msg.contains('xmlhttprequest error');
  }

  String mapError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return 'حدث خطأ. حاول مرة أخرى';
  }
}
