import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/body_measurements.dart';
import '../domain/size_recommendation.dart';

String measurementText(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

String measureLabel(BuildContext context, BodyMeasure field) =>
    measurementText(context, field.ar, field.en);

class MeasurementEditor extends StatefulWidget {
  const MeasurementEditor({
    super.key,
    this.initial,
    this.initialLabel,
    this.showProfileLabel = false,
    this.onSave,
    this.onSaveProfile,
    required this.previewBuilder,
  }) : assert(onSave != null || onSaveProfile != null);
  final BodyMeasurements? initial;
  final String? initialLabel;
  final bool showProfileLabel;
  final Future<void> Function(BodyMeasurements)? onSave;
  final Future<void> Function(BodyMeasurements value, String label)?
  onSaveProfile;
  final Widget Function(BodyMeasurements?) previewBuilder;
  @override
  State<MeasurementEditor> createState() => _MeasurementEditorState();
}

class _MeasurementEditorState extends State<MeasurementEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<BodyMeasure, TextEditingController> _fields;
  late final TextEditingController _labelController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel ?? '');
    _fields = {
      for (final field in BodyMeasurements.customerFields)
        field: TextEditingController(
          text: widget.initial?[field] == null
              ? ''
              : measurementNumber(widget.initial![field]!),
        ),
    };
  }

  @override
  void dispose() {
    _labelController.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  BodyMeasurements get _draft => BodyMeasurements(
    values: {
      for (final entry in _fields.entries)
        if (parseMeasurement(entry.value.text) case final value?)
          if (entry.key.accepts(value)) entry.key: value,
    },
  );

  String _t(String ar, String en) => measurementText(context, ar, en);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onSaveProfile != null) {
        await widget.onSaveProfile!(_draft, _labelController.text.trim());
      } else {
        await widget.onSave!(_draft);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _t(
            'تعذر حفظ القياسات. حاول مجدداً.',
            'Could not save your measurements. Please try again.',
          );
        });
      }
    }
  }

  Widget _field(BodyMeasure field) => AppTextField(
    key: ValueKey('measurement-${field.key}'),
    controller: _fields[field],
    enabled: !_saving,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    onChanged: (_) => setState(() {}),
    label: measureLabel(context, field),
    prefixIcon: AppIcons.ruler,
    suffixText: field == BodyMeasure.weight ? _t('كغ', 'kg') : _t('سم', 'cm'),
    helperText: field == BodyMeasure.footLength
        ? _t('من الكعب لأطول إصبع', 'Heel to longest toe')
        : null,
    helperMaxLines: 2,
    errorMaxLines: 2,
    validator: (text) {
      if (text == null || text.trim().isEmpty) {
        return _t('أدخل هذا القياس', 'Enter this measurement');
      }
      final value = parseMeasurement(text);
      if (value == null || !field.accepts(value)) {
        return _t(
          'أدخل قيمة بين ${measurementNumber(field.min)} و${measurementNumber(field.max)}',
          'Enter a value from ${measurementNumber(field.min)} to ${measurementNumber(field.max)}',
        );
      }
      return null;
    },
  );

  Widget _group(List<BodyMeasure> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.maxWidth >= 350 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      return Wrap(
        spacing: 12,
        runSpacing: 18,
        children: [
          for (final field in fields)
            SizedBox(
              width: twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              child: _field(field),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
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
                      _t('قياساتي', 'My measurements'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: _t('إغلاق', 'Close'),
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
                        _t(
                          'أدخل وزنك وطولك وطول قدمك فقط. يمكنك تعديلها لاحقاً.',
                          'Enter only your weight, height and foot length. You can edit them later.',
                        ),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: widget.previewBuilder(
                          _draft.hasBasics ? _draft : null,
                        ),
                      ),
                      Text(
                        _t(
                          'شكل تقريبي حسب قياساتك',
                          'Approximate shape based on your measurements',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (SizeRecommendation.estimateFromBody(_draft)
                          case final est?) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.borderStrong,
                              ),
                            ),
                            child: Text(
                              est.shoeEu != null
                                  ? '${_t('مقاسك المتوقع', 'Your estimated size')}: ${est.clothingLabel}  ·  EU ${est.shoeEu}'
                                  : '${_t('مقاسك المتوقع', 'Your estimated size')}: ${est.clothingLabel}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (widget.showProfileLabel) ...[
                        TextField(
                          key: const ValueKey('measurement-profile-label'),
                          controller: _labelController,
                          enabled: !_saving,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: _t(
                              'اسم الشخص (اختياري)',
                              'Person name (optional)',
                            ),
                            hintText: _t(
                              'مثال: قياساتي، أحمد، سارة...',
                              'e.g. Me, Ahmed, Sara...',
                            ),
                            prefixIcon: Icon(AppIcons.user, size: 19),
                            filled: true,
                            fillColor: AppColors.surfaceAlt,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _group([BodyMeasure.weight, BodyMeasure.height]),
                      const SizedBox(height: 20),
                      _field(BodyMeasure.footLength),
                      const SizedBox(height: 16),
                      Text(
                        _t(
                          'تُحفظ القياسات لهذا الحساب على هذا الجهاز. اقتراح المقاس يعتمد على جدول المنتج؛ الشكل المعروض تقديري.',
                          'Measurements are saved for this account on this device. Size suggestions use the product chart; the figure is an estimate.',
                        ),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
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
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(
                    _saving
                        ? _t('جارٍ الحفظ…', 'Saving…')
                        : _t('حفظ القياسات', 'Save measurements'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
