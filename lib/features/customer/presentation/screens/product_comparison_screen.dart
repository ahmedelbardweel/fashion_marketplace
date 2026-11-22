import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../router/routes.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class ProductComparisonScreen extends ConsumerWidget {
  const ProductComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productComparisonProvider);

    final hasMultiple = products.length >= 2;
    double? lowestPrice;
    double? highestRating;
    if (hasMultiple) {
      final prices = products.map((p) => p.price).toSet();
      if (prices.length > 1) {
        lowestPrice = products
            .map((p) => p.price)
            .reduce((a, b) => a < b ? a : b);
      }
      final ratings = products.map((p) => p.ratingAvg).toSet();
      final maxRating = products
          .map((p) => p.ratingAvg)
          .reduce((a, b) => a > b ? a : b);
      if (ratings.length > 1 && maxRating > 0) {
        highestRating = maxRating;
      }
    }

    return CustomerScaffold(
      title: 'مقارنة المنتجات'.tr,
      showBottomNav: false,
      body: products.isEmpty
          ? AppEmpty(
              icon: AppIcons.compare,
              title: 'قائمة المقارنة فارغة'.tr,
              message:
                  'أضف منتجين أو أكثر من صفحة المنتج للمقارنة جنباً إلى جنب'.tr,
              actionLabel: 'تصفح المنتجات'.tr,
              onAction: AppHaptics.action(
                () => context.go(AppRoutes.customerCatalog),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Compact top summary bar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${'منتجات للمقارنة'.tr} (${products.length})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: AppFont.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: AppHaptics.action(() {
                          ref.read(productComparisonProvider.notifier).clear();
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(AppIcons.delete, size: 14),
                        label: Text(
                          'مسح الكل'.tr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.semiBold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Compact vertically stacked cards (all 3 fit in one screen)
                  for (var i = 0; i < products.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ComparisonProductCard(
                      product: products[i],
                      isBestPrice:
                          lowestPrice != null &&
                          products[i].price == lowestPrice,
                      isTopRated:
                          highestRating != null &&
                          products[i].ratingAvg == highestRating,
                      onRemove: () => ref
                          .read(productComparisonProvider.notifier)
                          .removeProduct(products[i].id),
                      onOpenDetails: () => context.push(
                        AppRoutes.customerProductDetailsPath(products[i].id),
                      ),
                    ),
                  ],

                  if (products.length == 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(CardDesign.radius),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.compare,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'أضف منتجاً آخر للمقارنة بين الأسعار والمواصفات'
                                  .tr,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          TextButton(
                            onPressed: AppHaptics.action(
                              () => context.go(AppRoutes.customerCatalog),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'تصفح المنتجات'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: AppFont.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ComparisonProductCard extends StatelessWidget {
  const _ComparisonProductCard({
    required this.product,
    required this.isBestPrice,
    required this.isTopRated,
    required this.onRemove,
    required this.onOpenDetails,
  });

  final CustomerProduct product;
  final bool isBestPrice;
  final bool isTopRated;
  final VoidCallback onRemove;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final colorsText = product.availableColors.isEmpty
        ? 'قياسي'.tr
        : product.availableColors.join('، ');
    final sizesText = product.availableSizes.isEmpty
        ? 'قياسي'.tr
        : product.availableSizes.join('، ');
    final inStock = product.totalStock > 0;
    final stockText = inStock
        ? '${product.totalStock} قطعة'.tr
        : 'نفد المخزون'.tr;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: CardDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact header: 60x60 image + name, shop, rating, price, badges, remove
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: AppHaptics.action(onOpenDetails),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: CompareDesign.imageBackground,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.coverImage != null
                      ? AppNetworkImage(
                          product.coverImage!,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                        )
                      : Center(
                          child: Icon(
                            AppIcons.garment,
                            color: AppColors.iconMuted,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: AppColors.surfaceAlt,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: AppHaptics.action(onRemove),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                AppIcons.close,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.primary,
                              fontWeight: AppFont.semiBold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            '·',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        Icon(
                          AppIcons.starFilled,
                          color: AppColors.rating,
                          size: 13,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFont.semiBold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          AppFormat.price(product.price),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFont.extraBold,
                            color: AppColors.text,
                          ),
                        ),
                        if (product.hasOffer && product.originalPrice != null) ...[
                          Text(
                            AppFormat.price(product.originalPrice!),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                          if (product.discountPercent > 0)
                            _MiniBadge(
                              label: '-${product.discountPercent}%',
                              bg: AppColors.error,
                              fg: AppPalette.white,
                            ),
                        ],
                        if (isBestPrice)
                          _MiniBadge(
                            label: 'أفضل سعر'.tr,
                            bg: AppColors.successSoft,
                            fg: AppColors.success,
                          ),
                        if (isTopRated)
                          _MiniBadge(
                            label: 'الأعلى تقييماً'.tr,
                            bg: AppColors.warningSoft,
                            fg: AppColors.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Compact 3-column spec strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _CompactSpecCell(
                      label: 'الألوان'.tr,
                      value: colorsText,
                    ),
                  ),
                  VerticalDivider(
                    width: 12,
                    thickness: 1,
                    color: AppColors.divider,
                  ),
                  Expanded(
                    child: _CompactSpecCell(
                      label: 'المقاسات'.tr,
                      value: sizesText,
                    ),
                  ),
                  VerticalDivider(
                    width: 12,
                    thickness: 1,
                    color: AppColors.divider,
                  ),
                  Expanded(
                    child: _CompactSpecCell(
                      label: 'المخزون'.tr,
                      value: stockText,
                      valueColor: inStock ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Slim full-width details action
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: AppHaptics.action(onOpenDetails),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                elevation: 0,
              ),
              child: Text(
                'عرض التفاصيل'.tr,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: AppFont.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSpecCell extends StatelessWidget {
  const _CompactSpecCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            color: CompareDesign.rowLabelColor,
            fontWeight: AppFont.medium,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: AppFont.semiBold,
            color: valueColor ?? AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: AppFont.bold,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}
