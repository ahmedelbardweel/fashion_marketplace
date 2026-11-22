import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_design.dart';
import '../utils/app_haptics.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/app_card.dart';
import 'push_notification_provider.dart';
import 'push_notification_service.dart';

/// Shared notification permission & toggle row used across Customer, Shop,
/// and Admin profile/settings screens.
class PushNotificationSettingsRow extends ConsumerWidget {
  const PushNotificationSettingsRow({super.key});

  Future<void> _onEnablePressed(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(pushNotificationControllerProvider.notifier)
        .requestPermissionAndEnable();
    if (!context.mounted) return;
    if (result.isGranted) {
      showAppSnackBar(context, 'تم تفعيل الإشعارات بنجاح'.tr);
    } else {
      showAppSnackBar(
        context,
        'يرجى السماح بالإشعارات من إعدادات الجهاز لتصلك التنبيهات'.tr,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushState = ref.watch(pushNotificationControllerProvider);
    final granted = pushState.permissionStatus.isGranted;
    final active = pushState.isEffectivelyActive;

    final String subtitle;
    if (active && pushState.fcmReady && pushState.hasToken) {
      subtitle = 'FCM متصل — تصلك الإشعارات حتى عند إغلاق التطبيق'.tr;
    } else if (active) {
      subtitle = 'مفعّلة — بانتظار ربط Firebase (FCM) للإشعارات خارج التطبيق'.tr;
    } else if (granted && !pushState.notificationsEnabled) {
      subtitle = 'متوقفة مؤقتاً من التطبيق'.tr;
    } else if (pushState.permissionStatus == PushPermissionStatus.denied ||
        pushState.permissionStatus == PushPermissionStatus.permanentlyDenied) {
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
              } else {
                ref
                    .read(pushNotificationControllerProvider.notifier)
                    .setNotificationsEnabled(!pushState.notificationsEnabled);
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
                'تفعيل'.tr,
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
