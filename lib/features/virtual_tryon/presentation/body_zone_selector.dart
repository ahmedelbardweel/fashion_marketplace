import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../customer/domain/models/customer_product.dart';
import '../data/body_measurement_store.dart';
import '../domain/body_measurements.dart';
import '../domain/size_recommendation.dart';
import '../domain/tryon_session.dart';
import 'measurement_editor.dart';

String _zoneLabel(TryonBodyZone zone) => switch (zone) {
  TryonBodyZone.upperBody => 'الجزء العلوي'.tr,
  TryonBodyZone.lowerPants => 'بنطلون'.tr,
  TryonBodyZone.lowerShorts => 'شورت'.tr,
  TryonBodyZone.fullBody => 'طقم كامل / فستان'.tr,
  TryonBodyZone.footwear => 'الأحذية'.tr,
  TryonBodyZone.headFace => 'رأس / نظارات'.tr,
  TryonBodyZone.wristHand => 'ساعة / معصم'.tr,
  TryonBodyZone.bags => 'شنط / حقائب'.tr,
};

class InteractiveBodyZoneSelector extends StatefulWidget {
  const InteractiveBodyZoneSelector({
    super.key,
    required this.selectedZone,
    required this.onZoneSelected,
    required this.onContinue,
    this.selectedProduct,
    this.availableProducts = const [],
    this.onProductSelected,
    this.measurementProfileId = 'guest',
  });

  final TryonBodyZone selectedZone;
  final ValueChanged<TryonBodyZone> onZoneSelected;
  final VoidCallback onContinue;
  final CustomerProduct? selectedProduct;
  final List<CustomerProduct> availableProducts;
  final ValueChanged<CustomerProduct>? onProductSelected;
  final String measurementProfileId;

  @override
  State<InteractiveBodyZoneSelector> createState() =>
      _InteractiveBodyZoneSelectorState();
}

class _InteractiveBodyZoneSelectorState
    extends State<InteractiveBodyZoneSelector> {
  BodyProfileCollection _profileCollection = BodyProfileCollection.empty;
  bool _loadingMeasurements = true;
  bool _loadFailed = false;
  int _loadRevision = 0;
  late BodyMeasurementStore _store;

  BodyMeasurements? get _measurements =>
      _profileCollection.activeProfile?.measurements;
  List<SavedBodyProfile> get _profiles => _profileCollection.profiles;
  SavedBodyProfile? get _activeProfile => _profileCollection.activeProfile;

  TryonBodyZone get selectedZone => widget.selectedZone;
  CustomerProduct? get selectedProduct => widget.selectedProduct;
  ValueChanged<TryonBodyZone> get onZoneSelected => widget.onZoneSelected;
  VoidCallback get onContinue => widget.onContinue;

  String _t(String ar, String en) => measurementText(context, ar, en);

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  @override
  void didUpdateWidget(covariant InteractiveBodyZoneSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measurementProfileId != widget.measurementProfileId) {
      _profileCollection = BodyProfileCollection.empty;
      _loadMeasurements();
    }
  }

  Future<void> _loadMeasurements() async {
    final revision = ++_loadRevision;
    _store = BodyMeasurementStore(widget.measurementProfileId);
    setState(() {
      _loadingMeasurements = true;
      _loadFailed = false;
    });
    try {
      final loaded = await _store.loadProfiles();
      if (mounted && revision == _loadRevision) {
        setState(() => _profileCollection = loaded);
      }
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        setState(() => _loadFailed = true);
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loadingMeasurements = false);
      }
    }
  }

  Future<void> _openMeasurementEditor({SavedBodyProfile? editing}) async {
    final store = _store;
    final revision = _loadRevision;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => FractionallySizedBox(
        heightFactor: .94,
        child: MeasurementEditor(
          initial: editing?.measurements,
          initialLabel: editing?.label,
          showProfileLabel: true,
          previewBuilder: (draft) => ColorCodedBodyMap(
            selectedZone: selectedZone,
            onZoneTapped: (_) {},
            measurements: draft,
          ),
          onSaveProfile: (value, label) async {
            final fallbackName = _t(
              'شخص ${_profiles.length + 1}',
              'Person ${_profiles.length + 1}',
            );
            final updated = await store.upsertProfile(
              id: editing?.id,
              label: label.isEmpty ? (editing?.label ?? fallbackName) : label,
              measurements: value,
            );
            if (mounted && revision == _loadRevision) {
              setState(() => _profileCollection = updated);
            }
          },
        ),
      ),
    );
  }

  Future<void> _selectProfile(SavedBodyProfile profile) async {
    if (profile.id == _activeProfile?.id) return;
    final revision = _loadRevision;
    final store = _store;
    setState(() {
      _profileCollection = BodyProfileCollection(
        profiles: _profileCollection.profiles,
        activeId: profile.id,
      );
    });
    try {
      final updated = await store.selectProfile(profile.id);
      if (mounted && revision == _loadRevision) {
        setState(() => _profileCollection = updated);
      }
    } catch (_) {}
  }

  Future<void> _deleteProfile(SavedBodyProfile profile) async {
    final revision = _loadRevision;
    final store = _store;
    try {
      final updated = await store.deleteProfile(profile.id);
      if (mounted && revision == _loadRevision) {
        setState(() => _profileCollection = updated);
      }
    } catch (_) {
      if (mounted && revision == _loadRevision) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'تعذر حذف القياسات. حاول مجدداً.',
                'Could not delete measurements. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Widget _addSquareCard({required Key cardKey}) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openMeasurementEditor(),
        child: Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              AppIcons.add,
              size: 32,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _savedProfileSquareCard(SavedBodyProfile item, bool isSelected) {
    final m = item.measurements;
    final estimated = SizeRecommendation.estimateFromBody(m, zone: selectedZone);
    final sizeBadge = selectedZone == TryonBodyZone.footwear
        ? (estimated?.shoeEu != null
              ? 'EU ${estimated!.shoeEu}'
              : estimated?.clothingLabel ?? '')
        : (estimated?.clothingLabel ?? '');

    return Material(
      color: isSelected ? AppColors.primarySoft : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('profile-card-${item.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectProfile(item),
        child: Container(
          width: 118,
          height: 118,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.primaryDark : AppColors.text,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _deleteProfile(item),
                    child: Tooltip(
                      message: isSelected
                          ? _t(
                              'حذف القياسات المحفوظة',
                              'Delete saved measurements',
                            )
                          : _t('حذف', 'Delete'),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          AppIcons.delete,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (sizeBadge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sizeBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              Text(
                '${measurementNumber(m[BodyMeasure.height]!)} ${_t('سم', 'cm')} · ${measurementNumber(m[BodyMeasure.weight]!)} ${_t('كغ', 'kg')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  key: isSelected
                      ? const ValueKey('edit-measurements')
                      : ValueKey('edit-profile-${item.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openMeasurementEditor(editing: item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.edit,
                          size: 13,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _t('تعديل', 'Edit'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
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

  Widget _measurementCard() {
    final activeId = _activeProfile?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(AppIcons.ruler, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t('القياسات', 'Measurements'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            if (_profiles.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_profiles.length}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            'أضف قياساتك أو قياسات أكثر من شخص لتحديد المقاس وتخصيص الهيكل قبل تركيب الملابس.',
            'Add measurements for yourself or multiple people to personalize the figure and fit before trying clothes on.',
          ),
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingMeasurements)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (_loadFailed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _loadMeasurements,
              child: Text(
                _t(
                  'تعذر تحميل القياسات · إعادة المحاولة',
                  'Could not load measurements · Retry',
                ),
              ),
            ),
          )
        else if (_profiles.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _addSquareCard(
              cardKey: const ValueKey('edit-measurements'),
            ),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _profiles.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == _profiles.length) {
                  return _addSquareCard(
                    cardKey: const ValueKey('add-measurement-profile'),
                  );
                }
                final item = _profiles[index];
                return _savedProfileSquareCard(item, item.id == activeId);
              },
            ),
          ),
      ],
    );
  }

  Widget _sizeSuggestion() {
    final product = selectedProduct;
    final measurements = _measurements;
    if (product == null || measurements == null) return const SizedBox.shrink();
    final match = SizeRecommendation.evaluate(
      measurements: measurements,
      chart: product.details['size_chart'],
      availableSizes: product.availableSizes,
      zone: selectedZone,
    );
    final estimated = SizeRecommendation.estimateFromBody(
      measurements,
      zone: selectedZone,
      availableSizes: product.availableSizes,
    );

    late final String message;
    late final String detail;
    var highlighted = match.status == SizeMatchStatus.matched;

    if (match.status == SizeMatchStatus.matched) {
      message = _t(
        'المقاس المقترح: ${match.size}',
        'Suggested size: ${match.size}',
      );
      detail = _t(
        'حسب جدول هذا المنتج والمقاسات المتوفرة؛ قد تختلف الراحة حسب القَصّة.',
        'Based on this product chart and available sizes; comfort can vary with the cut.',
      );
    } else if (match.status == SizeMatchStatus.outOfStock) {
      message = _t(
        'المقاس المطابق لقياساتك غير متوفر حالياً.',
        'The size matching your measurements is currently out of stock.',
      );
      detail = _t(
        'جرّب اختيار مقاس قريب من المقاسات المتوفرة.',
        'Try picking the closest available size.',
      );
    } else if (match.status == SizeMatchStatus.noMatch) {
      message = _t(
        'لا يوجد مقاس في الجدول يطابق القياسات المدخلة.',
        'No chart size matches the measurements entered.',
      );
      detail = _t(
        'مقاسك التقريبي من الوزن والطول: ${estimated?.clothingLabel ?? '-'}',
        'Estimated from weight & height: ${estimated?.clothingLabel ?? '-'}',
      );
    } else if (estimated != null) {
      highlighted = true;
      final h = measurementNumber(measurements[BodyMeasure.height]!);
      final w = measurementNumber(measurements[BodyMeasure.weight]!);
      if (selectedZone == TryonBodyZone.footwear && estimated.shoeEu != null) {
        final foot = measurementNumber(measurements[BodyMeasure.footLength]!);
        final stockSuffix = estimated.matchedStockSize != null
            ? '  ·  ${_t('متوفر', 'In stock')}: ${estimated.matchedStockSize}'
            : '';
        message = _t(
          'مقاس الحذاء المناسب لك: EU ${estimated.shoeEu}$stockSuffix',
          'Your recommended shoe size: EU ${estimated.shoeEu}$stockSuffix',
        );
        detail = _t(
          'تم حسابه مباشرة من طول القدم ($foot سم).',
          'Calculated directly from your foot length ($foot cm).',
        );
      } else {
        final stockSuffix = estimated.matchedStockSize != null
            ? '  ·  ${_t('متوفر', 'In stock')}: ${estimated.matchedStockSize}'
            : '';
        message = _t(
          'المقاس المناسب لك: ${estimated.clothingLabel}$stockSuffix',
          'Your recommended size: ${estimated.clothingLabel}$stockSuffix',
        );
        detail = _t(
          'تم حسابه من طولك ($h سم) ووزنك ($w كغ) بناءً على قياساتك.',
          'Calculated directly from your height ($h cm) and weight ($w kg).',
        );
      }
    } else {
      message = _t(
        'أكمل بيانات الوزن والطول وطول القدم.',
        'Complete your weight, height and foot length.',
      );
      detail = _t(
        'أدخل قياساتك لعرض المقاس المناسب لك مباشرة.',
        'Enter your measurements to see your recommended size.',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: highlighted ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selectedProduct case final product?) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: product.tryonReferenceImage != null
                                      ? AppNetworkImage(
                                          product.tryonReferenceImage!,
                                          fit: BoxFit.cover,
                                          cacheWidth: 144,
                                          errorBuilder: (_, _, _) => Icon(
                                            AppIcons.garment,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Icon(
                                          AppIcons.garment,
                                          color: AppColors.primary,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'القطعة المختارة'.tr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        'اختر منطقة التجربة'.tr,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'المس منطقة على الجسم أو اختر من الخيارات أدناه.'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _measurementCard(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  AppIcons.bodyGuide,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'منظر أمامي'.tr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  AppIcons.focus,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: (constraints.maxHeight * .58).clamp(
                                300.0,
                                410.0,
                              ),
                              child: ColorCodedBodyMap(
                                selectedZone: selectedZone,
                                onZoneTapped: onZoneSelected,
                                measurements: _measurements,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_measurements != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  _t(
                                    'هيكل تقريبي حسب قياساتك',
                                    'Approximate figure based on your measurements',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      AppIcons.checkCircle,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _zoneLabel(selectedZone),
                                            style: TextStyle(
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            selectedZone.framingInstruction.tr,
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sizeSuggestion(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final zone in TryonBodyZone.values)
                            ChoiceChip(
                              label: Text(_zoneLabel(zone)),
                              selected: selectedZone == zone,
                              onSelected: (_) => onZoneSelected(zone),
                              selectedColor: AppColors.primarySoft,
                              backgroundColor: AppColors.surface,
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: selectedZone == zone
                                    ? AppColors.primaryDark
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: selectedZone == zone
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: selectedZone == zone
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onContinue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'ابدأ التجربة'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(AppIcons.forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Drawing and hit testing share a fixed coordinate system: resizing never
/// stretches the figure or changes which anatomical region receives a tap.
class ColorCodedBodyMap extends StatelessWidget {
  const ColorCodedBodyMap({
    super.key,
    required this.selectedZone,
    required this.onZoneTapped,
    this.measurements,
  });
  final TryonBodyZone selectedZone;
  final ValueChanged<TryonBodyZone> onZoneTapped;
  final BodyMeasurements? measurements;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final geometry = _BodyGeometry(size, measurements);
      return Semantics(
        image: true,
        label: 'دليل مناطق الجسم'.tr,
        value: _zoneLabel(selectedZone),
        child: GestureDetector(
          onTapUp: (details) {
            final zone = geometry.hitTest(details.localPosition);
            if (zone != null) onZoneTapped(zone);
          },
          child: CustomPaint(
            size: size,
            painter: _BodyPainter(
              selectedZone: selectedZone,
              primary: AppColors.primary,
              neutral: AppColors.borderStrong,
              surface: AppColors.surfaceAlt,
              outline: AppColors.textMuted,
              measurements: measurements,
            ),
          ),
        ),
      );
    },
  );
}

class _BodyGeometry {
  _BodyGeometry(this.size, [BodyMeasurements? measurements])
    : proportions = BodyProportions(measurements);
  final Size size;
  final BodyProportions proportions;
  late final Path upperPath = projectPath(upper);
  late final Path shortsPath = projectPath(shorts);
  late final Path calvesPath = projectPath(calves);
  late final Path feetPath = projectPath(feet);
  late final Path headNeckPath = Path()
    ..addPath(projectPath(head), Offset.zero)
    ..addPath(projectPath(neck), Offset.zero);
  late final Path handsPath = Path()
    ..addPath(projectPath(hand), Offset.zero)
    ..addPath(projectPath(mirror(hand)), Offset.zero);
  late final double _drawingWidth = math.max(
    240,
    upperPath.getBounds().width + 40,
  );
  late final double scale = math.min(
    size.width / _drawingWidth,
    size.height / math.max(550, 550 * proportions.heightScale),
  );
  late final Offset origin = Offset(
    size.width / 2,
    (size.height - scale * 550 * proportions.heightScale) / 2,
  );

  Offset project(Offset p) {
    if (proportions.measurements == null) return p;
    var x = p.dx * proportions.widthAt(p.dy);
    // Keep arm centerlines smooth: changing the waist must not bend elbows or
    // wrists. Translate the arms outward and scale their thickness separately.
    if (p.dy >= 145 && p.dy <= 315 && p.dx.abs() > 38) {
      final center = 48 + (p.dy - 145) * .18;
      final shift = math.max(
        (proportions.widthAt(165) - 1) * 38,
        (proportions.widthAt(235) - 1) * 30,
      );
      final thickness = math.sqrt(proportions.widthAt(165)).clamp(.85, 1.45);
      final armX =
          p.dx.sign * (center + shift + (p.dx.abs() - center) * thickness);
      final blend =
          ((p.dy - 145) / 35).clamp(0.0, 1.0) *
          ((p.dx.abs() - 38) / 10).clamp(0.0, 1.0);
      x += (armX - x) * blend;
    }
    if (p.dy > 492) {
      final blend = ((p.dy - 492) / 35).clamp(0.0, 1.0);
      final footX =
          p.dx.sign *
          (22 * proportions.widthAt(492) +
              (p.dx.abs() - 22) *
                  proportions.footScale /
                  math.sqrt(proportions.heightRatio));
      x += (footX - x) * blend;
    }
    final inseam = proportions.measurements?[BodyMeasure.inseam];
    final legRatio = inseam == null
        ? 1.0
        : (inseam / (175 * proportions.heightRatio * .45)).clamp(.75, 1.25);
    final crotch = 527 - (527 - 292) * legRatio;
    final y = p.dy < 292
        ? p.dy * crotch / 292
        : crotch + (p.dy - 292) * legRatio;
    return Offset(x, y * proportions.heightScale);
  }

  Path projectPath(Path source) {
    if (proportions.measurements == null) return source;
    final result = Path();
    for (final contour in source.computeMetrics()) {
      final first = project(contour.getTangentForOffset(0)!.position);
      result.moveTo(first.dx, first.dy);
      for (var distance = 2.0; distance < contour.length; distance += 2) {
        final point = project(contour.getTangentForOffset(distance)!.position);
        result.lineTo(point.dx, point.dy);
      }
      final last = project(
        contour.getTangentForOffset(contour.length)!.position,
      );
      result.lineTo(last.dx, last.dy);
      if (contour.isClosed) result.close();
    }
    return result;
  }

  static Path mirror(Path path) => path.transform(
    Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
  );

  static final head = Path()
    ..moveTo(0, 18)
    ..cubicTo(-20, 18, -23, 34, -21, 50)
    ..cubicTo(-20, 65, -12, 78, 0, 80)
    ..cubicTo(12, 78, 20, 65, 21, 50)
    ..cubicTo(23, 34, 20, 18, 0, 18)
    ..close();
  static final neck = Path()
    ..moveTo(-11, 73)
    ..lineTo(-11, 90)
    ..quadraticBezierTo(-15, 98, -23, 101)
    ..quadraticBezierTo(0, 115, 23, 101)
    ..quadraticBezierTo(15, 98, 11, 90)
    ..lineTo(11, 73)
    ..close();

  static final upper = Path()
    ..moveTo(-12, 95)
    ..quadraticBezierTo(-23, 100, -40, 104)
    ..cubicTo(-51, 108, -55, 121, -57, 139)
    ..lineTo(-66, 190)
    ..quadraticBezierTo(-73, 228, -80, 270)
    ..lineTo(-66, 274)
    ..quadraticBezierTo(-51, 234, -49, 206)
    ..lineTo(-39, 157)
    ..cubicTo(-37, 185, -28, 210, -29, 245)
    ..quadraticBezierTo(0, 250, 29, 245)
    ..cubicTo(28, 210, 37, 185, 39, 157)
    ..lineTo(49, 206)
    ..quadraticBezierTo(51, 234, 66, 274)
    ..lineTo(80, 270)
    ..quadraticBezierTo(73, 228, 66, 190)
    ..lineTo(57, 139)
    ..cubicTo(55, 121, 51, 108, 40, 104)
    ..quadraticBezierTo(23, 100, 12, 95)
    ..quadraticBezierTo(0, 105, -12, 95)
    ..close();

  static final hand = Path()
    ..moveTo(-79, 269)
    ..lineTo(-67, 273)
    ..quadraticBezierTo(-64, 282, -63, 290)
    ..quadraticBezierTo(-64, 295, -68, 289)
    ..lineTo(-70, 285)
    ..lineTo(-71, 304)
    ..quadraticBezierTo(-77, 312, -82, 302)
    ..quadraticBezierTo(-87, 291, -79, 269)
    ..close();

  static final shorts = Path()
    ..moveTo(-29, 245)
    ..quadraticBezierTo(0, 250, 29, 245)
    ..cubicTo(36, 264, 37, 282, 35, 303)
    ..lineTo(29, 356)
    ..lineTo(9, 356)
    ..lineTo(5, 306)
    ..quadraticBezierTo(0, 290, -5, 306)
    ..lineTo(-9, 356)
    ..lineTo(-29, 356)
    ..lineTo(-35, 303)
    ..cubicTo(-37, 282, -36, 264, -29, 245)
    ..close();

  static final calf = Path()
    ..moveTo(-29, 356)
    ..lineTo(-9, 356)
    ..cubicTo(-8, 378, -7, 390, -10, 410)
    ..cubicTo(-13, 439, -16, 468, -15, 492)
    ..lineTo(-29, 492)
    ..cubicTo(-28, 468, -34, 439, -35, 413)
    ..cubicTo(-36, 392, -30, 375, -29, 356)
    ..close();

  static final foot = Path()
    ..moveTo(-29, 492)
    ..lineTo(-15, 492)
    ..lineTo(-14, 516)
    ..quadraticBezierTo(-14, 525, -22, 527)
    ..lineTo(-42, 527)
    ..quadraticBezierTo(-49, 525, -45, 518)
    ..quadraticBezierTo(-31, 503, -29, 492)
    ..close();

  static final calves = Path()
    ..addPath(calf, Offset.zero)
    ..addPath(mirror(calf), Offset.zero);
  static final feet = Path()
    ..addPath(foot, Offset.zero)
    ..addPath(mirror(foot), Offset.zero);

  TryonBodyZone? hitTest(Offset position) {
    if (scale <= 0) return null;
    final point = (position - origin) / scale;
    if (upperPath.contains(point)) return TryonBodyZone.upperBody;
    if (shortsPath.contains(point)) return TryonBodyZone.lowerShorts;
    if (calvesPath.contains(point)) return TryonBodyZone.lowerPants;
    if (feetPath.contains(point)) return TryonBodyZone.footwear;
    if (headNeckPath.contains(point)) return TryonBodyZone.headFace;
    if (handsPath.contains(point)) return TryonBodyZone.wristHand;
    return null;
  }
}

class _BodyPainter extends CustomPainter {
  const _BodyPainter({
    required this.selectedZone,
    required this.primary,
    required this.neutral,
    required this.surface,
    required this.outline,
    this.measurements,
  });
  final TryonBodyZone selectedZone;
  final Color primary, neutral, surface, outline;
  final BodyMeasurements? measurements;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _BodyGeometry(size, measurements);
    canvas.save();
    canvas.translate(geometry.origin.dx, geometry.origin.dy);
    canvas.scale(geometry.scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: geometry.project(const Offset(0, 535)),
        width: 115 * geometry.proportions.widthAt(492),
        height: 10,
      ),
      Paint()..color = neutral.withValues(alpha: .3),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-110, 58, 220, 440),
      Paint()
        ..shader = RadialGradient(
          colors: [
            primary.withValues(alpha: .08),
            primary.withValues(alpha: 0),
          ],
        ).createShader(const Rect.fromLTWH(-110, 58, 220, 440)),
    );

    void draw(Path path, {bool active = false}) {
      path = geometry.projectPath(path);
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: active
                ? [
                    Color.lerp(primary, AppPalette.white, .18)!,
                    primary,
                    Color.lerp(primary, AppPalette.ink, .12)!,
                  ]
                : [surface, neutral, surface],
            stops: const [0, .55, 1],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = active ? primary : outline.withValues(alpha: .42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.6 : 1
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final full = selectedZone == TryonBodyZone.fullBody;
    final headActive = selectedZone == TryonBodyZone.headFace;
    final handActive =
        selectedZone == TryonBodyZone.wristHand ||
        selectedZone == TryonBodyZone.bags;
    draw(_BodyGeometry.neck, active: headActive);
    draw(_BodyGeometry.head, active: headActive);
    draw(_BodyGeometry.hand, active: handActive);
    draw(_BodyGeometry.mirror(_BodyGeometry.hand), active: handActive);
    draw(
      _BodyGeometry.upper,
      active: full || selectedZone == TryonBodyZone.upperBody,
    );
    draw(
      _BodyGeometry.shorts,
      active:
          full ||
          selectedZone == TryonBodyZone.lowerShorts ||
          selectedZone == TryonBodyZone.lowerPants,
    );
    draw(
      _BodyGeometry.calves,
      active: full || selectedZone == TryonBodyZone.lowerPants,
    );
    draw(_BodyGeometry.feet, active: selectedZone == TryonBodyZone.footwear);

    // Subtle collarbones and joint contours give the neutral mannequin form.
    final detail = Paint()
      ..color = outline.withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final collar = Path()
      ..moveTo(-30, 115)
      ..quadraticBezierTo(-16, 113, -5, 121);
    canvas.drawPath(geometry.projectPath(collar), detail);
    canvas.drawPath(geometry.projectPath(_BodyGeometry.mirror(collar)), detail);
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        geometry.projectPath(
          Path()
            ..moveTo(12 * side, 367)
            ..quadraticBezierTo(20 * side, 372, 27 * side, 367),
        ),
        detail,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter oldDelegate) =>
      selectedZone != oldDelegate.selectedZone ||
      measurements != oldDelegate.measurements ||
      primary != oldDelegate.primary ||
      neutral != oldDelegate.neutral ||
      surface != oldDelegate.surface ||
      outline != oldDelegate.outline;
}
