import '../widgets/product_cart_sheet.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/app_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerFavoritesScreen extends ConsumerWidget {
  const CustomerFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(customerFavoritesProvider);

    return CustomerScaffold(
      title: 'المفضلة (Wishlist)',
      currentNavIndex: 2,
      showBack: false,
      body: RefreshIndicator.noSpinner(
        onRefresh: () async {
          ref.invalidate(customerFavoritesProvider);
        },
        child: favoritesAsync.skeletonWhen(
          placeholder: LoadingFixtures.products,
          data: (favorites) {
            if (favorites.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: AppColors.gray300,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'قائمة المفضلة فارغة',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'احفظ الملابس التي تنال إعجابك للرجوع إليها لاحقاً',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.gray500),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'تصفح الأزياء الآن',
                      onPressed: () => context.go(AppRoutes.customerCatalog),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: favorites.length,
              gridDelegate: ProductGridDelegate(
                textScale: MediaQuery.textScalerOf(context).scale(14) / 14,
              ),
              itemBuilder: (context, index) {
                final product = favorites[index];
                return ProductGridCard(
                  onAddToCart: () => showProductCartSheet(context, product.id),
                  inStock: product.totalStock > 0,
                  imageUrl: product.coverImage,
                  title: product.name,
                  subtitle: product.shopName,
                  meta: '${product.price.toStringAsFixed(2)} ر.س',
                  onTap: () => context.push(
                    AppRoutes.customerProductDetailsPath(product.id),
                  ),
                );
              },
            );
          },
          error: (err, _) => Center(child: Text('تعذر تحميل المفضلة: $err')),
        ),
      ),
    );
  }
}
