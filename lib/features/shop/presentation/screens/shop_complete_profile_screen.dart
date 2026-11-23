import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/payment_method.dart';
import '../../../admin/domain/models/subscription_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_providers.dart';
import '../widgets/product_form_steps.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';
import '../widgets/subscription_payment_section.dart';

class ShopCompleteProfileScreen extends ConsumerStatefulWidget {
  const ShopCompleteProfileScreen({super.key});

  @override
  ConsumerState<ShopCompleteProfileScreen> createState() =>
      _ShopCompleteProfileScreenState();
}

class _ShopCompleteProfileScreenState
    extends ConsumerState<ShopCompleteProfileScreen> {
  static List<String> get _stepLabels => [
    'المتجر'.tr,
    'المالك'.tr,
    'الهوية'.tr,
    'الباقة'.tr,
    'التحويل'.tr,
    'الإرسال'.tr,
  ];

  final _shopFormKey = GlobalKey<FormState>();
  final _ownerFormKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  late final TextEditingController _shopNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _registerController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _subscriptionNotesController;

  int _step = 0;
  var _seeded = false;
  var _visitedIdentity = false;

  SubscriptionPlan? _selectedPlan;
  String? _selectedPlanId;
  PaymentMethod? _selectedPaymentMethod;
  String? _selectedPaymentMethodId;
  PickedBytes? _pickedReceipt;
  var _uploadingReceipt = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _shopNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _cityController = TextEditingController(text: user?.city ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _registerController = TextEditingController();
    _ownerNameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _subscriptionNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shopNameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _registerController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _subscriptionNotesController.dispose();
    super.dispose();
  }

  void _seedFromShop(Shop shop) {
    if (_seeded) return;
    _seeded = true;
    if (_shopNameController.text.isEmpty) {
      _shopNameController.text = shop.name;
    }
    if (_descriptionController.text.isEmpty) {
      _descriptionController.text = shop.description ?? '';
    }
    if (_cityController.text.isEmpty) {
      _cityController.text = shop.city ?? '';
    }
    if (_addressController.text.isEmpty) {
      _addressController.text = shop.address ?? '';
    }
    if (_registerController.text.isEmpty) {
      _registerController.text = shop.commercialRegister ?? '';
    }
    if (_selectedPlanId == null && shop.subscriptionPlanId != null) {
      _selectedPlanId = shop.subscriptionPlanId;
    }
  }

  int _completedShopFieldsCount() {
    final fields = [
      _shopNameController.text,
      _descriptionController.text,
      _cityController.text,
      _addressController.text,
      _registerController.text,
    ];
    return fields.where((f) => f.trim().isNotEmpty).length;
  }

  int _completedOwnerFieldsCount() {
    final fields = [_ownerNameController.text, _phoneController.text];
    return fields.where((f) => f.trim().isNotEmpty).length;
  }

  bool _hasReceipt(Shop? shop) =>
      _pickedReceipt != null ||
      (shop?.subscriptionReceiptUrl?.trim().isNotEmpty ?? false);

  List<double> _stepProgress(Shop? shop) {
    final shopRatio = _completedShopFieldsCount() / 5.0;
    final ownerRatio = _completedOwnerFieldsCount() / 2.0;
    final identityDone =
        _visitedIdentity ||
        (shop?.logoPath?.trim().isNotEmpty ?? false) ||
        (shop?.coverPath?.trim().isNotEmpty ?? false);
    final planDone = _selectedPlanId != null && _selectedPlanId!.isNotEmpty;
    final transferRatio =
        ((_selectedPaymentMethodId != null &&
                _selectedPaymentMethodId!.isNotEmpty)
            ? 0.5
            : 0.0) +
        (_hasReceipt(shop) ? 0.5 : 0.0);
    final readyToSend =
        shopRatio >= 1.0 &&
        ownerRatio >= 1.0 &&
        planDone &&
        transferRatio >= 1.0;

    return [
      shopRatio,
      ownerRatio,
      identityDone ? 1.0 : (_step > 2 ? 1.0 : 0.0),
      planDone ? 1.0 : 0.0,
      transferRatio,
      (_step == 5 && readyToSend) ? 1.0 : 0.0,
    ];
  }

  String? _validateStep(int index, Shop? shop) {
    switch (index) {
      case 0:
        if (_shopFormKey.currentState != null &&
            !_shopFormKey.currentState!.validate()) {
          return 'يرجى إكمال جميع الحقول المطلوبة في معلومات المتجر'.tr;
        }
        if (_completedShopFieldsCount() < 5) {
          return 'يرجى إكمال جميع الحقول المطلوبة في معلومات المتجر'.tr;
        }
        return null;
      case 1:
        if (_ownerFormKey.currentState != null &&
            !_ownerFormKey.currentState!.validate()) {
          return 'يرجى إدخال اسم صاحب المحل ورقم الهاتف بشكل صحيح'.tr;
        }
        if (_completedOwnerFieldsCount() < 2) {
          return 'يرجى إدخال اسم صاحب المحل ورقم الهاتف بشكل صحيح'.tr;
        }
        return null;
      case 2:
        // Logo, cover & documents are optional during signup
        return null;
      case 3:
        if (_selectedPlanId == null || _selectedPlanId!.isEmpty) {
          return 'يرجى اختيار باقة الاشتراك للمتابعة'.tr;
        }
        return null;
      case 4:
        if (_selectedPaymentMethodId == null ||
            _selectedPaymentMethodId!.isEmpty) {
          return 'يرجى اختيار حساب التحويل أولاً'.tr;
        }
        if (!_hasReceipt(shop)) {
          return 'يرجى إرفاق صورة إشعار تحويل الاشتراك قبل المتابعة'.tr;
        }
        return null;
      default:
        return null;
    }
  }

  void _goToStep(int target, Shop? shop) {
    FocusScope.of(context).unfocus();
    if (target > _step) {
      for (var i = _step; i < target; i++) {
        final err = _validateStep(i, shop);
        if (err != null) {
          if (i != _step) setState(() => _step = i);
          showAppSnackBar(context, err, isError: true);
          return;
        }
      }
    }
    setState(() {
      if (_step == 2 || target > 2) _visitedIdentity = true;
      _step = target.clamp(0, _stepLabels.length - 1);
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _saveDraftOnly() async {
    if (ref.read(shopActionProvider).isLoading || _uploadingReceipt) return;
    FocusScope.of(context).unfocus();
    if (_step == 0 && _shopFormKey.currentState?.validate() != true) return;
    if (_step == 1 && _ownerFormKey.currentState?.validate() != true) return;
    if (_completedShopFieldsCount() < 5 || _completedOwnerFieldsCount() < 2) {
      showAppSnackBar(
        context,
        'أكمل بيانات المحل والمالك المطلوبة لحفظ المسودة'.tr,
        isError: true,
      );
      return;
    }

    final actions = ref.read(shopActionProvider.notifier);
    final saved = await actions.completeProfile(
      shopName: _shopNameController.text,
      description: _descriptionController.text,
      city: _cityController.text,
      address: _addressController.text,
      commercialRegister: _registerController.text,
      ownerName: _ownerNameController.text,
      phone: _phoneController.text,
    );
    if (!mounted) return;
    if (!saved) {
      final error = ref.read(shopActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر حفظ البيانات'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم حفظ بيانات المتجر كمسودة بنجاح'.tr);
  }

  Future<void> _nextFromStep(Shop? shop) async {
    final err = _validateStep(_step, shop);
    if (err != null) {
      showAppSnackBar(context, err, isError: true);
      return;
    }
    // When leaving Step 1 (Owner info) into Step 2 (Identity), save draft shop
    // so logo/cover/document uploads immediately have a valid shop record.
    if (_step == 1 && (shop == null || !shop.isProfileReady)) {
      final actions = ref.read(shopActionProvider.notifier);
      await actions.completeProfile(
        shopName: _shopNameController.text,
        description: _descriptionController.text,
        city: _cityController.text,
        address: _addressController.text,
        commercialRegister: _registerController.text,
        ownerName: _ownerNameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
    }
    _goToStep(_step + 1, shop);
  }

  Future<void> _submitAll(Shop? shop) async {
    if (ref.read(shopActionProvider).isLoading || _uploadingReceipt) return;
    FocusScope.of(context).unfocus();

    for (var i = 0; i < 5; i++) {
      final err = _validateStep(i, shop);
      if (err != null) {
        setState(() => _step = i);
        showAppSnackBar(context, err, isError: true);
        return;
      }
    }

    final actions = ref.read(shopActionProvider.notifier);
    String receiptUrl = shop?.subscriptionReceiptUrl?.trim() ?? '';
    if (_pickedReceipt != null) {
      setState(() => _uploadingReceipt = true);
      try {
        receiptUrl = await ref
            .read(shopRepositoryProvider)
            .uploadSubscriptionReceipt(
              bytes: _pickedReceipt!.bytes,
              fileName: _pickedReceipt!.fileName,
              contentType: _pickedReceipt!.contentType,
            );
      } catch (error) {
        if (mounted) {
          setState(() => _uploadingReceipt = false);
          showAppSnackBar(
            context,
            actions.errorMessage(error),
            isError: true,
          );
        }
        return;
      }
      if (mounted) setState(() => _uploadingReceipt = false);
    }

    if (receiptUrl.isEmpty) {
      if (mounted) {
        setState(() => _step = 4);
        showAppSnackBar(
          context,
          'يرجى إرفاق صورة إشعار تحويل الاشتراك قبل إرسال الطلب'.tr,
          isError: true,
        );
      }
      return;
    }

    final submitted = await actions.saveAndSubmitProfileWithSubscription(
      shopName: _shopNameController.text,
      description: _descriptionController.text,
      city: _cityController.text,
      address: _addressController.text,
      commercialRegister: _registerController.text,
      ownerName: _ownerNameController.text,
      phone: _phoneController.text,
      planId: _selectedPlanId!,
      paymentMethodId: _selectedPaymentMethodId!,
      receiptUrl: receiptUrl,
      notes: _subscriptionNotesController.text,
    );
    if (!mounted) return;
    if (!submitted) {
      final error = ref.read(shopActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر إرسال الطلب'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }

    showAppSnackBar(
      context,
      'تم إرسال طلب اعتماد المتجر وإشعار الاشتراك للإدارة'.tr,
    );
    context.go(AppRoutes.shopStatus);
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(myShopProvider);
    final isLoading =
        ref.watch(shopActionProvider).isLoading || _uploadingReceipt;
    final shop = shopAsync.asData?.value;
    final canEdit = (shop?.canEdit ?? true) && !isLoading;
    final lastStep = _stepLabels.length - 1;

    return ShopScaffold(
      title: 'فتح متجر جديد'.tr,
      showBack: false,
      showBottomNav: false,
      showNotifications: false,
      actions: [
        if (_step == 0 || _step == 1)
          TextButton(
            onPressed: canEdit ? _saveDraftOnly : null,
            child: Text(
              'حفظ مسودة'.tr,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: AppFont.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        IconButton(
          tooltip: 'تسجيل الخروج'.tr,
          onPressed: () => confirmShopLogout(context, ref),
          icon: Icon(AppIcons.logout, color: AppBarDesign.iconColor),
        ),
      ],
      body: shopAsync.skeletonWhen(
        placeholder: LoadingFixtures.shop,
        skipLoadingOnReload: true,
        error: (error, _) => ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل بيانات المحل'.tr,
              message: ref.read(shopRepositoryProvider).mapError(error),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة'.tr,
              onAction: () => ref.invalidate(myShopProvider),
            ),
          ],
        ),
        data: (shop) {
          final isPlaceholder =
              shop != null && shop.id == LoadingFixtures.shop.id;
          if (shop != null && !isPlaceholder) _seedFromShop(shop);
          final progress = _stepProgress(shop);

          return Column(
            children: [
              // Compact sticky step bar pinned at top
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: ProductFormSteps(
                  labels: _stepLabels,
                  progress: progress,
                  current: _step,
                  compact: true,
                  onSelected: (i) => _goToStep(i, shop),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: AppSpacing.page,
                  children: [
                    if (shop?.visibleRejectionReason != null) ...[
                      ShopNoticeBanner(
                        title: 'سبب رفض الطلب السابق'.tr,
                        message: shop!.visibleRejectionReason!,
                        tone: BadgeTone.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Active Step Content
                    switch (_step) {
                      0 => _buildStep1ShopInfo(context, isPlaceholder, canEdit),
                      1 => _buildStep2OwnerInfo(
                        context,
                        isPlaceholder,
                        canEdit,
                      ),
                      2 => _buildStep3Identity(context, shop, canEdit),
                      3 => _buildStep4Plan(context, canEdit),
                      4 => _buildStep5Transfer(context, shop, canEdit),
                      _ => _buildStep6Review(context, shop),
                    },

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: AppButton(
                label: 'السابق'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: isLoading ? null : () => _goToStep(_step - 1, shop),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              label: _step == lastStep
                  ? 'تأكيد وإرسال الطلب'.tr
                  : '${'التالي'.tr}: ${_stepLabels[_step + 1]}',
              isLoading: isLoading,
              onPressed: !canEdit
                  ? null
                  : (_step == lastStep
                        ? () => _submitAll(shop)
                        : () => _nextFromStep(shop)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1ShopInfo(
    BuildContext context,
    bool isPlaceholder,
    bool canEdit,
  ) {
    return Form(
      key: isPlaceholder ? null : _shopFormKey,
      child: ShopDetailsFormFields(
        shopNameController: _shopNameController,
        descriptionController: _descriptionController,
        cityController: _cityController,
        addressController: _addressController,
        registerController: _registerController,
        ownerNameController: _ownerNameController,
        phoneController: _phoneController,
        enabled: canEdit,
        showShopInfo: true,
        showOwnerInfo: false,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Widget _buildStep2OwnerInfo(
    BuildContext context,
    bool isPlaceholder,
    bool canEdit,
  ) {
    return Form(
      key: isPlaceholder ? null : _ownerFormKey,
      child: ShopDetailsFormFields(
        shopNameController: _shopNameController,
        descriptionController: _descriptionController,
        cityController: _cityController,
        addressController: _addressController,
        registerController: _registerController,
        ownerNameController: _ownerNameController,
        phoneController: _phoneController,
        enabled: canEdit,
        showShopInfo: false,
        showOwnerInfo: true,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Widget _buildStep3Identity(BuildContext context, Shop? shop, bool canEdit) {
    return ShopMediaManagerCard(shop: shop, canEdit: canEdit);
  }

  Widget _buildStep4Plan(BuildContext context, bool canEdit) {
    return SubscriptionPlanPicker(
      selectedPlanId: _selectedPlanId,
      enabled: canEdit,
      onPlanSelected: (plan) => setState(() {
        _selectedPlan = plan;
        _selectedPlanId = plan.id;
      }),
    );
  }

  Widget _buildStep5Transfer(BuildContext context, Shop? shop, bool canEdit) {
    final planName = _selectedPlan?.displayName ?? shop?.subscriptionPlanName;
    final planPrice = _selectedPlan?.price ?? shop?.subscriptionPrice ?? 0;
    final hasReceipt = _hasReceipt(shop);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exact same header row as Customer Checkout
        Row(
          children: [
            Expanded(
              child: Text(
                'الدفع وإشعار الحوالة'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
              ),
            ),
            AppStatusBadge(
              label: hasReceipt ? 'تم الرفع'.tr : 'مطلوب'.tr,
              tone: hasReceipt ? BadgeTone.success : BadgeTone.warning,
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Single unified card matching Customer Checkout (amount bar + bank/wallet chips + selected account + receipt uploader)
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          borderColor: hasReceipt
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (planName != null && planName.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CheckoutDesign.optionSelectedBackground,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${'المبلغ المطلوب تحويله'.tr} ($planName)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: AppFont.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        AppFormat.price(planPrice),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: AppFont.extraBold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AdminPaymentAccountsPicker(
                selectedPaymentMethodId: _selectedPaymentMethodId,
                enabled: canEdit,
                onPaymentMethodSelected: (pm) => setState(() {
                  _selectedPaymentMethod = pm;
                  _selectedPaymentMethodId = pm.id;
                }),
              ),
              const Divider(height: AppSpacing.md),
              TransferReceiptUploader(
                pickedReceiptBytes: _pickedReceipt?.bytes,
                pickedReceiptName: _pickedReceipt?.fileName,
                existingReceiptUrl: shop?.subscriptionReceiptUrl,
                onReceiptPicked: (picked) =>
                    setState(() => _pickedReceipt = picked),
                onReceiptCleared: () => setState(() => _pickedReceipt = null),
                notesController: _subscriptionNotesController,
                enabled: canEdit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep6Review(BuildContext context, Shop? shop) {
    final planName =
        _selectedPlan?.displayName ?? shop?.subscriptionPlanName ?? '-';
    final planPrice = _selectedPlan?.price ?? shop?.subscriptionPrice ?? 0;
    final planDuration = _selectedPlan?.durationLabel ?? '';
    final pmName =
        _selectedPaymentMethod?.displayName ??
        shop?.subscriptionPaymentMethodName ??
        '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) Shop Details Summary
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'بيانات المتجر'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _goToStep(0, shop),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('تعديل'.tr),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.sm),
              _ReviewLine(label: 'اسم المحل'.tr, value: _shopNameController.text),
              _ReviewLine(label: 'المدينة'.tr, value: _cityController.text),
              _ReviewLine(label: 'العنوان'.tr, value: _addressController.text),
              _ReviewLine(
                label: 'السجل التجاري'.tr,
                value: _registerController.text,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 2) Owner & Contact Summary
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'بيانات المالك والتواصل'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _goToStep(1, shop),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('تعديل'.tr),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.sm),
              _ReviewLine(
                label: 'اسم صاحب المحل'.tr,
                value: _ownerNameController.text,
              ),
              _ReviewLine(label: 'رقم الهاتف'.tr, value: _phoneController.text),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 3) Subscription & Transfer Summary
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'الاشتراك وإشعار التحويل'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _goToStep(4, shop),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('تعديل'.tr),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.sm),
              _ReviewLine(
                label: 'الباقة'.tr,
                value: planDuration.isNotEmpty
                    ? '$planName ($planDuration)'
                    : planName,
              ),
              _ReviewLine(
                label: 'قيمة الاشتراك'.tr,
                value: AppFormat.price(planPrice),
                highlight: true,
              ),
              _ReviewLine(label: 'العمولة على المبيعات'.tr, value: '0%'.tr),
              _ReviewLine(label: 'تم التحويل إلى'.tr, value: pmName),
              if (_pickedReceipt != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: Image.memory(
                      _pickedReceipt!.bytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              ] else if (shop?.subscriptionReceiptUrl?.trim().isNotEmpty ??
                  false) ...[
                const SizedBox(height: AppSpacing.xs),
                ReceiptThumbnailCard(
                  imageUrl: shop!.subscriptionReceiptUrl!.trim(),
                  subtitle: 'إشعار تحويل الاشتراك'.tr,
                  height: 150,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 3) What happens next guide
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ماذا يحدث بعد إرسال الطلب؟'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              _NextInfoRow(
                number: '1',
                text: 'يصل طلب متجرك مع صورة إشعار التحويل مباشرة للإدارة.'.tr,
              ),
              _NextInfoRow(
                number: '2',
                text:
                    'تتحقق الإدارة من الإشعار وتعتمد المتجر وتفعّل باقتك فوراً.'
                        .tr,
              ),
              _NextInfoRow(
                number: '3',
                text:
                    'يُفتح متجرك وتبدأ بنشر منتجاتك ومتابعة كشفك المالي الكامل (100% بدون عمولة).'
                        .tr,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 3,
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: highlight ? AppFont.extraBold : AppFont.semiBold,
                color: highlight ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextInfoRow extends StatelessWidget {
  const _NextInfoRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: AppFont.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
