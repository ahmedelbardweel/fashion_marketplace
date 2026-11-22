import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gaza_region_picker_sheet.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/gaza_region.dart';
import '../../../admin/domain/models/payment_method.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/customer_shop.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_action_sheet.dart';
import '../widgets/customer_shell.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

const List<PaymentMethod> _kPlaceholderPaymentMethods = [
  PaymentMethod(
    id: 'sk_bank_1',
    name: 'بنك فلسطين',
    nameEn: 'Bank of Palestine',
    type: 'bank',
    accountNumber: '0458-000000-001',
    iban: 'PS00PALS0458000000000001',
    accountHolder: 'منصة وصلة للتجارة',
  ),
  PaymentMethod(
    id: 'sk_wallet_1',
    name: 'محفظة بال باي',
    nameEn: 'PalPay Wallet',
    type: 'wallet',
    accountNumber: '0599000001',
    accountHolder: 'منصة وصلة',
  ),
];

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _deliveryMode = 'shop_delivery'; // 'shop_delivery' | 'customer_pickup'
  String _paymentType = 'bank'; // 'bank' | 'wallet'
  String? _selectedPaymentMethodId;
  String? _uploadedReceiptUrl;
  Uint8List? _receiptPreviewBytes;
  bool _isUploadingReceipt = false;
  bool _isSubmitting = false;

  bool get _isShopDelivery => _deliveryMode == 'shop_delivery';

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      _cityController.text = user.city?.trim() ?? '';
      _addressController.text = user.address?.trim() ?? '';
      _phoneController.text = user.phone ?? '';
    }
  }

  Future<void> _openAddressSheet() async {
    if (_isSubmitting) return;
    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return SafeArea(
            top: false,
            child: AppBottomSheetScaffold(
              title: _isShopDelivery
                  ? 'منطقة التوصيل والتواصل'.tr
                  : 'بيانات التواصل'.tr,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isShopDelivery) ...[
                    GazaRegionFormField(
                      controller: _cityController,
                      label: 'منطقة التوصيل في قطاع غزة *',
                      onlyDeliveryAvailable: true,
                      enabled: !_isSubmitting,
                      onChanged: (_) {
                        setSheetState(() {});
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _addressController,
                      label: 'العنوان التفصيلي'.tr,
                      prefixIcon: AppIcons.location,
                      enabled: !_isSubmitting,
                      onChanged: (_) {
                        setSheetState(() {});
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppTextField(
                    controller: _phoneController,
                    label: 'رقم هاتف التواصل'.tr,
                    keyboardType: TextInputType.phone,
                    prefixIcon: AppIcons.phone,
                    enabled: !_isSubmitting,
                    onChanged: (_) {
                      setSheetState(() {});
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'حفظ'.tr,
                    onPressed: () {
                      FocusScope.of(sheetCtx).unfocus();
                      Navigator.of(sheetCtx).pop();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _computeDeliveryFee(
    Map<String, List<dynamic>> itemsByShop,
    List<CustomerShop> shops,
  ) {
    if (!_isShopDelivery) return 0.0;
    final shopById = <String, CustomerShop>{for (final s in shops) s.id: s};
    var sum = 0.0;
    for (final shopId in itemsByShop.keys) {
      sum += shopById[shopId]?.deliveryFee ?? 0.0;
    }
    return sum;
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    AppHaptics.selection();
    if (!mounted) return;
    showAppSnackBar(context, '${'تم نسخ'.tr} $label');
  }

  Future<void> _pickAndUploadReceipt({required bool fromCamera}) async {
    if (_isUploadingReceipt || _isSubmitting) return;
    final picked = fromCamera
        ? await MediaPicker.pickFromCamera()
        : await MediaPicker.pickImage();
    if (picked == null || !mounted) return;

    setState(() {
      _receiptPreviewBytes = picked.bytes;
      _isUploadingReceipt = true;
    });
    try {
      final url = await ref
          .read(customerRepositoryProvider)
          .uploadPaymentReceipt(
            bytes: picked.bytes,
            fileName: picked.fileName,
            contentType: picked.contentType,
          );
      if (!mounted) return;
      setState(() {
        _uploadedReceiptUrl = url;
        _isUploadingReceipt = false;
      });
      AppHaptics.success();
      showAppSnackBar(context, 'تم رفع صورة إشعار الحوالة بنجاح'.tr);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_uploadedReceiptUrl == null) {
          _receiptPreviewBytes = null;
        }
        _isUploadingReceipt = false;
      });
      showAppSnackBar(
        context,
        ref.read(customerRepositoryProvider).mapError(error),
        isError: true,
      );
    }
  }

  Future<void> _submitOrder(List<PaymentMethod> activeMethods) async {
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();
    final regions =
        ref.read(gazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;

    if (phone.isEmpty) {
      showAppSnackBar(context, 'يرجى إدخال رقم هاتف التواصل'.tr, isError: true);
      await _openAddressSheet();
      return;
    }

    String fullAddress;
    if (_isShopDelivery) {
      if (!isValidGazaRegionSelection(city, regions)) {
        showAppSnackBar(
          context,
          'يرجى اختيار منطقة التوصيل من قائمة قطاع غزة المعتمدة'.tr,
          isError: true,
        );
        await _openAddressSheet();
        return;
      }
      if (address.isEmpty) {
        showAppSnackBar(
          context,
          'يرجى إدخال العنوان التفصيلي للتوصيل'.tr,
          isError: true,
        );
        await _openAddressSheet();
        return;
      }
      fullAddress = '$city — $address';
    } else {
      fullAddress = 'توصيل من الزبون';
    }

    final selectedMethod = _resolveSelectedMethod(activeMethods);
    if (selectedMethod == null) {
      showAppSnackBar(
        context,
        'يرجى اختيار وسيلة الدفع (بنك أو محفظة)'.tr,
        isError: true,
      );
      return;
    }

    if (_uploadedReceiptUrl == null || _uploadedReceiptUrl!.trim().isEmpty) {
      showAppSnackBar(
        context,
        'يرجى رفع صورة إشعار الحوالة أولاً لإتمام الطلب'.tr,
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
          deliveryAddress: fullAddress,
          phone: phone,
          notes: _notesController.text,
          deliveryMode: _deliveryMode,
          paymentMethodId: selectedMethod.id,
          paymentReceiptUrl: _uploadedReceiptUrl!,
        );
      }

      ref.read(cartProvider.notifier).clearCart();
      ref.invalidate(customerOrdersProvider);

      if (!mounted) return;
      AppHaptics.success();

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
                    'تم إرسال طلبك وإشعار الحوالة بنجاح'.tr,
                    style: Theme.of(
                      ctx,
                    ).textTheme.titleLarge?.copyWith(fontWeight: AppFont.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'سيراجع صاحب المتجر إشعار الحوالة ويبدأ بتجهيز وشحن طلبك فوراً، وسيصلك إشعار بكل تحديث.'
                        .tr,
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'متابعة حالة الطلب'.tr,
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

  PaymentMethod? _resolveSelectedMethod(List<PaymentMethod> methods) {
    if (methods.isEmpty) return null;
    final banks = methods.where((m) => m.isBank).toList();
    final wallets = methods.where((m) => m.isWallet).toList();
    final effectiveType = _paymentType == 'wallet'
        ? (wallets.isNotEmpty ? 'wallet' : 'bank')
        : (banks.isNotEmpty ? 'bank' : 'wallet');
    final scoped = effectiveType == 'wallet' ? wallets : banks;
    final pool = scoped.isNotEmpty ? scoped : methods;
    if (_selectedPaymentMethodId != null) {
      for (final m in pool) {
        if (m.id == _selectedPaymentMethodId) return m;
      }
    }
    return pool.first;
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final itemsByShop = ref.watch(cartProvider.notifier).itemsByShop;
    final subtotal = ref.watch(cartProvider.notifier).totalAmount;
    final shopsAsync = ref.watch(customerShopsProvider);
    final paymentMethodsAsync = ref.watch(activePaymentMethodsProvider);

    final shops = shopsAsync.asData?.value ?? const <CustomerShop>[];
    final shopDeliveryFee = _computeDeliveryFee(itemsByShop, shops);
    final activeDeliveryFee = _isShopDelivery ? shopDeliveryFee : 0.0;
    final grandTotal = subtotal + activeDeliveryFee;

    final activeMethods =
        paymentMethodsAsync.asData?.value ?? const <PaymentMethod>[];
    final selectedMethod = _resolveSelectedMethod(activeMethods);
    final hasReceipt =
        _uploadedReceiptUrl != null && _uploadedReceiptUrl!.trim().isNotEmpty;
    final canSubmit =
        cartItems.isNotEmpty &&
        !_isSubmitting &&
        !_isUploadingReceipt &&
        selectedMethod != null &&
        hasReceipt;

    return CustomerScaffold(
      title: 'إتمام الشراء'.tr,
      showBottomNav: false,
      bottomNavigationBar: _CheckoutStickyFooter(
        items: cartItems,
        subtotal: subtotal,
        deliveryFee: activeDeliveryFee,
        grandTotal: grandTotal,
        isShopDelivery: _isShopDelivery,
        isSubmitting: _isSubmitting,
        canSubmit: canSubmit,
        onSubmit: () => _submitOrder(activeMethods),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =================================================================
            // 1) اختيار التوصيل في أعلى الشاشة مباشرة
            // =================================================================
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SegmentedDeliveryTab(
                      selected: _isShopDelivery,
                      title: 'توصيل المحل'.tr,
                      onTap: _isSubmitting
                          ? null
                          : () {
                              AppHaptics.selection();
                              setState(() => _deliveryMode = 'shop_delivery');
                            },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _SegmentedDeliveryTab(
                      selected: !_isShopDelivery,
                      title: 'توصيل الزبون'.tr,
                      onTap: _isSubmitting
                          ? null
                          : () {
                              AppHaptics.selection();
                              setState(() => _deliveryMode = 'customer_pickup');
                            },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // =================================================================
            // 2) المنطقة وبيانات التواصل (مضغوطة جداً وتفتح BottomSheet مع SafeArea)
            // =================================================================
            Builder(
              builder: (context) {
                final cityText = _cityController.text.trim();
                final addrText = _addressController.text.trim();
                final phoneText = _phoneController.text.trim();
                final summaryParts = <String>[
                  if (_isShopDelivery && cityText.isNotEmpty) cityText,
                  if (_isShopDelivery && addrText.isNotEmpty) addrText,
                  if (phoneText.isNotEmpty) phoneText,
                ];
                final summaryLine = summaryParts.isEmpty
                    ? 'اضغط لإدخال المنطقة والعنوان ورقم الهاتف'.tr
                    : summaryParts.join(' · ');

                return AppCard(
                  padding: EdgeInsets.zero,
                  onTap: _isSubmitting ? null : _openAddressSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Icon(
                            _isShopDelivery
                                ? AppIcons.location
                                : AppIcons.phone,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isShopDelivery
                                    ? 'منطقة التوصيل والتواصل'.tr
                                    : 'بيانات التواصل'.tr,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: AppFont.bold,
                                  color: AppColors.text,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                summaryLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: summaryParts.isEmpty
                                      ? AppColors.warning
                                      : AppColors.textMuted,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تعديل'.tr,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFont.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          AppIcons.forward,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 6),

            // بوكس الملاحظات تحت المنطقة مباشرة
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                controller: _notesController,
                enabled: !_isSubmitting,
                minLines: 2,
                maxLines: 3,
                style: TextStyle(fontSize: 13, color: AppColors.text),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hintText: _isShopDelivery
                      ? 'ملاحظات للتوصيل (اختياري)'.tr
                      : 'ملاحظات أو اسم المندوب (اختياري)'.tr,
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Icon(
                      AppIcons.notes,
                      size: 17,
                      color: AppColors.textMuted,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // =================================================================
            // 3) الدفع وإشعار الحوالة
            // =================================================================
            Row(
              children: [
                Expanded(
                  child: _CompactSectionTitle(
                    title: 'الدفع وإشعار الحوالة'.tr,
                  ),
                ),
                AppStatusBadge(
                  label: hasReceipt ? 'تم الرفع'.tr : 'مطلوب'.tr,
                  tone: hasReceipt ? BadgeTone.success : BadgeTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 6),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderColor: hasReceipt
                  ? AppColors.success.withValues(alpha: 0.45)
                  : AppColors.border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bank / Wallet selector + account details (unified AppSkeleton shimmer)
                  paymentMethodsAsync.skeletonWhen(
                    placeholder: _kPlaceholderPaymentMethods,
                    error: (_, _) => Row(
                      children: [
                        Expanded(
                          child: Text(
                            'تعذر تحميل أرقام البنوك والمحافظ'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(activePaymentMethodsProvider),
                          child: Text('إعادة المحاولة'.tr),
                        ),
                      ],
                    ),
                    data: (methods) {
                      if (methods.isEmpty) {
                        return Text(
                          'لا توجد وسائل دفع مفعّلة حالياً من الإدارة. يرجى المحاولة لاحقاً.'
                              .tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        );
                      }

                      final banks = methods.where((m) => m.isBank).toList();
                      final wallets = methods.where((m) => m.isWallet).toList();
                      final hasBothTypes =
                          banks.isNotEmpty && wallets.isNotEmpty;
                      final effectiveType = _paymentType == 'wallet'
                          ? (wallets.isNotEmpty ? 'wallet' : 'bank')
                          : (banks.isNotEmpty ? 'bank' : 'wallet');
                      final visibleMethods =
                          effectiveType == 'wallet' ? wallets : banks;
                      final activeSelected = _resolveSelectedMethod(methods);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasBothTypes) ...[
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _SegmentedDeliveryTab(
                                      selected: effectiveType == 'bank',
                                      title: 'بنك'.tr,
                                      onTap: _isSubmitting
                                          ? null
                                          : () {
                                              AppHaptics.selection();
                                              setState(() {
                                                _paymentType = 'bank';
                                                _selectedPaymentMethodId =
                                                    banks.first.id;
                                              });
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: _SegmentedDeliveryTab(
                                      selected: effectiveType == 'wallet',
                                      title: 'محفظة'.tr,
                                      onTap: _isSubmitting
                                          ? null
                                          : () {
                                              AppHaptics.selection();
                                              setState(() {
                                                _paymentType = 'wallet';
                                                _selectedPaymentMethodId =
                                                    wallets.first.id;
                                              });
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: visibleMethods.map((m) {
                                final isSelected = activeSelected?.id == m.id;
                                return Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 6,
                                  ),
                                  child: InkWell(
                                    onTap: _isSubmitting
                                        ? null
                                        : () {
                                            AppHaptics.selection();
                                            setState(
                                              () => _selectedPaymentMethodId =
                                                  m.id,
                                            );
                                          },
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.sm,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 140,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? CheckoutDesign
                                                  .optionSelectedBackground
                                            : AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.sm,
                                        ),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        m.displayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? AppFont.bold
                                              : AppFont.medium,
                                          color: isSelected
                                              ? AppColors.text
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (activeSelected != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _CompactAccountRow(
                              label: activeSelected.accountHolder
                                      .trim()
                                      .isNotEmpty
                                  ? activeSelected.accountHolder.trim()
                                  : (activeSelected.isWallet
                                        ? 'رقم المحفظة'.tr
                                        : 'رقم الحساب'.tr),
                              value: activeSelected.accountNumber,
                              onCopy: () => _copyText(
                                activeSelected.accountNumber,
                                activeSelected.isWallet
                                    ? 'رقم المحفظة'.tr
                                    : 'رقم الحساب'.tr,
                              ),
                            ),
                            if (activeSelected.iban != null &&
                                activeSelected.iban!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _CompactAccountRow(
                                label: 'IBAN',
                                value: activeSelected.iban!.trim(),
                                onCopy: () => _copyText(
                                  activeSelected.iban!.trim(),
                                  'IBAN',
                                ),
                              ),
                            ],
                          ],
                        ],
                      );
                    },
                  ),

                  const Divider(height: AppSpacing.md),

                  // Receipt uploader buttons (always accessible for quick pick/replace)
                  Row(
                    children: [
                      Expanded(
                        child: _CompactReceiptAction(
                          icon: AppIcons.addPhoto,
                          label: 'من المعرض'.tr,
                          onTap: () =>
                              _pickAndUploadReceipt(fromCamera: false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CompactReceiptAction(
                          icon: IconsaxPlusLinear.camera,
                          label: 'تصوير الإشعار'.tr,
                          onTap: () => _pickAndUploadReceipt(fromCamera: true),
                        ),
                      ),
                    ],
                  ),

                  // Clear full-width receipt preview directly below so user can verify it
                  if (_receiptPreviewBytes != null || hasReceipt) ...[
                    const SizedBox(height: AppSpacing.sm),
                    GestureDetector(
                      onTap: hasReceipt
                          ? () => showReceiptImageViewer(
                              context,
                              imageUrl: _uploadedReceiptUrl!,
                              title: 'إشعار الحوالة المرفق'.tr,
                            )
                          : null,
                      child: Container(
                        height: 190,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_receiptPreviewBytes != null)
                              Image.memory(
                                _receiptPreviewBytes!,
                                fit: BoxFit.contain,
                              )
                            else
                              AppNetworkImage(
                                _uploadedReceiptUrl!,
                                fit: BoxFit.contain,
                              ),
                            if (_isUploadingReceipt)
                              Container(
                                color: Colors.black.withValues(alpha: 0.48),
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.sm,
                                    ),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const AppBusyLabel(
                                    label: 'جاري رفع إشعار الحوالة...',
                                  ),
                                ),
                              ),
                            if (!_isUploadingReceipt && !_isSubmitting)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.68),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      AppHaptics.selection();
                                      setState(() {
                                        _uploadedReceiptUrl = null;
                                        _receiptPreviewBytes = null;
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (hasReceipt && !_isUploadingReceipt)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.sm,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.zoom_in_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'اضغط على الصورة للمعاينة'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: AppFont.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSectionTitle extends StatelessWidget {
  const _CompactSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: AppFont.bold,
        color: AppColors.text,
      ),
    );
  }
}

class _SegmentedDeliveryTab extends StatelessWidget {
  const _SegmentedDeliveryTab({
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? CheckoutDesign.optionSelectedBackground
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? AppColors.border : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? AppFont.bold : AppFont.medium,
            color: selected ? AppColors.text : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CompactAccountRow extends StatelessWidget {
  const _CompactAccountRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: AppFont.extraBold,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(
                'نسخ'.tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactReceiptAction extends StatelessWidget {
  const _CompactReceiptAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: AppHaptics.action(onTap),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: AppFont.bold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutStickyFooter extends StatelessWidget {
  const _CheckoutStickyFooter({
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.grandTotal,
    required this.isShopDelivery,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  final List<CartItem> items;
  final double subtotal;
  final double deliveryFee;
  final double grandTotal;
  final bool isShopDelivery;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              10,
              AppSpacing.md,
              10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 54),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.productName} (${item.variantDescription}) × ${item.quantity}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  AppFormat.price(item.totalPrice),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: AppFont.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Divider(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'قيمة المنتجات'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      AppFormat.price(subtotal),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: AppFont.semiBold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                if (isShopDelivery) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'رسوم التوصيل (من المحل)'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        deliveryFee > 0
                            ? AppFormat.price(deliveryFee)
                            : 'مجاناً'.tr,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: deliveryFee > 0
                              ? AppColors.text
                              : AppColors.success,
                          fontWeight: AppFont.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: CheckoutDesign.optionSelectedBackground,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المبلغ المطلوب تحويله'.tr,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: AppFont.bold,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        AppFormat.price(grandTotal),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFont.extraBold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (canSubmit || isSubmitting)
                  AppButton(
                    label: 'إتمام الطلب'.tr,
                    isLoading: isSubmitting,
                    onPressed: canSubmit ? onSubmit : null,
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: ButtonDesign.height,
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        disabledBackgroundColor: AppColors.surfaceAlt,
                        disabledForegroundColor: AppColors.textMuted,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ButtonDesign.radius,
                          ),
                        ),
                      ),
                      child: Text(
                        'إتمام الطلب'.tr,
                        style: TextStyle(
                          fontWeight: AppFont.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
