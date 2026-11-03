import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/background_removal_service.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/shop_shell.dart';

class _VariantDraft {
  _VariantDraft({
    required this.color,
    required this.size,
    required this.stock,
  });

  String color;
  String size;
  int stock;
}

class _ImageDraft {
  _ImageDraft({required this.path, required this.kind});

  final String path;
  final String kind;
}

class ShopProductFormScreen extends ConsumerStatefulWidget {
  const ShopProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ShopProductFormScreen> createState() =>
      _ShopProductFormScreenState();
}

class _ShopProductFormScreenState extends ConsumerState<ShopProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _colorController = TextEditingController();
  final _sizeController = TextEditingController();
  final _stockController = TextEditingController(text: '0');

  String? _categoryId;
  String _status = 'draft';
  final _variants = <_VariantDraft>[];
  final _newImages = <_ImageDraft>[];
  var _seeded = false;
  var _uploading = false;
  var _removeBg = false;
  String? _uploadStatusText;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _seed() {
    if (_seeded || widget.productId == null) return;
    final product =
        ref.read(shopProductProvider(widget.productId!)).asData?.value;
    if (product == null) return;
    _seeded = true;
    _nameController.text = product.name;
    _descController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    _categoryId = product.categoryId;
    _status = product.status == 'deleted' ? 'draft' : product.status;
    _variants
      ..clear()
      ..addAll(
        product.variants.map(
          (item) => _VariantDraft(
            color: item.color,
            size: item.size,
            stock: item.stock,
          ),
        ),
      );
    setState(() {});
  }

  void _addVariant() {
    final color = _colorController.text.trim();
    final size = _sizeController.text.trim();
    final stock = int.tryParse(_stockController.text.trim()) ?? -1;
    if (color.isEmpty || size.isEmpty || stock < 0) {
      showAppSnackBar(context, 'أدخل لوناً ومقاساً ومخزوناً صالحاً', isError: true);
      return;
    }
    setState(() {
      _variants.add(_VariantDraft(color: color, size: size, stock: stock));
      _colorController.clear();
      _sizeController.clear();
      _stockController.text = '0';
    });
  }

  Future<void> _uploadImage({required String kind}) async {
    final picked = await MediaPicker.pickImage();
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _uploadStatusText = _removeBg
          ? 'جاري عزل وتفريغ الخلفية بالذكاء الاصطناعي...'
          : 'جاري رفع الصورة...';
    });

    try {
      Uint8List uploadBytes = picked.bytes;
      String uploadFileName = picked.fileName;
      String? contentType = picked.contentType;

      if (_removeBg) {
        uploadBytes = await BackgroundRemovalService.instance
            .removeBackground(picked.bytes);
        final baseName = p.basenameWithoutExtension(picked.fileName);
        uploadFileName = '$baseName.png';
        contentType = 'image/png';
      }

      final url = await ref.read(shopStorageRepositoryProvider).uploadBytes(
            bucket: 'product-media',
            folder: kind,
            fileName: uploadFileName,
            bytes: uploadBytes,
            contentType: contentType,
          );

      setState(() => _newImages.add(_ImageDraft(path: url, kind: kind)));

      if (mounted) {
        showAppSnackBar(
          context,
          _removeBg
              ? 'تم عزل وتفريغ الخلفية ورفع الصورة بنجاح'
              : 'تم تجهيز الصورة للرفع مع الحفظ',
        );
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(shopStorageRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  Future<void> _save({required bool publish}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_variants.isEmpty) {
      showAppSnackBar(context, 'أضف لوناً ومقاساً واحداً على الأقل', isError: true);
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null) {
      showAppSnackBar(context, 'السعر غير صالح', isError: true);
      return;
    }

    final actions = ref.read(shopCatalogActionProvider.notifier);
    final product = await actions.saveProduct(
      name: _nameController.text,
      description: _descController.text,
      price: price,
      categoryId: _categoryId,
      status: publish ? 'published' : _status,
      id: widget.productId,
      variants: _variants
          .map((item) => (color: item.color, size: item.size, stock: item.stock))
          .toList(),
      images: _newImages
          .map((item) => (path: item.path, kind: item.kind))
          .toList(),
    );

    if (!mounted) return;
    if (product == null) {
      final error = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر حفظ المنتج' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }

    showAppSnackBar(context, publish ? 'تم نشر المنتج' : 'تم حفظ المنتج');
    ref.invalidate(shopCatalogActionProvider);
    context.go(AppRoutes.shopProducts);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shopProductProvider(widget.productId ?? ''), (previous, next) => _seed());
    _seed();

    final categories = ref.watch(shopCategoriesProvider).value ?? [];
    final busy = ref.watch(shopCatalogActionProvider).isLoading || _uploading;

    return ShopScaffold(
      title: widget.productId == null ? 'إضافة منتج' : 'تعديل منتج',
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'اسم المنتج',
                validator: (value) =>
                    Validators.required(value, field: 'اسم المنتج'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descController,
                label: 'الوصف',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _priceController,
                label: 'السعر',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    Validators.required(value, field: 'السعر'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('التصنيف', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('بدون تصنيف'),
                  ),
                  ...categories.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('الألوان والمقاسات',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _colorController,
                label: 'اللون',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _sizeController,
                label: 'المقاس',
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _stockController,
                label: 'المخزون',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'إضافة مقاس/لون',
                variant: AppButtonVariant.outlined,
                onPressed: busy ? null : _addVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              ..._variants.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Text(
                      '${item.color} / ${item.size} · مخزون ${item.stock}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('صور المنتج وAR',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('تفريغ الخلفية تلقائياً (مجاني ✨)'),
                subtitle: const Text(
                  'عزل المنتج وجعل الخلفية شفافة بالذكاء الاصطناعي',
                ),
                value: _removeBg,
                onChanged:
                    _uploading ? null : (val) => setState(() => _removeBg = val),
              ),
              if (_uploadStatusText != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _uploadStatusText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.gray700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'رفع صورة منتج',
                variant: AppButtonVariant.outlined,
                isLoading: _uploading,
                onPressed: () => _uploadImage(kind: 'gallery'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'رفع صورة AR',
                variant: AppButtonVariant.outlined,
                isLoading: _uploading,
                onPressed: () => _uploadImage(kind: 'ar'),
              ),
              if (_newImages.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('صور جديدة: ${_newImages.length}'),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'حفظ كمسودة',
                variant: AppButtonVariant.outlined,
                isLoading: busy,
                onPressed: () {
                  _status = 'draft';
                  _save(publish: false);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'حفظ ونشر',
                isLoading: busy,
                onPressed: () => _save(publish: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
