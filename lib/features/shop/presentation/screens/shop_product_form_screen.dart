import 'dart:typed_data';

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
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
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/product_form_steps.dart';
import '../widgets/product_size_chart_editor.dart';
import '../widgets/shop_components.dart';
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
  static const _pricePresets = ['50', '100', '150', '200', '300'];
  static const _materialPresets = [
    'قطن 100%',
    'كتان',
    'جينز',
    'بوليستر',
    'صوف',
    'جلد',
    'حرير',
  ];
  static const _carePresets = [
    'غسيل بارد',
    'غسيل يدوي',
    'تنظيف جاف',
    'لا يُكوى',
  ];
  static const _colorPresets = [
    'أسود',
    'أبيض',
    'كحلي',
    'رمادي',
    'بيج',
    'بني',
    'أحمر',
    'أخضر',
    'أزرق',
  ];
  static const _sizePresets = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    '38',
    '39',
    '40',
    '41',
    '42',
    'مقاس موحد',
  ];
  static const _stockPresets = ['1', '5', '10', '20', '50'];

  static List<String> get _steps => [
    'الأساسيات'.tr,
    'المواصفات'.tr,
    'الصور'.tr,
    'المقاسات'.tr,
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

  // Steps:
  // 0: Basics (4 required fields)
  // 1: Specs (4 optional fields — always valid)
  // 2: Photos
  // 3: Sizes & Stock
  // 4: Review & Publish
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
    if (step == 2) {
      if (forSave && (_processing || _images.any((i) => i.path == null))) {
        return 'انتظر تجهيز الصور أو أعد محاولة الصور المتعثرة أو احذفها'.tr;
      }
      if (publish && !_images.any((i) => i.kind == 'gallery')) {
        return 'أضف صورة واحدة على الأقل للمنتج'.tr;
      }
    }
    if (step == 3 && publish) {
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
    ];
    final specs = [
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
    final ready = [0, 2, 3].every((i) => _validate(i, forSave: true) == null);

    return [
      basics.where((v) => v).length / basics.length,
      specs.where((v) => v).length / specs.length,
      photos,
      stock,
      _step == 4 && ready ? 1.0 : 0.0,
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

  Future<void> _openCategoryPicker(List<CatalogCategory> items) async {
    final searchCtrl = TextEditingController();
    final newCatCtrl = TextEditingController(text: _newCategory ?? '');
    var addingNew = false;

    final result = await AppBottomSheet.show<({String? categoryId, String? newCategory})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 1.0,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final options = hierarchicalCategoryOptions(items).where((entry) {
            if (query.isEmpty) return true;
            final full = entry.parent == null
                ? entry.category.name
                : '${entry.parent!.name} ${entry.category.name}';
            return full.toLowerCase().contains(query) ||
                full.tr.toLowerCase().contains(query);
          }).toList();

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Container(
                      width: SheetDesign.handleWidth,
                      height: SheetDesign.handleHeight,
                      decoration: BoxDecoration(
                        color: SheetDesign.handle,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'اختيار التصنيف'.tr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: SheetDesign.titleSize,
                        fontWeight: SheetDesign.titleWeight,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (addingNew) ...[
                            Text(
                              'استخدم اسماً واضحاً مثل فساتين سهرة أو ملابس رياضية. سيُحفظ التصنيف مع المنتج.'
                                  .tr,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: newCatCtrl,
                              label: 'اسم التصنيف'.tr,
                              hint: 'مثال: ملابس صيفية'.tr,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              label: 'استخدام التصنيف'.tr,
                              onPressed: () {
                                final value = newCatCtrl.text.trim();
                                if (value.isEmpty) return;
                                final matches = items.where(
                                  (c) =>
                                      c.name.trim().toLowerCase() ==
                                      value.toLowerCase(),
                                );
                                Navigator.of(sheetCtx).pop((
                                  categoryId: matches.isEmpty
                                      ? null
                                      : matches.first.id,
                                  newCategory: matches.isEmpty ? value : null,
                                ));
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: 'تراجع'.tr,
                              variant: AppButtonVariant.secondary,
                              onPressed: () =>
                                  setSheetState(() => addingNew = false),
                            ),
                          ] else ...[
                            if (items.length > 5) ...[
                              AppTextField(
                                controller: searchCtrl,
                                hint: 'ابحث في التصنيفات...'.tr,
                                onChanged: (_) => setSheetState(() {}),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (options.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg,
                                ),
                                child: Text(
                                  'لا يوجد تصنيف مطابق، يمكنك إضافة تصنيف جديد.'
                                      .tr,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              )
                            else
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  if (_newCategory != null)
                                    ChoiceChip(
                                      label: Text(
                                        '$_newCategory (${'جديد'.tr})',
                                      ),
                                      selected: true,
                                      onSelected: (_) =>
                                          Navigator.of(sheetCtx).pop((
                                            categoryId: null,
                                            newCategory: _newCategory,
                                          )),
                                    ),
                                  for (final entry in options)
                                    ChoiceChip(
                                      label: Text(
                                        entry.parent == null
                                            ? entry.category.name.tr
                                            : '${entry.parent!.name.tr} · ${entry.category.name.tr}',
                                      ),
                                      selected:
                                          _newCategory == null &&
                                          _categoryId == entry.category.id,
                                      onSelected: AppHaptics.change(
                                        (_) => Navigator.of(sheetCtx).pop((
                                          categoryId: entry.category.id,
                                          newCategory: null,
                                        )),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!addingNew)
                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border(top: AppBorders.side),
                      ),
                      child: AppButton(
                        label: 'إضافة تصنيف جديد'.tr,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => setSheetState(() => addingNew = true),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 350));
    searchCtrl.dispose();
    newCatCtrl.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _categoryId = result.categoryId;
      _newCategory = result.newCategory;
      _dirty = true;
    });
  }

  Future<void> _editVariant([int? index]) async {
    final old = index == null ? null : _variants[index];
    final color = TextEditingController(text: old?.color ?? '');
    final size = TextEditingController(text: old?.size ?? '');
    final stock = TextEditingController(text: old?.stock.toString() ?? '5');
    String? error;

    final result = await AppBottomSheet.show<_VariantDraft>(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (context, update) => AppBottomSheetScaffold(
          title: index == null ? 'إضافة لون ومقاس'.tr : 'تعديل الخيار'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: color,
                label: 'اللون'.tr,
                hint: 'مثال: أسود'.tr,
                onChanged: (_) => update(() {}),
              ),
              const SizedBox(height: AppSpacing.xs),
              _QuickChoiceRow(
                options: _colorPresets,
                selected: color.text.trim(),
                onSelected: (v) => update(() => color.text = v.tr),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: size,
                label: 'المقاس'.tr,
                hint: 'مثال: M أو 40'.tr,
                onChanged: (_) => update(() {}),
              ),
              const SizedBox(height: AppSpacing.xs),
              _QuickChoiceRow(
                options: _sizePresets,
                selected: size.text.trim(),
                onSelected: (v) => update(() => size.text = v.tr),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: stock,
                label: 'عدد القطع المتاحة'.tr,
                keyboardType: TextInputType.number,
                onChanged: (_) => update(() {}),
              ),
              const SizedBox(height: AppSpacing.xs),
              _QuickChoiceRow(
                options: _stockPresets,
                selected: stock.text.trim(),
                translate: false,
                onSelected: (v) => update(() => stock.text = v),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: AppFont.semiBold,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
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
    for (final step in const [0, 2, 3]) {
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
            Text(
              'التغييرات غير المحفوظة لن تُضاف إلى منتجاتك.'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'متابعة التعديل'.tr,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'مغادرة دون حفظ'.tr,
              variant: AppButtonVariant.secondary,
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
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: AppFont.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    ),
  );

  // Step 1: Basics — strictly 4 fields (Name, Category, Price, Description)
  Widget _basics() {
    final categories = ref.watch(shopCategoriesProvider);
    return _section(
      'البيانات الأساسية'.tr,
      '4 حقول فقط للتعريف بالمنتج وسعره وتصنيفه.'.tr,
      [
        AppTextField(
          controller: _name,
          label: 'اسم المنتج *'.tr,
          hint: 'مثال: جاكيت جينز كلاسيك'.tr,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'التصنيف *'.tr,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: InputDesign.label,
            fontWeight: InputDesign.labelWeight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        categories.when(
          loading: () => AppSkeleton(
            child: AppCard(child: Text('جاري تحميل التصنيفات'.tr)),
          ),
          error: (_, _) => TextButton(
            onPressed: AppHaptics.action(
              () => ref.invalidate(shopCategoriesProvider),
            ),
            child: Text('تعذر تحميل التصنيفات — إعادة المحاولة'.tr),
          ),
          data: (items) {
            final options = hierarchicalCategoryOptions(items);
            String? selectedLabel;
            if (_newCategory != null) {
              selectedLabel = '$_newCategory (${'جديد'.tr})';
            } else if (_categoryId != null) {
              final found = options
                  .where((e) => e.category.id == _categoryId)
                  .firstOrNull;
              if (found != null) {
                selectedLabel = found.parent == null
                    ? found.category.name.tr
                    : '${found.parent!.name.tr} · ${found.category.name.tr}';
              }
            }
            return InkWell(
              onTap: AppHaptics.action(() => _openCategoryPicker(items)),
              borderRadius: BorderRadius.circular(InputDesign.radius),
              child: InputDecorator(
                decoration: const InputDecoration(),
                isEmpty: selectedLabel == null,
                child: Text(
                  selectedLabel ?? 'اختر التصنيف أو أضف تصنيفاً جديداً'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: selectedLabel == null
                        ? AppColors.textMuted
                        : AppColors.text,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _price,
          label: 'سعر القطعة (₪) *'.tr,
          hint: 'مثال: 120'.tr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: AppSpacing.xs),
        _QuickChoiceRow(
          options: _pricePresets,
          selected: _price.text.trim(),
          translate: false,
          suffix: ' ₪',
          onSelected: (v) => setState(() {
            _price.text = v;
            _dirty = true;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _description,
          label: 'وصف المنتج *'.tr,
          hint: 'القَصّة، الأسلوب، وما يميز المنتج'.tr,
          maxLines: 3,
        ),
      ],
    );
  }

  // Step 2: Optional Specs — strictly 4 fields with 1-tap quick choices
  Widget _specs() {
    return _section(
      'مواصفات إضافية (اختياري)'.tr,
      'اختر من الخيارات الجاهزة بلمسة واحدة، أو اضغط التالي للتخطي.'.tr,
      [
        AppTextField(
          controller: _brand,
          label: 'الماركة'.tr,
          hint: 'اختياري — اسم العلامة أو المتجر'.tr,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _material,
          label: 'الخامة'.tr,
          hint: 'مثال: قطن 100%'.tr,
        ),
        const SizedBox(height: AppSpacing.xs),
        _QuickChoiceRow(
          options: _materialPresets,
          selected: _material.text.trim(),
          onSelected: (v) => setState(() {
            _material.text = v.tr;
            _dirty = true;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _care,
          label: 'تعليمات العناية'.tr,
          hint: 'مثال: غسيل بارد'.tr,
        ),
        const SizedBox(height: AppSpacing.xs),
        _QuickChoiceRow(
          options: _carePresets,
          selected: _care.text.trim(),
          onSelected: (v) => setState(() {
            _care.text = v.tr;
            _dirty = true;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _sku,
          label: 'رمز المنتج (SKU)'.tr,
          hint: 'اختياري — رمز خاص بالمتجر'.tr,
        ),
      ],
    );
  }

  Widget _imagePreview(_ImageDraft item) {
    if (item.kind == '3d_model') {
      return Center(
        child: AppStatusBadge(label: '3D', tone: BadgeTone.primary),
      );
    }
    if (item.preview != null) {
      return Image.memory(
        item.preview!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Center(child: Text('بدون صورة'.tr)),
      );
    }
    return AppNetworkImage(
      item.path!,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Center(child: Text('بدون صورة'.tr)),
    );
  }

  // Step 3: Photos
  Widget _photos() => _section(
    'صور المنتج'.tr,
    'اختر حتى 12 صورة — يتم إزالة الخلفية تلقائياً وتكون الصورة الأولى هي الرئيسية.'
        .tr,
    [
      AppButton(
        label: _processing
            ? 'جاري تجهيز الصور… يمكنك إكمال البيانات'.tr
            : '${'اختيار صور المنتج'.tr} (${_images.length}/12)',
        variant: AppButtonVariant.secondary,
        onPressed: _processing || _images.length >= 12 ? null : _pickImages,
      ),
      const SizedBox(height: AppSpacing.md),
      if (_images.isEmpty)
        ShopEmptyState(
          title: 'لم تُضف صوراً بعد',
          message: 'صورة أمامية، خلفية، وصورة للتفاصيل تزيد ثقة المشتري.',
        ),
      ...List.generate(_images.length, (index) {
        final item = _images[index];
        final primary =
            item.kind == 'gallery' &&
            _images.indexWhere((i) => i.kind == 'gallery') == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppStatusBadge(
                      label: primary
                          ? 'الصورة الرئيسية'
                          : item.kind == 'ar'
                          ? 'صورة تجربة الملابس'
                          : '${'صورة'.tr} ${index + 1}',
                      tone: primary ? BadgeTone.primary : BadgeTone.neutral,
                    ),
                    const Spacer(),
                    Tooltip(
                      message: 'حذف الصورة'.tr,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: AppHaptics.action(
                          () => setState(() {
                            _images.remove(item);
                            _dirty = true;
                          }),
                        ),
                        child: Text('حذف'.tr),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Container(
                    height: 170,
                    color: AppColors.surfaceAlt,
                    child: _imagePreview(item),
                  ),
                ),
                if (item.working || (item.path == null && !item.failed)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppBusyLabel(label: 'جاري إزالة الخلفية وتجهيز الصورة'.tr),
                ],
                if (item.failed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'تعذرت معالجة الصورة. أعد المحاولة أو احذفها لاختيار صورة أخرى.'
                        .tr,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'إعادة المحاولة'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: _processing ? null : () => _retry(item),
                  ),
                ],
                if (_images.length > 1) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
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
                      if (index > 0)
                        TextButton(
                          onPressed: AppHaptics.action(
                            () => setState(() {
                              _images.removeAt(index);
                              _images.insert(index - 1, item);
                              _dirty = true;
                            }),
                          ),
                          child: Text('تقديم الصورة'.tr),
                        ),
                      if (index < _images.length - 1)
                        TextButton(
                          onPressed: AppHaptics.action(
                            () => setState(() {
                              _images.removeAt(index);
                              _images.insert(index + 1, item);
                              _dirty = true;
                            }),
                          ),
                          child: Text('تأخير الصورة'.tr),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    ],
  );

  // Step 4: Sizes & Stock
  Widget _stock() {
    final totalUnits = _variants.fold<int>(0, (sum, v) => sum + v.stock);
    return _section(
      'كل خيار وكمّيته'.tr,
      'أضف الألوان والمقاسات المتوفرة بالكمية المناسبة لكل خيار.'.tr,
      [
        ShopKpiCard(
          label: '${_variants.length} ${'خيارات'.tr}',
          value: '$totalUnits ${'قطعة'.tr}',
        ),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(_variants.length, (index) {
          final v = _variants[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${v.color} · ${v.size}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: AppFont.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${v.stock} ${'قطعة'.tr}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: AppHaptics.action(() => _editVariant(index)),
                    child: Text('تعديل'.tr),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: AppHaptics.action(
                      () => setState(() {
                        _variants.removeAt(index);
                        _dirty = true;
                      }),
                    ),
                    child: Text('حذف'.tr),
                  ),
                ],
              ),
            ),
          );
        }),
        AppButton(
          label: 'إضافة لون ومقاس'.tr,
          variant: AppButtonVariant.secondary,
          onPressed: () => _editVariant(),
        ),
        const SizedBox(height: AppSpacing.md),
        ProductSizeChartEditor(
          sizes: _variants.map((v) => v.size).toSet(),
          chart: _existingDetails['size_chart'],
          onChanged: (chart) => setState(() {
            _existingDetails = {..._existingDetails, 'size_chart': chart};
            _dirty = true;
          }),
        ),
      ],
    );
  }

  // Step 5: Review & Publish
  Widget _review() {
    final categories = ref.watch(shopCategoriesProvider).value ?? [];
    final matched = categories.where((c) => c.id == _categoryId);
    final categoryLabel =
        _newCategory ??
        (matched.isEmpty ? 'غير محدد'.tr : matched.first.name.tr);
    final totalUnits = _variants.fold<int>(0, (sum, v) => sum + v.stock);

    return _section(
      'راجع منتجك قبل النشر'.tr,
      'تأكد من السعر والصورة الرئيسية والمخزون. يمكنك الرجوع لأي مرحلة لتعديلها.'
          .tr,
      [
        if (_images.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Container(
              height: 200,
              color: AppColors.surfaceAlt,
              child: _imagePreview(_images.first),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _name.text.trim(),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: AppFont.bold),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _parsedPrice != null
                  ? AppFormat.price(_parsedPrice!)
                  : '${_price.text} ₪',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: AppFont.extraBold,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _description.text.trim(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Divider(height: AppSpacing.lg),
        _ReviewRow(label: 'التصنيف'.tr, value: categoryLabel),
        if (_brand.text.trim().isNotEmpty)
          _ReviewRow(label: 'الماركة'.tr, value: _brand.text.trim()),
        if (_material.text.trim().isNotEmpty)
          _ReviewRow(label: 'الخامة'.tr, value: _material.text.trim()),
        if (_care.text.trim().isNotEmpty)
          _ReviewRow(label: 'تعليمات العناية'.tr, value: _care.text.trim()),
        if (_sku.text.trim().isNotEmpty)
          _ReviewRow(label: 'رمز المنتج (SKU)'.tr, value: _sku.text.trim()),
        _ReviewRow(label: 'الصور'.tr, value: '${_images.length}'),
        _ReviewRow(
          label: 'المخزون'.tr,
          value:
              '${_variants.length} ${'خيارات'.tr} · $totalUnits ${'قطعة'.tr}',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: List.generate(
            4,
            (i) => ActionChip(
              label: Text('${'تعديل'.tr} ${_steps[i]}'),
              onPressed: AppHaptics.action(() => _go(i)),
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
          showBottomNav: false,
          showNotifications: false,
          body: ListView(
            padding: AppSpacing.page,
            children: [
              ShopNoticeBanner(
                title: 'تعذر فتح المنتج',
                message: 'حدث خطأ أثناء تحميل بيانات المنتج. حاول مرة أخرى.',
                tone: BadgeTone.error,
                actionLabel: 'إعادة المحاولة',
                onAction: () =>
                    ref.invalidate(shopProductProvider(widget.productId!)),
              ),
            ],
          ),
        );
      }
      if (!_seeded) {
        return ShopScaffold(
          title: 'تعديل منتج'.tr,
          showBottomNav: false,
          showNotifications: false,
          body: AppSkeleton(
            child: ListView(
              padding: AppSpacing.page,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بيانات المنتج'.tr),
                      const SizedBox(height: AppSpacing.sm),
                      Text('وصف المنتج'.tr),
                      const SizedBox(height: AppSpacing.md),
                      const SizedBox(height: 160),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final saving = ref.watch(shopCatalogActionProvider).isLoading;
    final lastStep = _steps.length - 1;

    return PopScope(
      canPop: _leaving || (!_dirty && !_processing && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: ShopScaffold(
        title: widget.productId == null ? 'إضافة منتج'.tr : 'تعديل منتج'.tr,
        showBottomNav: false,
        showNotifications: false,
        actions: [
          TextButton(
            onPressed: AppHaptics.action(
              saving || _processing ? null : () => _save(false),
            ),
            child: Text('حفظ كمسودة'.tr),
          ),
        ],
        body: AbsorbPointer(
          absorbing: saving,
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            controller: _scroll,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: AppSpacing.md),
                    switch (_step) {
                      0 => _basics(),
                      1 => _specs(),
                      2 => _photos(),
                      3 => _stock(),
                      _ => _review(),
                    },
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottom: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: AppButton(
                  label: 'السابق'.tr,
                  variant: AppButtonVariant.secondary,
                  onPressed: saving ? null : () => _go(_step - 1),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              flex: 2,
              child: AppButton(
                label: _step == lastStep
                    ? 'نشر المنتج'.tr
                    : '${'التالي'.tr}: ${_steps[_step + 1]}',
                isLoading: saving,
                onPressed: _step == lastStep
                    ? (_processing ? null : () => _save(true))
                    : _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChoiceRow extends StatelessWidget {
  const _QuickChoiceRow({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.translate = true,
    this.suffix = '',
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool translate;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: options.map((opt) {
        final display = translate ? opt.tr : '$opt$suffix';
        final matchValue = translate ? opt.tr : opt;
        final isSelected = selected == matchValue;
        return ChoiceChip(
          label: Text(display),
          selected: isSelected,
          onSelected: AppHaptics.change((_) => onSelected(opt)),
        );
      }).toList(),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: AppFont.semiBold),
            ),
          ),
        ],
      ),
    );
  }
}
