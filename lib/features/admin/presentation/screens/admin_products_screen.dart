import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/models/catalog_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

class AdminProductsScreen extends ConsumerWidget {
  const AdminProductsScreen({super.key});

  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    AdminProduct product,
  ) async {
    final action = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: product.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المحل: ${product.shopName ?? '-'}\nالتصنيف: ${product.categoryName ?? '-'}\nالحالة: ${product.statusLabel}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (product.status != 'hidden')
              AppButton(
                label: 'إخفاء المنتج',
                onPressed: () => Navigator.of(context).pop('hidden'),
              ),
            if (product.status == 'hidden') ...[
              AppButton(
                label: 'إعادة النشر',
                onPressed: () => Navigator.of(context).pop('published'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else
              const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'حذف المنتج',
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop('deleted'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.setProductStatus(
      productId: product.id,
      status: action,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر تحديث المنتج' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث حالة المنتج');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(adminProductsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'المنتجات',
      body: AdminAsyncBody<List<AdminProduct>>(
        value: products,
        emptyMessage: 'لا توجد منتجات بعد',
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminProductsProvider),
        builder: (items) {
          return ListView(
            padding: AppSpacing.page,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: busy ? null : () => _manage(context, ref, item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${item.shopName ?? '-'} · ${item.statusLabel}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.price.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.titleMedium,
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
