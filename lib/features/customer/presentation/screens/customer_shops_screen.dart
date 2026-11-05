import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerShopsScreen extends ConsumerWidget {
  const CustomerShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(customerShopsProvider);

    return CustomerScaffold(
      title: 'المحلات المعتمدة',
      body: RefreshIndicator.noSpinner(
        onRefresh: () async {
          ref.invalidate(customerShopsProvider);
        },
        child: shopsAsync.skeletonWhen(
          placeholder: LoadingFixtures.customerShops,
          data: (shops) {
            if (shops.isEmpty) {
              return const Center(child: Text('لا توجد محلات معتمدة حالياً'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: shops.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final shop = shops[index];
                return AppCard(
                  onTap: () =>
                      context.push(AppRoutes.customerShopProfilePath(shop.id)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.gray100,
                        child:
                            shop.logoPath != null && shop.logoPath!.isNotEmpty
                            ? ClipOval(
                                child: AppNetworkImage(
                                  shop.logoPath!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.storefront_rounded),
                                ),
                              )
                            : const Icon(
                                Icons.storefront_rounded,
                                color: AppColors.black,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (shop.description != null &&
                                shop.description!.isNotEmpty)
                              Text(
                                shop.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.gray500),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              '${shop.city ?? 'متجر أزياء'} · ${shop.productsCount} منتج',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.gray700),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left, color: AppColors.gray500),
                    ],
                  ),
                );
              },
            );
          },
          error: (err, _) => Center(child: Text('تعذر تحميل المحلات: $err')),
        ),
      ),
    );
  }
}
