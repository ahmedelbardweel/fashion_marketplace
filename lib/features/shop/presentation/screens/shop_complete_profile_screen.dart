import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopCompleteProfileScreen extends ConsumerStatefulWidget {
  const ShopCompleteProfileScreen({super.key});

  @override
  ConsumerState<ShopCompleteProfileScreen> createState() =>
      _ShopCompleteProfileScreenState();
}

class _ShopCompleteProfileScreenState
    extends ConsumerState<ShopCompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _registerController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  var _seeded = false;

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
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _registerController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
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
  }

  int _completedFieldsCount() {
    final fields = [
      _shopNameController.text,
      _descriptionController.text,
      _cityController.text,
      _addressController.text,
      _registerController.text,
      _ownerNameController.text,
      _phoneController.text,
    ];
    return fields.where((f) => f.trim().isNotEmpty).length;
  }

  Future<void> _save({required bool submit}) async {
    if (ref.read(shopActionProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final actions = ref.read(shopActionProvider.notifier);

    if (!submit) {
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
      showAppSnackBar(context, 'تم حفظ البيانات'.tr);
      return;
    }

    final submitted = await actions.saveAndSubmitProfile(
      shopName: _shopNameController.text,
      description: _descriptionController.text,
      city: _cityController.text,
      address: _addressController.text,
      commercialRegister: _registerController.text,
      ownerName: _ownerNameController.text,
      phone: _phoneController.text,
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

    showAppSnackBar(context, 'تم إرسال طلب الانضمام للإدارة'.tr);
    context.go(AppRoutes.shopStatus);
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(myShopProvider);
    final isLoading = ref.watch(shopActionProvider).isLoading;
    final shop = shopAsync.asData?.value;
    final canEdit = (shop?.canEdit ?? true) && !isLoading;

    return ShopScaffold(
      title: 'استكمال بيانات المحل'.tr,
      showBack: false,
      showBottomNav: false,
      showNotifications: false,
      actions: [
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
          final completed = _completedFieldsCount();
          final progress = completed / 7;

          return Form(
            key: isPlaceholder ? null : _formKey,
            child: ListView(
              padding: AppSpacing.page,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'اكتمال ملف المتجر'.tr,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: AppFont.bold),
                            ),
                          ),
                          AppStatusBadge(
                            label: '$completed / 7',
                            tone: completed == 7
                                ? BadgeTone.success
                                : BadgeTone.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ShopProgressBar(
                        value: progress,
                        color: completed == 7
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        completed == 7
                            ? 'جميع الحقول المطلوبة مكتملة، يمكنك إرسال الطلب للمراجعة الآن.'
                                  .tr
                            : 'أكمل جميع الحقول المطلوبة ثم أرسل طلب الانضمام لمراجعة الإدارة.'
                                  .tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (shop?.visibleRejectionReason != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ShopNoticeBanner(
                    title: 'سبب رفض الطلب السابق'.tr,
                    message: shop!.visibleRejectionReason!,
                    tone: BadgeTone.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ShopDetailsFormFields(
                  shopNameController: _shopNameController,
                  descriptionController: _descriptionController,
                  cityController: _cityController,
                  addressController: _addressController,
                  registerController: _registerController,
                  ownerNameController: _ownerNameController,
                  phoneController: _phoneController,
                  enabled: canEdit,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                ShopMediaManagerCard(shop: shop, canEdit: canEdit),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          );
        },
      ),
      bottom: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'حفظ مسودة'.tr,
              variant: AppButtonVariant.secondary,
              isLoading: isLoading,
              onPressed: canEdit ? () => _save(submit: false) : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: AppButton(
              label: 'حفظ وإرسال للمراجعة'.tr,
              isLoading: isLoading,
              onPressed: canEdit ? () => _save(submit: true) : null,
            ),
          ),
        ],
      ),
    );
  }
}
