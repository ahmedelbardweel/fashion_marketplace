import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../../../shop/domain/models/shop.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminShopsManageScreen extends ConsumerWidget {
  const AdminShopsManageScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, Shop shop) async {
    if (shop.status != ShopStatus.approved &&
        shop.status != ShopStatus.suspended) {
      context.push(AppRoutes.adminShopReviewPath(shop.id));
      return;
    }

    final suspend = shop.status != ShopStatus.suspended;
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: suspend ? 'تعليق المحل'.tr : 'إعادة تفعيل المحل'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              suspend
                  ? 'تعليق محل "${shop.name}"؟'.tr
                  : 'إعادة تفعيل محل "${shop.name}"؟'.tr,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'تأكيد'.tr,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'إلغاء'.tr,
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.setShopSuspended(
      shopId: shop.id,
      suspend: suspend,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر تحديث المحل'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      suspend ? 'تم تعليق المحل'.tr : 'تم إعادة تفعيل المحل'.tr,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(adminManagedShopsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'إدارة المحلات'.tr,
      body: AdminAsyncBody<List<Shop>>(
        placeholder: LoadingFixtures.shops,
        value: shops,
        emptyMessage: 'لا توجد محلات بعد'.tr,
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminManagedShopsProvider),
        builder: (items) {
          return ListView(
            padding: AppSpacing.page,
            children: items
                .map(
                  (shop) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: busy ? null : () => _toggle(context, ref, shop),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${shop.status.labelAr} · ${shop.city ?? '-'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (shop.ownerEmail != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              shop.ownerEmail!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            shop.status == ShopStatus.approved ||
                                    shop.status == ShopStatus.suspended
                                ? 'اضغط للتعليق أو إعادة التفعيل'.tr
                                : 'اضغط لعرض تفاصيل الطلب'.tr,
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
