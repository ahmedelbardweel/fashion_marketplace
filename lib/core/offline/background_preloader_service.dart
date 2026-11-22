import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../core/utils/map_utils.dart';
import '../../features/admin/domain/models/catalog_models.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/customer/domain/models/cart_item.dart';
import '../../features/customer/domain/models/customer_order.dart';
import '../../features/customer/domain/models/customer_product.dart'
    as customer_models;
import '../../features/customer/domain/models/customer_shop.dart';
import '../../features/shop/domain/models/shop.dart';
import '../../features/shop/domain/models/shop_product.dart' as shop_models;
import 'local_database.dart';
import 'network_monitor_service.dart';

/// Silently downloads and caches the entire application dataset from Supabase
/// into the encrypted local SQLite database in the background without blocking
/// the UI or interrupting the user.
class BackgroundPreloaderService {
  BackgroundPreloaderService._();

  static final BackgroundPreloaderService instance =
      BackgroundPreloaderService._();

  static const int _maxDailyProducts = LocalDatabase.maxOfflineProducts; // 100
  static const String _dailyDateKey = 'offline_products_cache_date_v1';
  static const String _dailyOffsetKey = 'offline_products_cache_offset_v1';

  bool _isRunning = false;
  DateTime? _lastFullPreloadAt;

  SupabaseClient get _client => SupabaseConfig.client;
  LocalDatabase get _db => LocalDatabase.instance;

  /// Triggers a silent background preload of all public and role-specific tables.
  Future<void> preloadAllSilently({
    AppUser? currentUser,
    bool force = false,
  }) async {
    if (_isRunning) return;
    if (!NetworkMonitorService.instance.isOnline) return;

    if (!force &&
        _lastFullPreloadAt != null &&
        DateTime.now().difference(_lastFullPreloadAt!) <
            const Duration(minutes: 2)) {
      return;
    }

    _isRunning = true;
    try {
      await _db.initialize();

      // 1. Preload public catalog tables in parallel batches
      await Future.wait([
        _preloadBanners(),
        _preloadCategories(),
        _preloadApprovedShops(),
      ]);

      // Yield briefly to keep UI frame rate at 60/120fps
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. Preload at most 100 published products, rotating daily (wiping old 100)
      final favoriteIds = await _preloadUserFavorites(currentUser?.id);
      await _syncDailyPublishedProducts(favoriteIds);

      // 3. Preload role-specific tables if authenticated
      final user = currentUser ?? await _preloadCurrentProfile();
      if (user != null) {
        await _db.saveUserProfile(user, isCurrentSession: true);

        switch (user.role) {
          case UserRole.customer:
            await Future.wait([
              _preloadCustomerCart(user.id),
              _preloadCustomerComparison(user.id, favoriteIds),
              _preloadCustomerOrders(user.id),
              _preloadCustomerNotifications(),
            ]);
          case UserRole.shop:
            await _preloadShopOwnerData(user.id);
          case UserRole.admin:
            await _preloadAdminData(user.id);
        }
      }

      _lastFullPreloadAt = DateTime.now();
      unawaited(_db.prefetchAllCachedImageUrls());
      debugPrint(
        '[BackgroundPreloaderService] Silent full database preload completed.',
      );
    } catch (e) {
      debugPrint('[BackgroundPreloaderService] Silent preload warning: $e');
    } finally {
      _isRunning = false;
    }
  }

  Future<AppUser?> _preloadCurrentProfile() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();
      if (row == null) return null;
      return AppUser.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<void> _preloadBanners() async {
    try {
      final rows = await _client
          .from('banners')
          .select()
          .order('sort_order', ascending: true);
      final banners = (rows as List)
          .map((r) => AdminBanner.fromMap(asStringMap(r)))
          .toList();
      await _db.saveBanners(banners);
    } catch (_) {}
  }

  Future<void> _preloadCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select()
          .order('sort_order', ascending: true);
      final categories = (rows as List)
          .map((r) => CatalogCategory.fromMap(asStringMap(r)))
          .toList();
      await _db.saveCategories(categories);
    } catch (_) {}
  }

  Future<void> _preloadApprovedShops() async {
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

      await _db.saveCustomerShops(shops);
    } catch (_) {}
  }

  Future<Set<String>> _preloadUserFavorites(String? userId) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) return const {};
    try {
      final rows = await _client
          .from('favorites')
          .select('product_id')
          .eq('customer_id', uid);
      final ids = (rows as List).map((r) => r['product_id'].toString()).toSet();
      await _db.saveFavoriteIds(uid, ids);
      return ids;
    } catch (_) {
      return const {};
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<List<customer_models.CustomerProduct>> _fetchPublishedProductRange({
    required int start,
    required int count,
    required Set<String> favoriteIds,
  }) async {
    if (count <= 0) return const [];
    final rawRows = await _client
        .from('products')
        .select('''
          id, shop_id, category_id, name, description, details, price, original_price, discount_amount, discount_percent, offer_title, offer_starts_at, offer_ends_at, status,
          shops:shop_id(name),
          categories:category_id(name),
          variants:product_variants(*),
          images:product_images(*)
        ''')
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .range(start, start + count - 1) as List;

    return rawRows.map((row) {
      final map = asStringMap(row);
      final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
      final catMap = row['categories'] is Map
          ? asStringMap(row['categories'])
          : null;

      map['shop_name'] = shopMap?['name'] ?? 'متجر';
      map['category_name'] = catMap?['name'];

      final variantsList = (row['variants'] as List? ?? [])
          .map((v) => customer_models.ProductVariant.fromMap(asStringMap(v)))
          .toList();

      final imagesList = (row['images'] as List? ?? [])
          .map((img) => customer_models.ProductImage.fromMap(asStringMap(img)))
          .toList();

      final pid = map['id']?.toString() ?? '';

      return customer_models.CustomerProduct.fromMap(
        map,
        variants: variantsList,
        images: imagesList,
        isFavorite: favoriteIds.contains(pid),
      );
    }).toList();
  }

  /// Keeps at most 100 published products cached offline. Once per day, deletes
  /// the previous 100 products (and their stale disk images) and downloads the
  /// next rotating batch of 100 products so the app stays fast and lightweight.
  Future<void> _syncDailyPublishedProducts(Set<String> favoriteIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final lastDate = prefs.getString(_dailyDateKey);
      final cachedCount = await _db.getCachedPublishedProductCount();

      // Already rotated today and cache is populated within the 100-item cap.
      if (lastDate == today &&
          cachedCount > 0 &&
          cachedCount <= _maxDailyProducts) {
        return;
      }

      // Compute starting offset for today's rotating 100-product window.
      var startOffset = prefs.getInt(_dailyOffsetKey) ?? 0;
      if (startOffset < 0) startOffset = 0;

      // Download today's 100 products in 2 light chunks of 50 to avoid UI jank.
      const chunkSize = 50;
      final collected = <customer_models.CustomerProduct>[];
      final seenIds = <String>{};

      var fetchedFromOffset = 0;
      for (var fetched = 0; fetched < _maxDailyProducts; fetched += chunkSize) {
        final remaining = _maxDailyProducts - fetched;
        final take = remaining < chunkSize ? remaining : chunkSize;
        final batch = await _fetchPublishedProductRange(
          start: startOffset + fetched,
          count: take,
          favoriteIds: favoriteIds,
        );
        fetchedFromOffset += batch.length;
        for (final item in batch) {
          if (item.id.isNotEmpty && seenIds.add(item.id)) {
            collected.add(item);
          }
        }
        if (batch.length < take) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      // If we hit the end of the catalog while starting at a non-zero offset,
      // wrap around from 0 so the user still gets up to 100 fresh products.
      int nextOffset;
      if (fetchedFromOffset < _maxDailyProducts) {
        if (startOffset > 0 && collected.length < _maxDailyProducts) {
          final needed = _maxDailyProducts - collected.length;
          final wrapped = await _fetchPublishedProductRange(
            start: 0,
            count: needed,
            favoriteIds: favoriteIds,
          );
          for (final item in wrapped) {
            if (collected.length >= _maxDailyProducts) break;
            if (item.id.isNotEmpty && seenIds.add(item.id)) {
              collected.add(item);
            }
          }
          nextOffset = wrapped.length < needed ? 0 : needed;
        } else {
          nextOffset = 0;
        }
      } else {
        nextOffset = startOffset + _maxDailyProducts;
      }

      // Delete yesterday's cached products + stale images and save ONLY today's 100.
      await _db.replaceOfflineCatalogProducts(collected);

      // Preload reviews ONLY for today's cached <= 100 products.
      final productIds = collected.map((p) => p.id).toList();
      if (productIds.isNotEmpty) {
        final rows = await _client
            .from('product_reviews')
            .select('''
              id, product_id, customer_id, rating, comment, created_at,
              profiles:customer_id(full_name)
            ''')
            .inFilter('product_id', productIds)
            .order('created_at', ascending: false)
            .limit(150);

        final byProduct = <String, List<customer_models.ProductReview>>{};
        for (final row in rows as List) {
          final map = asStringMap(row);
          final profile = row['profiles'] is Map
              ? asStringMap(row['profiles'])
              : null;
          map['customer_name'] = profile?['full_name'] ?? 'عميل';
          final review = customer_models.ProductReview.fromMap(map);
          (byProduct[review.productId] ??= []).add(review);
        }

        for (final entry in byProduct.entries) {
          await _db.saveProductReviews(entry.key, entry.value);
        }
      }

      await prefs.setString(_dailyDateKey, today);
      await prefs.setInt(_dailyOffsetKey, nextOffset);
      debugPrint(
        '[BackgroundPreloaderService] Daily offline rotation complete: '
        'cached ${collected.length} products (offset $startOffset -> next $nextOffset).',
      );
    } catch (_) {}
  }

  Future<void> _preloadCustomerCart(String userId) async {
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
            .map((v) => customer_models.ProductVariant.fromMap(asStringMap(v)))
            .toList();
        final images = (pData['images'] as List? ?? [])
            .map((img) => customer_models.ProductImage.fromMap(asStringMap(img)))
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

        final qty = ((r['quantity'] as num?)?.toInt() ?? 1).clamp(1, maxStock);
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
      await _db.saveCartItems(userId, items);
    } catch (_) {}
  }

  Future<void> _preloadCustomerComparison(
    String userId,
    Set<String> favoriteIds,
  ) async {
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

      final list = <customer_models.CustomerProduct>[];
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
            .map((v) => customer_models.ProductVariant.fromMap(asStringMap(v)))
            .toList();
        final images = (pData['images'] as List? ?? [])
            .map((img) => customer_models.ProductImage.fromMap(asStringMap(img)))
            .toList();
        final pid = map['id']?.toString() ?? '';

        list.add(
          customer_models.CustomerProduct.fromMap(
            map,
            variants: variants,
            images: images,
            isFavorite: favoriteIds.contains(pid),
          ),
        );
      }
      await _db.saveComparisonProducts(userId, list);
    } catch (_) {}
  }

  Future<void> _preloadCustomerOrders(String userId) async {
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

      final orders = (rows as List).map((row) {
        final map = asStringMap(row);
        final shopMap = row['shops'] is Map ? asStringMap(row['shops']) : null;
        map['shop_name'] = shopMap?['name'] ?? 'متجر';

        final itemsList = (row['items'] as List? ?? [])
            .map((item) => CustomerOrderItem.fromMap(asStringMap(item)))
            .toList();

        return CustomerOrder.fromMap(map, items: itemsList);
      }).toList();

      await _db.saveCustomerOrders(orders);
    } catch (_) {}
  }

  Future<void> _preloadCustomerNotifications() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .inFilter('audience', ['all', 'customer'])
          .order('created_at', ascending: false);
      final notifications = (rows as List)
          .map((r) => AdminNotification.fromMap(asStringMap(r)))
          .toList();
      await _db.saveNotifications(notifications);
    } catch (_) {}
  }

  Future<void> _preloadShopOwnerData(String userId) async {
    try {
      final shopData = await _client
          .from('shops')
          .select('*, owner:profiles!owner_id(full_name, email, phone)')
          .eq('owner_id', userId)
          .maybeSingle();
      if (shopData == null) return;

      final shop = Shop.fromMap(
        Map<String, dynamic>.from(shopData),
        forOwner: true,
      );
      await _db.saveFullShop(shop);

      // Shop products
      final prodRows = await _client
          .from('products')
          .select('*, categories(name), product_variants(*), product_images(*)')
          .eq('shop_id', shop.id)
          .neq('status', 'deleted')
          .order('updated_at', ascending: false);
      final shopProducts = (prodRows as List)
          .map(
            (r) => shop_models.ShopProduct.fromMap(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
      await _db.saveShopProducts(shopProducts);

      // Shop orders
      final orderRows = await _client
          .from('orders')
          .select('*, customer:profiles!customer_id(full_name, email)')
          .eq('shop_id', shop.id)
          .order('created_at', ascending: false);
      final shopOrders = (orderRows as List)
          .map(
            (r) => shop_models.ShopOrder.fromMap(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
      await _db.saveShopOrders(shop.id, shopOrders);

      // Shop images & documents
      final imgRows = await _client
          .from('shop_images')
          .select()
          .eq('shop_id', shop.id);
      final images = (imgRows as List)
          .map(
            (r) => shop_models.ShopMediaItem.fromMap(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
      await _db.saveShopImages(shop.id, images);

      final docRows = await _client
          .from('shop_documents')
          .select()
          .eq('shop_id', shop.id);
      final docs = (docRows as List)
          .map(
            (r) => shop_models.ShopMediaItem.fromMap(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
      await _db.saveShopDocuments(shop.id, docs);

      // Notifications
      final notifRows = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      final notifs = (notifRows as List)
          .map((r) => AdminNotification.fromMap(asStringMap(r)))
          .toList();
      await _db.saveNotifications(notifs);
    } catch (_) {}
  }

  Future<void> _preloadAdminData(String adminUserId) async {
    try {
      final userRows = await _client
          .from('profiles')
          .select()
          .neq('role', 'admin')
          .order('created_at', ascending: false);
      final users = (userRows as List)
          .map((r) => AppUser.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      await _db.saveUsersList(users, activeUserId: adminUserId);

      final shopRows = await _client
          .from('shops')
          .select('*, owner:profiles!owner_id(full_name, email, phone)')
          .neq('status', 'draft')
          .order('updated_at', ascending: false);
      final shops = (shopRows as List)
          .map(
            (r) => Shop.fromMap(
              Map<String, dynamic>.from(r as Map),
              forOwner: false,
            ),
          )
          .toList();
      await _db.saveFullShops(shops);

      final settingRows = await _client
          .from('platform_settings')
          .select()
          .order('key');
      final settings = (settingRows as List)
          .map(
            (r) => PlatformSetting.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
      await _db.savePlatformSettings(settings);

      final notifRows = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      final notifs = (notifRows as List)
          .map((r) => AdminNotification.fromMap(asStringMap(r)))
          .toList();
      await _db.saveNotifications(notifs);
    } catch (_) {}
  }
}
