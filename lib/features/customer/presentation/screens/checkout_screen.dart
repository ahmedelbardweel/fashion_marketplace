import 'dart:math';
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

  final Map<String, String> _deliveryModeByShop = {};
  String _paymentType = 'bank'; // 'bank' | 'wallet'
  String? _selectedPaymentMethodId;
  String? _uploadedReceiptUrl;
  Uint8List? _receiptPreviewBytes;
  bool _isUploadingReceipt = false;
  bool _isSubmitting = false;

  String _deliveryModeFor(String shopId) =>
      _deliveryModeByShop[shopId] ?? 'shop_delivery';

  bool _isShopDeliveryFor(String shopId) =>
      _deliveryModeFor(shopId) == 'shop_delivery';

  bool _hasAnyShopDelivery(Iterable<String> shopIds) {
    if (shopIds.isEmpty) return true;
    return shopIds.any(_isShopDeliveryFor);
  }

  String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

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

  Future<void> _openAddressSheet({required bool needsAddress}) async {
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
              title: needsAddress
                  ? 'منطقة التوصيل والتواصل'.tr
                  : 'بيانات التواصل'.tr,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (needsAddress) ...[
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

  double _deliveryFeeForShop(String shopId, Map<String, CustomerShop> shopById) {
    if (!_isShopDeliveryFor(shopId)) return 0.0;
    return shopById[shopId]?.deliveryFee ?? 0.0;
  }

  double _computeTotalDeliveryFee(
    Map<String, List<CartItem>> itemsByShop,
    Map<String, CustomerShop> shopById,
  ) {
    var sum = 0.0;
    for (final shopId in itemsByShop.keys) {
      sum += _deliveryFeeForShop(shopId, shopById);
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

  Future<void> _submitOrder(
    List<PaymentMethod> activeMethods,
    Map<String, CustomerShop> shopById,
  ) async {
    final itemsByShop = ref.read(cartProvider.notifier).itemsByShop;
    if (itemsByShop.isEmpty) {
      showAppSnackBar(context, 'السلة فارغة'.tr, isError: true);
      return;
    }

    final needsAddress = _hasAnyShopDelivery(itemsByShop.keys);
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();
    final regions =
        ref.read(gazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;

    if (phone.isEmpty) {
      showAppSnackBar(context, 'يرجى إدخال رقم هاتف التواصل'.tr, isError: true);
      await _openAddressSheet(needsAddress: needsAddress);
      return;
    }

    if (needsAddress) {
      if (!isValidGazaRegionSelection(city, regions)) {
        showAppSnackBar(
          context,
          'يرجى اختيار منطقة التوصيل من قائمة قطاع غزة المعتمدة'.tr,
          isError: true,
        );
        await _openAddressSheet(needsAddress: true);
        return;
      }
      if (address.isEmpty) {
        showAppSnackBar(
          context,
          'يرجى إدخال العنوان التفصيلي للتوصيل'.tr,
          isError: true,
        );
        await _openAddressSheet(needsAddress: true);
        return;
      }
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

    final shopsCount = itemsByShop.length;
    final checkoutGroupId = shopsCount > 1 ? _generateUuidV4() : null;
    final subtotal = ref.read(cartProvider.notifier).totalAmount;
    final grandTotal =
        subtotal + _computeTotalDeliveryFee(itemsByShop, shopById);

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(customerRepositoryProvider);

      for (final entry in itemsByShop.entries) {
        final mode = _deliveryModeFor(entry.key);
        final shopAddress = mode == 'shop_delivery'
            ? '$city — $address'
            : 'توصيل من الزبون';
        await repo.placeOrder(
          shopId: entry.key,
          items: entry.value,
          deliveryAddress: shopAddress,
          phone: phone,
          notes: _notesController.text,
          deliveryMode: mode,
          paymentMethodId: selectedMethod.id,
          paymentReceiptUrl: _uploadedReceiptUrl!,
          checkoutGroupId: checkoutGroupId,
          groupTotal: grandTotal,
          groupShopsCount: shopsCount,
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
                    shopsCount > 1
                        ? (AppLang.isEn
                              ? '$shopsCount Orders Placed with One Transfer!'
                              : 'تم إرسال $shopsCount طلبات بحوالة واحدة بنجاح')
                        : 'تم إرسال طلبك وإشعار الحوالة بنجاح'.tr,
                    style: Theme.of(
                      ctx,
                    ).textTheme.titleLarge?.copyWith(fontWeight: AppFont.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    shopsCount > 1
                        ? 'تم تقسيم سلتك تلقائياً إلى شحنات مستقلة لكل متجر، وسيتم تأكيد الحوالة وتجهيز كل شحنة من محلها.'
                              .tr
                        : 'سيتم مراجعة إشعار الحوالة وتأكيده ليبدأ المتجر بتجهيز وشحن طلبك فوراً، وسيصلك إشعار بكل تحديث.'
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
    final shopById = <String, CustomerShop>{for (final s in shops) s.id: s};
    final shopEntries = itemsByShop.entries.toList();
    final isMultiShop = shopEntries.length > 1;
    final anyShopDelivery = _hasAnyShopDelivery(itemsByShop.keys);
    final activeDeliveryFee = _computeTotalDeliveryFee(itemsByShop, shopById);
    final grandTotal = subtotal + activeDeliveryFee;

    final shipments = [
      for (final entry in shopEntries)
        _ShopShipmentSummary(
          shopId: entry.key,
          shopName:
              shopById[entry.key]?.name ??
              (entry.value.isNotEmpty ? entry.value.first.shopName : 'متجر'.tr),
          shopCity: shopById[entry.key]?.city,
          items: entry.value,
          subtotal: entry.value.fold<double>(0, (s, i) => s + i.totalPrice),
          shopConfiguredDeliveryFee: shopById[entry.key]?.deliveryFee ?? 0.0,
          deliveryMode: _deliveryModeFor(entry.key),
        ),
    ];

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
        shipments: shipments,
        subtotal: subtotal,
        deliveryFee: activeDeliveryFee,
        grandTotal: grandTotal,
        hasAnyShopDelivery: anyShopDelivery,
        isSubmitting: _isSubmitting,
        canSubmit: canSubmit,
        onSubmit: () => _submitOrder(activeMethods, shopById),
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
            // 1) الشحنات وخيار التوصيل لكل محل (شحنة واحدة أو عدة شحنات مستقلة)
            // =================================================================
            if (!isMultiShop && shipments.length == 1) ...[
              Builder(
                builder: (_) {
                  final sh = shipments.first;
                  final shopDel = sh.isShopDelivery;
                  return Container(
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
                            selected: shopDel,
                            title: sh.shopConfiguredDeliveryFee > 0
                                ? '${'توصيل المحل'.tr} (${AppFormat.price(sh.shopConfiguredDeliveryFee)})'
                                : 'توصيل المحل'.tr,
                            onTap: _isSubmitting
                                ? null
                                : () {
                                    AppHaptics.selection();
                                    setState(
                                      () => _deliveryModeByShop[sh.shopId] =
                                          'shop_delivery',
                                    );
                                  },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _SegmentedDeliveryTab(
                            selected: !shopDel,
                            title: 'توصيل الزبون'.tr,
                            onTap: _isSubmitting
                                ? null
                                : () {
                                    AppHaptics.selection();
                                    setState(
                                      () => _deliveryModeByShop[sh.shopId] =
                                          'customer_pickup',
                                    );
                                  },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else if (isMultiShop) ...[
              Row(
                children: [
                  Expanded(
                    child: _CompactSectionTitle(
                      title: AppLang.isEn
                          ? 'Shipments by Shop (${shipments.length})'
                          : 'الشحنات حسب المحل (${shipments.length} متاجر)',
                    ),
                  ),
                  AppStatusBadge(
                    label: 'توصيل مستقل لكل محل'.tr,
                    tone: BadgeTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < shipments.length; i++) ...[
                _MultiShopShipmentCard(
                  index: i + 1,
                  totalShipments: shipments.length,
                  shipment: shipments[i],
                  disabled: _isSubmitting,
                  onModeChanged: (mode) {
                    AppHaptics.selection();
                    setState(
                      () => _deliveryModeByShop[shipments[i].shopId] = mode,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],

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
                  if (anyShopDelivery && cityText.isNotEmpty) cityText,
                  if (anyShopDelivery && addrText.isNotEmpty) addrText,
                  if (phoneText.isNotEmpty) phoneText,
                ];
                final summaryLine = summaryParts.isEmpty
                    ? (anyShopDelivery
                          ? 'اضغط لإدخال المنطقة والعنوان ورقم الهاتف'.tr
                          : 'اضغط لإدخال رقم هاتف التواصل'.tr)
                    : summaryParts.join(' · ');

                return AppCard(
                  padding: EdgeInsets.zero,
                  onTap: _isSubmitting
                      ? null
                      : () => _openAddressSheet(needsAddress: anyShopDelivery),
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
                            anyShopDelivery
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
                                anyShopDelivery
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
                  hintText: anyShopDelivery
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
                  if (isMultiShop) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.info,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              AppLang.isEn
                                  ? 'One combined transfer of ${AppFormat.price(grandTotal)} for ${shipments.length} shops — each shop ships independently.'
                                  : 'حوالة واحدة مجمّعة بقيمة ${AppFormat.price(grandTotal)} لـ ${shipments.length} متاجر — تصلك كل شحنة من محلها بشكل مستقل.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
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

class _ShopShipmentSummary {
  const _ShopShipmentSummary({
    required this.shopId,
    required this.shopName,
    this.shopCity,
    required this.items,
    required this.subtotal,
    required this.shopConfiguredDeliveryFee,
    required this.deliveryMode,
  });

  final String shopId;
  final String shopName;
  final String? shopCity;
  final List<CartItem> items;
  final double subtotal;
  final double shopConfiguredDeliveryFee;
  final String deliveryMode;

  bool get isShopDelivery => deliveryMode == 'shop_delivery';
  double get activeDeliveryFee =>
      isShopDelivery ? shopConfiguredDeliveryFee : 0.0;
  double get total => subtotal + activeDeliveryFee;
}

class _MultiShopShipmentCard extends StatelessWidget {
  const _MultiShopShipmentCard({
    required this.index,
    required this.totalShipments,
    required this.shipment,
    required this.disabled,
    required this.onModeChanged,
  });

  final int index;
  final int totalShipments;
  final _ShopShipmentSummary shipment;
  final bool disabled;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final city = shipment.shopCity?.trim();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  AppLang.isEn
                      ? 'Shipment $index/$totalShipments'
                      : 'شحنة $index من $totalShipments',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: AppFont.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  shipment.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (city != null && city.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(AppIcons.location, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 2),
                Text(
                  city,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          for (final item in shipment.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.productName} (${item.variantDescription}) × ${item.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    AppFormat.price(item.totalPrice),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFont.semiBold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentedDeliveryTab(
                    selected: shipment.isShopDelivery,
                    title: shipment.shopConfiguredDeliveryFee > 0
                        ? '${'توصيل المحل'.tr} (${AppFormat.price(shipment.shopConfiguredDeliveryFee)})'
                        : '${'توصيل المحل'.tr} (${'مجاناً'.tr})',
                    onTap: disabled ? null : () => onModeChanged('shop_delivery'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _SegmentedDeliveryTab(
                    selected: !shipment.isShopDelivery,
                    title: '${'توصيل الزبون'.tr} (${'مجاناً'.tr})',
                    onTap:
                        disabled ? null : () => onModeChanged('customer_pickup'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجمالي هذه الشحنة'.tr,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              Text(
                AppFormat.price(shipment.total),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.extraBold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutStickyFooter extends StatelessWidget {
  const _CheckoutStickyFooter({
    required this.items,
    required this.shipments,
    required this.subtotal,
    required this.deliveryFee,
    required this.grandTotal,
    required this.hasAnyShopDelivery,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  final List<CartItem> items;
  final List<_ShopShipmentSummary> shipments;
  final double subtotal;
  final double deliveryFee;
  final double grandTotal;
  final bool hasAnyShopDelivery;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isMultiShop = shipments.length > 1;
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
                if (isMultiShop) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 62),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: shipments.map((sh) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${sh.shopName} (${sh.isShopDelivery ? 'توصيل المحل'.tr : 'توصيل الزبون'.tr})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  AppFormat.price(sh.total),
                                  style: TextStyle(
                                    fontSize: 12,
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
                  const Divider(height: 10),
                ] else if (items.isNotEmpty) ...[
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
                if (hasAnyShopDelivery) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isMultiShop
                            ? 'إجمالي رسوم التوصيل (${shipments.where((s) => s.isShopDelivery).length} متاجر)'
                                  .tr
                            : 'رسوم التوصيل (من المحل)'.tr,
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
                        isMultiShop
                            ? 'المبلغ المطلوب تحويله (حوالة واحدة)'.tr
                            : 'المبلغ المطلوب تحويله'.tr,
                        style: TextStyle(
                          fontSize: 13,
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
