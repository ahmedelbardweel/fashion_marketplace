import '../../../../core/theme/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopOrdersScreen extends ConsumerWidget {
  const ShopOrdersScreen({super.key});

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    ShopOrder order,
  ) async {
    final statuses = [
      ('confirmed', 'تأكيد'.tr),
      ('processing', 'تجهيز'.tr),
      ('shipped', 'شحن'.tr),
      ('delivered', 'تسليم'.tr),
      ('cancelled', 'إلغاء'.tr),
    ];

    final status = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'تحديث حالة الطلب'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الطلب الحالي: ${order.statusLabel.tr}'.tr),
            const SizedBox(height: AppSpacing.md),
            ...statuses.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppButton(
                  label: item.$2,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => Navigator.of(context).pop(item.$1),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (status == null) return;
    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.updateOrderStatus(
      orderId: order.id,
      status: status,
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
    showAppSnackBar(context, 'تم تحديث حالة الطلب'.tr);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopState = ref.watch(myShopProvider);
    final shop = shopState.asData?.value;
    final awaitingShop = shopState.isLoading && !shopState.hasValue;
    final orders = awaitingShop
        ? const AsyncLoading<List<ShopOrder>>()
        : ref.watch(shopOrdersProvider);
    final busy = ref.watch(shopCatalogActionProvider).isLoading;
    final approved = shop?.visibleStatus == ShopStatus.approved;

    return ShopScaffold(
      title: 'طلبات المحل'.tr,
      showBack: false,
      body: !approved && !awaitingShop
          ? ListView(
              padding: AppSpacing.page,
              children: [
                AppCard(
                  child: Text('الطلبات تظهر بعد موافقة الإدارة على المحل.'.tr),
                ),
              ],
            )
          : orders.skeletonWhen(
              placeholder: LoadingFixtures.shopOrders,
              skipLoadingOnReload: true,
              error: (error, _) => Center(
                child: Text(
                  ref.read(shopCatalogRepositoryProvider).mapError(error).tr,
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    padding: AppSpacing.page,
                    children: [AppCard(child: Text('لا توجد طلبات بعد'.tr))],
                  );
                }
                return ListView(
                  padding: AppSpacing.page,
                  children: items
                      .map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            onTap: busy
                                ? null
                                : () => _update(context, ref, order),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.customerName ??
                                      order.customerEmail ??
                                      'عميل'.tr,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${order.statusLabel.tr} · ${AppFormat.price(order.total)}',
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  order.createdAt.toString().split('.').first,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
    );
  }
}
