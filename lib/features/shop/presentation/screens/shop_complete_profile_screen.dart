import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
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
  var _uploading = false;

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

  void _seedFromShop() {
    if (_seeded) return;
    final shop = ref.read(myShopProvider).asData?.value;
    if (shop == null) return;
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

  Future<void> _save({required bool submit}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

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
        error == null ? 'تعذر حفظ البيانات' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }

    if (!submit) {
      showAppSnackBar(context, 'تم حفظ البيانات');
      return;
    }

    final submitted = await actions.submitApplication();
    if (!mounted) return;
    if (!submitted) {
      final error = ref.read(shopActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر إرسال الطلب' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }

    showAppSnackBar(context, 'تم إرسال طلب الانضمام للإدارة');
  }

  Future<void> _uploadLogo() async {
    final picked = await MediaPicker.pickImage();
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(shopStorageRepositoryProvider).uploadBytes(
            bucket: 'shop-media',
            folder: 'logo',
            fileName: picked.fileName,
            bytes: picked.bytes,
            contentType: picked.contentType,
          );
      final ok =
          await ref.read(shopCatalogActionProvider.notifier).setLogo(url);
      if (!mounted) return;
      showAppSnackBar(context, ok ? 'تم رفع الشعار' : 'تعذر رفع الشعار',
          isError: !ok);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(shopStorageRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadCover() async {
    final picked = await MediaPicker.pickImage();
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(shopStorageRepositoryProvider).uploadBytes(
            bucket: 'shop-media',
            folder: 'cover',
            fileName: picked.fileName,
            bytes: picked.bytes,
            contentType: picked.contentType,
          );
      final ok =
          await ref.read(shopCatalogActionProvider.notifier).setCover(url);
      if (!mounted) return;
      showAppSnackBar(
        context,
        ok ? 'تم رفع صورة الغلاف' : 'تعذر رفع صورة الغلاف',
        isError: !ok,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(shopStorageRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadGallery() async {
    final picked = await MediaPicker.pickImage();
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(shopStorageRepositoryProvider).uploadBytes(
            bucket: 'shop-media',
            folder: 'gallery',
            fileName: picked.fileName,
            bytes: picked.bytes,
            contentType: picked.contentType,
          );
      final ok =
          await ref.read(shopCatalogActionProvider.notifier).addShopImage(url);
      if (!mounted) return;
      showAppSnackBar(
        context,
        ok ? 'تم رفع صورة المحل' : 'تعذر رفع الصورة',
        isError: !ok,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(shopStorageRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadDocument() async {
    final picked = await MediaPicker.pickDocument();
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final path = await ref.read(shopStorageRepositoryProvider).uploadBytes(
            bucket: 'shop-documents',
            folder: 'docs',
            fileName: picked.fileName,
            bytes: picked.bytes,
            contentType: picked.contentType,
          );
      final ok = await ref.read(shopCatalogActionProvider.notifier).addDocument(
            docType: 'إثبات محل',
            path: path,
          );
      if (!mounted) return;
      showAppSnackBar(context, ok ? 'تم رفع المستند' : 'تعذر رفع المستند',
          isError: !ok);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(shopStorageRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myShopProvider, (_, __) => _seedFromShop());
    final shopAsync = ref.watch(myShopProvider);
    final docs = ref.watch(shopDocumentsProvider).asData?.value ?? [];
    final images = ref.watch(shopImagesProvider).asData?.value ?? [];
    final busy = ref.watch(shopActionProvider).isLoading ||
        ref.watch(shopCatalogActionProvider).isLoading ||
        _uploading;

    WidgetsBinding.instance.addPostFrameCallback((_) => _seedFromShop());

    return ShopScaffold(
      title: 'بيانات المحل',
      showBack: false,
      showBottomNav: false,
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: AppSpacing.page,
            child: Text(ref.read(shopRepositoryProvider).mapError(error)),
          ),
        ),
        data: (shop) {
          return SingleChildScrollView(
            padding: AppSpacing.page,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'أكمل بيانات المحل',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'ارفع الشعار والمستندات ثم أرسل طلب الانضمام للإدارة.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const AppCard(
                    child: Text(
                      'لا يمكن إضافة منتجات أو نشرها قبل موافقة الإدارة.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _shopNameController,
                    label: 'اسم المحل',
                    validator: Validators.shopName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _descriptionController,
                    label: 'وصف المحل',
                    maxLines: 3,
                    validator: (value) =>
                        Validators.required(value, field: 'وصف المحل'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _cityController,
                    label: 'المدينة',
                    validator: (value) =>
                        Validators.required(value, field: 'المدينة'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _addressController,
                    label: 'عنوان المحل',
                    validator: (value) =>
                        Validators.required(value, field: 'عنوان المحل'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _registerController,
                    label: 'رقم السجل التجاري',
                    validator: (value) => Validators.required(
                      value,
                      field: 'رقم السجل التجاري',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _ownerNameController,
                    label: 'اسم المسؤول',
                    validator: Validators.fullName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'رفع الشعار',
                    variant: AppButtonVariant.outlined,
                    isLoading: _uploading,
                    onPressed: _uploadLogo,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'رفع صورة الغلاف',
                    variant: AppButtonVariant.outlined,
                    isLoading: _uploading,
                    onPressed: _uploadCover,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'رفع صور المحل',
                    variant: AppButtonVariant.outlined,
                    isLoading: _uploading,
                    onPressed: _uploadGallery,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'رفع مستند إثبات',
                    variant: AppButtonVariant.outlined,
                    isLoading: _uploading,
                    onPressed: _uploadDocument,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'صور: ${images.length} · مستندات: ${docs.length}${shop?.logoPath == null ? '' : ' · الشعار مرفوع'}',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'حفظ كمسودة',
                    variant: AppButtonVariant.outlined,
                    isLoading: busy,
                    onPressed: () => _save(submit: false),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'إرسال طلب الانضمام',
                    isLoading: busy,
                    onPressed: () => _save(submit: true),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'تسجيل الخروج',
                    variant: AppButtonVariant.outlined,
                    onPressed: () => confirmShopLogout(context, ref),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
