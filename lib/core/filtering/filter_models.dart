import 'dart:ui' show Color;

import '../../features/admin/domain/models/catalog_models.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/customer/domain/models/customer_order.dart';
import '../../features/customer/domain/models/customer_product.dart';
import '../../features/customer/domain/models/customer_shop.dart';
import '../../features/shop/domain/models/shop.dart';
import '../../features/shop/domain/models/shop_product.dart';
import '../search/smart_search_sheets.dart';
import '../search/text_search_engine.dart';
import '../search/visual_search_service.dart';

export '../search/text_search_engine.dart';

/// Extracts all string and numeric values from a nested JSON map (such as `product.details`).
List<String> _flattenJsonMapValues(Map<String, dynamic> map) {
  final out = <String>[];
  void visit(dynamic value) {
    if (value == null) return;
    if (value is String) {
      if (value.trim().isNotEmpty) out.add(value);
    } else if (value is num || value is bool) {
      out.add(value.toString());
    } else if (value is Map) {
      for (final entry in value.entries) {
        out.add(entry.key.toString());
        visit(entry.value);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        visit(item);
      }
    }
  }

  visit(map);
  return out;
}

/// Checks whether [value] lies within optional inclusive [min]..[max] bounds.
bool matchesNumberRange(double value, double? min, double? max) {
  if (min != null && value < min) return false;
  if (max != null && value > max) return false;
  return true;
}

/// Time-window filter options shared by Orders and Notifications.
enum DateRangePreset {
  all('الكل'),
  today('اليوم'),
  last7Days('آخر 7 أيام'),
  last30Days('آخر 30 يوماً');

  const DateRangePreset(this.labelAr);
  final String labelAr;

  bool matches(DateTime date, {DateTime? now}) {
    if (this == DateRangePreset.all) return true;
    final current = (now ?? DateTime.now()).toLocal();
    final localDate = date.toLocal();
    final startOfToday = DateTime(current.year, current.month, current.day);

    switch (this) {
      case DateRangePreset.all:
        return true;
      case DateRangePreset.today:
        return !localDate.isBefore(startOfToday);
      case DateRangePreset.last7Days:
        return !localDate.isBefore(
          startOfToday.subtract(const Duration(days: 6)),
        );
      case DateRangePreset.last30Days:
        return !localDate.isBefore(
          startOfToday.subtract(const Duration(days: 29)),
        );
    }
  }
}

/// Inventory stock availability filter (Customer & Shop).
enum StockFilter {
  all('الكل'),
  inStock('متوفر'),
  lowStock('مخزون منخفض'),
  outOfStock('نفدت الكمية');

  const StockFilter(this.labelAr);
  final String labelAr;

  bool matchesStock(int totalStock, {int lowThreshold = 5}) {
    return switch (this) {
      StockFilter.all => true,
      StockFilter.inStock => totalStock > 0,
      StockFilter.lowStock => totalStock > 0 && totalStock <= lowThreshold,
      StockFilter.outOfStock => totalStock <= 0,
    };
  }
}

/// Binary activation filter for Categories, Banners, and Users.
enum ActiveStateFilter {
  all('الكل'),
  active('نشط'),
  inactive('معطّل');

  const ActiveStateFilter(this.labelAr);
  final String labelAr;

  bool matches(bool isActive) {
    return switch (this) {
      ActiveStateFilter.all => true,
      ActiveStateFilter.active => isActive,
      ActiveStateFilter.inactive => !isActive,
    };
  }
}

/// Product sorting modes used across Customer, Shop, and Admin.
enum ProductSortOption {
  newest('الأحدث'),
  priceAsc('السعر: الأقل أولاً'),
  priceDesc('السعر: الأعلى أولاً'),
  topRated('الأعلى تقييماً'),
  nameAsc('الاسم: أ - ي'),
  stockAsc('الأقل مخزوناً'),
  stockDesc('الأكثر توفراً');

  const ProductSortOption(this.labelAr);
  final String labelAr;
}

/// Order sorting modes shared across Customer, Shop, and Admin.
enum OrderSortOption {
  newest('الأحدث'),
  oldest('الأقدم'),
  totalDesc('الأعلى قيمة'),
  totalAsc('الأقل قيمة');

  const OrderSortOption(this.labelAr);
  final String labelAr;
}

/// Shop sorting modes for Customer directory & Admin shop management.
enum ShopSortOption {
  defaultOrder('الافتراضي'),
  productsDesc('الأكثر منتجات'),
  newest('الأحدث'),
  nameAsc('الاسم: أ - ي');

  const ShopSortOption(this.labelAr);
  final String labelAr;
}

/// Sorting modes for Categories & Banners.
enum DisplayOrderSort {
  displayOrder('الترتيب الافتراضي'),
  nameAsc('أبجدياً: أ - ي'),
  nameDesc('أبجدياً: ي - أ');

  const DisplayOrderSort(this.labelAr);
  final String labelAr;
}

/// Review sorting options on product details.
enum ReviewSortOption {
  newest('الأحدث'),
  highestRating('الأعلى تقييماً'),
  lowestRating('الأقل تقييماً');

  const ReviewSortOption(this.labelAr);
  final String labelAr;
}

/// Extracts sorted unique non-empty city names from any iterable of strings.
List<String> extractDistinctValues(Iterable<String?> rawValues) {
  final seen = <String, String>{};
  for (final raw in rawValues) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) continue;
    final key = normalizeSearchText(trimmed);
    seen.putIfAbsent(key, () => trimmed);
  }
  final list = seen.values.toList()..sort((a, b) => a.compareTo(b));
  return list;
}

const List<String> kDefaultClothingSizes = [
  'XS',
  'S',
  'M',
  'L',
  'XL',
  'XXL',
  '3XL',
];

const List<String> kDefaultClothingColors = [
  'أسود',
  'أبيض',
  'أزرق',
  'كحلي',
  'أحمر',
  'أخضر',
  'بيج',
  'بني',
  'رمادي',
  'وردي',
];

/// Collects distinct sizes present across [products], preserving canonical order first.
List<String> extractProductSizes(Iterable<CustomerProduct> products) {
  final canonicalOrder = {
    for (var i = 0; i < kDefaultClothingSizes.length; i++)
      kDefaultClothingSizes[i].toUpperCase(): i,
  };
  final byKey = <String, String>{};
  for (final product in products) {
    for (final v in product.variants) {
      if (!v.isActive) continue;
      final size = v.size.trim();
      if (size.isEmpty) continue;
      byKey.putIfAbsent(size.toUpperCase(), () => size);
    }
  }
  if (byKey.isEmpty) return List<String>.from(kDefaultClothingSizes);

  final list = byKey.values.toList()
    ..sort((a, b) {
      final ia = canonicalOrder[a.toUpperCase()] ?? 999;
      final ib = canonicalOrder[b.toUpperCase()] ?? 999;
      if (ia != ib) return ia.compareTo(ib);
      return a.compareTo(b);
    });
  return list;
}

/// Collects distinct colors present across [products], falling back to defaults when empty.
List<String> extractProductColors(Iterable<CustomerProduct> products) {
  final byKey = <String, String>{};
  for (final product in products) {
    for (final v in product.variants) {
      if (!v.isActive) continue;
      final color = v.color.trim();
      if (color.isEmpty) continue;
      byKey.putIfAbsent(normalizeSearchText(color), () => color);
    }
  }
  if (byKey.isEmpty) return List<String>.from(kDefaultClothingColors);
  return byKey.values.toList()..sort((a, b) => a.compareTo(b));
}

/// Resolves common Arabic/English fashion color names or `#RRGGBB` strings to a swatch [Color].
Color? resolveColorSwatch(String rawColor) {
  final trimmed = rawColor.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('#')) {
    final hex = trimmed.substring(1);
    if (hex.length == 6) {
      final parsed = int.tryParse('FF$hex', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }
  }

  final norm = normalizeSearchText(trimmed);
  for (final entry in _colorPaletteMap.entries) {
    if (norm.contains(entry.key)) return entry.value;
  }
  return null;
}

const Map<String, Color> _colorPaletteMap = {
  'اسود': Color(0xFF18181B),
  'black': Color(0xFF18181B),
  'فحمي': Color(0xFF27272A),
  'ابيض': Color(0xFFFAFAFA),
  'white': Color(0xFFFAFAFA),
  'اوف وايت': Color(0xFFF5F2EB),
  'كريمي': Color(0xFFF6F0E2),
  'عاجي': Color(0xFFF6F0E2),
  'كحلي': Color(0xFF1E3A5F),
  'navy': Color(0xFF1E3A5F),
  'ازرق': Color(0xFF2563EB),
  'blue': Color(0xFF2563EB),
  'سماوي': Color(0xFF38BDF8),
  'تركواز': Color(0xFF0D9488),
  'تيل': Color(0xFF007C83),
  'teal': Color(0xFF007C83),
  'احمر': Color(0xFFDC2626),
  'red': Color(0xFFDC2626),
  'عنابي': Color(0xFF7F1D1D),
  'نبيتي': Color(0xFF7F1D1D),
  'burgundy': Color(0xFF7F1D1D),
  'اخضر': Color(0xFF16A34A),
  'green': Color(0xFF16A34A),
  'زيتوني': Color(0xFF556B2F),
  'زيتي': Color(0xFF4D6B2A),
  'olive': Color(0xFF556B2F),
  'بيج': Color(0xFFD6C2A3),
  'beige': Color(0xFFD6C2A3),
  'رملي': Color(0xFFCBB593),
  'كموني': Color(0xFFC49A45),
  'بني': Color(0xFF6B4226),
  'brown': Color(0xFF6B4226),
  'عسلي': Color(0xFF9A5B25),
  'جملي': Color(0xFFB67E43),
  'رمادي': Color(0xFF71717A),
  'رصاصي': Color(0xFF71717A),
  'gray': Color(0xFF71717A),
  'grey': Color(0xFF71717A),
  'وردي': Color(0xFFEC4899),
  'زهري': Color(0xFFF472B6),
  'بمبي': Color(0xFFF472B6),
  'pink': Color(0xFFEC4899),
  'اصفر': Color(0xFFEAB308),
  'yellow': Color(0xFFEAB308),
  'برتقالي': Color(0xFFF97316),
  'orange': Color(0xFFF97316),
  'بنفسجي': Color(0xFF9333EA),
  'موف': Color(0xFFA855F7),
  'purple': Color(0xFF9333EA),
  'ذهبي': Color(0xFFD4AF37),
  'gold': Color(0xFFD4AF37),
  'فضي': Color(0xFFA1A1AA),
  'silver': Color(0xFFA1A1AA),
};

// ---------------------------------------------------------------------------
// 1. Customer Catalog & Storefront Product Filter
// ---------------------------------------------------------------------------

class ProductFilter {
  const ProductFilter({
    this.categoryId,
    this.shopId,
    this.search,
    this.minPrice,
    this.maxPrice,
    this.color,
    this.size,
    this.inStockOnly = false,
    this.minRating,
    this.sort = ProductSortOption.newest,
  });

  static const ProductFilter empty = ProductFilter();

  final String? categoryId;
  final String? shopId;
  final String? search;
  final double? minPrice;
  final double? maxPrice;
  final String? color;
  final String? size;
  final bool inStockOnly;
  final double? minRating;
  final ProductSortOption sort;

  ProductFilter copyWith({
    String? categoryId,
    String? shopId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? color,
    String? size,
    bool? inStockOnly,
    double? minRating,
    ProductSortOption? sort,
    bool clearCategory = false,
    bool clearShop = false,
    bool clearSearch = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    bool clearPrice = false,
    bool clearColor = false,
    bool clearSize = false,
    bool clearMinRating = false,
  }) {
    return ProductFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      shopId: clearShop ? null : (shopId ?? this.shopId),
      search: clearSearch ? null : (search ?? this.search),
      minPrice: (clearPrice || clearMinPrice)
          ? null
          : (minPrice ?? this.minPrice),
      maxPrice: (clearPrice || clearMaxPrice)
          ? null
          : (maxPrice ?? this.maxPrice),
      color: clearColor ? null : (color ?? this.color),
      size: clearSize ? null : (size ?? this.size),
      inStockOnly: inStockOnly ?? this.inStockOnly,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      sort: sort ?? this.sort,
    );
  }

  /// Counts discrete filter facets (excluding search query & default sort) for badges.
  int get activeFacetCount {
    var count = 0;
    if (categoryId != null && categoryId!.trim().isNotEmpty) count++;
    if (shopId != null && shopId!.trim().isNotEmpty) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (color != null && color!.trim().isNotEmpty) count++;
    if (size != null && size!.trim().isNotEmpty) count++;
    if (inStockOnly) count++;
    if (minRating != null) count++;
    return count;
  }

  bool get hasSearch => search != null && search!.trim().isNotEmpty;

  bool get hasActiveFilters =>
      activeFacetCount > 0 || hasSearch || sort != ProductSortOption.newest;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProductFilter &&
            other.categoryId == categoryId &&
            other.shopId == shopId &&
            other.search == search &&
            other.minPrice == minPrice &&
            other.maxPrice == maxPrice &&
            other.color == color &&
            other.size == size &&
            other.inStockOnly == inStockOnly &&
            other.minRating == minRating &&
            other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(
    categoryId,
    shopId,
    search,
    minPrice,
    maxPrice,
    color,
    size,
    inStockOnly,
    minRating,
    sort,
  );
}

/// Builds weighted searchable fields covering every product attribute stored
/// in the database (name, category, shop, colors, sizes, details JSON, price…).
List<SearchField> buildCustomerProductSearchFields(CustomerProduct product) {
  final colors = product.availableColors;
  final galleryUrls = <String>[
    if (product.coverImage != null && product.coverImage!.trim().isNotEmpty)
      product.coverImage!,
    for (final img in product.images) if (img.kind != '3d_model') img.filePath,
  ];
  // Image-detected colors are only a fallback when the seller set no colors,
  // so studio backgrounds never cause false color matches.
  final detected = colors.isEmpty
      ? galleryUrls
            .expand(VisualSearchService.instance.getCachedProductImageColors)
            .toSet()
            .toList()
      : const <String>[];
  return [
    SearchField(product.name, 4.0),
    SearchField(product.categoryName, 3.0),
    SearchField(colors.join(' '), 3.0),
    SearchField(
      product.variants.map((v) => '${v.color} ${v.size}').join(' '),
      2.6,
    ),
    SearchField(product.availableSizes.join(' '), 2.6),
    SearchField(_flattenJsonMapValues(product.details).join(' '), 2.0),
    SearchField(product.description, 1.6),
    SearchField(product.shopName, 1.5),
    SearchField(
      '${product.price.toInt()} ${product.price.toStringAsFixed(0)} ${product.price}',
      1.2,
    ),
    SearchField(detected.join(' '), 0.8),
    SearchField(product.id, 0.5),
  ];
}

double? _tighterMin(double? a, double? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a > b ? a : b;
}

double? _tighterMax(double? a, double? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a < b ? a : b;
}

double _visualScoreFor(VisualSearchQuery query, CustomerProduct p) {
  return VisualSearchService.instance.scoreTextAndColorMetadata(
    query: query,
    productColors: p.variants.map((v) => v.color),
    productName: p.name,
    productDescription: p.description,
    categoryName: p.categoryName,
    productImageUrl: p.coverImage,
    productImageUrls: p.images.where((i) => i.kind != '3d_model').map((i) => i.filePath),
  );
}

List<CustomerProduct> applyCustomerProductFilter(
  List<CustomerProduct> products,
  ProductFilter filter,
) {
  final normColor = normalizeSearchText(filter.color);
  final normSize = normalizeSearchText(filter.size);
  final activeVisual = ActiveVisualSearchStore.instance.currentQuery.value;
  final query = PreparedSearchQuery.parse(filter.search);
  final minPrice = _tighterMin(filter.minPrice, query.intent.minPrice);
  final maxPrice = _tighterMax(filter.maxPrice, query.intent.maxPrice);

  final scored = <({CustomerProduct product, double score, int index})>[];

  for (var i = 0; i < products.length; i++) {
    final product = products[i];
    if (filter.categoryId != null &&
        filter.categoryId!.isNotEmpty &&
        product.categoryId != filter.categoryId) {
      continue;
    }
    if (filter.shopId != null &&
        filter.shopId!.isNotEmpty &&
        product.shopId != filter.shopId) {
      continue;
    }
    if (!matchesNumberRange(product.price, minPrice, maxPrice)) {
      continue;
    }
    if (filter.inStockOnly && product.totalStock <= 0) {
      continue;
    }
    if (filter.minRating != null && product.ratingAvg < filter.minRating!) {
      continue;
    }
    if (normColor.isNotEmpty) {
      final hasColor = product.variants.any(
        (v) =>
            v.isActive &&
            (!filter.inStockOnly || v.stock > 0) &&
            normalizeSearchText(v.color) == normColor,
      );
      if (!hasColor) continue;
    }
    if (normSize.isNotEmpty) {
      final hasSize = product.variants.any(
        (v) =>
            v.isActive &&
            (!filter.inStockOnly || v.stock > 0) &&
            normalizeSearchText(v.size) == normSize,
      );
      if (!hasSize) continue;
    }

    final visualScore = activeVisual != null
        ? _visualScoreFor(activeVisual, product)
        : 0.0;

    var relevance = visualScore * 10.0;
    if (query.hasTextTokens) {
      final textScore = query.score(buildCustomerProductSearchFields(product));
      if (textScore == null) {
        // Image search: keep visually similar items even if the generated
        // color/keyword text differs from the seller's wording.
        if (activeVisual == null || visualScore < 0.38) continue;
      } else {
        relevance += textScore;
      }
    }

    scored.add((product: product, score: relevance, index: i));
  }

  final rankByRelevance =
      filter.sort == ProductSortOption.newest &&
      (query.hasTextTokens || activeVisual != null);
  if (rankByRelevance) {
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.index.compareTo(b.index); // stable: newest first on ties
    });
  }

  final filtered = scored.map((e) => e.product).toList();

  switch (filter.sort) {
    case ProductSortOption.newest:
      break; // Relevance (when searching) or repository chronological order.
    case ProductSortOption.priceAsc:
      filtered.sort((a, b) => a.price.compareTo(b.price));
    case ProductSortOption.priceDesc:
      filtered.sort((a, b) => b.price.compareTo(a.price));
    case ProductSortOption.topRated:
      filtered.sort((a, b) {
        final byAvg = b.ratingAvg.compareTo(a.ratingAvg);
        if (byAvg != 0) return byAvg;
        return b.ratingCount.compareTo(a.ratingCount);
      });
    case ProductSortOption.nameAsc:
      filtered.sort((a, b) => a.name.compareTo(b.name));
    case ProductSortOption.stockDesc:
      filtered.sort((a, b) => b.totalStock.compareTo(a.totalStock));
    case ProductSortOption.stockAsc:
      filtered.sort((a, b) => a.totalStock.compareTo(b.totalStock));
  }

  return filtered;
}

/// Computes the closest / most similar products when an exact search or filter
/// yields 0 matches (whether by image, voice, or text).
List<CustomerProduct> computeSimilarCustomerProducts(
  List<CustomerProduct> pool,
  ProductFilter filter, {
  int maxResults = 6,
}) {
  if (pool.isEmpty) return const [];

  final activeVisual = ActiveVisualSearchStore.instance.currentQuery.value;
  final query = PreparedSearchQuery.parse(filter.search);
  final minPrice = _tighterMin(filter.minPrice, query.intent.minPrice);
  final maxPrice = _tighterMax(filter.maxPrice, query.intent.maxPrice);
  final normFilterColor = normalizeSearchText(filter.color);
  final normFilterSize = normalizeSearchText(filter.size);

  final scored = <({CustomerProduct product, double score})>[];

  for (final p in pool) {
    if (filter.shopId != null &&
        filter.shopId!.isNotEmpty &&
        p.shopId != filter.shopId) {
      continue;
    }

    var score = 0.0;

    // 1. Visual similarity if an image search is active
    if (activeVisual != null) {
      score += _visualScoreFor(activeVisual, p) * 3.0;
    }

    // 2. Partial token, synonym, stem & typo overlap across all fields
    if (query.hasTextTokens) {
      score += query.partialScore(buildCustomerProductSearchFields(p));
    }

    // 3. Price proximity to the requested range
    if (minPrice != null || maxPrice != null) {
      if (matchesNumberRange(p.price, minPrice, maxPrice)) {
        score += 1.0;
      } else {
        final target = p.price < (minPrice ?? 0) ? minPrice! : (maxPrice ?? p.price);
        final distance = (p.price - target).abs() / (target <= 0 ? 1 : target);
        score += (1.0 - distance).clamp(0.0, 1.0) * 0.5;
      }
    }

    // 4. Category, Color, Size & Stock proximity
    if (filter.categoryId != null &&
        filter.categoryId!.isNotEmpty &&
        p.categoryId == filter.categoryId) {
      score += 1.2;
    }
    if (normFilterColor.isNotEmpty &&
        p.variants.any((v) => areSearchTermsEquivalent(v.color, filter.color))) {
      score += 1.0;
    }
    if (normFilterSize.isNotEmpty &&
        p.variants.any((v) => normalizeSearchText(v.size) == normFilterSize)) {
      score += 0.7;
    }
    if (p.totalStock > 0) {
      score += 0.25;
    }
    score += (p.ratingAvg / 5.0) * 0.2;

    scored.add((product: p, score: score));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(maxResults).map((e) => e.product).toList();
}

// ---------------------------------------------------------------------------
// 2. Customer Shops Filter
// ---------------------------------------------------------------------------

class CustomerShopFilter {
  const CustomerShopFilter({
    this.search = '',
    this.city,
    this.onlyWithProducts = false,
    this.sort = ShopSortOption.defaultOrder,
  });

  static const CustomerShopFilter empty = CustomerShopFilter();

  final String search;
  final String? city;
  final bool onlyWithProducts;
  final ShopSortOption sort;

  CustomerShopFilter copyWith({
    String? search,
    String? city,
    bool? onlyWithProducts,
    ShopSortOption? sort,
    bool clearCity = false,
  }) {
    return CustomerShopFilter(
      search: search ?? this.search,
      city: clearCity ? null : (city ?? this.city),
      onlyWithProducts: onlyWithProducts ?? this.onlyWithProducts,
      sort: sort ?? this.sort,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (city != null && city!.trim().isNotEmpty) count++;
    if (onlyWithProducts) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 ||
      search.trim().isNotEmpty ||
      sort != ShopSortOption.defaultOrder;
}

List<CustomerShop> filterCustomerShops(
  List<CustomerShop> shops,
  CustomerShopFilter filter,
) {
  final normCity = normalizeSearchText(filter.city);
  final query = PreparedSearchQuery.parse(filter.search);
  final scored = <({CustomerShop shop, double score, int index})>[];

  for (var i = 0; i < shops.length; i++) {
    final shop = shops[i];
    if (filter.onlyWithProducts && shop.productsCount <= 0) continue;
    if (normCity.isNotEmpty && normalizeSearchText(shop.city) != normCity) {
      continue;
    }
    var score = 0.0;
    if (query.hasTextTokens) {
      final s = query.score([
        SearchField(shop.name, 4.0),
        SearchField(shop.city, 2.5),
        SearchField(shop.description, 1.8),
        SearchField(shop.address, 1.2),
      ]);
      if (s == null) continue;
      score = s;
    }
    scored.add((shop: shop, score: score, index: i));
  }

  if (query.hasTextTokens &&
      (filter.sort == ShopSortOption.defaultOrder ||
          filter.sort == ShopSortOption.newest)) {
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
  }

  final filtered = scored.map((e) => e.shop).toList();

  switch (filter.sort) {
    case ShopSortOption.defaultOrder:
    case ShopSortOption.newest:
      break;
    case ShopSortOption.productsDesc:
      filtered.sort((a, b) => b.productsCount.compareTo(a.productsCount));
    case ShopSortOption.nameAsc:
      filtered.sort((a, b) => a.name.compareTo(b.name));
  }
  return filtered;
}

// ---------------------------------------------------------------------------
// 3. Orders Filter (Customer, Shop, Admin)
// ---------------------------------------------------------------------------

class OrderFilterState {
  const OrderFilterState({
    this.search = '',
    this.status,
    this.shopName,
    this.shopId,
    this.datePreset = DateRangePreset.all,
    this.minTotal,
    this.maxTotal,
    this.sort = OrderSortOption.newest,
  });

  static const OrderFilterState empty = OrderFilterState();

  final String search;
  final String? status;
  final String? shopName;
  final String? shopId;
  final DateRangePreset datePreset;
  final double? minTotal;
  final double? maxTotal;
  final OrderSortOption sort;

  OrderFilterState copyWith({
    String? search,
    String? status,
    String? shopName,
    String? shopId,
    DateRangePreset? datePreset,
    double? minTotal,
    double? maxTotal,
    OrderSortOption? sort,
    bool clearStatus = false,
    bool clearShopName = false,
    bool clearShopId = false,
    bool clearTotalRange = false,
  }) {
    return OrderFilterState(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      shopName: clearShopName ? null : (shopName ?? this.shopName),
      shopId: clearShopId ? null : (shopId ?? this.shopId),
      datePreset: datePreset ?? this.datePreset,
      minTotal: clearTotalRange ? null : (minTotal ?? this.minTotal),
      maxTotal: clearTotalRange ? null : (maxTotal ?? this.maxTotal),
      sort: sort ?? this.sort,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (status != null && status!.trim().isNotEmpty) count++;
    if (shopName != null && shopName!.trim().isNotEmpty) count++;
    if (shopId != null && shopId!.trim().isNotEmpty) count++;
    if (datePreset != DateRangePreset.all) count++;
    if (minTotal != null || maxTotal != null) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 ||
      search.trim().isNotEmpty ||
      sort != OrderSortOption.newest;
}

void _sortByOrder<T>(
  List<T> items,
  OrderSortOption sort,
  DateTime Function(T) getDate,
  double Function(T) getTotal,
) {
  switch (sort) {
    case OrderSortOption.newest:
      items.sort((a, b) => getDate(b).compareTo(getDate(a)));
    case OrderSortOption.oldest:
      items.sort((a, b) => getDate(a).compareTo(getDate(b)));
    case OrderSortOption.totalDesc:
      items.sort((a, b) => getTotal(b).compareTo(getTotal(a)));
    case OrderSortOption.totalAsc:
      items.sort((a, b) => getTotal(a).compareTo(getTotal(b)));
  }
}

List<CustomerOrder> filterCustomerOrders(
  List<CustomerOrder> orders,
  OrderFilterState filter, {
  DateTime? now,
}) {
  final normShop = normalizeSearchText(filter.shopName);
  final filtered = orders.where((order) {
    if (filter.status != null &&
        filter.status!.isNotEmpty &&
        order.status != filter.status) {
      return false;
    }
    if (filter.shopId != null &&
        filter.shopId!.isNotEmpty &&
        order.shopId != filter.shopId) {
      return false;
    }
    if (normShop.isNotEmpty && normalizeSearchText(order.shopName) != normShop) {
      return false;
    }
    if (!filter.datePreset.matches(order.createdAt, now: now)) return false;
    if (!matchesNumberRange(order.total, filter.minTotal, filter.maxTotal)) {
      return false;
    }
    return matchesSearchTokens(filter.search, [
      order.id,
      order.shopName,
      order.statusLabel,
      order.deliveryAddress,
      order.phone,
      order.notes,
      ...order.items.map((item) => item.productName),
    ]);
  }).toList();

  _sortByOrder(filtered, filter.sort, (o) => o.createdAt, (o) => o.total);
  return filtered;
}

List<ShopOrder> filterShopOrders(
  List<ShopOrder> orders,
  OrderFilterState filter, {
  DateTime? now,
}) {
  final filtered = orders.where((order) {
    if (filter.status != null &&
        filter.status!.isNotEmpty &&
        order.status != filter.status) {
      return false;
    }
    if (!filter.datePreset.matches(order.createdAt, now: now)) return false;
    if (!matchesNumberRange(order.total, filter.minTotal, filter.maxTotal)) {
      return false;
    }
    return matchesSearchTokens(filter.search, [
      order.id,
      order.customerName,
      order.customerEmail,
      order.statusLabel,
      order.status,
    ]);
  }).toList();

  _sortByOrder(filtered, filter.sort, (o) => o.createdAt, (o) => o.total);
  return filtered;
}

List<AdminOrder> filterAdminOrders(
  List<AdminOrder> orders,
  OrderFilterState filter, {
  DateTime? now,
}) {
  final normShop = normalizeSearchText(filter.shopName);
  final filtered = orders.where((order) {
    if (filter.status != null &&
        filter.status!.isNotEmpty &&
        order.status != filter.status) {
      return false;
    }
    if (normShop.isNotEmpty && normalizeSearchText(order.shopName) != normShop) {
      return false;
    }
    if (!filter.datePreset.matches(order.createdAt, now: now)) return false;
    if (!matchesNumberRange(order.total, filter.minTotal, filter.maxTotal)) {
      return false;
    }
    return matchesSearchTokens(filter.search, [
      order.id,
      order.shopName,
      order.customerEmail,
      order.status,
    ]);
  }).toList();

  _sortByOrder(filtered, filter.sort, (o) => o.createdAt, (o) => o.total);
  return filtered;
}

// ---------------------------------------------------------------------------
// 4. Shop Seller Products Filter
// ---------------------------------------------------------------------------

class ShopProductFilterState {
  const ShopProductFilterState({
    this.search = '',
    this.status,
    this.categoryId,
    this.stockFilter = StockFilter.all,
    this.minPrice,
    this.maxPrice,
    this.sort = ProductSortOption.newest,
  });

  static const ShopProductFilterState empty = ShopProductFilterState();

  final String search;
  final String? status;
  final String? categoryId;
  final StockFilter stockFilter;
  final double? minPrice;
  final double? maxPrice;
  final ProductSortOption sort;

  ShopProductFilterState copyWith({
    String? search,
    String? status,
    String? categoryId,
    StockFilter? stockFilter,
    double? minPrice,
    double? maxPrice,
    ProductSortOption? sort,
    bool clearStatus = false,
    bool clearCategory = false,
    bool clearPriceRange = false,
  }) {
    return ShopProductFilterState(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      stockFilter: stockFilter ?? this.stockFilter,
      minPrice: clearPriceRange ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPriceRange ? null : (maxPrice ?? this.maxPrice),
      sort: sort ?? this.sort,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (status != null && status!.isNotEmpty) count++;
    if (categoryId != null && categoryId!.isNotEmpty) count++;
    if (stockFilter != StockFilter.all) count++;
    if (minPrice != null || maxPrice != null) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 ||
      search.trim().isNotEmpty ||
      sort != ProductSortOption.newest;
}

List<ShopProduct> filterShopProducts(
  List<ShopProduct> products,
  ShopProductFilterState filter,
) {
  final query = PreparedSearchQuery.parse(filter.search);
  final minPrice = _tighterMin(filter.minPrice, query.intent.minPrice);
  final maxPrice = _tighterMax(filter.maxPrice, query.intent.maxPrice);
  final scored = <({ShopProduct product, double score, int index})>[];

  for (var i = 0; i < products.length; i++) {
    final product = products[i];
    if (filter.status != null &&
        filter.status!.isNotEmpty &&
        product.status != filter.status) {
      continue;
    }
    if (filter.categoryId != null &&
        filter.categoryId!.isNotEmpty &&
        product.categoryId != filter.categoryId) {
      continue;
    }
    if (!filter.stockFilter.matchesStock(product.totalStock)) {
      continue;
    }
    if (!matchesNumberRange(product.price, minPrice, maxPrice)) {
      continue;
    }
    var score = 0.0;
    if (query.hasTextTokens) {
      final detectedImageColors = VisualSearchService.instance
          .getCachedProductImageColors(product.coverImage);
      final s = query.score([
        SearchField(product.name, 4.0),
        SearchField(product.categoryName, 3.0),
        SearchField(
          product.variants.map((v) => '${v.color} ${v.size} ${v.stock}').join(' '),
          2.6,
        ),
        SearchField(_flattenJsonMapValues(product.details).join(' '), 2.0),
        SearchField(product.description, 1.6),
        SearchField(product.statusLabel, 1.4),
        SearchField(
          '${product.price.toInt()} ${product.price.toStringAsFixed(0)} ${product.price}',
          1.2,
        ),
        SearchField(detectedImageColors.join(' '), 0.8),
        SearchField(product.id, 0.5),
      ]);
      if (s == null) continue;
      score = s;
    }
    scored.add((product: product, score: score, index: i));
  }

  if (query.hasTextTokens && filter.sort == ProductSortOption.newest) {
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
  }

  final filtered = scored.map((e) => e.product).toList();

  switch (filter.sort) {
    case ProductSortOption.newest:
    case ProductSortOption.topRated:
      break;
    case ProductSortOption.priceAsc:
      filtered.sort((a, b) => a.price.compareTo(b.price));
    case ProductSortOption.priceDesc:
      filtered.sort((a, b) => b.price.compareTo(a.price));
    case ProductSortOption.nameAsc:
      filtered.sort((a, b) => a.name.compareTo(b.name));
    case ProductSortOption.stockAsc:
      filtered.sort((a, b) => a.totalStock.compareTo(b.totalStock));
    case ProductSortOption.stockDesc:
      filtered.sort((a, b) => b.totalStock.compareTo(a.totalStock));
  }

  return filtered;
}

// ---------------------------------------------------------------------------
// 5. Admin Products Filter
// ---------------------------------------------------------------------------

class AdminProductFilterState {
  const AdminProductFilterState({
    this.search = '',
    this.status,
    this.shopName,
    this.categoryName,
    this.minPrice,
    this.maxPrice,
    this.sort = ProductSortOption.newest,
  });

  static const AdminProductFilterState empty = AdminProductFilterState();

  final String search;
  final String? status;
  final String? shopName;
  final String? categoryName;
  final double? minPrice;
  final double? maxPrice;
  final ProductSortOption sort;

  AdminProductFilterState copyWith({
    String? search,
    String? status,
    String? shopName,
    String? categoryName,
    double? minPrice,
    double? maxPrice,
    ProductSortOption? sort,
    bool clearStatus = false,
    bool clearShopName = false,
    bool clearCategoryName = false,
    bool clearPriceRange = false,
  }) {
    return AdminProductFilterState(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      shopName: clearShopName ? null : (shopName ?? this.shopName),
      categoryName: clearCategoryName
          ? null
          : (categoryName ?? this.categoryName),
      minPrice: clearPriceRange ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPriceRange ? null : (maxPrice ?? this.maxPrice),
      sort: sort ?? this.sort,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (status != null && status!.isNotEmpty) count++;
    if (shopName != null && shopName!.isNotEmpty) count++;
    if (categoryName != null && categoryName!.isNotEmpty) count++;
    if (minPrice != null || maxPrice != null) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 ||
      search.trim().isNotEmpty ||
      sort != ProductSortOption.newest;
}

List<AdminProduct> filterAdminProducts(
  List<AdminProduct> products,
  AdminProductFilterState filter,
) {
  final normShop = normalizeSearchText(filter.shopName);
  final normCategory = normalizeSearchText(filter.categoryName);
  final query = PreparedSearchQuery.parse(filter.search);
  final minPrice = _tighterMin(filter.minPrice, query.intent.minPrice);
  final maxPrice = _tighterMax(filter.maxPrice, query.intent.maxPrice);
  final scored = <({AdminProduct product, double score, int index})>[];

  for (var i = 0; i < products.length; i++) {
    final product = products[i];
    if (filter.status != null &&
        filter.status!.isNotEmpty &&
        product.status != filter.status) {
      continue;
    }
    if (normShop.isNotEmpty &&
        normalizeSearchText(product.shopName) != normShop) {
      continue;
    }
    if (normCategory.isNotEmpty &&
        normalizeSearchText(product.categoryName) != normCategory) {
      continue;
    }
    if (!matchesNumberRange(product.price, minPrice, maxPrice)) {
      continue;
    }
    var score = 0.0;
    if (query.hasTextTokens) {
      final s = query.score([
        SearchField(product.name, 4.0),
        SearchField(product.categoryName, 2.8),
        SearchField(product.shopName, 2.5),
        SearchField(product.description, 1.6),
        SearchField('${product.statusLabel} ${product.status}', 1.3),
        SearchField(
          '${product.price.toInt()} ${product.price.toStringAsFixed(0)} ${product.price}',
          1.2,
        ),
        SearchField(product.id, 0.5),
      ]);
      if (s == null) continue;
      score = s;
    }
    scored.add((product: product, score: score, index: i));
  }

  if (query.hasTextTokens && filter.sort == ProductSortOption.newest) {
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
  }

  final filtered = scored.map((e) => e.product).toList();

  switch (filter.sort) {
    case ProductSortOption.newest:
    case ProductSortOption.topRated:
    case ProductSortOption.stockAsc:
    case ProductSortOption.stockDesc:
      break;
    case ProductSortOption.priceAsc:
      filtered.sort((a, b) => a.price.compareTo(b.price));
    case ProductSortOption.priceDesc:
      filtered.sort((a, b) => b.price.compareTo(a.price));
    case ProductSortOption.nameAsc:
      filtered.sort((a, b) => a.name.compareTo(b.name));
  }

  return filtered;
}

// ---------------------------------------------------------------------------
// 6. Admin Shops & Applications Filter
// ---------------------------------------------------------------------------

class AdminShopFilterState {
  const AdminShopFilterState({
    this.search = '',
    this.status,
    this.city,
    this.sort = ShopSortOption.newest,
  });

  static const AdminShopFilterState empty = AdminShopFilterState();

  final String search;
  final ShopStatus? status;
  final String? city;
  final ShopSortOption sort;

  AdminShopFilterState copyWith({
    String? search,
    ShopStatus? status,
    String? city,
    ShopSortOption? sort,
    bool clearStatus = false,
    bool clearCity = false,
  }) {
    return AdminShopFilterState(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      city: clearCity ? null : (city ?? this.city),
      sort: sort ?? this.sort,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (status != null) count++;
    if (city != null && city!.trim().isNotEmpty) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 ||
      search.trim().isNotEmpty ||
      sort != ShopSortOption.newest;
}

List<Shop> filterAdminShops(List<Shop> shops, AdminShopFilterState filter) {
  final normCity = normalizeSearchText(filter.city);
  final filtered = shops.where((shop) {
    if (filter.status != null && shop.status != filter.status) {
      return false;
    }
    if (normCity.isNotEmpty && normalizeSearchText(shop.city) != normCity) {
      return false;
    }
    return matchesSearchTokens(filter.search, [
      shop.name,
      shop.description,
      shop.city,
      shop.address,
      shop.ownerName,
      shop.ownerEmail,
      shop.ownerPhone,
      shop.commercialRegister,
      shop.status.labelAr,
    ]);
  }).toList();

  switch (filter.sort) {
    case ShopSortOption.defaultOrder:
    case ShopSortOption.productsDesc:
      break;
    case ShopSortOption.newest:
      filtered.sort((a, b) {
        final da = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    case ShopSortOption.nameAsc:
      filtered.sort((a, b) => a.name.compareTo(b.name));
  }
  return filtered;
}

// ---------------------------------------------------------------------------
// 7. Admin Users Filter
// ---------------------------------------------------------------------------

class AdminUserFilterState {
  const AdminUserFilterState({
    this.search = '',
    this.role,
    this.activeFilter = ActiveStateFilter.all,
    this.profileCompleted,
    this.city,
    this.sortByNameAsc = false,
  });

  static const AdminUserFilterState empty = AdminUserFilterState();

  final String search;
  final UserRole? role;
  final ActiveStateFilter activeFilter;
  final bool? profileCompleted;
  final String? city;
  final bool sortByNameAsc;

  AdminUserFilterState copyWith({
    String? search,
    UserRole? role,
    ActiveStateFilter? activeFilter,
    bool? profileCompleted,
    String? city,
    bool? sortByNameAsc,
    bool clearRole = false,
    bool clearProfileCompleted = false,
    bool clearCity = false,
  }) {
    return AdminUserFilterState(
      search: search ?? this.search,
      role: clearRole ? null : (role ?? this.role),
      activeFilter: activeFilter ?? this.activeFilter,
      profileCompleted: clearProfileCompleted
          ? null
          : (profileCompleted ?? this.profileCompleted),
      city: clearCity ? null : (city ?? this.city),
      sortByNameAsc: sortByNameAsc ?? this.sortByNameAsc,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (role != null) count++;
    if (activeFilter != ActiveStateFilter.all) count++;
    if (profileCompleted != null) count++;
    if (city != null && city!.trim().isNotEmpty) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 || search.trim().isNotEmpty || sortByNameAsc;
}

List<AppUser> filterAdminUsers(
  List<AppUser> users,
  AdminUserFilterState filter,
) {
  final normCity = normalizeSearchText(filter.city);
  final filtered = users.where((user) {
    if (filter.role != null && user.role != filter.role) return false;
    if (!filter.activeFilter.matches(user.isActive)) return false;
    if (filter.profileCompleted != null &&
        user.profileCompleted != filter.profileCompleted) {
      return false;
    }
    if (normCity.isNotEmpty && normalizeSearchText(user.city) != normCity) {
      return false;
    }
    return matchesSearchTokens(filter.search, [
      user.displayName,
      user.fullName,
      user.email,
      user.phone,
      user.city,
      user.address,
      user.role.labelAr,
    ]);
  }).toList();

  if (filter.sortByNameAsc) {
    filtered.sort((a, b) => a.displayName.compareTo(b.displayName));
  }
  return filtered;
}

// ---------------------------------------------------------------------------
// 8. Notifications Filter (Customer, Shop, Admin)
// ---------------------------------------------------------------------------

class NotificationFilterState {
  const NotificationFilterState({
    this.search = '',
    this.audience,
    this.datePreset = DateRangePreset.all,
    this.oldestFirst = false,
  });

  static const NotificationFilterState empty = NotificationFilterState();

  final String search;
  final String? audience;
  final DateRangePreset datePreset;
  final bool oldestFirst;

  NotificationFilterState copyWith({
    String? search,
    String? audience,
    DateRangePreset? datePreset,
    bool? oldestFirst,
    bool clearAudience = false,
  }) {
    return NotificationFilterState(
      search: search ?? this.search,
      audience: clearAudience ? null : (audience ?? this.audience),
      datePreset: datePreset ?? this.datePreset,
      oldestFirst: oldestFirst ?? this.oldestFirst,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (audience != null && audience!.isNotEmpty) count++;
    if (datePreset != DateRangePreset.all) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 || search.trim().isNotEmpty || oldestFirst;
}

List<AdminNotification> filterNotifications(
  List<AdminNotification> notifications,
  NotificationFilterState filter, {
  DateTime? now,
}) {
  final filtered = notifications.where((item) {
    if (filter.audience != null &&
        filter.audience!.isNotEmpty &&
        item.audience != filter.audience) {
      return false;
    }
    if (!filter.datePreset.matches(item.createdAt, now: now)) return false;
    return matchesSearchTokens(filter.search, [
      item.title,
      item.body,
      item.audienceLabel,
    ]);
  }).toList();

  filtered.sort(
    (a, b) => filter.oldestFirst
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt),
  );
  return filtered;
}

// ---------------------------------------------------------------------------
// 9. Categories & Banners Filter (Admin)
// ---------------------------------------------------------------------------

class CatalogListFilterState {
  const CatalogListFilterState({
    this.search = '',
    this.activeFilter = ActiveStateFilter.all,
    this.sort = DisplayOrderSort.displayOrder,
  });

  static const CatalogListFilterState empty = CatalogListFilterState();

  final String search;
  final ActiveStateFilter activeFilter;
  final DisplayOrderSort sort;

  CatalogListFilterState copyWith({
    String? search,
    ActiveStateFilter? activeFilter,
    DisplayOrderSort? sort,
  }) {
    return CatalogListFilterState(
      search: search ?? this.search,
      activeFilter: activeFilter ?? this.activeFilter,
      sort: sort ?? this.sort,
    );
  }

  int get activeFacetCount => activeFilter != ActiveStateFilter.all ? 1 : 0;

  bool get hasActiveFilters =>
      activeFacetCount > 0 ||
      search.trim().isNotEmpty ||
      sort != DisplayOrderSort.displayOrder;
}

List<CatalogCategory> filterAdminCategories(
  List<CatalogCategory> categories,
  CatalogListFilterState filter,
) {
  final filtered = categories.where((c) {
    if (!filter.activeFilter.matches(c.isActive)) return false;
    return matchesSearchTokens(filter.search, [c.name, c.description]);
  }).toList();

  switch (filter.sort) {
    case DisplayOrderSort.displayOrder:
      break;
    case DisplayOrderSort.nameAsc:
      filtered.sort((a, b) => a.name.compareTo(b.name));
    case DisplayOrderSort.nameDesc:
      filtered.sort((a, b) => b.name.compareTo(a.name));
  }
  return filtered;
}

List<AdminBanner> filterAdminBanners(
  List<AdminBanner> banners,
  CatalogListFilterState filter,
) {
  final filtered = banners.where((b) {
    if (!filter.activeFilter.matches(b.isActive)) return false;
    return matchesSearchTokens(filter.search, [b.title, b.subtitle]);
  }).toList();

  switch (filter.sort) {
    case DisplayOrderSort.displayOrder:
      filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    case DisplayOrderSort.nameAsc:
      filtered.sort((a, b) => a.title.compareTo(b.title));
    case DisplayOrderSort.nameDesc:
      filtered.sort((a, b) => b.title.compareTo(a.title));
  }
  return filtered;
}

// ---------------------------------------------------------------------------
// 10. Product Reviews Filter (Customer Product Details)
// ---------------------------------------------------------------------------

class ReviewFilterState {
  const ReviewFilterState({
    this.rating,
    this.withCommentOnly = false,
    this.sort = ReviewSortOption.newest,
  });

  static const ReviewFilterState empty = ReviewFilterState();

  final int? rating;
  final bool withCommentOnly;
  final ReviewSortOption sort;

  ReviewFilterState copyWith({
    int? rating,
    bool? withCommentOnly,
    ReviewSortOption? sort,
    bool clearRating = false,
  }) {
    return ReviewFilterState(
      rating: clearRating ? null : (rating ?? this.rating),
      withCommentOnly: withCommentOnly ?? this.withCommentOnly,
      sort: sort ?? this.sort,
    );
  }

  int get activeFacetCount {
    var count = 0;
    if (rating != null) count++;
    if (withCommentOnly) count++;
    return count;
  }

  bool get hasActiveFilters =>
      activeFacetCount > 0 || sort != ReviewSortOption.newest;
}

List<ProductReview> filterProductReviews(
  List<ProductReview> reviews,
  ReviewFilterState filter,
) {
  final filtered = reviews.where((review) {
    if (filter.rating != null && review.rating != filter.rating) return false;
    if (filter.withCommentOnly &&
        (review.comment == null || review.comment!.trim().isEmpty)) {
      return false;
    }
    return true;
  }).toList();

  switch (filter.sort) {
    case ReviewSortOption.newest:
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case ReviewSortOption.highestRating:
      filtered.sort((a, b) {
        final byRate = b.rating.compareTo(a.rating);
        return byRate != 0 ? byRate : b.createdAt.compareTo(a.createdAt);
      });
    case ReviewSortOption.lowestRating:
      filtered.sort((a, b) {
        final byRate = a.rating.compareTo(b.rating);
        return byRate != 0 ? byRate : b.createdAt.compareTo(a.createdAt);
      });
  }
  return filtered;
}
