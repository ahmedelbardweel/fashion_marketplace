import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../../../../core/filtering/filter_models.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_filter_bar.dart';
import '../providers/shop_catalog_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(shopNotificationsProvider);
    final readIds = ref.watch(readNotificationIdsProvider);

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
                    id: 'shop_notif_aud_global',
                    label: 'الكل (العملاء والمتاجر)',
                    selected: _filter.audience == 'all_users',
                    onTap: () => setState(() {
                      final same = _filter.audience == 'all_users';
                      _filter = same
                          ? _filter.copyWith(clearAudience: true)
                          : _filter.copyWith(audience: 'all_users');
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
                          children: filtered
                            .map(
                            (AdminNotification item) => Padding(
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
                                    Text(item.audienceLabel),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
