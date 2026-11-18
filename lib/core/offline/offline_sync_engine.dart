import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../core/utils/map_utils.dart';
import '../../features/customer/domain/models/customer_order.dart';
import 'background_preloader_service.dart';
import 'local_database.dart';
import 'network_monitor_service.dart';

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.isOnline,
    required this.isSyncing,
    required this.pendingCount,
    this.lastSyncedAt,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncedAt;

  SyncStatusSnapshot copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatusSnapshot(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

/// Processes the AES-256-GCM encrypted & HMAC-SHA256 signed `sync_outbox` queue
/// automatically in chronological order (FIFO) as soon as internet connectivity
/// is restored.
class OfflineSyncEngine {
  OfflineSyncEngine._();

  static final OfflineSyncEngine instance = OfflineSyncEngine._();

  final StreamController<SyncStatusSnapshot> _snapshotController =
      StreamController<SyncStatusSnapshot>.broadcast();

  StreamSubscription<bool>? _networkSub;
  bool _initialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;

  SupabaseClient get _client => SupabaseConfig.client;
  LocalDatabase get _db => LocalDatabase.instance;

  Stream<SyncStatusSnapshot> get onSyncStatusChanged =>
      _snapshotController.stream;

  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _db.initialize();
    await NetworkMonitorService.instance.initialize();

    _networkSub = NetworkMonitorService.instance.onStatusChange.listen((
      isOnline,
    ) {
      unawaited(_emitSnapshot());
      if (isOnline) {
        // Immediately flush all offline actions when internet returns
        unawaited(syncPendingActions());
      }
    });

    await _emitSnapshot();

    if (NetworkMonitorService.instance.isOnline) {
      unawaited(syncPendingActions());
    }
  }

  /// Enqueues an encrypted and HMAC-signed offline mutation and immediately
  /// attempts to sync if online.
  Future<void> enqueue({
    required String id,
    required String userId,
    required String actionType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.enqueueSyncAction(
      id: id,
      userId: userId,
      actionType: actionType,
      entityId: entityId,
      payload: payload,
    );
    await _emitSnapshot();

    if (NetworkMonitorService.instance.isOnline) {
      unawaited(syncPendingActions());
    }
  }

  /// Flushes all pending actions in `sync_outbox` in strict FIFO order.
  Future<int> syncPendingActions() async {
    if (_isSyncing) return 0;
    final online = await NetworkMonitorService.instance.checkNow();
    if (!online) {
      await _emitSnapshot();
      return 0;
    }

    // Must have an active authenticated session on Supabase to push user mutations
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      await _emitSnapshot();
      return 0;
    }

    _isSyncing = true;
    await _emitSnapshot();

    var syncedCount = 0;
    try {
      final actions = await _db.getPendingSyncActions(userId: currentUserId);
      if (actions.isEmpty) {
        // Even if no pending mutations exist, trigger a silent background preload
        unawaited(BackgroundPreloaderService.instance.preloadAllSilently());
        return 0;
      }

      debugPrint(
        '[OfflineSyncEngine] Syncing ${actions.length} offline action(s) to Supabase...',
      );

      for (final record in actions) {
        if (!NetworkMonitorService.instance.isOnline) break;

        await _db.markSyncActionSyncing(record.id);
        try {
          await _executeRemoteAction(record);
          await _db.deleteSyncAction(record.id);
          syncedCount++;
          await _emitSnapshot();
        } catch (error) {
          final isNetErr = _isNetworkException(error);
          await _db.markSyncActionFailed(record.id, error.toString());
          if (isNetErr) {
            NetworkMonitorService.instance.reportNetworkFailure();
            break;
          }
          // If it's a permanent validation error after 5 retries, drop it so it doesn't block forever
          if (record.retryCount >= 5) {
            debugPrint(
              '[OfflineSyncEngine] Dropping permanently failing action ${record.id}: $error',
            );
            await _db.deleteSyncAction(record.id);
          }
        }
      }

      if (syncedCount > 0) {
        _lastSyncedAt = DateTime.now();
        // Refresh local cache from Supabase after syncing all offline mutations
        unawaited(
          BackgroundPreloaderService.instance.preloadAllSilently(force: true),
        );
      }
      return syncedCount;
    } finally {
      _isSyncing = false;
      await _emitSnapshot();
    }
  }

  Future<void> _executeRemoteAction(SyncOutboxRecord record) async {
    final p = record.payload;
    final userId = record.userId;

    switch (record.actionType) {
      case 'place_order':
        final shopId = p['shop_id']?.toString() ?? '';
        final itemsPayload = p['items'] as List? ?? const [];
        final address = p['delivery_address']?.toString() ?? '';
        final phone = p['phone']?.toString() ?? '';
        final notes = p['notes']?.toString();
        final tempOrderId = p['temp_order_id']?.toString() ?? record.entityId;

        dynamic result;
        try {
          result = await _client.rpc(
            'customer_place_order',
            params: {
              'p_shop_id': shopId,
              'p_items': itemsPayload,
              'p_delivery_address': address,
              'p_phone': phone,
              'p_notes': notes,
            },
          );
        } on PostgrestException catch (e) {
          if (e.message.contains('p_notes') || e.code == 'PGRST202') {
            result = await _client.rpc(
              'customer_place_order',
              params: {
                'p_shop_id': shopId,
                'p_items': itemsPayload,
                'p_delivery_address': address,
                'p_phone': phone,
              },
            );
          } else {
            rethrow;
          }
        }

        final officialOrder = CustomerOrder.fromMap(asStringMap(result));
        await _db.replaceTemporaryOrder(tempOrderId, officialOrder);

      case 'cart_upsert':
        final variantId = p['variant_id']?.toString();
        await _client.from('cart_items').upsert({
          'customer_id': userId,
          'product_id': p['product_id'],
          'variant_id': (variantId == null || variantId.isEmpty)
              ? null
              : variantId,
          'color': p['color'],
          'size': p['size'],
          'quantity': p['quantity'],
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'customer_id,product_id,color,size');

      case 'cart_remove':
        await _client
            .from('cart_items')
            .delete()
            .eq('customer_id', userId)
            .eq('product_id', p['product_id'] as Object)
            .eq('color', p['color'] as Object)
            .eq('size', p['size'] as Object);

      case 'cart_clear':
        await _client.from('cart_items').delete().eq('customer_id', userId);

      case 'favorite_set':
        final productId = p['product_id']?.toString() ?? '';
        final isFavorite = p['is_favorite'] == true;
        if (isFavorite) {
          final existing = await _client
              .from('favorites')
              .select('id')
              .eq('customer_id', userId)
              .eq('product_id', productId)
              .maybeSingle();
          if (existing == null) {
            await _client.from('favorites').insert({
              'customer_id': userId,
              'product_id': productId,
            });
          }
        } else {
          await _client
              .from('favorites')
              .delete()
              .eq('customer_id', userId)
              .eq('product_id', productId);
        }

      case 'comparison_add':
        await _client.from('comparison_items').upsert({
          'customer_id': userId,
          'product_id': p['product_id'],
        }, onConflict: 'customer_id,product_id');

      case 'comparison_remove':
        await _client
            .from('comparison_items')
            .delete()
            .eq('customer_id', userId)
            .eq('product_id', p['product_id'] as Object);

      case 'comparison_clear':
        await _client
            .from('comparison_items')
            .delete()
            .eq('customer_id', userId);

      case 'add_review':
        await _client.from('product_reviews').upsert({
          'customer_id': userId,
          'product_id': p['product_id'],
          'rating': p['rating'],
          'comment': p['comment'],
          'created_at':
              p['created_at'] ?? DateTime.now().toIso8601String(),
        }, onConflict: 'customer_id,product_id');

      case 'complete_customer_profile':
        await _client.rpc(
          'complete_customer_profile',
          params: {
            'p_full_name': p['full_name'],
            'p_phone': p['phone'],
            'p_city': p['city'],
            'p_address': p['address'],
          },
        );

      case 'update_customer_profile':
        await _client
            .from('profiles')
            .update({
              'full_name': p['full_name'],
              'phone': p['phone'],
              'city': p['city'],
              'address': p['address'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

      case 'shop_update_order_status':
        await _client.rpc(
          'shop_update_order_status',
          params: {
            'p_order_id': p['order_id'],
            'p_status': p['status'],
          },
        );

      case 'shop_set_product_status':
        await _client.rpc(
          'shop_set_product_status',
          params: {
            'p_product_id': p['product_id'],
            'p_status': p['status'],
          },
        );

      case 'shop_save_product_form':
        await _client.rpc(
          'shop_save_product_form',
          params: {'p_data': p['data']},
        );

      case 'shop_update_profile':
        await _client.rpc(
          'shop_update_profile',
          params: {
            'p_shop_name': p['shop_name'],
            'p_description': p['description'],
            'p_city': p['city'],
            'p_address': p['address'],
            'p_commercial_register': p['commercial_register'],
            'p_owner_name': p['owner_name'],
            'p_phone': p['phone'],
          },
        );

      case 'admin_set_user_active':
        await _client.rpc(
          'admin_set_user_active',
          params: {
            'p_user_id': p['user_id'],
            'p_is_active': p['is_active'],
          },
        );

      case 'admin_set_shop_suspended':
        await _client.rpc(
          'admin_set_shop_suspended',
          params: {
            'p_shop_id': p['shop_id'],
            'p_suspend': p['suspend'],
          },
        );

      case 'admin_set_product_status':
        await _client.rpc(
          'admin_set_product_status',
          params: {
            'p_product_id': p['product_id'],
            'p_status': p['status'],
          },
        );

      case 'admin_update_setting':
        await _client.rpc(
          'admin_update_setting',
          params: {
            'p_key': p['key'],
            'p_value': p['value'],
          },
        );
    }
  }

  bool _isNetworkException(Object error) {
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

  Future<void> _emitSnapshot() async {
    if (_snapshotController.isClosed) return;
    final uid = _client.auth.currentUser?.id;
    final pendingCount = await _db.getPendingSyncCount(userId: uid);
    _snapshotController.add(
      SyncStatusSnapshot(
        isOnline: NetworkMonitorService.instance.isOnline,
        isSyncing: _isSyncing,
        pendingCount: pendingCount,
        lastSyncedAt: _lastSyncedAt,
      ),
    );
  }

  void dispose() {
    _networkSub?.cancel();
  }
}
