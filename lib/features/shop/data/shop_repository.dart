import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../core/utils/map_utils.dart';
import '../domain/models/shop.dart';

const _shopWithOwner =
    '*, owner:profiles!owner_id(full_name, email, phone)';

class ShopRepository {
  ShopRepository({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<Shop?> fetchMyShop() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('shops')
        .select('*, owner:profiles!owner_id(full_name, email, phone)')
        .eq('owner_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Shop.fromMap(Map<String, dynamic>.from(data), forOwner: true);
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
    final data = await _client.rpc(
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
    );

    return Shop.fromMap(asStringMap(data), forOwner: true);
  }

  Future<Shop> submitApplication() async {
    final data = await _client.rpc('submit_shop_application');
    return Shop.fromMap(asStringMap(data), forOwner: true);
  }

  Future<List<Shop>> fetchAllApplications() async {
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
    return shops;
  }

  Future<Shop?> fetchShopById(String shopId) async {
    final data = await _client
        .from('shops')
        .select(_shopWithOwner)
        .eq('id', shopId)
        .maybeSingle();
    if (data == null) return null;
    return Shop.fromMap(Map<String, dynamic>.from(data), forOwner: false);
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

    return Shop.fromMap(asStringMap(data), forOwner: false);
  }

  String mapError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return 'حدث خطأ. حاول مرة أخرى';
  }
}
