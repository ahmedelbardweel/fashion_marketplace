import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_monitor_service.dart';
import 'offline_sync_engine.dart';

final isOnlineStreamProvider = StreamProvider<bool>((ref) async* {
  yield NetworkMonitorService.instance.isOnline;
  yield* NetworkMonitorService.instance.onStatusChange;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref
      .watch(isOnlineStreamProvider)
      .maybeWhen(
        data: (online) => online,
        orElse: () => NetworkMonitorService.instance.isOnline,
      );
});

final syncStatusProvider = StreamProvider<SyncStatusSnapshot>((ref) async* {
  yield SyncStatusSnapshot(
    isOnline: NetworkMonitorService.instance.isOnline,
    isSyncing: OfflineSyncEngine.instance.isSyncing,
    pendingCount: 0,
  );
  yield* OfflineSyncEngine.instance.onSyncStatusChanged;
});
