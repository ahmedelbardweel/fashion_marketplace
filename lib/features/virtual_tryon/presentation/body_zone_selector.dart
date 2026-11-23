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
            showZoneHighlight: false,
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

  Widget _addCompactButton({required Key cardKey}) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openMeasurementEditor(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Icon(
              AppIcons.add,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyMeasurementBar() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('edit-measurements'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openMeasurementEditor(),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(AppIcons.ruler, color: AppColors.primary, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('القياسات', 'Measurements'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.add, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _t('إضافة', 'Add'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedProfileChip(SavedBodyProfile item, bool isSelected) {
    final m = item.measurements;
    final estimated = SizeRecommendation.estimateFromBody(m, zone: selectedZone);
    final sizeBadge = selectedZone == TryonBodyZone.footwear
        ? (estimated?.shoeEu != null
              ? 'EU ${estimated!.shoeEu}'
              : estimated?.clothingLabel ?? '')
        : (estimated?.clothingLabel ?? '');

    return Material(
      color: isSelected ? AppColors.surfaceAlt : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('profile-card-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectProfile(item),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.borderStrong : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  AppIcons.checkCircleFilled,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              if (sizeBadge.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    sizeBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              InkWell(
                key: isSelected
                    ? const ValueKey('edit-measurements')
                    : ValueKey('edit-profile-${item.id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openMeasurementEditor(editing: item),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    AppIcons.edit,
                    size: 15,
                    color: AppColors.primary,
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
                    padding: const EdgeInsets.all(4),
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
        ),
      ),
    );
  }

  Widget _measurementCard() {
    final activeId = _activeProfile?.id;
    if (_loadingMeasurements) {
      return AppSkeleton(
        enabled: true,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    if (_loadFailed) {
      return Align(
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
      );
    }
    if (_profiles.isEmpty) {
      return _emptyMeasurementBar();
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _profiles.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _profiles.length) {
            return _addCompactButton(
              cardKey: const ValueKey('add-measurement-profile'),
            );
          }
          final item = _profiles[index];
          return _savedProfileChip(item, item.id == activeId);
        },
      ),
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
    var highlighted = match.status == SizeMatchStatus.matched;

    if (match.status == SizeMatchStatus.matched) {
      message = _t(
        'المقاس المقترح: ${match.size}',
        'Suggested size: ${match.size}',
      );
    } else if (match.status == SizeMatchStatus.outOfStock) {
      message = _t(
        'المقاس المطابق لقياساتك غير متوفر حالياً.',
        'The size matching your measurements is currently out of stock.',
      );
    } else if (match.status == SizeMatchStatus.noMatch) {
      message = _t(
        'المقاس التقريبي: ${estimated?.clothingLabel ?? '-'}',
        'Estimated size: ${estimated?.clothingLabel ?? '-'}',
      );
    } else if (estimated != null) {
      highlighted = true;
      final stockSuffix = estimated.matchedStockSize != null
          ? ' · ${_t('متوفر', 'In stock')}: ${estimated.matchedStockSize}'
          : '';
      if (selectedZone == TryonBodyZone.footwear && estimated.shoeEu != null) {
        message = _t(
          'المقاس المناسب: EU ${estimated.shoeEu}$stockSuffix',
          'Recommended size: EU ${estimated.shoeEu}$stockSuffix',
        );
      } else {
        message = _t(
          'المقاس المناسب: ${estimated.clothingLabel}$stockSuffix',
          'Recommended size: ${estimated.clothingLabel}$stockSuffix',
        );
      }
    } else {
      message = _t(
        'أكمل قياساتك لعرض المقاس المناسب.',
        'Complete measurements for size recommendation.',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.ruler,
              size: 16,
              color: highlighted ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: highlighted ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selectedProduct case final product?) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: product.tryonReferenceImage != null
                                      ? AppNetworkImage(
                                          product.tryonReferenceImage!,
                                          fit: BoxFit.cover,
                                          cacheWidth: 108,
                                          errorBuilder: (_, _, _) => Icon(
                                            AppIcons.garment,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Icon(
                                          AppIcons.garment,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _measurementCard(),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SizedBox(
                          height: (constraints.maxHeight * .40).clamp(
                            210.0,
                            275.0,
                          ),
                          child: ColorCodedBodyMap(
                            selectedZone: selectedZone,
                            onZoneTapped: onZoneSelected,
                            measurements: _measurements,
                          ),
                        ),
                      ),
                      _sizeSuggestion(),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final zone in TryonBodyZone.values)
                            ChoiceChip(
                              label: Text(_zoneLabel(zone)),
                              selected: selectedZone == zone,
                              showCheckmark: false,
                              onSelected: (_) => onZoneSelected(zone),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                color: selectedZone == zone
                                    ? AppColors.onPrimary
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: selectedZone == zone
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              side: BorderSide(
                                color: selectedZone == zone
                                    ? Colors.transparent
                                    : AppColors.border,
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
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
                        const SizedBox(width: 8),
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

enum _BodyBuildTier {
  slim('assets/images/tryon_body_model_slim.png', 18.8, 0.94),
  regular('assets/images/tryon_body_model.png', 23.0, 1.0),
  plus('assets/images/tryon_body_model_plus.png', 29.8, 1.08),
  xl('assets/images/tryon_body_model_xl.png', 36.5, 1.18);

  const _BodyBuildTier(this.assetPath, this.centerBmi, this.bracketWidthFactor);
  final String assetPath;
  final double centerBmi;
  final double bracketWidthFactor;

  static _BodyBuildTier fromMeasurements(BodyMeasurements? m) {
    final h = m?[BodyMeasure.height];
    final w = m?[BodyMeasure.weight];
    if (h == null || w == null || h <= 0 || w <= 0) return _BodyBuildTier.regular;
    final meters = h / 100.0;
    final bmi = w / (meters * meters);
    if (bmi < 20.5) return _BodyBuildTier.slim;
    if (bmi < 27.0) return _BodyBuildTier.regular;
    if (bmi < 33.0) return _BodyBuildTier.plus;
    return _BodyBuildTier.xl;
  }

  /// Subtle natural fine-tuning around the selected tier's realistic photo
  /// (never over-stretches the face).
  double fineWidthScale(BodyMeasurements? m) {
    final h = m?[BodyMeasure.height];
    final w = m?[BodyMeasure.weight];
    if (h == null || w == null || h <= 0 || w <= 0) return 1.0;
    final meters = h / 100.0;
    final bmi = w / (meters * meters);
    final ratio = math.sqrt(bmi / centerBmi);
    return ratio.clamp(0.93, 1.08);
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
    this.showZoneHighlight = true,
  });
  final TryonBodyZone selectedZone;
  final ValueChanged<TryonBodyZone> onZoneTapped;
  final BodyMeasurements? measurements;
  final bool showZoneHighlight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final geometry = _BodyGeometry(size, measurements);
      final tier = _BodyBuildTier.fromMeasurements(measurements);
      final modelWidth = 240.0 * geometry.scale;
      final modelHeight = 550.0 * geometry.scale * geometry.proportions.heightScale;
      final fineStretch = tier.fineWidthScale(measurements);

      return RepaintBoundary(
        child: Semantics(
          image: true,
          label: 'دليل مناطق الجسم'.tr,
          value: _zoneLabel(selectedZone),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final zone = geometry.hitTest(details.localPosition);
              if (zone != null) onZoneTapped(zone);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Subtle studio floor shadow & ambient glow behind real figure
                Positioned.fill(
                  child: CustomPaint(
                    key: ValueKey(
                      'body-bg-${showZoneHighlight ? selectedZone.name : 'none'}-${tier.name}',
                    ),
                    size: size,
                    painter: _BodyZoneHighlightPainter(
                      selectedZone: selectedZone,
                      primary: AppColors.primary,
                      neutral: AppColors.borderStrong,
                      measurements: measurements,
                      tier: tier,
                      layer: _BodyOverlayLayer.backdrop,
                      showZoneHighlight: showZoneHighlight,
                    ),
                  ),
                ),
                // Photorealistic full-body studio model matching user's BMI tier
                Positioned(
                  left: geometry.origin.dx - (modelWidth * fineStretch) / 2,
                  top: geometry.origin.dy,
                  width: modelWidth * fineStretch,
                  height: modelHeight,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Image.asset(
                      tier.assetPath,
                      key: ValueKey(tier.assetPath),
                      fit: BoxFit.fill,
                      cacheHeight: 680,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                // Interactive glowing zone scanner highlight over the real figure
                if (showZoneHighlight)
                  Positioned.fill(
                    child: CustomPaint(
                      key: ValueKey(
                        'body-fg-${selectedZone.name}-${tier.name}',
                      ),
                      size: size,
                      painter: _BodyZoneHighlightPainter(
                        selectedZone: selectedZone,
                        primary: AppColors.primary,
                        neutral: AppColors.borderStrong,
                        measurements: measurements,
                        tier: tier,
                        layer: _BodyOverlayLayer.foreground,
                        showZoneHighlight: true,
                      ),
                    ),
                  ),
              ],
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

enum _BodyOverlayLayer { backdrop, foreground }

class _BodyZoneHighlightPainter extends CustomPainter {
  const _BodyZoneHighlightPainter({
    required this.selectedZone,
    required this.primary,
    required this.neutral,
    required this.tier,
    required this.layer,
    this.measurements,
    this.showZoneHighlight = true,
  });
  final TryonBodyZone selectedZone;
  final Color primary, neutral;
  final _BodyBuildTier tier;
  final _BodyOverlayLayer layer;
  final BodyMeasurements? measurements;
  final bool showZoneHighlight;

  /// Anatomical bounding boxes on the 240×550 real model canvas (x centered at 0).
  List<Rect> _zoneRects(TryonBodyZone zone, double widthScale, double heightScale) {
    Rect scaled(double left, double top, double right, double bottom) => Rect.fromLTRB(
      left * widthScale,
      top * heightScale,
      right * widthScale,
      bottom * heightScale,
    );

    return switch (zone) {
      TryonBodyZone.headFace => [scaled(-34, 14, 34, 102)],
      TryonBodyZone.upperBody => [scaled(-82, 96, 82, 276)],
      TryonBodyZone.lowerShorts => [scaled(-52, 270, 52, 386)],
      TryonBodyZone.lowerPants => [scaled(-52, 270, 52, 492)],
      TryonBodyZone.fullBody => [scaled(-82, 96, 82, 492)],
      TryonBodyZone.footwear => [scaled(-56, 476, 56, 534)],
      TryonBodyZone.wristHand => [
        scaled(-90, 258, -46, 326),
        scaled(46, 258, 90, 326),
      ],
      TryonBodyZone.bags => [scaled(-84, 142, 84, 336)],
    };
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    final len = math.min(18.0, math.min(rect.width, rect.height) * 0.28);
    final r = 8.0;
    final path = Path()
      // Top-left
      ..moveTo(rect.left, rect.top + len)
      ..lineTo(rect.left, rect.top + r)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + r, rect.top)
      ..lineTo(rect.left + len, rect.top)
      // Top-right
      ..moveTo(rect.right - len, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + r)
      ..lineTo(rect.right, rect.top + len)
      // Bottom-left
      ..moveTo(rect.left, rect.bottom - len)
      ..lineTo(rect.left, rect.bottom - r)
      ..quadraticBezierTo(rect.left, rect.bottom, rect.left + r, rect.bottom)
      ..lineTo(rect.left + len, rect.bottom)
      // Bottom-right
      ..moveTo(rect.right - len, rect.bottom)
      ..lineTo(rect.right - r, rect.bottom)
      ..quadraticBezierTo(rect.right, rect.bottom, rect.right, rect.bottom - r)
      ..lineTo(rect.right, rect.bottom - len);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _BodyGeometry(size, measurements);
    final widthStretch =
        tier.bracketWidthFactor * tier.fineWidthScale(measurements);
    final heightScale = geometry.proportions.heightScale;

    canvas.save();
    canvas.translate(geometry.origin.dx, geometry.origin.dy);
    canvas.scale(geometry.scale);

    final rects = _zoneRects(selectedZone, widthStretch, heightScale);

    if (layer == _BodyOverlayLayer.backdrop) {
      // Soft floor shadow under shoes
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, 533 * heightScale),
          width: 118 * widthStretch,
          height: 12,
        ),
        Paint()..color = neutral.withValues(alpha: 0.28),
      );
      // Soft studio spotlight glow behind the active zone
      if (showZoneHighlight) {
        for (final rect in rects) {
          final glowRect = rect.inflate(24);
          canvas.drawOval(
            glowRect,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.22),
                  primary.withValues(alpha: 0.0),
                ],
              ).createShader(glowRect),
          );
        }
      }
    } else {
      // Sleek translucent zone highlight & studio scanner corner brackets
      final bracketPaint = Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (final rect in rects) {
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primary.withValues(alpha: 0.14),
                primary.withValues(alpha: 0.08),
                primary.withValues(alpha: 0.16),
              ],
            ).createShader(rect),
        );
        _drawCornerBrackets(canvas, rect, bracketPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyZoneHighlightPainter oldDelegate) =>
      selectedZone != oldDelegate.selectedZone ||
      measurements != oldDelegate.measurements ||
      primary != oldDelegate.primary ||
      neutral != oldDelegate.neutral ||
      tier != oldDelegate.tier ||
      layer != oldDelegate.layer ||
      showZoneHighlight != oldDelegate.showZoneHighlight;
}
