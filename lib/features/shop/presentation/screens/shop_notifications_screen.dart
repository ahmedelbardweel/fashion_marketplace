import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_shell.dart';

class ShopNotificationsScreen extends ConsumerStatefulWidget {
  const ShopNotificationsScreen({super.key});

  @override
  ConsumerState<ShopNotificationsScreen> createState() =>
      _ShopNotificationsScreenState();
}

class _ShopNotificationsScreenState
    extends ConsumerState<ShopNotificationsScreen> {
  NotificationFilterState _filter = NotificationFilterState.empty;
  final Set<String> _sessionUnreadIds = {};

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final result = await AppBottomSheet.show<
        ({String title, String body, String scope})>(
      context: context,
      child: const _ShopSendNotificationSheet(),
    );
    if (result == null) return;

    final actions = ref.read(shopCatalogActionProvider.notifier);
    final ok = await actions.sendNotification(
      title: result.title,
      body: result.body,
      scope: result.scope,
    );
    if (!context.mounted) return;
    if (!ok) {
      final error = ref.read(shopCatalogActionProvider).error;
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
    final notifications = ref.watch(shopNotificationsProvider);
    final readIds = ref.watch(readNotificationIdsProvider);
    final shop = ref.watch(myShopProvider).asData?.value;
    final approved = shop?.visibleStatus == ShopStatus.approved;
    final busy = ref.watch(shopCatalogActionProvider).isLoading;

    return ShopScaffold(
      title: 'الإشعارات'.tr,
      showBottomNav: false,
      body: notifications.skeletonWhen(
        placeholder: LoadingFixtures.notifications,
        error: (error, _) => Center(
          child: Text(ref.read(shopCatalogRepositoryProvider).mapError(error)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return AppRefreshIndicator(
              onRefresh: () => ref.refresh(shopNotificationsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.page,
                children: [AppCard(child: Text('لا توجد إشعارات حالياً'.tr))],
              ),
            );
          }

          markVisibleNotificationsRead(
            ref: ref,
            notifications: items,
            readIds: readIds,
            sessionUnreadIds: _sessionUnreadIds,
            isMounted: () => mounted,
          );
          final filtered = filterNotifications(items, _filter);

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
                    id: 'shop_notif_aud_all',
                    label: 'الكل',
                    selected: _filter.audience == null,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(clearAudience: true),
                    ),
                  ),
                  AppQuickFilterOption(
                    id: 'shop_notif_aud_shop',
                    label: 'أصحاب المتاجر',
                    selected: _filter.audience == 'shop',
                    onTap: () => setState(() {
                      final same = _filter.audience == 'shop';
                      _filter = same
                          ? _filter.copyWith(clearAudience: true)
                          : _filter.copyWith(audience: 'shop');
                    }),
                  ),
                  AppQuickFilterOption(
                    id: 'shop_notif_aud_sent',
                    label: 'إشعاراتي المرسلة',
                    selected: _filter.audience == 'customer',
                    onTap: () => setState(() {
                      final same = _filter.audience == 'customer';
                      _filter = same
                          ? _filter.copyWith(clearAudience: true)
                          : _filter.copyWith(audience: 'customer');
                    }),
                  ),
                  AppQuickFilterOption(
                    id: 'shop_notif_aud_global',
                    label: 'الكل (العملاء والمتاجر)',
                    selected: _filter.audience == 'all',
                    onTap: () => setState(() {
                      final same = _filter.audience == 'all';
                      _filter = same
                          ? _filter.copyWith(clearAudience: true)
                          : _filter.copyWith(audience: 'all');
                    }),
                  ),
                  for (final preset in DateRangePreset.values)
                    if (preset != DateRangePreset.all)
                      AppQuickFilterOption(
                        id: 'shop_notif_${preset.name}',
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
                activeTags: [
                  if (_filter.audience != null)
                    AppActiveFilterTag(
                      label: _filter.audience == 'shop'
                          ? 'أصحاب المتاجر'.tr
                          : _filter.audience == 'customer'
                          ? 'إشعاراتي المرسلة'.tr
                          : 'الكل (العملاء والمتاجر)'.tr,
                      onRemove: () => setState(
                        () => _filter = _filter.copyWith(clearAudience: true),
                      ),
                    ),
                  if (_filter.datePreset != DateRangePreset.all)
                    AppActiveFilterTag(
                      label: _filter.datePreset.labelAr.tr,
                      onRemove: () => setState(
                        () => _filter = _filter.copyWith(
                          datePreset: DateRangePreset.all,
                        ),
                      ),
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
                      ref.refresh(shopNotificationsProvider.future),
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
                          children: [
                            for (final AdminNotification item in filtered)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                          ),
                                          if (item.isSentByShop)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primarySoft,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadii.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                'مرسل من محلك'.tr,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: AppFont.bold,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                            ),
                                          if (_sessionUnreadIds.contains(
                                            item.id,
                                          )) ...[
                                            const SizedBox(width: AppSpacing.xs),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        item.audienceLabel.tr,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(item.body),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
      bottom: approved
          ? AppButton(
              label: 'إرسال إشعار للعملاء'.tr,
              isLoading: busy,
              onPressed: () => _send(context, ref),
            )
          : null,
    );
  }
}

class _ShopSendNotificationSheet extends StatefulWidget {
  const _ShopSendNotificationSheet();

  @override
  State<_ShopSendNotificationSheet> createState() =>
      _ShopSendNotificationSheetState();
}

class _ShopSendNotificationSheetState
    extends State<_ShopSendNotificationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _scope = 'shop_customers';

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetScaffold(
      title: 'إرسال إشعار للعملاء'.tr,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _titleController,
              label: 'العنوان'.tr,
              validator: (value) =>
                  Validators.required(value, field: 'العنوان'.tr),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _bodyController,
              label: 'المحتوى'.tr,
              maxLines: 4,
              validator: (value) =>
                  Validators.required(value, field: 'المحتوى'.tr),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'الجمهور'.tr,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in [
                  ('shop_customers', 'عملاء المحل'.tr),
                  ('all_customers', 'جميع العملاء'.tr),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _scope == option.$1,
                    onSelected: AppHaptics.change(
                      (_) => setState(() => _scope = option.$1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _scope == 'shop_customers'
                  ? 'سيصل الإشعار للعملاء الذين طلبوا من محلك سابقاً'.tr
                  : 'سيصل الإشعار كعرض عام لجميع عملاء التطبيق'.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'إرسال'.tr,
              onPressed: () {
                if (_formKey.currentState?.validate() != true) return;
                Navigator.of(context).pop((
                  title: _titleController.text,
                  body: _bodyController.text,
                  scope: _scope,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
