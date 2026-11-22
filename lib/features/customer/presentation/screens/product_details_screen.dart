import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/network_guard.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/fashion_color_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
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
  final Set<String> _recommendedIds = {};
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _similarLoaded = false;
  int _generalOffset = 0;
  CustomerProduct? _anchorProduct;
  static const int _pageSize = kProductPageSize;

  int _currentImageIndex = 0;
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;
  bool _togglingFavorite = false;
  bool _isHeroCollapsed = false;
  bool _isAutoSnapping = false;
  bool _dragStartedCollapsed = false;
  double _heroCollapseExtent = 320;
  double _heroCollapseThreshold = 200;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _snapHeroTo(double target) async {
    if (!mounted || _isAutoSnapping || !_scrollController.hasClients) return;
    final current = _scrollController.offset;
    if ((current - target).abs() < 1.0) return;
    _isAutoSnapping = true;
    try {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutQuart,
      );
    } finally {
      _isAutoSnapping = false;
    }
  }

  bool _handleHeroSnapNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical ||
        _heroCollapseExtent <= 1.0) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isAutoSnapping = false;
        _dragStartedCollapsed =
            notification.metrics.pixels >= _heroCollapseExtent - 2.0;
      }
      return false;
    }

    if (notification is ScrollEndNotification && !_isAutoSnapping) {
      final offset = notification.metrics.pixels;
      final maxExtent = notification.metrics.maxScrollExtent;
      if (offset > 0.5 &&
          offset < _heroCollapseExtent - 0.5 &&
          maxExtent > 1.0) {
        final shouldCollapse = _dragStartedCollapsed
            ? offset > _heroCollapseExtent * 0.70
            : offset >= _heroCollapseExtent * 0.30;
        final target = (shouldCollapse ? _heroCollapseExtent : 0.0).clamp(
          0.0,
          maxExtent,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _snapHeroTo(target);
        });
      }
    }
    return false;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    final collapsed = current >= _heroCollapseThreshold;
    if (collapsed != _isHeroCollapsed) {
      setState(() => _isHeroCollapsed = collapsed);
    }
    if (current >= maxScroll - 350) {
      _loadMoreProducts();
    }
  }

  void _ensureRecommendationsStarted(CustomerProduct product) {
    if (_anchorProduct?.id == product.id) return;
    _anchorProduct = product;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMoreProducts();
    });
  }

  Set<String> _extractTokens(String? text) {
    if (text == null || text.trim().isEmpty) return const {};
    return text
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .split(RegExp(r'[\s\-_,،./\\()]+'))
        .where((w) => w.length >= 2)
        .toSet();
  }

  double _similarityScore(CustomerProduct candidate, CustomerProduct anchor) {
    double score = 0;
    if (anchor.categoryId != null &&
        candidate.categoryId == anchor.categoryId) {
      score += 60;
    }

    final anchorNameTokens = _extractTokens(anchor.name);
    final candNameTokens = _extractTokens(candidate.name);
    final sharedName = anchorNameTokens.intersection(candNameTokens).length;
    score += sharedName * 20;

    final anchorDescTokens = _extractTokens(anchor.description);
    final candDescTokens = _extractTokens(candidate.description);
    final sharedDesc = anchorDescTokens.intersection(candDescTokens).length;
    score += sharedDesc.clamp(0, 4) * 5;

    final anchorBrand = anchor.details['brand']?.toString().trim().toLowerCase();
    final candBrand = candidate.details['brand']
        ?.toString()
        .trim()
        .toLowerCase();
    if (anchorBrand != null &&
        anchorBrand.isNotEmpty &&
        anchorBrand == candBrand) {
      score += 12;
    }

    final anchorColors = anchor.availableColors
        .map((c) => c.trim().toLowerCase())
        .toSet();
    final candColors = candidate.availableColors
        .map((c) => c.trim().toLowerCase())
        .toSet();
    if (anchorColors.intersection(candColors).isNotEmpty) {
      score += 8;
    }

    if (anchor.price > 0 && candidate.price > 0) {
      final ratioDiff = (candidate.price - anchor.price).abs() / anchor.price;
      if (ratioDiff <= 0.35) {
        score += 10 * (1 - ratioDiff / 0.35);
      }
    }

    if (candidate.shopId == anchor.shopId) {
      score += 6;
    }
    if (candidate.totalStock > 0) {
      score += 4;
    }
    return score;
  }

  Future<void> _loadMoreProducts() async {
    final anchor = _anchorProduct;
    if (anchor == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final incoming = <CustomerProduct>[];

      // Phase 1: Same category + sibling department + keyword-similar products FIRST
      if (!_similarLoaded) {
        _similarLoaded = true;
        final candidates = <String, CustomerProduct>{};

        if (anchor.categoryId != null && anchor.categoryId!.isNotEmpty) {
          final sameCat = await repo.getProducts(
            categoryId: anchor.categoryId,
            excludeProductId: anchor.id,
            limit: 24,
            offset: 0,
          );
          for (final item in sameCat) {
            if (item.id != anchor.id) candidates[item.id] = item;
          }

          // Also include sibling subcategories under the same parent department
          final allCats = await repo.getCategories();
          final currentCat = allCats
              .where((c) => c.id == anchor.categoryId)
              .firstOrNull;
          final parentId = currentCat?.parentId;
          if (parentId != null && parentId.isNotEmpty) {
            final deptItems = await repo.getProducts(
              categoryId: parentId,
              excludeProductId: anchor.id,
              limit: 24,
              offset: 0,
            );
            for (final item in deptItems) {
              if (item.id != anchor.id) candidates.putIfAbsent(item.id, () => item);
            }
          }
        }

        final ranked = candidates.values.toList()
          ..sort(
            (a, b) => _similarityScore(b, anchor).compareTo(
              _similarityScore(a, anchor),
            ),
          );
        incoming.addAll(ranked);

        // If fewer than a full page of same-category items exist, top up with general products
        if (incoming.length < _pageSize) {
          final general = await repo.getProducts(
            excludeProductId: anchor.id,
            limit: _pageSize,
            offset: _generalOffset,
          );
          _generalOffset += general.length;
          if (general.length < _pageSize) {
            _hasMore = false;
          }
          general.sort(
            (a, b) => _similarityScore(b, anchor).compareTo(
              _similarityScore(a, anchor),
            ),
          );
          incoming.addAll(general);
        }
      } else {
        // Phase 2: Seamless pagination through remaining catalog products
        final general = await repo.getProducts(
          excludeProductId: anchor.id,
          limit: _pageSize,
          offset: _generalOffset,
        );
        _generalOffset += general.length;
        if (general.length < _pageSize) {
          _hasMore = false;
        }
        general.sort(
          (a, b) => _similarityScore(b, anchor).compareTo(
            _similarityScore(a, anchor),
          ),
        );
        incoming.addAll(general);
      }

      if (!mounted) return;
      setState(() {
        for (final item in incoming) {
          if (item.id != anchor.id && _recommendedIds.add(item.id)) {
            _recommendedProducts.add(item);
          }
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setRecommendedFavorite(String productId, bool isFavorite) {
    setState(() {
      for (var i = 0; i < _recommendedProducts.length; i++) {
        if (_recommendedProducts[i].id == productId) {
          _recommendedProducts[i] = _recommendedProducts[i].copyWith(
            isFavorite: isFavorite,
          );
        }
      }
    });
  }

  Future<void> _toggleFavorite(CustomerProduct product) async {
    final nextFav = !product.isFavorite;
    syncFavoriteAcrossProductLists(ref, product, nextFav);
    _setRecommendedFavorite(product.id, nextFav);
    try {
      await ref.read(customerRepositoryProvider).toggleFavorite(product.id);
      ref.invalidate(customerProductDetailsProvider(product.id));
    } catch (_) {
      syncFavoriteAcrossProductLists(ref, product, product.isFavorite);
      if (mounted) {
        _setRecommendedFavorite(product.id, product.isFavorite);
      }
    }
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
    var reviewFilter = ReviewFilterState.empty;

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
              final filteredReviews = filterProductReviews(
                currentReviews,
                reviewFilter,
              );

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
                                          color: AppColors.borderStrong,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'آراء العملاء السابقة'.tr,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: AppFont.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (currentReviews.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: AppHaptics.action(() async {
                                      final picked =
                                          await showAppSortSheet<
                                            ReviewSortOption
                                          >(
                                            context: ctx,
                                            current: reviewFilter.sort,
                                            options: const [
                                              AppSortChoice(
                                                value: ReviewSortOption.newest,
                                                label: 'الأحدث',
                                                icon: AppIcons.arrowDown,
                                              ),
                                              AppSortChoice(
                                                value: ReviewSortOption
                                                    .highestRating,
                                                label: 'الأعلى تقييماً',
                                                icon: AppIcons.starFilled,
                                              ),
                                              AppSortChoice(
                                                value: ReviewSortOption
                                                    .lowestRating,
                                                label: 'الأقل تقييماً',
                                                icon: AppIcons.star,
                                              ),
                                            ],
                                          );
                                      if (picked != null) {
                                        setSheetState(
                                          () => reviewFilter = reviewFilter
                                              .copyWith(sort: picked),
                                        );
                                      }
                                    }),
                                    icon: const Icon(
                                      Icons.swap_vert_rounded,
                                      size: 16,
                                    ),
                                    label: Text(reviewFilter.sort.labelAr.tr),
                                  ),
                              ],
                            ),
                            if (currentReviews.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    FilterChip(
                                      label: Text(
                                        '${'الكل'.tr} (${currentReviews.length})',
                                      ),
                                      selected: reviewFilter.rating == null,
                                      onSelected: (_) => setSheetState(
                                        () => reviewFilter = reviewFilter
                                            .copyWith(clearRating: true),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    for (final star in const [5, 4, 3, 2, 1]) ...[
                                      FilterChip(
                                        avatar: Icon(
                                          AppIcons.starFilled,
                                          size: 14,
                                          color: ProductDetailsDesign.ratingStar,
                                        ),
                                        label: Text(
                                          '$star (${currentReviews.where((r) => r.rating == star).length})',
                                        ),
                                        selected: reviewFilter.rating == star,
                                        onSelected: (_) => setSheetState(
                                          () => reviewFilter =
                                              reviewFilter.rating == star
                                                  ? reviewFilter.copyWith(
                                                      clearRating: true,
                                                    )
                                                  : reviewFilter.copyWith(
                                                      rating: star,
                                                    ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                    ],
                                    FilterChip(
                                      label: Text('مع تعليق فقط'.tr),
                                      selected: reviewFilter.withCommentOnly,
                                      onSelected: (v) => setSheetState(
                                        () => reviewFilter = reviewFilter
                                            .copyWith(withCommentOnly: v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            if (currentReviews.isEmpty)
                              AppEmpty(
                                icon: AppIcons.reviews,
                                message:
                                    'لا توجد تقييمات لهذا المنتج بعد. كن أول من يقيّمه.'
                                        .tr,
                              )
                            else if (filteredReviews.isEmpty)
                              AppFilterEmptyState(
                                onReset: () => setSheetState(
                                  () => reviewFilter = ReviewFilterState.empty,
                                ),
                              )
                            else
                              ...filteredReviews.map(
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

        // Initialize default selections & load category-matched recommendations
        if (productAsync.hasValue) {
          _ensureRecommendationsStarted(product);
        }
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
        final topPadding = MediaQuery.paddingOf(context).top;
        final minGalleryHeight =
            topPadding +
            ProductDetailsDesign.floatingButtonSize +
            (AppSpacing.sm * 2);
        final stageHeight = (screenHeight * 0.48).clamp(300.0, 460.0);
        final galleryHeight =
            minGalleryHeight + stageHeight + ProductDetailsDesign.contentOverlap;
        _heroCollapseExtent = (galleryHeight - minGalleryHeight).clamp(
          1.0,
          double.infinity,
        );
        _heroCollapseThreshold = _heroCollapseExtent * 0.68;

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

        final isLoadingSkeleton =
            productAsync.isLoading && !productAsync.hasValue;
        final useDarkStatusIcons =
            !isLoadingSkeleton && (!_isHeroCollapsed || !AppColors.isDark);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                useDarkStatusIcons ? Brightness.dark : Brightness.light,
            statusBarBrightness:
                useDarkStatusIcons ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: ProductDetailsDesign.pageBackground,
          body: Stack(
            children: [
              // 1) Main Scrollable Content (Collapsing Hero Gallery + Editorial Sheet)
              AppRefreshIndicator(
                edgeOffset: topPadding + ProductDetailsDesign.floatingButtonSize + AppSpacing.sm,
                onRefresh: () => Future.wait([
                  ref.refresh(
                    customerProductDetailsProvider(widget.productId).future,
                  ),
                  ref.refresh(productReviewsProvider(widget.productId).future),
                ]),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleHeroSnapNotification,
                  child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _HeroGallerySliverDelegate(
                        maxHeight: galleryHeight,
                        minHeight: minGalleryHeight,
                        product: product,
                        galleryController: _galleryController,
                        currentImageIndex: _currentImageIndex,
                        onPageChanged: (index) =>
                            setState(() => _currentImageIndex = index),
                        onOpenFullscreen: (index) => _openFullScreenGallery(
                          context,
                          product.images,
                          index,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: ProductDetailsDesign.contentBackground,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
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
                                          gradient: ProductDetailsDesign
                                              .studioGradient,
                                          borderRadius: BorderRadius.circular(
                                            ProductDetailsDesign.thumbRadius,
                                          ),
                                        ),
                                        foregroundDecoration: BoxDecoration(
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
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                          height: double.infinity,
                                          contentPadding:
                                              const EdgeInsets.all(4),
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

                            // Price + Original Price + Discount Badge + Stock Status Pill
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
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
                                if (product.hasOffer &&
                                    product.originalPrice != null) ...[
                                  Text(
                                    AppFormat.price(product.originalPrice!),
                                    style: TextStyle(
                                      fontSize:
                                          ProductDetailsDesign.priceSize - 8,
                                      fontWeight: AppFont.medium,
                                      color: AppColors.textMuted,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: AppColors.textMuted,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: Text(
                                      '-${product.discountPercent}%',
                                      style: const TextStyle(
                                        color: AppPalette.white,
                                        fontSize: 11.5,
                                        fontWeight: AppFont.bold,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                                _StockBadge(stock: currentStock),
                                if (product.categoryName != null &&
                                    product.categoryName!.trim().isNotEmpty)
                                  InkWell(
                                    onTap: product.categoryId == null
                                        ? null
                                        : AppHaptics.action(() {
                                            ref
                                                .read(
                                                  productFilterProvider
                                                      .notifier,
                                                )
                                                .state = ProductFilter(
                                              categoryId: product.categoryId,
                                            );
                                            context.push(
                                              AppRoutes.customerCatalog,
                                            );
                                          }),
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
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        product.categoryName!.trim().tr,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: AppFont.semiBold,
                                          color: AppColors.textSecondary,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(
                              height: ProductDetailsDesign.sectionSpacing,
                            ),
                            const Divider(height: 1),

                            // Color & Size Selection (circles only, 50/50 split with full-height centered divider)
                            if (product.availableColors.isNotEmpty ||
                                allSizes.isNotEmpty)
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (product.availableColors.isNotEmpty)
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(
                                            0,
                                            14,
                                            allSizes.isNotEmpty ? 14 : 0,
                                            14,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'حدد اللون'.tr,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: AppFont.semiBold,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: product
                                                    .availableColors
                                                    .map((clr) {
                                                      final isSelected =
                                                          _selectedColor == clr;
                                                      return ColorSwatchCircle(
                                                        colorName: clr,
                                                        selected: isSelected,
                                                        size: 30,
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedColor =
                                                                clr;
                                                            _selectedSize =
                                                                null;
                                                          });
                                                        },
                                                      );
                                                    })
                                                    .toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (product.availableColors.isNotEmpty &&
                                        allSizes.isNotEmpty)
                                      VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: AppColors.divider,
                                      ),
                                    if (allSizes.isNotEmpty)
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(
                                            product.availableColors.isNotEmpty
                                                ? 14
                                                : 0,
                                            14,
                                            0,
                                            14,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'حدد القياس'.tr,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: AppFont.semiBold,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 8,
                                                children: allSizes.map((sz) {
                                                  final available =
                                                      matchingSizes.contains(
                                                        sz,
                                                      );
                                                  final isSelected =
                                                      _selectedSize == sz;
                                                  return SizeSwatchCircle(
                                                    label: sz,
                                                    selected: isSelected,
                                                    enabled: available,
                                                    size: 36,
                                                    onTap: available
                                                        ? () => setState(
                                                            () =>
                                                                _selectedSize =
                                                                    sz,
                                                          )
                                                        : null,
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

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

                            // Customer Reviews Preview Card (tapping opens full reviews & add-review sheet)
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

                            const SizedBox(height: AppSpacing.lg),

                            // Infinite Recommendations Section (same category & similar first)
                            AppSectionHeader(
                              padding: EdgeInsets.zero,
                              title: 'منتجات قد تعجبك'.tr,
                            ),
                            const SizedBox(height: AppSpacing.sm),

                            if (_recommendedProducts.isEmpty && _loadingMore)
                              const ProductGridSkeleton()
                            else if (_recommendedProducts.isNotEmpty) ...[
                              GridView.builder(
                                padding: EdgeInsets.zero,
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
                                    originalMeta: recProduct.hasOffer
                                        ? AppFormat.price(
                                            recProduct.originalPrice!,
                                          )
                                        : null,
                                    discountPercent: recProduct.hasOffer
                                        ? recProduct.discountPercent
                                        : null,
                                    inStock: recProduct.totalStock > 0,
                                    isFavorite: recProduct.isFavorite,
                                    onToggleFavorite: () =>
                                        _toggleFavorite(recProduct),
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
              ),

              // 2) Floating Top Bar over the Gallery (Back, Logo, Compare, Favorite, Cart)
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
                        const SizedBox(width: AppSpacing.xs),
                        const AppLogoMark(),
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
                                    await _toggleFavorite(product);
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

          // 3) Sticky Bottom Action Bar: Try-On CTA + Quantity Stepper & Add to Cart CTA
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Subtle Light-Gray Try-On Button above Add to Cart
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceAlt,
                          foregroundColor: AppColors.text,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.button,
                            ),
                            side: BorderSide(color: AppColors.border),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.bold,
                          ),
                        ),
                        icon: const Icon(AppIcons.tryOn, size: 19),
                        label: Text('جرب الملابس'.tr),
                        onPressed: AppHaptics.action(
                          () => context.push(
                            AppRoutes.customerRealtimeTryonPath(product.id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
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
                  ],
                ),
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
          message: AppErrorMapper.message(
            err,
            fallback: 'تعذر تحميل تفاصيل المنتج حالياً. حاول مرة أخرى.',
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'متوفر في المخزون'.tr,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: AppFont.semiBold,
          color: AppColors.textSecondary,
          height: 1.1,
        ),
      ),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: ProductDetailsDesign.studioGradient,
                  ),
                  child: InteractiveViewer(
                    maxScale: GalleryViewerDesign.maxZoom,
                    child: Center(
                      child: AppNetworkImage(
                        widget.images[index].filePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        contentPadding: const EdgeInsets.all(AppSpacing.lg),
                      ),
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
    ),
    );
  }
}

class _HeroGallerySliverDelegate extends SliverPersistentHeaderDelegate {
  const _HeroGallerySliverDelegate({
    required this.maxHeight,
    required this.minHeight,
    required this.product,
    required this.galleryController,
    required this.currentImageIndex,
    required this.onPageChanged,
    required this.onOpenFullscreen,
  });

  final double maxHeight;
  final double minHeight;
  final CustomerProduct product;
  final PageController galleryController;
  final int currentImageIndex;
  final ValueChanged<int> onPageChanged;
  final void Function(int index) onOpenFullscreen;

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final raw = (shrinkOffset / range).clamp(0.0, 1.0);
    final curved = Curves.easeOutCubic.transform(raw);
    final imageScale = 1.0 - 0.16 * curved;
    final imageOpacity = (1.0 - 1.15 * Curves.easeInCubic.transform(raw)).clamp(
      0.0,
      1.0,
    );
    final headerFade = Curves.easeInOutCubic.transform(
      ((raw - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    final controlsOpacity = (1.0 - raw * 2.4).clamp(0.0, 1.0);
    final sheetProgress = Curves.easeInOutCubic.transform(raw);
    final capHeight =
        ProductDetailsDesign.contentOverlap * (1.0 - sheetProgress);
    final capRadius = ProductDetailsDesign.contentRadius * (1.0 - sheetProgress);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ProductDetailsDesign.studioGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed product image positioned cleanly below the top icons;
          // moves smoothly upward and gently shrinks as the user scrolls down.
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: maxExtent,
              child: SizedBox(
                height: maxExtent,
                child: Transform.translate(
                  offset: Offset(0, -shrinkOffset * 0.48),
                  child: Transform.scale(
                    scale: imageScale,
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: imageOpacity,
                      child: product.images.isNotEmpty
                          ? PageView.builder(
                              controller: galleryController,
                              itemCount: product.images.length,
                              onPageChanged: onPageChanged,
                              itemBuilder: (context, index) {
                                final img = product.images[index];
                                return GestureDetector(
                                  onTap: AppHaptics.action(
                                    () => onOpenFullscreen(index),
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  child: AppNetworkImage(
                                    img.filePath,
                                    fit: ProductDetailsDesign.galleryImageFit,
                                    width: double.infinity,
                                    height: double.infinity,
                                    contentPadding: EdgeInsets.fromLTRB(
                                      AppSpacing.lg,
                                      minExtent + 8,
                                      AppSpacing.lg,
                                      ProductDetailsDesign.contentOverlap + 18,
                                    ),
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(
                                        AppIcons.garment,
                                        size: 48,
                                        color: AppColors.iconMuted,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                AppIcons.garment,
                                size: 54,
                                color: AppColors.iconMuted,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Cross-fade into solid header surface as the hero collapses upward
          if (headerFade > 0.01)
            IgnorePointer(
              child: ColoredBox(
                color: ProductDetailsDesign.contentBackground.withValues(
                  alpha: headerFade,
                ),
              ),
            ),

          if (controlsOpacity > 0.02 && product.images.isNotEmpty)
            PositionedDirectional(
              start: AppSpacing.md,
              end: AppSpacing.md,
              bottom: ProductDetailsDesign.contentOverlap + 14,
              child: IgnorePointer(
                ignoring: controlsOpacity < 0.35,
                child: Opacity(
                  opacity: controlsOpacity,
                  child: Row(
                    children: [
                      if (product.hasOffer && product.discountPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                              color: AppPalette.white,
                              fontSize: 12,
                              fontWeight: AppFont.bold,
                              height: 1.1,
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
                            color: ProductDetailsDesign.counterBackground,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            '${currentImageIndex + 1} / ${product.images.length}',
                            style: const TextStyle(
                              color: ProductDetailsDesign.counterText,
                              fontSize: ProductDetailsDesign.counterTextSize,
                              fontWeight: AppFont.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: AppSpacing.xs),
                      _FloatingCircleButton(
                        icon: AppIcons.fullscreen,
                        tooltip: 'تكبير الصورة'.tr,
                        onTap: () => onOpenFullscreen(currentImageIndex),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (capHeight > 0.5)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: capHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: ProductDetailsDesign.contentBackground,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(capRadius),
                  ),
                ),
              ),
            ),

          if (curved > 0.85)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: ((curved - 0.85) / 0.15).clamp(0.0, 1.0),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppBarDesign.borderColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeroGallerySliverDelegate oldDelegate) {
    return oldDelegate.maxHeight != maxHeight ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.product != product ||
        oldDelegate.currentImageIndex != currentImageIndex;
  }
}
