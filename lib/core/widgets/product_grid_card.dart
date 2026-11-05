import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';
import 'app_skeleton.dart';

/// Uses the available grid width, including split-screen and desktop layouts.
class ProductGridDelegate extends SliverGridDelegate {
  const ProductGridDelegate({this.textScale = 1});
  final double textScale;
  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final count = width < 280 ? 1 : (width / 170).floor().clamp(2, 6);
    final cardWidth = (width - (count - 1) * 8) / count;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      crossAxisSpacing: 8,
      mainAxisSpacing: 12,
      mainAxisExtent: cardWidth * 1.15 + 78 + 94 * textScale,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(ProductGridDelegate oldDelegate) =>
      textScale != oldDelegate.textScale;
}

class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.imageUrl,
    this.onTap,
    this.onAddToCart,
    this.inStock = true,
  });
  final String title;
  final String subtitle;
  final String meta;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: AppColors.gray100,
              child: imageUrl == null || imageUrl!.isEmpty
                  ? const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: AppColors.gray500,
                      ),
                    )
                  : AppNetworkImage(
                      imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall?.copyWith(color: AppColors.gray500),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(14) * 3,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleSmall?.copyWith(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                  ),
                  onPressed: inStock ? onAddToCart : null,
                  child: Text(
                    inStock ? 'إضافة إلى السلة' : 'نفدت الكمية',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
