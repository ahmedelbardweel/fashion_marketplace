import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/domain/models/gaza_region.dart';
import '../../features/admin/presentation/providers/admin_providers.dart';
import '../theme/app_design.dart';
import 'app_bottom_sheet.dart';
import 'app_empty.dart';
import 'app_text_field.dart';

/// Returns true only when [value] matches one of the official Gaza Strip
/// governorates or neighborhoods managed by the platform.
bool isValidGazaRegionSelection(String value, List<GazaRegion> regions) {
  final clean = value.trim();
  if (clean.isEmpty) return false;
  final source = regions.isEmpty ? kDefaultGazaRegions : regions;
  final groups = groupGazaRegions(source);
  for (final group in groups) {
    final gov = group.governorate;
    if (clean == gov.name) return true;
    for (final area in group.areas) {
      if (clean == area.name || clean == '${gov.name} · ${area.name}') {
        return true;
      }
    }
  }
  return false;
}

/// Strictly enforced, read-only Gaza Strip city/region selector form field
/// matching the exact design of the product category field and BottomSheet.
class GazaRegionFormField extends ConsumerWidget {
  const GazaRegionFormField({
    super.key,
    required this.controller,
    this.label = 'المدينة *',
    this.placeholder = 'اختر المدينة أو الحي في قطاع غزة',
    this.sheetTitle = 'اختيار المدينة في قطاع غزة',
    this.enabled = true,
    this.onlyDeliveryAvailable = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final String sheetTitle;
  final bool enabled;
  final bool onlyDeliveryAvailable;
  final ValueChanged<GazaRegion>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions =
        ref.watch(gazaRegionsProvider).asData?.value ?? kDefaultGazaRegions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.tr,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: InputDesign.label,
            fontWeight: InputDesign.labelWeight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (ctx, value, _) {
            final selectedCity = value.text.trim();
            final isValid = isValidGazaRegionSelection(selectedCity, regions);
            return FormField<String>(
              initialValue: selectedCity,
              validator: (_) {
                final current = controller.text.trim();
                if (current.isEmpty) {
                  return 'يرجى اختيار المدينة من مناطق قطاع غزة'.tr;
                }
                if (!isValidGazaRegionSelection(current, regions)) {
                  return 'يرجى اختيار منطقة معتمدة من قائمة قطاع غزة'.tr;
                }
                return null;
              },
              builder: (fieldState) => InkWell(
                onTap: enabled
                    ? AppHaptics.action(() async {
                        FocusScope.of(ctx).unfocus();
                        final latestRegions =
                            ref.read(gazaRegionsProvider).asData?.value ??
                            kDefaultGazaRegions;
                        final picked = await showGazaRegionPickerSheet(
                          context: ctx,
                          regions: latestRegions,
                          selectedRegionName: selectedCity,
                          onlyDeliveryAvailable: onlyDeliveryAvailable,
                          title: sheetTitle,
                        );
                        if (picked == null || picked.name.isEmpty) return;
                        controller.text = picked.name;
                        fieldState.didChange(picked.name);
                        onChanged?.call(picked);
                      })
                    : null,
                borderRadius: BorderRadius.circular(InputDesign.radius),
                child: InputDecorator(
                  decoration: InputDecoration(
                    errorText: fieldState.errorText,
                    helperText: selectedCity.isNotEmpty && !isValid
                        ? 'يرجى تحديث المدينة باختيار منطقة معتمدة من القائمة'.tr
                        : null,
                  ),
                  isEmpty: selectedCity.isEmpty,
                  child: Text(
                    selectedCity.isEmpty ? placeholder.tr : selectedCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: selectedCity.isEmpty
                          ? AppColors.textMuted
                          : AppColors.text,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Full-height SafeArea Gaza Strip city/area picker matching the exact design
/// of the product category picker BottomSheet.
Future<GazaRegion?> showGazaRegionPickerSheet({
  required BuildContext context,
  required List<GazaRegion> regions,
  String? selectedRegionName,
  bool onlyDeliveryAvailable = false,
  bool allowClear = false,
  String? title,
}) {
  final source = regions.isEmpty ? kDefaultGazaRegions : regions;
  final groups = groupGazaRegions(source);
  final searchCtrl = TextEditingController();
  String? selectedGovId;

  return AppBottomSheet.show<GazaRegion?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    maxHeightFactor: 1.0,
    child: StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final q = searchCtrl.text.trim().toLowerCase();
        final visibleGroups = groups.where((g) {
          if (selectedGovId != null && g.governorate.id != selectedGovId) {
            return false;
          }
          if (q.isEmpty) return true;
          if (g.governorate.name.toLowerCase().contains(q) ||
              (g.governorate.nameEn?.toLowerCase().contains(q) ?? false)) {
            return true;
          }
          return g.areas.any(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                (a.nameEn?.toLowerCase().contains(q) ?? false),
          );
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        (title ?? 'اختيار المدينة في قطاع غزة').tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: SheetDesign.titleSize,
                          fontWeight: SheetDesign.titleWeight,
                        ),
                      ),
                      if (allowClear)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: AppHaptics.action(
                              () => Navigator.of(
                                sheetCtx,
                              ).pop(const GazaRegion(id: '', name: '')),
                            ),
                            child: Text('الكل'.tr),
                          ),
                        ),
                    ],
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
                        AppTextField(
                          controller: searchCtrl,
                          hint: 'ابحث باسم المحافظة أو الحي في قطاع غزة...'.tr,
                          onChanged: (_) => setSheetState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: AppSpacing.xs,
                                ),
                                child: ChoiceChip(
                                  label: Text('كل المحافظات'.tr),
                                  selected: selectedGovId == null,
                                  onSelected: AppHaptics.change(
                                    (_) => setSheetState(
                                      () => selectedGovId = null,
                                    ),
                                  ),
                                ),
                              ),
                              for (final g in groups)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: AppSpacing.xs,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      AppLang.isEn
                                          ? (g.governorate.nameEn ??
                                                g.governorate.name)
                                          : g.governorate.name,
                                    ),
                                    selected:
                                        selectedGovId == g.governorate.id,
                                    onSelected: AppHaptics.change(
                                      (_) => setSheetState(
                                        () =>
                                            selectedGovId = g.governorate.id,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (visibleGroups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Text(
                              'لا توجد مناطق مطابقة للبحث'.tr,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          )
                        else
                          for (final group in visibleGroups) ...[
                            _GovernorateBlock(
                              group: group,
                              query: q,
                              selectedRegionName: selectedRegionName,
                              onlyDeliveryAvailable: onlyDeliveryAvailable,
                              onPick: (picked) =>
                                  Navigator.of(sheetCtx).pop(picked),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(() {
    Future<void>.delayed(const Duration(milliseconds: 350), searchCtrl.dispose);
  });
}

class _GovernorateBlock extends StatelessWidget {
  const _GovernorateBlock({
    required this.group,
    required this.query,
    required this.selectedRegionName,
    required this.onlyDeliveryAvailable,
    required this.onPick,
  });

  final GazaGovernorateGroup group;
  final String query;
  final String? selectedRegionName;
  final bool onlyDeliveryAvailable;
  final ValueChanged<GazaRegion> onPick;

  @override
  Widget build(BuildContext context) {
    final gov = group.governorate;
    final govTitle = AppLang.isEn ? (gov.nameEn ?? gov.name) : gov.name;
    final areas = group.areas.where((a) {
      if (onlyDeliveryAvailable && !a.isDeliveryAvailable) return false;
      if (query.isEmpty) return true;
      if (gov.name.toLowerCase().contains(query) ||
          (gov.nameEn?.toLowerCase().contains(query) ?? false)) {
        return true;
      }
      return a.name.toLowerCase().contains(query) ||
          (a.nameEn?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                govTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.extraBold),
              ),
            ),
            if (!gov.isDeliveryAvailable)
              AppStatusBadge(
                label: 'التوصيل متوقف مؤقتاً',
                tone: BadgeTone.warning,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            if (!onlyDeliveryAvailable || gov.isDeliveryAvailable)
              ChoiceChip(
                label: Text(govTitle),
                selected: selectedRegionName == gov.name,
                onSelected: AppHaptics.change((_) => onPick(gov)),
              ),
            for (final area in areas)
              ChoiceChip(
                label: Text(
                  AppLang.isEn
                      ? '$govTitle · ${area.nameEn ?? area.name}'
                      : '${gov.name} · ${area.name}',
                ),
                selected:
                    selectedRegionName == area.name ||
                    selectedRegionName == '${gov.name} · ${area.name}' ||
                    selectedRegionName == '${gov.name} - ${area.name}',
                onSelected: onlyDeliveryAvailable && !area.isDeliveryAvailable
                    ? null
                    : AppHaptics.change(
                        (_) => onPick(
                          GazaRegion(
                            id: area.id,
                            parentId: area.parentId,
                            name: '${gov.name} · ${area.name}',
                            nameEn: area.nameEn,
                            governorateCode: area.governorateCode,
                            deliveryFee: area.deliveryFee,
                            estimatedDelivery: area.estimatedDelivery,
                            isDeliveryAvailable: area.isDeliveryAvailable,
                            isActive: area.isActive,
                            sortOrder: area.sortOrder,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}
