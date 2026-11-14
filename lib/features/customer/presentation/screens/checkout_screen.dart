import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_action_sheet.dart';
import '../widgets/customer_shell.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      final addr = user.address?.trim() ?? '';
      _addressController.text = addr.isNotEmpty ? addr : (user.city ?? '');
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

    if (address.isEmpty || phone.isEmpty) {
      showAppSnackBar(
        context,
        'يرجى إدخال عنوان التوصيل ورقم الهاتف'.tr,
        isError: true,
      );
      return;
    }

    final itemsByShop = ref.read(cartProvider.notifier).itemsByShop;
    if (itemsByShop.isEmpty) {
      showAppSnackBar(context, 'السلة فارغة'.tr, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(customerRepositoryProvider);

      for (final entry in itemsByShop.entries) {
        await repo.placeOrder(
          shopId: entry.key,
          items: entry.value,
          deliveryAddress: address,
          phone: phone,
          notes: _notesController.text,
        );
      }

      ref.read(cartProvider.notifier).clearCart();
      ref.invalidate(customerOrdersProvider);

      if (!mounted) return;

      AppBottomSheet.show(
        context: context,
        isDismissible: false,
        enableDrag: false,
        child: Builder(
          builder: (ctx) {
            return CustomerActionSheet(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: CheckoutDesign.successIconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.checkCircleFilled,
                      color: CheckoutDesign.successIcon,
                      size: CheckoutDesign.successIconSize,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'تم تأكيد طلبك بنجاح'.tr,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'سيتولى المتجر تجهيز ملابسك وشحنها إلى عنوانك في أقرب وقت.'.tr,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'متابعة تفاصيل الطلب'.tr,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go(AppRoutes.customerOrders);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(customerRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalAmount = ref.watch(cartProvider.notifier).totalAmount;

    return CustomerScaffold(
      title: 'إتمام الشراء'.tr,
      showSearch: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Delivery Information Card
            Text(
              'عنوان التوصيل والتواصل'.tr,
              style: TextStyle(
                fontSize: SectionDesign.titleSize,
                fontWeight: SectionDesign.titleWeight,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _addressController,
                    label: 'عنوان التوصيل التفصيلي (المدينة، الحي، الشارع)'.tr,
                    prefixIcon: AppIcons.location,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    label: 'رقم هاتف المستلم'.tr,
                    keyboardType: TextInputType.phone,
                    prefixIcon: AppIcons.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _notesController,
                    label: 'ملاحظات إضافية للتوصيل (اختياري)'.tr,
                    prefixIcon: AppIcons.notes,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Payment Method
            Text(
              'طريقة الدفع'.tr,
              style: TextStyle(
                fontSize: SectionDesign.titleSize,
                fontWeight: SectionDesign.titleWeight,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              borderColor: CheckoutDesign.optionSelectedBorder,
              backgroundColor: CheckoutDesign.optionSelectedBackground,
              child: Row(
                children: [
                  Icon(AppIcons.payment, color: AppColors.icon),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الدفع عند الاستلام'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ادفع نقداً أو عبر البطاقة عند استلام طلبك'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.checkCircleFilled, color: AppColors.primary),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Order Summary
            Text(
              'ملخص الطلب (${cartItems.length})'.tr,
              style: TextStyle(
                fontSize: SectionDesign.titleSize,
                fontWeight: SectionDesign.titleWeight,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  ...cartItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} (${item.variantDescription}) × ${item.quantity}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppFormat.price(item.totalPrice),
                            style: TextStyle(
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الشحن والتوصيل'.tr),
                      Text(
                        'مجاناً'.tr,
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: AppFont.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المبلغ المطلوب دفعه'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFont.bold,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        AppFormat.price(totalAmount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: AppFont.extraBold,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Confirm Button
            AppButton(
              label: 'تأكيد الطلب الآن'.tr,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitOrder,
            ),
          ],
        ),
      ),
    );
  }
}
