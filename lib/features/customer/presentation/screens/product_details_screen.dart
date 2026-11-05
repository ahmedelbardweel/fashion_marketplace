import '../../../../core/widgets/app_bottom_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<CustomerProduct> _recommendedProducts = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 6;

  int _currentImageIndex = 0;
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;
  bool _togglingFavorite = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreProducts();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= maxScroll - 350) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(customerRepositoryProvider)
          .getProducts(
            excludeProductId: widget.productId,
            limit: _pageSize,
            offset: _recommendedProducts.length,
          );
      if (!mounted) return;
      setState(() {
        _recommendedProducts.addAll(next);
        if (next.length < _pageSize) {
          _hasMore = false;
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openFullReviewsBottomSheet(
    BuildContext context,
    CustomerProduct product,
    List<ProductReview> reviews,
  ) {
    int rating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      child: Builder(
        builder: (bottomSheetContext) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final reviewsAsync = ref.watch(
                productReviewsProvider(widget.productId),
              );
              final currentReviews = reviewsAsync.value ?? reviews;

              return SafeArea(
                top: true,
                bottom: true,
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.90,
                  child: Column(
                    children: [
                      // Handle & Header
                      Container(
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.gray300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.rate_review_outlined,
                                  size: 20,
                                  color: AppColors.black,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'تقييمات وآراء المشترين (${currentReviews.length})',
                                  style: Theme.of(ctx).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Scrollable Reviews & Add Form
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                            // Add Review Box
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.gray100,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.card,
                                ),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'أضف تقييمك ورأيك في القطعة',
                                    style: Theme.of(ctx).textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  // Stars Picker
                                  Row(
                                    children: List.generate(5, (index) {
                                      final starNum = index + 1;
                                      return InkWell(
                                        onTap: () => setSheetState(
                                          () => rating = starNum,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            starNum <= rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: AppColors.black,
                                            size: 28,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextField(
                                    controller: commentController,
                                    maxLines: 3,
                                    style: Theme.of(ctx).textTheme.bodyMedium,
                                    decoration: InputDecoration(
                                      hintText: 'اكتب رأيك وتجربتك مع المقاس والجودة والخامة...',
                                      filled: true,
                                      fillColor: AppColors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.input,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.input,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.input,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.black,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.all(
                                        AppSpacing.sm,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.black,
                                        foregroundColor: AppColors.white,
                                        minimumSize: const Size(0, 46),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.button,
                                          ),
                                        ),
                                      ),
                                      onPressed: isSubmitting
                                          ? null
                                          : () async {
                                              setSheetState(
                                                () => isSubmitting = true,
                                              );
                                              try {
                                                await ref
                                                    .read(
                                                      customerRepositoryProvider,
                                                    )
                                                    .addReview(
                                                      productId: product.id,
                                                      rating: rating,
                                                      comment: commentController
                                                          .text
                                                          .trim(),
                                                    );
                                                ref.invalidate(
                                                  customerProductDetailsProvider(
                                                    product.id,
                                                  ),
                                                );
                                                ref.invalidate(
                                                  productReviewsProvider(
                                                    product.id,
                                                  ),
                                                );
                                                commentController.clear();
                                                setSheetState(() {
                                                  isSubmitting = false;
                                                  rating = 5;
                                                });
                                                if (context.mounted) {
                                                  showAppSnackBar(
                                                    context,
                                                    'تمت إضافة تقييمك بنجاح ⭐',
                                                  );
                                                }
                                              } catch (e) {
                                                setSheetState(
                                                  () => isSubmitting = false,
                                                );
                                                if (context.mounted) {
                                                  showAppSnackBar(
                                                    context,
                                                    'تعذر إضافة التقييم',
                                                    isError: true,
                                                  );
                                                }
                                              }
                                            },
                                      child: isSubmitting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.white,
                                              ),
                                            )
                                          : const Text('إرسال التقييم'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // Existing Reviews
                            Text(
                              'آراء العملاء السابقة',
                              style: Theme.of(ctx).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (currentReviews.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg,
                                ),
                                child: Center(
                                  child: Text(
                                    'لا توجد تقييمات لهذا المنتج بعد. كن أول من يقيّمه!',
                                    style: TextStyle(color: AppColors.gray500),
                                  ),
                                ),
                              )
                            else
                              ...currentReviews.map((rev) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              rev.customerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Row(
                                              children: List.generate(5, (i) {
                                                return Icon(
                                                  i < rev.rating
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: AppColors.black,
                                                  size: 15,
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                        if (rev.comment != null &&
                                            rev.comment!.isNotEmpty) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            rev.comment!,
                                            style: Theme.of(ctx)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(
      customerProductDetailsProvider(widget.productId),
    );
    final reviewsAsync = ref.watch(productReviewsProvider(widget.productId));
    final compareList = ref.watch(productComparisonProvider);

    return productAsync.when(
      data: (product) {
        if (product == null) {
          return const CustomerScaffold(
            title: 'تفاصيل المنتج',
            body: Center(child: Text('المنتج غير موجود')),
          );
        }

        // Initialize default selections
        if (_selectedColor == null && product.availableColors.isNotEmpty) {
          _selectedColor = product.availableColors.first;
        }

        final matchingSizes = product.variants
            .where((v) => v.color == _selectedColor && v.stock > 0)
            .map((v) => v.size)
            .toList();

        if (_selectedSize == null || !matchingSizes.contains(_selectedSize)) {
          if (matchingSizes.isNotEmpty) {
            _selectedSize = matchingSizes.first;
          }
        }

        final currentVariant = product.variants
            .cast<ProductVariant?>()
            .firstWhere(
              (v) => v?.color == _selectedColor && v?.size == _selectedSize,
              orElse: () => null,
            );

        final currentStock = currentVariant?.stock ?? 0;
        final isInCompare = compareList.any((p) => p.id == product.id);

        return CustomerScaffold(
          title: product.name,
          actions: [
            // Favorite Button
            IconButton(
              icon: Icon(
                product.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: AppColors.black,
              ),
              onPressed: _togglingFavorite
                  ? null
                  : () async {
                      setState(() => _togglingFavorite = true);
                      await ref
                          .read(customerRepositoryProvider)
                          .toggleFavorite(product.id);
                      ref.invalidate(
                        customerProductDetailsProvider(widget.productId),
                      );
                      ref.invalidate(customerFavoritesProvider);
                      setState(() => _togglingFavorite = false);
                    },
            ),
          ],
          body: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Gallery
                if (product.images.isNotEmpty) ...[
                  SizedBox(
                    height: 380,
                    child: PageView.builder(
                      itemCount: product.images.length,
                      onPageChanged: (index) =>
                          setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) {
                        final img = product.images[index];
                        return Container(
                          color: AppColors.gray100,
                          child: Image.network(
                            img.filePath,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, st) =>
                                const Center(child: Text('تعذر تحميل الصورة')),
                          ),
                        );
                      },
                    ),
                  ),
                  if (product.images.length > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(product.images.length, (idx) {
                        final active = idx == _currentImageIndex;
                        return Container(
                          width: active ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: active ? AppColors.black : AppColors.gray300,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                        );
                      }),
                    ),
                  ],
                ] else
                  Container(
                    height: 250,
                    color: AppColors.gray100,
                    alignment: Alignment.center,
                    child: const Text('بدون صورة'),
                  ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop Link
                      InkWell(
                        onTap: () => context.push(
                          AppRoutes.customerShopProfilePath(product.shopId),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 18,
                              color: AppColors.gray700,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              "المتجر صاحب الملابس هو : ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              product.shopName,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Title
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Price & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${product.price.toStringAsFixed(2)} ر.س',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black,
                                ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount})',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),

                      // Colors Selection
                      Text(
                        'الألوان المتاحة',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: product.availableColors.map((clr) {
                          final isSelected = _selectedColor == clr;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedColor = clr;
                                _selectedSize = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs + 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.black
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.black
                                      : AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                clr,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.black,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Sizes Selection
                      Text(
                        'المقاسات المتاحة',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: matchingSizes.map((sz) {
                          final isSelected = _selectedSize == sz;
                          return InkWell(
                            onTap: () => setState(() => _selectedSize = sz),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs + 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.black
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.black
                                      : AppColors.border,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                sz,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.black,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Stock status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentStock > 0
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              size: 15,
                              color: AppColors.black,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              currentStock > 0
                                  ? 'متوفر في المخزون ($currentStock قطعة)'
                                  : 'نفذت الكمية لهذا المقاس',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Description
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        Text(
                          'تفاصيل ومواصفات القطعة',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppCard(
                          child: Text(
                            product.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),

                      // Reviews Summary Box (Opens full-height bottom sheet on tap)
                      InkWell(
                        onTap: () => _openFullReviewsBottomSheet(
                          context,
                          product,
                          reviewsAsync.value ?? [],
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gray100,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: AppColors.black,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      product.ratingAvg.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'آراء وتقييمات المشترين',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      product.ratingCount > 0
                                          ? '${product.ratingCount} تقييم • اضغط لقراءة الآراء وإضافة تقييمك'
                                          : 'لا توجد تقييمات بعد • اضغط لتكون أول من يقيّم',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.gray500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),

                      // Infinite Recommendations Section (Loads 6 by 6)
                      Row(
                        children: [
                          Text(
                            'منتجات قد تعجبك',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (_recommendedProducts.isEmpty && _loadingMore) ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                      ] else if (_recommendedProducts.isNotEmpty) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.sm,
                                mainAxisSpacing: AppSpacing.sm,
                                childAspectRatio: 0.58,
                              ),
                          itemCount: _recommendedProducts.length,
                          itemBuilder: (context, index) {
                            final recProduct = _recommendedProducts[index];
                            final primaryImg = recProduct.images.isNotEmpty
                                ? recProduct.images.first.filePath
                                : null;
                            return ProductGridCard(
                              title: recProduct.name,
                              subtitle:
                                  '${recProduct.price.toStringAsFixed(2)} ر.س',
                              meta: recProduct.shopName,
                              imageUrl: primaryImg,
                              onTap: () => context.push(
                                AppRoutes.customerProductDetailsPath(
                                  recProduct.id,
                                ),
                              ),
                            );
                          },
                        ),
                        if (_loadingMore) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ],
                        if (!_hasMore) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Center(
                              child: Text(
                                'وصلت إلى نهاية التوصيات',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.gray500),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Real-Time Decart AI Try-on Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: AppColors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: () => context.push(
                        AppRoutes.customerRealtimeTryonPath(product.id),
                      ),
                      child: const Text(
                        'تجربة الملابس',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Compare products.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isInCompare
                                  ? AppColors.white
                                  : AppColors.black,
                              backgroundColor: isInCompare
                                  ? AppColors.black
                                  : AppColors.white,
                              side: BorderSide(
                                color: isInCompare
                                    ? AppColors.black
                                    : AppColors.border,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.button,
                                ),
                              ),
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                            ),
                            label: Text(
                              isInCompare ? 'في المقارنة' : 'مقارنة القطعة',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              final notifier = ref.read(
                                productComparisonProvider.notifier,
                              );
                              if (isInCompare) {
                                notifier.removeProduct(product.id);
                                showAppSnackBar(
                                  context,
                                  'تمت الإزالة من المقارنة',
                                );
                              } else {
                                final added = notifier.addProduct(product);
                                if (added) {
                                  showAppSnackBar(
                                    context,
                                    'تمت الإضافة للمقارنة (بحد أقصى 3 منتجات)',
                                  );
                                } else {
                                  showAppSnackBar(
                                    context,
                                    'الحد الأقصى للمقارنة هو 3 منتجات',
                                    isError: true,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Row 2: Quantity Stepper & Add to Cart side-by-side
                    Row(
                      children: [
                        // Quantity Stepper
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(
                              AppRadii.button,
                            ),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(AppRadii.button),
                                ),
                                child: Container(
                                  width: 36,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: _quantity > 1
                                        ? AppColors.black
                                        : AppColors.gray500,
                                  ),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  border: Border.symmetric(
                                    vertical: BorderSide(
                                      color: AppColors.border,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: _quantity < currentStock
                                    ? () => setState(() => _quantity++)
                                    : null,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(AppRadii.button),
                                ),
                                child: Container(
                                  width: 36,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: _quantity < currentStock
                                        ? AppColors.black
                                        : AppColors.gray500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),

                        // Add to Cart Primary Button
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.black,
                              foregroundColor: AppColors.white,
                              disabledBackgroundColor: AppColors.gray300,
                              disabledForegroundColor: AppColors.gray500,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.button,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 20,
                            ),
                            label: Text(
                              currentStock > 0
                                  ? 'إضافة إلى السلة • ${(product.price * _quantity).toStringAsFixed(2)} ر.س'
                                  : 'نفذت الكمية',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            onPressed:
                                currentStock > 0 &&
                                    _selectedColor != null &&
                                    _selectedSize != null
                                ? () {
                                    ref
                                        .read(cartProvider.notifier)
                                        .addItem(
                                          product: product,
                                          variantId: currentVariant?.id,
                                          color: _selectedColor!,
                                          size: _selectedSize!,
                                          quantity: _quantity,
                                          maxStock: currentStock,
                                        );
                                    showAppSnackBar(
                                      context,
                                      'تمت إضافة القطعة إلى سلة المشتريات 🛍️',
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const CustomerScaffold(
        title: 'جاري التحميل...',
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => CustomerScaffold(
        title: 'خطأ',
        body: Center(child: Text('تعذر تحميل تفاصيل المنتج: $err')),
      ),
    );
  }
}
