import 'package:flutter/material.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../../domain/models/customer_product.dart';
import '../../domain/models/customer_shop.dart';

/// Standard customer-facing sort options for fashion products.
const List<AppSortChoice<ProductSortOption>> kCustomerProductSortChoices = [
  AppSortChoice(
    value: ProductSortOption.newest,
    label: 'الأحدث',
    icon: AppIcons.sparkles,
  ),
  AppSortChoice(
    value: ProductSortOption.priceAsc,
    label: 'السعر: الأقل أولاً',
    icon: AppIcons.arrowUp,
  ),
  AppSortChoice(
    value: ProductSortOption.priceDesc,
    label: 'السعر: الأعلى أولاً',
    icon: AppIcons.arrowDown,
  ),
  AppSortChoice(
    value: ProductSortOption.topRated,
    label: 'الأعلى تقييماً',
    icon: AppIcons.starFilled,
  ),
  AppSortChoice(
    value: ProductSortOption.nameAsc,
    label: 'الاسم: أ - ي',
    icon: AppIcons.catalog,
  ),
];

/// Builds removable active filter tags for a [ProductFilter].
List<AppActiveFilterTag> buildCustomerProductActiveTags({
  required ProductFilter filter,
  required ValueChanged<ProductFilter> onChanged,
  List<CatalogCategory> categories = const [],
  List<CustomerShop> shops = const [],
  bool includeCategoryTag = true,
  bool includeShopTag = true,
}) {
  final tags = <AppActiveFilterTag>[];

  if (includeCategoryTag &&
      filter.categoryId != null &&
      filter.categoryId!.isNotEmpty) {
    final categoryName = categories
        .where((c) => c.id == filter.categoryId)
        .map((c) => c.name)
        .firstOrNull;
    tags.add(
      AppActiveFilterTag(
        label: categoryName != null
            ? '${'التصنيف: '.tr}$categoryName'.trim()
            : 'التصنيف'.tr,
        onRemove: () => onChanged(filter.copyWith(clearCategory: true)),
      ),
    );
  }

  if (includeShopTag && filter.shopId != null && filter.shopId!.isNotEmpty) {
    final shopName = shops
        .where((s) => s.id == filter.shopId)
        .map((s) => s.name)
        .firstOrNull;
    if (shopName != null) {
      tags.add(
        AppActiveFilterTag(
          label: 'المتجر: $shopName'.tr,
          onRemove: () => onChanged(filter.copyWith(clearShop: true)),
        ),
      );
    }
  }

  if (filter.minPrice != null || filter.maxPrice != null) {
    final String label;
    if (filter.minPrice != null && filter.maxPrice != null) {
      label =
          'السعر: من ${filter.minPrice!.toStringAsFixed(0)} إلى ${filter.maxPrice!.toStringAsFixed(0)}'
              .tr;
    } else if (filter.minPrice != null) {
      label = 'السعر: من ${filter.minPrice!.toStringAsFixed(0)}'.tr;
    } else {
      label = 'السعر: حتى ${filter.maxPrice!.toStringAsFixed(0)}'.tr;
    }
    tags.add(
      AppActiveFilterTag(
        label: label,
        onRemove: () => onChanged(filter.copyWith(clearPrice: true)),
      ),
    );
  }

  if (filter.color != null && filter.color!.trim().isNotEmpty) {
    tags.add(
      AppActiveFilterTag(
        label: 'اللون: ${filter.color!}'.tr,
        swatchColor: resolveColorSwatch(filter.color!),
        onRemove: () => onChanged(filter.copyWith(clearColor: true)),
      ),
    );
  }

  if (filter.size != null && filter.size!.trim().isNotEmpty) {
    tags.add(
      AppActiveFilterTag(
        label: 'المقاس: ${filter.size!}'.tr,
        onRemove: () => onChanged(filter.copyWith(clearSize: true)),
      ),
    );
  }

  if (filter.minRating != null) {
    tags.add(
      AppActiveFilterTag(
        label: 'التقييم: ${filter.minRating!.toStringAsFixed(0)}+ نجوم'.tr,
        onRemove: () => onChanged(filter.copyWith(clearMinRating: true)),
      ),
    );
  }

  if (filter.inStockOnly) {
    tags.add(
      AppActiveFilterTag(
        label: 'متوفر فقط'.tr,
        onRemove: () => onChanged(filter.copyWith(inStockOnly: false)),
      ),
    );
  }

  return tags;
}

/// Opens the comprehensive product filter sheet across customer surfaces.
Future<ProductFilter?> showCustomerProductFilterSheet({
  required BuildContext context,
  required ProductFilter initial,
  required List<CustomerProduct> sourceProducts,
  List<CatalogCategory> categories = const [],
  List<CustomerShop> shops = const [],
  bool showCategorySection = true,
  bool showShopSection = true,
}) {
  final availableColors = extractProductColors(sourceProducts);
  final availableSizes = extractProductSizes(sourceProducts);

  return AppBottomSheet.show<ProductFilter>(
    context: context,
    isScrollControlled: true,
    child: _ProductFilterSheetBody(
      initial: initial,
      categories: categories,
      shops: shops,
      availableColors: availableColors,
      availableSizes: availableSizes,
      showCategorySection: showCategorySection,
      showShopSection: showShopSection,
    ),
  );
}

class _ProductFilterSheetBody extends StatefulWidget {
  const _ProductFilterSheetBody({
    required this.initial,
    required this.categories,
    required this.shops,
    required this.availableColors,
    required this.availableSizes,
    required this.showCategorySection,
    required this.showShopSection,
  });

  final ProductFilter initial;
  final List<CatalogCategory> categories;
  final List<CustomerShop> shops;
  final List<String> availableColors;
  final List<String> availableSizes;
  final bool showCategorySection;
  final bool showShopSection;

  @override
  State<_ProductFilterSheetBody> createState() =>
      _ProductFilterSheetBodyState();
}

class _ProductFilterSheetBodyState extends State<_ProductFilterSheetBody> {
  late ProductFilter _draft;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _minController = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  ProductFilter _resolvedDraft() {
    final minP = double.tryParse(_minController.text.trim());
    final maxP = double.tryParse(_maxController.text.trim());
    return _draft.copyWith(
      minPrice: minP,
      maxPrice: maxP,
      clearMinPrice: minP == null,
      clearMaxPrice: maxP == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _resolvedDraft();

    return AppFilterSheetScaffold(
      title: 'تصفية المنتجات',
      activeCount: current.activeFacetCount,
      onReset: () {
        _minController.clear();
        _maxController.clear();
        setState(() {
          _draft = ProductFilter(
            search: _draft.search,
            shopId: widget.showShopSection ? null : _draft.shopId,
          );
        });
      },
      onApply: () => Navigator.of(context).pop(_resolvedDraft()),
      children: [
        AppFilterSection(
          title: 'ترتيب النتائج',
          child: AppFilterChoiceWrap<ProductSortOption>(
            options: kCustomerProductSortChoices.map((e) => e.value).toList(),
            selectedValue: _draft.sort,
            allowDeselect: false,
            labelBuilder: (opt) => opt.labelAr,
            onSelected: (opt) {
              if (opt != null) setState(() => _draft = _draft.copyWith(sort: opt));
            },
          ),
        ),
        if (widget.showCategorySection && widget.categories.isNotEmpty)
          AppFilterSection(
            title: 'التصنيف',
            child: AppFilterChoiceWrap<String>(
              options: widget.categories.map((c) => c.id).toList(),
              selectedValue: _draft.categoryId,
              allLabel: 'الكل',
              labelBuilder: (id) =>
                  widget.categories.firstWhere((c) => c.id == id).name,
              onSelected: (id) => setState(
                () => _draft = id == null
                    ? _draft.copyWith(clearCategory: true)
                    : _draft.copyWith(categoryId: id),
              ),
            ),
          ),
        if (widget.showShopSection && widget.shops.isNotEmpty)
          AppFilterSection(
            title: 'المتجر',
            child: AppFilterChoiceWrap<String>(
              options: widget.shops.map((s) => s.id).toList(),
              selectedValue: _draft.shopId,
              allLabel: 'الكل',
              labelBuilder: (id) =>
                  widget.shops.firstWhere((s) => s.id == id).name,
              onSelected: (id) => setState(
                () => _draft = id == null
                    ? _draft.copyWith(clearShop: true)
                    : _draft.copyWith(shopId: id),
              ),
            ),
          ),
        AppFilterSection(
          title: 'نطاق السعر',
          child: AppFilterRangeInputs(
            minController: _minController,
            maxController: _maxController,
            presets: const [
              ('أقل من 150', null, 150),
              ('150 - 350', 150, 350),
              ('350 - 700', 350, 700),
              ('أكثر من 700', 700, null),
            ],
            onPresetSelected: (min, max) => setState(() {
              _draft = _draft.copyWith(
                minPrice: min,
                maxPrice: max,
                clearMinPrice: min == null,
                clearMaxPrice: max == null,
              );
            }),
          ),
        ),
        if (widget.availableSizes.isNotEmpty)
          AppFilterSection(
            title: 'المقاس',
            child: AppFilterChoiceWrap<String>(
              options: widget.availableSizes,
              selectedValue: _draft.size,
              allLabel: 'الكل',
              labelBuilder: (s) => s,
              onSelected: (size) => setState(
                () => _draft = size == null
                    ? _draft.copyWith(clearSize: true)
                    : _draft.copyWith(size: size),
              ),
            ),
          ),
        if (widget.availableColors.isNotEmpty)
          AppFilterSection(
            title: 'اللون',
            child: AppFilterColorWrap(
              colors: widget.availableColors,
              selectedColor: _draft.color,
              onSelected: (color) => setState(
                () => _draft = color == null
                    ? _draft.copyWith(clearColor: true)
                    : _draft.copyWith(color: color),
              ),
            ),
          ),
        AppFilterSection(
          title: 'التقييم',
          child: AppFilterChoiceWrap<double>(
            options: const [4.0, 3.0],
            selectedValue: _draft.minRating,
            allLabel: 'الكل',
            labelBuilder: (r) => '${r.toStringAsFixed(0)}★ فأعلى',
            onSelected: (rating) => setState(
              () => _draft = rating == null
                  ? _draft.copyWith(clearMinRating: true)
                  : _draft.copyWith(minRating: rating),
            ),
          ),
        ),
        AppFilterSwitchRow(
          title: 'المتوفر في المخزون فقط',
          subtitle: 'إخفاء المنتجات غير المتوفرة حالياً',
          value: _draft.inStockOnly,
          onChanged: (val) =>
              setState(() => _draft = _draft.copyWith(inStockOnly: val)),
        ),
      ],
    );
  }
}
