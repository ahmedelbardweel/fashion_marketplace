import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_design.dart';
import 'app_skeleton.dart';

/// Responsive grid delegate driven by [ProductGridDesign] and [ProductCardDesign].
class ProductGridDelegate extends SliverGridDelegate {
  const ProductGridDelegate({this.textScale = 1});
  final double textScale;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final count = width < 280
        ? 1
        : (width / ProductGridDesign.minCardWidth)
              .floor()
              .clamp(ProductGridDesign.minColumns, ProductGridDesign.maxColumns);
    final cardWidth =
        (width - (count - 1) * ProductGridDesign.crossSpacing) / count;
    final imageHeight = cardWidth / ProductCardDesign.imageAspectRatio;
    final footerHeight = ProductCardDesign.infoHeight + (textScale - 1) * 14;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      crossAxisSpacing: ProductGridDesign.crossSpacing,
      mainAxisSpacing: ProductGridDesign.mainSpacing,
      mainAxisExtent: imageHeight + footerHeight,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(ProductGridDelegate oldDelegate) =>
      textScale != oldDelegate.textScale;
}

/// Minimalist fashion product card:
/// Displays ONLY the product image, favorite button in the top corner,
/// price, and add-to-cart button. All visual styling comes from [ProductCardDesign].
class ProductGridCard extends StatefulWidget {
  const ProductGridCard({
    super.key,
    required this.meta,
    this.originalMeta,
    this.discountPercent,
    this.title = '',
    this.subtitle = '',
    this.imageUrl,
    this.onTap,
    this.onAddToCart,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.showFavorite = true,
    this.inStock = true,
  });

  /// Kept as optional parameters for backward compatibility across call sites;
  /// not rendered on the card per design specification.
  final String title;
  final String subtitle;

  /// Current / discounted price string (e.g. "120.00 ₪").
  final String meta;

  /// Optional original price before discount (rendered smaller with strikethrough).
  final String? originalMeta;

  /// Optional discount percentage (e.g. 20 -> displays "-20%" badge).
  final int? discountPercent;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final Future<void> Function()? onToggleFavorite;
  final bool isFavorite;
  final bool showFavorite;
  final bool inStock;

  @override
  State<ProductGridCard> createState() => _ProductGridCardState();
}

class _ProductGridCardState extends State<ProductGridCard> {
  late bool _isFavorite = widget.isFavorite;
  bool _togglingFavorite = false;

  @override
  void didUpdateWidget(covariant ProductGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite && !_togglingFavorite) {
      _isFavorite = widget.isFavorite;
    }
  }

  Future<void> _handleFavoriteTap() async {
    if (_togglingFavorite || widget.onToggleFavorite == null) return;
    final previous = _isFavorite;
    setState(() {
      _isFavorite = !previous;
      _togglingFavorite = true;
    });
    try {
      await widget.onToggleFavorite!();
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = previous);
      }
    } finally {
      if (mounted) {
        setState(() => _togglingFavorite = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageRadius = BorderRadius.circular(ProductCardDesign.imageRadius);
    final canAddToCart = widget.inStock && widget.onAddToCart != null;
    final isSkeleton = AppSkeleton.isActive(context);

    return Container(
      padding: ProductCardDesign.cardPadding,
      decoration: BoxDecoration(
        color: ProductCardDesign.cardBackground,
        borderRadius: BorderRadius.circular(ProductCardDesign.cardRadius),
        boxShadow: ProductCardDesign.cardShadow,
        border: ProductCardDesign.cardBorderWidth > 0
            ? Border.all(
                color: ProductCardDesign.cardBorderColor,
                width: ProductCardDesign.cardBorderWidth,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) Image + Favorite Corner Button + Out-of-stock Badge
          Expanded(
            child: GestureDetector(
              onTap: AppHaptics.action(widget.onTap),
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  color: isSkeleton
                      ? SkeletonDesign.base
                      : ProductCardDesign.imageBackground,
                  gradient: isSkeleton
                      ? null
                      : ProductDetailsDesign.studioGradient,
                  borderRadius: imageRadius,
                  border: Border.all(
                    color: isSkeleton
                        ? AppColors.border
                        : ProductCardDesign.imageBorderColor,
                    width: ProductCardDesign.imageBorderWidth,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: isSkeleton
                    ? Bone(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: imageRadius,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: widget.inStock
                                ? 1
                                : ProductCardDesign.outOfStockImageOpacity,
                            child: widget.imageUrl == null ||
                                    widget.imageUrl!.isEmpty
                                ? Center(
                                    child: Icon(
                                      AppIcons.garment,
                                      size: 32,
                                      color: ProductCardDesign.placeholderIcon,
                                    ),
                                  )
                                : AppNetworkImage(
                                    widget.imageUrl!,
                                    fit: ProductCardDesign.imageFit,
                                    alignment: Alignment.center,
                                    contentPadding:
                                        ProductCardDesign.imageInnerPadding,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Icon(
                                        AppIcons.imageBroken,
                                        size: 28,
                                        color:
                                            ProductCardDesign.placeholderIcon,
                                      ),
                                    ),
                                  ),
                          ),

                          // Out of stock pill
                          if (!widget.inStock)
                            PositionedDirectional(
                              bottom: ProductCardDesign.favoriteInset,
                              start: ProductCardDesign.favoriteInset,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ProductCardDesign
                                      .outOfStockBadgeBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                                child: Text(
                                  ProductCardDesign.outOfStockLabel,
                                  style: const TextStyle(
                                    color:
                                        ProductCardDesign.outOfStockBadgeText,
                                    fontSize: 10,
                                    fontWeight: AppFont.bold,
                                  ),
                                ),
                              ),
                            ),

                          // Favorite button & discount badge directly below it
                          if ((widget.showFavorite &&
                                  widget.onToggleFavorite != null) ||
                              (widget.discountPercent != null &&
                                  widget.discountPercent! > 0))
                            Align(
                              alignment: ProductCardDesign.favoriteAlignment,
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  ProductCardDesign.favoriteInset,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (widget.showFavorite &&
                                        widget.onToggleFavorite != null)
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: AppHaptics.action(
                                            _handleFavoriteTap,
                                          ),
                                          customBorder: const CircleBorder(),
                                          child: Container(
                                            width:
                                                ProductCardDesign.favoriteSize,
                                            height:
                                                ProductCardDesign.favoriteSize,
                                            decoration: BoxDecoration(
                                              color: ProductCardDesign
                                                  .favoriteBackground,
                                              shape: BoxShape.circle,
                                              boxShadow: ProductCardDesign
                                                  .favoriteShadow,
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              _isFavorite
                                                  ? AppIcons.heartFilled
                                                  : AppIcons.heart,
                                              size: ProductCardDesign
                                                  .favoriteIconSize,
                                              color: _isFavorite
                                                  ? ProductCardDesign
                                                        .favoriteActiveIcon
                                                  : ProductCardDesign
                                                        .favoriteIcon,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (widget.discountPercent != null &&
                                        widget.discountPercent! > 0) ...[
                                      if (widget.showFavorite &&
                                          widget.onToggleFavorite != null)
                                        const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                        child: Text(
                                          '-${widget.discountPercent}%',
                                          style: const TextStyle(
                                            color: AppPalette.white,
                                            fontSize: 10.5,
                                            fontWeight: AppFont.bold,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: ProductCardDesign.infoTopSpacing),

          // 2) New Price + Old Price (strikethrough) + Add to Cart Button
          SizedBox(
            height: ProductCardDesign.cartButtonSize,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: AppHaptics.action(widget.onTap),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            AppLang.tr(widget.meta),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ProductCardDesign.priceSize,
                              fontWeight: ProductCardDesign.priceWeight,
                              color: ProductCardDesign.priceColor,
                            ),
                          ),
                        ),
                        if (widget.originalMeta != null &&
                            widget.originalMeta!.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              AppLang.tr(widget.originalMeta!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ProductCardDesign.priceSize - 3.5,
                                fontWeight: AppFont.medium,
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.onAddToCart != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Material(
                    color: canAddToCart
                        ? ProductCardDesign.cartButtonBackground
                        : ProductCardDesign.cartButtonDisabledBackground,
                    borderRadius: BorderRadius.circular(
                      ProductCardDesign.cartButtonRadius,
                    ),
                    child: InkWell(
                      onTap: AppHaptics.action(
                        canAddToCart ? widget.onAddToCart : null,
                      ),
                      borderRadius: BorderRadius.circular(
                        ProductCardDesign.cartButtonRadius,
                      ),
                      child: SizedBox(
                        width: ProductCardDesign.cartButtonSize,
                        height: ProductCardDesign.cartButtonSize,
                        child: Icon(
                          AppIcons.addToCart,
                          size: ProductCardDesign.cartIconSize,
                          color: canAddToCart
                              ? ProductCardDesign.cartButtonIcon
                              : ProductCardDesign.cartButtonDisabledIcon,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
