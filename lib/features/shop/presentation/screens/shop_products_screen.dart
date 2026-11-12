import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/product_grid_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopProductsScreen extends ConsumerWidget {
  const ShopProductsScreen({super.key});

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    ShopProduct product,
  ) async {
    final action = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: product.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الحالة: ${product.statusLabel}\nالمخزون: ${product.totalStock}'.tr,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'تعديل'.tr,
              onPressed: () => Navigator.of(context).pop('edit'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (product.status != 'published')
              AppButton(
                label: 'نشر'.tr,
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop('published'),
              ),
            if (product.status == 'published')
              AppButton(
                label: 'إيقاف النشر'.tr,
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop('hidden'),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'حذف'.tr,
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop('deleted'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'edit') {
      if (context.mounted) {
        context.push(AppRoutes.shopProductEditPath(product.id));
      }
      return;
    }

    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.setProductStatus(
      productId: product.id,
      status: action,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر التحديث'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث المنتج'.tr);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(myShopProvider);
    final shop = shopState.asData?.value;
    final awaitingShop = shopState.isLoading && !shopState.hasValue;
    final products = awaitingShop
        ? const AsyncLoading<List<ShopProduct>>()
        : ref.watch(shopProductsProvider);
    final busy = ref.watch(shopCatalogActionProvider).isLoading;
    final approved = shop?.visibleStatus == ShopStatus.approved;

    return ShopScaffold(
      title: 'المنتجات'.tr,
      showBack: false,
      body: !approved && !awaitingShop
          ? ListView(
              padding: AppSpacing.page,
              children: [
                AppCard(
                  child: Text(
                    'لا يمكن إدارة المنتجات قبل موافقة الإدارة على المحل.'.tr,
                  ),
                ),
              ],
            )
          : products.skeletonWhen(
              placeholder: LoadingFixtures.shopProducts,
              skipLoadingOnReload: true,
              error: (error, _) => Center(
                child: Text(
                  ref.read(shopCatalogRepositoryProvider).mapError(error),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    padding: AppSpacing.page,
                    children: [
                      AppCard(child: Text('لا توجد منتجات بعد'.tr)),
                    ],
                  );
                }
                return GridView.builder(
                  padding: AppSpacing.page,
                  itemCount: items.length,
                  gridDelegate: ProductGridDelegate(
                    textScale: MediaQuery.textScalerOf(context).scale(14) / 14,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ProductGridCard(
                      imageUrl: item.coverImage,
                      meta: AppFormat.price(item.price),
                      inStock: item.totalStock > 0,
                      showFavorite: false,
                      onTap: busy ? null : () => _manage(context, ref, item),
                    );
                  },
                );
              },
            ),
      bottom: approved
          ? AppButton(
              label: 'إضافة منتج'.tr,
              isLoading: busy,
              onPressed: () => context.push(AppRoutes.shopProductForm),
            )
          : null,
    );
  }
}
