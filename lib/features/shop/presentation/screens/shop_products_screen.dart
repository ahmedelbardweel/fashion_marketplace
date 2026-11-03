import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
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
              'الحالة: ${product.statusLabel}\nالمخزون: ${product.totalStock}',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'تعديل',
              onPressed: () => Navigator.of(context).pop('edit'),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (product.status != 'published')
              AppButton(
                label: 'نشر',
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop('published'),
              ),
            if (product.status == 'published')
              AppButton(
                label: 'إيقاف النشر',
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop('hidden'),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'حذف',
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
        error == null ? 'تعذر التحديث' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث المنتج');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(myShopProvider).asData?.value;
    final products = ref.watch(shopProductsProvider);
    final busy = ref.watch(shopCatalogActionProvider).isLoading;
    final approved = shop?.visibleStatus == ShopStatus.approved;

    return ShopScaffold(
      title: 'المنتجات',
      showBack: false,
      body: !approved
          ? ListView(
              padding: AppSpacing.page,
              children: const [
                AppCard(
                  child: Text(
                    'لا يمكن إدارة المنتجات قبل موافقة الإدارة على المحل.',
                  ),
                ),
              ],
            )
          : products.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  ref.read(shopCatalogRepositoryProvider).mapError(error),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    padding: AppSpacing.page,
                    children: const [
                      AppCard(child: Text('لا توجد منتجات بعد')),
                    ],
                  );
                }
                return GridView.builder(
                  padding: AppSpacing.page,
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.58,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ProductGridCard(
                      imageUrl: item.coverImage,
                      title: item.name,
                      subtitle:
                          '${item.statusLabel} · ${item.categoryName ?? 'بدون تصنيف'}',
                      meta:
                          '${item.price.toStringAsFixed(2)} · مخزون ${item.totalStock}',
                      onTap: busy ? null : () => _manage(context, ref, item),
                    );
                  },
                );
              },
            ),
      bottom: approved
          ? AppButton(
              label: 'إضافة منتج',
              isLoading: busy,
              onPressed: () => context.push(AppRoutes.shopProductForm),
            )
          : null,
    );
  }
}
