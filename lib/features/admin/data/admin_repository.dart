import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/filtering/filter_models.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/network_monitor_service.dart';
import '../../../core/offline/offline_sync_engine.dart';
import '../../../core/pagination/paginated_state.dart';
import '../../../core/utils/map_utils.dart';
import '../../auth/domain/models/app_user.dart';
import '../../shop/domain/models/shop.dart';
import '../../shop/domain/models/shop_product.dart';
import '../domain/models/admin_stats.dart';
import '../domain/models/catalog_models.dart';
import '../domain/models/decart_settings_status.dart';

class AdminRepository {
  AdminRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  final LocalDatabase _localDb = LocalDatabase.instance;

  Future<String?> _resolveUserId() async {
    final uid = _client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) return uid;
    final activeProfile = await _localDb.getActiveSessionProfile();
    return activeProfile?.id;
  }

  Future<AdminStats> fetchStats() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc('admin_dashboard_stats');
        return AdminStats.fromMap(asStringMap(data));
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.computeAdminStats();
  }

  Future<List<AppUser>> fetchUsers() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('profiles')
            .select()
            .neq('role', 'admin')
            .order('created_at', ascending: false);
        final users = (rows as List)
            .map(
              (row) => AppUser.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        final activeId = await _resolveUserId();
        unawaited(_localDb.saveUsersList(users, activeUserId: activeId));
        return users;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getNonAdminUsers();
  }

  Future<AppUser> setUserActive({
    required String userId,
    required bool isActive,
  }) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc(
          'admin_set_user_active',
          params: {'p_user_id': userId, 'p_is_active': isActive},
        );
        final updated = AppUser.fromMap(asStringMap(data));
        await _localDb.saveUserProfile(updated);
        return updated;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final existing = await _localDb.getUserProfile(userId);
    if (existing == null) throw StateError('تعذر العثور على المستخدم محلياً');

    final updated = AppUser(
      id: existing.id,
      email: existing.email,
      role: existing.role,
      isActive: isActive,
      profileCompleted: existing.profileCompleted,
      fullName: existing.fullName,
      phone: existing.phone,
      city: existing.city,
      address: existing.address,
    );
    await _localDb.saveUserProfile(updated);

    final adminId = await _resolveUserId();
    if (adminId != null) {
      await OfflineSyncEngine.instance.enqueue(
        id: 'admin_user_active_$userId',
        userId: adminId,
        actionType: 'admin_set_user_active',
        entityId: userId,
        payload: {'user_id': userId, 'is_active': isActive},
      );
    }
    return updated;
  }

  Future<List<Shop>> fetchManagedShops() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('shops')
            .select('*, owner:profiles!owner_id(full_name, email, phone)')
            .neq('status', 'draft')
            .order('updated_at', ascending: false);
        final shops = (rows as List)
            .map(
              (row) => Shop.fromMap(
                Map<String, dynamic>.from(row as Map),
                forOwner: false,
              ),
            )
            .toList();
        unawaited(_localDb.saveFullShops(shops));
        return shops;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getAllNonDraftShops();
  }

  Future<Shop> setShopSuspended({
    required String shopId,
    required bool suspend,
  }) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc(
          'admin_set_shop_suspended',
          params: {'p_shop_id': shopId, 'p_suspend': suspend},
        );
        final shop = Shop.fromMap(asStringMap(data), forOwner: false);
        await _localDb.saveFullShop(shop);
        return shop;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final existing = await _localDb.getShopById(shopId);
    if (existing == null) throw StateError('تعذر العثور على المحل محلياً');

    final nextStatus = suspend ? ShopStatus.suspended : ShopStatus.approved;
    final updated = Shop(
      id: existing.id,
      ownerId: existing.ownerId,
      name: existing.name,
      description: existing.description,
      city: existing.city,
      address: existing.address,
      commercialRegister: existing.commercialRegister,
      logoPath: existing.logoPath,
      coverPath: existing.coverPath,
      status: nextStatus,
      visibleStatus: nextStatus,
      ownerName: existing.ownerName,
      ownerEmail: existing.ownerEmail,
      ownerPhone: existing.ownerPhone,
    );
    await _localDb.saveFullShop(updated);

    final adminId = await _resolveUserId();
    if (adminId != null) {
      await OfflineSyncEngine.instance.enqueue(
        id: 'admin_shop_suspend_$shopId',
        userId: adminId,
        actionType: 'admin_set_shop_suspended',
        entityId: shopId,
        payload: {'shop_id': shopId, 'suspend': suspend},
      );
    }
    return updated;
  }

  Future<List<ShopMediaItem>> fetchShopImages(String shopId) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('shop_images')
            .select()
            .eq('shop_id', shopId)
            .order('created_at', ascending: false);
        final items = (rows as List)
            .map(
              (row) =>
                  ShopMediaItem.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        unawaited(_localDb.saveShopImages(shopId, items));
        return items;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getShopImages(shopId);
  }

  Future<String> signedDocumentUrl(String path) async {
    final result = await _client.storage
        .from('shop-documents')
        .createSignedUrl(path, 60 * 30);
    return result;
  }

  Future<List<ShopDocument>> fetchShopDocuments(String shopId) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('shop_documents')
            .select()
            .eq('shop_id', shopId)
            .order('created_at', ascending: false);
        final docs = (rows as List)
            .map(
              (row) =>
                  ShopDocument.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        return docs;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    final localDocs = await _localDb.getShopDocuments(shopId);
    return localDocs
        .map(
          (d) => ShopDocument(
            id: d.id,
            docType: d.kind,
            filePath: d.filePath,
          ),
        )
        .toList();
  }

  Future<List<CatalogCategory>> fetchCategories() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('categories')
            .select()
            .order('sort_order')
            .order('name');
        final categories = (rows as List)
            .map(
              (row) => CatalogCategory.fromMap(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        unawaited(_localDb.saveCategories(categories));
        return categories;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getCategories(activeOnly: false);
  }

  Future<CatalogCategory> upsertCategory({
    required String name,
    String? description,
    bool isActive = true,
    String? id,
    String? parentId,
    String? iconKey,
  }) async {
    final data = await _client.rpc(
      'admin_upsert_category_tree',
      params: {
        'p_name': name.trim(),
        'p_description': description,
        'p_is_active': isActive,
        'p_id': id,
        'p_parent_id': parentId,
        'p_icon_key': iconKey,
      },
    );
    final cat = CatalogCategory.fromMap(asStringMap(data));
    await _localDb.saveCategories([cat]);
    return cat;
  }

  Future<PaginatedPage<AdminProduct>> fetchProductsPage({
    int limit = kProductPageSize,
    int offset = 0,
    String? status,
    double? minPrice,
    double? maxPrice,
    String? search,
    ProductSortOption sort = ProductSortOption.newest,
  }) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        var query = _client
            .from('products')
            .select('*, shops(name), categories(name)')
            .neq('status', 'deleted');

        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        if (minPrice != null) {
          query = query.gte('price', minPrice);
        }
        if (maxPrice != null) {
          query = query.lte('price', maxPrice);
        }
        if (search != null && search.trim().isNotEmpty) {
          query = query.ilike('name', '%${search.trim()}%');
        }

        final orderedQuery = switch (sort) {
          ProductSortOption.priceAsc =>
            query
                .order('price', ascending: true)
                .order('updated_at', ascending: false),
          ProductSortOption.priceDesc =>
            query
                .order('price', ascending: false)
                .order('updated_at', ascending: false),
          ProductSortOption.nameAsc =>
            query
                .order('name', ascending: true)
                .order('updated_at', ascending: false),
          _ => query.order('updated_at', ascending: false),
        };

        final from = offset < 0 ? 0 : offset;
        final to = from + limit - 1;
        final rawRows = await orderedQuery.range(from, to) as List;

        final items = rawRows
            .map(
              (row) =>
                  AdminProduct.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();

        return PaginatedPage<AdminProduct>(
          items: items,
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

    return _localDb.getAdminProductsPage(
      limit: limit,
      offset: offset,
      status: status,
      minPrice: minPrice,
      maxPrice: maxPrice,
      search: search,
      sort: sort,
    );
  }

  Future<List<AdminProduct>> fetchProducts() async {
    final page = await fetchProductsPage(limit: 50);
    return page.items;
  }

  Future<AdminProduct> setProductStatus({
    required String productId,
    required String status,
  }) async {
    await _localDb.updateProductStatusLocal(productId, status);

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc(
          'admin_set_product_status',
          params: {'p_product_id': productId, 'p_status': status},
        );
        return AdminProduct.fromMap(asStringMap(data));
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final adminId = await _resolveUserId();
    if (adminId != null) {
      await OfflineSyncEngine.instance.enqueue(
        id: 'admin_prod_status_$productId',
        userId: adminId,
        actionType: 'admin_set_product_status',
        entityId: productId,
        payload: {'product_id': productId, 'status': status},
      );
    }

    return AdminProduct(
      id: productId,
      name: '',
      price: 0,
      status: status,
    );
  }

  Future<List<AdminOrder>> fetchOrders() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('orders')
            .select('*, shops(name), profiles!customer_id(email)')
            .order('created_at', ascending: false);
        return (rows as List)
            .map(
              (row) =>
                  AdminOrder.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getAdminOrders();
  }

  Future<List<AdminBanner>> fetchBanners() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('banners')
            .select()
            .order('sort_order')
            .order('created_at', ascending: false);
        final banners = (rows as List)
            .map(
              (row) =>
                  AdminBanner.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        unawaited(_localDb.saveBanners(banners));
        return banners;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getBanners(activeOnly: false);
  }

  Future<AdminBanner> upsertBanner({
    required String title,
    String? subtitle,
    String? imagePath,
    bool isActive = true,
    String? id,
  }) async {
    final data = await _client.rpc(
      'admin_upsert_banner',
      params: {
        'p_title': title.trim(),
        'p_subtitle': subtitle,
        'p_is_active': isActive,
        'p_id': id,
      },
    );
    var created = AdminBanner.fromMap(asStringMap(data));
    if (imagePath != null) {
      final cleanImage = imagePath.trim();
      final updated = await _client
          .from('banners')
          .update({'image_path': cleanImage.isEmpty ? null : cleanImage})
          .eq('id', created.id)
          .select()
          .maybeSingle();
      if (updated != null) {
        created = AdminBanner.fromMap(Map<String, dynamic>.from(updated));
      }
    }
    await _localDb.saveBanners([created]);
    return created;
  }

  Future<void> deleteBanner(String id) async {
    await _client.rpc('admin_delete_banner', params: {'p_id': id});
    await _localDb.deleteBanner(id);
  }

  Future<List<AdminNotification>> fetchNotifications() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('notifications')
            .select()
            .order('created_at', ascending: false);
        final list = (rows as List)
            .map(
              (row) => AdminNotification.fromMap(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        unawaited(_localDb.saveNotifications(list));
        return list;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getNotifications();
  }

  Future<AdminNotification> sendNotification({
    required String title,
    required String body,
    required String audience,
  }) async {
    final data = await _client.rpc(
      'admin_send_notification',
      params: {
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_audience': audience,
      },
    );
    final created = AdminNotification.fromMap(asStringMap(data));
    await _localDb.saveNotifications([created]);
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {'notification_id': created.id},
      );
    } catch (_) {}
    return created;
  }

  Future<DecartSettingsStatus> fetchDecartStatus() async {
    final data = await _client.rpc('admin_decart_status');
    return DecartSettingsStatus.fromMap(asStringMap(data));
  }

  Future<void> setDecartApiKey(String apiKey) async {
    await _client.rpc(
      'admin_set_decart_api_key',
      params: {'p_api_key': apiKey.trim()},
    );
  }

  Future<List<PlatformSetting>> fetchSettings() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('platform_settings')
            .select()
            .order('key');
        final settings = (rows as List)
            .map(
              (row) => PlatformSetting.fromMap(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        unawaited(_localDb.savePlatformSettings(settings));
        return settings;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getPlatformSettings();
  }

  Future<PlatformSetting> updateSetting({
    required String key,
    required String value,
  }) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc(
          'admin_update_setting',
          params: {'p_key': key, 'p_value': value},
        );
        final setting = PlatformSetting.fromMap(asStringMap(data));
        await _localDb.savePlatformSettings([setting]);
        return setting;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final setting = PlatformSetting(key: key, value: value, label: key);
    await _localDb.savePlatformSettings([setting]);

    final adminId = await _resolveUserId();
    if (adminId != null) {
      await OfflineSyncEngine.instance.enqueue(
        id: 'admin_setting_$key',
        userId: adminId,
        actionType: 'admin_update_setting',
        entityId: key,
        payload: {'key': key, 'value': value},
      );
    }
    return setting;
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
    if (error is PostgrestException) return error.message;
    return 'حدث خطأ. حاول مرة أخرى';
  }
}
