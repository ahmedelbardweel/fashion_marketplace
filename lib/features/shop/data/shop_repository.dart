import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/network/network_guard.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/offline/network_monitor_service.dart';
import '../../../core/utils/map_utils.dart';
import '../domain/models/shop.dart';

const _shopWithOwner =
    '*, owner:profiles!owner_id(full_name, email, phone)';

class ShopRepository {
  ShopRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  final LocalDatabase _localDb = LocalDatabase.instance;

  Future<String?> _resolveUserId() async {
    final uid = _client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) return uid;
    final activeProfile = await _localDb.getActiveSessionProfile();
    return activeProfile?.id;
  }

  Future<Shop?> fetchMyShop() async {
    final userId = await _resolveUserId();
    if (userId == null) return null;

    if (NetworkMonitorService.instance.isOnline) {
      try {
        // Right after registration, the DB trigger creating the draft shop
        // can take a brief moment; retry once if null.
        for (var attempt = 0; attempt < 2; attempt++) {
          final data = await _client
              .from('shops')
              .select('*, owner:profiles!owner_id(full_name, email, phone)')
              .eq('owner_id', userId)
              .maybeSingle();

          if (data != null) {
            final shop = Shop.fromMap(
              Map<String, dynamic>.from(data),
              forOwner: true,
            );
            unawaited(_localDb.saveFullShop(shop));
            return shop;
          }
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
        }
        return null;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }

    return _localDb.getShopByOwnerId(userId);
  }

  Future<Shop> completeShopProfile({
    required String shopName,
    required String description,
    required String city,
    required String address,
    required String commercialRegister,
    required String ownerName,
    required String phone,
  }) async {
    final data = await NetworkGuard.run(
      () => _client.rpc(
        'complete_shop_profile',
        params: {
          'p_shop_name': shopName.trim(),
          'p_description': description.trim(),
          'p_city': city.trim(),
          'p_address': address.trim(),
          'p_commercial_register': commercialRegister.trim(),
          'p_owner_name': ownerName.trim(),
          'p_phone': phone.trim(),
        },
      ),
      timeout: AppTimeouts.action,
    );

    final shop = Shop.fromMap(asStringMap(data), forOwner: true);
    await _localDb.saveFullShop(shop);
    return shop;
  }

  Future<Shop> submitApplication() async {
    final data = await NetworkGuard.run(
      () => _client.rpc('submit_shop_application'),
      timeout: AppTimeouts.action,
    );
    final shop = Shop.fromMap(asStringMap(data), forOwner: true);
    await _localDb.saveFullShop(shop);
    return shop;
  }

  Future<List<Shop>> fetchAllApplications() async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final rows = await _client
            .from('shops')
            .select(_shopWithOwner)
            .neq('status', 'draft')
            .order('submitted_at', ascending: true);

        final shops = (rows as List)
            .map(
              (row) => Shop.fromMap(
                Map<String, dynamic>.from(row as Map),
                forOwner: false,
              ),
            )
            .toList();

        shops.sort((a, b) {
          final pendingCompare = (a.status == ShopStatus.pending ? 0 : 1)
              .compareTo(b.status == ShopStatus.pending ? 0 : 1);
          if (pendingCompare != 0) return pendingCompare;
          return (b.submittedAt ?? DateTime(0))
              .compareTo(a.submittedAt ?? DateTime(0));
        });
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

    final shops = await _localDb.getAllNonDraftShops();
    shops.sort((a, b) {
      final pendingCompare = (a.status == ShopStatus.pending ? 0 : 1)
          .compareTo(b.status == ShopStatus.pending ? 0 : 1);
      if (pendingCompare != 0) return pendingCompare;
      return (b.submittedAt ?? DateTime(0))
          .compareTo(a.submittedAt ?? DateTime(0));
    });
    return shops;
  }

  Future<Shop?> fetchShopById(String shopId) async {
    if (NetworkMonitorService.instance.isOnline) {
      try {
        final data = await _client
            .from('shops')
            .select(_shopWithOwner)
            .eq('id', shopId)
            .maybeSingle();
        if (data == null) return null;
        final shop = Shop.fromMap(
          Map<String, dynamic>.from(data),
          forOwner: false,
        );
        unawaited(_localDb.saveFullShop(shop));
        return shop;
      } catch (e) {
        if (_isNetworkError(e)) {
          NetworkMonitorService.instance.reportNetworkFailure();
        } else {
          rethrow;
        }
      }
    }

    return _localDb.getShopById(shopId, forOwner: false);
  }

  Future<Shop> reviewApplication({
    required String shopId,
    required bool approve,
    String? rejectionReason,
  }) async {
    final data = await _client.rpc(
      'review_shop_application',
      params: {
        'p_shop_id': shopId,
        'p_approve': approve,
        'p_rejection_reason': rejectionReason,
      },
    );

    final shop = Shop.fromMap(asStringMap(data), forOwner: false);
    await _localDb.saveFullShop(shop);
    return shop;
  }

  /// Deactivates/closes the current owner's shop and account.
  Future<void> deleteShopAccount() async {
    final userId = await _resolveUserId();
    if (userId == null) throw StateError('يجب تسجيل الدخول');

    try {
      await _client.rpc('delete_my_shop_account');
    } on PostgrestException catch (error) {
      // Fallback if migration 020 has not been applied yet.
      final msg = error.message.toLowerCase();
      if (!msg.contains('delete_my_shop_account') && error.code != 'PGRST202') {
        rethrow;
      }
      await _client
          .from('profiles')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    }

    await _localDb.clearActiveSession();
  }

  bool _isNetworkError(Object error) => AppErrorMapper.isNetworkError(error);

  String mapError(Object error) => AppErrorMapper.message(error);
}
