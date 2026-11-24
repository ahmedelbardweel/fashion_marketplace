import 'dart:async';

import 'package:fashion_marketplace/core/cache/app_memory_cache.dart';
import 'package:fashion_marketplace/core/pagination/paginated_state.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMemoryCache.instance.clear();
  });

  group('AppMemoryCache', () {
    test('coalesces concurrent in-flight requests into 1 backend call', () async {
      final cache = AppMemoryCache.instance;
      var invocations = 0;
      final gate = Completer<String>();

      Future<String> loader() async {
        invocations++;
        return gate.future;
      }

      final futures = List.generate(
        5,
        (_) => cache.fetchCached<String>(
          'test:coalesce',
          ttl: const Duration(minutes: 5),
          loader: loader,
        ),
      );

      gate.complete('payload');
      final results = await Future.wait(futures);

      expect(invocations, 1);
      expect(results, everyElement('payload'));
      expect(cache.getFresh<String>('test:coalesce'), 'payload');
    });

    test('invalidatePrefix clears matching keys only', () {
      final cache = AppMemoryCache.instance;
      cache.set<String>('customer:feed:p1', 'a', ttl: const Duration(minutes: 5));
      cache.set<String>('customer:feed:p2', 'b', ttl: const Duration(minutes: 5));
      cache.set<String>('customer:banners', 'c', ttl: const Duration(minutes: 5));

      cache.invalidatePrefix('customer:feed:');

      expect(cache.getFresh<String>('customer:feed:p1'), isNull);
      expect(cache.getFresh<String>('customer:feed:p2'), isNull);
      expect(cache.getFresh<String>('customer:banners'), 'c');
    });
  });

  group('CustomerProduct.fromLiteFeedMap', () {
    test('parses lean RPC payload with cover image, stock, colors, and offer', () {
      final product = CustomerProduct.fromLiteFeedMap({
        'id': 'prod-1',
        'shop_id': 'shop-1',
        'shop_name': 'متجر الأناقة',
        'category_id': 'cat-1',
        'category_name': 'قمصان',
        'name': 'قميص كتان صيفي',
        'price': 80,
        'original_price': 100,
        'discount_amount': 20,
        'discount_percent': 20,
        'status': 'published',
        'cover_image': 'https://example.com/cover.webp',
        'total_stock': 14,
        'available_colors': ['أبيض', 'أسود'],
        'available_sizes': ['M', 'L'],
        'rating_avg': 4.8,
        'rating_count': 12,
        'is_favorite': true,
      });

      expect(product.isSummaryOnly, isTrue);
      expect(product.coverImage, 'https://example.com/cover.webp');
      expect(product.totalStock, 14);
      expect(product.availableColors, {'أبيض', 'أسود'});
      expect(product.availableSizes, {'M', 'L'});
      expect(product.hasOffer, isTrue);
      expect(product.effectivePrice, 80);
      expect(product.isFavorite, isTrue);
      expect(product.ratingAvg, 4.8);
      expect(product.ratingCount, 12);
    });
  });

  group('PaginatedListNotifier SWR', () {
    test('default page size is 16 for fewer Supabase round-trips', () {
      expect(kProductPageSize, 16);
    });

    test('renders cached items immediately while revalidating from network', () async {
      final networkGate = Completer<PaginatedPage<String>>();

      final notifier = PaginatedListNotifier<String>(
        autoLoad: false,
        pageSize: 2,
        itemId: (s) => s,
        initialCacheLoader: (_) async => const PaginatedPage<String>(
          items: ['cached-1', 'cached-2'],
          rawCount: 2,
        ),
        fetcher: (_, _) => networkGate.future,
      );

      final loadFuture = notifier.loadInitial();
      // Allow cache loader microtask to finish while network is still pending.
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isInitialLoading, isFalse);
      expect(notifier.state.items, ['cached-1', 'cached-2']);

      networkGate.complete(
        const PaginatedPage<String>(
          items: ['fresh-1', 'fresh-2'],
          rawCount: 2,
        ),
      );
      await loadFuture;

      expect(notifier.state.isInitialLoading, isFalse);
      expect(notifier.state.items, ['fresh-1', 'fresh-2']);
      expect(notifier.state.hasMore, isTrue);
    });
  });
}
