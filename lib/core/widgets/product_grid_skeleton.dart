import 'package:flutter/material.dart';

import 'app_skeleton.dart';
import 'product_grid_card.dart';

/// Appended product placeholders reuse the actual card and grid dimensions.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key});
  @override
  Widget build(BuildContext context) => AppSkeleton(
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      gridDelegate: ProductGridDelegate(
        textScale: MediaQuery.textScalerOf(context).scale(14) / 14,
      ),
      itemBuilder: (_, _) => ProductGridCard(
        meta: '120.00 ₪',
        imageUrl: 'skeleton://product',
        onAddToCart: () {},
        onToggleFavorite: () async {},
      ),
    ),
  );
}
