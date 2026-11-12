import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';
import '../widgets/product_cart_sheet.dart';

final _shopProductsProvider =
    FutureProvider.autoDispose.family<List<CustomerProduct>, String>(
      (ref, shopId) async {
        return ref
            .watch(customerRepositoryProvider)
            .getProducts(shopId: shopId);
      },
    );

class ShopPublicProfileScreen extends ConsumerWidget {
  const ShopPublicProfileScreen({super.key, required this.shopId});

  final String shopId;

  Future<void> _toggleFavorite(WidgetRef ref, String productId) async {
    await ref.read(customerRepositoryProvider).toggleFavorite(productId);
    ref.invalidate(_shopProductsProvider(shopId));
    ref.invalidate(customerFavoritesProvider);
    ref.invalidate(customerProductsProvider);
    ref.invalidate(customerProductDetailsProvider(productId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(customerShopDetailsProvider(shopId));
    final products = ref.watch(_shopProductsProvider(shopId));

    return shopAsync.skeletonWhen(
      placeholder: LoadingFixtures.customerShop,
      data: (shop) {
        if (shop == null) {
          return CustomerScaffold(
            title: 'المتجر'.tr,
            body: AppEmpty(
              icon: AppIcons.shop,
              message: 'المتجر غير موجود'.tr,
            ),
          );
        }

        final locationText = [
          shop.city,
          shop.address,
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

        return CustomerScaffold(
          title: shop.name,
          showSearch: false,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover + Overlapping Avatar Header
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: ShopProfileDesign.coverHeight,
                      width: double.infinity,
                      color: ShopProfileDesign.coverBackground,
                      child:
                          shop.coverPath != null && shop.coverPath!.isNotEmpty
                          ? AppNetworkImage(
                              shop.coverPath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  AppIcons.shopActive,
                                  size: 48,
                                  color: AppColors.icon,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                AppIcons.shopActive,
                                size: 48,
                                color: AppColors.icon,
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: -(ShopProfileDesign.logoSize / 2),
                      child: Container(
                        width: ShopProfileDesign.logoSize,
                        height: ShopProfileDesign.logoSize,
                        decoration: BoxDecoration(
                          color: ShopProfileDesign.logoBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ShopProfileDesign.logoBorder,
                            width: ShopProfileDesign.logoBorderWidth,
                          ),
                          boxShadow: AppShadows.soft,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child:
                            shop.logoPath != null && shop.logoPath!.isNotEmpty
                            ? AppNetworkImage(
                                shop.logoPath!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                AppIcons.shopActive,
                                size: 34,
                                color: AppColors.icon,
                              ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: (ShopProfileDesign.logoSize / 2) + 12),

                // Shop Info
                Padding(
                  padding: AppSpacing.pageHorizontal,
                  child: Column(
                    children: [
                      Text(
                        shop.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ShopProfileDesign.nameSize,
                          fontWeight: ShopProfileDesign.nameWeight,
                          color: AppColors.text,
                        ),
                      ),
                      if (locationText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.location,
                              size: 15,
                              color: AppColors.icon,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                locationText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ShopProfileDesign.metaColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (shop.description != null &&
                          shop.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          shop.description!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.lg),

                AppSectionHeader(title: 'تشكيلة المتجر'.tr),
                const SizedBox(height: AppSpacing.md),

                // Products Grid
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  child: products.skeletonWhen(
                    placeholder: LoadingFixtures.products,
                    data: (items) {
                      if (items.isEmpty) {
                        return AppEmpty(
                          icon: AppIcons.garment,
                          message: 'لا توجد منتجات منشورة لهذا المتجر حالياً'.tr,
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: ProductGridDelegate(
                          textScale:
                              MediaQuery.textScalerOf(context).scale(14) / 14,
                        ),
                        itemBuilder: (context, index) {
                          final p = items[index];
                          return ProductGridCard(
                            imageUrl: p.coverImage,
                            meta: AppFormat.price(p.price),
                            inStock: p.totalStock > 0,
                            isFavorite: p.isFavorite,
                            onToggleFavorite: () => _toggleFavorite(ref, p.id),
                            onAddToCart: () =>
                                showProductCartSheet(context, p.id),
                            onTap: () => context.push(
                              AppRoutes.customerProductDetailsPath(p.id),
                            ),
                          );
                        },
                      );
                    },
                    error: (err, _) => AppEmpty(
                      icon: AppIcons.error,
                      message: 'تعذر تحميل المنتجات: $err'.tr,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      error: (e, _) => CustomerScaffold(
        title: 'المتجر'.tr,
        body: AppEmpty(
          icon: AppIcons.error,
          message: 'تعذر تحميل المتجر: $e'.tr,
        ),
      ),
    );
  }
}
