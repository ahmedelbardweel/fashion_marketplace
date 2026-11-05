import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
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

  Future<AdminStats> fetchStats() async {
    final data = await _client.rpc('admin_dashboard_stats');
    return AdminStats.fromMap(asStringMap(data));
  }

  Future<List<AppUser>> fetchUsers() async {
    final rows = await _client
        .from('profiles')
        .select()
        .neq('role', 'admin')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => AppUser.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<AppUser> setUserActive({
    required String userId,
    required bool isActive,
  }) async {
    final data = await _client.rpc(
      'admin_set_user_active',
      params: {
        'p_user_id': userId,
        'p_is_active': isActive,
      },
    );
    return AppUser.fromMap(asStringMap(data));
  }

  Future<List<Shop>> fetchManagedShops() async {
    final rows = await _client
        .from('shops')
        .select('*, owner:profiles!owner_id(full_name, email, phone)')
        .neq('status', 'draft')
        .order('updated_at', ascending: false);
    return (rows as List)
        .map(
          (row) => Shop.fromMap(
            Map<String, dynamic>.from(row as Map),
            forOwner: false,
          ),
        )
        .toList();
  }

  Future<Shop> setShopSuspended({
    required String shopId,
    required bool suspend,
  }) async {
    final data = await _client.rpc(
      'admin_set_shop_suspended',
      params: {
        'p_shop_id': shopId,
        'p_suspend': suspend,
      },
    );
    return Shop.fromMap(asStringMap(data), forOwner: false);
  }

  Future<List<ShopMediaItem>> fetchShopImages(String shopId) async {
    final rows = await _client
        .from('shop_images')
        .select()
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              ShopMediaItem.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<String> signedDocumentUrl(String path) async {
    final result = await _client.storage
        .from('shop-documents')
        .createSignedUrl(path, 60 * 30);
    return result;
  }

  Future<List<ShopDocument>> fetchShopDocuments(String shopId) async {
    final rows = await _client
        .from('shop_documents')
        .select()
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              ShopDocument.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<CatalogCategory>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .order('sort_order')
        .order('name');
    return (rows as List)
        .map(
          (row) =>
              CatalogCategory.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<CatalogCategory> upsertCategory({
    required String name,
    String? description,
    bool isActive = true,
    String? id,
  }) async {
    final data = await _client.rpc(
      'admin_upsert_category',
      params: {
        'p_name': name.trim(),
        'p_description': description,
        'p_is_active': isActive,
        'p_id': id,
      },
    );
    return CatalogCategory.fromMap(asStringMap(data));
  }

  Future<List<AdminProduct>> fetchProducts() async {
    final rows = await _client
        .from('products')
        .select('*, shops(name), categories(name)')
        .neq('status', 'deleted')
        .order('updated_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              AdminProduct.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<AdminProduct> setProductStatus({
    required String productId,
    required String status,
  }) async {
    final data = await _client.rpc(
      'admin_set_product_status',
      params: {
        'p_product_id': productId,
        'p_status': status,
      },
    );
    return AdminProduct.fromMap(asStringMap(data));
  }

  Future<List<AdminOrder>> fetchOrders() async {
    final rows = await _client
        .from('orders')
        .select('*, shops(name), profiles!customer_id(email)')
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => AdminOrder.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<AdminBanner>> fetchBanners() async {
    final rows = await _client
        .from('banners')
        .select()
        .order('sort_order')
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => AdminBanner.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<AdminBanner> upsertBanner({
    required String title,
    String? subtitle,
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
    return AdminBanner.fromMap(asStringMap(data));
  }

  Future<void> deleteBanner(String id) async {
    await _client.rpc('admin_delete_banner', params: {'p_id': id});
  }

  Future<List<AdminNotification>> fetchNotifications() async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              AdminNotification.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
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
    return AdminNotification.fromMap(asStringMap(data));
  }

  Future<DecartSettingsStatus> fetchDecartStatus() async {
    final data = await _client.rpc('admin_decart_status');
    return DecartSettingsStatus.fromMap(asStringMap(data));
  }

  Future<void> setDecartApiKey(String apiKey) async {
    await _client.rpc('admin_set_decart_api_key', params: {
      'p_api_key': apiKey.trim(),
    });
  }

  Future<List<PlatformSetting>> fetchSettings() async {
    final rows = await _client.from('platform_settings').select().order('key');
    return (rows as List)
        .map(
          (row) =>
              PlatformSetting.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<PlatformSetting> updateSetting({
    required String key,
    required String value,
  }) async {
    final data = await _client.rpc(
      'admin_update_setting',
      params: {
        'p_key': key,
        'p_value': value,
      },
    );
    return PlatformSetting.fromMap(asStringMap(data));
  }

  String mapError(Object error) {
    if (error is PostgrestException) return error.message;
    return 'حدث خطأ. حاول مرة أخرى';
  }
}
