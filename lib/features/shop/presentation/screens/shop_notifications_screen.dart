import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../admin/domain/models/catalog_models.dart';
import '../providers/shop_catalog_providers.dart';
import '../widgets/shop_shell.dart';

class ShopNotificationsScreen extends ConsumerWidget {
  const ShopNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(shopNotificationsProvider);

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
            return ListView(
              padding: AppSpacing.page,
              children: [AppCard(child: Text('لا توجد إشعارات حالياً'.tr))],
            );
          }
          return ListView(
            padding: AppSpacing.page,
            children: items
                .map(
                  (AdminNotification item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge,
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
          );
        },
      ),
    );
  }
}
