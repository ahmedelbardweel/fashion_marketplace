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
import '../../domain/models/shop.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopName;
  late final TextEditingController _description;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _register;
  late final TextEditingController _ownerName;
  late final TextEditingController _phone;
  var _seeded = false;
  var _uploading = false;

  @override
  void initState() {
    super.initState();
    _shopName = TextEditingController();
    _description = TextEditingController();
    _city = TextEditingController();
    _address = TextEditingController();
    _register = TextEditingController();
    _ownerName = TextEditingController();
    _phone = TextEditingController();
  }

  @override
  void dispose() {
    _shopName.dispose();
    _description.dispose();
    _city.dispose();
    _address.dispose();
    _register.dispose();
    _ownerName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seed(Shop? shop) {
    if (_seeded || shop == null) return;
    _seeded = true;
    _shopName.text = shop.name;
    _description.text = shop.description ?? '';
    _city.text = shop.city ?? '';
    _address.text = shop.address ?? '';
    _register.text = shop.commercialRegister ?? '';
    final user = ref.read(authControllerProvider).user;
    _ownerName.text = shop.ownerName ?? user?.fullName ?? '';
    _phone.text = shop.ownerPhone ?? user?.phone ?? '';
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
      showAppSnackBar(
        context,
        ok ? 'تم تحديث الشعار' : 'تعذر تحديث الشعار',
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
        ok ? 'تم تحديث صورة الغلاف' : 'تعذر التحديث',
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
        ok ? 'تم رفع صورة المحل' : 'تعذر الرفع',
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
      showAppSnackBar(
        context,
        ok ? 'تم رفع المستند' : 'تعذر رفع المستند',
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.updateProfile(
      shopName: _shopName.text,
      description: _description.text,
      city: _city.text,
      address: _address.text,
      commercialRegister: _register.text,
      ownerName: _ownerName.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر الحفظ' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث ملف المحل');
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(myShopProvider);
    final images = ref.watch(shopImagesProvider).asData?.value ?? [];
    final docs = ref.watch(shopDocumentsProvider).asData?.value ?? [];
    final busy =
        ref.watch(shopCatalogActionProvider).isLoading || _uploading;

    ref.listen(myShopProvider, (_, next) => _seed(next.asData?.value));
    _seed(shopAsync.asData?.value);

    return ShopScaffold(
      title: 'ملف المحل',
      showBack: false,
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(ref.read(shopRepositoryProvider).mapError(error)),
        ),
        data: (shop) {
          return SingleChildScrollView(
            padding: AppSpacing.page,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحالة: ${shop?.visibleStatus.labelAr ?? '-'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (shop?.logoPath != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text('الشعار مرفوع',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                  Text('صور مرفوعة: ${images.length} · مستندات: ${docs.length}'),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _shopName,
                    label: 'اسم المحل',
                    validator: Validators.shopName,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _description,
                    label: 'الوصف',
                    maxLines: 3,
                    validator: (value) =>
                        Validators.required(value, field: 'الوصف'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _city,
                    label: 'المدينة',
                    validator: (value) =>
                        Validators.required(value, field: 'المدينة'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _address,
                    label: 'العنوان',
                    validator: (value) =>
                        Validators.required(value, field: 'العنوان'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _register,
                    label: 'السجل التجاري',
                    validator: (value) => Validators.required(
                      value,
                      field: 'السجل التجاري',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _ownerName,
                    label: 'اسم المسؤول',
                    validator: Validators.fullName,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phone,
                    label: 'الهاتف',
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'حفظ التعديلات',
                    isLoading: busy,
                    onPressed: _save,
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
