import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';

Future<void> showProductCartSheet(BuildContext context, String productId) =>
    AppBottomSheet.show<void>(
      context: context,
      child: _ProductCartSheet(productId: productId),
    );

class _ProductCartSheet extends ConsumerStatefulWidget {
  const _ProductCartSheet({required this.productId});
  final String productId;
  @override
  ConsumerState<_ProductCartSheet> createState() => _ProductCartSheetState();
}

class _ProductCartSheetState extends ConsumerState<_ProductCartSheet> {
  String? _selectedColor;
  String? _selectedSize;

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(customerProductDetailsProvider(widget.productId));
    return AppBottomSheetScaffold(
      title: 'اختر اللون والمقاس',
      child: details.when(
        loading: () => const AppSkeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('اسم المنتج'),
              SizedBox(height: 16),
              Text('اختر اللون والمقاس'),
              SizedBox(height: 20),
              SizedBox(height: 48, child: Card()),
            ],
          ),
        ),
        error: (_, _) => Column(
          children: [
            const Text('تعذر تحميل خيارات المنتج'),
            TextButton(
              onPressed: AppHaptics.action(
                () => ref.invalidate(
                  customerProductDetailsProvider(widget.productId),
                ),
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
        data: (product) {
          if (product == null || product.status != 'published') {
            return const Text('هذا المنتج غير متاح حالياً');
          }

          final available = product.variants
              .where((v) => v.isActive && v.stock > 0)
              .toList();
          final colors = available.map((v) => v.color).toSet().toList();
          if (_selectedColor == null && colors.isNotEmpty) {
            _selectedColor = colors.first;
          }

          final sizesForColor = available
              .where((v) => v.color == _selectedColor)
              .map((v) => v.size)
              .toSet()
              .toList();
          if (_selectedSize == null || !sizesForColor.contains(_selectedSize)) {
            _selectedSize = sizesForColor.isNotEmpty
                ? sizesForColor.first
                : null;
          }

          ProductVariant? choice;
          for (final variant in available) {
            if (variant.color == _selectedColor &&
                variant.size == _selectedSize) {
              choice = variant;
              break;
            }
          }

          final cart = ref.watch(cartProvider);
          final quantity = choice == null
              ? 0
              : cart
                    .where(
                      (item) =>
                          item.productId == product.id &&
                          item.color == choice!.color &&
                          item.size == choice.size,
                    )
                    .fold<int>(0, (total, item) => total + item.quantity);
          final atLimit = choice != null && quantity >= choice.stock;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Mini Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 84,
                    decoration: BoxDecoration(
                      color: ProductCardDesign.imageBackground,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(
                        color: ProductCardDesign.imageBorderColor,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.coverImage != null
                        ? AppNetworkImage(
                            product.coverImage!,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            AppIcons.garment,
                            color: AppColors.iconMuted,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.shopName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.semiBold,
                            color: ProductDetailsDesign.shopNameColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormat.price(product.price),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: AppFont.extraBold,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),

              if (available.isEmpty)
                const Text(
                  'نفدت الكمية حالياً',
                  style: TextStyle(
                    fontWeight: AppFont.bold,
                    color: AppColors.error,
                  ),
                )
              else ...[
                // Color Selection
                Row(
                  children: [
                    const Text(
                      'اللون',
                      style: TextStyle(
                        fontSize: ProductDetailsDesign.sectionTitleSize,
                        fontWeight: ProductDetailsDesign.sectionTitleWeight,
                        color: AppColors.text,
                      ),
                    ),
                    if (_selectedColor != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '· $_selectedColor',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: AppFont.semiBold,
                          color: ProductDetailsDesign.sectionValueColor,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final color in colors)
                      _OptionPill(
                        label: color,
                        selected: color == _selectedColor,
                        onTap: () => setState(() {
                          _selectedColor = color;
                          _selectedSize = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Size Selection
                Row(
                  children: [
                    const Text(
                      'المقاس',
                      style: TextStyle(
                        fontSize: ProductDetailsDesign.sectionTitleSize,
                        fontWeight: ProductDetailsDesign.sectionTitleWeight,
                        color: AppColors.text,
                      ),
                    ),
                    if (_selectedSize != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '· $_selectedSize',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: AppFont.semiBold,
                          color: ProductDetailsDesign.sectionValueColor,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final size in sizesForColor)
                      _OptionPill(
                        label: size,
                        selected: size == _selectedSize,
                        onTap: () => setState(() => _selectedSize = size),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                icon: const Icon(AppIcons.bag, size: 20),
                onPressed: AppHaptics.action(
                  choice == null || atLimit
                      ? null
                      : () {
                          ref
                              .read(cartProvider.notifier)
                              .addItem(
                                product: product,
                                variantId: choice!.id,
                                color: choice.color,
                                size: choice.size,
                                maxStock: choice.stock,
                              );
                          Navigator.of(context).pop();
                          showAppSnackBar(
                            context,
                            'تمت إضافة القطعة إلى السلة',
                          );
                        },
                ),
                label: Text(
                  atLimit
                      ? 'وصلت للكمية المتاحة'
                      : 'إضافة إلى السلة · ${AppFormat.price(product.price)}',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: AppHaptics.action(onTap),
      borderRadius: BorderRadius.circular(ProductDetailsDesign.optionRadius),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: ProductDetailsDesign.optionMinWidth,
          minHeight: ProductDetailsDesign.optionHeight,
        ),
        padding: ProductDetailsDesign.optionPadding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
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
            color: selected
                ? ProductDetailsDesign.optionSelectedText
                : ProductDetailsDesign.optionText,
            fontWeight: selected
                ? ProductDetailsDesign.optionSelectedWeight
                : ProductDetailsDesign.optionWeight,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
