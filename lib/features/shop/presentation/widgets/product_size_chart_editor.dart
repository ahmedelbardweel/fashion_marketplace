import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../virtual_tryon/domain/body_measurements.dart';
import '../../../virtual_tryon/domain/size_recommendation.dart';
import '../../../virtual_tryon/presentation/measurement_editor.dart';

/// Product-specific body ranges are stored in the existing product details JSON.
class ProductSizeChartEditor extends StatelessWidget {
  const ProductSizeChartEditor({
    super.key,
    required this.sizes,
    required this.chart,
    required this.onChanged,
  });
  final Set<String> sizes;
  final dynamic chart;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    String t(String ar, String en) => measurementText(context, ar, en);
    final rows = readSizeChart(chart);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(AppIcons.ruler, color: AppColors.primary),
      title: Text(t('جدول قياسات المنتج', 'Product measurement chart')),
      subtitle: Text(
        t(
          'اختياري · لاقتراح المقاس المناسب للعميل',
          'Optional · helps suggest a size for the customer',
        ),
      ),
      children: [
        Text(
          t(
            'أدخل نطاق قياسات جسم العميل بالسنتيمتر حسب جدول الشركة، وليس أبعاد القطعة المفرودة. للصدر في القطع العلوية، وللخصر والورك في السفلية، ولطول القدم في الأحذية.',
            'Use customer body ranges in cm from the brand chart, not flat garment dimensions. Include chest for tops, waist and hips for bottoms, and foot length for footwear.',
          ),
          style: TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
        if (sizes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(t('أضف مقاساً أولاً', 'Add a size first')),
          ),
        for (final size in sizes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(size),
            subtitle: Text(
              rows.any((r) => r.size == size)
                  ? t('جدول القياسات جاهز', 'Measurement chart added')
                  : t('بدون قياسات', 'No measurements yet'),
            ),
            trailing: IconButton(
              tooltip: t('تعديل جدول القياسات', 'Edit measurement chart'),
              icon: const Icon(AppIcons.edit),
              onPressed: () async {
                final result = await showModalBottomSheet<SizeChartRow>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: .9,
                    child: _SizeRowEditor(
                      size: size,
                      initial: rows.where((r) => r.size == size).firstOrNull,
                    ),
                  ),
                );
                if (result == null) return;
                onChanged(
                  writeSizeChart([
                    ...rows.where((r) => r.size != size),
                    if (result.ranges.isNotEmpty) result,
                  ]),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SizeRowEditor extends StatefulWidget {
  const _SizeRowEditor({required this.size, this.initial});
  final String size;
  final SizeChartRow? initial;
  @override
  State<_SizeRowEditor> createState() => _SizeRowEditorState();
}

class _SizeRowEditorState extends State<_SizeRowEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<BodyMeasure, (TextEditingController, TextEditingController)>
  _fields;
  @override
  void initState() {
    super.initState();
    _fields = {
      for (final field in BodyMeasure.values.where(
        (f) => f != BodyMeasure.weight,
      ))
        field: (
          TextEditingController(
            text: widget.initial?.ranges[field] == null
                ? ''
                : measurementNumber(widget.initial!.ranges[field]!.$1),
          ),
          TextEditingController(
            text: widget.initial?.ranges[field] == null
                ? ''
                : measurementNumber(widget.initial!.ranges[field]!.$2),
          ),
        ),
    };
  }

  @override
  void dispose() {
    for (final pair in _fields.values) {
      pair.$1.dispose();
      pair.$2.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String ar, String en) => measurementText(context, ar, en);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t('قياسات المقاس', 'Measurements for size')} ${widget.size}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: t('إغلاق', 'Close'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t(
                          'كل القيم بالسنتيمتر. اترك القياس فارغاً إذا لم يرد في جدول الشركة.',
                          'All values are in cm. Leave measurements blank if they are not in the brand chart.',
                        ),
                      ),
                      for (final entry in _fields.entries) ...[
                        const SizedBox(height: 18),
                        Text(
                          measureLabel(context, entry.key),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0; i < 2; i++) ...[
                              if (i == 1) const SizedBox(width: 12),
                              Expanded(
                                child: AppTextField(
                                  key: ValueKey(
                                    'size-range-${entry.key.key}-$i',
                                  ),
                                  controller: i == 0
                                      ? entry.value.$1
                                      : entry.value.$2,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  label: i == 0
                                      ? t('من', 'From')
                                      : t('إلى', 'To'),
                                  errorMaxLines: 3,
                                  validator: (_) {
                                    final a = entry.value.$1.text.trim(),
                                        b = entry.value.$2.text.trim();
                                    if (a.isEmpty && b.isEmpty) return null;
                                    final low = parseMeasurement(a),
                                        high = parseMeasurement(b);
                                    if (low == null ||
                                        high == null ||
                                        !entry.key.accepts(low) ||
                                        !entry.key.accepts(high) ||
                                        low > high) {
                                      return t(
                                        'نطاق صحيح بين ${measurementNumber(entry.key.min)} و${measurementNumber(entry.key.max)}',
                                        'Valid range: ${measurementNumber(entry.key.min)}–${measurementNumber(entry.key.max)}',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!_form.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      SizeChartRow(widget.size, {
                        for (final entry in _fields.entries)
                          if (entry.value.$1.text.trim().isNotEmpty)
                            entry.key: (
                              parseMeasurement(entry.value.$1.text)!,
                              parseMeasurement(entry.value.$2.text)!,
                            ),
                      }),
                    );
                  },
                  child: Text(
                    t('حفظ نطاق القياسات', 'Save measurement ranges'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
