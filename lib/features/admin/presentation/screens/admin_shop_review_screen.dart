import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
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
      child: AppBottomSheetScaffold(
        title: 'قبول المحل',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'قبول طلب "${shop.name}"؟ سيظهر القرار للمحل حسب إعداد تأخير القرار.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'تأكيد القبول',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'إلغاء',
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
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
        error == null ? 'تعذر قبول الطلب' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    ref.invalidate(adminStatsProvider);
    ref.invalidate(adminManagedShopsProvider);
    showAppSnackBar(context, 'تم قبول الطلب');
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, Shop shop) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'رفض المحل',
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اكتب سبب الرفض. سيظهر للمحل حسب إعداد تأخير القرار.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: reasonController,
                label: 'سبب الرفض',
                maxLines: 3,
                validator: (value) =>
                    Validators.required(value, field: 'سبب الرفض'),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'تأكيد الرفض',
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'إلغاء',
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
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
        error == null ? 'تعذر رفض الطلب' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    ref.invalidate(adminStatsProvider);
    ref.invalidate(adminManagedShopsProvider);
    showAppSnackBar(context, 'تم رفض الطلب');
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(adminShopByIdProvider(shopId));
    final docsAsync = ref.watch(adminShopDocumentsProvider(shopId));
    final imagesAsync = ref.watch(adminShopImagesProvider(shopId));
    final busy = ref.watch(shopActionProvider).isLoading;

    return AdminScaffold(
      title: 'مراجعة المحل',
      body: AdminAsyncBody<Shop?>(
        placeholder: LoadingFixtures.shop,
        value: shopAsync,
        emptyMessage: 'الطلب غير موجود',
        isEmpty: (shop) => shop == null,
        onRetry: () {
          ref.invalidate(adminShopByIdProvider(shopId));
          ref.invalidate(adminShopDocumentsProvider(shopId));
          ref.invalidate(adminShopImagesProvider(shopId));
        },
        builder: (shop) {
          final current = shop!;
          return ListView(
            padding: AppSpacing.page,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('الحالة: ${current.status.labelAr}'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'الوصف', value: current.description ?? '-'),
                    _InfoRow(label: 'المدينة', value: current.city ?? '-'),
                    _InfoRow(label: 'العنوان', value: current.address ?? '-'),
                    _InfoRow(
                      label: 'السجل التجاري',
                      value: current.commercialRegister ?? '-',
                    ),
                    _InfoRow(
                      label: 'اسم المسؤول',
                      value: current.ownerName ?? '-',
                    ),
                    _InfoRow(label: 'البريد', value: current.ownerEmail ?? '-'),
                    _InfoRow(label: 'الهاتف', value: current.ownerPhone ?? '-'),
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
                        'الشعار',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppNetworkImage(
                        current.logoPath!,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Text('تعذر عرض الشعار'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('صور المحل', style: Theme.of(context).textTheme.titleLarge),
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
                    return const AppCard(child: Text('لا توجد صور مرفوعة'));
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
                                      errorBuilder: (_, __, ___) =>
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
              Text('المستندات', style: Theme.of(context).textTheme.titleLarge),
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
                    return const AppCard(
                      child: Text('لا توجد مستندات مرفوعة لهذا المحل بعد'),
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
                                      'تعذر فتح المستند',
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
                                    'اضغط لإنشاء رابط مؤقت للعرض',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
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
                  label: 'قبول',
                  isLoading: busy,
                  onPressed: () => _approve(context, ref, current),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'رفض',
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
