import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(customerBannersProvider);
    final categoriesAsync = ref.watch(customerCategoriesProvider);
    final shopsAsync = ref.watch(customerShopsProvider);
    final productsAsync = ref.watch(customerProductsProvider);

    return CustomerScaffold(
      title: 'السوق العصري',
      currentNavIndex: 0,
      showBack: false,
      showProfile: true,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customerBannersProvider);
          ref.invalidate(customerCategoriesProvider);
          ref.invalidate(customerShopsProvider);
          ref.invalidate(customerProductsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Promotional Banners
              bannersAsync.when(
                data: (banners) {
                  if (banners.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SizedBox(
                      height: 110,
                      child: PageView.builder(
                        itemCount: banners.length,
                        itemBuilder: (context, index) {
                          final b = banners[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  b.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (b.subtitle != null &&
                                    b.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    b.subtitle!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.gray700),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              // Categories Section
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) return const SizedBox.shrink();
                  return SizedBox(
                    height: 48,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        return ActionChip(
                          backgroundColor: AppColors.gray100,
                          side: const BorderSide(color: AppColors.border),
                          label: Text(cat.name),
                          onPressed: () {
                            ref.read(productFilterProvider.notifier).state =
                                ProductFilter(categoryId: cat.id);
                            context.push(AppRoutes.customerCatalog);
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Approved Shops Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المحلات المعتمدة',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.customerShops),
                      child: const Text('جميع المحلات'),
                    ),
                  ],
                ),
              ),

              shopsAsync.when(
                data: (shops) {
                  if (shops.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text('لا توجد محلات معتمدة حالياً'),
                    );
                  }
                  return SizedBox(
                    height: 120,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: shops.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          onTap: () => context.push(
                            AppRoutes.customerShopProfilePath(shop.id),
                          ),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadii.card,
                              ),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.gray100,
                                  child:
                                      shop.logoPath != null &&
                                          shop.logoPath!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            shop.logoPath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.store,
                                                  color: AppColors.black,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.store,
                                          color: AppColors.black,
                                        ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  shop.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  shop.city ?? 'متجر أزياء',
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.gray500),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Latest Products Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أحدث الملابس والمنتجات',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.customerCatalog),
                      child: const Text('تصفح الكل'),
                    ),
                  ],
                ),
              ),

              productsAsync.when(
                data: (products) {
                  if (products.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('لا توجد منتجات منشورة حالياً'),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.58,
                          ),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductGridCard(
                          imageUrl: product.coverImage,
                          title: product.name,
                          subtitle: product.shopName,
                          meta:
                              '${product.price.toStringAsFixed(2)} ر.س · مخزون ${product.totalStock}',
                          onTap: () => context.push(
                            AppRoutes.customerProductDetailsPath(product.id),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('تعذر تحميل المنتجات: $err'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
