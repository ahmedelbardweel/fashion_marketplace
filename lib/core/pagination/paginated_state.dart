import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Standard batch size requested per product fetch across all roles.
const int kProductPageSize = 16;

/// Result returned by a single paginated repository request.
class PaginatedPage<T> {
  const PaginatedPage({
    required this.items,
    this.rawCount,
    this.totalCount,
    this.isSimilarFallback = false,
  });

  final List<T> items;

  /// Number of raw rows returned by the backend before client-side refinement.
  /// Defaults to [items.length].
  final int? rawCount;

  /// Optional exact total count reported by the backend.
  final int? totalCount;

  /// True when no exact match was found and [items] contains similar suggestions.
  final bool isSimilarFallback;

  int get effectiveRawCount => rawCount ?? items.length;
}

typedef PageFetcher<T> = Future<PaginatedPage<T>> Function(
  int offset,
  int limit,
);

/// Immutable state for paginated grids and lists.
class PaginatedListState<T> {
  const PaginatedListState({
    this.items = const [],
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.fetchedCount = 0,
    this.totalCount,
    this.initialError,
    this.loadMoreError,
    this.isSimilarFallback = false,
  });

  final List<T> items;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int fetchedCount;
  final int? totalCount;
  final Object? initialError;
  final Object? loadMoreError;

  /// True when no exact match was found and [items] contains similar suggestions.
  final bool isSimilarFallback;

  bool get isEmpty => !isInitialLoading && items.isEmpty && initialError == null;
  bool get hasError => initialError != null;

  PaginatedListState<T> copyWith({
    List<T>? items,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? fetchedCount,
    int? totalCount,
    Object? initialError,
    Object? loadMoreError,
    bool? isSimilarFallback,
    bool clearInitialError = false,
    bool clearLoadMoreError = false,
    bool clearTotalCount = false,
  }) {
    return PaginatedListState<T>(
      items: items ?? this.items,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      fetchedCount: fetchedCount ?? this.fetchedCount,
      totalCount: clearTotalCount ? null : (totalCount ?? this.totalCount),
      initialError:
          clearInitialError ? null : (initialError ?? this.initialError),
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      isSimilarFallback: isSimilarFallback ?? this.isSimilarFallback,
    );
  }
}

/// Race-condition-safe controller that fetches [pageSize] items per request.
/// Supports optional [initialCacheLoader] for instant Stale-While-Revalidate
/// rendering before the network round-trip resolves.
class PaginatedListNotifier<T> extends StateNotifier<PaginatedListState<T>> {
  PaginatedListNotifier({
    required PageFetcher<T> fetcher,
    Future<PaginatedPage<T>?> Function(int limit)? initialCacheLoader,
    this.itemId,
    this.pageSize = kProductPageSize,
    bool autoLoad = true,
  }) : _fetcher = fetcher,
       _initialCacheLoader = initialCacheLoader,
       super(const PaginatedListState()) {
    if (autoLoad) {
      Future.microtask(loadInitial);
    }
  }

  PageFetcher<T> _fetcher;
  Future<PaginatedPage<T>?> Function(int limit)? _initialCacheLoader;
  final String Function(T item)? itemId;
  final int pageSize;

  int _generation = 0;

  /// Replaces the fetcher (e.g. when server-side filter/sort changes) and reloads page 0.
  Future<void> resetWithFetcher(
    PageFetcher<T> nextFetcher, {
    Future<PaginatedPage<T>?> Function(int limit)? nextCacheLoader,
    bool preserveItemsWhileLoading = false,
  }) {
    _fetcher = nextFetcher;
    _initialCacheLoader = nextCacheLoader;
    return loadInitial(preserveItemsWhileLoading: preserveItemsWhileLoading);
  }

  /// Fetches the first batch (`offset = 0`, `limit = pageSize`).
  Future<void> loadInitial({
    bool preserveItemsWhileLoading = false,
    bool skipCacheHydration = false,
  }) async {
    final requestGen = ++_generation;
    var keepExisting = preserveItemsWhileLoading && state.items.isNotEmpty;

    if (!keepExisting && !skipCacheHydration && _initialCacheLoader != null) {
      try {
        final cached = await _initialCacheLoader!(pageSize);
        if (!mounted || requestGen != _generation) return;
        if (cached != null && cached.items.isNotEmpty) {
          final dedupedCached = _dedupeList(cached.items);
          final cachedRawCount = cached.effectiveRawCount;
          state = PaginatedListState<T>(
            items: dedupedCached,
            isInitialLoading: false,
            isLoadingMore: false,
            hasMore: !cached.isSimilarFallback && cachedRawCount >= pageSize,
            fetchedCount: cachedRawCount,
            totalCount: cached.totalCount,
            isSimilarFallback: cached.isSimilarFallback,
          );
          keepExisting = true;
        }
      } catch (_) {
        // Ignore cache hydration failures and continue to live fetcher.
      }
    }

    if (!keepExisting) {
      state = state.copyWith(
        items: const [],
        isInitialLoading: true,
        isLoadingMore: false,
        hasMore: true,
        fetchedCount: 0,
        isSimilarFallback: false,
        clearInitialError: true,
        clearLoadMoreError: true,
        clearTotalCount: true,
      );
    } else if (preserveItemsWhileLoading) {
      state = state.copyWith(
        isInitialLoading: false,
        isLoadingMore: true,
        clearInitialError: true,
        clearLoadMoreError: true,
      );
    }

    try {
      final page = await _fetcher(0, pageSize);
      if (!mounted || requestGen != _generation) return;

      final deduped = _dedupeList(page.items);
      final rawCount = page.effectiveRawCount;

      state = PaginatedListState<T>(
        items: deduped,
        isInitialLoading: false,
        isLoadingMore: false,
        hasMore: !page.isSimilarFallback && rawCount >= pageSize,
        fetchedCount: rawCount,
        totalCount: page.totalCount,
        isSimilarFallback: page.isSimilarFallback,
      );
    } catch (error) {
      if (!mounted || requestGen != _generation) return;
      if (keepExisting) {
        state = state.copyWith(
          isInitialLoading: false,
          isLoadingMore: false,
          loadMoreError: preserveItemsWhileLoading ? error : null,
        );
      } else {
        state = state.copyWith(
          isInitialLoading: false,
          isLoadingMore: false,
          hasMore: false,
          initialError: error,
        );
      }
    }
  }

  /// Pull-to-refresh helper keeping current cards visible until page 0 resolves.
  Future<void> refresh() =>
      loadInitial(preserveItemsWhileLoading: true, skipCacheHydration: true);

  /// Fetches the next batch (`offset = state.fetchedCount`, `limit = pageSize`).
  Future<void> loadMore() async {
    if (state.isInitialLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.isSimilarFallback) {
      return;
    }

    final requestGen = _generation;
    final offset = state.fetchedCount;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final page = await _fetcher(offset, pageSize);
      if (!mounted || requestGen != _generation) return;

      final merged = _mergeUnique(state.items, page.items);
      final rawCount = page.effectiveRawCount;
      final nextOffset = offset + rawCount;
      final nextHasMore = rawCount >= pageSize && rawCount > 0;

      state = state.copyWith(
        items: merged,
        isLoadingMore: false,
        hasMore: nextHasMore,
        fetchedCount: nextOffset,
        totalCount: page.totalCount ?? state.totalCount,
      );
    } catch (error) {
      if (!mounted || requestGen != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: error,
      );
    }
  }

  /// Applies an in-memory update across loaded items (e.g. optimistic favorite toggle).
  void updateWhere(
    bool Function(T item) predicate,
    T Function(T item) transform,
  ) {
    if (state.items.isEmpty) return;
    var changed = false;
    final updated = state.items.map((item) {
      if (!predicate(item)) return item;
      changed = true;
      return transform(item);
    }).toList();
    if (changed) {
      state = state.copyWith(items: updated);
    }
  }

  /// Removes matching loaded items optimistically (e.g. removing a favorite).
  void removeWhere(bool Function(T item) predicate) {
    if (state.items.isEmpty) return;
    final next = state.items.where((item) => !predicate(item)).toList();
    if (next.length != state.items.length) {
      final removedCount = state.items.length - next.length;
      final nextFetched = (state.fetchedCount - removedCount).clamp(
        0,
        state.fetchedCount,
      );
      state = state.copyWith(items: next, fetchedCount: nextFetched);
    }
  }

  List<T> _dedupeList(List<T> source) {
    final idFn = itemId;
    if (idFn == null) return List<T>.from(source);
    final seen = <String>{};
    final result = <T>[];
    for (final item in source) {
      if (seen.add(idFn(item))) {
        result.add(item);
      }
    }
    return result;
  }

  List<T> _mergeUnique(List<T> current, List<T> incoming) {
    final idFn = itemId;
    if (idFn == null) return [...current, ...incoming];
    final seen = current.map(idFn).toSet();
    final result = List<T>.from(current);
    for (final item in incoming) {
      if (seen.add(idFn(item))) {
        result.add(item);
      }
    }
    return result;
  }
}
