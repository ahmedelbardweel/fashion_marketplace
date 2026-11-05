import '../../../../core/widgets/app_skeleton.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
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
      actions: [
        if (cartItems.isNotEmpty)
          TextButton(
            onPressed: () => cartNotifier.clearCart(),
            child: const Text('تفريغ السلة'),
          ),
      ],
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: AppColors.gray300,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'سلة المشتريات فارغة',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'تصفح أحدث الأزياء وأضف المنتجات لسلتك',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.gray500),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'تصفح المتجر الآن',
                    onPressed: () => context.go(AppRoutes.customerCatalog),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                              child: Container(
                                width: 75,
                                height: 75,
                                color: AppColors.gray100,
                                child: item.imagePath != null
                                    ? AppNetworkImage(
                                        item.imagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.checkroom),
                                      )
                                    : const Icon(Icons.checkroom),
                              ),
                            ),

                            const SizedBox(width: AppSpacing.md),

                            // Product Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.shopName} · ${item.variantDescription}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.gray500),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${item.unitPrice.toStringAsFixed(2)} ر.س',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.black,
                                        ),
                                  ),
                                ],
                              ),
                            ),

                            // Quantity Stepper & Remove
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.gray500,
                                  ),
                                  onPressed: () =>
                                      cartNotifier.removeItem(item.id),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          cartNotifier.updateQuantity(
                                            item.id,
                                            item.quantity - 1,
                                          ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          cartNotifier.updateQuantity(
                                            item.id,
                                            item.quantity + 1,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Cart Summary & Checkout Button
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المجموع الفرعي',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${cartNotifier.totalAmount.toStringAsFixed(2)} ر.س',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'التوصيل',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            'مجاناً',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الإجمالي النهائي',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${cartNotifier.totalAmount.toStringAsFixed(2)} ر.س',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'متابعة الشراء (${cartItems.length} عناصر)',
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
