import 'package:fashion_marketplace/core/filtering/filter_models.dart';
import 'package:fashion_marketplace/features/admin/domain/models/catalog_models.dart';
import 'package:fashion_marketplace/features/auth/domain/models/app_user.dart';
import 'package:fashion_marketplace/features/auth/domain/models/user_role.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_order.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_shop.dart';
import 'package:fashion_marketplace/features/shop/domain/models/shop.dart';
import 'package:fashion_marketplace/features/shop/domain/models/shop_product.dart'
    hide ProductVariant;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime(2026, 11, 15, 14, 30);

  group('Text normalization & token search', () {
    test('normalizes Arabic hamza forms, ta marbuta, alef maksura, and tashkeel', () {
      expect(normalizeSearchText('أَحْمَد إِسْلَام آلَـة'), 'احمد اسلام اله');
      expect(normalizeSearchText('فُستان سَهرة أَنيق'), 'فستان سهره انيق');
      expect(normalizeSearchText('مَرْمَى  و شَاطِئ'), 'مرمي و شاطي');
      expect(normalizeSearchText('لؤلؤي   فضفاض'), 'لولوي فضفاض');
      expect(normalizeSearchText('  Blazer   NAVY  '), 'blazer navy');
      expect(normalizeSearchText(null), '');
    });

    test('matchesSearchTokens requires all tokens across combined fields', () {
      final fields = ['فستان سهرة', 'بوتيك النخبة', 'أسود'];
      expect(matchesSearchTokens('', fields), isTrue);
      expect(matchesSearchTokens(null, fields), isTrue);
      expect(matchesSearchTokens('فستان سهره اسود', fields), isTrue);
      expect(matchesSearchTokens('النخبه اسود', fields), isTrue);
      expect(matchesSearchTokens('فستان ابيض', fields), isFalse);
      expect(matchesSearchTokens('بحث', const []), isFalse);
    });
  });

  group('Ranges, presets, extractors, and color swatches', () {
    test('matchesNumberRange handles inclusive open and closed bounds', () {
      expect(matchesNumberRange(150, null, null), isTrue);
      expect(matchesNumberRange(150, 150, 300), isTrue);
      expect(matchesNumberRange(300, 150, 300), isTrue);
      expect(matchesNumberRange(149.9, 150, null), isFalse);
      expect(matchesNumberRange(300.1, null, 300), isFalse);
    });

    test('DateRangePreset filters relative to local start of today', () {
      final todayMorning = DateTime(2026, 11, 15, 1, 0);
      final threeDaysAgo = DateTime(2026, 11, 12, 23, 0);
      final tenDaysAgo = DateTime(2026, 11, 5, 10, 0);
      final fortyDaysAgo = DateTime(2026, 10, 1, 10, 0);

      expect(DateRangePreset.today.matches(todayMorning, now: fixedNow), isTrue);
      expect(DateRangePreset.today.matches(threeDaysAgo, now: fixedNow), isFalse);

      expect(
        DateRangePreset.last7Days.matches(threeDaysAgo, now: fixedNow),
        isTrue,
      );
      expect(
        DateRangePreset.last7Days.matches(tenDaysAgo, now: fixedNow),
        isFalse,
      );

      expect(
        DateRangePreset.last30Days.matches(tenDaysAgo, now: fixedNow),
        isTrue,
      );
      expect(
        DateRangePreset.last30Days.matches(fortyDaysAgo, now: fixedNow),
        isFalse,
      );
    });

    test('StockFilter and ActiveStateFilter classify boundary values accurately', () {
      expect(StockFilter.inStock.matchesStock(1), isTrue);
      expect(StockFilter.inStock.matchesStock(0), isFalse);
      expect(StockFilter.lowStock.matchesStock(0), isFalse);
      expect(StockFilter.lowStock.matchesStock(5), isTrue);
      expect(StockFilter.lowStock.matchesStock(6), isFalse);
      expect(StockFilter.outOfStock.matchesStock(0), isTrue);
      expect(StockFilter.outOfStock.matchesStock(1), isFalse);

      expect(ActiveStateFilter.all.matches(true), isTrue);
      expect(ActiveStateFilter.all.matches(false), isTrue);
      expect(ActiveStateFilter.active.matches(true), isTrue);
      expect(ActiveStateFilter.active.matches(false), isFalse);
      expect(ActiveStateFilter.inactive.matches(false), isTrue);
      expect(ActiveStateFilter.inactive.matches(true), isFalse);
    });

    test('extractDistinctValues deduplicates normalized strings cleanly', () {
      final result = extractDistinctValues(['غزة', 'غزه ', 'رام الله', null, '']);
      expect(result.length, 2);
      expect(result, contains('رام الله'));
    });

    test('resolveColorSwatch parses hex strings, Arabic names, and English names', () {
      expect(resolveColorSwatch('#FF5733'), const Color(0xFFFF5733));
      expect(resolveColorSwatch('#80112233'), const Color(0x80112233));
      expect(resolveColorSwatch('أسود'), const Color(0xFF18181B));
      expect(resolveColorSwatch('Navy'), const Color(0xFF1E3A5F));
      expect(resolveColorSwatch('غير معروف'), isNull);
      expect(resolveColorSwatch(''), isNull);
    });
  });

  group('Customer ProductFilter & applyCustomerProductFilter', () {
    CustomerProduct buildProduct({
      required String id,
      required String name,
      required double price,
      String categoryId = 'cat-1',
      String categoryName = 'فساتين',
      String shopId = 'shop-1',
      String shopName = 'أزياء الشام',
      double ratingAvg = 4.5,
      int ratingCount = 10,
      List<ProductVariant> variants = const [],
    }) {
      return CustomerProduct.fromMap(
        {
          'id': id,
          'shop_id': shopId,
          'shop_name': shopName,
          'category_id': categoryId,
          'category_name': categoryName,
          'name': name,
          'description': 'وصف $name',
          'price': price,
          'status': 'approved',
          'rating_avg': ratingAvg,
          'rating_count': ratingCount,
        },
        variants: variants,
      );
    }

    ProductVariant variant({
      required String id,
      required String size,
      required String color,
      int stock = 4,
      bool isActive = true,
    }) {
      return ProductVariant(
        id: id,
        productId: 'p',
        size: size,
        color: color,
        stock: stock,
        isActive: isActive,
      );
    }

    final products = [
      buildProduct(
        id: 'p1',
        name: 'بليزر كلاسيكي',
        price: 250,
        categoryId: 'cat-jackets',
        categoryName: 'جاكيتات',
        shopId: 's1',
        shopName: 'متجر المها',
        ratingAvg: 4.8,
        ratingCount: 30,
        variants: [
          variant(id: 'v1', size: 'L', color: 'كحلي', stock: 5),
          variant(id: 'v2', size: 'XL', color: 'أسود', stock: 0),
        ],
      ),
      buildProduct(
        id: 'p2',
        name: 'فستان سهرة',
        price: 520,
        categoryId: 'cat-dresses',
        categoryName: 'فساتين',
        shopId: 's2',
        shopName: 'بوتيك روز',
        ratingAvg: 4.8,
        ratingCount: 5,
        variants: [
          variant(id: 'v3', size: 'S', color: 'أحمر', stock: 2),
          variant(id: 'v4', size: 'M', color: 'كحلي', stock: 0, isActive: false),
        ],
      ),
      buildProduct(
        id: 'p3',
        name: 'أحذية رياضية خفيفة',
        price: 120,
        categoryId: 'cat-shoes',
        categoryName: 'أحذية',
        shopId: 's1',
        shopName: 'متجر المها',
        ratingAvg: 3.5,
        ratingCount: 12,
        variants: [
          variant(id: 'v5', size: 'M', color: 'أبيض', stock: 0),
        ],
      ),
    ];

    test('ProductFilter.copyWith supports clearing price bounds & individual facets', () {
      const initial = ProductFilter(
        categoryId: 'c1',
        shopId: 's1',
        search: 'جاكيت',
        minPrice: 100,
        maxPrice: 400,
        color: 'أسود',
        size: 'M',
        inStockOnly: true,
        minRating: 4.0,
        sort: ProductSortOption.priceAsc,
      );

      expect(initial.activeFacetCount, 7);
      expect(initial.hasActiveFilters, isTrue);

      final clearedMin = initial.copyWith(clearMinPrice: true);
      expect(clearedMin.minPrice, isNull);
      expect(clearedMin.maxPrice, 400);

      final clearedMax = initial.copyWith(clearMaxPrice: true);
      expect(clearedMax.minPrice, 100);
      expect(clearedMax.maxPrice, isNull);

      final clearedBoth = initial.copyWith(clearPrice: true);
      expect(clearedBoth.minPrice, isNull);
      expect(clearedBoth.maxPrice, isNull);
      expect(clearedBoth.activeFacetCount, 6);

      final clearedAll = initial.copyWith(
        clearCategory: true,
        clearShop: true,
        clearSearch: true,
        clearPrice: true,
        clearColor: true,
        clearSize: true,
        clearMinRating: true,
        inStockOnly: false,
        sort: ProductSortOption.newest,
      );
      expect(clearedAll, ProductFilter.empty);
      expect(clearedAll.hasActiveFilters, isFalse);
    });

    test('extractProductSizes preserves canonical clothing order and skips inactive variants', () {
      final sizes = extractProductSizes(products);
      // p2 has active S, inactive M; p1 has active L, XL; p3 has active M
      expect(sizes, ['S', 'M', 'L', 'XL']);
    });

    test('filters by category, shop, price, rating, inStockOnly, color, size, and normalized search', () {
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(categoryId: 'cat-jackets'),
        ).map((e) => e.id),
        ['p1'],
      );

      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(shopId: 's1', minPrice: 150, maxPrice: 300),
        ).map((e) => e.id),
        ['p1'],
      );

      // Inactive variant (p2 كحلي) should NOT match color filter
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(color: 'كحلي'),
        ).map((e) => e.id),
        ['p1'],
      );

      // Out-of-stock variant (p1 أسود has stock=0) fails when inStockOnly=true
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(color: 'اسود', inStockOnly: false),
        ).map((e) => e.id),
        ['p1'],
      );
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(color: 'اسود', inStockOnly: true),
        ),
        isEmpty,
      );

      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(minRating: 4.0),
        ).map((e) => e.id),
        ['p1', 'p2'],
      );

      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(search: 'احذيه المها'),
        ).map((e) => e.id),
        ['p3'],
      );
    });

    test('sorts products by priceAsc, priceDesc, topRated tie-breaker, nameAsc, and stock', () {
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(sort: ProductSortOption.priceAsc),
        ).map((e) => e.id),
        ['p3', 'p1', 'p2'],
      );
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(sort: ProductSortOption.priceDesc),
        ).map((e) => e.id),
        ['p2', 'p1', 'p3'],
      );
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(sort: ProductSortOption.topRated),
        ).map((e) => e.id),
        ['p1', 'p2', 'p3'],
      );
      expect(
        applyCustomerProductFilter(
          products,
          const ProductFilter(sort: ProductSortOption.stockDesc),
        ).map((e) => e.id),
        ['p1', 'p2', 'p3'],
      );
    });
  });

  group('Customer Shops & Orders Filters', () {
    test('filterCustomerShops filters by city, productsCount, search and sort', () {
      final shops = [
        CustomerShop.fromMap({
          'id': 's1',
          'name': 'دار الزي',
          'city': 'غزة',
          'products_count': 12,
        }),
        CustomerShop.fromMap({
          'id': 's2',
          'name': 'أطياف مودرن',
          'city': 'رام الله',
          'products_count': 0,
        }),
        CustomerShop.fromMap({
          'id': 's3',
          'name': 'بوتيك الياسمين',
          'city': 'غزه',
          'products_count': 25,
        }),
      ];

      final byCity = filterCustomerShops(
        shops,
        const CustomerShopFilter(city: 'غزة', onlyWithProducts: true, sort: ShopSortOption.productsDesc),
      );
      expect(byCity.map((s) => s.id), ['s3', 's1']);

      final byQuery = filterCustomerShops(
        shops,
        const CustomerShopFilter(search: 'اطياف رام'),
      );
      expect(byQuery.map((s) => s.id), ['s2']);
    });

    test('filterCustomerOrders, filterShopOrders, and filterAdminOrders work uniformly', () {
      final cOrders = [
        CustomerOrder.fromMap(
          {
            'id': 'ord-100',
            'customer_id': 'c1',
            'shop_id': 's1',
            'shop_name': 'متجر النخبة',
            'status': 'delivered',
            'total': 320,
            'delivery_address': 'غزة - الرمال',
            'phone': '0599111222',
            'created_at': DateTime(2026, 11, 15, 9, 0).toIso8601String(),
          },
          items: [
            CustomerOrderItem.fromMap({
              'id': 'oi-1',
              'product_id': 'p1',
              'product_name': 'جاكيت صوف',
              'quantity': 1,
              'unit_price': 320,
            }),
          ],
        ),
        CustomerOrder.fromMap(
          {
            'id': 'ord-200',
            'customer_id': 'c1',
            'shop_id': 's2',
            'shop_name': 'بوتيك روز',
            'status': 'pending',
            'total': 95,
            'delivery_address': 'خانيونس',
            'created_at': DateTime(2026, 10, 1, 9, 0).toIso8601String(),
          },
        ),
      ];

      expect(
        filterCustomerOrders(
          cOrders,
          const OrderFilterState(search: 'صوف النخبه', datePreset: DateRangePreset.today),
          now: fixedNow,
        ).map((e) => e.id),
        ['ord-100'],
      );
      expect(
        filterCustomerOrders(
          cOrders,
          const OrderFilterState(sort: OrderSortOption.totalAsc),
          now: fixedNow,
        ).map((e) => e.id),
        ['ord-200', 'ord-100'],
      );

      final sOrders = [
        ShopOrder.fromMap({
          'id': 'so-1',
          'customer_id': 'u1',
          'customer_name': 'سارة علي',
          'customer_email': 'sara@example.com',
          'shop_id': 's1',
          'status': 'confirmed',
          'total': 450,
          'created_at': DateTime(2026, 11, 14, 12, 0).toIso8601String(),
        }),
        ShopOrder.fromMap({
          'id': 'so-2',
          'customer_id': 'u2',
          'customer_name': 'أحمد عمر',
          'customer_email': 'ahmad@example.com',
          'shop_id': 's1',
          'status': 'cancelled',
          'total': 110,
          'created_at': DateTime(2026, 11, 15, 10, 0).toIso8601String(),
        }),
      ];

      expect(
        filterShopOrders(
          sOrders,
          const OrderFilterState(
            search: 'ساره',
            status: 'confirmed',
            minTotal: 400,
            datePreset: DateRangePreset.last7Days,
          ),
          now: fixedNow,
        ).map((e) => e.id),
        ['so-1'],
      );

      final aOrders = [
        AdminOrder.fromMap({
          'id': 'ao-1',
          'shop_id': 's1',
          'shop_name': 'أزياء الشام',
          'customer_email': 'c1@test.com',
          'status': 'shipped',
          'total': 600,
          'created_at': DateTime(2026, 11, 15, 8, 0).toIso8601String(),
        }),
        AdminOrder.fromMap({
          'id': 'ao-2',
          'shop_id': 's2',
          'shop_name': 'دار الموضة',
          'customer_email': 'c2@test.com',
          'status': 'pending',
          'total': 180,
          'created_at': DateTime(2026, 11, 10, 8, 0).toIso8601String(),
        }),
      ];

      expect(
        filterAdminOrders(
          aOrders,
          const OrderFilterState(shopName: 'دار الموضه', maxTotal: 200),
          now: fixedNow,
        ).map((e) => e.id),
        ['ao-2'],
      );
    });
  });

  group('Shop Products & Admin Management Filters', () {
    test('filterShopProducts supports status, stockFilter, category, price range and sort', () {
      final items = [
        ShopProduct.fromMap({
          'id': 'sp-1',
          'shop_id': 's1',
          'category_id': 'c1',
          'category_name': 'بلوزات',
          'name': 'بلوزة حرير',
          'price': 180,
          'status': 'approved',
          'variants': [
            {'id': 'v1', 'product_id': 'sp-1', 'size': 'M', 'color': 'وردي', 'stock': 3, 'is_active': true},
          ],
        }),
        ShopProduct.fromMap({
          'id': 'sp-2',
          'shop_id': 's1',
          'category_id': 'c2',
          'category_name': 'معاطف',
          'name': 'معطف شتوي',
          'price': 540,
          'status': 'pending_approval',
          'variants': [
            {'id': 'v2', 'product_id': 'sp-2', 'size': 'L', 'color': 'بني', 'stock': 0, 'is_active': true},
          ],
        }),
      ];

      expect(
        filterShopProducts(
          items,
          const ShopProductFilterState(
            stockFilter: StockFilter.lowStock,
            search: 'وردي',
          ),
        ).map((e) => e.id),
        ['sp-1'],
      );
      expect(
        filterShopProducts(
          items,
          const ShopProductFilterState(
            status: 'pending_approval',
            stockFilter: StockFilter.outOfStock,
          ),
        ).map((e) => e.id),
        ['sp-2'],
      );
      expect(
        filterShopProducts(
          items,
          const ShopProductFilterState(sort: ProductSortOption.priceDesc),
        ).map((e) => e.id),
        ['sp-2', 'sp-1'],
      );
    });

    test('filterAdminProducts filters across shop, category, status, price range, and sort', () {
      final items = [
        AdminProduct.fromMap({
          'id': 'ap-1',
          'name': 'حقيبة جلد',
          'price': 310,
          'status': 'approved',
          'shop_name': 'بوتيك المها',
          'category_name': 'إكسسوارات',
        }),
        AdminProduct.fromMap({
          'id': 'ap-2',
          'name': 'ساعة يد',
          'price': 720,
          'status': 'pending_approval',
          'shop_name': 'ساعات النور',
          'category_name': 'ساعات',
        }),
      ];

      expect(
        filterAdminProducts(
          items,
          const AdminProductFilterState(
            shopName: 'بوتيك المها',
            categoryName: 'اكسسوارات',
            maxPrice: 400,
          ),
        ).map((e) => e.id),
        ['ap-1'],
      );
      expect(
        filterAdminProducts(
          items,
          const AdminProductFilterState(sort: ProductSortOption.priceDesc),
        ).map((e) => e.id),
        ['ap-2', 'ap-1'],
      );
    });

    test('filterAdminShops filters by status, normalized city, search, and newest date', () {
      final shops = [
        Shop.fromMap({
          'id': 'sh-1',
          'owner_id': 'o1',
          'name': 'الأناقة العصرية',
          'city': 'غزة',
          'status': 'pending',
          'owner_name': 'خالد يوسف',
          'submitted_at': '2026-11-10T10:00:00Z',
        }),
        Shop.fromMap({
          'id': 'sh-2',
          'owner_id': 'o2',
          'name': 'إطلالة الغد',
          'city': 'رام الله',
          'status': 'approved',
          'owner_name': 'مريم حسن',
          'submitted_at': '2026-11-14T10:00:00Z',
        }),
      ];

      expect(
        filterAdminShops(
          shops,
          const AdminShopFilterState(
            status: ShopStatus.pending,
            city: 'غزه',
            search: 'خالد الاناقه',
          ),
        ).map((e) => e.id),
        ['sh-1'],
      );
      expect(
        filterAdminShops(
          shops,
          const AdminShopFilterState(sort: ShopSortOption.newest),
        ).map((e) => e.id),
        ['sh-2', 'sh-1'],
      );
    });

    test('filterAdminUsers filters by role, activeFilter, profileCompleted, city and search', () {
      final users = [
        AppUser.fromMap({
          'id': 'u1',
          'email': 'ali@shop.com',
          'full_name': 'علي أحمد',
          'role': 'shop',
          'city': 'نابلس',
          'is_active': true,
          'profile_completed': true,
        }),
        AppUser.fromMap({
          'id': 'u2',
          'email': 'mona@cust.com',
          'full_name': 'منى سعيد',
          'role': 'customer',
          'city': 'غزة',
          'is_active': false,
          'profile_completed': false,
        }),
      ];

      expect(
        filterAdminUsers(
          users,
          const AdminUserFilterState(
            role: UserRole.customer,
            activeFilter: ActiveStateFilter.inactive,
            profileCompleted: false,
            city: 'غزه',
          ),
        ).map((e) => e.id),
        ['u2'],
      );
      expect(
        filterAdminUsers(
          users,
          const AdminUserFilterState(sortByNameAsc: true),
        ).map((e) => e.id),
        ['u1', 'u2'],
      );
    });

    test('filterNotifications filters by audience, datePreset, search, and chronological order', () {
      final list = [
        AdminNotification.fromMap({
          'id': 'n1',
          'title': 'عرض نهاية الأسبوع',
          'body': 'خصم 30% على المعاطف',
          'audience': 'customer',
          'created_at': DateTime(2026, 11, 15, 8, 0).toIso8601String(),
        }),
        AdminNotification.fromMap({
          'id': 'n2',
          'title': 'تنبيه للتجار',
          'body': 'مراجعة الطلبات المتأخرة',
          'audience': 'shop',
          'created_at': DateTime(2026, 11, 1, 8, 0).toIso8601String(),
        }),
      ];

      expect(
        filterNotifications(
          list,
          const NotificationFilterState(
            audience: 'customer',
            datePreset: DateRangePreset.today,
            search: 'المعاطف',
          ),
          now: fixedNow,
        ).map((e) => e.id),
        ['n1'],
      );
      expect(
        filterNotifications(
          list,
          const NotificationFilterState(oldestFirst: true),
          now: fixedNow,
        ).map((e) => e.id),
        ['n2', 'n1'],
      );
    });

    test('filterAdminCategories and filterAdminBanners filter active state, search, and sort', () {
      final categories = [
        CatalogCategory.fromMap({
          'id': 'c1',
          'name': 'بناطيل',
          'description': 'pants',
          'is_active': true,
        }),
        CatalogCategory.fromMap({
          'id': 'c2',
          'name': 'أحذية',
          'description': 'shoes',
          'is_active': false,
        }),
      ];

      expect(
        filterAdminCategories(
          categories,
          const CatalogListFilterState(
            activeFilter: ActiveStateFilter.active,
            search: 'pants',
          ),
        ).map((e) => e.id),
        ['c1'],
      );
      expect(
        filterAdminCategories(
          categories,
          const CatalogListFilterState(sort: DisplayOrderSort.nameAsc),
        ).map((e) => e.id),
        ['c2', 'c1'],
      );

      final banners = [
        AdminBanner.fromMap({
          'id': 'b1',
          'title': 'موسم الخريف',
          'subtitle': 'تشكيلة دافئة',
          'image_url': 'https://example.com/1.jpg',
          'is_active': true,
          'sort_order': 2,
        }),
        AdminBanner.fromMap({
          'id': 'b2',
          'title': 'أزياء الصيف',
          'subtitle': 'خصومات كبرى',
          'image_url': 'https://example.com/2.jpg',
          'is_active': true,
          'sort_order': 1,
        }),
      ];

      expect(
        filterAdminBanners(
          banners,
          const CatalogListFilterState(sort: DisplayOrderSort.displayOrder),
        ).map((e) => e.id),
        ['b2', 'b1'],
      );
      expect(
        filterAdminBanners(
          banners,
          const CatalogListFilterState(search: 'دافئه', sort: DisplayOrderSort.nameDesc),
        ).map((e) => e.id),
        ['b1'],
      );
    });

    test('filterProductReviews filters by exact stars, comment presence, and sorts cleanly', () {
      final reviews = [
        ProductReview(
          id: 'r1',
          productId: 'p1',
          customerId: 'u1',
          customerName: 'ليلى',
          rating: 5,
          comment: 'خامة ممتازة جداً',
          createdAt: DateTime(2026, 11, 10),
        ),
        ProductReview(
          id: 'r2',
          productId: 'p1',
          customerId: 'u2',
          customerName: 'نور',
          rating: 5,
          comment: '   ',
          createdAt: DateTime(2026, 11, 14),
        ),
        ProductReview(
          id: 'r3',
          productId: 'p1',
          customerId: 'u3',
          customerName: 'زياد',
          rating: 2,
          comment: 'المقاس صغير',
          createdAt: DateTime(2026, 11, 12),
        ),
      ];

      expect(
        filterProductReviews(
          reviews,
          const ReviewFilterState(rating: 5, withCommentOnly: true),
        ).map((e) => e.id),
        ['r1'],
      );
      expect(
        filterProductReviews(
          reviews,
          const ReviewFilterState(sort: ReviewSortOption.lowestRating),
        ).map((e) => e.id),
        ['r3', 'r2', 'r1'],
      );
    });
  });
}
