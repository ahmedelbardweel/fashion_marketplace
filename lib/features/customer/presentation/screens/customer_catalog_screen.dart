import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

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

  void _openFilterBottomSheet() {
    final currentFilter = ref.read(productFilterProvider);
    final categories = ref.read(customerCategoriesProvider).value ?? [];

    String? selectedCategory = currentFilter.categoryId;
    String? selectedColor = currentFilter.color;
    String? selectedSize = currentFilter.size;
    double? minPrice = currentFilter.minPrice;
    double? maxPrice = currentFilter.maxPrice;

    final minPriceController = TextEditingController(
      text: minPrice != null ? minPrice.toStringAsFixed(0) : '',
    );
    final maxPriceController = TextEditingController(
      text: maxPrice != null ? maxPrice.toStringAsFixed(0) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.bottomSheet)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تصفية المنتجات',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              selectedCategory = null;
                              selectedColor = null;
                              selectedSize = null;
                              minPriceController.clear();
                              maxPriceController.clear();
                            });
                          },
                          child: const Text('إعادة ضبط'),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),

                    // Category
                    Text('التصنيف', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: categories.map((cat) {
                        final isSelected = selectedCategory == cat.id;
                        return ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: AppColors.black,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.white : AppColors.black,
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              selectedCategory = val ? cat.id : null;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Price Range
                    Text('نطاق السعر (ر.س)', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'من',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'إلى',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Sizes
                    Text('المقاس', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: ['XS', 'S', 'M', 'L', 'XL', 'XXL'].map((sz) {
                        final isSelected = selectedSize == sz;
                        return ChoiceChip(
                          label: Text(sz),
                          selected: isSelected,
                          selectedColor: AppColors.black,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.white : AppColors.black,
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              selectedSize = val ? sz : null;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    AppButton(
                      label: 'تطبيق الفلترة',
                      onPressed: () {
                        final minP = double.tryParse(minPriceController.text.trim());
                        final maxP = double.tryParse(maxPriceController.text.trim());

                        ref.read(productFilterProvider.notifier).state =
                            ref.read(productFilterProvider).copyWith(
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(productFilterProvider);
    final productsAsync = ref.watch(customerProductsProvider);
    final compareList = ref.watch(productComparisonProvider);

    return CustomerScaffold(
      title: 'استعراض الملابس',
      currentNavIndex: 1,
      showBack: false,
      actions: [
        IconButton(
          tooltip: 'تصفية وبحث متقدم',
          icon: Icon(
            filter.hasActiveFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: filter.hasActiveFilters ? AppColors.black : AppColors.gray700,
          ),
          onPressed: _openFilterBottomSheet,
        ),
      ],
      body: Column(
        children: [
          // Live Search Bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم المنتج، الموديل، التفاصيل...',
                prefixIcon: const Icon(Icons.search, color: AppColors.gray500),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(productFilterProvider.notifier).state =
                              filter.copyWith(search: '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.gray100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (val) {
                ref.read(productFilterProvider.notifier).state =
                    filter.copyWith(search: val.trim());
              },
            ),
          ),

          // Active filter badges
          if (filter.hasActiveFilters) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (filter.categoryId != null)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: InputChip(
                          label: const Text('تصنيف محدد'),
                          onDeleted: () {
                            ref.read(productFilterProvider.notifier).state =
                                filter.copyWith(clearCategory: true);
                          },
                        ),
                      ),
                    if (filter.minPrice != null || filter.maxPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: InputChip(
                          label: Text(
                              'السعر: ${filter.minPrice ?? 0} - ${filter.maxPrice ?? '∞'}'),
                          onDeleted: () {
                            ref.read(productFilterProvider.notifier).state =
                                filter.copyWith(minPrice: null, maxPrice: null);
                          },
                        ),
                      ),
                    if (filter.size != null)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: InputChip(
                          label: Text('المقاس: ${filter.size}'),
                          onDeleted: () {
                            ref.read(productFilterProvider.notifier).state =
                                filter.copyWith(clearSize: true);
                          },
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(productFilterProvider.notifier).state =
                            const ProductFilter();
                      },
                      child: const Text('مسح الكل'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],

          // Products Grid
          Expanded(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 64, color: AppColors.gray300),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'لا توجد منتجات مطابقة للبحث أو الفلتر',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            ref.read(productFilterProvider.notifier).state =
                                const ProductFilter();
                          },
                          child: const Text('إعادة ضبط الفلاتر'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(customerProductsProvider);
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.58,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductGridCard(
                        imageUrl: product.coverImage,
                        title: product.name,
                        subtitle: product.shopName,
                        meta:
                            '${product.price.toStringAsFixed(2)} ر.س · مخزون ${product.totalStock}',
                        onTap: () => context.push(
                          AppRoutes.customerProductDetailsPath(product.id),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, _) => Center(
                child: Text('تعذر تحميل المنتجات: $err'),
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
                color: AppColors.black,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded, color: AppColors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'تم تحديد ${compareList.length} منتجات للمقارنة',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.white),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.customerCompare),
                    child: const Text(
                      'فتح المقارنة',
                      style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
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
