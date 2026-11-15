import 'package:fashion_marketplace/core/utils/app_haptics.dart';

import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/catalog_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_async_body.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/widgets/app_filter_bar.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  NotificationFilterState _filter = NotificationFilterState.empty;

  static const _audienceOptions = [
    ('all_users', 'الكل (العملاء والمتاجر)'),
    ('customer', 'العملاء'),
    ('shop', 'أصحاب المتاجر'),
  ];

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var audience = 'all';
    final formKey = GlobalKey<FormState>();

    final saved = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'إرسال إشعار'.tr,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: titleController,
                    label: 'العنوان'.tr,
                    validator: (value) =>
                        Validators.required(value, field: 'العنوان'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: bodyController,
                    label: 'المحتوى'.tr,
                    maxLines: 4,
                    validator: (value) =>
                        Validators.required(value, field: 'المحتوى'.tr),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'الجمهور'.tr,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in [
                        ('all', 'الجميع'.tr),
                        ('customer', 'المستخدمون'.tr),
                        ('shop', 'المحلات'.tr),
                      ])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: audience == option.$1,
                          onSelected: AppHaptics.change(
                            (_) => setModalState(() => audience = option.$1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'إرسال'.tr,
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    final title = titleController.text;
    final body = bodyController.text;
    final selectedAudience = audience;
    titleController.dispose();
    bodyController.dispose();
    if (saved != true) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.sendNotification(
      title: title,
      body: body,
      audience: selectedAudience,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر الإرسال'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم إرسال الإشعار'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(adminNotificationsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'الإشعارات'.tr,
      body: AdminAsyncBody<List<AdminNotification>>(
        placeholder: LoadingFixtures.notifications,
        value: notifications,
        emptyMessage: 'لا توجد إشعارات مرسلة بعد'.tr,
        isEmpty: (data) => data.isEmpty,
        onRetry: () => ref.invalidate(adminNotificationsProvider),
        onRefresh: () => ref.refresh(adminNotificationsProvider.future),
        builder: (items) {
          final filtered = filterNotifications(items, _filter);
          final audienceCounts = <String, int>{};
          for (final item in items) {
            audienceCounts[item.audience] =
                (audienceCounts[item.audience] ?? 0) + 1;
          }

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
                    count: items.length,
                    selected:
                        _filter.audience == null &&
                        _filter.datePreset == DateRangePreset.all,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        clearAudience: true,
                        datePreset: DateRangePreset.all,
                      ),
                    ),
                  ),
                  for (final aud in _audienceOptions)
                    AppQuickFilterOption(
                      id: 'admin_notif_${aud.$1}',
                      label: aud.$2,
                      count: audienceCounts[aud.$1] ?? 0,
                      selected: _filter.audience == aud.$1,
                      onTap: () => setState(() {
                        final same = _filter.audience == aud.$1;
                        _filter = same
                            ? _filter.copyWith(clearAudience: true)
                            : _filter.copyWith(audience: aud.$1);
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
                onClearAll: () => setState(
                  () => _filter = NotificationFilterState.empty,
                ),
                showCountWhenUnfiltered: true,
              ),
              Expanded(
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
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.page,
                        children: filtered
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        item.audienceLabel,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(item.body),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
      bottom: AppButton(
        label: 'إرسال إشعار'.tr,
        isLoading: busy,
        onPressed: () => _send(context, ref),
      ),
    );
  }
}
