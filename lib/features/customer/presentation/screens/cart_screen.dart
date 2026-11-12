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

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return CustomerScaffold(
      title: 'سلة المشتريات',
      showSearch: false,
      actions: [
        if (cartItems.isNotEmpty)
          TextButton.icon(
            onPressed: AppHaptics.action(() => cartNotifier.clearCart()),
            icon: const Icon(AppIcons.delete, size: 18),
            label: const Text('تفريغ'),
          ),
      ],
      body: cartItems.isEmpty
          ? AppEmpty(
              icon: AppIcons.bag,
              title: 'سلة المشتريات فارغة',
              message: 'تصفح أحدث الأزياء وأضف القطع المفضلة إلى سلتك',
              actionLabel: 'تصفح المتجر الآن',
              onAction: AppHaptics.action(
                () => context.go(AppRoutes.customerCatalog),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: AppSpacing.lg,
                      color: CartDesign.itemDivider,
                    ),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Portrait Product Image Thumbnail
                          GestureDetector(
                            onTap: AppHaptics.action(
                              () => context.push(
                                AppRoutes.customerProductDetailsPath(
                                  item.productId,
                                ),
                              ),
                            ),
                            child: Container(
                              width: CartDesign.itemImageWidth,
                              height: CartDesign.itemImageHeight,
                              decoration: BoxDecoration(
                                color: CartDesign.itemImageBackground,
                                borderRadius: BorderRadius.circular(
                                  CartDesign.itemImageRadius,
                                ),
                                border: Border.all(
                                  color: CartDesign.itemImageBorder,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item.imagePath != null
                                  ? AppNetworkImage(
                                      item.imagePath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        AppIcons.garment,
                                        color: AppColors.iconMuted,
                                      ),
                                    )
                                  : const Icon(
                                      AppIcons.garment,
                                      color: AppColors.iconMuted,
                                    ),
                            ),
                          ),

                          const SizedBox(width: AppSpacing.md),

                          // Product Info + Quantity Stepper
                          Expanded(
                            child: SizedBox(
                              height: CartDesign.itemImageHeight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.productName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: CartDesign.itemTitleSize,
                                            fontWeight:
                                                CartDesign.itemTitleWeight,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        icon: const Icon(
                                          AppIcons.close,
                                          size: 18,
                                          color: CartDesign.removeIcon,
                                        ),
                                        onPressed: AppHaptics.action(
                                          () =>
                                              cartNotifier.removeItem(item.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.shopName} · ${item.variantDescription}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CartDesign.itemMetaColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppFormat.price(item.totalPrice),
                                        style: const TextStyle(
                                          fontSize: CartDesign.itemPriceSize,
                                          fontWeight:
                                              CartDesign.itemPriceWeight,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Container(
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: CartDesign.stepperBackground,
                                          borderRadius: BorderRadius.circular(
                                            CartDesign.stepperRadius,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(
                                                AppIcons.remove,
                                                size: 16,
                                                color: AppColors.icon,
                                              ),
                                              onPressed: AppHaptics.action(
                                                () => cartNotifier
                                                    .updateQuantity(
                                                      item.id,
                                                      item.quantity - 1,
                                                    ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                  ),
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: AppFont.bold,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(
                                                AppIcons.add,
                                                size: 16,
                                                color: AppColors.icon,
                                              ),
                                              onPressed: AppHaptics.action(
                                                () => cartNotifier
                                                    .updateQuantity(
                                                      item.id,
                                                      item.quantity + 1,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Cart Summary & Checkout Button
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: CartDesign.summaryBackground,
                    boxShadow: CartDesign.summaryShadow,
                    border: Border(
                      top: BorderSide(color: CartDesign.summaryBorder),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'المجموع الفرعي',
                            style: TextStyle(color: CartDesign.summaryLabel),
                          ),
                          Text(
                            AppFormat.price(cartNotifier.totalAmount),
                            style: const TextStyle(
                              fontWeight: AppFont.semiBold,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'التوصيل',
                            style: TextStyle(color: CartDesign.summaryLabel),
                          ),
                          Text(
                            'مجاناً',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: AppFont.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي النهائي',
                            style: TextStyle(
                              fontSize: CartDesign.totalSize,
                              fontWeight: CartDesign.totalWeight,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            AppFormat.price(cartNotifier.totalAmount),
                            style: const TextStyle(
                              fontSize: CartDesign.totalSize,
                              fontWeight: CartDesign.totalWeight,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'إتمام الشراء (${cartItems.length})',
                        onPressed: () =>
                            context.push(AppRoutes.customerCheckout),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
