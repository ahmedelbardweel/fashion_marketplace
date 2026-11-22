import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/receipt_image_viewer.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../shop/domain/models/shop.dart';
import '../../domain/models/catalog_models.dart';
import '../providers/admin_providers.dart';

BadgeTone adminShopStatusTone(ShopStatus status) {
  switch (status) {
    case ShopStatus.approved:
      return BadgeTone.success;
    case ShopStatus.pending:
      return BadgeTone.warning;
    case ShopStatus.rejected:
    case ShopStatus.suspended:
      return BadgeTone.error;
    case ShopStatus.draft:
      return BadgeTone.neutral;
  }
}

BadgeTone adminOrderStatusTone(String status) {
  switch (status) {
    case 'delivered':
      return BadgeTone.success;
    case 'cancelled':
      return BadgeTone.error;
    case 'shipped':
    case 'confirmed':
      return BadgeTone.primary;
    case 'processing':
    case 'pending':
    default:
      return BadgeTone.warning;
  }
}

BadgeTone adminProductStatusTone(String status) {
  switch (status) {
    case 'published':
      return BadgeTone.success;
    case 'hidden':
      return BadgeTone.warning;
    case 'deleted':
      return BadgeTone.error;
    default:
      return BadgeTone.neutral;
  }
}

/// Customer/Shop-style greeting header for the Admin AppBar.
class AdminGreetingHeader extends StatelessWidget {
  const AdminGreetingHeader({super.key, required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final fullName = user?.fullName?.trim() ?? '';
    final email = user?.email.trim() ?? '';
    final greetingName = fullName.isNotEmpty
        ? fullName
        : (email.contains('@') ? email.split('@').first : 'الإدارة'.tr);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${'مرحباً'.tr}${AppLang.isEn ? ',' : '،'} $greetingName 👋',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: AppBarDesign.titleWeight,
            color: AppBarDesign.titleColor,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (email.isNotEmpty) ...[
              Flexible(
                child: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: AppFont.medium,
                    color: AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '•',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
              ),
            ],
            Text(
              'إدارة المنصة'.tr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFont.bold,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Clean shadow-free KPI card matching ShopKpiCard.
class AdminKpiCard extends StatelessWidget {
  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: AppFont.extraBold,
              color: AppColors.text,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(CardDesign.radius),
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(CardDesign.radius),
        child: content,
      ),
    );
  }
}

/// Clean shadow-free notice banner matching ShopNoticeBanner.
class AdminNoticeBanner extends StatelessWidget {
  const AdminNoticeBanner({
    super.key,
    required this.title,
    required this.message,
    this.tone = BadgeTone.primary,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final BadgeTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      BadgeTone.success => AppColors.successSoft,
      BadgeTone.warning => AppColors.warningSoft,
      BadgeTone.error => AppColors.errorSoft,
      BadgeTone.primary => AppColors.primarySoft,
      BadgeTone.neutral => AppColors.surfaceAlt,
    };
    final fg = switch (tone) {
      BadgeTone.success => AppColors.success,
      BadgeTone.warning => AppColors.warning,
      BadgeTone.error => AppColors.error,
      BadgeTone.primary => AppColors.primaryDark,
      BadgeTone.neutral => AppColors.text,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(CardDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.tr,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: AppFont.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.tr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.text,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: actionLabel!.tr,
              variant: AppButtonVariant.secondary,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Clean centered, button-free empty state matching ShopEmptyState.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.tr,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: AppFont.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message.tr,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Vertically centered pull-to-refresh empty view matching ShopCenteredEmptyView.
class AdminCenteredEmptyView extends StatelessWidget {
  const AdminCenteredEmptyView({
    super.key,
    required this.title,
    required this.message,
    required this.onRefresh,
  });

  final String title;
  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.page,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - AppSpacing.page.vertical)
                  .clamp(0.0, double.infinity),
            ),
            child: Center(
              child: AdminEmptyState(title: title, message: message),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings/Profile menu row matching ShopProfileMenuRow & Customer Profile.
class AdminProfileMenuRow extends StatelessWidget {
  const AdminProfileMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingBadge,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingBadge;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.text;
    final iconBg = isDestructive
        ? AppColors.errorSoft
        : ProfileDesign.menuIconBackground;
    final iconColor = isDestructive ? AppColors.error : ProfileDesign.menuIcon;

    return ListTile(
      onTap: onTap == null ? null : AppHaptics.action(onTap),
      leading: Container(
        width: ProfileDesign.menuIconBoxSize,
        height: ProfileDesign.menuIconBoxSize,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        AppLang.tr(title),
        style: TextStyle(
          fontSize: 14,
          fontWeight: AppFont.semiBold,
          color: color,
        ),
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(
              AppLang.tr(subtitle!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingBadge != null && trailingBadge!.isNotEmpty) ...[
            AppStatusBadge(label: trailingBadge!, tone: BadgeTone.primary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Icon(
            AppIcons.forward,
            color: isDestructive ? AppColors.error : ProfileDesign.menuChevron,
          ),
        ],
      ),
    );
  }
}

/// Preference choice tile matching ShopPreferenceTile.
class AdminPreferenceTile extends StatelessWidget {
  const AdminPreferenceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primaryDark : AppColors.icon,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.tr,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  AppIcons.checkCircleFilled,
                  size: 20,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shadow-free order card for Admin Orders & Admin Dashboard Today's Orders.
class AdminOrderCard extends StatelessWidget {
  const AdminOrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  final AdminOrder order;
  final VoidCallback? onTap;

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    final d = l.day.toString().padLeft(2, '0');
    final m = l.month.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '$d/$m/${l.year} • $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final shortId = order.id.length >= 8
        ? order.id.substring(0, 8).toUpperCase()
        : order.id.toUpperCase();
    final customerLabel = (order.customerName?.trim().isNotEmpty ?? false)
        ? order.customerName!.trim()
        : (order.customerEmail ?? '-');
    final region = (order.shippingCity?.trim().isNotEmpty ?? false)
        ? order.shippingCity!.trim()
        : (order.shopCity?.trim() ?? '');

    return Material(
      color: SellerDesign.statCardBackground,
      borderRadius: BorderRadius.circular(CardDesign.radius),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(CardDesign.radius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CardDesign.radius),
            border: Border.all(color: SellerDesign.statCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.shopName ?? 'متجر'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppStatusBadge(
                    label: order.statusLabel,
                    tone: adminOrderStatusTone(order.status),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#$shortId · $customerLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppFormat.price(order.total),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.extraBold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (region.isNotEmpty) ...[
                    Expanded(
                      child: Text(
                        region,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: AppFont.semiBold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    _formatDate(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (order.paymentStatus != 'not_required' ||
                  order.isCustomerPickup) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 4,
                  children: [
                    AppStatusBadge(
                      label: order.deliveryModeLabel,
                      tone: order.isCustomerPickup
                          ? BadgeTone.neutral
                          : BadgeTone.primary,
                    ),
                    if (order.paymentStatus != 'not_required')
                      AppStatusBadge(
                        label: order.paymentStatusLabel,
                        tone: order.paymentStatus == 'verified'
                            ? BadgeTone.success
                            : order.paymentStatus == 'issue_reported'
                            ? BadgeTone.error
                            : BadgeTone.warning,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared Admin Order Details + Status Override BottomSheet.
Future<void> showAdminOrderStatusSheet(
  BuildContext context,
  WidgetRef ref,
  AdminOrder order,
) async {
  const statuses = <(String, String)>[
    ('pending', 'قيد الانتظار'),
    ('confirmed', 'مؤكد'),
    ('processing', 'قيد التجهيز'),
    ('shipped', 'تم الشحن'),
    ('delivered', 'تم التسليم'),
    ('cancelled', 'ملغي'),
  ];

  var selected = order.status;
  var saving = false;
  final shortId = order.id.length >= 8
      ? order.id.substring(0, 8).toUpperCase()
      : order.id.toUpperCase();

  await AppBottomSheet.show<void>(
    context: context,
    isScrollControlled: true,
    child: StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        return AppBottomSheetScaffold(
          title: '${'إدارة الطلب'.tr} #$shortId',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OrderMetaRow(
                      label: 'المتجر'.tr,
                      value: order.shopName ?? '-',
                    ),
                    const SizedBox(height: 6),
                    _OrderMetaRow(
                      label: 'العميل'.tr,
                      value: (order.customerName?.trim().isNotEmpty ?? false)
                          ? order.customerName!.trim()
                          : (order.customerEmail ?? '-'),
                    ),
                    if (order.customerPhone?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      _OrderMetaRow(
                        label: 'الهاتف'.tr,
                        value: order.customerPhone!.trim(),
                      ),
                    ],
                    if (order.shippingCity?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      _OrderMetaRow(
                        label: 'المنطقة'.tr,
                        value: order.shippingCity!.trim(),
                      ),
                    ],
                    if (order.shippingAddress?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      _OrderMetaRow(
                        label: 'العنوان'.tr,
                        value: order.shippingAddress!.trim(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _OrderMetaRow(
                      label: 'طريقة التوصيل'.tr,
                      value: order.deliveryModeLabel.tr,
                    ),
                    if (order.deliveryFee > 0) ...[
                      const SizedBox(height: 6),
                      _OrderMetaRow(
                        label: 'رسوم التوصيل'.tr,
                        value: AppFormat.price(order.deliveryFee),
                      ),
                    ],
                    if (order.paymentMethodName?.trim().isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 6),
                      _OrderMetaRow(
                        label: 'وسيلة الدفع'.tr,
                        value: order.paymentMethodName!.trim(),
                      ),
                    ],
                    if (order.paymentStatus != 'not_required') ...[
                      const SizedBox(height: 6),
                      _OrderMetaRow(
                        label: 'حالة الحوالة'.tr,
                        value: order.paymentStatusLabel.tr,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _OrderMetaRow(
                      label: 'الإجمالي'.tr,
                      value: AppFormat.price(order.total),
                      bold: true,
                    ),
                  ],
                ),
              ),
              if (order.hasReceipt) ...[
                const SizedBox(height: AppSpacing.md),
                ReceiptThumbnailCard(
                  imageUrl: order.paymentReceiptUrl!,
                  subtitle: '${'إشعار حوالة طلب'.tr} #$shortId',
                  height: 150,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'تحديث حالة الطلب'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: statuses.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.$2.tr),
                    selected: selected == entry.$1,
                    onSelected: saving
                        ? null
                        : (_) => setSheetState(() => selected = entry.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'حفظ حالة الطلب'.tr,
                isLoading: saving,
                onPressed: selected == order.status
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        final actions = ref.read(adminActionProvider.notifier);
                        final ok = await actions.updateOrderStatus(
                          orderId: order.id,
                          status: selected,
                        );
                        if (!context.mounted) return;
                        if (!ok) {
                          if (sheetCtx.mounted) {
                            setSheetState(() => saving = false);
                          }
                          final err = ref.read(adminActionProvider).error;
                          showAppSnackBar(
                            context,
                            err == null
                                ? 'تعذر تحديث الطلب'.tr
                                : actions.errorMessage(err),
                            isError: true,
                          );
                          return;
                        }
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        showAppSnackBar(context, 'تم تحديث حالة الطلب'.tr);
                      },
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'إغلاق'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: saving ? null : () => Navigator.of(sheetCtx).pop(),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _OrderMetaRow extends StatelessWidget {
  const _OrderMetaRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? AppFont.extraBold : AppFont.semiBold,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
