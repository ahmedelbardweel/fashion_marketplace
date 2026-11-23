import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../shop/domain/models/shop.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminShopReviewScreen extends ConsumerWidget {
  const AdminShopReviewScreen({super.key, required this.shopId});

  final String shopId;

  Future<void> _approve(BuildContext context, WidgetRef ref, Shop shop) async {
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: Builder(
        builder: (sheetCtx) => AppBottomSheetScaffold(
          title: 'قبول المحل وتفعيل الاشتراك'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'قبول طلب "${shop.name}" وتفعيل اشتراكه (${shop.subscriptionPlanName ?? 'الباقة المختارة'} — ${AppFormat.price(shop.subscriptionPrice)})؟ سيتمكن التاجر من نشر منتجاته فوراً بدون عمولة.'
                    .tr,
                style: Theme.of(sheetCtx).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'تأكيد القبول وتفعيل الاشتراك'.tr,
                onPressed: () => Navigator.of(sheetCtx).pop(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'إلغاء'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(sheetCtx).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final actions = ref.read(shopActionProvider.notifier);
    final ok = await actions.review(shopId: shop.id, approve: true);
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(shopActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر قبول الطلب'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    ref.invalidate(adminStatsProvider);
    ref.invalidate(adminManagedShopsProvider);
    ref.invalidate(adminSubscriptionPayoutOverviewProvider);
    showAppSnackBar(context, 'تم اعتماد المحل وتفعيل اشتراكه بنجاح'.tr);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, Shop shop) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: Builder(
        builder: (sheetCtx) => AppBottomSheetScaffold(
          title: 'رفض الطلب'.tr,
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'اكتب سبب الرفض ليظهر للتاجر ويتمكن من تصحيح البيانات أو إشعار الحوالة وإعادة الإرسال.'
                      .tr,
                  style: Theme.of(sheetCtx).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: reasonController,
                  label: 'سبب الرفض'.tr,
                  maxLines: 3,
                  validator: (value) =>
                      Validators.required(value, field: 'سبب الرفض'.tr),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'تأكيد الرفض'.tr,
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.of(sheetCtx).pop(true);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'إلغاء'.tr,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;

    final actions = ref.read(shopActionProvider.notifier);
    final ok = await actions.review(
      shopId: shop.id,
      approve: false,
      rejectionReason: reason,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(shopActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر رفض الطلب'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    ref.invalidate(adminStatsProvider);
    ref.invalidate(adminManagedShopsProvider);
    ref.invalidate(adminSubscriptionPayoutOverviewProvider);
    showAppSnackBar(context, 'تم رفض الطلب وإشعار التاجر بالسبب'.tr);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(adminShopByIdProvider(shopId));
    final docsAsync = ref.watch(adminShopDocumentsProvider(shopId));
    final imagesAsync = ref.watch(adminShopImagesProvider(shopId));
    final busy = ref.watch(shopActionProvider).isLoading;

    return AdminScaffold(
      title: 'مراجعة المحل والاشتراك'.tr,
      body: AdminAsyncBody<Shop?>(
        placeholder: LoadingFixtures.shop,
        value: shopAsync,
        emptyMessage: 'الطلب غير موجود'.tr,
        isEmpty: (shop) => shop == null,
        onRetry: () {
          ref.invalidate(adminShopByIdProvider(shopId));
          ref.invalidate(adminShopDocumentsProvider(shopId));
          ref.invalidate(adminShopImagesProvider(shopId));
        },
        onRefresh: () => Future.wait([
          ref.refresh(adminShopByIdProvider(shopId).future),
          ref.refresh(adminShopDocumentsProvider(shopId).future),
          ref.refresh(adminShopImagesProvider(shopId).future),
        ]),
        builder: (shop) {
          final current = shop!;
          final hasReceipt =
              current.subscriptionReceiptUrl?.trim().isNotEmpty ?? false;
          final subBadgeTone = switch (current.subscriptionStatus) {
            'active' => BadgeTone.success,
            'rejected' || 'expired' => BadgeTone.error,
            'pending' => BadgeTone.warning,
            _ => BadgeTone.neutral,
          };
          final subBadgeLabel = switch (current.subscriptionStatus) {
            'active' => 'اشتراك فعّال'.tr,
            'expired' => 'منتهي'.tr,
            'rejected' => 'مرفوض'.tr,
            'pending' => 'بانتظار التحقق'.tr,
            _ => 'غير محدد'.tr,
          };

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page,
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text('${'الحالة'.tr}: ${current.status.labelAr.tr}'),
                        ],
                      ),
                    ),
                    AppStatusBadge(label: subBadgeLabel, tone: subBadgeTone),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Subscription & Receipt Verification Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          AppIcons.wallet,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'بيانات الاشتراك وإشعار الحوالة'.tr,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: AppFont.bold),
                          ),
                        ),
                        if (current.subscriptionPrice > 0)
                          Text(
                            AppFormat.price(current.subscriptionPrice),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: AppFont.extraBold,
                                  color: AppColors.primary,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'الباقة المختارة'.tr,
                      value: current.subscriptionPlanName ?? '-',
                    ),
                    if (current.subscriptionPaymentMethodName?.isNotEmpty ??
                        false)
                      _InfoRow(
                        label: 'تم التحويل إلى'.tr,
                        value:
                            '${current.subscriptionPaymentMethodName!}${(current.subscriptionPaymentAccountNumber?.isNotEmpty ?? false) ? ' (${current.subscriptionPaymentAccountNumber!})' : ''}',
                      ),
                    if (hasReceipt) ...[
                      Text(
                        'صورة إشعار التحويل (اضغط للتكبير والتحقق)'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ReceiptThumbnailCard(
                        imageUrl: current.subscriptionReceiptUrl!.trim(),
                        subtitle:
                            '${'إشعار اشتراك'.tr}: ${current.name} (${AppFormat.price(current.subscriptionPrice)})',
                        height: 200,
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'لم يتم إرفاق إشعار تحويل اشتراك مع هذا الطلب.'.tr,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'الوصف'.tr,
                      value: current.description ?? '-',
                    ),
                    _InfoRow(label: 'المدينة'.tr, value: current.city ?? '-'),
                    _InfoRow(
                      label: 'العنوان'.tr,
                      value: current.address ?? '-',
                    ),
                    _InfoRow(
                      label: 'السجل التجاري'.tr,
                      value: current.commercialRegister ?? '-',
                    ),
                    _InfoRow(
                      label: 'اسم المسؤول'.tr,
                      value: current.ownerName ?? '-',
                    ),
                    _InfoRow(
                      label: 'البريد'.tr,
                      value: current.ownerEmail ?? '-',
                    ),
                    _InfoRow(
                      label: 'الهاتف'.tr,
                      value: current.ownerPhone ?? '-',
                    ),
                  ],
                ),
              ),
              if (current.logoPath != null && current.logoPath!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الشعار'.tr,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppNetworkImage(
                        current.logoPath!,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text('تعذر عرض الشعار'.tr),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'صور المحل'.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              imagesAsync.skeletonWhen(
                placeholder: LoadingFixtures.media,
                error: (error, _) => AppCard(
                  child: Text(
                    ref.read(adminRepositoryProvider).mapError(error),
                  ),
                ),
                data: (images) {
                  if (images.isEmpty) {
                    return AppCard(child: Text('لا توجد صور مرفوعة'.tr));
                  }
                  return Column(
                    children: images
                        .map(
                          (image) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              child: image.filePath.startsWith('http')
                                  ? AppNetworkImage(
                                      image.filePath,
                                      height: 140,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          Text(image.filePath),
                                    )
                                  : Text(image.filePath),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'المستندات'.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              docsAsync.skeletonWhen(
                placeholder: LoadingFixtures.documents,
                error: (error, _) => AppCard(
                  child: Text(
                    ref.read(adminRepositoryProvider).mapError(error),
                  ),
                ),
                data: (docs) {
                  if (docs.isEmpty) {
                    return AppCard(
                      child: Text('لا توجد مستندات مرفوعة لهذا المحل بعد'.tr),
                    );
                  }
                  return Column(
                    children: docs
                        .map(
                          (doc) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              onTap: () async {
                                try {
                                  final url = await ref
                                      .read(adminRepositoryProvider)
                                      .signedDocumentUrl(doc.filePath);
                                  final uri = Uri.parse(url);
                                  final opened = await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  if (!context.mounted) return;
                                  if (!opened) {
                                    showAppSnackBar(
                                      context,
                                      'تعذر فتح المستند'.tr,
                                      isError: true,
                                    );
                                  }
                                } catch (error) {
                                  if (!context.mounted) return;
                                  showAppSnackBar(
                                    context,
                                    ref
                                        .read(adminRepositoryProvider)
                                        .mapError(error),
                                    isError: true,
                                  );
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.docType),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'اضغط لإنشاء رابط مؤقت للعرض'.tr,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
              if (current.status == ShopStatus.pending) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'قبول المحل وتفعيل الاشتراك'.tr,
                  isLoading: busy,
                  onPressed: () => _approve(context, ref, current),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'رفض الطلب'.tr,
                  variant: AppButtonVariant.outlined,
                  isLoading: busy,
                  onPressed: () => _reject(context, ref, current),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
