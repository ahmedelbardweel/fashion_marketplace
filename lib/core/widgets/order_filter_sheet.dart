import 'package:flutter/material.dart';

import '../filtering/filter_models.dart';
import '../theme/app_design.dart';
import 'app_bottom_sheet.dart';
import 'app_filter_bar.dart';

const List<(String key, String labelAr)> kOrderStatusFilters = [
  ('pending', 'قيد الانتظار'),
  ('confirmed', 'مؤكد'),
  ('processing', 'قيد التجهيز'),
  ('shipped', 'تم الشحن'),
  ('delivered', 'تم التوصيل'),
  ('cancelled', 'ملغي'),
];

const List<AppSortChoice<OrderSortOption>> kOrderSortChoices = [
  AppSortChoice(
    value: OrderSortOption.newest,
    label: 'الأحدث',
    icon: AppIcons.arrowDown,
  ),
  AppSortChoice(
    value: OrderSortOption.oldest,
    label: 'الأقدم',
    icon: AppIcons.arrowUp,
  ),
  AppSortChoice(
    value: OrderSortOption.totalDesc,
    label: 'الأعلى قيمة',
    icon: AppIcons.payment,
  ),
  AppSortChoice(
    value: OrderSortOption.totalAsc,
    label: 'الأقل قيمة',
    icon: AppIcons.payment,
  ),
];

String orderStatusLabel(String status) {
  for (final entry in kOrderStatusFilters) {
    if (entry.$1 == status) return entry.$2;
  }
  return status;
}

List<AppActiveFilterTag> buildOrderActiveTags({
  required OrderFilterState filter,
  required ValueChanged<OrderFilterState> onChanged,
  bool includeStatusTag = false,
}) {
  final tags = <AppActiveFilterTag>[];

  if (includeStatusTag &&
      filter.status != null &&
      filter.status!.trim().isNotEmpty) {
    tags.add(
      AppActiveFilterTag(
        label: '${'الحالة'.tr}: ${orderStatusLabel(filter.status!).tr}',
        onRemove: () => onChanged(filter.copyWith(clearStatus: true)),
      ),
    );
  }

  if (filter.shopName != null && filter.shopName!.trim().isNotEmpty) {
    tags.add(
      AppActiveFilterTag(
        label: 'المتجر: ${filter.shopName!}'.tr,
        onRemove: () => onChanged(filter.copyWith(clearShopName: true)),
      ),
    );
  }

  if (filter.datePreset != DateRangePreset.all) {
    tags.add(
      AppActiveFilterTag(
        label: '${'الفترة الزمنية'.tr}: ${filter.datePreset.labelAr.tr}',
        onRemove: () =>
            onChanged(filter.copyWith(datePreset: DateRangePreset.all)),
      ),
    );
  }

  if (filter.minTotal != null || filter.maxTotal != null) {
    final String label;
    if (filter.minTotal != null && filter.maxTotal != null) {
      label =
          'الإجمالي: من ${filter.minTotal!.toStringAsFixed(0)} إلى ${filter.maxTotal!.toStringAsFixed(0)}'
              .tr;
    } else if (filter.minTotal != null) {
      label = 'الإجمالي: من ${filter.minTotal!.toStringAsFixed(0)}'.tr;
    } else {
      label = 'الإجمالي: حتى ${filter.maxTotal!.toStringAsFixed(0)}'.tr;
    }
    tags.add(
      AppActiveFilterTag(
        label: label,
        onRemove: () => onChanged(filter.copyWith(clearTotalRange: true)),
      ),
    );
  }

  return tags;
}

Future<OrderFilterState?> showOrderFilterSheet({
  required BuildContext context,
  required OrderFilterState initial,
  List<String> availableShops = const [],
}) {
  return AppBottomSheet.show<OrderFilterState>(
    context: context,
    isScrollControlled: true,
    child: _OrderFilterSheetBody(
      initial: initial,
      availableShops: availableShops,
    ),
  );
}

class _OrderFilterSheetBody extends StatefulWidget {
  const _OrderFilterSheetBody({
    required this.initial,
    required this.availableShops,
  });

  final OrderFilterState initial;
  final List<String> availableShops;

  @override
  State<_OrderFilterSheetBody> createState() => _OrderFilterSheetBodyState();
}

class _OrderFilterSheetBodyState extends State<_OrderFilterSheetBody> {
  late OrderFilterState _draft;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _minController = TextEditingController(
      text: widget.initial.minTotal?.toStringAsFixed(0) ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initial.maxTotal?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  OrderFilterState _resolved() {
    final minVal = double.tryParse(_minController.text.trim());
    final maxVal = double.tryParse(_maxController.text.trim());
    return OrderFilterState(
      search: _draft.search,
      status: _draft.status,
      shopName: _draft.shopName,
      shopId: _draft.shopId,
      datePreset: _draft.datePreset,
      minTotal: minVal,
      maxTotal: maxVal,
      sort: _draft.sort,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved();
    return AppFilterSheetScaffold(
      title: 'تصفية الطلبات',
      activeCount: resolved.activeFacetCount,
      onReset: () {
        _minController.clear();
        _maxController.clear();
        setState(() => _draft = OrderFilterState(search: _draft.search));
      },
      onApply: () => Navigator.of(context).pop(_resolved()),
      children: [
        AppFilterSection(
          title: 'ترتيب النتائج',
          child: AppFilterChoiceWrap<OrderSortOption>(
            options: kOrderSortChoices.map((e) => e.value).toList(),
            selectedValue: _draft.sort,
            allowDeselect: false,
            labelBuilder: (s) => s.labelAr,
            onSelected: (s) {
              if (s != null) setState(() => _draft = _draft.copyWith(sort: s));
            },
          ),
        ),
        AppFilterSection(
          title: 'الحالة',
          child: AppFilterChoiceWrap<String>(
            options: kOrderStatusFilters.map((e) => e.$1).toList(),
            selectedValue: _draft.status,
            allLabel: 'الكل',
            labelBuilder: orderStatusLabel,
            onSelected: (st) => setState(
              () => _draft = st == null
                  ? _draft.copyWith(clearStatus: true)
                  : _draft.copyWith(status: st),
            ),
          ),
        ),
        AppFilterSection(
          title: 'الفترة الزمنية',
          child: AppFilterChoiceWrap<DateRangePreset>(
            options: DateRangePreset.values,
            selectedValue: _draft.datePreset,
            allowDeselect: false,
            labelBuilder: (d) => d.labelAr,
            onSelected: (d) {
              if (d != null) {
                setState(() => _draft = _draft.copyWith(datePreset: d));
              }
            },
          ),
        ),
        if (widget.availableShops.isNotEmpty)
          AppFilterSection(
            title: 'المتجر',
            child: AppFilterChoiceWrap<String>(
              options: widget.availableShops,
              selectedValue: _draft.shopName,
              allLabel: 'الكل',
              labelBuilder: (s) => s,
              onSelected: (shop) => setState(
                () => _draft = shop == null
                    ? _draft.copyWith(clearShopName: true)
                    : _draft.copyWith(shopName: shop),
              ),
            ),
          ),
        AppFilterSection(
          title: 'نطاق الإجمالي',
          child: AppFilterRangeInputs(
            minController: _minController,
            maxController: _maxController,
            presets: const [
              ('أقل من 200', null, 200),
              ('200 - 500', 200, 500),
              ('أكثر من 500', 500, null),
            ],
            onPresetSelected: (min, max) => setState(() {
              _draft = OrderFilterState(
                search: _draft.search,
                status: _draft.status,
                shopName: _draft.shopName,
                shopId: _draft.shopId,
                datePreset: _draft.datePreset,
                minTotal: min,
                maxTotal: max,
                sort: _draft.sort,
              );
            }),
          ),
        ),
      ],
    );
  }
}
