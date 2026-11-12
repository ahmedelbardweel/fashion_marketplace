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
  static List<String> get _steps => [
    'بيانات المنتج'.tr,
    'الصور'.tr,
    'المقاسات والمخزون'.tr,
    'المراجعة'.tr,
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
      double.tryParse(_price.text.trim().replaceAll('٫'.tr, '.'));
  String? _validate(int step, {bool publish = true, bool forSave = false}) {
    if (step == 0) {
      if (_name.text.trim().isEmpty) return 'اكتب اسم المنتج أولاً'.tr;
      final price = _parsedPrice;
      if (price == null ||
          !price.isFinite ||
          price < 0 ||
          (publish && price == 0)) {
        return 'أدخل سعراً صحيحاً أكبر من صفر'.tr;
      }
      if (publish && _description.text.trim().isEmpty) {
        return 'أضف وصفاً يوضح المنتج للعميل'.tr;
      }
      if (publish && _categoryId == null && _newCategory == null) {
        return 'اختر تصنيفاً أو أضف تصنيفاً جديداً'.tr;
      }
    }
    if (step == 1) {
      if (forSave && (_processing || _images.any((i) => i.path == null))) {
        return 'انتظر تجهيز الصور أو أعد محاولة الصور المتعثرة أو احذفها'.tr;
      }
      if (publish && !_images.any((i) => i.kind == 'gallery')) {
        return 'أضف صورة واحدة على الأقل للمنتج'.tr;
      }
    }
    if (step == 2 && publish) {
      if (_variants.isEmpty) return 'أضف اللون والمقاس والكمية المتاحة'.tr;
      if (_variants.every((v) => v.stock == 0)) {
        return 'أضف كمية متاحة قبل النشر'.tr;
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
        title: 'تصنيف جديد'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'استخدم اسماً واضحاً مثل فساتين سهرة أو ملابس رياضية. سيُحفظ التصنيف مع المنتج.'.tr,
            ),
            const SizedBox(height: 16),
            TextField(
              maxLength: 80,
              decoration: InputDecoration(labelText: 'اسم التصنيف'.tr),
              onChanged: (v) => value = v,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'استخدام التصنيف'.tr,
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
          title: index == null ? 'إضافة لون ومقاس'.tr : 'تعديل الخيار'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(controller: color, label: 'اللون، مثل أسود'.tr),
              const SizedBox(height: 12),
              AppTextField(controller: size, label: 'المقاس، مثل M أو 38'.tr),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'مقاس موحد'.tr]
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
                label: 'عدد القطع المتاحة'.tr,
                keyboardType: TextInputType.number,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!),
                ),
              const SizedBox(height: 16),
              AppButton(
                label: 'حفظ الخيار'.tr,
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
                    update(() => error = 'أدخل اللون والمقاس وكمية صحيحة'.tr);
                    return;
                  }
                  if (duplicate != -1 && duplicate != index) {
                    update(
                      () => error =
                          'هذا اللون والمقاس موجودان بالفعل؛ عدّل كميتهما'.tr,
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
        showAppSnackBar(context, 'يمكن إضافة 12 صورة كحد أقصى'.tr);
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
          'تعذر اختيار الصور، حاول مجدداً'.tr,
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
        error == null ? 'تعذر الحفظ'.tr : actions.errorMessage(error),
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
      publish ? 'تم نشر المنتج بنجاح'.tr : 'تم حفظ المسودة'.tr,
    );
    context.go(AppRoutes.shopProducts);
  }

  Future<void> _confirmLeave() async {
    if (_saving) return;
    final leave = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'مغادرة إضافة المنتج؟'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('التغييرات غير المحفوظة لن تُضاف إلى منتجاتك.'.tr),
            const SizedBox(height: 16),
            AppButton(
              label: 'متابعة التعديل'.tr,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'مغادرة دون حفظ'.tr,
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
      'عرّف العميل بالمنتج'.tr,
      'الاسم والوصف والتصنيف والسعر مطلوبة للنشر. يمكنك إكمال البقية لاحقاً كمسودة.'.tr,
      [
        _field(_name, 'اسم المنتج *'.tr),
        _field(
          _description,
          'الوصف * — القَصّة والتفاصيل وما يميز المنتج'.tr,
          lines: 4,
        ),
        _field(_price, 'سعر القطعة (₪) *'.tr, number: true),
        categories.when(
          loading: () => AppSkeleton(
            child: ListTile(
              title: Text('تصنيف المنتج'.tr),
              subtitle: Text('جاري تحميل التصنيفات'.tr),
            ),
          ),
          error: (_, _) => TextButton(
            onPressed: AppHaptics.action(
              () => ref.invalidate(shopCategoriesProvider),
            ),
            child: Text('تعذر تحميل التصنيفات — إعادة المحاولة'.tr),
          ),
          data: (items) => DropdownButtonFormField<String>(
            key: ValueKey('$_categoryId/$_newCategory/${items.length}'),
            isExpanded: true,
            initialValue: _newCategory != null
                ? '__new__'
                : items.any((c) => c.id == _categoryId)
                ? _categoryId
                : null,
            decoration: InputDecoration(labelText: 'التصنيف *'.tr),
            items: [
              if (_newCategory != null)
                DropdownMenuItem(
                  value: '__new__',
                  child: Text(
                    '$_newCategory (جديد)'.tr,
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
            label: Text('إضافة تصنيف جديد'.tr),
          ),
        ),
        const Divider(height: 32),
        Text(
          'تفاصيل تساعد العميل على الاختيار (اختيارية)'.tr,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        _field(_brand, 'الماركة'.tr),
        _field(_material, 'الخامة وتركيبة القماش'.tr),
        _field(_care, 'تعليمات الغسيل والعناية'.tr, lines: 2),
        _field(_sku, 'رمز المنتج لدى المحل'.tr),
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
    'صور واضحة تبيع أفضل'.tr,
    'اختر حتى 12 صورة. نزيل الخلفية تلقائياً ونرفعها بصيغة شفافة. اجعل الصورة الأمامية أولاً لتكون صورة المنتج الرئيسية.'.tr,
    [
      AppButton(
        label: _processing
            ? 'جاري تجهيز الصور… يمكنك إكمال البيانات'.tr
            : 'اختيار صور المنتج'.tr,
        variant: AppButtonVariant.outlined,
        onPressed: _processing || _images.length >= 12 ? null : _pickImages,
      ),
      const SizedBox(height: 16),
      if (_images.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(AppIcons.addPhoto, size: 48),
              SizedBox(height: 12),
              Text(
                'صورة أمامية، خلفية، وصورة للتفاصيل'.tr,
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
                      ? 'الصورة الرئيسية'.tr
                      : item.kind == 'ar'
                      ? 'صورة تجربة الملابس'.tr
                      : 'صورة ${index + 1}'.tr,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (item.working || (item.path == null && !item.failed))
                  AppBusyLabel(label: 'جاري إزالة الخلفية وتجهيز الصورة'.tr),
                if (item.failed) ...[
                  Text(
                    'تعذرت معالجة الصورة. أعد المحاولة أو احذفها لاختيار صورة أخرى.'.tr,
                  ),
                  TextButton(
                    onPressed: AppHaptics.action(
                      _processing ? null : () => _retry(item),
                    ),
                    child: Text('إعادة المحاولة'.tr),
                  ),
                ],
                Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'تقديم الصورة'.tr,
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
                      tooltip: 'تأخير الصورة'.tr,
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
                        child: Text('جعلها الرئيسية'.tr),
                      ),
                    IconButton(
                      tooltip: 'حذف الصورة'.tr,
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
    'كل خيار وكمّيته'.tr,
    'أضف كل لون ومقاس متاح مرة واحدة. يمكنك تعديل الكمية أو حذف الخيار قبل الحفظ.'.tr,
    [
      Text(
        '${_variants.length} خيارات · ${_variants.fold<int>(0, (sum, v) => sum + v.stock)} قطعة متاحة'.tr,
      ),
      const SizedBox(height: 16),
      ...List.generate(_variants.length, (index) {
        final v = _variants[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${v.color} · ${v.size}'),
          subtitle: Text('${v.stock} قطعة'.tr),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل الخيار'.tr,
                onPressed: AppHaptics.action(() => _editVariant(index)),
                icon: const Icon(AppIcons.edit),
              ),
              IconButton(
                tooltip: 'حذف الخيار'.tr,
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
        label: 'إضافة لون ومقاس'.tr,
        variant: AppButtonVariant.outlined,
        onPressed: () => _editVariant(),
      ),
    ],
  );
  Widget _review() {
    final categories = ref.watch(shopCategoriesProvider).value ?? [];
    final matched = categories.where((c) => c.id == _categoryId);
    return _section(
      'راجع منتجك قبل النشر'.tr,
      'تأكد من السعر والصورة الرئيسية والمخزون. يمكنك الرجوع لأي مرحلة لتعديلها.'.tr,
      [
        if (_images.isNotEmpty)
          SizedBox(height: 220, child: _imagePreview(_images.first)),
        const SizedBox(height: 16),
        Text(_name.text, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(_description.text),
        const SizedBox(height: 16),
        Text(
          '${_price.text} ₪'.tr,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Divider(height: 32),
        Text(
          'التصنيف: ${_newCategory ?? (matched.isEmpty ? 'غير محدد'.tr : matched.first.name)}',
        ),
        for (final entry in {
          'الماركة'.tr: _brand.text,
          'الخامة'.tr: _material.text,
          'العناية'.tr: _care.text,
          'رمز المنتج'.tr: _sku.text,
        }.entries)
          if (entry.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${entry.key}: ${entry.value}'),
            ),
        const SizedBox(height: 12),
        Text(
          '${_images.length} صور · ${_variants.length} خيارات · ${_variants.fold<int>(0, (sum, v) => sum + v.stock)} قطعة'.tr,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: List.generate(
            3,
            (i) => TextButton(
              onPressed: AppHaptics.action(() => _go(i)),
              child: Text('تعديل ${_steps[i]}'.tr),
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
          title: 'تعديل منتج'.tr,
          body: Center(
            child: TextButton(
              onPressed: AppHaptics.action(
                () => ref.invalidate(shopProductProvider(widget.productId!)),
              ),
              child: Text('تعذر فتح المنتج — إعادة المحاولة'.tr),
            ),
          ),
        );
      }
      if (!_seeded) {
        return ShopScaffold(
          title: 'تعديل منتج'.tr,
          body: AppSkeleton(
            child: Column(
              children: [
                ListTile(
                  title: Text('بيانات المنتج'.tr),
                  subtitle: Text('وصف المنتج'.tr),
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
        title: widget.productId == null ? 'إضافة منتج'.tr : 'تعديل منتج'.tr,
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
                      'الخطوة ${_step + 1} من 4'.tr,
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
                          ? 'نشر المنتج'.tr
                          : 'التالي: ${_steps[_step + 1]}'.tr,
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
                            child: Text('السابق'.tr),
                          ),
                        TextButton(
                          onPressed: AppHaptics.action(
                            saving || _processing ? null : () => _save(false),
                          ),
                          child: Text('حفظ كمسودة'.tr),
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
