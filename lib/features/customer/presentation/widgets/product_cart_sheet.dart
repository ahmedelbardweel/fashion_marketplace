import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/fashion_color_palette.dart';
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
      title: 'اختر اللون والمقاس'.tr,
      child: details.when(
        loading: () => AppSkeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('اسم المنتج'.tr),
              SizedBox(height: 16),
              Text('اختر اللون والمقاس'.tr),
              SizedBox(height: 20),
              SizedBox(height: 48, child: Card()),
            ],
          ),
        ),
        error: (_, _) => Column(
          children: [
            Text('تعذر تحميل خيارات المنتج'.tr),
            TextButton(
              onPressed: AppHaptics.action(
                () => ref.invalidate(
                  customerProductDetailsProvider(widget.productId),
                ),
              ),
              child: Text('إعادة المحاولة'.tr),
            ),
          ],
        ),
        data: (product) {
          if (product == null || product.status != 'published') {
            return Text('هذا المنتج غير متاح حالياً'.tr);
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
                        : Icon(
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
                          style: TextStyle(
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              AppFormat.price(product.price),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: AppFont.extraBold,
                                color: AppColors.text,
                              ),
                            ),
                            if (product.hasOffer &&
                                product.originalPrice != null) ...[
                              Text(
                                AppFormat.price(product.originalPrice!),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: AppFont.medium,
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: AppColors.textMuted,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
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
                                    fontSize: 10.5,
                                    fontWeight: AppFont.bold,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                Text(
                  'نفدت الكمية حالياً'.tr,
                  style: TextStyle(
                    fontWeight: AppFont.bold,
                    color: AppColors.error,
                  ),
                )
              else ...[
                // Color & Size Selection (circles only, 50/50 split with full-height centered divider)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            0,
                            10,
                            14,
                            10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                children: [
                                  for (final color in colors)
                                    ColorSwatchCircle(
                                      colorName: color,
                                      selected: color == _selectedColor,
                                      size: 30,
                                      onTap: () => setState(() {
                                        _selectedColor = color;
                                        _selectedSize = null;
                                      }),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            14,
                            10,
                            0,
                            10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                children: [
                                  for (final size in sizesForColor)
                                    SizeSwatchCircle(
                                      label: size,
                                      selected: size == _selectedSize,
                                      enabled: true,
                                      size: 36,
                                      onTap: () =>
                                          setState(() => _selectedSize = size),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                            'تمت إضافة القطعة إلى السلة'.tr,
                          );
                        },
                ),
                label: Text(
                  atLimit
                      ? 'وصلت للكمية المتاحة'.tr
                      : 'إضافة إلى السلة · ${AppFormat.price(product.price)}'.tr,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
