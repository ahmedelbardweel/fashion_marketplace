import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_design.dart';
import '../utils/app_haptics.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_card.dart';
import 'notification_models.dart';
import 'push_notification_provider.dart';
import 'push_notification_service.dart';

/// Opens a sleek bottom sheet letting the user customize which notification
/// categories they want to receive (synced to Supabase).
Future<void> showNotificationPreferencesSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await AppBottomSheet.show<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    child: const _NotificationPreferencesSheet(),
  );
}

class _NotificationPreferencesSheet extends ConsumerWidget {
  const _NotificationPreferencesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushState = ref.watch(pushNotificationControllerProvider);
    final prefs = pushState.preferences;
    final notifier = ref.read(pushNotificationControllerProvider.notifier);

    return AppBottomSheetScaffold(
      title: 'تخصيص أنواع الإشعارات'.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اختر أنواع التنبيهات التي تود استلامها على جهازك في أي وقت.'.tr,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CategoryPrefTile(
            category: NotificationCategory.orders,
            value: prefs.ordersEnabled,
            onChanged: (v) =>
                notifier.updatePreferences(prefs.copyWith(ordersEnabled: v)),
          ),
          const SizedBox(height: AppSpacing.xs),
          _CategoryPrefTile(
            category: NotificationCategory.offers,
            value: prefs.offersEnabled,
            onChanged: (v) =>
                notifier.updatePreferences(prefs.copyWith(offersEnabled: v)),
          ),
          const SizedBox(height: AppSpacing.xs),
          _CategoryPrefTile(
            category: NotificationCategory.catalog,
            value: prefs.catalogEnabled,
            onChanged: (v) =>
                notifier.updatePreferences(prefs.copyWith(catalogEnabled: v)),
          ),
          const SizedBox(height: AppSpacing.xs),
          _CategoryPrefTile(
            category: NotificationCategory.system,
            value: prefs.systemEnabled,
            onChanged: (v) =>
                notifier.updatePreferences(prefs.copyWith(systemEnabled: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _CategoryPrefTile extends StatelessWidget {
  const _CategoryPrefTile({
    required this.category,
    required this.value,
    required this.onChanged,
  });

  final NotificationCategory category;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = category.accentColor;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: value
              ? accent.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: value ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            category.icon,
            size: 20,
            color: value ? accent : AppColors.textMuted,
          ),
        ),
        title: Text(
          category.channelName.tr,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: AppFont.bold,
            color: AppColors.text,
          ),
        ),
        subtitle: Text(
          category.channelDescription.tr,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: (next) {
            AppHaptics.selection();
            onChanged(next);
          },
        ),
        onTap: () {
          AppHaptics.selection();
          onChanged(!value);
        },
      ),
    );
  }
}

/// Shared notification permission, master toggle, and category preferences row
/// used across Customer, Shop, and Admin profile/settings screens.
class PushNotificationSettingsRow extends ConsumerWidget {
  const PushNotificationSettingsRow({super.key});

  Future<void> _onEnablePressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(pushNotificationControllerProvider.notifier);
    final currentStatus =
        ref.read(pushNotificationControllerProvider).permissionStatus;

    if (currentStatus == PushPermissionStatus.permanentlyDenied) {
      await notifier.openDeviceNotificationSettings();
      return;
    }

    final result = await notifier.requestPermissionAndEnable();
    if (!context.mounted) return;
    if (result.isGranted) {
      showAppSnackBar(context, 'تم تفعيل الإشعارات بنجاح'.tr);
    } else {
      showAppSnackBar(
        context,
        'يرجى السماح بالإشعارات من إعدادات الجهاز لتصلك التنبيهات'.tr,
        isError: true,
        actionLabel: 'الإعدادات',
        onAction: () => notifier.openDeviceNotificationSettings(),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushState = ref.watch(pushNotificationControllerProvider);
    final granted = pushState.permissionStatus.isGranted;
    final active = pushState.isEffectivelyActive;
    final permanentlyDenied =
        pushState.permissionStatus == PushPermissionStatus.permanentlyDenied;

    final String subtitle;
    if (active && pushState.fcmReady && pushState.hasToken) {
      subtitle = 'مفعّلة — اضغط لتخصيص أنواع الإشعارات'.tr;
    } else if (active) {
      subtitle = 'مفعّلة — اضغط لتخصيص أنواع الإشعارات'.tr;
    } else if (granted && !pushState.notificationsEnabled) {
      subtitle = 'متوقفة مؤقتاً من التطبيق'.tr;
    } else if (permanentlyDenied) {
      subtitle = 'مرفوضة من النظام — اضغط لفتح إعدادات الجهاز'.tr;
    } else if (pushState.permissionStatus == PushPermissionStatus.denied) {
      subtitle = 'غير مسموحة — اضغط لتفعيل صلاحية الإشعارات'.tr;
    } else {
      subtitle = 'فعّل الإشعارات لاستلام العروض وتحديثات الطلبات'.tr;
    }

    return ListTile(
      onTap: pushState.isRequesting
          ? null
          : AppHaptics.action(() {
              if (!granted) {
                _onEnablePressed(context, ref);
              } else if (active) {
                showNotificationPreferencesSheet(context, ref);
              } else {
                ref
                    .read(pushNotificationControllerProvider.notifier)
                    .setNotificationsEnabled(true);
              }
            }),
      leading: Container(
        width: ProfileDesign.menuIconBoxSize,
        height: ProfileDesign.menuIconBoxSize,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primarySoft
              : ProfileDesign.menuIconBackground,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(
          active ? AppIcons.bellActive : AppIcons.bell,
          size: 20,
          color: active ? AppColors.primaryDark : ProfileDesign.menuIcon,
        ),
      ),
      title: Text(
        'إشعارات الهاتف'.tr,
        style: TextStyle(
          fontSize: 14,
          fontWeight: AppFont.semiBold,
          color: AppColors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: pushState.isRequesting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : granted
          ? Switch.adaptive(
              value: pushState.notificationsEnabled,
              onChanged: (val) => ref
                  .read(pushNotificationControllerProvider.notifier)
                  .setNotificationsEnabled(val),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                (permanentlyDenied ? 'الإعدادات' : 'تفعيل').tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
    );
  }
}

class PushNotificationSettingsCard extends ConsumerStatefulWidget {
  const PushNotificationSettingsCard({super.key});

  @override
  ConsumerState<PushNotificationSettingsCard> createState() =>
      _PushNotificationSettingsCardState();
}

class _PushNotificationSettingsCardState
    extends ConsumerState<PushNotificationSettingsCard> {
  bool _sendingTest = false;

  Future<void> _triggerClosedAppTest() async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    try {
      final result = await ref
          .read(pushNotificationControllerProvider.notifier)
          .sendTestClosedAppNotification(delaySeconds: 5);
      if (!mounted) return;
      showAppSnackBar(context, result.message.tr, isError: !result.ok);
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pushState = ref.watch(pushNotificationControllerProvider);
    final active = pushState.isEffectivelyActive;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PushNotificationSettingsRow(),
          if (active) ...[
            Divider(height: 1, color: AppColors.divider),
            InkWell(
              onTap: AppHaptics.action(
                () => showNotificationPreferencesSheet(context, ref),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'تخصيص أنواع الإشعارات'.tr,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: AppFont.semiBold,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Icon(
                      AppIcons.forward,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.divider),
            InkWell(
              onTap: _sendingTest
                  ? null
                  : AppHaptics.action(_triggerClosedAppTest),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadii.card),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.bellActive,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'تجربة إشعار عند إغلاق التطبيق (خلال 5 ثوانٍ)'.tr,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: AppFont.semiBold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (_sendingTest)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Icon(
                        AppIcons.forward,
                        size: 15,
                        color: AppColors.primary,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
