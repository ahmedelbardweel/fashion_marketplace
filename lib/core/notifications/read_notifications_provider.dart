import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../../features/admin/domain/models/catalog_models.dart';

/// Persists locally read notification IDs so app-bar and dashboard badges
/// accurately reflect only unread notifications across sessions.
class ReadNotificationsNotifier extends StateNotifier<Set<String>> {
  ReadNotificationsNotifier() : super(AppPreferences.getReadNotificationIds()) {
    unawaited(_syncFromDisk());
  }

  Future<void> _syncFromDisk() async {
    await AppPreferences.init();
    if (!mounted) return;
    final persisted = AppPreferences.getReadNotificationIds();
    if (persisted.isNotEmpty) {
      state = {...state, ...persisted};
    }
  }

  void markRead(String id) {
    if (id.isEmpty || state.contains(id)) return;
    final next = {...state, id};
    state = next;
    unawaited(AppPreferences.setReadNotificationIds(next));
  }

  void markAllRead(Iterable<String> ids) {
    final additions = ids.where((id) => id.isNotEmpty && !state.contains(id));
    if (additions.isEmpty) return;
    final next = {...state, ...additions};
    state = next;
    unawaited(AppPreferences.setReadNotificationIds(next));
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
