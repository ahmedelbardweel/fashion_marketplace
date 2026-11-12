import 'package:fashion_marketplace/core/utils/app_haptics.dart';

import '../widgets/product_form_steps.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/background_removal_service.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/shop_shell.dart';

final shopProductImagePickerProvider =
    Provider<Future<List<PickedBytes>> Function()>(
      (ref) => MediaPicker.pickImages,
    );
final shopProductBackgroundRemoverProvider =
    Provider<Future<Uint8List> Function(Uint8List)>(
      (ref) => BackgroundRemovalService.instance.removeBackground,
    );

class _VariantDraft {
  _VariantDraft(this.color, this.size, this.stock);
  final String color;
  final String size;
  final int stock;
  Map<String, dynamic> toJson() => {
    'color': color,
    'size': size,
    'stock': stock,
  };
}

class _ImageDraft {
  _ImageDraft({this.path, this.picked, this.kind = 'gallery'});
  String? path;
  final PickedBytes? picked;
  Uint8List? preview;
  final String kind;
  bool working = false;
  bool failed = false;
}

class ShopProductFormScreen extends ConsumerStatefulWidget {
  const ShopProductFormScreen({super.key, this.productId});
  final String? productId;
  @override
  ConsumerState<ShopProductFormScreen> createState() =>
      _ShopProductFormScreenState();
}

class _ShopProductFormScreenState extends ConsumerState<ShopProductFormScreen> {
  static const _steps = [
    'بيانات المنتج',
    'الصور',
    'المقاسات والمخزون',
    'المراجعة',
  ];
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _brand = TextEditingController();
  final _material = TextEditingController();
  final _care = TextEditingController();
  final _sku = TextEditingController();
  final _scroll = ScrollController();
  final _variants = <_VariantDraft>[];
  final _images = <_ImageDraft>[];
  String? _categoryId;
  String? _newCategory;
  bool _seeded = false;
  bool _processing = false;
  bool _dirty = false;
  bool _leaving = false;
  int _step = 0;
  Map<String, dynamic> _existingDetails = {};
  bool get _saving => ref.read(shopCatalogActionProvider).isLoading;
  List<TextEditingController> get _controllers => [
    _name,
    _description,
    _price,
    _brand,
    _material,
    _care,
    _sku,
  ];
  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _seed() {
    if (_seeded || widget.productId == null) return;
    final product = ref.read(shopProductProvider(widget.productId!)).value;
    if (product == null) return;
    _seeded = true;
    _name.text = product.name;
    _description.text = product.description ?? '';
    _price.text = product.price.toStringAsFixed(2);
    _categoryId = product.categoryId;
    _existingDetails = product.details;
    _brand.text = product.details['brand']?.toString() ?? '';
    _material.text = product.details['material']?.toString() ?? '';
    _care.text = product.details['care']?.toString() ?? '';
    _sku.text = product.details['sku']?.toString() ?? '';
    _variants.addAll(
      product.variants
          .where((v) => v.isActive)
          .map((v) => _VariantDraft(v.color, v.size, v.stock)),
    );
    _images.addAll(
      product.images.map((v) => _ImageDraft(path: v.filePath, kind: v.kind)),
    );
    setState(() => _dirty = false);
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  double? get _parsedPrice =>
      double.tryParse(_price.text.trim().replaceAll('٫', '.'));
  String? _validate(int step, {bool publish = true, bool forSave = false}) {
    if (step == 0) {
      if (_name.text.trim().isEmpty) return 'اكتب اسم المنتج أولاً';
      final price = _parsedPrice;
      if (price == null ||
          !price.isFinite ||
          price < 0 ||
          (publish && price == 0)) {
        return 'أدخل سعراً صحيحاً أكبر من صفر';
      }
      if (publish && _description.text.trim().isEmpty) {
        return 'أضف وصفاً يوضح المنتج للعميل';
      }
      if (publish && _categoryId == null && _newCategory == null) {
        return 'اختر تصنيفاً أو أضف تصنيفاً جديداً';
      }
    }
    if (step == 1) {
      if (forSave && (_processing || _images.any((i) => i.path == null))) {
        return 'انتظر تجهيز الصور أو أعد محاولة الصور المتعثرة أو احذفها';
      }
      if (publish && !_images.any((i) => i.kind == 'gallery')) {
        return 'أضف صورة واحدة على الأقل للمنتج';
      }
    }
    if (step == 2 && publish) {
      if (_variants.isEmpty) return 'أضف اللون والمقاس والكمية المتاحة';
      if (_variants.every((v) => v.stock == 0)) {
        return 'أضف كمية متاحة قبل النشر';
      }
    }
    return null;
  }

  List<double> get _stepProgress {
    final basics = [
      _name.text.trim().isNotEmpty,
      _description.text.trim().isNotEmpty,
      _parsedPrice != null && _parsedPrice!.isFinite && _parsedPrice! > 0,
      _categoryId != null || _newCategory != null,
      _brand.text.trim().isNotEmpty,
      _material.text.trim().isNotEmpty,
      _care.text.trim().isNotEmpty,
      _sku.text.trim().isNotEmpty,
    ];
    final photos = _images.isEmpty
        ? 0.0
        : _images
                  .where((i) => i.path != null && !i.failed && !i.working)
                  .length /
              _images.length;
    final stock = _variants.isEmpty
        ? 0.0
        : (_variants.any((v) => v.stock > 0) ? 1.0 : 2 / 3);
    final ready = List.generate(
      3,
      (i) => _validate(i, forSave: true) == null,
    ).every((v) => v);
    return [
      basics.where((v) => v).length / basics.length,
      photos,
      stock,
      _step == 3 && ready ? 1 : 0,
    ];
  }

  void _next() {
    final error = _validate(_step);
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    _go(_step + 1);
  }

  Future<void> _addCategory() async {
    String value = '';
    final result = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'تصنيف جديد',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'استخدم اسماً واضحاً مثل فساتين سهرة أو ملابس رياضية. سيُحفظ التصنيف مع المنتج.',
            ),
            const SizedBox(height: 16),
            TextField(
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'اسم التصنيف'),
              onChanged: (v) => value = v,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'استخدام التصنيف',
              onPressed: () {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final categories = ref.read(shopCategoriesProvider).value ?? [];
    final matches = categories.where(
      (c) => c.name.trim().toLowerCase() == result.toLowerCase(),
    );
    setState(() {
      _categoryId = matches.isEmpty ? null : matches.first.id;
      _newCategory = matches.isEmpty ? result : null;
      _dirty = true;
    });
  }

  Future<void> _editVariant([int? index]) async {
    final old = index == null ? null : _variants[index];
    final color = TextEditingController(text: old?.color ?? '');
    final size = TextEditingController(text: old?.size ?? '');
    final stock = TextEditingController(text: old?.stock.toString() ?? '1');
    String? error;
    final result = await AppBottomSheet.show<_VariantDraft>(
      context: context,
      child: StatefulBuilder(
        builder: (context, update) => AppBottomSheetScaffold(
          title: index == null ? 'إضافة لون ومقاس' : 'تعديل الخيار',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(controller: color, label: 'اللون، مثل أسود'),
              const SizedBox(height: 12),
              AppTextField(controller: size, label: 'المقاس، مثل M أو 38'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'مقاس موحد']
                    .map(
                      (v) => ActionChip(
                        label: Text(v),
                        onPressed: AppHaptics.action(() => size.text = v),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: stock,
                label: 'عدد القطع المتاحة',
                keyboardType: TextInputType.number,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!),
                ),
              const SizedBox(height: 16),
              AppButton(
                label: 'حفظ الخيار',
                onPressed: () {
                  final amount = int.tryParse(stock.text.trim());
                  final duplicate = _variants.indexWhere(
                    (v) =>
                        v.color.toLowerCase() ==
                            color.text.trim().toLowerCase() &&
                        v.size.toLowerCase() == size.text.trim().toLowerCase(),
                  );
                  if (color.text.trim().isEmpty ||
                      size.text.trim().isEmpty ||
                      amount == null ||
                      amount < 0 ||
                      amount > 2147483647) {
                    update(() => error = 'أدخل اللون والمقاس وكمية صحيحة');
                    return;
                  }
                  if (duplicate != -1 && duplicate != index) {
                    update(
                      () => error =
                          'هذا اللون والمقاس موجودان بالفعل؛ عدّل كميتهما',
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    _VariantDraft(color.text.trim(), size.text.trim(), amount),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    // Controllers remain alive until the bottom sheet exit transition completes.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    color.dispose();
    size.dispose();
    stock.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _variants.add(result);
      } else {
        _variants[index] = result;
      }
      _dirty = true;
    });
  }

  Future<void> _pickImages() async {
    if (_processing || _saving) return;
    setState(() => _processing = true);
    try {
      final picked = await ref.read(shopProductImagePickerProvider)();
      if (!mounted || picked.isEmpty) return;
      final remaining = (12 - _images.length).clamp(0, 12);
      if (picked.length > remaining) {
        showAppSnackBar(context, 'يمكن إضافة 12 صورة كحد أقصى');
      }
      final drafts = picked
          .take(remaining)
          .map((v) => _ImageDraft(picked: v)..preview = v.bytes)
          .toList();
      setState(() {
        _images.addAll(drafts);
        _dirty = true;
        _processing = true;
      });
      for (final draft in drafts) {
        if (!mounted) break;
        await _processImage(draft);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'تعذر اختيار الصور، حاول مجدداً',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processImage(_ImageDraft draft) async {
    if (!_images.contains(draft)) return;
    setState(() {
      draft.working = true;
      draft.failed = false;
    });
    try {
      final bytes = await ref.read(shopProductBackgroundRemoverProvider)(
        draft.picked!.bytes,
      );
      if (!mounted || !_images.contains(draft)) return;
      setState(() => draft.preview = bytes);
      final path = await ref
          .read(shopStorageRepositoryProvider)
          .uploadBytes(
            bucket: 'product-media',
            folder: 'gallery',
            fileName:
                '${p.basenameWithoutExtension(draft.picked!.fileName)}.png',
            bytes: bytes,
            contentType: 'image/png',
          );
      if (!mounted || !_images.contains(draft)) return;
      setState(() {
        draft.path = path;
        draft.working = false;
      });
    } catch (_) {
      if (mounted && _images.contains(draft)) {
        setState(() {
          draft.failed = true;
          draft.working = false;
        });
      }
    }
  }

  Future<void> _retry(_ImageDraft draft) async {
    setState(() => _processing = true);
    await _processImage(draft);
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _save(bool publish) async {
    if (_saving || _processing) return;
    for (var step = 0; step < 3; step++) {
      final error = _validate(step, publish: publish, forSave: true);
      if (error != null) {
        _go(step);
        showAppSnackBar(context, error, isError: true);
        return;
      }
    }
    final actions = ref.read(shopCatalogActionProvider.notifier);
    final result = await actions.saveProductForm({
      'id': widget.productId,
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': _parsedPrice,
      'category_id': _categoryId,
      'new_category_name': _newCategory,
      'status': publish ? 'published' : 'draft',
      'details': {
        ..._existingDetails,
        'brand': _brand.text.trim(),
        'material': _material.text.trim(),
        'care': _care.text.trim(),
        'sku': _sku.text.trim(),
      },
      'variants': _variants.map((v) => v.toJson()).toList(),
      'images': _images.map((i) => {'path': i.path, 'kind': i.kind}).toList(),
    });
    if (!mounted) return;
    if (result == null) {
      final error = ref.read(shopCatalogActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر الحفظ' : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    setState(() {
      _dirty = false;
      _leaving = true;
    });
    showAppSnackBar(
      context,
      publish ? 'تم نشر المنتج بنجاح' : 'تم حفظ المسودة',
    );
    context.go(AppRoutes.shopProducts);
  }

  Future<void> _confirmLeave() async {
    if (_saving) return;
    final leave = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'مغادرة إضافة المنتج؟',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('التغييرات غير المحفوظة لن تُضاف إلى منتجاتك.'),
            const SizedBox(height: 16),
            AppButton(
              label: 'متابعة التعديل',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'مغادرة دون حفظ',
              variant: AppButtonVariant.outlined,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      context.go(AppRoutes.shopProducts);
    }
  }

  Widget _section(String title, String hint, List<Widget> children) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AppTextField(
      controller: controller,
      label: label,
      maxLines: lines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
    ),
  );
  Widget _basics() {
    final categories = ref.watch(shopCategoriesProvider);
    return _section(
      'عرّف العميل بالمنتج',
      'الاسم والوصف والتصنيف والسعر مطلوبة للنشر. يمكنك إكمال البقية لاحقاً كمسودة.',
      [
        _field(_name, 'اسم المنتج *'),
        _field(
          _description,
          'الوصف * — القَصّة والتفاصيل وما يميز المنتج',
          lines: 4,
        ),
        _field(_price, 'سعر القطعة (ر.س) *', number: true),
        categories.when(
          loading: () => const AppSkeleton(
            child: ListTile(
              title: Text('تصنيف المنتج'),
              subtitle: Text('جاري تحميل التصنيفات'),
            ),
          ),
          error: (_, _) => TextButton(
            onPressed: AppHaptics.action(
              () => ref.invalidate(shopCategoriesProvider),
            ),
            child: const Text('تعذر تحميل التصنيفات — إعادة المحاولة'),
          ),
          data: (items) => DropdownButtonFormField<String>(
            key: ValueKey('$_categoryId/$_newCategory/${items.length}'),
            isExpanded: true,
            initialValue: _newCategory != null
                ? '__new__'
                : items.any((c) => c.id == _categoryId)
                ? _categoryId
                : null,
            decoration: const InputDecoration(labelText: 'التصنيف *'),
            items: [
              if (_newCategory != null)
                DropdownMenuItem(
                  value: '__new__',
                  child: Text(
                    '$_newCategory (جديد)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ...items.map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: AppHaptics.change(
              (v) => setState(() {
                if (v != '__new__') {
                  _categoryId = v;
                  _newCategory = null;
                }
                _dirty = true;
              }),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: AppHaptics.action(_addCategory),
            icon: const Icon(AppIcons.add),
            label: const Text('إضافة تصنيف جديد'),
          ),
        ),
        const Divider(height: 32),
        Text(
          'تفاصيل تساعد العميل على الاختيار (اختيارية)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        _field(_brand, 'الماركة'),
        _field(_material, 'الخامة وتركيبة القماش'),
        _field(_care, 'تعليمات الغسيل والعناية', lines: 2),
        _field(_sku, 'رمز المنتج لدى المحل'),
      ],
    );
  }

  Widget _imagePreview(_ImageDraft item) {
    if (item.kind == '3d_model') {
      return const Center(child: Icon(AppIcons.tryOn, size: 40));
    }
    if (item.preview != null) {
      return Image.memory(
        item.preview!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(AppIcons.imageBroken),
      );
    }
    return AppNetworkImage(
      item.path!,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(AppIcons.imageBroken),
    );
  }

  Widget _photos() => _section(
    'صور واضحة تبيع أفضل',
    'اختر حتى 12 صورة. نزيل الخلفية تلقائياً ونرفعها بصيغة شفافة. اجعل الصورة الأمامية أولاً لتكون صورة المنتج الرئيسية.',
    [
      AppButton(
        label: _processing
            ? 'جاري تجهيز الصور… يمكنك إكمال البيانات'
            : 'اختيار صور المنتج',
        variant: AppButtonVariant.outlined,
        onPressed: _processing || _images.length >= 12 ? null : _pickImages,
      ),
      const SizedBox(height: 16),
      if (_images.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(AppIcons.addPhoto, size: 48),
              SizedBox(height: 12),
              Text(
                'صورة أمامية، خلفية، وصورة للتفاصيل',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ...List.generate(_images.length, (index) {
        final item = _images[index];
        final primary =
            item.kind == 'gallery' &&
            _images.indexWhere((i) => i.kind == 'gallery') == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 180, child: _imagePreview(item)),
                const SizedBox(height: 8),
                Text(
                  primary
                      ? 'الصورة الرئيسية'
                      : item.kind == 'ar'
                      ? 'صورة تجربة الملابس'
                      : 'صورة ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (item.working || (item.path == null && !item.failed))
                  const AppBusyLabel(label: 'جاري إزالة الخلفية وتجهيز الصورة'),
                if (item.failed) ...[
                  const Text(
                    'تعذرت معالجة الصورة. أعد المحاولة أو احذفها لاختيار صورة أخرى.',
                  ),
                  TextButton(
                    onPressed: AppHaptics.action(
                      _processing ? null : () => _retry(item),
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'تقديم الصورة',
                      onPressed: AppHaptics.action(
                        index == 0
                            ? null
                            : () => setState(() {
                                _images.removeAt(index);
                                _images.insert(index - 1, item);
                                _dirty = true;
                              }),
                      ),
                      icon: const Icon(AppIcons.arrowUp),
                    ),
                    IconButton(
                      tooltip: 'تأخير الصورة',
                      onPressed: AppHaptics.action(
                        index == _images.length - 1
                            ? null
                            : () => setState(() {
                                _images.removeAt(index);
                                _images.insert(index + 1, item);
                                _dirty = true;
                              }),
                      ),
                      icon: const Icon(AppIcons.arrowDown),
                    ),
                    if (!primary && item.kind == 'gallery')
                      TextButton(
                        onPressed: AppHaptics.action(
                          () => setState(() {
                            _images.remove(item);
                            _images.insert(0, item);
                            _dirty = true;
                          }),
                        ),
                        child: const Text('جعلها الرئيسية'),
                      ),
                    IconButton(
                      tooltip: 'حذف الصورة',
                      onPressed: AppHaptics.action(
                        () => setState(() {
                          _images.remove(item);
                          _dirty = true;
                        }),
                      ),
                      icon: const Icon(AppIcons.delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    ],
  );
  Widget _stock() => _section(
    'كل خيار وكمّيته',
    'أضف كل لون ومقاس متاح مرة واحدة. يمكنك تعديل الكمية أو حذف الخيار قبل الحفظ.',
    [
      Text(
        '${_variants.length} خيارات · ${_variants.fold<int>(0, (sum, v) => sum + v.stock)} قطعة متاحة',
      ),
      const SizedBox(height: 16),
      ...List.generate(_variants.length, (index) {
        final v = _variants[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${v.color} · ${v.size}'),
          subtitle: Text('${v.stock} قطعة'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل الخيار',
                onPressed: AppHaptics.action(() => _editVariant(index)),
                icon: const Icon(AppIcons.edit),
              ),
              IconButton(
                tooltip: 'حذف الخيار',
                onPressed: AppHaptics.action(
                  () => setState(() {
                    _variants.removeAt(index);
                    _dirty = true;
                  }),
                ),
                icon: const Icon(AppIcons.delete),
              ),
            ],
          ),
        );
      }),
      AppButton(
        label: 'إضافة لون ومقاس',
        variant: AppButtonVariant.outlined,
        onPressed: () => _editVariant(),
      ),
    ],
  );
  Widget _review() {
    final categories = ref.watch(shopCategoriesProvider).value ?? [];
    final matched = categories.where((c) => c.id == _categoryId);
    return _section(
      'راجع منتجك قبل النشر',
      'تأكد من السعر والصورة الرئيسية والمخزون. يمكنك الرجوع لأي مرحلة لتعديلها.',
      [
        if (_images.isNotEmpty)
          SizedBox(height: 220, child: _imagePreview(_images.first)),
        const SizedBox(height: 16),
        Text(_name.text, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(_description.text),
        const SizedBox(height: 16),
        Text(
          '${_price.text} ر.س',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Divider(height: 32),
        Text(
          'التصنيف: ${_newCategory ?? (matched.isEmpty ? 'غير محدد' : matched.first.name)}',
        ),
        for (final entry in {
          'الماركة': _brand.text,
          'الخامة': _material.text,
          'العناية': _care.text,
          'رمز المنتج': _sku.text,
        }.entries)
          if (entry.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${entry.key}: ${entry.value}'),
            ),
        const SizedBox(height: 12),
        Text(
          '${_images.length} صور · ${_variants.length} خيارات · ${_variants.fold<int>(0, (sum, v) => sum + v.stock)} قطعة',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: List.generate(
            3,
            (i) => TextButton(
              onPressed: AppHaptics.action(() => _go(i)),
              child: Text('تعديل ${_steps[i]}'),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.productId != null) {
      ref.listen(shopProductProvider(widget.productId!), (_, _) {
        if (!_seeded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _seed();
          });
        }
      });
      final product = ref.watch(shopProductProvider(widget.productId!));
      if (!_seeded && product.hasValue && product.value != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _seed();
        });
      }
      if (product.hasError || (product.hasValue && product.value == null)) {
        return ShopScaffold(
          title: 'تعديل منتج',
          body: Center(
            child: TextButton(
              onPressed: AppHaptics.action(
                () => ref.invalidate(shopProductProvider(widget.productId!)),
              ),
              child: const Text('تعذر فتح المنتج — إعادة المحاولة'),
            ),
          ),
        );
      }
      if (!_seeded) {
        return const ShopScaffold(
          title: 'تعديل منتج',
          body: AppSkeleton(
            child: Column(
              children: [
                ListTile(
                  title: Text('بيانات المنتج'),
                  subtitle: Text('وصف المنتج'),
                ),
                SizedBox(height: 200, child: Card()),
              ],
            ),
          ),
        );
      }
    }
    final saving = ref.watch(shopCatalogActionProvider).isLoading;
    return PopScope(
      canPop: _leaving || (!_dirty && !_processing && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: ShopScaffold(
        title: widget.productId == null ? 'إضافة منتج' : 'تعديل منتج',
        showBottomNav: false,
        body: AbsorbPointer(
          absorbing: saving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            controller: _scroll,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'الخطوة ${_step + 1} من 4',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ProductFormSteps(
                      labels: _steps,
                      progress: _stepProgress,
                      current: _step,
                      onSelected: (i) {
                        if (i > _step) {
                          for (var s = 0; s < i; s++) {
                            final error = _validate(s);
                            if (error != null) {
                              _go(s);
                              showAppSnackBar(context, error, isError: true);
                              return;
                            }
                          }
                        }
                        _go(i);
                      },
                    ),
                    const SizedBox(height: 20),
                    switch (_step) {
                      0 => _basics(),
                      1 => _photos(),
                      2 => _stock(),
                      _ => _review(),
                    },
                    const SizedBox(height: 20),
                    AppButton(
                      label: _step == 3
                          ? 'نشر المنتج'
                          : 'التالي: ${_steps[_step + 1]}',
                      isLoading: saving,
                      onPressed: _step == 3
                          ? (_processing ? null : () => _save(true))
                          : _next,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: AppHaptics.action(() => _go(_step - 1)),
                            child: const Text('السابق'),
                          ),
                        TextButton(
                          onPressed: AppHaptics.action(
                            saving || _processing ? null : () => _save(false),
                          ),
                          child: const Text('حفظ كمسودة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
