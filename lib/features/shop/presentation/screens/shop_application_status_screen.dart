import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopApplicationStatusScreen extends ConsumerWidget {
  const ShopApplicationStatusScreen({super.key});

  String _message(Shop shop) {
    switch (shop.visibleStatus) {
      case ShopStatus.pending:
        return 'طلب الانضمام قيد المراجعة لدى الإدارة. سيظهر القرار هنا بعد المدة المحددة في إعدادات المنصة.'.tr;
      case ShopStatus.approved:
        return 'تمت الموافقة على المحل. يمكنك الآن إدارة منتجاتك وطلباتك.'.tr;
      case ShopStatus.rejected:
        return 'تم رفض طلب الانضمام. يمكنك تعديل البيانات وإعادة التقديم.'.tr;
      case ShopStatus.suspended:
        return 'تم تعليق المحل. تواصل مع الإدارة.'.tr;
      case ShopStatus.draft:
        return 'أكمل بيانات المحل ثم أرسل طلب الانضمام.'.tr;
    }
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      final shop = await ref.refresh(myShopProvider.future);
      if (!context.mounted) return;
      if (shop == null) {
        showAppSnackBar(
          context,
          'لم يتم العثور على بيانات المحل'.tr,
          isError: true,
        );
        return;
      }
      showAppSnackBar(context, 'الحالة الحالية: ${shop.visibleStatus.labelAr}'.tr);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        ref.read(shopRepositoryProvider).mapError(error),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);
    final refreshing = shopAsync.isLoading || shopAsync.isRefreshing;

    return ShopScaffold(
      title: 'حالة الطلب'.tr,
      showBack: false,
      showBottomNav: false,
      body: shopAsync.skeletonWhen(
        placeholder: LoadingFixtures.shop,
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        error: (error, _) => Center(
          child: Padding(
            padding: AppSpacing.page,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ref.read(shopRepositoryProvider).mapError(error)),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'إعادة المحاولة'.tr,
                  onPressed: () => _refresh(context, ref),
                ),
              ],
            ),
          ),
        ),
        data: (shop) {
          if (shop == null) {
            return Center(child: Text('لم يتم العثور على بيانات المحل'.tr));
          }

          return ListView(
            padding: AppSpacing.page,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الحالة'.tr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      shop.visibleStatus.labelAr,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      shop.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _message(shop),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (shop.visibleRejectionReason != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'سبب الرفض'.tr,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(shop.visibleRejectionReason!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (shop.visibleStatus == ShopStatus.rejected ||
                  shop.visibleStatus == ShopStatus.draft)
                AppButton(
                  label: 'تعديل البيانات وإعادة التقديم'.tr,
                  onPressed: () => context.go(AppRoutes.shopCompleteProfile),
                ),
              if (shop.visibleStatus == ShopStatus.approved)
                AppButton(
                  label: 'الذهاب إلى لوحة المحل'.tr,
                  onPressed: () => context.go(AppRoutes.shopHome),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'تحديث الحالة'.tr,
                variant: AppButtonVariant.outlined,
                isLoading: refreshing,
                onPressed: () => _refresh(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'تسجيل الخروج'.tr,
                variant: AppButtonVariant.outlined,
                onPressed: () => confirmShopLogout(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}
