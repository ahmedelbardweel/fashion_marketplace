import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../core/widgets/product_grid_skeleton.dart';
import '../../../../router/routes.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/product_cart_sheet.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PageController _galleryController = PageController();
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
    _galleryController.dispose();
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

  Future<void> _toggleFavorite(String productId) async {
    await ref.read(customerRepositoryProvider).toggleFavorite(productId);
    ref.invalidate(customerProductDetailsProvider(productId));
    ref.invalidate(customerFavoritesProvider);
    ref.invalidate(customerProductsProvider);
  }

  void _openFullScreenGallery(
    BuildContext context,
    List<ProductImage> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenGalleryPage(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
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
                        width: SheetDesign.handleWidth,
                        height: SheetDesign.handleHeight,
                        decoration: BoxDecoration(
                          color: SheetDesign.handle,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
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
                                Icon(
                                  AppIcons.rateReview,
                                  size: 20,
                                  color: AppColors.icon,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'تقييمات وآراء المشترين (${currentReviews.length})'.tr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: AppFont.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                AppIcons.close,
                                size: 22,
                                color: AppColors.icon,
                              ),
                              onPressed: AppHaptics.action(
                                () => Navigator.of(ctx).pop(),
                              ),
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
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(
                                  ProductDetailsDesign.reviewCardRadius,
                                ),
                                border: Border.all(
                                  color: ProductDetailsDesign.reviewCardBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'أضف تقييمك ورأيك في القطعة'.tr,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: AppFont.bold,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  // Stars Picker
                                  Row(
                                    children: List.generate(5, (index) {
                                      final starNum = index + 1;
                                      return InkWell(
                                        onTap: AppHaptics.action(
                                          () => setSheetState(
                                            () => rating = starNum,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.sm,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            starNum <= rating
                                                ? AppIcons.starFilled
                                                : AppIcons.star,
                                            color: starNum <= rating
                                                ? ProductDetailsDesign
                                                      .ratingStar
                                                : ProductDetailsDesign
                                                      .ratingStarEmpty,
                                            size: ProductDetailsDesign
                                                .reviewPickerStarSize,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextField(
                                    controller: commentController,
                                    maxLines: 3,
                                    style: Theme.of(ctx).textTheme.bodyMedium
                                        ?.copyWith(color: AppColors.text),
                                    decoration: InputDecoration(
                                      hintText:
                                          'اكتب رأيك وتجربتك مع المقاس والجودة والخامة...'.tr,
                                      filled: true,
                                      fillColor: AppColors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          InputDesign.radius,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          InputDesign.radius,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          InputDesign.radius,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.primary,
                                          width: 1.5,
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
                                      onPressed: AppHaptics.action(
                                        isSubmitting
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
                                                        comment:
                                                            commentController
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
                                                      'تمت إضافة تقييمك بنجاح'.tr,
                                                    );
                                                  }
                                                } catch (e) {
                                                  setSheetState(
                                                    () => isSubmitting = false,
                                                  );
                                                  if (context.mounted) {
                                                    showAppSnackBar(
                                                      context,
                                                      'تعذر إضافة التقييم'.tr,
                                                      isError: true,
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                                      child: isSubmitting
                                          ? AppBusyLabel(
                                              label: 'إرسال التقييم'.tr,
                                            )
                                          : Text('إرسال التقييم'.tr),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // Existing Reviews
                            Text(
                              'آراء العملاء السابقة'.tr,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: AppFont.bold,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (currentReviews.isEmpty)
                              AppEmpty(
                                icon: AppIcons.reviews,
                                message:
                                    'لا توجد تقييمات لهذا المنتج بعد. كن أول من يقيّمه.'.tr,
                              )
                            else
                              ...currentReviews.map(
                                (rev) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: _ReviewTile(review: rev),
                                ),
                              ),
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
    final cartCount = ref.watch(cartProvider.notifier).totalItemCount;

    return productAsync.skeletonWhen(
      placeholder: LoadingFixtures.product,
      data: (product) {
        if (product == null) {
          return CustomerScaffold(
            showBottomNav: false,
            title: 'تفاصيل المنتج'.tr,
            body: AppEmpty(
              icon: AppIcons.garment,
              message: 'المنتج غير موجود'.tr,
            ),
          );
        }

        // Initialize default selections
        if (productAsync.hasValue &&
            _selectedColor == null &&
            product.availableColors.isNotEmpty) {
          _selectedColor = product.availableColors.first;
        }

        final allSizes = product.variants.map((v) => v.size).toSet().toList();
        final matchingSizes = product.variants
            .where((v) => v.color == _selectedColor && v.stock > 0)
            .map((v) => v.size)
            .toList();

        if (productAsync.hasValue &&
            (_selectedSize == null || !matchingSizes.contains(_selectedSize))) {
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
        if (_quantity > currentStock && currentStock > 0) {
          _quantity = currentStock;
        }
        final isInCompare = compareList.any((p) => p.id == product.id);
        final reviews = reviewsAsync.value ?? <ProductReview>[];
        final screenHeight = MediaQuery.of(context).size.height;
        final galleryHeight =
            (screenHeight * ProductDetailsDesign.galleryHeightFactor).clamp(
              ProductDetailsDesign.galleryMinHeight,
              ProductDetailsDesign.galleryMaxHeight,
            );

        final specFields = <MapEntry<String, String>>[];
        if (product.categoryName != null &&
            product.categoryName!.trim().isNotEmpty) {
          specFields.add(MapEntry('التصنيف'.tr, product.categoryName!));
        }
        for (final field in {
          'brand': 'الماركة'.tr,
          'material': 'الخامة'.tr,
          'care': 'طريقة العناية'.tr,
          'fit': 'القَصّة'.tr,
          'origin': 'بلد الصنع'.tr,
        }.entries) {
          final val = product.details[field.key]?.toString().trim() ?? '';
          if (val.isNotEmpty) {
            specFields.add(MapEntry(field.value, val));
          }
        }

        return Scaffold(
          backgroundColor: ProductDetailsDesign.pageBackground,
          body: Stack(
            children: [
              // 1) Main Scrollable Content (Editorial Hero Gallery + Overlapping Sheet)
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Editorial Portrait Gallery — Distinct from grid cards:
                    // edge-to-edge, tall portrait ratio, interactive zoom on tap,
                    // floating virtual try-on pill, and thumbnail strip below.
                    SizedBox(
                      height: galleryHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (product.images.isNotEmpty)
                            PageView.builder(
                              controller: _galleryController,
                              itemCount: product.images.length,
                              onPageChanged: (index) =>
                                  setState(() => _currentImageIndex = index),
                              itemBuilder: (context, index) {
                                final img = product.images[index];
                                return GestureDetector(
                                  onTap: AppHaptics.action(
                                    () => _openFullScreenGallery(
                                      context,
                                      product.images,
                                      index,
                                    ),
                                  ),
                                  child: ColoredBox(
                                    color:
                                        ProductDetailsDesign.galleryBackground,
                                    child: AppNetworkImage(
                                      img.filePath,
                                      fit: ProductDetailsDesign.galleryImageFit,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, _, _) => Center(
                                        child: Icon(
                                          AppIcons.garment,
                                          size: 48,
                                          color: AppColors.iconMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            ColoredBox(
                              color: ProductDetailsDesign.galleryBackground,
                              child: Center(
                                child: Icon(
                                  AppIcons.garment,
                                  size: 54,
                                  color: AppColors.iconMuted,
                                ),
                              ),
                            ),

                          // Bottom controls over gallery: image counter + Try-On pill + Zoom button
                          PositionedDirectional(
                            start: AppSpacing.md,
                            end: AppSpacing.md,
                            bottom: ProductDetailsDesign.contentOverlap + 14,
                            child: Row(
                              children: [
                                // Virtual Try-On quick pill on gallery
                                Material(
                                  color: ProductDetailsDesign
                                      .tryOnPillBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                  elevation: 0,
                                  child: InkWell(
                                    onTap: AppHaptics.action(
                                      () => context.push(
                                        AppRoutes.customerRealtimeTryonPath(
                                          product.id,
                                        ),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                    child: Container(
                                      height:
                                          ProductDetailsDesign.tryOnPillHeight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                        boxShadow: ProductDetailsDesign
                                            .floatingButtonShadow,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            AppIcons.tryOn,
                                            size: 18,
                                            color: ProductDetailsDesign
                                                .tryOnPillIcon,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'جرّبها عليك الآن'.tr,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: AppFont.bold,
                                              color: ProductDetailsDesign
                                                  .tryOnPillText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (product.images.length > 1)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ProductDetailsDesign
                                          .counterBackground,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: Text(
                                      '${_currentImageIndex + 1} / ${product.images.length}',
                                      style: const TextStyle(
                                        color:
                                            ProductDetailsDesign.counterText,
                                        fontSize: ProductDetailsDesign
                                            .counterTextSize,
                                        fontWeight: AppFont.bold,
                                      ),
                                    ),
                                  ),
                                if (product.images.isNotEmpty) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  _FloatingCircleButton(
                                    icon: AppIcons.fullscreen,
                                    tooltip: 'تكبير الصورة'.tr,
                                    onTap: () => _openFullScreenGallery(
                                      context,
                                      product.images,
                                      _currentImageIndex,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Overlapping Editorial Content Sheet
                    Transform.translate(
                      offset: const Offset(
                        0,
                        -ProductDetailsDesign.contentOverlap,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ProductDetailsDesign.contentBackground,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(
                              ProductDetailsDesign.contentRadius,
                            ),
                          ),
                        ),
                        padding: ProductDetailsDesign.contentPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Thumbnail Strip (when multiple images exist)
                            if (product.images.length > 1) ...[
                              SizedBox(
                                height: ProductDetailsDesign.thumbSize,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: product.images.length,
                                  separatorBuilder: (_, _) => const SizedBox(
                                    width: ProductDetailsDesign.thumbSpacing,
                                  ),
                                  itemBuilder: (context, idx) {
                                    final active = idx == _currentImageIndex;
                                    return GestureDetector(
                                      onTap: AppHaptics.action(() {
                                        setState(
                                          () => _currentImageIndex = idx,
                                        );
                                        _galleryController.animateToPage(
                                          idx,
                                          duration: AppMotion.normal,
                                          curve: AppMotion.curve,
                                        );
                                      }),
                                      child: AnimatedContainer(
                                        duration: AppMotion.fast,
                                        width: ProductDetailsDesign.thumbSize,
                                        height: ProductDetailsDesign.thumbSize,
                                        decoration: BoxDecoration(
                                          color: ProductDetailsDesign
                                              .galleryBackground,
                                          borderRadius: BorderRadius.circular(
                                            ProductDetailsDesign.thumbRadius,
                                          ),
                                          border: Border.all(
                                            color: active
                                                ? ProductDetailsDesign
                                                      .thumbActiveBorder
                                                : ProductDetailsDesign
                                                      .thumbBorder,
                                            width: active
                                                ? ProductDetailsDesign
                                                      .thumbActiveBorderWidth
                                                : 1,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: AppNetworkImage(
                                          product.images[idx].filePath,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],

                            // Brand / Shop Row + Rating Pill
                            Row(
                              children: [
                                InkWell(
                                  onTap: AppHaptics.action(
                                    () => context.push(
                                      AppRoutes.customerShopProfilePath(
                                        product.shopId,
                                      ),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.xs,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          AppIcons.shop,
                                          size: 16,
                                          color: AppColors.icon,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          product.shopName,
                                          style: TextStyle(
                                            fontSize: ProductDetailsDesign
                                                .shopNameSize,
                                            fontWeight: ProductDetailsDesign
                                                .shopNameWeight,
                                            color: ProductDetailsDesign
                                                .shopNameColor,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          AppIcons.forward,
                                          size: 16,
                                          color: ProductDetailsDesign
                                              .shopNameColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: AppHaptics.action(
                                    () => _openFullReviewsBottomSheet(
                                      context,
                                      product,
                                      reviews,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          AppIcons.starFilled,
                                          size: ProductDetailsDesign
                                              .ratingStarSize,
                                          color: ProductDetailsDesign
                                              .ratingStar,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          product.ratingAvg.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: ProductDetailsDesign
                                                .ratingTextSize,
                                            fontWeight: AppFont.bold,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        Text(
                                          ' (${product.ratingCount})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.xs),

                            // Product Title
                            Text(
                              product.name,
                              style: TextStyle(
                                fontSize: ProductDetailsDesign.titleSize,
                                fontWeight: ProductDetailsDesign.titleWeight,
                                color: ProductDetailsDesign.titleColor,
                                height: 1.35,
                              ),
                            ),

                            const SizedBox(height: AppSpacing.sm),

                            // Price + Stock Status Pill
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  AppFormat.price(product.price),
                                  style: TextStyle(
                                    fontSize: ProductDetailsDesign.priceSize,
                                    fontWeight:
                                        ProductDetailsDesign.priceWeight,
                                    color: ProductDetailsDesign.priceColor,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _StockBadge(stock: currentStock),
                              ],
                            ),

                            const SizedBox(
                              height: ProductDetailsDesign.sectionSpacing,
                            ),
                            const Divider(height: 1),
                            const SizedBox(
                              height: ProductDetailsDesign.sectionSpacing,
                            ),

                            // Color Selection
                            if (product.availableColors.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    'اللون'.tr,
                                    style: TextStyle(
                                      fontSize:
                                          ProductDetailsDesign.sectionTitleSize,
                                      fontWeight: ProductDetailsDesign
                                          .sectionTitleWeight,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  if (_selectedColor != null) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '· $_selectedColor',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: AppFont.semiBold,
                                        color: ProductDetailsDesign
                                            .sectionValueColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: product.availableColors.map((clr) {
                                  final isSelected = _selectedColor == clr;
                                  return _SelectorChip(
                                    label: clr,
                                    selected: isSelected,
                                    enabled: true,
                                    onTap: () {
                                      setState(() {
                                        _selectedColor = clr;
                                        _selectedSize = null;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],

                            // Size Selection
                            if (allSizes.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    'المقاس'.tr,
                                    style: TextStyle(
                                      fontSize:
                                          ProductDetailsDesign.sectionTitleSize,
                                      fontWeight: ProductDetailsDesign
                                          .sectionTitleWeight,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  if (_selectedSize != null) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '· $_selectedSize',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: AppFont.semiBold,
                                        color: ProductDetailsDesign
                                            .sectionValueColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: allSizes.map((sz) {
                                  final available = matchingSizes.contains(sz);
                                  final isSelected = _selectedSize == sz;
                                  return _SelectorChip(
                                    label: sz,
                                    selected: isSelected,
                                    enabled: available,
                                    onTap: available
                                        ? () =>
                                              setState(() => _selectedSize = sz)
                                        : null,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(
                                height: ProductDetailsDesign.sectionSpacing,
                              ),
                            ],

                            // Virtual Try-On Feature Banner
                            InkWell(
                              onTap: AppHaptics.action(
                                () => context.push(
                                  AppRoutes.customerRealtimeTryonPath(
                                    product.id,
                                  ),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                ProductDetailsDesign.tryOnCardRadius,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: ProductDetailsDesign
                                      .tryOnCardBackground,
                                  borderRadius: BorderRadius.circular(
                                    ProductDetailsDesign.tryOnCardRadius,
                                  ),
                                  border: Border.all(
                                    color: ProductDetailsDesign.tryOnCardBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: ProductDetailsDesign
                                            .tryOnIconBackground,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.md,
                                        ),
                                      ),
                                      child: Icon(
                                        AppIcons.tryOn,
                                        color: ProductDetailsDesign.tryOnIcon,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'غرفة القياس الافتراضية المباشرة'.tr,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: AppFont.bold,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'شاهد كيف تبدو هذه القطعة عليك بالكاميرا مباشرة قبل الشراء'.tr,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      AppIcons.forward,
                                      size: 16,
                                      color: AppColors.icon,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.lg),

                            // Accordion Sections: Description & Specifications
                            const Divider(height: 1),
                            if (product.description?.trim().isNotEmpty ?? false)
                              _DetailAccordion(
                                title: 'وصف القطعة'.tr,
                                icon: AppIcons.notes,
                                initiallyExpanded: true,
                                child: Text(
                                  product.description!,
                                  style: TextStyle(
                                    fontSize: ProductDetailsDesign.bodyTextSize,
                                    color: ProductDetailsDesign.bodyTextColor,
                                    height: 1.65,
                                  ),
                                ),
                              ),
                            if (specFields.isNotEmpty)
                              _DetailAccordion(
                                title: 'المواصفات والخامة والعناية'.tr,
                                icon: AppIcons.ruler,
                                initiallyExpanded:
                                    product.description?.trim().isEmpty ?? true,
                                child: Column(
                                  children: [
                                    for (final entry in specFields)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                entry.key,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: ProductDetailsDesign
                                                      .specLabelColor,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                entry.value,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      ProductDetailsDesign
                                                          .specValueWeight,
                                                  color: ProductDetailsDesign
                                                      .specValueColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: AppSpacing.lg),

                            // Seller Card
                            InkWell(
                              onTap: AppHaptics.action(
                                () => context.push(
                                  AppRoutes.customerShopProfilePath(
                                    product.shopId,
                                  ),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                ProductDetailsDesign.shopCardRadius,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(
                                    ProductDetailsDesign.shopCardRadius,
                                  ),
                                  border: Border.all(
                                    color: ProductDetailsDesign.shopCardBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: ProductDetailsDesign.shopLogoSize,
                                      height: ProductDetailsDesign.shopLogoSize,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        AppIcons.shopActive,
                                        color: AppColors.icon,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'يباع بواسطة'.tr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            product.shopName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: AppFont.bold,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                      ),
                                      child: Text(
                                        'زيارة المتجر'.tr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: AppFont.bold,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: ProductDetailsDesign.sectionSpacing,
                            ),

                            // Customer Reviews Section (with inline preview + full sheet)
                            AppSectionHeader(
                              padding: EdgeInsets.zero,
                              title:
                                  'تقييمات المشترين (${product.ratingCount})'.tr,
                              actionLabel: 'عرض الكل وإضافة تقييم'.tr,
                              onAction: AppHaptics.action(
                                () => _openFullReviewsBottomSheet(
                                  context,
                                  product,
                                  reviews,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            InkWell(
                              onTap: AppHaptics.action(
                                () => _openFullReviewsBottomSheet(
                                  context,
                                  product,
                                  reviews,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                ProductDetailsDesign.reviewCardRadius,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(
                                    ProductDetailsDesign.reviewCardRadius,
                                  ),
                                  border: Border.all(
                                    color:
                                        ProductDetailsDesign.reviewCardBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          product.ratingAvg.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: AppFont.extraBold,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(5, (i) {
                                            return Icon(
                                              i < product.ratingAvg.round()
                                                  ? AppIcons.starFilled
                                                  : AppIcons.star,
                                              size: 15,
                                              color: ProductDetailsDesign
                                                  .ratingStar,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'شاركنا تجربتك مع القطعة'.tr,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: AppFont.bold,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            product.ratingCount > 0
                                                ? 'اضغط لقراءة ${product.ratingCount} تقييم أو كتابة تقييمك'.tr
                                                : 'لا توجد تقييمات بعد · كن أول من يقيّم هذه القطعة'.tr,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      AppIcons.forward,
                                      color: AppColors.icon,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (reviews.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              for (final rev in reviews.take(2))
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: _ReviewTile(review: rev),
                                ),
                            ],

                            const SizedBox(
                              height: ProductDetailsDesign
                                  .recommendationsTopSpacing,
                            ),

                            // Infinite Recommendations Section
                            AppSectionHeader(
                              padding: EdgeInsets.zero,
                              title: 'منتجات قد تعجبك'.tr,
                            ),
                            const SizedBox(height: AppSpacing.md),

                            if (_recommendedProducts.isEmpty && _loadingMore)
                              const ProductGridSkeleton()
                            else if (_recommendedProducts.isNotEmpty) ...[
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: ProductGridDelegate(
                                  textScale:
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(14) /
                                      14,
                                ),
                                itemCount: _recommendedProducts.length,
                                itemBuilder: (context, index) {
                                  final recProduct =
                                      _recommendedProducts[index];
                                  return ProductGridCard(
                                    imageUrl: recProduct.coverImage,
                                    meta: AppFormat.price(recProduct.price),
                                    inStock: recProduct.totalStock > 0,
                                    isFavorite: recProduct.isFavorite,
                                    onToggleFavorite: () =>
                                        _toggleFavorite(recProduct.id),
                                    onAddToCart: () => showProductCartSheet(
                                      context,
                                      recProduct.id,
                                    ),
                                    onTap: () => context.push(
                                      AppRoutes.customerProductDetailsPath(
                                        recProduct.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (_loadingMore) const ProductGridSkeleton(),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2) Floating Top Bar over the Gallery (Back, Compare, Favorite, Cart)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        _FloatingCircleButton(
                          icon: AppIcons.back,
                          tooltip: 'رجوع'.tr,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        _FloatingCircleButton(
                          icon: AppIcons.compare,
                          tooltip: isInCompare
                              ? 'إزالة من المقارنة'.tr
                              : 'إضافة للمقارنة'.tr,
                          selected: isInCompare,
                          onTap: () {
                            final notifier = ref.read(
                              productComparisonProvider.notifier,
                            );
                            if (isInCompare) {
                              notifier.removeProduct(product.id);
                              showAppSnackBar(
                                context,
                                'تمت الإزالة من المقارنة'.tr,
                              );
                            } else {
                              final added = notifier.addProduct(product);
                              if (added) {
                                showAppSnackBar(
                                  context,
                                  'تمت الإضافة للمقارنة'.tr,
                                  actionLabel: 'عرض المقارنة'.tr,
                                  onAction: () =>
                                      context.push(AppRoutes.customerCompare),
                                );
                              } else {
                                showAppSnackBar(
                                  context,
                                  'الحد الأقصى للمقارنة هو 3 منتجات'.tr,
                                  isError: true,
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _FloatingCircleButton(
                          icon: product.isFavorite
                              ? AppIcons.heartFilled
                              : AppIcons.heart,
                          tooltip: 'المفضلة'.tr,
                          onTap: _togglingFavorite
                              ? null
                              : () async {
                                  setState(() => _togglingFavorite = true);
                                  try {
                                    await _toggleFavorite(product.id);
                                  } finally {
                                    if (mounted) {
                                      setState(() => _togglingFavorite = false);
                                    }
                                  }
                                },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _FloatingCircleButton(
                          icon: AppIcons.bag,
                          tooltip: 'سلة المشتريات'.tr,
                          badgeCount: cartCount,
                          onTap: () => context.push(AppRoutes.customerCart),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 3) Sticky Bottom Action Bar: Quantity Stepper + Primary Add to Cart CTA
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: ProductDetailsDesign.bottomBarBackground,
              boxShadow: ProductDetailsDesign.bottomBarShadow,
              border: Border(
                top: BorderSide(color: ProductDetailsDesign.bottomBarBorder),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: ProductDetailsDesign.bottomBarPadding,
                child: Row(
                  children: [
                    // Quantity Stepper
                    Container(
                      height: ProductDetailsDesign.bottomBarButtonHeight,
                      width: ProductDetailsDesign.stepperWidth,
                      decoration: BoxDecoration(
                        color: ProductDetailsDesign.stepperBackground,
                        borderRadius: BorderRadius.circular(
                          ProductDetailsDesign.stepperRadius,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: AppHaptics.action(
                              _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            icon: Icon(
                              AppIcons.remove,
                              size: 18,
                              color: _quantity > 1
                                  ? ProductDetailsDesign.stepperIcon
                                  : ProductDetailsDesign.stepperIconDisabled,
                            ),
                          ),
                          Text(
                            '$_quantity',
                            style: TextStyle(
                              fontSize: ProductDetailsDesign.stepperValueSize,
                              fontWeight: AppFont.extraBold,
                              color: AppColors.text,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: AppHaptics.action(
                              _quantity < currentStock
                                  ? () => setState(() => _quantity++)
                                  : null,
                            ),
                            icon: Icon(
                              AppIcons.add,
                              size: 18,
                              color: _quantity < currentStock
                                  ? ProductDetailsDesign.stepperIcon
                                  : ProductDetailsDesign.stepperIconDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Primary Add to Cart Button
                    Expanded(
                      child: SizedBox(
                        height: ProductDetailsDesign.bottomBarButtonHeight,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            AppIcons.bag,
                            size: 20,
                          ),
                          label: Text(
                            currentStock > 0
                                ? 'إضافة إلى السلة · ${AppFormat.price(product.price * _quantity)}'.tr
                                : 'نفدت الكمية'.tr,
                          ),
                          onPressed: AppHaptics.action(
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
                                      'تمت إضافة القطعة إلى سلة المشتريات'.tr,
                                      actionLabel: 'عرض السلة'.tr,
                                      onAction: () =>
                                          context.push(AppRoutes.customerCart),
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      error: (err, _) => CustomerScaffold(
        showBottomNav: false,
        title: 'تفاصيل المنتج'.tr,
        body: AppEmpty(
          icon: AppIcons.error,
          title: 'تعذر تحميل تفاصيل المنتج'.tr,
          message: '$err',
        ),
      ),
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: ProductDetailsDesign.floatingIconSize,
      color: selected
          ? AppColors.onPrimary
          : ProductDetailsDesign.floatingButtonIcon,
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: AppHaptics.action(onTap),
          customBorder: const CircleBorder(),
          child: Container(
            width: ProductDetailsDesign.floatingButtonSize,
            height: ProductDetailsDesign.floatingButtonSize,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : ProductDetailsDesign.floatingButtonBackground,
              shape: BoxShape.circle,
              boxShadow: ProductDetailsDesign.floatingButtonShadow,
            ),
            alignment: Alignment.center,
            child: badgeCount > 0
                ? Badge(
                    label: Text('$badgeCount'),
                    backgroundColor: AppBarDesign.badgeBackground,
                    textColor: AppBarDesign.badgeText,
                    child: iconWidget,
                  )
                : iconWidget,
          ),
        ),
      ),
    );
  }
}

class _SelectorChip extends StatelessWidget {
  const _SelectorChip({
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? AppHaptics.action(onTap) : null,
      borderRadius: BorderRadius.circular(ProductDetailsDesign.optionRadius),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        constraints: const BoxConstraints(
          minWidth: ProductDetailsDesign.optionMinWidth,
          minHeight: ProductDetailsDesign.optionHeight,
        ),
        padding: ProductDetailsDesign.optionPadding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? ProductDetailsDesign.optionDisabledBackground
              : selected
              ? ProductDetailsDesign.optionSelectedBackground
              : ProductDetailsDesign.optionBackground,
          borderRadius: BorderRadius.circular(
            ProductDetailsDesign.optionRadius,
          ),
          border: Border.all(
            color: selected
                ? ProductDetailsDesign.optionSelectedBorder
                : ProductDetailsDesign.optionBorder,
            width: selected
                ? ProductDetailsDesign.optionSelectedBorderWidth
                : ProductDetailsDesign.optionBorderWidth,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? ProductDetailsDesign.optionDisabledText
                : selected
                ? ProductDetailsDesign.optionSelectedText
                : ProductDetailsDesign.optionText,
            fontWeight: selected
                ? ProductDetailsDesign.optionSelectedWeight
                : ProductDetailsDesign.optionWeight,
            decoration: enabled ? null : TextDecoration.lineThrough,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    if (stock <= 0) {
      return AppStatusBadge(
        label: 'نفدت الكمية'.tr,
        tone: BadgeTone.error,
      );
    }
    if (stock <= ProductDetailsDesign.lowStockThreshold) {
      return AppStatusBadge(
        label: 'متبقي $stock فقط'.tr,
        tone: BadgeTone.warning,
      );
    }
    return AppStatusBadge(
      label: 'متوفر في المخزون'.tr,
      tone: BadgeTone.primary,
    );
  }
}

class _DetailAccordion extends StatelessWidget {
  const _DetailAccordion({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ProductDetailsDesign.expandableDivider),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
          iconColor: ProductDetailsDesign.expandableIcon,
          collapsedIconColor: ProductDetailsDesign.expandableIcon,
          leading: Icon(icon, size: 20, color: AppColors.icon),
          title: Text(
            title,
            style: TextStyle(
              fontSize: ProductDetailsDesign.expandableTitleSize,
              fontWeight: ProductDetailsDesign.expandableTitleWeight,
              color: AppColors.text,
            ),
          ),
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: child),
          ],
        ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final initial = review.customerName.trim().isNotEmpty
        ? review.customerName.trim().characters.first
        : 'ع'.tr;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          ProductDetailsDesign.reviewCardRadius,
        ),
        border: Border.all(color: ProductDetailsDesign.reviewCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: ProductDetailsDesign.reviewAvatarSize,
                height: ProductDetailsDesign.reviewAvatarSize,
                decoration: BoxDecoration(
                  color: ProductDetailsDesign.reviewAvatarBackground,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontWeight: AppFont.bold,
                    color: ProductDetailsDesign.reviewAvatarText,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  review.customerName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating
                        ? AppIcons.starFilled
                        : AppIcons.star,
                    color: i < review.rating
                        ? ProductDetailsDesign.ratingStar
                        : ProductDetailsDesign.ratingStarEmpty,
                    size: ProductDetailsDesign.reviewStarSize,
                  );
                }),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 13,
                color: ProductDetailsDesign.bodyTextColor,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FullscreenGalleryPage extends StatefulWidget {
  const _FullscreenGalleryPage({
    required this.images,
    required this.initialIndex,
  });

  final List<ProductImage> images;
  final int initialIndex;

  @override
  State<_FullscreenGalleryPage> createState() => _FullscreenGalleryPageState();
}

class _FullscreenGalleryPageState extends State<_FullscreenGalleryPage> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GalleryViewerDesign.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  maxScale: GalleryViewerDesign.maxZoom,
                  child: Center(
                    child: AppNetworkImage(
                      widget.images[index].filePath,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            PositionedDirectional(
              top: AppSpacing.sm,
              start: AppSpacing.md,
              end: AppSpacing.md,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: GalleryViewerDesign.closeBackground,
                      foregroundColor: GalleryViewerDesign.closeIcon,
                    ),
                    onPressed: AppHaptics.action(
                      () => Navigator.of(context).pop(),
                    ),
                    icon: const Icon(AppIcons.close),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
