import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/body_measurements.dart';

/// Named body measurement profile belonging to one person on this account.
class SavedBodyProfile {
  const SavedBodyProfile({
    required this.id,
    required this.label,
    required this.measurements,
  });

  final String id;
  final String label;
  final BodyMeasurements measurements;

  SavedBodyProfile copyWith({String? label, BodyMeasurements? measurements}) {
    return SavedBodyProfile(
      id: id,
      label: label ?? this.label,
      measurements: measurements ?? this.measurements,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'data': measurements.customerOnly.toJson(),
  };

  static SavedBodyProfile? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final label = json['label']?.toString().trim() ?? '';
    final data = json['data'];
    if (id.isEmpty || data is! Map<String, dynamic>) return null;
    final measurements = BodyMeasurements.fromJson(data)?.customerOnly;
    if (measurements == null) return null;
    return SavedBodyProfile(
      id: id,
      label: label.isEmpty ? 'شخص' : label,
      measurements: measurements,
    );
  }
}

/// Collection of saved person profiles plus the currently active profile id.
class BodyProfileCollection {
  const BodyProfileCollection({required this.profiles, required this.activeId});

  static const BodyProfileCollection empty = BodyProfileCollection(
    profiles: [],
    activeId: null,
  );

  final List<SavedBodyProfile> profiles;
  final String? activeId;

  SavedBodyProfile? get activeProfile {
    if (profiles.isEmpty) return null;
    if (activeId != null) {
      for (final p in profiles) {
        if (p.id == activeId) return p;
      }
    }
    return profiles.first;
  }
}

/// Account-scoped body measurement storage backed by Supabase (when signed in)
/// with SharedPreferences as an instant local cache & offline fallback.
/// No measurements are ever sent to the third-party try-on rendering service.
class BodyMeasurementStore {
  BodyMeasurementStore(this.profileId);
  final String profileId;

  static const String _remoteTable = 'user_body_measurements';

  String get storageKey =>
      'body_measurements.v1.${Uri.encodeComponent(profileId)}';

  String get profilesStorageKey =>
      'body_measurement_profiles.v1.${Uri.encodeComponent(profileId)}';

  SupabaseClient? _activeSupabaseClient() {
    final trimmed = profileId.trim();
    if (trimmed.isEmpty || trimmed == 'guest') return null;
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null || currentUser.id != trimmed) return null;
      return client;
    } catch (_) {
      return null;
    }
  }

  Future<BodyProfileCollection?> _fetchRemoteProfiles() async {
    final client = _activeSupabaseClient();
    if (client == null) return null;
    try {
      final row = await client
          .from(_remoteTable)
          .select('active_profile_id, profiles')
          .eq('user_id', profileId)
          .maybeSingle();
      if (row == null) return null;
      final rawProfiles = row['profiles'];
      if (rawProfiles is! List) return BodyProfileCollection.empty;
      final parsed = <SavedBodyProfile>[];
      for (final item in rawProfiles) {
        if (item is Map) {
          final profile = SavedBodyProfile.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (profile != null) parsed.add(profile);
        }
      }
      if (parsed.isEmpty) return BodyProfileCollection.empty;
      final rawActive = row['active_profile_id']?.toString();
      final resolvedActive = parsed.any((p) => p.id == rawActive)
          ? rawActive
          : parsed.first.id;
      return BodyProfileCollection(
        profiles: List.unmodifiable(parsed),
        activeId: resolvedActive,
      );
    } catch (_) {
      // Offline or migration 036 not yet applied — fall back to local cache.
      return null;
    }
  }

  Future<void> _pushRemoteProfiles(
    List<SavedBodyProfile> profiles,
    String? activeId,
  ) async {
    final client = _activeSupabaseClient();
    if (client == null) return;
    try {
      await client.from(_remoteTable).upsert({
        'user_id': profileId,
        'active_profile_id': activeId,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {
      // Keep local save resilient if temporarily offline.
    }
  }

  Future<void> _clearRemoteProfiles() async {
    final client = _activeSupabaseClient();
    if (client == null) return;
    try {
      await client.from(_remoteTable).delete().eq('user_id', profileId);
    } catch (_) {
      // Keep local clear resilient if temporarily offline.
    }
  }

  Future<BodyMeasurements?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(storageKey);
    if (value != null) {
      try {
        final json = jsonDecode(value);
        if (json is Map<String, dynamic>) {
          final parsed = BodyMeasurements.fromJson(json)?.customerOnly;
          if (parsed != null) return parsed;
        }
      } on FormatException {
        return null;
      }
    }
    final remote = await _fetchRemoteProfiles();
    final active = remote?.activeProfile;
    if (remote != null && active != null) {
      await _persistLocalAll(
        prefs,
        remote.profiles,
        active.id,
        active.measurements,
      );
      return active.measurements;
    }
    return null;
  }

  Future<void> save(BodyMeasurements value) async {
    if (!value.isValid) throw const FormatException('Invalid measurements');
    final prefs = await SharedPreferences.getInstance();
    final clean = value.customerOnly;
    if (!await prefs.setString(storageKey, jsonEncode(clean.toJson()))) {
      throw StateError('Could not save measurements');
    }

    // Keep multi-profile collection in sync with direct save() calls.
    final current = await _loadLocalProfiles(prefs);
    final list = List<SavedBodyProfile>.from(current.profiles);
    final active = current.activeProfile;
    final nextActiveId = active?.id ?? 'default';
    if (active != null) {
      final idx = list.indexWhere((p) => p.id == active.id);
      if (idx >= 0) list[idx] = active.copyWith(measurements: clean);
    } else {
      list.add(
        SavedBodyProfile(
          id: nextActiveId,
          label: 'قياساتي',
          measurements: clean,
        ),
      );
    }
    await _writeProfiles(prefs, list, nextActiveId);
    await _pushRemoteProfiles(list, nextActiveId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(storageKey)) {
      throw StateError('Could not clear measurements');
    }
    await prefs.remove(profilesStorageKey);
    await _clearRemoteProfiles();
  }

  Future<BodyProfileCollection> _loadLocalProfiles(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(profilesStorageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded['version'] == 1 &&
            decoded['profiles'] is List) {
          final parsed = <SavedBodyProfile>[];
          for (final item in decoded['profiles'] as List) {
            if (item is Map<String, dynamic>) {
              final profile = SavedBodyProfile.fromJson(item);
              if (profile != null) parsed.add(profile);
            }
          }
          if (parsed.isEmpty) return BodyProfileCollection.empty;
          final rawActive = decoded['active_id']?.toString();
          final resolvedActive = parsed.any((p) => p.id == rawActive)
              ? rawActive
              : parsed.first.id;
          return BodyProfileCollection(
            profiles: List.unmodifiable(parsed),
            activeId: resolvedActive,
          );
        }
      } on FormatException {
        // Fall through to legacy single-profile check.
      }
    }

    final legacyValue = prefs.getString(storageKey);
    if (legacyValue == null) return BodyProfileCollection.empty;
    try {
      final decoded = jsonDecode(legacyValue);
      final legacy = decoded is Map<String, dynamic>
          ? BodyMeasurements.fromJson(decoded)?.customerOnly
          : null;
      if (legacy == null) return BodyProfileCollection.empty;
      final migrated = SavedBodyProfile(
        id: 'default',
        label: 'قياساتي',
        measurements: legacy,
      );
      return BodyProfileCollection(profiles: [migrated], activeId: migrated.id);
    } on FormatException {
      return BodyProfileCollection.empty;
    }
  }

  Future<BodyProfileCollection> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final local = await _loadLocalProfiles(prefs);
    final remote = await _fetchRemoteProfiles();

    if (remote != null && remote.profiles.isNotEmpty) {
      final active = remote.activeProfile!;
      await _persistLocalAll(
        prefs,
        remote.profiles,
        active.id,
        active.measurements,
      );
      return remote;
    }

    // Backfill existing local profiles up to Supabase on first sync.
    if (local.profiles.isNotEmpty && remote == null) {
      await _pushRemoteProfiles(local.profiles, local.activeId);
    }
    return local;
  }

  Future<BodyProfileCollection> upsertProfile({
    String? id,
    required String label,
    required BodyMeasurements measurements,
  }) async {
    if (!measurements.isValid) {
      throw const FormatException('Invalid measurements');
    }
    final clean = measurements.customerOnly;
    final prefs = await SharedPreferences.getInstance();
    final current = await _loadLocalProfiles(prefs);
    final list = List<SavedBodyProfile>.from(current.profiles);

    final trimmedLabel = label.trim();
    final effectiveLabel = trimmedLabel.isNotEmpty
        ? trimmedLabel
        : 'شخص ${list.length + 1}';

    String targetId;
    final existingIdx = id == null ? -1 : list.indexWhere((p) => p.id == id);
    if (existingIdx >= 0) {
      targetId = list[existingIdx].id;
      list[existingIdx] = SavedBodyProfile(
        id: targetId,
        label: trimmedLabel.isNotEmpty ? trimmedLabel : list[existingIdx].label,
        measurements: clean,
      );
    } else {
      targetId =
          'p_${DateTime.now().microsecondsSinceEpoch}_${list.length + 1}';
      list.add(
        SavedBodyProfile(
          id: targetId,
          label: effectiveLabel,
          measurements: clean,
        ),
      );
    }

    await _persistAll(prefs, list, targetId, clean);
    return BodyProfileCollection(
      profiles: List.unmodifiable(list),
      activeId: targetId,
    );
  }

  Future<BodyProfileCollection> selectProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _loadLocalProfiles(prefs);
    final target = current.profiles.where((p) => p.id == id).firstOrNull;
    if (target == null) return current;
    await _persistAll(prefs, current.profiles, target.id, target.measurements);
    return BodyProfileCollection(
      profiles: current.profiles,
      activeId: target.id,
    );
  }

  Future<BodyProfileCollection> deleteProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _loadLocalProfiles(prefs);
    final remaining = current.profiles.where((p) => p.id != id).toList();
    if (remaining.isEmpty) {
      await clear();
      return BodyProfileCollection.empty;
    }
    final nextActive = remaining.any((p) => p.id == current.activeId)
        ? current.activeId!
        : remaining.first.id;
    final activeProfile = remaining.firstWhere((p) => p.id == nextActive);
    await _persistAll(prefs, remaining, nextActive, activeProfile.measurements);
    return BodyProfileCollection(
      profiles: List.unmodifiable(remaining),
      activeId: nextActive,
    );
  }

  Future<void> _persistLocalAll(
    SharedPreferences prefs,
    List<SavedBodyProfile> profiles,
    String activeId,
    BodyMeasurements activeMeasurements,
  ) async {
    if (!await prefs.setString(
      storageKey,
      jsonEncode(activeMeasurements.customerOnly.toJson()),
    )) {
      throw StateError('Could not save measurements');
    }
    await _writeProfiles(prefs, profiles, activeId);
  }

  Future<void> _persistAll(
    SharedPreferences prefs,
    List<SavedBodyProfile> profiles,
    String activeId,
    BodyMeasurements activeMeasurements,
  ) async {
    await _persistLocalAll(prefs, profiles, activeId, activeMeasurements);
    await _pushRemoteProfiles(profiles, activeId);
  }

  Future<void> _writeProfiles(
    SharedPreferences prefs,
    List<SavedBodyProfile> profiles,
    String activeId,
  ) async {
    final encoded = jsonEncode({
      'version': 1,
      'active_id': activeId,
      'profiles': profiles.map((p) => p.toJson()).toList(),
    });
    if (!await prefs.setString(profilesStorageKey, encoded)) {
      throw StateError('Could not save measurement profiles');
    }
  }
}
