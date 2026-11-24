import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/notifications/notification_list_components.dart';
import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/push_notification_settings_card.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
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
    final result =
        await AppBottomSheet.show<({String title, String body, String scope})>(
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
      showNotifications: false,
      actions: [
        IconButton(
          tooltip: 'تخصيص أنواع الإشعارات'.tr,
          icon: Icon(Icons.tune_rounded, color: AppColors.text, size: 21),
          onPressed: AppHaptics.action(
            () => showNotificationPreferencesSheet(context, ref),
          ),
        ),
      ],
      body: notifications.skeletonWhen(
        placeholder: LoadingFixtures.notifications,
        error: (error, _) => ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل الإشعارات'.tr,
              message: ref.read(shopCatalogRepositoryProvider).mapError(error),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة'.tr,
              onAction: () => ref.invalidate(shopNotificationsProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ShopCenteredEmptyView(
              onRefresh: () => ref.refresh(shopNotificationsProvider.future),
              title: 'لا توجد إشعارات حالياً',
              message: approved
                  ? 'ستصل هنا تنبيهات الإدارة والطلبات، ويمكنك إرسال عروض لعملاء متجرك.'
                  : 'ستظهر هنا تنبيهات المنصة وحالة طلب انضمام متجرك.',
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
                    id: 'shop_notif_aud_all',
                    label: 'الكل',
                    selected:
                        _filter.audience == null && _filter.category == null,
                    onTap: () => setState(
                      () => _filter = _filter.copyWith(
                        clearAudience: true,
                        clearCategory: true,
                      ),
                    ),
                  ),
                  for (final cat in NotificationCategory.values)
                    AppQuickFilterOption(
                      id: 'shop_notif_cat_${cat.key}',
                      label: cat.shortLabel,
                      selected: _filter.category == cat,
                      onTap: () => setState(() {
                        final same = _filter.category == cat;
                        _filter = same
                            ? _filter.copyWith(clearCategory: true)
                            : _filter.copyWith(category: cat);
                      }),
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
                  if (_filter.category != null)
                    AppActiveFilterTag(
                      label: _filter.category!.shortLabel.tr,
                      onRemove: () => setState(
                        () => _filter = _filter.copyWith(clearCategory: true),
                      ),
                    ),
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
                            final AdminNotification item = entry.item!;
                            final isUnread = _sessionUnreadIds.contains(
                              item.id,
                            );
                            return NotificationItemCard(
                              notification: item,
                              isUnread: isUnread,
                              onTap: item.hasDeepLink
                                  ? () => navigateToNotificationTarget(
                                      context: context,
                                      ref: ref,
                                      notification: item,
                                      role: UserRole.shop,
                                    )
                                  : null,
                              extraBadges: [
                                if (item.isSentByShop)
                                  const AppStatusBadge(
                                    label: 'مرسل من محلك',
                                    tone: BadgeTone.primary,
                                  ),
                                AppStatusBadge(
                                  label: item.audienceLabel,
                                  tone: BadgeTone.neutral,
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
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
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
