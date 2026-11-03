import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class ProductComparisonScreen extends ConsumerWidget {
  const ProductComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productComparisonProvider);

    return CustomerScaffold(
      title: 'مقارنة المنتجات',
      actions: [
        if (products.isNotEmpty)
          TextButton(
            onPressed: () {
              ref.read(productComparisonProvider.notifier).clear();
            },
            child: const Text('مسح الكل'),
          ),
      ],
      body: products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.compare_arrows_rounded,
                    size: 64,
                    color: AppColors.gray300,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'قائمة المقارنة فارغة',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'أضف منتجين أو أكثر من صفحة المنتج للمقارنة جنباً إلى جنب',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.gray500),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'تصفح المنتجات',
                    onPressed: () => context.go(AppRoutes.customerCatalog),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: products.map((product) {
                  return Container(
                    width: 260,
                    margin: const EdgeInsets.only(left: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Remove button
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              ref
                                  .read(productComparisonProvider.notifier)
                                  .removeProduct(product.id);
                            },
                          ),
                        ),

                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          child: Container(
                            height: 180,
                            color: AppColors.gray100,
                            child: product.coverImage != null
                                ? Image.network(
                                    product.coverImage!,
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(Icons.checkroom),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Name
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: AppSpacing.xs),

                        // Shop
                        Text(
                          'المتجر: ${product.shopName}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.gray500),
                        ),

                        const SizedBox(height: AppSpacing.xs),

                        // Price
                        Text(
                          '${product.price.toStringAsFixed(2)} ر.س',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                        ),

                        const SizedBox(height: AppSpacing.sm),
                        const Divider(),

                        // Rating
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount} تقييم)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Colors
                        Text('الألوان:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          product.availableColors.isEmpty
                              ? 'قياسي'
                              : product.availableColors.join(' ، '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Sizes
                        Text('المقاسات:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          product.availableSizes.isEmpty
                              ? 'قياسي'
                              : product.availableSizes.join(' ، '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Stock
                        Text('المخزون:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '${product.totalStock} قطعة',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Action button
                        AppButton(
                          label: 'عرض التفاصيل والطلب',
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
