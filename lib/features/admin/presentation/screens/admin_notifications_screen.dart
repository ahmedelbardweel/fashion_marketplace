import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/notifications/notification_list_components.dart';
import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/push_notification_settings_card.dart';
import '../../../../core/notifications/read_notifications_provider.dart';
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
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  NotificationFilterState _filter = NotificationFilterState.empty;
  final Set<String> _sessionUnreadIds = {};

  Future<void> _openComposer() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var audience = 'all';
    String? targetRegion;
    var sending = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.92,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return AppBottomSheetScaffold(
            title: 'إرسال إشعار جديد'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'الجمهور المستهدف'.tr,
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
                        label: Text('الجميع'.tr),
                        selected: audience == 'all',
                        onSelected: (_) => setSheetState(() => audience = 'all'),
                      ),
                      ChoiceChip(
                        label: Text('العملاء فقط'.tr),
                        selected: audience == 'customer',
                        onSelected: (_) =>
                            setSheetState(() => audience = 'customer'),
                      ),
                      ChoiceChip(
                        label: Text('المحلات فقط'.tr),
                        selected: audience == 'shop',
                        onSelected: (_) =>
                            setSheetState(() => audience = 'shop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Text(
                    'تخصيص لمنطقة في قطاع غزة (اختياري)'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: targetRegion != null
                              ? '${'المنطقة'.tr}: $targetRegion'
                              : 'كل مناطق قطاع غزة'.tr,
                          variant: AppButtonVariant.secondary,
                          onPressed: sending
                              ? null
                              : () async {
                                  final regions =
                                      ref
                                          .read(adminGazaRegionsProvider)
                                          .asData
                                          ?.value ??
                                      kDefaultGazaRegions;
                                  final picked =
                                      await showGazaRegionPickerSheet(
                                        context: sheetCtx,
                                        regions: regions,
                                        selectedRegionName: targetRegion,
                                        allowClear: true,
                                        title: 'استهداف منطقة في قطاع غزة',
                                      );
                                  if (picked == null || !sheetCtx.mounted) {
                                    return;
                                  }
                                  setSheetState(() {
                                    targetRegion = picked.name.isEmpty
                                        ? null
                                        : picked.name;
                                  });
                                },
                        ),
                      ),
                      if (targetRegion != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'مسح'.tr,
                          variant: AppButtonVariant.secondary,
                          expand: false,
                          onPressed: sending
                              ? null
                              : () => setSheetState(() => targetRegion = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: titleCtrl,
                    label: 'عنوان الإشعار *'.tr,
                    hint: 'مثال: عروض جديدة في غزة أو تحديث التوصيل'.tr,
                    validator: (v) =>
                        Validators.required(v, field: 'العنوان'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: bodyCtrl,
                    label: 'نص الإشعار *'.tr,
                    hint: 'اكتب تفاصيل الإشعار بوضوح...'.tr,
                    maxLines: 4,
                    validator: (v) =>
                        Validators.required(v, field: 'نص الإشعار'.tr),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: 'إرسال الإشعار الآن'.tr,
                    isLoading: sending,
                    onPressed: () async {
                      FocusScope.of(sheetCtx).unfocus();
                      if (formKey.currentState?.validate() != true) return;
                      setSheetState(() => sending = true);
                      final actions = ref.read(adminActionProvider.notifier);
                      final ok = await actions.sendNotification(
                        title: titleCtrl.text,
                        body: bodyCtrl.text,
                        audience: audience,
                        targetRegion: targetRegion,
                      );
                      if (!mounted) return;
                      if (!ok) {
                        if (sheetCtx.mounted) {
                          setSheetState(() => sending = false);
                        }
                        final err = ref.read(adminActionProvider).error;
                        showAppSnackBar(
                          context,
                          err == null
                              ? 'تعذر إرسال الإشعار'.tr
                              : actions.errorMessage(err),
                          isError: true,
                        );
                        return;
                      }
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      showAppSnackBar(context, 'تم إرسال الإشعار بنجاح'.tr);
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
    titleCtrl.dispose();
    bodyCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(adminNotificationsProvider);
    final readIds = ref.watch(readNotificationIdsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'الإشعارات الجماعية والموجهة'.tr,
      showBack: true,
      showBottomNav: false,
      actions: [
        IconButton(
          tooltip: 'تخصيص أنواع الإشعارات'.tr,
          icon: Icon(Icons.tune_rounded, color: AppColors.text, size: 21),
          onPressed: AppHaptics.action(
            () => showNotificationPreferencesSheet(context, ref),
          ),
        ),
      ],
      bottom: AppButton(
        label: 'إرسال إشعار جديد'.tr,
        isLoading: busy,
        onPressed: _openComposer,
      ),
      body: notifsAsync.skeletonWhen(
        placeholder: LoadingFixtures.notifications,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل الإشعارات',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminNotificationsProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return AdminCenteredEmptyView(
              onRefresh: () => ref.refresh(adminNotificationsProvider.future),
              title: 'لا توجد إشعارات مرسلة بعد',
              message:
                  'أرسل أول إشعار للعملاء أو المحلات أو لمناطق محددة في قطاع غزة.',
            );
          }

          markVisibleNotificationsRead(
            ref: ref,
            notifications: items,
            readIds: readIds,
            sessionUnreadIds: _sessionUnreadIds,
            isMounted: () => mounted,
          );
          final filtered = filterNotifications(
            items,
            _filter,
            readIds: readIds,
          );
          final sections = buildNotificationSections(filtered);

          return Column(
            children: [
              AppFilterToolbar(
                searchValue: _filter.search,
                searchHint: 'ابحث في الإشعارات...',
                onSearchChanged: (val) =>
                    setState(() => _filter = _filter.copyWith(search: val)),
                sortLabel: _filter.oldestFirst ? 'الأقدم' : 'الأحدث',
                isDefaultSort: !_filter.oldestFirst,
                onOpenSort: () async {
                  final selected = await showAppSortSheet<bool>(
                    context: context,
                    current: _filter.oldestFirst,
                    options: const [
                      AppSortChoice(
                        value: false,
                        label: 'الأحدث',
                        icon: AppIcons.arrowDown,
                      ),
                      AppSortChoice(
                        value: true,
                        label: 'الأقدم',
                        icon: AppIcons.arrowUp,
                      ),
                    ],
                  );
                  if (selected != null && mounted) {
                    setState(
                      () => _filter = _filter.copyWith(oldestFirst: selected),
                    );
                  }
                },
                quickOptions: [
                  AppQuickFilterOption(
                    id: 'admin_notif_all',
                    label: 'الكل',
                    selected: _filter.category == null,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(clearCategory: true),
                    ),
                  ),
                  for (final cat in NotificationCategory.values)
                    AppQuickFilterOption(
                      id: 'admin_notif_cat_${cat.key}',
                      label: cat.shortLabel,
                      selected: _filter.category == cat,
                      onTap: () => setState(() {
                        final same = _filter.category == cat;
                        _filter = same
                            ? _filter.copyWith(clearCategory: true)
                            : _filter.copyWith(category: cat);
                      }),
                    ),
                  for (final preset in DateRangePreset.values)
                    if (preset != DateRangePreset.all)
                      AppQuickFilterOption(
                        id: 'admin_notif_${preset.name}',
                        label: preset.labelAr,
                        selected: _filter.datePreset == preset,
                        onTap: () => setState(() {
                          final same = _filter.datePreset == preset;
                          _filter = _filter.copyWith(
                            datePreset: same ? DateRangePreset.all : preset,
                          );
                        }),
                      ),
                ],
                totalCount: items.length,
                filteredCount: filtered.length,
                hasActiveCustomization: _filter.hasActiveFilters,
                onClearAll: () =>
                    setState(() => _filter = NotificationFilterState.empty),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
                child: AppRefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(adminNotificationsProvider.future),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          children: [
                            AppFilterEmptyState(
                              onReset: () => setState(
                                () => _filter = NotificationFilterState.empty,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.page,
                          itemCount: sections.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final entry = sections[index];
                            if (entry.header != null) {
                              return NotificationSectionHeader(
                                title: entry.header!,
                              );
                            }
                            final n = entry.item!;
                            final isUnread = _sessionUnreadIds.contains(n.id);
                            return NotificationItemCard(
                              notification: n,
                              isUnread: isUnread,
                              onTap: n.hasDeepLink
                                  ? () => navigateToNotificationTarget(
                                      context: context,
                                      ref: ref,
                                      notification: n,
                                      role: UserRole.admin,
                                    )
                                  : null,
                              extraBadges: [
                                AppStatusBadge(
                                  label: n.audienceLabel,
                                  tone: n.targetRegion != null
                                      ? BadgeTone.primary
                                      : BadgeTone.neutral,
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
