import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/domain/models/catalog_models.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../router/routes.dart';
import '../theme/app_design.dart';
import '../utils/app_haptics.dart';
import '../widgets/app_card.dart';
import 'notification_models.dart';
import 'read_notifications_provider.dart';

/// Navigates safely to a notification's deep-link route if valid for [role],
/// marking it as read immediately.
bool navigateToNotificationTarget({
  required BuildContext context,
  required WidgetRef ref,
  required AdminNotification notification,
  required UserRole role,
}) {
  ref.read(readNotificationIdsProvider.notifier).markRead(notification.id);

  final rawRoute = notification.route?.trim() ?? '';
  if (rawRoute.isEmpty) return false;

  final rolePrefix = switch (role) {
    UserRole.admin => AppRoutes.adminRoot,
    UserRole.shop => AppRoutes.shopRoot,
    UserRole.customer => AppRoutes.customerRoot,
  };
  if (!rawRoute.startsWith(rolePrefix)) return false;

  final router = GoRouter.maybeOf(context);
  if (router == null) return false;
  router.push(rawRoute);
  return true;
}

/// Groups a sorted list of notifications by date section (Today, Yesterday,
/// This Week, Earlier) preserving their existing sort order.
List<({String? header, AdminNotification? item})> buildNotificationSections(
  List<AdminNotification> items, {
  DateTime? now,
}) {
  final out = <({String? header, AdminNotification? item})>[];
  String? lastHeader;
  for (final item in items) {
    final section = notificationDateSectionTitle(item.createdAt, now: now);
    if (section != lastHeader) {
      lastHeader = section;
      out.add((header: section, item: null));
    }
    out.add((header: null, item: item));
  }
  return out;
}

class NotificationSectionHeader extends StatelessWidget {
  const NotificationSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 2),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFont.bold,
              color: AppColors.textMuted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Divider(
              height: 1,
              color: AppColors.divider.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Professional, interactive notification card with category icon/color,
/// optional rich image thumbnail, unread accent, relative time, badges,
/// and tap-to-open deep linking.
class NotificationItemCard extends StatelessWidget {
  const NotificationItemCard({
    super.key,
    required this.notification,
    required this.isUnread,
    this.onTap,
    this.extraBadges = const [],
  });

  final AdminNotification notification;
  final bool isUnread;
  final VoidCallback? onTap;
  final List<Widget> extraBadges;

  @override
  Widget build(BuildContext context) {
    final category = notification.category;
    final accent = category.accentColor;
    final relativeTime = formatNotificationRelativeTime(notification.createdAt);
    final hasLink = notification.hasDeepLink && onTap != null;

    return AppCard(
      onTap: onTap == null ? null : AppHaptics.action(onTap!),
      backgroundColor: isUnread
          ? AppColors.primary.withValues(alpha: AppColors.isDark ? 0.08 : 0.04)
          : null,
      borderColor: isUnread
          ? AppColors.primary.withValues(alpha: 0.28)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationLeading(
            category: category,
            imageUrl: notification.imageUrl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isUnread
                              ? AppFont.bold
                              : AppFont.semiBold,
                          color: AppColors.text,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (isUnread)
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasLink) ...[
                      const SizedBox(width: 4),
                      Icon(
                        AppIcons.forward,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ],
                ),
                if (notification.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.48,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        category.shortLabel.tr,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: AppFont.bold,
                          color: accent,
                        ),
                      ),
                    ),
                    ...extraBadges,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11.5,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          relativeTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationLeading extends StatelessWidget {
  const _NotificationLeading({
    required this.category,
    this.imageUrl,
  });

  final NotificationCategory category;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: NotificationsDesign.iconBoxSize,
              height: NotificationsDesign.iconBoxSize,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _iconCircle(),
            ),
          ),
          Positioned(
            bottom: -3,
            right: -3,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: category.accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Icon(category.icon, size: 10, color: Colors.white),
            ),
          ),
        ],
      );
    }
    return _iconCircle();
  }

  Widget _iconCircle() {
    final accent = category.accentColor;
    return Container(
      width: NotificationsDesign.iconBoxSize,
      height: NotificationsDesign.iconBoxSize,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(category.icon, color: accent, size: 20),
    );
  }
}

/// Compact "Mark all as read" bar shown whenever there are unread notifications.
class MarkAllReadActionChip extends StatelessWidget {
  const MarkAllReadActionChip({
    super.key,
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '$unreadCount ${'غير مقروء'.tr}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: AppFont.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: AppHaptics.action(onMarkAllRead),
            icon: const Icon(Icons.done_all_rounded, size: 16),
            label: Text(
              'تحديد الكل كمقروء'.tr,
              style: const TextStyle(fontSize: 12, fontWeight: AppFont.bold),
            ),
          ),
        ],
      ),
    );
  }
}
