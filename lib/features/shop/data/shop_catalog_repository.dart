import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/filtering/filter_models.dart';
import '../../../core/network/network_guard.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/network_monitor_service.dart';
import '../../../core/offline/offline_sync_engine.dart';
import '../../../core/pagination/paginated_state.dart';
import '../../../core/utils/map_utils.dart';
import '../../admin/domain/models/catalog_models.dart';
import '../../admin/domain/models/revenue_models.dart';
import '../domain/models/shop.dart';
import '../domain/models/shop_product.dart';

class ShopCatalogRepository {
  ShopCatalogRepository({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  final LocalDatabase _localDb = LocalDatabase.instance;

  static const _productSelect =
      '*, categories(name), product_variants(*), product_images(*)';

  Future<String?> _resolveUserId() async {
    final uid = _client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) return uid;
    final activeProfile = await _localDb.getActiveSessionProfile();
    return activeProfile?.id;
  }

  Future<String?> _resolveCurrentShopId() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final shopId = await _client.rpc('current_shop_id');
        if (shopId != null) return shopId.toString();
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        }
      }
    }
    final userId = await _resolveUserId();
    if (userId == null) return null;
    final cachedShop = await _localDb.getShopByOwnerId(userId);
    return cachedShop?.id;
  }

  Future<ShopProduct> saveProductForm(Map<String, dynamic> data) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final result = await _client.rpc(
          'shop_save_product_form',
          params: {'p_data': data},
        );
        final product = ShopProduct.fromMap(asStringMap(result));
        await _localDb.saveShopProducts([product]);
        return product;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final userId = await _resolveUserId();
    final shopId = await _resolveCurrentShopId();
    if (userId == null || shopId == null) {
      throw StateError('تعذر حفظ المنتج بدون جلسة محل صالحة');
    }

    final productId =
        (data['id']?.toString().isNotEmpty ?? false)
            ? data['id'].toString()
            : 'offline_prod_${DateTime.now().millisecondsSinceEpoch}';

    final localProduct = ShopProduct(
      id: productId,
      shopId: shopId,
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString(),
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      status: data['status']?.toString() ?? 'draft',
      categoryId: data['category_id']?.toString(),
      details: Map<String, dynamic>.from(data['details'] as Map? ?? {}),
    );
    await _localDb.saveShopProducts([localProduct]);

    await OfflineSyncEngine.instance.enqueue(
      id: 'shop_save_product_$productId',
      userId: userId,
      actionType: 'shop_save_product_form',
      entityId: productId,
      payload: {'data': data},
    );
    return localProduct;
  }

  Future<ShopProduct> setProductOffer({
    required String productId,
    required double discountAmount,
    DateTime? startsAt,
    DateTime? endsAt,
    String? offerTitle,
  }) async {
    final trimmedTitle = offerTitle?.trim();
    final result = await _client.rpc(
      'shop_set_product_offer',
      params: {
        'p_product_id': productId,
        'p_discount_amount': discountAmount,
        'p_offer_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_offer_ends_at': endsAt?.toUtc().toIso8601String(),
        'p_offer_title': (trimmedTitle == null || trimmedTitle.isEmpty)
            ? null
            : trimmedTitle,
      },
    );
    final product = ShopProduct.fromMap(asStringMap(result));
    await _localDb.saveShopProducts([product]);
    return product;
  }

  Future<void> syncExpiredOffersSilently() async {
    if (!NetworkMonitorService.instance.isOnline) return;
    try {
      await _client.rpc('sync_product_offers');
    } catch (_) {
      // Non-critical background sync
    }
  }

  Future<List<AdminBanner>> fetchMyBanners() async {
    final shopId = await _resolveCurrentShopId();
    if (shopId == null) return const [];

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('banners')
            .select()
            .eq('shop_id', shopId)
            .order('is_auto_offer', ascending: false)
            .order('updated_at', ascending: false);
        final banners = (rows as List)
            .map((row) => AdminBanner.fromMap(asStringMap(row)))
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
    return _localDb.getBannersForShop(shopId);
  }

  Future<AdminBanner> upsertBanner({
    required String title,
    String? subtitle,
    String? imagePath,
    bool isActive = true,
    String? ctaLabel,
    String? id,
  }) async {
    final cleanSubtitle = subtitle?.trim();
    final cleanImage = imagePath?.trim();
    final cleanCta = ctaLabel?.trim();
    final result = await _client.rpc(
      'shop_upsert_banner',
      params: {
        'p_title': title.trim(),
        'p_subtitle': (cleanSubtitle == null || cleanSubtitle.isEmpty)
            ? null
            : cleanSubtitle,
        'p_image_path': (cleanImage == null || cleanImage.isEmpty)
            ? null
            : cleanImage,
        'p_is_active': isActive,
        'p_cta_label': (cleanCta == null || cleanCta.isEmpty)
            ? 'تصفح المحل'
            : cleanCta,
        'p_id': id,
      },
    );
    final banner = AdminBanner.fromMap(asStringMap(result));
    unawaited(_localDb.saveBanners([banner]));
    return banner;
  }

  Future<void> deleteBanner(String bannerId) async {
    await _client.rpc('shop_delete_banner', params: {'p_id': bannerId});
    await _localDb.deleteBanner(bannerId);
  }

  Future<ShopFinanceSummary> fetchMyFinanceSummary() async {
    final data = await _client.rpc('shop_my_finance_summary');
    return ShopFinanceSummary.fromMap(asStringMap(data));
  }

  Future<void> acceptCommissionAgreement() async {
    await _client.rpc('shop_accept_commission_agreement');
  }

  Future<ShopSettlement> submitSettlement({
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? receiptUrl,
    String? notes,
  }) async {
    final data = await _client.rpc(
      'shop_submit_settlement',
      params: {
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_reference_number': (referenceNumber?.trim().isEmpty ?? true)
            ? null
            : referenceNumber!.trim(),
        'p_receipt_url': (receiptUrl?.trim().isEmpty ?? true)
            ? null
            : receiptUrl!.trim(),
        'p_notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      },
    );
    return ShopSettlement.fromMap(asStringMap(data));
  }

  Future<ShopStats> fetchStats() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc('shop_dashboard_stats');
        return ShopStats.fromMap(asStringMap(data));
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }

    final shopId = await _resolveCurrentShopId();
    if (shopId == null) {
      return const ShopStats(
        products: 0,
        publishedProducts: 0,
        orders: 0,
        pendingOrders: 0,
        salesTotal: 0,
        stockUnits: 0,
      );
    }
    return _localDb.computeShopStats(shopId);
  }

  Future<List<CatalogCategory>> fetchActiveCategories() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('categories')
            .select()
            .eq('is_active', true)
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
    return _localDb.getCategories(activeOnly: true);
  }

  Future<PaginatedPage<ShopProduct>> fetchMyProductsPage({
    int limit = kProductPageSize,
    int offset = 0,
    String? status,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String? search,
    ProductSortOption sort = ProductSortOption.newest,
  }) async {
    final shopId = await _resolveCurrentShopId();
    if (shopId == null) {
      return const PaginatedPage<ShopProduct>(items: [], rawCount: 0);
    }

    if (NetworkMonitorService.instance.isOnline) {
      try {
        var query = _client
            .from('products')
            .select(_productSelect)
            .eq('shop_id', shopId)
            .neq('status', 'deleted');

        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        if (categoryId != null && categoryId.isNotEmpty) {
          query = query.eq('category_id', categoryId);
        }
        if (minPrice != null) {
          query = query.gte('price', minPrice);
        }
        if (maxPrice != null) {
          query = query.lte('price', maxPrice);
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

        final hasSearch = search != null && search.trim().isNotEmpty;
        if (hasSearch && offset > 0) {
          return const PaginatedPage<ShopProduct>(items: [], rawCount: 0);
        }

        final effectiveLimit = hasSearch ? kSearchPoolSize : limit;
        final from = offset < 0 ? 0 : offset;
        final to = from + effectiveLimit - 1;
        final rawRows = await orderedQuery.range(from, to) as List;

        final allFetched = rawRows
            .map(
              (row) =>
                  ShopProduct.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        if (allFetched.any(
          (p) =>
              p.isOfferExpired ||
              (p.hasOffer &&
                  p.originalPrice != null &&
                  p.price >= p.originalPrice!),
        )) {
          unawaited(syncExpiredOffersSilently());
        }
        unawaited(_localDb.saveShopProducts(allFetched));

        final items = hasSearch
            ? filterShopProducts(
                allFetched,
                ShopProductFilterState(
                  search: search,
                  status: status,
                  categoryId: categoryId,
                  minPrice: minPrice,
                  maxPrice: maxPrice,
                  sort: sort,
                ),
              )
            : allFetched;

        if (items.isEmpty && offset == 0 && allFetched.isNotEmpty) {
          return PaginatedPage<ShopProduct>(
            items: allFetched.take(limit).toList(),
            rawCount: 0,
            isSimilarFallback: true,
          );
        }

        return PaginatedPage<ShopProduct>(
          items: items,
          rawCount: hasSearch ? 0 : rawRows.length,
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }

    return _localDb.getShopProductsPage(
      shopId: shopId,
      limit: limit,
      offset: offset,
      status: status,
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
      search: search,
      sort: sort,
    );
  }

  Future<List<ShopProduct>> fetchMyProducts() async {
    final page = await fetchMyProductsPage(limit: 50);
    return page.items;
  }

  Future<ShopProduct?> fetchProduct(String productId) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client
            .from('products')
            .select(_productSelect)
            .eq('id', productId)
            .maybeSingle();
        if (data == null) return null;
        final product = ShopProduct.fromMap(Map<String, dynamic>.from(data));
        unawaited(_localDb.saveShopProducts([product]));
        return product;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getShopProductById(productId);
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
    await _localDb.updateProductStatusLocal(productId, status);

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc(
          'shop_set_product_status',
          params: {'p_product_id': productId, 'p_status': status},
        );
        final product = ShopProduct.fromMap(asStringMap(data));
        return (await fetchProduct(product.id)) ?? product;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final userId = await _resolveUserId();
    if (userId != null) {
      await OfflineSyncEngine.instance.enqueue(
        id: 'shop_prod_status_$productId',
        userId: userId,
        actionType: 'shop_set_product_status',
        entityId: productId,
        payload: {'product_id': productId, 'status': status},
      );
    }

    final cached = await _localDb.getShopProductById(productId);
    if (cached != null) return cached;
    throw StateError('تعذر العثور على المنتج محلياً');
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
    final shopId = await _resolveCurrentShopId();
    if (shopId == null) return const [];

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('orders')
            .select('*, customer:profiles!customer_id(full_name, email, phone)')
            .eq('shop_id', shopId)
            .order('created_at', ascending: false);

        final orders = (rows as List)
            .map(
              (row) => ShopOrder.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        unawaited(_localDb.saveShopOrders(shopId, orders));
        return orders;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }

    return _localDb.getShopOrders(shopId);
  }

  Future<ShopOrder> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _localDb.updateOrderStatusLocal(orderId, status);

    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client.rpc(
          'shop_update_order_status',
          params: {'p_order_id': orderId, 'p_status': status},
        );
        final updated = ShopOrder.fromMap(asStringMap(data));
        final customerId = updated.customerId;
        if (customerId != null && customerId.isNotEmpty) {
          try {
            final rows = await _client
                .from('notifications')
                .select('id')
                .eq('target_user_id', customerId)
                .eq('sender_role', 'shop')
                .order('created_at', ascending: false)
                .limit(1);
            final list = rows as List;
            if (list.isNotEmpty) {
              final notifId = (list.first as Map)['id'] as String?;
              if (notifId != null && notifId.isNotEmpty) {
                await _client.functions.invoke(
                  'send-push-notification',
                  body: {'notification_id': notifId},
                );
              }
            }
          } catch (_) {}
        }
        return updated;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final userId = await _resolveUserId();
    if (userId != null) {
      await OfflineSyncEngine.instance.enqueue(
        id: 'shop_order_status_$orderId',
        userId: userId,
        actionType: 'shop_update_order_status',
        entityId: orderId,
        payload: {'order_id': orderId, 'status': status},
      );
    }

    final shopId = await _resolveCurrentShopId();
    final orders = shopId != null
        ? await _localDb.getShopOrders(shopId)
        : const <ShopOrder>[];
    return orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => ShopOrder(
        id: orderId,
        status: status,
        total: 0,
        createdAt: DateTime.now(),
      ),
    );
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
    String scope = 'shop_customers',
  }) async {
    final data = await _client.rpc(
      'shop_send_notification',
      params: {
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_scope': scope,
      },
    );
    final created = AdminNotification.fromMap(asStringMap(data));
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {'notification_id': created.id},
      );
    } catch (_) {}
    return created;
  }

  Future<Shop> setMedia({String? logoPath, String? coverPath}) async {
    final data = await _client.rpc(
      'shop_set_media',
      params: {'p_logo_path': logoPath, 'p_cover_path': coverPath},
    );
    final shop = Shop.fromMap(asStringMap(data), forOwner: true);
    await _localDb.saveFullShop(shop);
    return shop;
  }

  Future<ShopMediaItem> addShopImage({
    required String filePath,
    String kind = 'gallery',
  }) async {
    final data = await _client.rpc(
      'shop_add_image',
      params: {'p_file_path': filePath, 'p_kind': kind},
    );
    return ShopMediaItem.fromMap(asStringMap(data));
  }

  Future<ShopMediaItem> addDocument({
    required String docType,
    required String filePath,
  }) async {
    final data = await _client.rpc(
      'shop_add_document',
      params: {'p_doc_type': docType, 'p_file_path': filePath},
    );
    return ShopMediaItem.fromMap(asStringMap(data));
  }

  Future<List<ShopMediaItem>> fetchShopImages() async {
    final shopId = await _resolveCurrentShopId();
    if (shopId == null) return const [];

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

  Future<List<ShopMediaItem>> fetchDocuments() async {
    final shopId = await _resolveCurrentShopId();
    if (shopId == null) return const [];

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
                  ShopMediaItem.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        unawaited(_localDb.saveShopDocuments(shopId, docs));
        return docs;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }
    return _localDb.getShopDocuments(shopId);
  }

  Future<ShopOrder> verifyOrderPayment({
    required String orderId,
    required bool approved,
    String? issueNote,
  }) async {
    await NetworkGuard.ensureOnline();
    final data = await _client.rpc(
      'shop_verify_order_payment',
      params: {
        'p_order_id': orderId,
        'p_approved': approved,
        'p_issue_note': (issueNote?.trim().isEmpty ?? true)
            ? null
            : issueNote!.trim(),
      },
    );
    return ShopOrder.fromMap(asStringMap(data));
  }

  Future<Shop> updateDeliveryFee(double deliveryFee) async {
    await NetworkGuard.ensureOnline();
    final data = await _client.rpc(
      'shop_update_delivery_fee',
      params: {'p_delivery_fee': deliveryFee},
    );
    final shop = Shop.fromMap(asStringMap(data), forOwner: true);
    await _localDb.saveFullShop(shop);
    return shop;
  }

  Future<Shop> updateProfile({
    required String shopName,
    required String description,
    required String city,
    required String address,
    required String commercialRegister,
    required String ownerName,
    required String phone,
    double? deliveryFee,
  }) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
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
            'p_delivery_fee': ?deliveryFee,
          },
        );
        final shop = Shop.fromMap(asStringMap(data), forOwner: true);
        await _localDb.saveFullShop(shop);
        return shop;
      } catch (e) {
        if (!_isNetworkError(e)) rethrow;
        NetworkMonitorService.instance.reportNetworkFailure();
      }
    }

    final userId = await _resolveUserId();
    final existing = userId != null
        ? await _localDb.getShopByOwnerId(userId)
        : null;
    if (userId == null || existing == null) {
      throw StateError('تعذر تحديث بيانات المحل بدون اتصال');
    }

    final updatedShop = Shop(
      id: existing.id,
      ownerId: existing.ownerId,
      name: shopName,
      description: description,
      city: city,
      address: address,
      commercialRegister: commercialRegister,
      logoPath: existing.logoPath,
      coverPath: existing.coverPath,
      status: existing.status,
      visibleStatus: existing.visibleStatus,
      ownerName: ownerName,
      ownerEmail: existing.ownerEmail,
      ownerPhone: phone,
    );
    await _localDb.saveFullShop(updatedShop);

    await OfflineSyncEngine.instance.enqueue(
      id: 'shop_update_profile_${existing.id}',
      userId: userId,
      actionType: 'shop_update_profile',
      entityId: existing.id,
      payload: {
        'shop_name': shopName,
        'description': description,
        'city': city,
        'address': address,
        'commercial_register': commercialRegister,
        'owner_name': ownerName,
        'phone': phone,
      },
    );
    return updatedShop;
  }

  bool _isNetworkError(Object error) => AppErrorMapper.isNetworkError(error);

  String mapError(Object error) => AppErrorMapper.message(error);
}
