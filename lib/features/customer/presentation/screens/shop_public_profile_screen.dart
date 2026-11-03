import '../../domain/models/customer_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class ShopPublicProfileScreen extends ConsumerWidget {
  const ShopPublicProfileScreen({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(customerShopDetailsProvider(shopId));
    final shopProductsAsync = FutureProvider.autoDispose<List<CustomerProduct>>((ref) async {
      return ref.watch(customerRepositoryProvider).getProducts(shopId: shopId);
    });
    final products = ref.watch(shopProductsAsync);

    return shopAsync.when(
      data: (shop) {
        if (shop == null) {
          return const CustomerScaffold(
            title: 'المحل',
            body: Center(child: Text('المحل غير موجود')),
          );
        }

        return CustomerScaffold(
          title: shop.name,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image
                Container(
                  height: 140,
                  color: AppColors.gray100,
                  child: shop.coverPath != null && shop.coverPath!.isNotEmpty
                      ? Image.network(
                          shop.coverPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.storefront, size: 48),
                          ),
                        )
                      : const Center(child: Icon(Icons.storefront, size: 48)),
                ),

                // Shop Info Card
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.white,
                            child: shop.logoPath != null &&
                                    shop.logoPath!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      shop.logoPath!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.store,
                                    size: 32, color: AppColors.black),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shop.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${shop.city ?? ''} · ${shop.address ?? ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.gray500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (shop.description != null &&
                          shop.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          shop.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'منتجات هذا المتجر',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Products Grid
                      products.when(
                        data: (items) {
                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg),
                              child: Center(
                                child: Text('لا توجد منتجات منشورة لهذا المتجر حالياً'),
                              ),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 0.58,
                            ),
                            itemBuilder: (context, index) {
                              final p = items[index];
                              return ProductGridCard(
                                imageUrl: p.coverImage,
                                title: p.name,
                                subtitle: p.categoryName ?? 'أزياء',
                                meta:
                                    '${p.price.toStringAsFixed(2)} ر.س · مخزون ${p.totalStock}',
                                onTap: () => context.push(
                                  AppRoutes.customerProductDetailsPath(p.id),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (err, _) => Text('تعذر تحميل المنتجات: $err'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const CustomerScaffold(
        title: 'جاري التحميل...',
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => CustomerScaffold(
        title: 'خطأ',
        body: Center(child: Text('تعذر تحميل المحل: $e')),
      ),
    );
  }
}
