import 'dart:async';

/// Lightweight in-memory TTL + in-flight request deduplication cache.
///
/// Prevents duplicate concurrent Supabase round-trips (request coalescing) and
/// serves recently fetched read-only data (banners, categories, shops, product
/// feeds, favorites, reviews) in 0ms while keeping memory bounded.
class AppMemoryCache {
  AppMemoryCache._();

  static final AppMemoryCache instance = AppMemoryCache._();

  static const int _maxEntries = 180;

  final Map<String, _CacheEntry<dynamic>> _store =
      <String, _CacheEntry<dynamic>>{};
  final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};

  /// Returns a cached value if present and not expired, otherwise `null`.
  T? getFresh<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      return null;
    }
    return entry.value as T;
  }

  /// Returns a cached value even if stale (useful for Stale-While-Revalidate).
  T? getAny<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    return entry.value as T;
  }

  /// Whether a fresh (non-expired) value currently exists for [key].
  bool hasFresh(String key) {
    final entry = _store[key];
    return entry != null && !entry.isExpired;
  }

  /// Stores [value] under [key] with a [ttl] expiration window.
  void set<T>(String key, T value, {required Duration ttl}) {
    if (_store.length >= _maxEntries && !_store.containsKey(key)) {
      _evictOldest();
    }
    _store[key] = _CacheEntry<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
      storedAt: DateTime.now(),
    );
  }

  /// Coalesces concurrent fetches for [key] and caches the resolved value.
  ///
  /// - When [forceRefresh] is false and a fresh cached value exists, returns it
  ///   immediately with zero network I/O.
  /// - When another caller is already fetching [key], shares the exact same
  ///   in-flight [Future] so Supabase only receives 1 request.
  Future<T> fetchCached<T>(
    String key, {
    required Duration ttl,
    required Future<T> Function() loader,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = getFresh<T>(key);
      if (cached != null) return cached;
    }

    final existing = _inFlight[key];
    if (existing != null) {
      return await existing as T;
    }

    final completer = Completer<T>();
    _inFlight[key] = completer.future;

    try {
      final result = await loader();
      set<T>(key, result, ttl: ttl);
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  void invalidate(String key) {
    _store.remove(key);
  }

  void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() {
    _store.clear();
  }

  void _evictOldest() {
    if (_store.isEmpty) return;
    // First remove expired entries.
    final now = DateTime.now();
    _store.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
    if (_store.length < _maxEntries) return;

    String? oldestKey;
    DateTime? oldestTime;
    for (final entry in _store.entries) {
      if (oldestTime == null || entry.value.storedAt.isBefore(oldestTime)) {
        oldestTime = entry.value.storedAt;
        oldestKey = entry.key;
      }
    }
    if (oldestKey != null) {
      _store.remove(oldestKey);
    }
  }
}

class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.expiresAt,
    required this.storedAt,
  });

  final T value;
  final DateTime expiresAt;
  final DateTime storedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
