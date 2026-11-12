import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerShopsScreen extends ConsumerWidget {
  const CustomerShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(customerShopsProvider);

    return CustomerScaffold(
      title: 'المتاجر المعتمدة',
      showSearch: false,
      body: RefreshIndicator.noSpinner(
        onRefresh: AppHaptics.refresh(() async {
          ref.invalidate(customerShopsProvider);
        }),
        child: shopsAsync.skeletonWhen(
          placeholder: LoadingFixtures.customerShops,
          data: (shops) {
            if (shops.isEmpty) {
              return const AppEmpty(
                icon: AppIcons.shop,
                message: 'لا توجد متاجر معتمدة حالياً',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: shops.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final shop = shops[index];
                return AppCard(
                  onTap: () =>
                      context.push(AppRoutes.customerShopProfilePath(shop.id)),
                  child: Row(
                    children: [
                      Container(
                        width: ShopProfileDesign.listLogoSize,
                        height: ShopProfileDesign.listLogoSize,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryBorder,
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child:
                            shop.logoPath != null && shop.logoPath!.isNotEmpty
                            ? AppNetworkImage(
                                shop.logoPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  AppIcons.shopActive,
                                  color: AppColors.icon,
                                ),
                              )
                            : const Icon(
                                AppIcons.shopActive,
                                color: AppColors.icon,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: AppFont.bold,
                                color: AppColors.text,
                              ),
                            ),
                            if (shop.description != null &&
                                shop.description!.isNotEmpty)
                              Text(
                                shop.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              '${shop.city ?? 'متجر أزياء'} · ${shop.productsCount} منتج',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: AppFont.semiBold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        AppIcons.forward,
                        color: AppColors.icon,
                      ),
                    ],
                  ),
                );
              },
            );
          },
          error: (err, _) => AppEmpty(
            icon: AppIcons.error,
            message: 'تعذر تحميل المتاجر: $err',
          ),
        ),
      ),
    );
  }
}
