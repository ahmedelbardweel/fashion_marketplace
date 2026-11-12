import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/product_cart_sheet.dart';

class CustomerCatalogScreen extends ConsumerStatefulWidget {
  const CustomerCatalogScreen({super.key});

  @override
  ConsumerState<CustomerCatalogScreen> createState() =>
      _CustomerCatalogScreenState();
}

class _CustomerCatalogScreenState extends ConsumerState<CustomerCatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filter = ref.read(productFilterProvider);
    if (filter.search != null) {
      _searchController.text = filter.search!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(String productId) async {
    await ref.read(customerRepositoryProvider).toggleFavorite(productId);
    ref.invalidate(customerProductsProvider);
    ref.invalidate(customerFavoritesProvider);
    ref.invalidate(customerProductDetailsProvider(productId));
  }

  void _openFilterBottomSheet() {
    final currentFilter = ref.read(productFilterProvider);
    final categories = ref.read(customerCategoriesProvider).value ?? [];

    String? selectedCategory = currentFilter.categoryId;
    String? selectedColor = currentFilter.color;
    String? selectedSize = currentFilter.size;
    final double? minPrice = currentFilter.minPrice;
    final double? maxPrice = currentFilter.maxPrice;

    final minPriceController = TextEditingController(
      text: minPrice != null ? minPrice.toStringAsFixed(0) : '',
    );
    final maxPriceController = TextEditingController(
      text: maxPrice != null ? maxPrice.toStringAsFixed(0) : '',
    );

    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      child: AppBottomSheetScaffold(
        title: 'تصفية المنتجات',
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (categories.isNotEmpty) ...[
                  const Text(
                    'التصنيف',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat.id;
                      return ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: AppHaptics.change((val) {
                          setModalState(() {
                            selectedCategory = val ? cat.id : null;
                          });
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Price Range
                const Text(
                  'نطاق السعر (ر.س)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'الحد الأدنى'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: maxPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'الحد الأقصى'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Sizes
                const Text(
                  'المقاس',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: ['XS', 'S', 'M', 'L', 'XL', 'XXL'].map((sz) {
                    final isSelected = selectedSize == sz;
                    return ChoiceChip(
                      label: Text(sz),
                      selected: isSelected,
                      onSelected: AppHaptics.change((val) {
                        setModalState(() {
                          selectedSize = val ? sz : null;
                        });
                      }),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'إعادة ضبط',
                        variant: AppButtonVariant.outlined,
                        onPressed: () {
                          setModalState(() {
                            selectedCategory = null;
                            selectedColor = null;
                            selectedSize = null;
                            minPriceController.clear();
                            maxPriceController.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: 'تطبيق الفلترة',
                        onPressed: () {
                          final minP = double.tryParse(
                            minPriceController.text.trim(),
                          );
                          final maxP = double.tryParse(
                            maxPriceController.text.trim(),
                          );

                          ref.read(productFilterProvider.notifier).state = ref
                              .read(productFilterProvider)
                              .copyWith(
                                categoryId: selectedCategory,
                                color: selectedColor,
                                size: selectedSize,
                                minPrice: minP,
                                maxPrice: maxP,
                                clearCategory: selectedCategory == null,
                                clearColor: selectedColor == null,
                                clearSize: selectedSize == null,
                              );

                          Navigator.of(ctx).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(productFilterProvider);
    final categoriesAsync = ref.watch(customerCategoriesProvider);
    final productsAsync = ref.watch(customerProductsProvider);
    final compareList = ref.watch(productComparisonProvider);

    return CustomerScaffold(
      title: 'المنتجات',
      currentNavIndex: 1,
      showBack: false,
      actions: [
        IconButton(
          tooltip: 'تصفية وبحث متقدم',
          icon: Badge(
            isLabelVisible: filter.hasActiveFilters,
            backgroundColor: CatalogDesign.filterActiveDot,
            child: const Icon(
              AppIcons.filter,
              color: CatalogDesign.filterButtonIcon,
            ),
          ),
          onPressed: AppHaptics.action(_openFilterBottomSheet),
        ),
      ],
      body: Column(
        children: [
          // Horizontal Category Chips Bar
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 54,
                decoration: const BoxDecoration(
                  color: CatalogDesign.toolbarBackground,
                  border: Border(
                    bottom: BorderSide(color: CatalogDesign.toolbarBorder),
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final allSelected = filter.categoryId == null;
                      return _CategoryFilterPill(
                        label: 'الكل',
                        selected: allSelected,
                        onTap: () {
                          ref.read(productFilterProvider.notifier).state =
                              filter.copyWith(clearCategory: true);
                        },
                      );
                    }
                    final cat = categories[index - 1];
                    final selected = filter.categoryId == cat.id;
                    return _CategoryFilterPill(
                      label: cat.name,
                      selected: selected,
                      onTap: () {
                        ref.read(productFilterProvider.notifier).state =
                            selected
                            ? filter.copyWith(clearCategory: true)
                            : filter.copyWith(categoryId: cat.id);
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Active filter badges
          if (filter.hasActiveFilters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              color: AppColors.surfaceSubtle,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (filter.search != null && filter.search!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.xs,
                        ),
                        child: InputChip(
                          label: Text('بحث: ${filter.search}'),
                          onDeleted: AppHaptics.action(() {
                            _searchController.clear();
                            ref.read(productFilterProvider.notifier).state =
                                filter.copyWith(search: '');
                          }),
                        ),
                      ),
                    if (filter.minPrice != null || filter.maxPrice != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.xs,
                        ),
                        child: InputChip(
                          label: Text(
                            'السعر: ${filter.minPrice ?? 0} - ${filter.maxPrice ?? '∞'}',
                          ),
                          onDeleted: AppHaptics.action(() {
                            ref.read(productFilterProvider.notifier).state =
                                filter.copyWith(minPrice: null, maxPrice: null);
                          }),
                        ),
                      ),
                    if (filter.size != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpacing.xs,
                        ),
                        child: InputChip(
                          label: Text('المقاس: ${filter.size}'),
                          onDeleted: AppHaptics.action(() {
                            ref.read(productFilterProvider.notifier).state =
                                filter.copyWith(clearSize: true);
                          }),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: AppHaptics.action(() {
                        _searchController.clear();
                        ref.read(productFilterProvider.notifier).state =
                            const ProductFilter();
                      }),
                      icon: const Icon(AppIcons.refresh, size: 16),
                      label: const Text('مسح الكل'),
                    ),
                  ],
                ),
              ),
            ),

          // Products Grid
          Expanded(
            child: productsAsync.skeletonWhen(
              placeholder: LoadingFixtures.products,
              data: (products) {
                if (products.isEmpty) {
                  return AppEmpty(
                    icon: AppIcons.searchOff,
                    title: 'لا توجد منتجات مطابقة',
                    message: 'جرّب تغيير كلمات البحث أو إعادة ضبط الفلاتر',
                    actionLabel: filter.hasActiveFilters
                        ? 'إعادة ضبط الفلاتر'
                        : null,
                    onAction: filter.hasActiveFilters
                        ? AppHaptics.action(() {
                            _searchController.clear();
                            ref.read(productFilterProvider.notifier).state =
                                const ProductFilter();
                          })
                        : null,
                  );
                }

                return RefreshIndicator.noSpinner(
                  onRefresh: AppHaptics.refresh(() async {
                    ref.invalidate(customerProductsProvider);
                  }),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: products.length,
                    gridDelegate: ProductGridDelegate(
                      textScale:
                          MediaQuery.textScalerOf(context).scale(14) / 14,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductGridCard(
                        imageUrl: product.coverImage,
                        meta: AppFormat.price(product.price),
                        inStock: product.totalStock > 0,
                        isFavorite: product.isFavorite,
                        onToggleFavorite: () => _toggleFavorite(product.id),
                        onAddToCart: () =>
                            showProductCartSheet(context, product.id),
                        onTap: () => context.push(
                          AppRoutes.customerProductDetailsPath(product.id),
                        ),
                      );
                    },
                  ),
                );
              },
              error: (err, _) => AppEmpty(
                icon: AppIcons.error,
                message: 'تعذر تحميل المنتجات: $err',
              ),
            ),
          ),

          // Quick Compare Bottom Banner
          if (compareList.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                border: Border(
                  top: BorderSide(color: AppColors.primaryBorder),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.compare,
                    color: AppColors.icon,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'تم تحديد ${compareList.length} منتجات للمقارنة',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: AppHaptics.action(
                      () => context.push(AppRoutes.customerCompare),
                    ),
                    child: const Text(
                      'فتح المقارنة',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: AppFont.extraBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryFilterPill extends StatelessWidget {
  const _CategoryFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: AppHaptics.action(onTap),
      borderRadius: BorderRadius.circular(ChipDesign.radius),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: ChipDesign.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ChipDesign.selectedBackground : ChipDesign.background,
          borderRadius: BorderRadius.circular(ChipDesign.radius),
          border: Border.all(
            color: selected ? ChipDesign.selectedBorder : ChipDesign.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ChipDesign.textSize,
            fontWeight: selected
                ? ChipDesign.selectedWeight
                : ChipDesign.textWeight,
            color: selected ? ChipDesign.selectedText : ChipDesign.text,
          ),
        ),
      ),
    );
  }
}
