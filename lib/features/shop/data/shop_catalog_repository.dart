import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/utils/map_utils.dart';
import '../../admin/domain/models/catalog_models.dart';
import '../domain/models/shop.dart';
import '../domain/models/shop_product.dart';

class ShopCatalogRepository {
  ShopCatalogRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const _productSelect =
      '*, categories(name), product_variants(*), product_images(*)';

  Future<ShopStats> fetchStats() async {
    final data = await _client.rpc('shop_dashboard_stats');
    return ShopStats.fromMap(asStringMap(data));
  }

  Future<List<CatalogCategory>> fetchActiveCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order')
        .order('name');
    return (rows as List)
        .map(
          (row) =>
              CatalogCategory.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<ShopProduct>> fetchMyProducts() async {
    final shopId = await _client.rpc('current_shop_id');
    if (shopId == null) return const [];

    final rows = await _client
        .from('products')
        .select(_productSelect)
        .eq('shop_id', shopId)
        .neq('status', 'deleted')
        .order('updated_at', ascending: false);

    return (rows as List)
        .map(
          (row) => ShopProduct.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<ShopProduct?> fetchProduct(String productId) async {
    final data = await _client
        .from('products')
        .select(_productSelect)
        .eq('id', productId)
        .maybeSingle();
    if (data == null) return null;
    return ShopProduct.fromMap(Map<String, dynamic>.from(data));
  }

  Future<ShopProduct> upsertProduct({
    required String name,
    required String description,
    required double price,
    String? categoryId,
    String status = 'draft',
    String? id,
  }) async {
    final data = await _client.rpc(
      'shop_upsert_product',
      params: {
        'p_name': name,
        'p_description': description,
        'p_price': price,
        'p_category_id': categoryId,
        'p_status': status,
        'p_id': id,
      },
    );
    final product = ShopProduct.fromMap(asStringMap(data));
    return (await fetchProduct(product.id)) ?? product;
  }

  Future<ShopProduct> setProductStatus({
    required String productId,
    required String status,
  }) async {
    final data = await _client.rpc(
      'shop_set_product_status',
      params: {
        'p_product_id': productId,
        'p_status': status,
      },
    );
    final product = ShopProduct.fromMap(asStringMap(data));
    return (await fetchProduct(product.id)) ?? product;
  }

  Future<ProductVariant> upsertVariant({
    required String productId,
    required String color,
    required String size,
    required int stock,
    String? id,
  }) async {
    final data = await _client.rpc(
      'shop_upsert_variant',
      params: {
        'p_product_id': productId,
        'p_color': color,
        'p_size': size,
        'p_stock': stock,
        'p_id': id,
      },
    );
    return ProductVariant.fromMap(asStringMap(data));
  }

  Future<ProductImage> addProductImage({
    required String productId,
    required String filePath,
    String kind = 'gallery',
  }) async {
    final data = await _client.rpc(
      'shop_add_product_image',
      params: {
        'p_product_id': productId,
        'p_file_path': filePath,
        'p_kind': kind,
      },
    );
    return ProductImage.fromMap(asStringMap(data));
  }

  Future<List<ShopOrder>> fetchOrders() async {
    final shopId = await _client.rpc('current_shop_id');
    if (shopId == null) return const [];

    final rows = await _client
        .from('orders')
        .select('*, customer:profiles!customer_id(full_name, email)')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => ShopOrder.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<ShopOrder> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final data = await _client.rpc(
      'shop_update_order_status',
      params: {
        'p_order_id': orderId,
        'p_status': status,
      },
    );
    return ShopOrder.fromMap(asStringMap(data));
  }

  Future<List<AdminNotification>> fetchNotifications() async {
    final userId = _client.auth.currentUser?.id;
    final filter = userId == null
        ? 'audience.eq.all,audience.eq.shop'
        : 'audience.eq.all,audience.eq.shop,target_user_id.eq.$userId';
    final rows = await _client
        .from('notifications')
        .select()
        .or(filter)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              AdminNotification.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<Shop> setMedia({String? logoPath, String? coverPath}) async {
    final data = await _client.rpc(
      'shop_set_media',
      params: {
        'p_logo_path': logoPath,
        'p_cover_path': coverPath,
      },
    );
    return Shop.fromMap(asStringMap(data), forOwner: true);
  }

  Future<ShopMediaItem> addShopImage({
    required String filePath,
    String kind = 'gallery',
  }) async {
    final data = await _client.rpc(
      'shop_add_image',
      params: {
        'p_file_path': filePath,
        'p_kind': kind,
      },
    );
    return ShopMediaItem.fromMap(asStringMap(data));
  }

  Future<ShopMediaItem> addDocument({
    required String docType,
    required String filePath,
  }) async {
    final data = await _client.rpc(
      'shop_add_document',
      params: {
        'p_doc_type': docType,
        'p_file_path': filePath,
      },
    );
    return ShopMediaItem.fromMap(asStringMap(data));
  }

  Future<List<ShopMediaItem>> fetchShopImages() async {
    final shopId = await _client.rpc('current_shop_id');
    if (shopId == null) return const [];
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

  Future<List<ShopMediaItem>> fetchDocuments() async {
    final shopId = await _client.rpc('current_shop_id');
    if (shopId == null) return const [];
    final rows = await _client
        .from('shop_documents')
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

  Future<Shop> updateProfile({
    required String shopName,
    required String description,
    required String city,
    required String address,
    required String commercialRegister,
    required String ownerName,
    required String phone,
  }) async {
    final data = await _client.rpc(
      'shop_update_profile',
      params: {
        'p_shop_name': shopName,
        'p_description': description,
        'p_city': city,
        'p_address': address,
        'p_commercial_register': commercialRegister,
        'p_owner_name': ownerName,
        'p_phone': phone,
      },
    );
    return Shop.fromMap(asStringMap(data), forOwner: true);
  }

  String mapError(Object error) {
    if (error is PostgrestException) return error.message;
    return 'حدث خطأ. حاول مرة أخرى';
  }
}
