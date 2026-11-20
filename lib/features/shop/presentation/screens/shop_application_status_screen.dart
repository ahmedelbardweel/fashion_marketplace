import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopApplicationStatusScreen extends ConsumerWidget {
  const ShopApplicationStatusScreen({super.key});

  String _message(Shop shop) {
    switch (shop.visibleStatus) {
      case ShopStatus.pending:
        return 'طلب الانضمام قيد المراجعة لدى الإدارة. سيظهر القرار هنا فور اكتمال المراجعة.'
            .tr;
      case ShopStatus.approved:
        return 'تمت الموافقة على متجرك بنجاح! يمكنك الآن إضافة منتجاتك واستقبال الطلبات.'
            .tr;
      case ShopStatus.rejected:
        return 'تم رفض طلب الانضمام. يمكنك تعديل البيانات وفق الملاحظات وإعادة التقديم.'
            .tr;
      case ShopStatus.suspended:
        return 'تم تعليق المتجر مؤقتاً. يرجى التواصل مع إدارة المنصة لمعرفة التفاصيل.'
            .tr;
      case ShopStatus.draft:
        return 'أكمل بيانات المتجر أولاً ثم أرسل طلب الانضمام للمراجعة.'.tr;
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
      showAppSnackBar(
        context,
        '${'الحالة الحالية'.tr}: ${shop.visibleStatus.labelAr.tr}',
      );
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
      title: 'حالة طلب الانضمام'.tr,
      showBack: false,
      showBottomNav: false,
      showNotifications: false,
      body: shopAsync.skeletonWhen(
        placeholder: LoadingFixtures.shop,
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        error: (error, _) => ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل حالة الطلب'.tr,
              message: ref.read(shopRepositoryProvider).mapError(error),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة'.tr,
              onAction: () => _refresh(context, ref),
            ),
          ],
        ),
        data: (shop) {
          if (shop == null) {
            return ListView(
              padding: AppSpacing.page,
              children: [
                ShopEmptyState(
                  title: 'لم يتم العثور على بيانات المحل',
                  message: 'اضغط للتحديث أو أعد تسجيل الدخول.',
                  actionLabel: 'تحديث',
                  onAction: () => _refresh(context, ref),
                ),
              ],
            );
          }

          final status = shop.visibleStatus;
          final tone = shopStatusTone(status);
          final currentStep = switch (status) {
            ShopStatus.draft => 0,
            ShopStatus.pending || ShopStatus.rejected => 1,
            ShopStatus.approved || ShopStatus.suspended => 2,
          };

          return AppRefreshIndicator(
            onRefresh: () => _refresh(context, ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      AppStatusBadge(label: status.labelAr, tone: tone),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        shop.name.trim().isNotEmpty ? shop.name : 'متجري'.tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: AppFont.bold),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _message(shop),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (shop.visibleRejectionReason != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ShopNoticeBanner(
                    title: 'سبب الرفض'.tr,
                    message: shop.visibleRejectionReason!,
                    tone: BadgeTone.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'مراحل تفعيل المتجر'.tr,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: AppFont.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _StatusTimelineStep(
                        index: 1,
                        title: 'استكمال بيانات المتجر'.tr,
                        subtitle: 'إدخال المعلومات الأساسية ورفع الهوية'.tr,
                        done: currentStep > 0 || shop.isProfileReady,
                        active: currentStep == 0,
                        isLast: false,
                      ),
                      _StatusTimelineStep(
                        index: 2,
                        title: 'مراجعة الإدارة'.tr,
                        subtitle: status == ShopStatus.rejected
                            ? 'تحتاج البيانات إلى تعديل وإعادة إرسال'.tr
                            : 'التحقق من السجل التجاري والبيانات'.tr,
                        done: currentStep > 1,
                        active: currentStep == 1,
                        hasError: status == ShopStatus.rejected,
                        isLast: false,
                      ),
                      _StatusTimelineStep(
                        index: 3,
                        title: 'تفعيل المتجر وبدء البيع'.tr,
                        subtitle: status == ShopStatus.suspended
                            ? 'المتجر موقوف حالياً'.tr
                            : 'إضافة المنتجات واستقبال طلبات العملاء'.tr,
                        done: status == ShopStatus.approved,
                        active: currentStep == 2,
                        hasError: status == ShopStatus.suspended,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (status == ShopStatus.rejected || status == ShopStatus.draft)
                  AppButton(
                    label: status == ShopStatus.draft
                        ? 'استكمال البيانات'.tr
                        : 'تعديل البيانات وإعادة التقديم'.tr,
                    onPressed: () => context.go(AppRoutes.shopCompleteProfile),
                  ),
                if (status == ShopStatus.approved)
                  AppButton(
                    label: 'الذهاب إلى لوحة المحل'.tr,
                    onPressed: () => context.go(AppRoutes.shopHome),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'تحديث الحالة'.tr,
                  variant: AppButtonVariant.secondary,
                  isLoading: refreshing,
                  onPressed: () => _refresh(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'تسجيل الخروج'.tr,
                  variant: AppButtonVariant.text,
                  onPressed: () => confirmShopLogout(context, ref),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusTimelineStep extends StatelessWidget {
  const _StatusTimelineStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.isLast,
    this.hasError = false,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final bool isLast;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final circleColor = hasError
        ? AppColors.error
        : done
        ? AppColors.success
        : active
        ? SellerDesign.stepActive
        : SellerDesign.stepInactive;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done || active || hasError
                      ? circleColor
                      : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: circleColor, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  hasError
                      ? '!'
                      : done
                      ? '✓'
                      : '$index',
                  style: TextStyle(
                    fontSize: AppFont.small,
                    fontWeight: AppFont.bold,
                    color: (done || active || hasError)
                        ? AppColors.onPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: done ? AppColors.success : AppColors.divider,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                      color: hasError ? AppColors.error : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
