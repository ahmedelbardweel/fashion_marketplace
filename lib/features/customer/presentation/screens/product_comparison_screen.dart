import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class ProductComparisonScreen extends ConsumerWidget {
  const ProductComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productComparisonProvider);

    return CustomerScaffold(
      title: 'مقارنة المنتجات'.tr,
      showSearch: false,
      actions: [
        if (products.isNotEmpty)
          TextButton(
            onPressed: AppHaptics.action(() {
              ref.read(productComparisonProvider.notifier).clear();
            }),
            child: Text('مسح الكل'.tr),
          ),
      ],
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
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: products.map((product) {
                  return Container(
                    width: 250,
                    margin: const EdgeInsetsDirectional.only(
                      end: AppSpacing.md,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(CardDesign.radius),
                      border: Border.all(color: CardDesign.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image + Close button in corner
                        Stack(
                          children: [
                            Container(
                              height: CompareDesign.imageHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: CompareDesign.imageBackground,
                                borderRadius: BorderRadius.circular(
                                  CompareDesign.imageRadius,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: product.coverImage != null
                                  ? AppNetworkImage(
                                      product.coverImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      AppIcons.garment,
                                      color: AppColors.iconMuted,
                                    ),
                            ),
                            PositionedDirectional(
                              top: 6,
                              end: 6,
                              child: Material(
                                color: AppColors.white,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: AppHaptics.action(() {
                                    ref
                                        .read(
                                          productComparisonProvider.notifier,
                                        )
                                        .removeProduct(product.id);
                                  }),
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      AppIcons.close,
                                      size: 16,
                                      color: AppColors.icon,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Name
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),

                        const SizedBox(height: 2),

                        // Shop
                        Text(
                          product.shopName,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                            fontWeight: AppFont.semiBold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Price
                        Text(
                          AppFormat.price(product.price),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: AppFont.extraBold,
                            color: AppColors.text,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.sm),

                        // Rating
                        Row(
                          children: [
                            Icon(
                              AppIcons.starFilled,
                              color: AppColors.rating,
                              size: 17,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount} تقييم)'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: AppFont.semiBold,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Colors
                        Text(
                          'الألوان المتاحة'.tr,
                          style: TextStyle(
                            fontSize: 11,
                            color: CompareDesign.rowLabelColor,
                          ),
                        ),
                        Text(
                          product.availableColors.isEmpty
                              ? 'قياسي'.tr
                              : product.availableColors.join(' ، '.tr),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.semiBold,
                            color: AppColors.text,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Sizes
                        Text(
                          'المقاسات المتاحة'.tr,
                          style: TextStyle(
                            fontSize: 11,
                            color: CompareDesign.rowLabelColor,
                          ),
                        ),
                        Text(
                          product.availableSizes.isEmpty
                              ? 'قياسي'.tr
                              : product.availableSizes.join(' ، '.tr),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.semiBold,
                            color: AppColors.text,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Stock
                        Text(
                          'المخزون'.tr,
                          style: TextStyle(
                            fontSize: 11,
                            color: CompareDesign.rowLabelColor,
                          ),
                        ),
                        Text(
                          '${product.totalStock} قطعة'.tr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.semiBold,
                            color: AppColors.text,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Action button
                        AppButton(
                          label: 'عرض التفاصيل'.tr,
                          onPressed: () => context.push(
                            AppRoutes.customerProductDetailsPath(product.id),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
