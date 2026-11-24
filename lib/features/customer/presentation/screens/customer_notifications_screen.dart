import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_guard.dart';
import '../../../../core/notifications/notification_list_components.dart';
import '../../../../core/notifications/notification_models.dart';
import '../../../../core/notifications/push_notification_settings_card.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../auth/domain/models/user_role.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

class CustomerNotificationsScreen extends ConsumerStatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  ConsumerState<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends ConsumerState<CustomerNotificationsScreen> {
  NotificationFilterState _filter = NotificationFilterState.empty;
  final Set<String> _sessionUnreadIds = {};

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(customerNotificationsProvider);
    final readIds = ref.watch(readNotificationIdsProvider);

    return CustomerScaffold(
      title: 'الإشعارات'.tr,
      actions: [
        IconButton(
          tooltip: 'تخصيص أنواع الإشعارات'.tr,
          icon: Icon(Icons.tune_rounded, color: AppColors.text, size: 21),
          onPressed: AppHaptics.action(
            () => showNotificationPreferencesSheet(context, ref),
          ),
        ),
      ],
      body: AppRefreshIndicator(
        onRefresh: () => ref.refresh(customerNotificationsProvider.future),
        child: notificationsAsync.skeletonWhen(
          placeholder: LoadingFixtures.notifications,
          data: (notifications) {
            if (notifications.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: AppEmpty(
                      icon: AppIcons.bell,
                      title: 'لا توجد إشعارات جديدة'.tr,
                      message: 'ستصلك هنا العروض الحصرية وتحديثات طلباتك'.tr,
                    ),
                  ),
                ],
              );
            }

            markVisibleNotificationsRead(
              ref: ref,
              notifications: notifications,
              readIds: readIds,
              sessionUnreadIds: _sessionUnreadIds,
              isMounted: () => mounted,
            );
            final filtered = filterNotifications(
              notifications,
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
                      id: 'cust_cat_all',
                      label: 'الكل',
                      selected: _filter.category == null,
                      onTap: () => setState(
                        () => _filter = _filter.copyWith(clearCategory: true),
                      ),
                    ),
                    for (final cat in NotificationCategory.values)
                      AppQuickFilterOption(
                        id: 'cust_cat_${cat.key}',
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
                          id: 'notif_${preset.name}',
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
                  totalCount: notifications.length,
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
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
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
                            final notif = entry.item!;
                            final isUnreadHighlight =
                                _sessionUnreadIds.contains(notif.id);

                            return NotificationItemCard(
                              notification: notif,
                              isUnread: isUnreadHighlight,
                              onTap: notif.hasDeepLink
                                  ? () => navigateToNotificationTarget(
                                      context: context,
                                      ref: ref,
                                      notification: notif,
                                      role: UserRole.customer,
                                    )
                                  : null,
                              extraBadges: [
                                if (notif.isSentByShop)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: Text(
                                      'من المتجر'.tr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: AppFont.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: AppEmpty(
                  icon: AppIcons.error,
                  title: 'تعذر تحميل الإشعارات'.tr,
                  message: AppErrorMapper.message(
                    error,
                    fallback: 'تعذر تحميل الإشعارات حالياً. حاول مرة أخرى.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
