import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';

Future<void> showProductCartSheet(BuildContext context, String productId) =>
    AppBottomSheet.show<void>(
      context: context,
      child: _ProductCartSheet(productId: productId),
    );

class _ProductCartSheet extends ConsumerStatefulWidget {
  const _ProductCartSheet({required this.productId});
  final String productId;
  @override
  ConsumerState<_ProductCartSheet> createState() => _ProductCartSheetState();
}

class _ProductCartSheetState extends ConsumerState<_ProductCartSheet> {
  String? selectedId;
  @override
  Widget build(BuildContext context) {
    final details = ref.watch(customerProductDetailsProvider(widget.productId));
    return AppBottomSheetScaffold(
      title: 'إضافة إلى السلة',
      child: details.when(
        loading: () => const AppSkeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('اسم المنتج'),
              SizedBox(height: 16),
              Text('اختر اللون والمقاس'),
              SizedBox(height: 20),
              SizedBox(height: 48, child: Card()),
            ],
          ),
        ),
        error: (_, _) => Column(
          children: [
            const Text('تعذر تحميل خيارات المنتج'),
            TextButton(
              onPressed: () => ref.invalidate(
                customerProductDetailsProvider(widget.productId),
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
        data: (product) {
          if (product == null || product.status != 'published') {
            return const Text('هذا المنتج غير متاح حالياً');
          }
          final available = product.variants
              .where((v) => v.isActive && v.stock > 0)
              .toList();
          ProductVariant? selected;
          for (final variant in available) {
            if (variant.id == selectedId || available.length == 1) {
              selected = variant;
            }
          }
          final choice = selected;
          final cart = ref.watch(cartProvider);
          final quantity = choice == null
              ? 0
              : cart
                    .where(
                      (item) =>
                          item.productId == product.id &&
                          item.color == choice.color &&
                          item.size == choice.size,
                    )
                    .fold<int>(0, (total, item) => total + item.quantity);
          final atLimit = choice != null && quantity >= choice.stock;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                product.shopName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${product.price.toStringAsFixed(2)} ر.س',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Text(available.isEmpty ? 'نفدت الكمية' : 'اختر اللون والمقاس'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final variant in available)
                    ChoiceChip(
                      label: Text('${variant.color} · ${variant.size}'),
                      selected: choice?.id == variant.id,
                      onSelected: (_) =>
                          setState(() => selectedId = variant.id),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: choice == null || atLimit
                    ? null
                    : () {
                        ref
                            .read(cartProvider.notifier)
                            .addItem(
                              product: product,
                              variantId: choice.id,
                              color: choice.color,
                              size: choice.size,
                              maxStock: choice.stock,
                            );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تمت إضافة المنتج إلى السلة'),
                          ),
                        );
                      },
                child: Text(
                  atLimit ? 'وصلت للكمية المتاحة' : 'تأكيد الإضافة إلى السلة',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
