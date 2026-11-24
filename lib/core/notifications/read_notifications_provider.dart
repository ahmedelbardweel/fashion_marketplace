import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/domain/models/catalog_models.dart';
import '../offline/network_monitor_service.dart';
import '../theme/app_theme.dart';

/// Persists locally read notification IDs and syncs them with Supabase
/// (`public.notification_reads`) so unread badges stay consistent across
/// sessions and devices.
class ReadNotificationsNotifier extends StateNotifier<Set<String>> {
  ReadNotificationsNotifier() : super(AppPreferences.getReadNotificationIds()) {
    unawaited(_syncFromDisk());
  }

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<void> _syncFromDisk() async {
    await AppPreferences.init();
    if (!mounted) return;
    final persisted = AppPreferences.getReadNotificationIds();
    if (persisted.isNotEmpty) {
      state = {...state, ...persisted};
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Pulls read notification IDs from Supabase and merges them with local state.
  Future<void> syncWithServer() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;
    if (!NetworkMonitorService.instance.isOnline) return;
    try {
      final raw = await client
          .rpc('get_my_read_notification_ids')
          .timeout(const Duration(seconds: 6));
      if (!mounted || raw is! List) return;
      final serverIds = raw
          .map((e) => e?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      if (serverIds.isEmpty) return;
      final merged = {...state, ...serverIds};
      if (merged.length != state.length) {
        state = merged;
        unawaited(AppPreferences.setReadNotificationIds(merged));
      }
    } catch (_) {
      // Graceful fallback when offline or before migration 038 is applied.
    }
  }

  Future<void> _pushReadIdsToServer(Iterable<String> ids) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;
    if (!NetworkMonitorService.instance.isOnline) return;
    final validUuids = ids.where((id) => _uuidRe.hasMatch(id)).toList();
    if (validUuids.isEmpty) return;
    try {
      await client
          .rpc('mark_notifications_read', params: {'p_ids': validUuids})
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Best-effort server sync; local state already persisted.
    }
  }

  void markRead(String id) {
    if (id.isEmpty || state.contains(id)) return;
    final next = {...state, id};
    state = next;
    unawaited(AppPreferences.setReadNotificationIds(next));
    unawaited(_pushReadIdsToServer([id]));
  }

  void markAllRead(Iterable<String> ids) {
    final additions = ids
        .where((id) => id.isNotEmpty && !state.contains(id))
        .toList();
    if (additions.isEmpty) return;
    final next = {...state, ...additions};
    state = next;
    unawaited(AppPreferences.setReadNotificationIds(next));
    unawaited(_pushReadIdsToServer(additions));
  }
}

final readNotificationIdsProvider =
    StateNotifierProvider<ReadNotificationsNotifier, Set<String>>(
      (ref) => ReadNotificationsNotifier(),
    );

/// Counts how many loaded notifications have not yet been marked read.
int countUnreadNotifications(
  List<AdminNotification>? notifications,
  Set<String> readIds,
) {
  if (notifications == null || notifications.isEmpty) return 0;
  var unread = 0;
  for (final item in notifications) {
    if (!readIds.contains(item.id)) unread++;
  }
  return unread;
}

/// Captures newly unread IDs for highlighting during the current screen visit
/// and schedules marking them read after the frame renders.
void markVisibleNotificationsRead({
  required WidgetRef ref,
  required List<AdminNotification> notifications,
  required Set<String> readIds,
  required Set<String> sessionUnreadIds,
  required bool Function() isMounted,
}) {
  final unreadIds = <String>[];
  for (final item in notifications) {
    if (!readIds.contains(item.id)) {
      unreadIds.add(item.id);
    }
  }
  if (unreadIds.isEmpty) return;
  sessionUnreadIds.addAll(unreadIds);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!isMounted()) return;
    ref.read(readNotificationIdsProvider.notifier).markAllRead(unreadIds);
  });
}
