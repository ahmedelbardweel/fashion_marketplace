import 'package:fashion_marketplace/core/filtering/filter_models.dart';
import 'package:fashion_marketplace/core/theme/app_design.dart';
import 'package:fashion_marketplace/core/widgets/app_filter_bar.dart';
import 'package:fashion_marketplace/features/admin/domain/models/catalog_models.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_shop.dart';
import 'package:fashion_marketplace/features/customer/presentation/widgets/product_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppLang.isEn = false;
    AppColors.isDark = false;
  });

  Widget wrapApp(Widget child, {TextDirection direction = TextDirection.rtl}) {
    return MaterialApp(
      theme: ThemeData(
        brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
      ),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
    );
  }

  group('AppFilterToolbar widget tests', () {
    testWidgets('renders RTL Arabic toolbar, handles search, quick chips, removable tags, and clear all', (tester) async {
      AppLang.isEn = false;
      AppColors.isDark = false;

      String search = '';
      var quickTapped = false;
      var removedTag = false;
      var clearedAll = false;
      var openedFilter = false;
      var openedSort = false;

      await tester.pumpWidget(
        wrapApp(
          StatefulBuilder(
            builder: (context, setState) {
              return AppFilterToolbar(
                searchValue: search,
                searchHint: 'ابحث عن منتج...',
                onSearchChanged: (v) => setState(() => search = v),
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'all',
                    label: 'الكل',
                    count: 10,
                    selected: false,
                    onTap: () {},
                  ),
                  AppQuickFilterOption(
                    id: 'instock',
                    label: 'متوفر فقط',
                    count: 6,
                    selected: true,
                    onTap: () => quickTapped = true,
                  ),
                ],
                activeTags: [
                  AppActiveFilterTag(
                    label: 'اللون: أسود',
                    swatchColor: const Color(0xFF18181B),
                    onRemove: () => removedTag = true,
                  ),
                ],
                activeFacetCount: 2,
                sortLabel: 'الأحدث',
                isDefaultSort: true,
                onOpenSort: () => openedSort = true,
                onOpenAdvancedFilter: () => openedFilter = true,
                totalCount: 10,
                filteredCount: 4,
                hasActiveCustomization: true,
                onClearAll: () => clearedAll = true,
              );
            },
          ),
        ),
      );

      expect(find.text('ابحث عن منتج...'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // active facet badge
      expect(find.text('عرض 4 من 10'), findsOneWidget);
      expect(find.text('مسح الكل'), findsOneWidget);
      expect(find.text('اللون: أسود'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'بليزر');
      await tester.pump();
      expect(search, 'بليزر');

      // Tap quick chip, sort pill, filter trigger, tag close icon, clear all
      await tester.tap(find.text('متوفر فقط (6)'));
      await tester.pump();
      expect(quickTapped, isTrue);

      await tester.tap(find.text('الأحدث'));
      await tester.pump();
      expect(openedSort, isTrue);

      await tester.tap(find.byIcon(AppIcons.filter));
      await tester.pump();
      expect(openedFilter, isTrue);

      await tester.tap(find.byIcon(AppIcons.close).last);
      await tester.pump();
      expect(removedTag, isTrue);

      await tester.tap(find.text('مسح الكل'));
      await tester.pump();
      expect(clearedAll, isTrue);

      // Tapping clear search icon clears query
      await tester.tap(find.byTooltip('مسح البحث'));
      await tester.pump();
      expect(search, '');
    });

    testWidgets('translates stats and actions cleanly in English LTR Dark Mode', (tester) async {
      AppLang.isEn = true;
      AppColors.isDark = true;

      await tester.pumpWidget(
        wrapApp(
          AppFilterToolbar(
            searchValue: '',
            onSearchChanged: (_) {},
            sortLabel: 'الأحدث',
            onOpenSort: () {},
            onOpenAdvancedFilter: () {},
            activeFacetCount: 1,
            totalCount: 12,
            filteredCount: 3,
            hasActiveCustomization: true,
            onClearAll: () {},
          ),
          direction: TextDirection.ltr,
        ),
      );

      expect(find.text('Showing 3 of 12'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.text('Newest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Sort & Product Filter Sheets', () {
    testWidgets('showAppSortSheet returns chosen sort option', (tester) async {
      ProductSortOption? chosen;

      await tester.pumpWidget(
        wrapApp(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  chosen = await showAppSortSheet<ProductSortOption>(
                    context: context,
                    current: ProductSortOption.newest,
                    options: kCustomerProductSortChoices,
                  );
                },
                child: const Text('open-sort'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-sort'));
      await tester.pumpAndSettle();

      expect(find.text('ترتيب النتائج'), findsOneWidget);
      expect(find.text('السعر: الأقل أولاً'), findsOneWidget);

      await tester.tap(find.text('السعر: الأقل أولاً'));
      await tester.pumpAndSettle();

      expect(chosen, ProductSortOption.priceAsc);
    });

    testWidgets('showCustomerProductFilterSheet selects color/size/price and clears price on reset', (tester) async {
      ProductFilter? result;

      final sourceProducts = [
        CustomerProduct.fromMap(
          {
            'id': 'p1',
            'shop_id': 's1',
            'shop_name': 'بوتيك النخبة',
            'category_id': 'c1',
            'category_name': 'جاكيتات',
            'name': 'جاكيت',
            'price': 200,
          },
          variants: [
            ProductVariant(
              id: 'v1',
              productId: 'p1',
              size: 'L',
              color: 'كحلي',
              stock: 3,
              isActive: true,
            ),
            ProductVariant(
              id: 'v2',
              productId: 'p1',
              size: 'M',
              color: 'أسود',
              stock: 2,
              isActive: true,
            ),
          ],
        ),
      ];

      final categories = [
        CatalogCategory.fromMap({'id': 'c1', 'name': 'جاكيتات', 'slug': 'jackets'}),
      ];
      final shops = [
        CustomerShop.fromMap({'id': 's1', 'name': 'بوتيك النخبة'}),
      ];

      await tester.pumpWidget(
        wrapApp(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showCustomerProductFilterSheet(
                    context: context,
                    initial: const ProductFilter(
                      search: 'جاكيت',
                      minPrice: 100,
                      maxPrice: 500,
                      color: 'أسود',
                      inStockOnly: true,
                    ),
                    sourceProducts: sourceProducts,
                    categories: categories,
                    shops: shops,
                  );
                },
                child: const Text('open-filter'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-filter'));
      await tester.pumpAndSettle();

      // Header badge shows 3 active facets (price, color, inStockOnly)
      expect(find.text('تصفية المنتجات'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Reset clears minPrice, maxPrice, color, inStockOnly while preserving search
      await tester.tap(find.text('إعادة ضبط'));
      await tester.pump();

      // Now select color 'كحلي' and size 'L' and price preset 'أقل من 150'
      await tester.scrollUntilVisible(
        find.text('كحلي'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('كحلي'));
      await tester.pump();

      await tester.tap(find.text('L'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('أقل من 150'),
        -150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('أقل من 150'));
      await tester.pump();

      await tester.tap(find.text('عرض النتائج'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.search, 'جاكيت');
      expect(result!.color, 'كحلي');
      expect(result!.size, 'L');
      expect(result!.minPrice, isNull);
      expect(result!.maxPrice, 150);
      expect(result!.inStockOnly, isFalse);
    });

    testWidgets('AppFilterEmptyState displays message and invokes onReset', (tester) async {
      var resetCalled = false;

      await tester.pumpWidget(
        wrapApp(
          AppFilterEmptyState(onReset: () => resetCalled = true),
        ),
      );

      expect(find.text('لا توجد نتائج مطابقة'), findsOneWidget);
      expect(find.text('إعادة ضبط الفلاتر'), findsOneWidget);

      await tester.tap(find.text('إعادة ضبط الفلاتر'));
      await tester.pump();

      expect(resetCalled, isTrue);
    });
  });
}
