import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/product_cart_sheet.dart';

class CustomerFavoritesScreen extends ConsumerWidget {
  const CustomerFavoritesScreen({super.key});

  Future<void> _toggleFavorite(WidgetRef ref, String productId) async {
    await ref.read(customerRepositoryProvider).toggleFavorite(productId);
    ref.invalidate(customerFavoritesProvider);
    ref.invalidate(customerProductsProvider);
    ref.invalidate(customerProductDetailsProvider(productId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(customerFavoritesProvider);

    return CustomerScaffold(
      title: 'المفضلة',
      currentNavIndex: 2,
      showBack: false,
      body: RefreshIndicator.noSpinner(
        onRefresh: AppHaptics.refresh(() async {
          ref.invalidate(customerFavoritesProvider);
        }),
        child: favoritesAsync.skeletonWhen(
          placeholder: LoadingFixtures.products,
          data: (favorites) {
            if (favorites.isEmpty) {
              return AppEmpty(
                icon: FavoritesDesign.emptyIcon,
                title: 'قائمة المفضلة فارغة',
                message: 'احفظ الأزياء التي تنال إعجابك للرجوع إليها في أي وقت',
                actionLabel: 'تصفح الأزياء الآن',
                onAction: AppHaptics.action(
                  () => context.go(AppRoutes.customerCatalog),
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
                  imageUrl: product.coverImage,
                  meta: AppFormat.price(product.price),
                  inStock: product.totalStock > 0,
                  isFavorite: true,
                  onToggleFavorite: () => _toggleFavorite(ref, product.id),
                  onAddToCart: () => showProductCartSheet(context, product.id),
                  onTap: () => context.push(
                    AppRoutes.customerProductDetailsPath(product.id),
                  ),
                );
              },
            );
          },
          error: (err, _) => AppEmpty(
            icon: AppIcons.error,
            message: 'تعذر تحميل المفضلة: $err',
          ),
        ),
      ),
    );
  }
}
