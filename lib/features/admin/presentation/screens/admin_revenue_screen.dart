import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gaza_region_picker_sheet.dart';
import '../../domain/models/gaza_region.dart';
import '../../domain/models/revenue_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

enum _RevenueTab { shops, settlements }

enum _ShopRiskQuick {
  all,
  hasDues,
  nearOrOverLimit,
  onHold,
  pendingAgreement,
  highCancellation,
  settled,
}

enum _ShopRevenueSort {
  highestOutstanding,
  highestSales,
  highestCommission,
  highestLimitUsage,
  highestCancellation,
  nameAsc,
}

enum _SettlementSort { newest, oldest, highestAmount, lowestAmount }

enum _ReceiptFilter { all, withReceipt, withoutReceipt }

class AdminRevenueScreen extends ConsumerStatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  ConsumerState<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends ConsumerState<AdminRevenueScreen> {
  _RevenueTab _tab = _RevenueTab.shops;

  // --- Shop Accounts Filter & Sort State ---
  String _shopSearch = '';
  _ShopRiskQuick _shopQuick = _ShopRiskQuick.all;
  _ShopRevenueSort _shopSort = _ShopRevenueSort.highestOutstanding;
  GazaRegion? _selectedRegion;
  String? _commissionTypeFilter; // 'percentage' | 'fixed' | 'hybrid'
  String? _cycleFilter; // 'weekly' | 'biweekly' | 'monthly'
  bool? _agreementAcceptedFilter; // true = accepted, false = pending
  bool _onlyWithPendingSettlements = false;
  double? _minDue;
  double? _maxDue;

  // --- Settlements Filter & Sort State ---
  String _settlementSearch = '';
  String? _settlementMethodFilter; // 'cash' | 'bank_transfer' | 'jawwal_pay' | 'palpay'
  _ReceiptFilter _receiptFilter = _ReceiptFilter.all;
  _SettlementSort _settlementSort = _SettlementSort.newest;
  double? _minSettlementAmount;
  double? _maxSettlementAmount;

  int get _activeShopFacetCount {
    var count = 0;
    if (_selectedRegion != null) count++;
    if (_commissionTypeFilter != null) count++;
    if (_cycleFilter != null) count++;
    if (_agreementAcceptedFilter != null) count++;
    if (_onlyWithPendingSettlements) count++;
    if (_minDue != null || _maxDue != null) count++;
    return count;
  }

  bool get _hasShopCustomization =>
      _shopSearch.trim().isNotEmpty ||
      _shopQuick != _ShopRiskQuick.all ||
      _shopSort != _ShopRevenueSort.highestOutstanding ||
      _activeShopFacetCount > 0;

  int get _activeSettlementFacetCount {
    var count = 0;
    if (_settlementMethodFilter != null) count++;
    if (_receiptFilter != _ReceiptFilter.all) count++;
    if (_minSettlementAmount != null || _maxSettlementAmount != null) count++;
    return count;
  }

  bool get _hasSettlementCustomization =>
      _settlementSearch.trim().isNotEmpty ||
      _settlementSort != _SettlementSort.newest ||
      _activeSettlementFacetCount > 0;

  void _clearShopFilters() {
    setState(() {
      _shopSearch = '';
      _shopQuick = _ShopRiskQuick.all;
      _shopSort = _ShopRevenueSort.highestOutstanding;
      _selectedRegion = null;
      _commissionTypeFilter = null;
      _cycleFilter = null;
      _agreementAcceptedFilter = null;
      _onlyWithPendingSettlements = false;
      _minDue = null;
      _maxDue = null;
    });
  }

  void _clearSettlementFilters() {
    setState(() {
      _settlementSearch = '';
      _settlementMethodFilter = null;
      _receiptFilter = _ReceiptFilter.all;
      _settlementSort = _SettlementSort.newest;
      _minSettlementAmount = null;
      _maxSettlementAmount = null;
    });
  }

  String _shopSortLabel(_ShopRevenueSort sort) {
    switch (sort) {
      case _ShopRevenueSort.highestOutstanding:
        return 'الأعلى مستحقات';
      case _ShopRevenueSort.highestSales:
        return 'الأعلى مبيعات';
      case _ShopRevenueSort.highestCommission:
        return 'الأعلى عمولة';
      case _ShopRevenueSort.highestLimitUsage:
        return 'الأقرب للسقف';
      case _ShopRevenueSort.highestCancellation:
        return 'الأعلى إلغاءً';
      case _ShopRevenueSort.nameAsc:
        return 'الاسم (أ - ي)';
    }
  }

  String _settlementSortLabel(_SettlementSort sort) {
    switch (sort) {
      case _SettlementSort.newest:
        return 'الأحدث أولاً';
      case _SettlementSort.oldest:
        return 'الأقدم أولاً';
      case _SettlementSort.highestAmount:
        return 'الأعلى مبلغاً';
      case _SettlementSort.lowestAmount:
        return 'الأقل مبلغاً';
    }
  }

  String _commissionTypeLabel(String type) {
    switch (type) {
      case 'fixed':
        return 'مبلغ ثابت (₪)';
      case 'hybrid':
        return 'هجين (% + ₪)';
      default:
        return 'نسبة مئوية (%)';
    }
  }

  String _cycleFilterLabel(String cycle) {
    switch (cycle) {
      case 'biweekly':
        return 'كل أسبوعين';
      case 'monthly':
        return 'شهرياً';
      default:
        return 'أسبوعياً';
    }
  }

  String _methodFilterLabel(String method) {
    switch (method) {
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'jawwal_pay':
        return 'جوال باي';
      case 'palpay':
        return 'بال باي';
      default:
        return 'نقداً (كاش)';
    }
  }

  List<ShopFinancialAccount> _applyShopFilters(
    List<ShopFinancialAccount> items,
    List<GazaGovernorateGroup> govGroups, {
    String? searchOverride,
    _ShopRiskQuick? quickOverride,
    _ShopRevenueSort? sortOverride,
    GazaRegion? regionOverride,
    bool useRegionOverride = false,
    String? commissionTypeOverride,
    bool useCommissionOverride = false,
    String? cycleOverride,
    bool useCycleOverride = false,
    bool? agreementOverride,
    bool useAgreementOverride = false,
    bool? onlyPendingOverride,
    double? minDueOverride,
    bool useMinDueOverride = false,
    double? maxDueOverride,
    bool useMaxDueOverride = false,
  }) {
    final q = (searchOverride ?? _shopSearch).trim().toLowerCase();
    final quick = quickOverride ?? _shopQuick;
    final sort = sortOverride ?? _shopSort;
    final region = useRegionOverride ? regionOverride : _selectedRegion;
    final commType = useCommissionOverride
        ? commissionTypeOverride
        : _commissionTypeFilter;
    final cycle = useCycleOverride ? cycleOverride : _cycleFilter;
    final agreement = useAgreementOverride
        ? agreementOverride
        : _agreementAcceptedFilter;
    final onlyPending = onlyPendingOverride ?? _onlyWithPendingSettlements;
    final minDue = useMinDueOverride ? minDueOverride : _minDue;
    final maxDue = useMaxDueOverride ? maxDueOverride : _maxDue;

    var list = items.where((acc) {
      if (q.isNotEmpty) {
        final hay =
            '${acc.shopName} ${acc.shopCity ?? ''} ${acc.agreementSummaryLabel}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }

      switch (quick) {
        case _ShopRiskQuick.all:
          break;
        case _ShopRiskQuick.hasDues:
          if (acc.outstandingBalance <= 0) return false;
        case _ShopRiskQuick.nearOrOverLimit:
          if (!acc.isNearLimit && !acc.isOverLimit) return false;
        case _ShopRiskQuick.onHold:
          if (!acc.financialHold) return false;
        case _ShopRiskQuick.pendingAgreement:
          if (acc.isAgreementAccepted) return false;
        case _ShopRiskQuick.highCancellation:
          if (!acc.isHighCancellationRisk) return false;
        case _ShopRiskQuick.settled:
          if (acc.outstandingBalance > 0) return false;
      }

      if (region != null) {
        final matchedGov = govGroups
            .where((g) => g.governorate.id == region.id)
            .firstOrNull;
        if (matchedGov != null) {
          if (!matchesGazaGovernorate(acc.shopCity, matchedGov)) return false;
        } else {
          final qAr = region.name.split('·').last.trim().toLowerCase();
          final qEn = region.nameEn?.trim().toLowerCase() ?? '';
          final city = (acc.shopCity ?? '').toLowerCase();
          final okAr = qAr.isNotEmpty && city.contains(qAr);
          final okEn = qEn.isNotEmpty && city.contains(qEn);
          if (!okAr && !okEn) return false;
        }
      }

      if (commType != null && acc.commissionType != commType) return false;
      if (cycle != null && acc.settlementCycle != cycle) return false;
      if (agreement != null && acc.isAgreementAccepted != agreement) {
        return false;
      }
      if (onlyPending && acc.pendingSettlementsCount <= 0) return false;
      if (minDue != null && acc.outstandingBalance < minDue) return false;
      if (maxDue != null && acc.outstandingBalance > maxDue) return false;

      return true;
    }).toList();

    list.sort((a, b) {
      switch (sort) {
        case _ShopRevenueSort.highestOutstanding:
          final cmp = b.outstandingBalance.compareTo(a.outstandingBalance);
          return cmp != 0 ? cmp : b.deliveredSales.compareTo(a.deliveredSales);
        case _ShopRevenueSort.highestSales:
          return b.deliveredSales.compareTo(a.deliveredSales);
        case _ShopRevenueSort.highestCommission:
          return b.commissionEarned.compareTo(a.commissionEarned);
        case _ShopRevenueSort.highestLimitUsage:
          return b.limitUsageRatio.compareTo(a.limitUsageRatio);
        case _ShopRevenueSort.highestCancellation:
          return b.cancellationRate.compareTo(a.cancellationRate);
        case _ShopRevenueSort.nameAsc:
          return a.shopName.toLowerCase().compareTo(b.shopName.toLowerCase());
      }
    });

    return list;
  }

  List<ShopSettlement> _applySettlementFilters(
    List<ShopSettlement> items, {
    String? searchOverride,
    String? methodOverride,
    bool useMethodOverride = false,
    _ReceiptFilter? receiptOverride,
    _SettlementSort? sortOverride,
    double? minOverride,
    bool useMinOverride = false,
    double? maxOverride,
    bool useMaxOverride = false,
  }) {
    final q = (searchOverride ?? _settlementSearch).trim().toLowerCase();
    final method = useMethodOverride ? methodOverride : _settlementMethodFilter;
    final receipt = receiptOverride ?? _receiptFilter;
    final sort = sortOverride ?? _settlementSort;
    final minAmt = useMinOverride ? minOverride : _minSettlementAmount;
    final maxAmt = useMaxOverride ? maxOverride : _maxSettlementAmount;

    var list = items.where((stl) {
      if (q.isNotEmpty) {
        final hay =
            '${stl.shopName ?? ''} ${stl.referenceNumber ?? ''} ${stl.notes ?? ''} ${stl.methodLabel}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (method != null && stl.paymentMethod != method) return false;
      final hasReceipt = stl.receiptUrl?.trim().isNotEmpty ?? false;
      if (receipt == _ReceiptFilter.withReceipt && !hasReceipt) return false;
      if (receipt == _ReceiptFilter.withoutReceipt && hasReceipt) return false;
      if (minAmt != null && stl.amount < minAmt) return false;
      if (maxAmt != null && stl.amount > maxAmt) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      switch (sort) {
        case _SettlementSort.newest:
          return b.createdAt.compareTo(a.createdAt);
        case _SettlementSort.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case _SettlementSort.highestAmount:
          return b.amount.compareTo(a.amount);
        case _SettlementSort.lowestAmount:
          return a.amount.compareTo(b.amount);
      }
    });

    return list;
  }

  Future<void> _openShopSortSheet() async {
    final picked = await showAppSortSheet<_ShopRevenueSort>(
      context: context,
      current: _shopSort,
      title: 'ترتيب حسابات المحلات',
      options: const [
        AppSortChoice(
          value: _ShopRevenueSort.highestOutstanding,
          label: 'الأعلى مستحقات',
        ),
        AppSortChoice(
          value: _ShopRevenueSort.highestSales,
          label: 'الأعلى مبيعات',
        ),
        AppSortChoice(
          value: _ShopRevenueSort.highestCommission,
          label: 'الأعلى عمولة',
        ),
        AppSortChoice(
          value: _ShopRevenueSort.highestLimitUsage,
          label: 'الأقرب للسقف',
        ),
        AppSortChoice(
          value: _ShopRevenueSort.highestCancellation,
          label: 'الأعلى إلغاءً',
        ),
        AppSortChoice(
          value: _ShopRevenueSort.nameAsc,
          label: 'الاسم (أ - ي)',
        ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _shopSort = picked);
    }
  }

  Future<void> _openSettlementSortSheet() async {
    final picked = await showAppSortSheet<_SettlementSort>(
      context: context,
      current: _settlementSort,
      title: 'ترتيب طلبات التسوية',
      options: const [
        AppSortChoice(
          value: _SettlementSort.newest,
          label: 'الأحدث أولاً',
        ),
        AppSortChoice(
          value: _SettlementSort.oldest,
          label: 'الأقدم أولاً',
        ),
        AppSortChoice(
          value: _SettlementSort.highestAmount,
          label: 'الأعلى مبلغاً',
        ),
        AppSortChoice(
          value: _SettlementSort.lowestAmount,
          label: 'الأقل مبلغاً',
        ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _settlementSort = picked);
    }
  }

  Future<void> _openShopAdvancedFilters(
    List<ShopFinancialAccount> allShops,
    List<GazaRegion> regions,
    List<GazaGovernorateGroup> govGroups,
  ) async {
    var draftRegion = _selectedRegion;
    var draftCommission = _commissionTypeFilter;
    var draftCycle = _cycleFilter;
    var draftAgreement = _agreementAcceptedFilter;
    var draftQuick = _shopQuick;
    var draftOnlyPending = _onlyWithPendingSettlements;
    final minCtrl = TextEditingController(
      text: _minDue != null ? _minDue!.toStringAsFixed(0) : '',
    );
    final maxCtrl = TextEditingController(
      text: _maxDue != null ? _maxDue!.toStringAsFixed(0) : '',
    );

    double? parseOpt(String text) {
      final cleaned = text.trim().replaceAll('٫', '.');
      if (cleaned.isEmpty) return null;
      return double.tryParse(cleaned);
    }

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final draftMin = parseOpt(minCtrl.text);
          final draftMax = parseOpt(maxCtrl.text);
          final previewCount = _applyShopFilters(
            allShops,
            govGroups,
            quickOverride: draftQuick,
            regionOverride: draftRegion,
            useRegionOverride: true,
            commissionTypeOverride: draftCommission,
            useCommissionOverride: true,
            cycleOverride: draftCycle,
            useCycleOverride: true,
            agreementOverride: draftAgreement,
            useAgreementOverride: true,
            onlyPendingOverride: draftOnlyPending,
            minDueOverride: draftMin,
            useMinDueOverride: true,
            maxDueOverride: draftMax,
            useMaxDueOverride: true,
          ).length;

          return AppBottomSheetScaffold(
            title: 'فلترة متقدمة للحسابات المالية'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1) Gaza Region Picker
                _FilterSectionLabel('منطقة قطاع غزة'.tr),
                const SizedBox(height: AppSpacing.xs),
                Material(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: AppHaptics.action(() async {
                      final picked = await showGazaRegionPickerSheet(
                        context: sheetCtx,
                        regions: regions,
                        selectedRegionName: draftRegion?.name,
                        allowClear: true,
                        title: 'تصفية المحلات حسب منطقة في غزة',
                      );
                      if (picked == null || !sheetCtx.mounted) return;
                      setSheetState(() {
                        draftRegion = picked.name.isEmpty ? null : picked;
                      });
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color: draftRegion != null
                              ? AppColors.primaryBorder
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              draftRegion == null
                                  ? 'كل مناطق قطاع غزة'.tr
                                  : (AppLang.isEn
                                        ? (draftRegion!.nameEn ??
                                              draftRegion!.name)
                                        : draftRegion!.name),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: draftRegion != null
                                    ? AppFont.bold
                                    : AppFont.medium,
                                color: draftRegion != null
                                    ? AppColors.primaryDark
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (draftRegion != null)
                            InkWell(
                              onTap: AppHaptics.action(
                                () => setSheetState(() => draftRegion = null),
                              ),
                              child: Text(
                                'مسح'.tr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: AppFont.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            )
                          else
                            Icon(
                              AppIcons.chevronDown,
                              size: 18,
                              color: AppColors.iconMuted,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2) Risk & Financial Status
                _FilterSectionLabel('حالة الذمة والمخاطر'.tr),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('الكل'.tr),
                      selected: draftQuick == _ShopRiskQuick.all,
                      onSelected: (_) =>
                          setSheetState(() => draftQuick = _ShopRiskQuick.all),
                    ),
                    ChoiceChip(
                      label: Text('عليها مستحقات'.tr),
                      selected: draftQuick == _ShopRiskQuick.hasDues,
                      onSelected: (_) => setSheetState(
                        () => draftQuick = _ShopRiskQuick.hasDues,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('قرب/تجاوز السقف'.tr),
                      selected: draftQuick == _ShopRiskQuick.nearOrOverLimit,
                      onSelected: (_) => setSheetState(
                        () => draftQuick = _ShopRiskQuick.nearOrOverLimit,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('مجمّد مالياً'.tr),
                      selected: draftQuick == _ShopRiskQuick.onHold,
                      onSelected: (_) => setSheetState(
                        () => draftQuick = _ShopRiskQuick.onHold,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('إلغاء مرتفع'.tr),
                      selected: draftQuick == _ShopRiskQuick.highCancellation,
                      onSelected: (_) => setSheetState(
                        () => draftQuick = _ShopRiskQuick.highCancellation,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('خالي الذمة'.tr),
                      selected: draftQuick == _ShopRiskQuick.settled,
                      onSelected: (_) => setSheetState(
                        () => draftQuick = _ShopRiskQuick.settled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 3) Agreement Status
                _FilterSectionLabel('حالة توثيق الاتفاقية'.tr),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('الكل'.tr),
                      selected: draftAgreement == null,
                      onSelected: (_) =>
                          setSheetState(() => draftAgreement = null),
                    ),
                    ChoiceChip(
                      label: Text('الاتفاقية موثّقة'.tr),
                      selected: draftAgreement == true,
                      onSelected: (_) =>
                          setSheetState(() => draftAgreement = true),
                    ),
                    ChoiceChip(
                      label: Text('بانتظار موافقة المحل'.tr),
                      selected: draftAgreement == false,
                      onSelected: (_) =>
                          setSheetState(() => draftAgreement = false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 4) Commission Type
                _FilterSectionLabel('نوع احتساب العمولة'.tr),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('الكل'.tr),
                      selected: draftCommission == null,
                      onSelected: (_) =>
                          setSheetState(() => draftCommission = null),
                    ),
                    ChoiceChip(
                      label: Text('نسبة مئوية (%)'.tr),
                      selected: draftCommission == 'percentage',
                      onSelected: (_) =>
                          setSheetState(() => draftCommission = 'percentage'),
                    ),
                    ChoiceChip(
                      label: Text('مبلغ ثابت (₪)'.tr),
                      selected: draftCommission == 'fixed',
                      onSelected: (_) =>
                          setSheetState(() => draftCommission = 'fixed'),
                    ),
                    ChoiceChip(
                      label: Text('هجين (% + ₪)'.tr),
                      selected: draftCommission == 'hybrid',
                      onSelected: (_) =>
                          setSheetState(() => draftCommission = 'hybrid'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 5) Settlement Cycle
                _FilterSectionLabel('دورة التسوية والسداد'.tr),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('الكل'.tr),
                      selected: draftCycle == null,
                      onSelected: (_) => setSheetState(() => draftCycle = null),
                    ),
                    ChoiceChip(
                      label: Text('أسبوعياً'.tr),
                      selected: draftCycle == 'weekly',
                      onSelected: (_) =>
                          setSheetState(() => draftCycle = 'weekly'),
                    ),
                    ChoiceChip(
                      label: Text('كل أسبوعين'.tr),
                      selected: draftCycle == 'biweekly',
                      onSelected: (_) =>
                          setSheetState(() => draftCycle = 'biweekly'),
                    ),
                    ChoiceChip(
                      label: Text('شهرياً'.tr),
                      selected: draftCycle == 'monthly',
                      onSelected: (_) =>
                          setSheetState(() => draftCycle = 'monthly'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 6) Outstanding Balance Range
                _FilterSectionLabel('نطاق المستحقات المالية (₪)'.tr),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: minCtrl,
                        label: 'من (₪)'.tr,
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: maxCtrl,
                        label: 'إلى (₪)'.tr,
                        hint: '500',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    ActionChip(
                      label: Text('+50 ₪'),
                      onPressed: () {
                        minCtrl.text = '50';
                        maxCtrl.clear();
                        setSheetState(() {});
                      },
                    ),
                    ActionChip(
                      label: Text('+100 ₪'),
                      onPressed: () {
                        minCtrl.text = '100';
                        maxCtrl.clear();
                        setSheetState(() {});
                      },
                    ),
                    ActionChip(
                      label: Text('+250 ₪'),
                      onPressed: () {
                        minCtrl.text = '250';
                        maxCtrl.clear();
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // 7) Pending Settlements Only Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    'لديها طلبات تسوية معلّقة فقط'.tr,
                    style: TextStyle(
                      fontWeight: AppFont.bold,
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                  value: draftOnlyPending,
                  onChanged: AppHaptics.change(
                    (v) => setSheetState(() => draftOnlyPending = v),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 8) Apply & Reset Actions
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'إعادة تعيين'.tr,
                        variant: AppButtonVariant.secondary,
                        onPressed: () {
                          minCtrl.clear();
                          maxCtrl.clear();
                          setSheetState(() {
                            draftRegion = null;
                            draftCommission = null;
                            draftCycle = null;
                            draftAgreement = null;
                            draftQuick = _ShopRiskQuick.all;
                            draftOnlyPending = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: '${'عرض النتائج'.tr} ($previewCount)',
                        onPressed: () {
                          setState(() {
                            _selectedRegion = draftRegion;
                            _commissionTypeFilter = draftCommission;
                            _cycleFilter = draftCycle;
                            _agreementAcceptedFilter = draftAgreement;
                            _shopQuick = draftQuick;
                            _onlyWithPendingSettlements = draftOnlyPending;
                            _minDue = parseOpt(minCtrl.text);
                            _maxDue = parseOpt(maxCtrl.text);
                          });
                          Navigator.of(sheetCtx).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    minCtrl.dispose();
    maxCtrl.dispose();
  }

  Future<void> _openSettlementAdvancedFilters(
    List<ShopSettlement> allSettlements,
  ) async {
    var draftMethod = _settlementMethodFilter;
    var draftReceipt = _receiptFilter;
    final minCtrl = TextEditingController(
      text: _minSettlementAmount != null
          ? _minSettlementAmount!.toStringAsFixed(0)
          : '',
    );
    final maxCtrl = TextEditingController(
      text: _maxSettlementAmount != null
          ? _maxSettlementAmount!.toStringAsFixed(0)
          : '',
    );

    double? parseOpt(String text) {
      final cleaned = text.trim().replaceAll('٫', '.');
      if (cleaned.isEmpty) return null;
      return double.tryParse(cleaned);
    }

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.85,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final previewCount = _applySettlementFilters(
            allSettlements,
            methodOverride: draftMethod,
            useMethodOverride: true,
            receiptOverride: draftReceipt,
            minOverride: parseOpt(minCtrl.text),
            useMinOverride: true,
            maxOverride: parseOpt(maxCtrl.text),
            useMaxOverride: true,
          ).length;

          return AppBottomSheetScaffold(
            title: 'فلترة طلبات التسوية'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FilterSectionLabel('طريقة الدفع'.tr),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('الكل'.tr),
                      selected: draftMethod == null,
                      onSelected: (_) =>
                          setSheetState(() => draftMethod = null),
                    ),
                    ChoiceChip(
                      label: Text('نقداً (كاش)'.tr),
                      selected: draftMethod == 'cash',
                      onSelected: (_) =>
                          setSheetState(() => draftMethod = 'cash'),
                    ),
                    ChoiceChip(
                      label: Text('تحويل بنكي'.tr),
                      selected: draftMethod == 'bank_transfer',
                      onSelected: (_) =>
                          setSheetState(() => draftMethod = 'bank_transfer'),
                    ),
                    ChoiceChip(
                      label: Text('جوال باي'.tr),
                      selected: draftMethod == 'jawwal_pay',
                      onSelected: (_) =>
                          setSheetState(() => draftMethod = 'jawwal_pay'),
                    ),
                    ChoiceChip(
                      label: Text('بال باي'.tr),
                      selected: draftMethod == 'palpay',
                      onSelected: (_) =>
                          setSheetState(() => draftMethod = 'palpay'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                _FilterSectionLabel('مرفق الإيصال'.tr),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('الكل'.tr),
                      selected: draftReceipt == _ReceiptFilter.all,
                      onSelected: (_) =>
                          setSheetState(() => draftReceipt = _ReceiptFilter.all),
                    ),
                    ChoiceChip(
                      label: Text('بإيصال مرفق'.tr),
                      selected: draftReceipt == _ReceiptFilter.withReceipt,
                      onSelected: (_) => setSheetState(
                        () => draftReceipt = _ReceiptFilter.withReceipt,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('بدون إيصال'.tr),
                      selected: draftReceipt == _ReceiptFilter.withoutReceipt,
                      onSelected: (_) => setSheetState(
                        () => draftReceipt = _ReceiptFilter.withoutReceipt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                _FilterSectionLabel('نطاق مبلغ التسوية (₪)'.tr),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: minCtrl,
                        label: 'من (₪)'.tr,
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: maxCtrl,
                        label: 'إلى (₪)'.tr,
                        hint: '500',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'إعادة تعيين'.tr,
                        variant: AppButtonVariant.secondary,
                        onPressed: () {
                          minCtrl.clear();
                          maxCtrl.clear();
                          setSheetState(() {
                            draftMethod = null;
                            draftReceipt = _ReceiptFilter.all;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: '${'عرض النتائج'.tr} ($previewCount)',
                        onPressed: () {
                          setState(() {
                            _settlementMethodFilter = draftMethod;
                            _receiptFilter = draftReceipt;
                            _minSettlementAmount = parseOpt(minCtrl.text);
                            _maxSettlementAmount = parseOpt(maxCtrl.text);
                          });
                          Navigator.of(sheetCtx).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    minCtrl.dispose();
    maxCtrl.dispose();
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year} • ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openShopActions(ShopFinancialAccount acc) async {
    final choice = await AppBottomSheet.show<String>(
      context: context,
      child: AppBottomSheetScaffold(
        title: acc.shopName,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _FinanceRow(
                    label: 'الاتفاقية الحالية'.tr,
                    value: '${acc.agreementSummaryLabel} · ${acc.cycleLabel.tr}',
                  ),
                  const SizedBox(height: 6),
                  _FinanceRow(
                    label: 'سقف الذمة المسموح'.tr,
                    value: AppFormat.price(acc.creditLimit),
                  ),
                  const SizedBox(height: 6),
                  _FinanceRow(
                    label: 'المستحق حالياً على المحل'.tr,
                    value: AppFormat.price(acc.outstandingBalance),
                    bold: true,
                  ),
                  if (acc.isHighCancellationRisk) ...[
                    const SizedBox(height: 8),
                    AppStatusBadge(
                      label:
                          '${'تنبيه: نسبة الإلغاء'.tr} ${acc.cancellationRate.toStringAsFixed(0)}%',
                      tone: BadgeTone.error,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'تعديل اتفاقية العمولة والسقف'.tr,
              onPressed: () => Navigator.of(context).pop('agreement'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'تسجيل دفعة سداد مستلمة'.tr,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop('payment'),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'كشف الحساب التفصيلي'.tr,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop('ledger'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: acc.financialHold
                    ? AppColors.successSoft
                    : AppColors.errorSoft,
                foregroundColor: acc.financialHold
                    ? AppColors.success
                    : AppColors.error,
                side: BorderSide(
                  color: (acc.financialHold ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.25),
                ),
                minimumSize: const Size(double.infinity, ButtonDesign.height),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ButtonDesign.radius),
                ),
              ),
              onPressed: AppHaptics.action(
                () => Navigator.of(context).pop('hold'),
              ),
              child: Text(
                acc.financialHold
                    ? 'فك التجميد المالي للمحل'.tr
                    : 'تجميد مالي مؤقت للمحل'.tr,
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'agreement':
        await _openAgreementEditor(acc);
      case 'payment':
        await _openDirectPaymentSheet(acc);
      case 'ledger':
        await _openLedgerSheet(acc);
      case 'hold':
        final actions = ref.read(adminActionProvider.notifier);
        final ok = await actions.setShopFinancialHold(
          shopId: acc.shopId,
          hold: !acc.financialHold,
        );
        if (!mounted) return;
        showAppSnackBar(
          context,
          ok
              ? (acc.financialHold
                    ? 'تم فك التجميد المالي للمحل'.tr
                    : 'تم تفعيل التجميد المالي للمحل'.tr)
              : 'تعذر تحديث الحالة المالية'.tr,
          isError: !ok,
        );
    }
  }

  Future<void> _openAgreementEditor(ShopFinancialAccount acc) async {
    var type = acc.commissionType;
    var cycle = acc.settlementCycle;
    var autoSuspend = acc.autoSuspendOnLimit;
    final rateCtrl = TextEditingController(
      text: acc.commissionRate.toStringAsFixed(
        acc.commissionRate.truncateToDouble() == acc.commissionRate ? 0 : 1,
      ),
    );
    final fixedCtrl = TextEditingController(
      text: acc.commissionFixedFee.toStringAsFixed(0),
    );
    final limitCtrl = TextEditingController(
      text: acc.creditLimit.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController(text: acc.agreementNotes ?? '');
    var saving = false;

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.94,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return AppBottomSheetScaffold(
            title: '${'اتفاقية العمولة'.tr} — ${acc.shopName}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'نوع احتساب العمولة'.tr,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: AppFont.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('نسبة مئوية (%)'.tr),
                      selected: type == 'percentage',
                      onSelected: (_) =>
                          setSheetState(() => type = 'percentage'),
                    ),
                    ChoiceChip(
                      label: Text('مبلغ ثابت (₪)'.tr),
                      selected: type == 'fixed',
                      onSelected: (_) => setSheetState(() => type = 'fixed'),
                    ),
                    ChoiceChip(
                      label: Text('هجين (% + ₪)'.tr),
                      selected: type == 'hybrid',
                      onSelected: (_) => setSheetState(() => type = 'hybrid'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                if (type == 'percentage' || type == 'hybrid') ...[
                  AppTextField(
                    controller: rateCtrl,
                    label: 'نسبة المنصة (%)'.tr,
                    hint: 'مثال: 5'.tr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (type == 'fixed' || type == 'hybrid') ...[
                  AppTextField(
                    controller: fixedCtrl,
                    label: 'مبلغ ثابت لكل طلب (₪)'.tr,
                    hint: 'مثال: 5'.tr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                AppTextField(
                  controller: limitCtrl,
                  label: 'سقف الذمة المالية المسموح (₪)'.tr,
                  hint: 'مثال: 300'.tr,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Text(
                  'دورة التسوية والسداد'.tr,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: AppFont.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text('أسبوعياً'.tr),
                      selected: cycle == 'weekly',
                      onSelected: (_) => setSheetState(() => cycle = 'weekly'),
                    ),
                    ChoiceChip(
                      label: Text('كل أسبوعين'.tr),
                      selected: cycle == 'biweekly',
                      onSelected: (_) =>
                          setSheetState(() => cycle = 'biweekly'),
                    ),
                    ChoiceChip(
                      label: Text('شهرياً'.tr),
                      selected: cycle == 'monthly',
                      onSelected: (_) => setSheetState(() => cycle = 'monthly'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.primary,
                  title: Text(
                    'تجميد تلقائي عند تجاوز السقف'.tr,
                    style: TextStyle(
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(
                    'يتم تجميد المحل تلقائياً عند بلوغ سقف الذمة حتى سداد المستحقات.'
                        .tr,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  value: autoSuspend,
                  onChanged: saving
                      ? null
                      : AppHaptics.change(
                          (v) => setSheetState(() => autoSuspend = v),
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),

                AppTextField(
                  controller: notesCtrl,
                  label: 'بنود أو ملاحظات الاتفاق (اختياري)'.tr,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),

                AppButton(
                  label: 'حفظ الاتفاقية'.tr,
                  isLoading: saving,
                  onPressed: () async {
                    FocusScope.of(sheetCtx).unfocus();
                    setSheetState(() => saving = true);
                    final rate =
                        double.tryParse(
                          rateCtrl.text.trim().replaceAll('٫', '.'),
                        ) ??
                        0;
                    final fixed =
                        double.tryParse(
                          fixedCtrl.text.trim().replaceAll('٫', '.'),
                        ) ??
                        0;
                    final limit =
                        double.tryParse(
                          limitCtrl.text.trim().replaceAll('٫', '.'),
                        ) ??
                        300;
                    final actions = ref.read(adminActionProvider.notifier);
                    final ok = await actions.updateShopAgreement(
                      shopId: acc.shopId,
                      commissionType: type,
                      commissionRate: type == 'fixed' ? 0 : rate,
                      commissionFixedFee: type == 'percentage' ? 0 : fixed,
                      creditLimit: limit,
                      settlementCycle: cycle,
                      autoSuspendOnLimit: autoSuspend,
                      agreementNotes: notesCtrl.text,
                    );
                    if (!mounted) return;
                    if (!ok) {
                      if (sheetCtx.mounted) setSheetState(() => saving = false);
                      final err = ref.read(adminActionProvider).error;
                      showAppSnackBar(
                        context,
                        err == null
                            ? 'تعذر حفظ الاتفاقية'.tr
                            : actions.errorMessage(err),
                        isError: true,
                      );
                      return;
                    }
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    showAppSnackBar(context, 'تم تحديث اتفاقية العمولة بنجاح'.tr);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    rateCtrl.dispose();
    fixedCtrl.dispose();
    limitCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _openDirectPaymentSheet(ShopFinancialAccount acc) async {
    final amountCtrl = TextEditingController(
      text: acc.outstandingBalance > 0
          ? acc.outstandingBalance.toStringAsFixed(2)
          : '',
    );
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var method = 'cash';
    var saving = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return AppBottomSheetScaffold(
            title: '${'تسجيل دفعة مستلمة'.tr} — ${acc.shopName}',
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: amountCtrl,
                    label: 'المبلغ المستلم (₪) *'.tr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse(
                        (v ?? '').trim().replaceAll('٫', '.'),
                      );
                      if (n == null || n <= 0) {
                        return 'أدخل مبلغاً صحيحاً أكبر من صفر'.tr;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'طريقة التحصيل'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: Text('نقداً (كاش)'.tr),
                        selected: method == 'cash',
                        onSelected: (_) => setSheetState(() => method = 'cash'),
                      ),
                      ChoiceChip(
                        label: Text('تحويل بنكي'.tr),
                        selected: method == 'bank_transfer',
                        onSelected: (_) =>
                            setSheetState(() => method = 'bank_transfer'),
                      ),
                      ChoiceChip(
                        label: Text('جوال باي'.tr),
                        selected: method == 'jawwal_pay',
                        onSelected: (_) =>
                            setSheetState(() => method = 'jawwal_pay'),
                      ),
                      ChoiceChip(
                        label: Text('بال باي'.tr),
                        selected: method == 'palpay',
                        onSelected: (_) =>
                            setSheetState(() => method = 'palpay'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: refCtrl,
                    label: 'رقم الإيصال / الحوالة (اختياري)'.tr,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: noteCtrl,
                    label: 'ملاحظات (اختياري)'.tr,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'تأكيد تسجيل الدفعة'.tr,
                    isLoading: saving,
                    onPressed: () async {
                      FocusScope.of(sheetCtx).unfocus();
                      if (formKey.currentState?.validate() != true) return;
                      setSheetState(() => saving = true);
                      final amount = double.parse(
                        amountCtrl.text.trim().replaceAll('٫', '.'),
                      );
                      final actions = ref.read(adminActionProvider.notifier);
                      final ok = await actions.recordShopPayment(
                        shopId: acc.shopId,
                        amount: amount,
                        paymentMethod: method,
                        referenceNumber: refCtrl.text,
                        note: noteCtrl.text,
                      );
                      if (!mounted) return;
                      if (!ok) {
                        if (sheetCtx.mounted) {
                          setSheetState(() => saving = false);
                        }
                        final err = ref.read(adminActionProvider).error;
                        showAppSnackBar(
                          context,
                          err == null
                              ? 'تعذر تسجيل الدفعة'.tr
                              : actions.errorMessage(err),
                          isError: true,
                        );
                        return;
                      }
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      showAppSnackBar(
                        context,
                        'تم تسجيل الدفعة وتحديث رصيد المحل'.tr,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    amountCtrl.dispose();
    refCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _openLedgerSheet(ShopFinancialAccount acc) async {
    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.9,
      child: Consumer(
        builder: (sheetCtx, sheetRef, _) {
          final ledgerAsync = sheetRef.watch(
            adminShopLedgerProvider(acc.shopId),
          );
          return AppBottomSheetScaffold(
            title: '${'كشف حساب'.tr} — ${acc.shopName}',
            child: ledgerAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => AdminNoticeBanner(
                title: 'تعذر تحميل كشف الحساب',
                message: sheetRef.read(adminRepositoryProvider).mapError(err),
                tone: BadgeTone.error,
              ),
              data: (data) {
                if (data.ledger.isEmpty) {
                  return const AdminEmptyState(
                    title: 'لا توجد حركات مالية بعد',
                    message:
                        'ستظهر هنا عمولات الطلبات المسلّمة ودفعات السداد المؤكدة.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in data.ledger) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
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
                                    entry.note?.trim().isNotEmpty == true
                                        ? entry.note!.trim()
                                        : entry.typeLabel.tr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: AppFont.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(entry.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${entry.isDebit ? '+' : '-'}${AppFormat.price(entry.amount)}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: AppFont.extraBold,
                                    color: entry.isDebit
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _reviewSettlement(
    ShopSettlement stl, {
    required bool approve,
  }) async {
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: approve ? 'اعتماد دفعة التسوية'.tr : 'رفض طلب التسوية'.tr,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                approve
                    ? '${'تأكيد استلام مبلغ'.tr} ${AppFormat.price(stl.amount)} ${'من'.tr} ${stl.shopName ?? ''}؟'
                    : 'اكتب سبب رفض طلب التسوية ليظهر لصاحب المحل.'.tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: noteCtrl,
                label: approve
                    ? 'ملاحظة الإدارة (اختياري)'.tr
                    : 'سبب الرفض *'.tr,
                validator: approve
                    ? null
                    : (v) => Validators.required(v, field: 'سبب الرفض'.tr),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: approve ? 'تأكيد الاستلام والخصم'.tr : 'تأكيد الرفض'.tr,
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'إلغاء'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirmed != true || !mounted) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.reviewSettlement(
      settlementId: stl.id,
      approve: approve,
      adminNote: note,
    );
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        err == null ? 'تعذر تنفيذ الإجراء'.tr : actions.errorMessage(err),
        isError: true,
      );
      return;
    }
    showAppSnackBar(
      context,
      approve ? 'تم اعتماد التسوية وتحديث الذمة'.tr : 'تم رفض طلب التسوية'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminRevenueOverviewProvider);
    final busy = ref.watch(adminActionProvider).isLoading;
    final regions =
        ref.watch(adminGazaRegionsProvider).asData?.value ??
        kDefaultGazaRegions;
    final govGroups = groupGazaRegions(regions);

    return AdminScaffold(
      title: 'الإيرادات والعمولات'.tr,
      showBack: true,
      showBottomNav: false,
      body: overviewAsync.skeletonWhen(
        placeholder: const AdminRevenueOverview(),
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل بيانات الإيرادات',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminRevenueOverviewProvider),
            ),
          ],
        ),
        data: (overview) {
          final allShops = overview.shops;
          final filteredShops = _applyShopFilters(allShops, govGroups);
          final allSettlements = overview.pendingSettlements;
          final filteredSettlements = _applySettlementFilters(allSettlements);

          // Live counts for Shop quick filter pills
          final duesCount = allShops.where((s) => s.outstandingBalance > 0).length;
          final nearLimitCount = allShops
              .where((s) => s.isNearLimit || s.isOverLimit)
              .length;
          final onHoldCount = allShops.where((s) => s.financialHold).length;
          final pendingAgCount =
              allShops.where((s) => !s.isAgreementAccepted).length;
          final highCancelCount =
              allShops.where((s) => s.isHighCancellationRisk).length;
          final settledCount =
              allShops.where((s) => s.outstandingBalance <= 0).length;

          // Filtered aggregates for the executive summary strip
          final filteredSalesSum = filteredShops.fold<double>(
            0,
            (s, e) => s + e.deliveredSales,
          );
          final filteredCommSum = filteredShops.fold<double>(
            0,
            (s, e) => s + e.commissionEarned,
          );
          final filteredDueSum = filteredShops.fold<double>(
            0,
            (s, e) => s + e.outstandingBalance,
          );

          final filteredSettlementsSum = filteredSettlements.fold<double>(
            0,
            (s, e) => s + e.amount,
          );

          return AppRefreshIndicator(
            onRefresh: () => ref.refresh(adminRevenueOverviewProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              children: [
                // 1) Platform Financial Summary KPIs
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'عمولات المنصة المكتسبة',
                        value: AppFormat.price(overview.totalCommissionEarned),
                        subtitle:
                            '${'مبيعات'.tr}: ${AppFormat.price(overview.totalDeliveredSales)}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'المحصّل فعلياً',
                        value: AppFormat.price(overview.totalCollected),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AdminKpiCard(
                        label: 'مستحقات عند المحلات',
                        value: AppFormat.price(overview.totalOutstanding),
                        subtitle: overview.shopsOnHold > 0
                            ? '${overview.shopsOnHold} ${'محل مجمّد مالياً'.tr}'
                            : null,
                        onTap: () => setState(() {
                          _tab = _RevenueTab.shops;
                          _shopQuick = _ShopRiskQuick.hasDues;
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AdminKpiCard(
                        label: 'تسويات بانتظار التأكيد',
                        value: '${overview.pendingSettlementsCount}',
                        subtitle: AppFormat.price(
                          overview.pendingSettlementsAmount,
                        ),
                        onTap: () =>
                            setState(() => _tab = _RevenueTab.settlements),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 2) Tabs: Shop Accounts vs Pending Settlements
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            '${'حسابات المحلات'.tr} (${overview.shops.length})',
                          ),
                        ),
                        selected: _tab == _RevenueTab.shops,
                        onSelected: (_) =>
                            setState(() => _tab = _RevenueTab.shops),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            '${'طلبات التسوية'.tr} (${overview.pendingSettlementsCount})',
                          ),
                        ),
                        selected: _tab == _RevenueTab.settlements,
                        onSelected: (_) =>
                            setState(() => _tab = _RevenueTab.settlements),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 3) Professional Search, Quick Filters, Sort & Advanced Filter Toolbar
                if (_tab == _RevenueTab.shops) ...[
                  AppFilterToolbar(
                    padding: EdgeInsets.zero,
                    searchValue: _shopSearch,
                    searchHint: 'ابحث باسم المحل أو المنطقة في غزة...',
                    onSearchChanged: (v) => setState(() => _shopSearch = v),
                    sortLabel: _shopSortLabel(_shopSort),
                    isDefaultSort:
                        _shopSort == _ShopRevenueSort.highestOutstanding,
                    onOpenSort: _openShopSortSheet,
                    onOpenAdvancedFilter: () =>
                        _openShopAdvancedFilters(allShops, regions, govGroups),
                    activeFacetCount: _activeShopFacetCount,
                    quickOptions: [
                      AppQuickFilterOption(
                        id: 'rev_all',
                        label: 'الكل',
                        count: allShops.length,
                        selected: _shopQuick == _ShopRiskQuick.all,
                        onTap: () =>
                            setState(() => _shopQuick = _ShopRiskQuick.all),
                      ),
                      AppQuickFilterOption(
                        id: 'rev_dues',
                        label: 'عليها مستحقات',
                        count: duesCount,
                        selected: _shopQuick == _ShopRiskQuick.hasDues,
                        onTap: () =>
                            setState(() => _shopQuick = _ShopRiskQuick.hasDues),
                      ),
                      AppQuickFilterOption(
                        id: 'rev_limit',
                        label: 'قرب/تجاوز السقف',
                        count: nearLimitCount,
                        selected: _shopQuick == _ShopRiskQuick.nearOrOverLimit,
                        onTap: () => setState(
                          () => _shopQuick = _ShopRiskQuick.nearOrOverLimit,
                        ),
                      ),
                      AppQuickFilterOption(
                        id: 'rev_hold',
                        label: 'مجمّد مالياً',
                        count: onHoldCount,
                        selected: _shopQuick == _ShopRiskQuick.onHold,
                        onTap: () =>
                            setState(() => _shopQuick = _ShopRiskQuick.onHold),
                      ),
                      AppQuickFilterOption(
                        id: 'rev_agreement',
                        label: 'بانتظار الموافقة',
                        count: pendingAgCount,
                        selected: _shopQuick == _ShopRiskQuick.pendingAgreement,
                        onTap: () => setState(
                          () => _shopQuick = _ShopRiskQuick.pendingAgreement,
                        ),
                      ),
                      AppQuickFilterOption(
                        id: 'rev_cancel',
                        label: 'إلغاء مرتفع',
                        count: highCancelCount,
                        selected: _shopQuick == _ShopRiskQuick.highCancellation,
                        onTap: () => setState(
                          () => _shopQuick = _ShopRiskQuick.highCancellation,
                        ),
                      ),
                      AppQuickFilterOption(
                        id: 'rev_settled',
                        label: 'خالي الذمة',
                        count: settledCount,
                        selected: _shopQuick == _ShopRiskQuick.settled,
                        onTap: () =>
                            setState(() => _shopQuick = _ShopRiskQuick.settled),
                      ),
                    ],
                    activeTags: [
                      if (_selectedRegion != null)
                        AppActiveFilterTag(
                          label:
                              '${'المنطقة'.tr}: ${AppLang.isEn ? (_selectedRegion!.nameEn ?? _selectedRegion!.name) : _selectedRegion!.name}',
                          onRemove: () =>
                              setState(() => _selectedRegion = null),
                        ),
                      if (_commissionTypeFilter != null)
                        AppActiveFilterTag(
                          label: _commissionTypeLabel(_commissionTypeFilter!).tr,
                          onRemove: () =>
                              setState(() => _commissionTypeFilter = null),
                        ),
                      if (_cycleFilter != null)
                        AppActiveFilterTag(
                          label: _cycleFilterLabel(_cycleFilter!).tr,
                          onRemove: () => setState(() => _cycleFilter = null),
                        ),
                      if (_agreementAcceptedFilter != null)
                        AppActiveFilterTag(
                          label: (_agreementAcceptedFilter!
                                  ? 'الاتفاقية موثّقة'
                                  : 'بانتظار موافقة المحل')
                              .tr,
                          onRemove: () =>
                              setState(() => _agreementAcceptedFilter = null),
                        ),
                      if (_onlyWithPendingSettlements)
                        AppActiveFilterTag(
                          label: 'لديها تسوية معلّقة'.tr,
                          onRemove: () => setState(
                            () => _onlyWithPendingSettlements = false,
                          ),
                        ),
                      if (_minDue != null || _maxDue != null)
                        AppActiveFilterTag(
                          label:
                              '${'المستحق'.tr}: ${_minDue != null ? AppFormat.price(_minDue!) : '0'} — ${_maxDue != null ? AppFormat.price(_maxDue!) : '∞'}',
                          onRemove: () => setState(() {
                            _minDue = null;
                            _maxDue = null;
                          }),
                        ),
                    ],
                    totalCount: allShops.length,
                    filteredCount: filteredShops.length,
                    hasActiveCustomization: _hasShopCustomization,
                    onClearAll: _clearShopFilters,
                    showCountWhenUnfiltered: true,
                  ),

                  // Filtered Financial Totals Strip (when customized)
                  if (_hasShopCustomization && filteredShops.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _FilteredMetricCell(
                              label: 'مبيعات النتائج'.tr,
                              value: AppFormat.price(filteredSalesSum),
                            ),
                          ),
                          Expanded(
                            child: _FilteredMetricCell(
                              label: 'عمولات النتائج'.tr,
                              value: AppFormat.price(filteredCommSum),
                            ),
                          ),
                          Expanded(
                            child: _FilteredMetricCell(
                              label: 'مستحقات النتائج'.tr,
                              value: AppFormat.price(filteredDueSum),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),

                  if (allShops.isEmpty)
                    const AdminEmptyState(
                      title: 'لا توجد حسابات محلات بعد',
                      message:
                          'ستظهر هنا اتفاقيات العمولات والمستحقات المالية لكل محل.',
                    )
                  else if (filteredShops.isEmpty)
                    const AdminEmptyState(
                      title: 'لا توجد حسابات مطابقة للفلاتر',
                      message:
                          'جرّب تعديل معايير الفلترة أو الضغط على مسح الكل لعرض جميع المحلات.',
                    )
                  else
                    for (final acc in filteredShops) ...[
                      _ShopFinanceAccountCard(
                        account: acc,
                        onTap: busy ? null : () => _openShopActions(acc),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ] else ...[
                  AppFilterToolbar(
                    padding: EdgeInsets.zero,
                    searchValue: _settlementSearch,
                    searchHint: 'ابحث باسم المحل أو رقم الحوالة...',
                    onSearchChanged: (v) =>
                        setState(() => _settlementSearch = v),
                    sortLabel: _settlementSortLabel(_settlementSort),
                    isDefaultSort: _settlementSort == _SettlementSort.newest,
                    onOpenSort: _openSettlementSortSheet,
                    onOpenAdvancedFilter: () =>
                        _openSettlementAdvancedFilters(allSettlements),
                    activeFacetCount: _activeSettlementFacetCount,
                    quickOptions: [
                      AppQuickFilterOption(
                        id: 'stl_all',
                        label: 'الكل',
                        count: allSettlements.length,
                        selected:
                            _settlementMethodFilter == null &&
                            _receiptFilter == _ReceiptFilter.all,
                        onTap: () => setState(() {
                          _settlementMethodFilter = null;
                          _receiptFilter = _ReceiptFilter.all;
                        }),
                      ),
                      AppQuickFilterOption(
                        id: 'stl_cash',
                        label: 'نقداً (كاش)',
                        count: allSettlements
                            .where((s) => s.paymentMethod == 'cash')
                            .length,
                        selected: _settlementMethodFilter == 'cash',
                        onTap: () =>
                            setState(() => _settlementMethodFilter = 'cash'),
                      ),
                      AppQuickFilterOption(
                        id: 'stl_bank',
                        label: 'تحويل بنكي',
                        count: allSettlements
                            .where((s) => s.paymentMethod == 'bank_transfer')
                            .length,
                        selected: _settlementMethodFilter == 'bank_transfer',
                        onTap: () => setState(
                          () => _settlementMethodFilter = 'bank_transfer',
                        ),
                      ),
                      AppQuickFilterOption(
                        id: 'stl_jpay',
                        label: 'جوال باي',
                        count: allSettlements
                            .where((s) => s.paymentMethod == 'jawwal_pay')
                            .length,
                        selected: _settlementMethodFilter == 'jawwal_pay',
                        onTap: () => setState(
                          () => _settlementMethodFilter = 'jawwal_pay',
                        ),
                      ),
                      AppQuickFilterOption(
                        id: 'stl_palpay',
                        label: 'بال باي',
                        count: allSettlements
                            .where((s) => s.paymentMethod == 'palpay')
                            .length,
                        selected: _settlementMethodFilter == 'palpay',
                        onTap: () =>
                            setState(() => _settlementMethodFilter = 'palpay'),
                      ),
                      AppQuickFilterOption(
                        id: 'stl_receipt',
                        label: 'بإيصال مرفق',
                        count: allSettlements
                            .where(
                              (s) => s.receiptUrl?.trim().isNotEmpty ?? false,
                            )
                            .length,
                        selected: _receiptFilter == _ReceiptFilter.withReceipt,
                        onTap: () => setState(
                          () => _receiptFilter =
                              _receiptFilter == _ReceiptFilter.withReceipt
                              ? _ReceiptFilter.all
                              : _ReceiptFilter.withReceipt,
                        ),
                      ),
                    ],
                    activeTags: [
                      if (_settlementMethodFilter != null)
                        AppActiveFilterTag(
                          label: _methodFilterLabel(_settlementMethodFilter!).tr,
                          onRemove: () =>
                              setState(() => _settlementMethodFilter = null),
                        ),
                      if (_receiptFilter != _ReceiptFilter.all)
                        AppActiveFilterTag(
                          label: (_receiptFilter == _ReceiptFilter.withReceipt
                                  ? 'بإيصال مرفق'
                                  : 'بدون إيصال')
                              .tr,
                          onRemove: () => setState(
                            () => _receiptFilter = _ReceiptFilter.all,
                          ),
                        ),
                      if (_minSettlementAmount != null ||
                          _maxSettlementAmount != null)
                        AppActiveFilterTag(
                          label:
                              '${'المبلغ'.tr}: ${_minSettlementAmount != null ? AppFormat.price(_minSettlementAmount!) : '0'} — ${_maxSettlementAmount != null ? AppFormat.price(_maxSettlementAmount!) : '∞'}',
                          onRemove: () => setState(() {
                            _minSettlementAmount = null;
                            _maxSettlementAmount = null;
                          }),
                        ),
                    ],
                    totalCount: allSettlements.length,
                    filteredCount: filteredSettlements.length,
                    hasActiveCustomization: _hasSettlementCustomization,
                    onClearAll: _clearSettlementFilters,
                    showCountWhenUnfiltered: true,
                  ),

                  if (_hasSettlementCustomization &&
                      filteredSettlements.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'إجمالي مبالغ الطلبات المصفّاة'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: AppFont.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          Text(
                            AppFormat.price(filteredSettlementsSum),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFont.extraBold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),

                  if (allSettlements.isEmpty)
                    const AdminEmptyState(
                      title: 'لا توجد طلبات تسوية معلّقة',
                      message:
                          'ستظهر هنا إيصالات السداد المرفوعة من المحلات لمراجعتها واعتمادها.',
                    )
                  else if (filteredSettlements.isEmpty)
                    const AdminEmptyState(
                      title: 'لا توجد طلبات تسوية مطابقة',
                      message:
                          'جرّب تعديل البحث أو إزالة الفلاتر لعرض جميع الطلبات المعلّقة.',
                    )
                  else
                    for (final stl in filteredSettlements) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: SellerDesign.statCardBackground,
                          borderRadius: BorderRadius.circular(
                            CardDesign.radius,
                          ),
                          border: Border.all(
                            color: SellerDesign.statCardBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    stl.shopName ?? 'محل'.tr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: AppFont.bold),
                                  ),
                                ),
                                Text(
                                  AppFormat.price(stl.amount),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: AppFont.extraBold,
                                        color: AppColors.text,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${stl.methodLabel.tr}${stl.referenceNumber != null ? ' · #${stl.referenceNumber}' : ''} · ${_formatDate(stl.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            if (stl.notes?.trim().isNotEmpty ?? false) ...[
                              const SizedBox(height: 4),
                              Text(
                                stl.notes!.trim(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (stl.receiptUrl?.trim().isNotEmpty ?? false) ...[
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.sm,
                                ),
                                child: AppNetworkImage(
                                  stl.receiptUrl!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'اعتماد الاستلام'.tr,
                                    onPressed: busy
                                        ? null
                                        : () => _reviewSettlement(
                                            stl,
                                            approve: true,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.errorSoft,
                                      foregroundColor: AppColors.error,
                                      side: BorderSide(
                                        color: AppColors.error.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        ButtonDesign.height,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ButtonDesign.radius,
                                        ),
                                      ),
                                    ),
                                    onPressed: busy
                                        ? null
                                        : AppHaptics.action(
                                            () => _reviewSettlement(
                                              stl,
                                              approve: false,
                                            ),
                                          ),
                                    child: Text('رفض'.tr),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
    );
  }
}

class _FilteredMetricCell extends StatelessWidget {
  const _FilteredMetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFont.semiBold,
            color: AppColors.primaryDark.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: AppFont.extraBold,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopFinanceAccountCard extends StatelessWidget {
  const _ShopFinanceAccountCard({
    required this.account,
    required this.onTap,
  });

  final ShopFinancialAccount account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final barColor = account.financialHold || account.isOverLimit
        ? AppColors.error
        : (account.isNearLimit ? AppColors.warning : AppColors.primary);

    return Material(
      color: SellerDesign.statCardBackground,
      borderRadius: BorderRadius.circular(CardDesign.radius),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(CardDesign.radius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CardDesign.radius),
            border: Border.all(color: SellerDesign.statCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: AppFont.bold),
                        ),
                        if (account.shopCity?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${account.shopCity!.trim()} · ${account.cycleLabel.tr}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppStatusBadge(
                    label: account.agreementSummaryLabel,
                    tone: BadgeTone.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  AppStatusBadge(
                    label: account.isAgreementAccepted
                        ? 'الاتفاقية موثّقة'
                        : 'بانتظار موافقة المحل',
                    tone: account.isAgreementAccepted
                        ? BadgeTone.success
                        : BadgeTone.warning,
                  ),
                  if (account.financialHold)
                    const AppStatusBadge(
                      label: 'تجميد مالي',
                      tone: BadgeTone.error,
                    ),
                  if (account.pendingSettlementsCount > 0)
                    AppStatusBadge(
                      label:
                          '${account.pendingSettlementsCount} ${'تسوية معلّقة'.tr}',
                      tone: BadgeTone.primary,
                    ),
                  if (account.isHighCancellationRisk)
                    AppStatusBadge(
                      label:
                          '${'إلغاء مرتفع'.tr} ${account.cancellationRate.toStringAsFixed(0)}%',
                      tone: BadgeTone.error,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _FinanceRow(
                label: 'المبيعات المسلّمة'.tr,
                value: AppFormat.price(account.deliveredSales),
              ),
              const SizedBox(height: 4),
              _FinanceRow(
                label: 'حصة المنصة / المسدّد'.tr,
                value:
                    '${AppFormat.price(account.commissionEarned)} / ${AppFormat.price(account.totalPaid)}',
              ),
              const SizedBox(height: 4),
              _FinanceRow(
                label: 'المستحق حالياً'.tr,
                value:
                    '${AppFormat.price(account.outstandingBalance)} / ${AppFormat.price(account.creditLimit)}',
                bold: true,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: account.limitUsageRatio,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? AppFont.extraBold : AppFont.semiBold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}
