import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_shell.dart';

import '../../../../core/widgets/app_filter_bar.dart';

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
            final filtered = filterNotifications(notifications, _filter);

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
                    for (final preset in DateRangePreset.values)
                      AppQuickFilterOption(
                        id: 'notif_${preset.name}',
                        label: preset.labelAr,
                        selected: _filter.datePreset == preset,
                        onTap: () => setState(
                          () => _filter = _filter.copyWith(datePreset: preset),
                        ),
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
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final notif = filtered[index];
                            final isUnreadHighlight =
                                _sessionUnreadIds.contains(notif.id);
                            final dateStr = DateFormat(
                              'yyyy/MM/dd – hh:mm a',
                            ).format(notif.createdAt);

                            return AppCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: NotificationsDesign.iconBoxSize,
                                    height: NotificationsDesign.iconBoxSize,
                                    decoration: BoxDecoration(
                                      color:
                                          NotificationsDesign.iconBackground,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      AppIcons.bellActive,
                                      color: NotificationsDesign.icon,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: AppFont.bold,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                            ),
                                            if (isUnreadHighlight) ...[
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
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
                                        const SizedBox(height: 4),
                                        Text(
                                          notif.body,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                            if (notif.isSentByShop) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primarySoft,
                                                  borderRadius:
                                                      BorderRadius.circular(
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
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
          error: (err, _) => AppEmpty(
            icon: AppIcons.error,
            message: 'تعذر تحميل الإشعارات: $err'.tr,
          ),
        ),
      ),
    );
  }
}
