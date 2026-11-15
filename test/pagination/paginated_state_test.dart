import 'dart:async';

import 'package:fashion_marketplace/core/pagination/paginated_state.dart';
import 'package:fashion_marketplace/core/theme/app_design.dart';
import 'package:fashion_marketplace/core/widgets/app_pagination_footer.dart';
import 'package:fashion_marketplace/core/widgets/product_grid_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestItem {
  const _TestItem(this.id, this.label, {this.flagged = false});

  final String id;
  final String label;
  final bool flagged;
}

void main() {
  group('PaginatedListNotifier', () {
    test('uses default pageSize of 6 products per request', () {
      expect(kProductPageSize, 6);
    });

    test('loads 6 items initially and paginates offsets sequentially', () async {
      final calls = <(int offset, int limit)>[];
      final notifier = PaginatedListNotifier<_TestItem>(
        autoLoad: false,
        itemId: (e) => e.id,
        fetcher: (offset, limit) async {
          calls.add((offset, limit));
          if (offset == 0) {
            return PaginatedPage(
              items: List.generate(6, (i) => _TestItem('p$i', 'Item $i')),
            );
          }
          if (offset == 6) {
            return PaginatedPage(
              items: List.generate(3, (i) => _TestItem('p${6 + i}', 'Item $i')),
            );
          }
          return const PaginatedPage(items: []);
        },
      );

      await notifier.loadInitial();
      expect(calls, [(0, 6)]);
      expect(notifier.state.items.length, 6);
      expect(notifier.state.hasMore, isTrue);
      expect(notifier.state.fetchedCount, 6);
      expect(notifier.state.isInitialLoading, isFalse);

      await notifier.loadMore();
      expect(calls, [(0, 6), (6, 6)]);
      expect(notifier.state.items.length, 9);
      expect(notifier.state.hasMore, isFalse);
      expect(notifier.state.fetchedCount, 9);

      // Should not request again when hasMore is false.
      await notifier.loadMore();
      expect(calls.length, 2);

      notifier.dispose();
    });

    test(
      'tracks offset using rawCount when client-side facets refine items',
      () async {
        final calls = <(int offset, int limit)>[];
        final notifier = PaginatedListNotifier<_TestItem>(
          autoLoad: false,
          itemId: (e) => e.id,
          fetcher: (offset, limit) async {
            calls.add((offset, limit));
            if (offset == 0) {
              return const PaginatedPage(
                items: [_TestItem('p1', 'Match 1'), _TestItem('p4', 'Match 4')],
                rawCount: 6,
              );
            }
            return const PaginatedPage(
              items: [_TestItem('p7', 'Match 7')],
              rawCount: 2,
            );
          },
        );

        await notifier.loadInitial();
        expect(notifier.state.items.map((e) => e.id), ['p1', 'p4']);
        expect(notifier.state.fetchedCount, 6);
        expect(notifier.state.hasMore, isTrue);

        await notifier.loadMore();
        expect(calls, [(0, 6), (6, 6)]);
        expect(notifier.state.items.map((e) => e.id), ['p1', 'p4', 'p7']);
        expect(notifier.state.fetchedCount, 8);
        expect(notifier.state.hasMore, isFalse);

        notifier.dispose();
      },
    );

    test('deduplicates items across pages and ignores concurrent loadMore', () async {
      var fetchCount = 0;
      final page2Completer = Completer<PaginatedPage<_TestItem>>();
      final notifier = PaginatedListNotifier<_TestItem>(
        autoLoad: false,
        itemId: (e) => e.id,
        fetcher: (offset, limit) {
          fetchCount++;
          if (offset == 0) {
            return Future.value(
              PaginatedPage(
                items: List.generate(6, (i) => _TestItem('p$i', 'Item $i')),
              ),
            );
          }
          return page2Completer.future;
        },
      );

      await notifier.loadInitial();
      final f1 = notifier.loadMore();
      final f2 = notifier.loadMore();
      expect(fetchCount, 2);

      page2Completer.complete(
        const PaginatedPage(
          items: [
            _TestItem('p5', 'Duplicate'),
            _TestItem('p6', 'New 6'),
          ],
          rawCount: 2,
        ),
      );
      await Future.wait([f1, f2]);
      expect(notifier.state.items.length, 7);
      expect(notifier.state.items.last.id, 'p6');

      notifier.dispose();
    });

    test('preserves loaded items on loadMore failure and allows retry', () async {
      var shouldFail = true;
      final notifier = PaginatedListNotifier<_TestItem>(
        autoLoad: false,
        itemId: (e) => e.id,
        fetcher: (offset, limit) async {
          if (offset == 0) {
            return PaginatedPage(
              items: List.generate(6, (i) => _TestItem('p$i', 'Item $i')),
            );
          }
          if (shouldFail) {
            throw Exception('network glitch');
          }
          return const PaginatedPage(items: [_TestItem('p6', 'Item 6')]);
        },
      );

      await notifier.loadInitial();
      await notifier.loadMore();
      expect(notifier.state.items.length, 6);
      expect(notifier.state.loadMoreError, isNotNull);
      expect(notifier.state.isLoadingMore, isFalse);
      expect(notifier.state.hasMore, isTrue);

      shouldFail = false;
      await notifier.loadMore();
      expect(notifier.state.loadMoreError, isNull);
      expect(notifier.state.items.length, 7);
      expect(notifier.state.hasMore, isFalse);

      notifier.dispose();
    });

    test('discards stale response when resetWithFetcher changes filter', () async {
      final firstFilterCompleter = Completer<PaginatedPage<_TestItem>>();
      final notifier = PaginatedListNotifier<_TestItem>(
        autoLoad: false,
        itemId: (e) => e.id,
        fetcher: (_, _) => firstFilterCompleter.future,
      );

      final staleFuture = notifier.loadInitial();
      await notifier.resetWithFetcher((_, _) async {
        return const PaginatedPage(
          items: [_TestItem('fresh', 'Fresh Filter Result')],
        );
      });

      firstFilterCompleter.complete(
        const PaginatedPage(
          items: [_TestItem('stale', 'Stale Result')],
        ),
      );
      await staleFuture;

      expect(notifier.state.items.map((e) => e.id), ['fresh']);
      notifier.dispose();
    });

    test('supports updateWhere and removeWhere without losing pagination', () async {
      final notifier = PaginatedListNotifier<_TestItem>(
        autoLoad: false,
        itemId: (e) => e.id,
        fetcher: (offset, limit) async {
          return PaginatedPage(
            items: List.generate(6, (i) => _TestItem('p$i', 'Item $i')),
          );
        },
      );

      await notifier.loadInitial();
      notifier.updateWhere(
        (e) => e.id == 'p2',
        (e) => _TestItem(e.id, e.label, flagged: true),
      );
      expect(notifier.state.items[2].flagged, isTrue);

      notifier.removeWhere((e) => e.id == 'p0');
      expect(notifier.state.items.length, 5);
      expect(notifier.state.hasMore, isTrue);

      notifier.dispose();
    });
  });

  group('Scroll threshold & footer widgets', () {
    test('shouldLoadNextPage checks maxScrollExtent and threshold', () {
      expect(
        shouldLoadNextPage(
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 0,
            pixels: 0,
            viewportDimension: 600,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
        ),
        isFalse,
      );
      expect(
        shouldLoadNextPage(
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1000,
            pixels: 600,
            viewportDimension: 600,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
        ),
        isFalse,
      );
      expect(
        shouldLoadNextPage(
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1000,
            pixels: 720,
            viewportDimension: 600,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('AppLoadMoreFooter renders button, skeleton, error, and end states', (
      tester,
    ) async {
      var taps = 0;

      Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.from(colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)),
        home: Scaffold(body: child),
      );

      // 1) Has more -> Load more button
      await tester.pumpWidget(
        wrap(
          AppLoadMoreFooter(
            isLoadingMore: false,
            hasMore: true,
            itemsCount: 6,
            onLoadMore: () => taps++,
          ),
        ),
      );
      expect(find.text('عرض المزيد (6 منتجات)'), findsOneWidget);
      await tester.tap(find.text('عرض المزيد (6 منتجات)'));
      expect(taps, 1);

      // 2) Loading more with grid skeleton
      await tester.pumpWidget(
        wrap(
          AppLoadMoreFooter(
            isLoadingMore: true,
            hasMore: true,
            itemsCount: 6,
            useProductGridSkeleton: true,
            onLoadMore: () {},
          ),
        ),
      );
      expect(find.byType(ProductGridSkeleton), findsOneWidget);

      // 3) Error -> Retry button
      await tester.pumpWidget(
        wrap(
          AppLoadMoreFooter(
            isLoadingMore: false,
            hasMore: true,
            itemsCount: 6,
            loadMoreError: Exception('fail'),
            onLoadMore: () => taps++,
          ),
        ),
      );
      expect(find.text('تعذر تحميل الدفعة التالية'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(taps, 2);

      // 4) End of list
      await tester.pumpWidget(
        wrap(
          AppLoadMoreFooter(
            isLoadingMore: false,
            hasMore: false,
            itemsCount: 9,
            onLoadMore: () {},
          ),
        ),
      );
      expect(find.text('تم عرض جميع النتائج (9)'), findsOneWidget);
    });

    testWidgets('AppPaginationScrollListener invokes onLoadMore near bottom', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPaginationScrollListener(
              hasMore: true,
              isLoadingMore: false,
              onLoadMore: () => calls++,
              child: ListView.builder(
                itemCount: 30,
                itemBuilder: (_, i) => SizedBox(height: 100, child: Text('R$i')),
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pump();
      expect(calls, greaterThan(0));
    });
  });
}
