import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/cache/app_memory_cache.dart';
import '../../../core/filtering/filter_models.dart';
import '../../../core/network/network_guard.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/network_monitor_service.dart';
import '../../../core/offline/offline_sync_engine.dart';
import '../../../core/pagination/paginated_state.dart';
import '../../../core/search/smart_search_sheets.dart';
import '../../../core/search/visual_search_service.dart';
import '../../../core/utils/app_image_compressor.dart';
import '../../../core/utils/map_utils.dart';
import '../../admin/domain/models/catalog_models.dart';
import '../../admin/domain/models/payment_method.dart';
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
  final AppMemoryCache _cache = AppMemoryCache.instance;

  static bool _feedLiteRpcAvailable = true;
  static bool _homeBootstrapRpcAvailable = true;

  static const Duration _bannersTtl = Duration(minutes: 5);
  static const Duration _categoriesTtl = Duration(minutes: 10);
  static const Duration _shopsTtl = Duration(minutes: 5);
  static const Duration _feedTtl = Duration(minutes: 3);
  static const Duration _favoritesTtl = Duration(minutes: 3);
  static const Duration _detailsTtl = Duration(minutes: 2);

  static const String _kBannersKey = 'customer:banners';
  static const String _kCategoriesKey = 'customer:categories';
  static const String _kShopsKey = 'customer:shops';
  static const String _kHomeBootstrapKey = 'customer:home_bootstrap';

  String? get currentUserId => _client.auth.currentUser?.id;

  bool _isMissingRpcError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('pgrst202') ||
        msg.contains('42883') ||
        msg.contains('could not find the function') ||
        msg.contains('does not exist');
  }

  String _sortKeyForRpc(ProductSortOption sort) {
    return switch (sort) {
      ProductSortOption.priceAsc => 'price_asc',
      ProductSortOption.priceDesc => 'price_desc',
      ProductSortOption.nameAsc => 'name_asc',
      ProductSortOption.topRated => 'rating_desc',
      _ => 'newest',
    };
  }

  String _feedCacheKey({
    required String? userId,
    required String? categoryId,
    required String? shopId,
    required double? minPrice,
    required double? maxPrice,
    required String? color,
    required String? size,
    required bool inStockOnly,
    required double? minRating,
    required ProductSortOption sort,
    required int limit,
    required int offset,
    required String? excludeProductId,
  }) {
    return 'customer:feed:${userId ?? 'anon'}|c:${categoryId ?? ''}|s:${shopId ?? ''}|min:${minPrice ?? ''}|max:${maxPrice ?? ''}|col:${color ?? ''}|sz:${size ?? ''}|st:$inStockOnly|r:${minRating ?? ''}|o:${sort.name}|ex:${excludeProductId ?? ''}|l:$limit|off:$offset';
  }

  /// Clears in-memory customer caches (e.g. on pull-to-refresh or account switch).
  void invalidateCatalogCache({bool includeStatic = false}) {
    _cache.invalidatePrefix('customer:feed:');
    _cache.invalidate(_kHomeBootstrapKey);
    if (includeStatic) {
      _cache.invalidate(_kBannersKey);
      _cache.invalidate(_kCategoriesKey);
      _cache.invalidate(_kShopsKey);
      _cache.invalidatePrefix('customer:shop:');
    }
  }

  /// Fetches banners + categories + approved shops + first page of lite products
  /// + user favorites in ONE single Supabase RPC round-trip (when migration 040
  /// is installed), hydrating both memory cache and SQLite simultaneously.
  Future<bool> warmHomeBootstrap({
    int productsLimit = kProductPageSize,
    bool forceRefresh = false,
  }) async {
    if (!_homeBootstrapRpcAvailable || !NetworkMonitorService.instance.isOnline) {
      return false;
    }

    if (!forceRefresh &&
        _cache.hasFresh(_kBannersKey) &&
        _cache.hasFresh(_kCategoriesKey) &&
        _cache.hasFresh(_kShopsKey)) {
      return true;
    }

    final userId = await _resolveUserId();
    try {
      return await _cache.fetchCached<bool>(
        _kHomeBootstrapKey,
        ttl: _feedTtl,
        forceRefresh: forceRefresh,
        loader: () async {
          final raw = await _client.rpc(
            'get_home_bootstrap',
            params: {'p_products_limit': productsLimit},
          );
          if (raw is! Map) return false;
          final payload = asStringMap(raw);

          final banners = (payload['banners'] as List? ?? const [])
              .map((row) => AdminBanner.fromMap(asStringMap(row)))
              .toList();
          final categories = (payload['categories'] as List? ?? const [])
              .map((row) => CatalogCategory.fromMap(asStringMap(row)))
              .toList();
          final shops = (payload['shops'] as List? ?? const []).map((row) {
            final map = asStringMap(row);
            final count = (map['products_count'] as num?)?.toInt() ?? 0;
            return CustomerShop.fromMap(map, productsCount: count);
          }).toList();
          final products = (payload['products'] as List? ?? const [])
              .map((row) => CustomerProduct.fromLiteFeedMap(asStringMap(row)))
              .toList();
          final favIds = (payload['favorite_ids'] as List? ?? const [])
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toSet();

          _cache.set<List<AdminBanner>>(
            _kBannersKey,
            banners,
            ttl: _bannersTtl,
          );
          _cache.set<List<CatalogCategory>>(
            _kCategoriesKey,
            categories,
            ttl: _categoriesTtl,
          );
          _cache.set<List<CustomerShop>>(_kShopsKey, shops, ttl: _shopsTtl);
          if (userId != null) {
            _cache.set<Set<String>>(
              'customer:favorites:$userId',
              favIds,
              ttl: _favoritesTtl,
            );
          }

          final defaultFeedKey = _feedCacheKey(
            userId: userId,
            categoryId: null,
            shopId: null,
            minPrice: null,
            maxPrice: null,
            color: null,
            size: null,
            inStockOnly: false,
            minRating: null,
            sort: ProductSortOption.newest,
            limit: productsLimit,
            offset: 0,
            excludeProductId: null,
          );
          _cache.set<PaginatedPage<CustomerProduct>>(
            defaultFeedKey,
            PaginatedPage<CustomerProduct>(
              items: products,
              rawCount: products.length,
            ),
            ttl: _feedTtl,
          );

          NetworkMonitorService.instance.reportNetworkSuccess();

          // Persist to SQLite asynchronously so offline & cold-start SWR stay hot
          unawaited(_localDb.saveBanners(banners));
          unawaited(_localDb.saveCategories(categories));
          unawaited(_localDb.saveCustomerShops(shops));
          if (userId != null) {
            unawaited(_localDb.saveFavoriteIds(userId, favIds));
          }
          if (products.isNotEmpty) {
            unawaited(
              _localDb.saveCustomerProducts(products, isLiteSummary: true),
            );
          }
          return true;
        },
      );
    } catch (e) {
      _cache.invalidate(_kHomeBootstrapKey);
      if (_isMissingRpcError(e)) {
        _homeBootstrapRpcAvailable = false;
      } else if (_isNetworkError(e)) {
        NetworkMonitorService.instance.reportNetworkFailure();
      }
      return false;
    }
  }

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

    final data = await NetworkGuard.run(
      () => _client.rpc(
        'complete_customer_profile',
        params: {
          'p_full_name': trimmedName,
          'p_phone': trimmedPhone,
          'p_city': trimmedCity,
          'p_address': trimmedAddress,
        },
      ),
      timeout: AppTimeouts.action,
    );
    final updatedUser = AppUser.fromMap(asStringMap(data));
    await _localDb.saveUserProfile(updatedUser, isCurrentSession: true);
    return updatedUser;
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

  // Fetch Banners (Memory TTL + In-flight deduplication + SQLite fallback)
  Future<List<AdminBanner>> getBanners({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.getFresh<List<AdminBanner>>(_kBannersKey);
      if (cached != null) return cached;
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        return await _cache.fetchCached<List<AdminBanner>>(
          _kBannersKey,
          ttl: _bannersTtl,
          forceRefresh: forceRefresh,
          loader: () async {
            final rows = await _client
                .from('banners')
                .select()
                .eq('is_active', true)
                .order('sort_order', ascending: true)
                .order('updated_at', ascending: false);
            final banners = (rows as List)
                .map((row) => AdminBanner.fromMap(asStringMap(row)))
                .toList();
            NetworkMonitorService.instance.reportNetworkSuccess();
            unawaited(_localDb.saveBanners(banners));
            return banners;
          },
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    final local = await _localDb.getBanners(activeOnly: true);
    if (local.isNotEmpty) {
      _cache.set<List<AdminBanner>>(_kBannersKey, local, ttl: _bannersTtl);
    }
    return local;
  }

  // Fetch Categories (Memory TTL + In-flight deduplication + SQLite fallback)
  Future<List<CatalogCategory>> getCategories({
    bool throwOnError = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getFresh<List<CatalogCategory>>(_kCategoriesKey);
      if (cached != null) return cached;
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        return await _cache.fetchCached<List<CatalogCategory>>(
          _kCategoriesKey,
          ttl: _categoriesTtl,
          forceRefresh: forceRefresh,
          loader: () async {
            final rows = await _client
                .from('categories')
                .select()
                .eq('is_active', true)
                .order('sort_order', ascending: true);
            final categories = (rows as List)
                .map((row) => CatalogCategory.fromMap(asStringMap(row)))
                .toList();
            NetworkMonitorService.instance.reportNetworkSuccess();
            unawaited(_localDb.saveCategories(categories));
            return categories;
          },
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else if (throwOnError) {
          rethrow;
        }
      }
    }

    final localCategories = await _localDb.getCategories(activeOnly: true);
    if (localCategories.isNotEmpty) {
      _cache.set<List<CatalogCategory>>(
        _kCategoriesKey,
        localCategories,
        ttl: _categoriesTtl,
      );
    }
    return localCategories;
  }

  // Fetch Approved Shops (Memory TTL + In-flight deduplication + SQLite fallback)
  Future<List<CustomerShop>> getShops({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.getFresh<List<CustomerShop>>(_kShopsKey);
      if (cached != null) return cached;
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        return await _cache.fetchCached<List<CustomerShop>>(
          _kShopsKey,
          ttl: _shopsTtl,
          forceRefresh: forceRefresh,
          loader: () async {
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

            NetworkMonitorService.instance.reportNetworkSuccess();
            unawaited(_localDb.saveCustomerShops(shops));
            return shops;
          },
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    final local = await _localDb.getCustomerShops();
    if (local.isNotEmpty) {
      _cache.set<List<CustomerShop>>(_kShopsKey, local, ttl: _shopsTtl);
    }
    return local;
  }

  // Fetch Single Shop Details (Memory TTL + SQLite fallback)
  Future<CustomerShop?> getShopDetails(
    String shopId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'customer:shop:$shopId';
    if (!forceRefresh) {
      final cached = _cache.getFresh<CustomerShop?>(cacheKey);
      if (cached != null) return cached;
      final allShops = _cache.getFresh<List<CustomerShop>>(_kShopsKey);
      final match = allShops?.where((s) => s.id == shopId).firstOrNull;
      if (match != null) {
        _cache.set<CustomerShop?>(cacheKey, match, ttl: _shopsTtl);
        return match;
      }
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        return await _cache.fetchCached<CustomerShop?>(
          cacheKey,
          ttl: _shopsTtl,
          forceRefresh: forceRefresh,
          loader: () async {
            final row = await _client
                .from('shops')
                .select()
                .eq('id', shopId)
                .single();
            final shop = CustomerShop.fromMap(asStringMap(row));
            NetworkMonitorService.instance.reportNetworkSuccess();
            unawaited(_localDb.saveCustomerShops([shop]));
            return shop;
          },
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getCustomerShopById(shopId);
  }

  /// Instant local hydration for Stale-While-Revalidate (checks memory first,
  /// then encrypted SQLite in < 30ms so product grids render immediately).
  Future<PaginatedPage<CustomerProduct>?> getCachedProductsPage({
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
    final hasSearchQuery =
        (search != null && search.trim().isNotEmpty) ||
        ActiveVisualSearchStore.instance.currentQuery.value != null;
    if (hasSearchQuery) return null;

    final userId = await _resolveUserId();
    final cacheKey = _feedCacheKey(
      userId: userId,
      categoryId: categoryId,
      shopId: shopId,
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

    final memHit = _cache.getAny<PaginatedPage<CustomerProduct>>(cacheKey);
    if (memHit != null && memHit.items.isNotEmpty) {
      return memHit;
    }

    final localPage = await _localDb.getCustomerProductsPage(
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
    return localPage.items.isNotEmpty ? localPage : null;
  }

  // Fetch Paginated Products (ultra-light RPC when available, automatic fallback)
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
    bool forceRefresh = false,
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

    final cacheKey = !hasSearchQuery
        ? _feedCacheKey(
            userId: userId,
            categoryId: categoryId,
            shopId: shopId,
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
          )
        : null;

    if (cacheKey != null && !forceRefresh) {
      final cached = _cache.getFresh<PaginatedPage<CustomerProduct>>(cacheKey);
      if (cached != null) return cached;
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        // Fast path: ultra-lightweight PostgreSQL RPC (1 tiny round-trip, ~80% smaller payload)
        if (!hasSearchQuery && _feedLiteRpcAvailable && cacheKey != null) {
          try {
            return await _cache.fetchCached<PaginatedPage<CustomerProduct>>(
              cacheKey,
              ttl: _feedTtl,
              forceRefresh: forceRefresh,
              loader: () async {
                List<String>? categoryIdsParam;
                if (categoryId != null && categoryId.isNotEmpty) {
                  final allCategories = await getCategories(throwOnError: true);
                  final branchIds = categoryBranchIds(allCategories, categoryId);
                  categoryIdsParam = branchIds.isEmpty
                      ? [categoryId]
                      : branchIds.toList();
                }

                final raw = await _client.rpc(
                  'get_products_feed_lite',
                  params: {
                    'p_category_ids': categoryIdsParam,
                    'p_shop_id': (shopId != null && shopId.isNotEmpty)
                        ? shopId
                        : null,
                    'p_min_price': minPrice,
                    'p_max_price': maxPrice,
                    'p_color': (color != null && color.trim().isNotEmpty)
                        ? color.trim()
                        : null,
                    'p_size': (size != null && size.trim().isNotEmpty)
                        ? size.trim()
                        : null,
                    'p_in_stock_only': inStockOnly,
                    'p_min_rating': minRating,
                    'p_sort': _sortKeyForRpc(sort),
                    'p_exclude_product_id':
                        (excludeProductId != null &&
                            excludeProductId.isNotEmpty)
                        ? excludeProductId
                        : null,
                    'p_limit': limit,
                    'p_offset': offset < 0 ? 0 : offset,
                  },
                );

                final rows = raw is List ? raw : const <dynamic>[];
                final items = rows
                    .map(
                      (row) =>
                          CustomerProduct.fromLiteFeedMap(asStringMap(row)),
                    )
                    .toList();

                NetworkMonitorService.instance.reportNetworkSuccess();

                if (items.isNotEmpty) {
                  unawaited(
                    _localDb.saveCustomerProducts(items, isLiteSummary: true),
                  );
                }

                if (items.isEmpty && offset == 0 && hasAnyFilter) {
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
                  final fallbackRaw = await _client.rpc(
                    'get_products_feed_lite',
                    params: {'p_limit': 60, 'p_offset': 0},
                  );
                  final fallbackPool = (fallbackRaw is List
                          ? fallbackRaw
                          : const <dynamic>[])
                      .map(
                        (row) =>
                            CustomerProduct.fromLiteFeedMap(asStringMap(row)),
                      )
                      .toList();
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
                  items: items,
                  rawCount: rows.length,
                );
              },
            );
          } catch (rpcError) {
            if (_isMissingRpcError(rpcError)) {
              _feedLiteRpcAvailable = false;
            } else {
              rethrow;
            }
          }
        }

        // Fallback path (also used for rich text/voice/visual search)
        var query = _client
            .from('products')
            .select(
              hasSearchQuery
                  ? '''
          id, shop_id, category_id, name, description, details, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
          shops:shop_id(name),
          categories:category_id(name),
          variants:product_variants(*),
          images:product_images(*)
        '''
                  : '''
          id, shop_id, category_id, name, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
          shops:shop_id(name),
          categories:category_id(name),
          variants:product_variants(id, product_id, color, size, stock, is_active),
          images:product_images(id, product_id, file_path, kind, sort_order)
        ''',
            )
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
        final results = await Future.wait<dynamic>([
          orderedQuery.range(from, to),
          _getUserFavoriteIds(),
        ]);
        final rawRows = results[0] as List;
        final favoriteIds = results[1] as Set<String>;
        NetworkMonitorService.instance.reportNetworkSuccess();

        final mapped = _mapProductRows(rawRows, favoriteIds);
        unawaited(
          _localDb.saveCustomerProducts(mapped, isLiteSummary: !hasSearchQuery),
        );

        if (hasSearchQuery) {
          final isVisual =
              ActiveVisualSearchStore.instance.currentQuery.value != null;
          final warm = VisualSearchService.instance.warmProductImages(
            [
              for (final p in mapped) ...[
                p.coverImage,
                if (isVisual)
                  ...p.images
                      .where((i) => i.kind != '3d_model')
                      .map((i) => i.filePath),
              ],
            ],
            downloadIfMissing: isVisual,
            maxImages: isVisual ? 250 : 60,
            concurrency: 8,
          );
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
              id, shop_id, category_id, name, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
              shops:shop_id(name),
              categories:category_id(name),
              variants:product_variants(id, product_id, color, size, stock, is_active),
              images:product_images(id, product_id, file_path, kind, sort_order)
            ''')
                .eq('status', 'published')
                .order('created_at', ascending: false)
                .limit(60) as List;
            fallbackPool = _mapProductRows(fallbackRows, favoriteIds);
            unawaited(
              _localDb.saveCustomerProducts(fallbackPool, isLiteSummary: true),
            );
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

        final pageResult = PaginatedPage<CustomerProduct>(
          items: refined,
          rawCount: hasSearchQuery ? 0 : rawRows.length,
        );
        if (cacheKey != null) {
          _cache.set<PaginatedPage<CustomerProduct>>(
            cacheKey,
            pageResult,
            ttl: _feedTtl,
          );
        }
        return pageResult;
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

  // Fetch Product Details (parallelized + memory TTL + deduplicated reviews/favorites)
  Future<CustomerProduct?> getProductDetails(
    String productId, {
    bool forceRefresh = false,
  }) async {
    final userId = await _resolveUserId();
    final cacheKey = 'customer:product:$productId';

    if (!forceRefresh) {
      final cached = _cache.getFresh<CustomerProduct?>(cacheKey);
      if (cached != null && !cached.isSummaryOnly) {
        if (userId != null) {
          final favs = _cache.getFresh<Set<String>>('customer:favorites:$userId');
          if (favs != null) {
            return cached.copyWith(isFavorite: favs.contains(productId));
          }
        }
        return cached;
      }
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        return await _cache.fetchCached<CustomerProduct?>(
          cacheKey,
          ttl: _detailsTtl,
          forceRefresh: forceRefresh,
          loader: () async {
            final results = await Future.wait<dynamic>([
              _client
                  .from('products')
                  .select('''
                id, shop_id, category_id, name, description, details, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
                shops:shop_id(name),
                categories:category_id(name),
                variants:product_variants(*),
                images:product_images(*)
              ''')
                  .eq('id', productId)
                  .single(),
              _getUserFavoriteIds(),
              getProductReviews(productId),
            ]);

            final row = results[0] as Map<String, dynamic>;
            final favoriteIds = results[1] as Set<String>;
            final reviews = results[2] as List<ProductReview>;
            NetworkMonitorService.instance.reportNetworkSuccess();

            final map = asStringMap(row);
            final shopMap = row['shops'] is Map
                ? asStringMap(row['shops'])
                : null;
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
          },
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }

    return _localDb.getCustomerProductById(productId, customerId: userId);
  }

  // Favorites helpers (Memory TTL + in-flight deduplication)
  Future<Set<String>> _getUserFavoriteIds({bool forceRefresh = false}) async {
    final userId = await _resolveUserId();
    if (userId == null) return const {};
    final cacheKey = 'customer:favorites:$userId';

    if (!forceRefresh) {
      final cached = _cache.getFresh<Set<String>>(cacheKey);
      if (cached != null) return cached;
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        return await _cache.fetchCached<Set<String>>(
          cacheKey,
          ttl: _favoritesTtl,
          forceRefresh: forceRefresh,
          loader: () async {
            final rows = await _client
                .from('favorites')
                .select('product_id')
                .eq('customer_id', userId);
            final ids = (rows as List)
                .map((r) => r['product_id'].toString())
                .toSet();
            NetworkMonitorService.instance.reportNetworkSuccess();
            unawaited(_localDb.saveFavoriteIds(userId, ids));
            return ids;
          },
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    return _localDb.getFavoriteProductIds(userId);
  }

  void _updateCachedFavoriteState(
    String userId,
    String productId,
    bool isFavorite,
  ) {
    final favKey = 'customer:favorites:$userId';
    final existing = _cache.getAny<Set<String>>(favKey);
    if (existing != null) {
      final next = Set<String>.from(existing);
      if (isFavorite) {
        next.add(productId);
      } else {
        next.remove(productId);
      }
      _cache.set<Set<String>>(favKey, next, ttl: _favoritesTtl);
    }
    _cache.invalidate('customer:product:$productId');
    _cache.invalidatePrefix('customer:feed:');
  }

  Future<bool> toggleFavorite(String productId) async {
    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    // Always update local state & memory cache immediately
    final nextLocalFavorite = await _localDb.toggleFavoriteLocal(
      customerId: userId,
      productId: productId,
    );
    _updateCachedFavoriteState(userId, productId, nextLocalFavorite);

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
          _updateCachedFavoriteState(userId, productId, false);
          return false;
        } else {
          await _client.from('favorites').insert({
            'customer_id': userId,
            'product_id': productId,
          });
          _updateCachedFavoriteState(userId, productId, true);
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
            id, shop_id, category_id, name, description, details, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
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

  // Reviews (Memory TTL + in-flight deduplication so Details & Reviews share 1 call)
  Future<List<ProductReview>> getProductReviews(
    String productId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'customer:reviews:$productId';
    if (!forceRefresh) {
      final cached = _cache.getFresh<List<ProductReview>>(cacheKey);
      if (cached != null) return cached;
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        return await _cache.fetchCached<List<ProductReview>>(
          cacheKey,
          ttl: _detailsTtl,
          forceRefresh: forceRefresh,
          loader: () async {
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

            NetworkMonitorService.instance.reportNetworkSuccess();
            unawaited(_localDb.saveProductReviews(productId, reviews));
            return reviews;
          },
        );
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
        _cache.invalidate('customer:reviews:$productId');
        _cache.invalidate('customer:product:$productId');
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
                id, shop_id, name, details, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
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
                id, shop_id, category_id, name, description, details, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
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

  // Active Payment Methods (Banks & Gaza E-Wallets managed by Admin)
  Future<List<PaymentMethod>> getActivePaymentMethods() async {
    await NetworkGuard.ensureOnline();
    final rows = await _client
        .from('payment_methods')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return (rows as List)
        .map((row) => PaymentMethod.fromMap(asStringMap(row)))
        .toList();
  }

  /// Uploads a transfer receipt image to the `payment-receipts` bucket and
  /// returns its public URL.
  Future<String> uploadPaymentReceipt({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('يجب تسجيل الدخول أولاً');
    }
    await NetworkGuard.ensureOnline();

    final compressed = await AppImageCompressor.compressForUpload(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      preset: ImageCompressPreset.receipt,
    );
    final ext = p.extension(compressed.fileName).toLowerCase();
    final safeExt = ext.isEmpty ? '.jpg' : ext;
    final path =
        '$userId/receipt_${DateTime.now().millisecondsSinceEpoch}$safeExt';

    await NetworkGuard.run(
      () => _client.storage.from('payment-receipts').uploadBinary(
            path,
            compressed.bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: compressed.contentType,
            ),
          ),
      timeout: AppTimeouts.upload,
      requireConnection: false,
    );

    return _client.storage.from('payment-receipts').getPublicUrl(path);
  }

  // Orders (Requires online connection to verify active payment method,
  // upload transfer receipt, and calculate authoritative shop delivery fee)
  Future<CustomerOrder> placeOrder({
    required String shopId,
    required List<CartItem> items,
    required String deliveryAddress,
    required String phone,
    String? notes,
    required String deliveryMode,
    required String paymentMethodId,
    required String paymentReceiptUrl,
    String? checkoutGroupId,
    double? groupTotal,
    int groupShopsCount = 1,
  }) async {
    if (items.isEmpty) {
      throw StateError('السلة فارغة');
    }
    if (paymentMethodId.trim().isEmpty) {
      throw StateError('يرجى اختيار وسيلة الدفع');
    }
    if (paymentReceiptUrl.trim().isEmpty) {
      throw StateError('يرجى رفع صورة إشعار الحوالة لإتمام الطلب');
    }

    await NetworkGuard.ensureOnline();

    final payload = items.map((i) => i.toOrderPayload()).toList();
    final trimmedAddress = deliveryAddress.trim();
    final trimmedPhone = phone.trim();
    final trimmedNotes = notes?.trim();

    final result = await _client.rpc(
      'customer_place_order',
      params: {
        'p_shop_id': shopId,
        'p_items': payload,
        'p_delivery_address': trimmedAddress,
        'p_phone': trimmedPhone,
        'p_notes': trimmedNotes,
        'p_delivery_mode': deliveryMode,
        'p_payment_method_id': paymentMethodId,
        'p_payment_receipt_url': paymentReceiptUrl.trim(),
        if (checkoutGroupId != null && checkoutGroupId.trim().isNotEmpty)
          'p_checkout_group_id': checkoutGroupId.trim(),
        if (groupTotal != null && groupTotal > 0) 'p_group_total': groupTotal,
        if (groupShopsCount > 1) 'p_group_shops_count': groupShopsCount,
      },
    );

    final createdOrder = CustomerOrder.fromMap(asStringMap(result));
    await _localDb.saveCustomerOrders([createdOrder]);
    return createdOrder;
  }

  Future<CustomerOrder> resubmitPaymentReceipt({
    required String orderId,
    required String receiptUrl,
    String? paymentMethodId,
  }) async {
    await NetworkGuard.ensureOnline();
    final result = await _client.rpc(
      'customer_resubmit_payment_receipt',
      params: {
        'p_order_id': orderId,
        'p_receipt_url': receiptUrl.trim(),
        if (paymentMethodId != null && paymentMethodId.trim().isNotEmpty)
          'p_payment_method_id': paymentMethodId.trim(),
      },
    );
    final updated = CustomerOrder.fromMap(asStringMap(result));
    await _localDb.saveCustomerOrders([updated]);
    return updated;
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
          shops:shop_id(name, phone, city, address),
          items:order_items(*)
        ''')
            .eq('id', orderId)
            .single();

        final map = asStringMap(row);
        final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
        map['shop_name'] = shopMap?['name'] ?? 'متجر';
        map['shop_phone'] = shopMap?['phone'];
        map['shop_city'] = shopMap?['city'];
        map['shop_address'] = shopMap?['address'];

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

  Future<void> sendOrderInquiry({
    required String orderId,
    required String topic,
    String? message,
    bool escalateAdmin = false,
  }) async {
    await NetworkGuard.ensureOnline();
    await _client.rpc(
      'customer_send_order_inquiry',
      params: {
        'p_order_id': orderId,
        'p_topic': topic.trim(),
        'p_message': (message?.trim().isEmpty ?? true) ? null : message!.trim(),
        'p_escalate_admin': escalateAdmin,
      },
    );
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

  bool _isNetworkError(Object error) => AppErrorMapper.isNetworkError(error);

  String mapError(Object error) => AppErrorMapper.message(error);
}
