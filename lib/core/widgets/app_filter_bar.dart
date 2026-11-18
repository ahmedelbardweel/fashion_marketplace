import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../filtering/filter_models.dart';
import '../search/smart_search_sheets.dart';
import '../search/visual_search_service.dart';
import '../theme/app_design.dart';
import '../utils/app_haptics.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_empty.dart';

/// Quick pill option rendered inside [AppFilterToolbar].
class AppQuickFilterOption {
  const AppQuickFilterOption({
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    this.swatchColor,
  });

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;
  final Color? swatchColor;
}

/// Active removable filter tag rendered below the toolbar.
class AppActiveFilterTag {
  const AppActiveFilterTag({
    required this.label,
    required this.onRemove,
    this.swatchColor,
  });

  final String label;
  final VoidCallback onRemove;
  final Color? swatchColor;
}

/// Option item used in [showAppSortSheet].
class AppSortChoice<T> {
  const AppSortChoice({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Opens a unified bottom sheet to choose a sort order.
Future<T?> showAppSortSheet<T>({
  required BuildContext context,
  required T current,
  required List<AppSortChoice<T>> options,
  String title = 'ترتيب النتائج',
}) {
  return AppBottomSheet.show<T>(
    context: context,
    child: AppBottomSheetScaffold(
      title: title.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt.value == current;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: AppHaptics.action(
                () => Navigator.of(context).pop(opt.value),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarySoft
                      : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryBorder
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        size: 18,
                        color: isSelected ? AppColors.primaryDark : AppColors.icon,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        opt.label.tr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? AppFont.bold
                              : AppFont.medium,
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.text,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        AppIcons.checkCircleFilled,
                        size: 20,
                        color: AppColors.primaryDark,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

/// Search box styled with [InputDesign] search tokens and external sync support.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'بحث...',
    this.onSubmitted,
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return Container(
      height: AppBarDesign.searchHeight,
      decoration: BoxDecoration(
        color: AppBarDesign.searchBackground,
        borderRadius: BorderRadius.circular(AppBarDesign.searchRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: (text) {
          if (text.isEmpty) {
            ActiveVisualSearchStore.instance.clear();
          }
          setState(() {});
          widget.onChanged(text);
        },
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        cursorColor: InputDesign.cursor,
        style: TextStyle(
          fontSize: 14,
          fontWeight: AppFont.medium,
          color: AppColors.text,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 11,
          ),
          hintText: widget.hint.tr,
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: AppBarDesign.searchHint,
          ),
          prefixIcon: Icon(
            AppIcons.search,
            size: 19,
            color: AppBarDesign.searchIcon,
          ),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'مسح البحث'.tr,
                  onPressed: AppHaptics.action(() {
                    ActiveVisualSearchStore.instance.clear();
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  }),
                  icon: Icon(
                    AppIcons.close,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Unified toolbar combining live search, quick pills, sort selector,
/// advanced filter button with badge count, active filter chips, and result stats.
class AppFilterToolbar extends StatelessWidget {
  const AppFilterToolbar({
    super.key,
    required this.searchValue,
    required this.onSearchChanged,
    this.searchHint = 'بحث...',
    this.quickOptions = const [],
    this.activeTags = const [],
    this.onOpenAdvancedFilter,
    this.activeFacetCount = 0,
    this.sortLabel,
    this.isDefaultSort = true,
    this.onOpenSort,
    this.totalCount,
    this.filteredCount,
    this.hasActiveCustomization = false,
    this.onClearAll,
    this.padding,
    this.showCountWhenUnfiltered = false,
    this.showingSimilarFallback = false,
  });

  final String searchValue;
  final ValueChanged<String> onSearchChanged;
  final String searchHint;
  final List<AppQuickFilterOption> quickOptions;
  final List<AppActiveFilterTag> activeTags;
  final VoidCallback? onOpenAdvancedFilter;
  final int activeFacetCount;
  final String? sortLabel;
  final bool isDefaultSort;
  final VoidCallback? onOpenSort;
  final int? totalCount;
  final int? filteredCount;
  final bool hasActiveCustomization;
  final VoidCallback? onClearAll;
  final EdgeInsetsGeometry? padding;
  final bool showCountWhenUnfiltered;
  final bool showingSimilarFallback;

  Future<void> _handleVisualSearch(BuildContext context) async {
    final visualResult = await showVisualSearchSheet(context);
    if (!context.mounted || visualResult == null) return;
    ActiveVisualSearchStore.instance.setQuery(visualResult);
    final parts = <String>[
      ...visualResult.inferredKeywords,
      visualResult.primaryColorName,
    ];
    final queryText = parts.join(' ').trim();
    onSearchChanged(queryText);
  }

  void _handleVoiceSearch(BuildContext context) {
    VoiceSearchFloatingOverlay.show(
      context: context,
      onResult: (spoken) {
        if (spoken.trim().isEmpty) return;
        ActiveVisualSearchStore.instance.clear();
        onSearchChanged(spoken.trim());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showStatsRow =
        activeTags.isNotEmpty ||
        hasActiveCustomization ||
        (showCountWhenUnfiltered && totalCount != null);

    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  value: searchValue,
                  hint: searchHint,
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ValueListenableBuilder<bool>(
                valueListenable: VoiceSearchFloatingOverlay.isActiveNotifier,
                builder: (context, isVoiceActive, _) {
                  return _CircleToolbarButton(
                    tooltip: 'بحث صوتي'.tr,
                    icon: IconsaxPlusLinear.microphone_2,
                    isActive: isVoiceActive,
                    onTap: () => _handleVoiceSearch(context),
                  );
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              ValueListenableBuilder<VisualSearchQuery?>(
                valueListenable: ActiveVisualSearchStore.instance.currentQuery,
                builder: (context, visualQuery, _) {
                  return _CircleToolbarButton(
                    tooltip: 'بحث بالصورة'.tr,
                    icon: AppIcons.camera,
                    isActive:
                        visualQuery != null && searchValue.trim().isNotEmpty,
                    onTap: () => _handleVisualSearch(context),
                  );
                },
              ),
              if (onOpenSort != null &&
                  quickOptions.isEmpty &&
                  onOpenAdvancedFilter == null) ...[
                const SizedBox(width: AppSpacing.xs),
                _SortActionButton(
                  label: sortLabel,
                  isDefaultSort: isDefaultSort,
                  onTap: onOpenSort!,
                ),
              ],
              if (onOpenAdvancedFilter != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _FilterTriggerButton(
                  activeCount: activeFacetCount,
                  onTap: onOpenAdvancedFilter!,
                ),
              ],
            ],
          ),
          ValueListenableBuilder<VisualSearchQuery?>(
            valueListenable: ActiveVisualSearchStore.instance.currentQuery,
            builder: (context, visualQuery, _) {
              if (visualQuery == null || searchValue.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.xs),
                        child: Image.memory(
                          visualQuery.imageBytes,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ColorDot(color: visualQuery.primarySwatch, size: 12),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${'بحث بالصورة'.tr}: ${visualQuery.allColorNames.join(' / ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        onTap: AppHaptics.action(() {
                          ActiveVisualSearchStore.instance.clear();
                          onSearchChanged('');
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            AppIcons.close,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (quickOptions.isNotEmpty || onOpenSort != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: ChipDesign.height,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (onOpenSort != null) ...[
                    _SortPillChip(
                      label: sortLabel ?? 'الأحدث',
                      isActive: !isDefaultSort,
                      onTap: onOpenSort!,
                    ),
                    if (quickOptions.isNotEmpty)
                      const SizedBox(width: AppSpacing.xs),
                  ],
                  for (var i = 0; i < quickOptions.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    _QuickPillChip(option: quickOptions[i]),
                  ],
                ],
              ),
            ),
          ],
          if (activeTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activeTags.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (_, index) =>
                    _ActiveFilterChipWidget(tag: activeTags[index]),
              ),
            ),
          ],
          if (showStatsRow) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (!showingSimilarFallback &&
                    filteredCount != null &&
                    totalCount != null)
                  Expanded(
                    child: Text(
                      hasActiveCustomization
                          ? AppLang.tr(
                              'عرض $filteredCount من $totalCount',
                            )
                          : AppLang.tr('إجمالي النتائج: $totalCount'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.semiBold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else if (!showingSimilarFallback && filteredCount != null)
                  Expanded(
                    child: Text(
                      AppLang.tr('النتائج: $filteredCount'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.semiBold,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (hasActiveCustomization && onClearAll != null)
                  TextButton.icon(
                    onPressed: AppHaptics.action(() {
                      ActiveVisualSearchStore.instance.clear();
                      onClearAll!();
                    }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.primaryDark,
                    ),
                    icon: Icon(AppIcons.refresh, size: 14),
                    label: Text(
                      'مسح الكل'.tr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (showingSimilarFallback) const AppSimilarResultsBanner(),
        ],
      ),
    );
  }
}

/// Clean minimal banner displayed when an exact search/visual query has 0 direct
/// hits and similar products are shown below it.
class AppSimilarResultsBanner extends StatelessWidget {
  const AppSimilarResultsBanner({
    super.key,
    this.onClear,
  });

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        'لا توجد منتجات مطابقة'.tr,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: AppFont.semiBold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CircleToolbarButton extends StatelessWidget {
  const _CircleToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? AppColors.primarySoft : AppColors.surfaceAlt,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: AppHaptics.action(onTap),
          child: Container(
            width: AppBarDesign.searchHeight,
            height: AppBarDesign.searchHeight,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primaryBorder : AppColors.border,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 19,
              color: isActive
                  ? AppColors.primaryDark
                  : CatalogDesign.filterButtonIcon,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterTriggerButton extends StatelessWidget {
  const _FilterTriggerButton({
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    return Tooltip(
      message: 'فلترة'.tr,
      child: Material(
        color: hasActive ? AppColors.primarySoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(CatalogDesign.filterButtonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(CatalogDesign.filterButtonRadius),
          onTap: AppHaptics.action(onTap),
          child: Container(
            height: AppBarDesign.searchHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                CatalogDesign.filterButtonRadius,
              ),
              border: Border.all(
                color: hasActive ? AppColors.primaryBorder : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.filter,
                  size: 19,
                  color: hasActive
                      ? AppColors.primaryDark
                      : CatalogDesign.filterButtonIcon,
                ),
                if (hasActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 11,
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortActionButton extends StatelessWidget {
  const _SortActionButton({
    required this.label,
    required this.isDefaultSort,
    required this.onTap,
  });

  final String? label;
  final bool isDefaultSort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = !isDefaultSort;
    return Tooltip(
      message: label?.tr ?? 'ترتيب النتائج'.tr,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: AppHaptics.action(onTap),
        child: Container(
          height: AppBarDesign.searchHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: highlighted ? AppColors.primarySoft : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: highlighted ? AppColors.primaryBorder : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_vert_rounded,
                size: 19,
                color: highlighted ? AppColors.primaryDark : AppColors.icon,
              ),
              if (label != null) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    label!.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFont.bold,
                      color: highlighted
                          ? AppColors.primaryDark
                          : AppColors.text,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SortPillChip extends StatelessWidget {
  const _SortPillChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(ChipDesign.radius),
      onTap: AppHaptics.action(onTap),
      child: Container(
        height: ChipDesign.height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySoft : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(ChipDesign.radius),
          border: Border.all(
            color: isActive ? AppColors.primaryBorder : AppColors.borderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: isActive ? AppColors.primaryDark : AppColors.icon,
            ),
            const SizedBox(width: 5),
            Text(
              label.tr,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? AppFont.bold : AppFont.semiBold,
                color: isActive ? AppColors.primaryDark : AppColors.text,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              AppIcons.chevronDown,
              size: 14,
              color: isActive ? AppColors.primaryDark : AppColors.iconMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPillChip extends StatelessWidget {
  const _QuickPillChip({required this.option});

  final AppQuickFilterOption option;

  @override
  Widget build(BuildContext context) {
    final selected = option.selected;
    return Material(
      color: selected ? ChipDesign.selectedBackground : ChipDesign.background,
      borderRadius: BorderRadius.circular(ChipDesign.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ChipDesign.radius),
        onTap: AppHaptics.action(option.onTap),
        child: Container(
          height: ChipDesign.height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ChipDesign.radius),
            border: Border.all(
              color: selected
                  ? ChipDesign.selectedBorder
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.swatchColor != null) ...[
                _ColorDot(color: option.swatchColor!, size: 12),
                const SizedBox(width: 6),
              ] else if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 15,
                  color: selected ? ChipDesign.selectedText : AppColors.icon,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                option.label.tr,
                style: TextStyle(
                  fontSize: ChipDesign.textSize,
                  fontWeight: selected
                      ? ChipDesign.selectedWeight
                      : ChipDesign.textWeight,
                  color: selected ? ChipDesign.selectedText : ChipDesign.text,
                ),
              ),
              if (option.count != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.onPrimary.withValues(alpha: 0.22)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '${option.count}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFont.bold,
                      color: selected
                          ? ChipDesign.selectedText
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChipWidget extends StatelessWidget {
  const _ActiveFilterChipWidget({required this.tag});

  final AppActiveFilterTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.swatchColor != null) ...[
            _ColorDot(color: tag.swatchColor!, size: 11),
            const SizedBox(width: 5),
          ],
          Text(
            tag.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFont.semiBold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: AppHaptics.action(tag.onRemove),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Icon(
              AppIcons.close,
              size: 15,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.borderStrong,
          width: 1,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Advanced Filter Sheet Scaffolding & Sections
// ---------------------------------------------------------------------------

/// Scrollable filter sheet scaffold with header reset button and sticky CTA.
class AppFilterSheetScaffold extends StatelessWidget {
  const AppFilterSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onApply,
    this.onReset,
    this.applyLabel = 'عرض النتائج',
    this.resetLabel = 'إعادة ضبط',
    this.activeCount = 0,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onApply;
  final VoidCallback? onReset;
  final String applyLabel;
  final String resetLabel;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(SheetDesign.topRadius),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            title.tr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                          if (activeCount > 0) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                              child: Text(
                                '$activeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: AppFont.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onReset != null)
                      TextButton(
                        onPressed: AppHaptics.action(onReset),
                        child: Text(
                          resetLabel.tr,
                          style: TextStyle(
                            fontWeight: AppFont.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: AppButton(
                  label: applyLabel.tr,
                  onPressed: onApply,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titled filter section inside [AppFilterSheetScaffold].
class AppFilterSection extends StatelessWidget {
  const AppFilterSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Choice chip grid for single-value facet selection inside filter sheets.
class AppFilterChoiceWrap<T> extends StatelessWidget {
  const AppFilterChoiceWrap({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
    this.allowDeselect = true,
    this.allLabel,
  });

  final List<T> options;
  final T? selectedValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?> onSelected;
  final bool allowDeselect;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        if (allLabel != null)
          _FilterSheetChip(
            label: allLabel!.tr,
            selected: selectedValue == null,
            onTap: () => onSelected(null),
          ),
        for (final item in options)
          _FilterSheetChip(
            label: labelBuilder(item).tr,
            selected: selectedValue == item,
            onTap: () {
              if (selectedValue == item && allowDeselect) {
                onSelected(null);
              } else {
                onSelected(item);
              }
            },
          ),
      ],
    );
  }
}

/// Color picker wrap with swatch indicator dots inside filter sheets.
class AppFilterColorWrap extends StatelessWidget {
  const AppFilterColorWrap({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<String> colors;
  final String? selectedColor;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final normalizedSelected = normalizeSearchText(selectedColor);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _FilterSheetChip(
          label: 'الكل'.tr,
          selected: selectedColor == null || selectedColor!.isEmpty,
          onTap: () => onSelected(null),
        ),
        for (final color in colors)
          _FilterSheetChip(
            label: color.tr,
            selected:
                normalizedSelected.isNotEmpty &&
                normalizeSearchText(color) == normalizedSelected,
            swatchColor: resolveColorSwatch(color),
            onTap: () {
              final isSame =
                  normalizedSelected.isNotEmpty &&
                  normalizeSearchText(color) == normalizedSelected;
              onSelected(isSame ? null : color);
            },
          ),
      ],
    );
  }
}

/// Numeric min/max range editor with optional quick preset pills.
class AppFilterRangeInputs extends StatelessWidget {
  const AppFilterRangeInputs({
    super.key,
    required this.minController,
    required this.maxController,
    this.minLabel = 'من',
    this.maxLabel = 'إلى',
    this.currencySuffix = 'شيكل',
    this.presets = const [],
    this.onPresetSelected,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final String minLabel;
  final String maxLabel;
  final String currencySuffix;
  final List<(String label, double? min, double? max)> presets;
  final void Function(double? min, double? max)? onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final currentMin = double.tryParse(minController.text.trim());
    final currentMax = double.tryParse(maxController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '${minLabel.tr} (${currencySuffix.tr})',
                  hintText: '0',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: maxController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '${maxLabel.tr} (${currencySuffix.tr})',
                  hintText: '∞',
                ),
              ),
            ),
          ],
        ),
        if (presets.isNotEmpty && onPresetSelected != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: presets.map((preset) {
              final (label, min, max) = preset;
              final isMatch = currentMin == min && currentMax == max;
              return _FilterSheetChip(
                label: label.tr,
                selected: isMatch,
                onTap: () {
                  minController.text = min == null ? '' : min.toStringAsFixed(0);
                  maxController.text = max == null ? '' : max.toStringAsFixed(0);
                  onPresetSelected!(min, max);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Toggle row styled smoothly for boolean filter options (e.g. "متوفر فقط").
class AppFilterSwitchRow extends StatelessWidget {
  const AppFilterSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
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
                  title.tr,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: AppFont.bold,
                    color: AppColors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: AppHaptics.change(onChanged),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _FilterSheetChip extends StatelessWidget {
  const _FilterSheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatchColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatchColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(ChipDesign.radius),
      onTap: AppHaptics.action(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ChipDesign.selectedBackground : ChipDesign.background,
          borderRadius: BorderRadius.circular(ChipDesign.radius),
          border: Border.all(
            color: selected ? ChipDesign.selectedBorder : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (swatchColor != null) ...[
              _ColorDot(color: swatchColor!, size: 12),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: ChipDesign.textSize,
                fontWeight: selected
                    ? ChipDesign.selectedWeight
                    : ChipDesign.textWeight,
                color: selected ? ChipDesign.selectedText : ChipDesign.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent zero-match view displayed below [AppFilterToolbar] with quick reset.
class AppFilterEmptyState extends StatelessWidget {
  const AppFilterEmptyState({
    super.key,
    required this.onReset,
    this.title = 'لا توجد نتائج مطابقة',
    this.message = 'جرّب تعديل كلمات البحث أو مسح بعض الفلاتر لعرض المزيد.',
    this.resetLabel = 'إعادة ضبط الفلاتر',
  });

  final VoidCallback onReset;
  final String title;
  final String message;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    return AppEmpty(
      icon: AppIcons.searchOff,
      title: title.tr,
      message: message.tr,
      actionLabel: resetLabel.tr,
      onAction: onReset,
    );
  }
}
