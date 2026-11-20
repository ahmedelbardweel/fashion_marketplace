import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/media_picker.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/models/shop.dart';
import '../../domain/models/shop_product.dart';
import '../providers/shop_catalog_providers.dart';

// =============================================================================
//  1) دوال مساعدة موحدة لحالات المتجر والطلبات والمنتجات والتنسيق
// =============================================================================

BadgeTone shopStatusTone(ShopStatus status) {
  return switch (status) {
    ShopStatus.approved => BadgeTone.success,
    ShopStatus.pending => BadgeTone.warning,
    ShopStatus.rejected || ShopStatus.suspended => BadgeTone.error,
    ShopStatus.draft => BadgeTone.neutral,
  };
}

BadgeTone orderStatusTone(String status) {
  return switch (status) {
    'delivered' => BadgeTone.success,
    'confirmed' || 'processing' || 'shipped' => BadgeTone.primary,
    'cancelled' => BadgeTone.error,
    _ => BadgeTone.warning,
  };
}

BadgeTone productStatusTone(String status) {
  return switch (status) {
    'published' => BadgeTone.success,
    'hidden' => BadgeTone.warning,
    'deleted' => BadgeTone.error,
    _ => BadgeTone.neutral,
  };
}

String shortOrderCode(String orderId) {
  final clean = orderId.replaceAll('-', '').toUpperCase();
  final slice = clean.length >= 8 ? clean.substring(0, 8) : clean;
  return '#$slice';
}

String formatShopDateTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y/$m/$d · $h:$min';
}

String? nextLogicalOrderStatus(String current) {
  return switch (current) {
    'pending' => 'confirmed',
    'confirmed' => 'processing',
    'processing' => 'shipped',
    'shipped' => 'delivered',
    _ => null,
  };
}

String orderActionLabel(String status) {
  return switch (status) {
    'confirmed' => 'تأكيد الطلب',
    'processing' => 'بدء التجهيز',
    'shipped' => 'تم الشحن',
    'delivered' => 'تأكيد التسليم',
    'cancelled' => 'إلغاء الطلب',
    _ => status,
  };
}

// =============================================================================
//  2) حالة فراغ نصية موحدة بدون أيقونات — SHOP EMPTY STATE
// =============================================================================

class ShopEmptyState extends StatelessWidget {
  const ShopEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLang.tr(title),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: AppFont.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLang.tr(message),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: AppLang.tr(actionLabel!),
              expand: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Vertically centered, pull-to-refreshable empty state for full-page shop views.
class ShopCenteredEmptyView extends StatelessWidget {
  const ShopCenteredEmptyView({
    super.key,
    required this.title,
    required this.message,
    required this.onRefresh,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final Future<void> Function() onRefresh;
  final String? actionLabel;
  final VoidCallback? onAction;

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
              minHeight: (constraints.maxHeight - AppSpacing.md * 2).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Center(
              child: ShopEmptyState(
                title: title,
                message: message,
                actionLabel: actionLabel,
                onAction: onAction,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  3) بطاقة هوية المتجر — SHOP IDENTITY HEADER
// =============================================================================

class ShopIdentityHeader extends StatelessWidget {
  const ShopIdentityHeader({
    super.key,
    required this.shop,
    this.trailing,
    this.showCover = true,
  });

  final Shop? shop;
  final Widget? trailing;
  final bool showCover;

  @override
  Widget build(BuildContext context) {
    final name = (shop?.name.trim().isNotEmpty ?? false)
        ? shop!.name
        : 'متجري'.tr;
    final status = shop?.visibleStatus ?? ShopStatus.draft;
    final city = shop?.city?.trim();
    final subtitle = (city != null && city.isNotEmpty)
        ? city
        : (shop?.ownerName?.trim().isNotEmpty ?? false)
        ? shop!.ownerName!
        : 'إدارة المتجر والطلبات'.tr;
    final hasCover = shop?.coverPath != null && shop!.coverPath!.isNotEmpty;
    final hasLogo = shop?.logoPath != null && shop!.logoPath!.isNotEmpty;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

    return Container(
      decoration: BoxDecoration(
        color: SellerDesign.statCardBackground,
        borderRadius: BorderRadius.circular(SellerDesign.statCardRadius),
        border: Border.all(color: SellerDesign.statCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCover && hasCover)
            SizedBox(
              height: SellerDesign.coverHeight,
              child: AppNetworkImage(
                shop!.coverPath!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: SellerDesign.coverHeight,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: SellerDesign.avatarSize,
                  height: SellerDesign.avatarSize,
                  decoration: BoxDecoration(
                    color: SellerDesign.statIconBackground,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: hasLogo
                      ? AppNetworkImage(
                          shop!.logoPath!,
                          fit: BoxFit.cover,
                          width: SellerDesign.avatarSize,
                          height: SellerDesign.avatarSize,
                          errorBuilder: (_, _, _) => Text(
                            initial,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: AppFont.extraBold,
                              color: SellerDesign.statIcon,
                            ),
                          ),
                        )
                      : Text(
                          initial,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: AppFont.extraBold,
                            color: SellerDesign.statIcon,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: AppFont.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppStatusBadge(
                        label: status.labelAr,
                        tone: shopStatusTone(status),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  4) بطاقة مؤشر الأداء — SHOP KPI CARD (بدون أيقونات)
// =============================================================================

class ShopKpiCard extends StatelessWidget {
  const ShopKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.tone = BadgeTone.primary,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final BadgeTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SellerDesign.statCardBackground,
      borderRadius: BorderRadius.circular(SellerDesign.statCardRadius),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(SellerDesign.statCardRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: SellerDesign.statCardBorder),
            borderRadius: BorderRadius.circular(SellerDesign.statCardRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLang.tr(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.text,
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        AppLang.tr(caption!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: AppFont.tiny,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: SellerDesign.statValueWeight,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  5) زر إجراء سريع — SHOP QUICK ACTION TILE (بدون أيقونات)
// =============================================================================

class ShopQuickActionTile extends StatelessWidget {
  const ShopQuickActionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.badgeCount = 0,
  });

  final String label;
  final VoidCallback? onTap;
  final bool highlighted;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? AppColors.primary
        : SellerDesign.statCardBackground;
    final fg = highlighted ? AppColors.onPrimary : AppColors.text;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: highlighted
                ? null
                : Border.all(color: SellerDesign.statCardBorder),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  AppLang.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: AppFont.bold,
                    color: fg,
                  ),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? AppColors.onPrimary.withValues(alpha: 0.22)
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: AppFont.bold,
                      color: highlighted
                          ? AppColors.onPrimary
                          : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  6) بانر تنبيه وحالة موحد — SHOP NOTICE BANNER (بدون أيقونات)
// =============================================================================

class ShopNoticeBanner extends StatelessWidget {
  const ShopNoticeBanner({
    super.key,
    required this.title,
    required this.message,
    this.tone = BadgeTone.warning,
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
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (AppColors.successSoft, AppColors.success),
      BadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
      BadgeTone.error => (AppColors.errorSoft, AppColors.error),
      BadgeTone.primary => (AppColors.primarySoft, AppColors.primaryDark),
      BadgeTone.neutral => (AppColors.surfaceAlt, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(CardDesign.radius),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLang.tr(title),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: AppFont.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLang.tr(message),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: AppHaptics.action(onAction),
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppLang.tr(actionLabel!),
                  style: const TextStyle(fontWeight: AppFont.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
//  7) بطاقة طلب موحدة — SHOP ORDER CARD (بدون أيقونات)
// =============================================================================

class ShopOrderCard extends StatelessWidget {
  const ShopOrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.actionHint,
  });

  final ShopOrder order;
  final VoidCallback? onTap;
  final String? actionHint;

  @override
  Widget build(BuildContext context) {
    final customer = (order.customerName?.trim().isNotEmpty ?? false)
        ? order.customerName!
        : (order.customerEmail?.trim().isNotEmpty ?? false)
        ? order.customerEmail!
        : 'عميل'.tr;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${'طلب'.tr} ${shortOrderCode(order.id)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: AppFont.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppStatusBadge(
                label: order.statusLabel,
                tone: orderStatusTone(order.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            customer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: AppFont.semiBold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatShopDateTime(order.createdAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                AppFormat.price(order.total),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: AppFont.extraBold,
                ),
              ),
              const Spacer(),
              if (onTap != null)
                Text(
                  AppLang.tr(actionHint ?? 'تحديث الحالة'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: AppFont.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared bottom sheet for updating a shop order's status (used in Dashboard & Orders).
Future<void> showShopOrderStatusSheet(
  BuildContext context,
  WidgetRef ref,
  ShopOrder order,
) async {
  final nextStep = nextLogicalOrderStatus(order.status);
  const allSteps = ['confirmed', 'processing', 'shipped', 'delivered'];
  final otherSteps = allSteps
      .where((s) => s != nextStep && s != order.status)
      .toList();
  final customer = (order.customerName?.trim().isNotEmpty ?? false)
      ? order.customerName!
      : (order.customerEmail?.trim().isNotEmpty ?? false)
      ? order.customerEmail!
      : 'عميل'.tr;

  final status = await AppBottomSheet.show<String>(
    context: context,
    child: AppBottomSheetScaffold(
      title: '${'طلب'.tr} ${shortOrderCode(order.id)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: AppFont.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppFormat.price(order.total)} · ${formatShopDateTime(order.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppStatusBadge(
                  label: order.statusLabel,
                  tone: orderStatusTone(order.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (nextStep != null) ...[
            Text(
              'الخطوة التالية المقترحة'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: orderActionLabel(nextStep).tr,
              onPressed: () => Navigator.of(context).pop(nextStep),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (otherSteps.isNotEmpty) ...[
            Text(
              'خيارات حالة أخرى'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...otherSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppButton(
                  label: orderActionLabel(step).tr,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(step),
                ),
              ),
            ),
          ],
          if (order.status != 'cancelled' && order.status != 'delivered') ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.errorSoft,
                foregroundColor: AppColors.error,
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
                minimumSize: const Size(double.infinity, ButtonDesign.height),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ButtonDesign.radius),
                ),
              ),
              onPressed: AppHaptics.action(
                () => Navigator.of(context).pop('cancelled'),
              ),
              child: Text('إلغاء الطلب'.tr),
            ),
          ],
        ],
      ),
    ),
  );

  if (status == null || !context.mounted) return;
  if (status == 'cancelled') {
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: 'تأكيد إلغاء الطلب'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'هل أنت متأكد من إلغاء الطلب ${shortOrderCode(order.id)}؟'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppPalette.white,
              ),
              onPressed: AppHaptics.action(
                () => Navigator.of(context).pop(true),
              ),
              child: Text('تأكيد الإلغاء'.tr),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'تراجع'.tr,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }

  final actions = ref.read(shopCatalogActionProvider.notifier);
  final ok = await actions.updateOrderStatus(orderId: order.id, status: status);
  if (!context.mounted) return;
  if (!ok) {
    final error = ref.read(shopCatalogActionProvider).error;
    showAppSnackBar(
      context,
      error == null ? 'تعذر التحديث'.tr : actions.errorMessage(error),
      isError: true,
    );
    return;
  }
  showAppSnackBar(context, 'تم تحديث حالة الطلب'.tr);
}

// =============================================================================
//  8) بطاقة منتج التاجر — SHOP PRODUCT MANAGE CARD + DELEGATE (بدون أيقونات)
// =============================================================================

class ShopProductManageGridDelegate extends SliverGridDelegate {
  const ShopProductManageGridDelegate({this.textScale = 1});

  final double textScale;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final count = width < 280
        ? 1
        : (width / ProductGridDesign.minCardWidth).floor().clamp(
            ProductGridDesign.minColumns,
            ProductGridDesign.maxColumns,
          );
    final cardWidth =
        (width - (count - 1) * ProductGridDesign.crossSpacing) / count;
    final imageHeight = cardWidth / ProductCardDesign.imageAspectRatio;
    final footerHeight = 76 + (textScale - 1) * 18;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      crossAxisSpacing: ProductGridDesign.crossSpacing,
      mainAxisSpacing: ProductGridDesign.mainSpacing,
      mainAxisExtent: imageHeight + footerHeight,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(ShopProductManageGridDelegate oldDelegate) =>
      textScale != oldDelegate.textScale;
}

class ShopProductManageCard extends StatelessWidget {
  const ShopProductManageCard({super.key, required this.product, this.onTap});

  final ShopProduct product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inStock = product.totalStock > 0;
    final isLowStock = inStock && product.totalStock <= 5;
    final stockColor = !inStock
        ? AppColors.error
        : isLowStock
        ? AppColors.warning
        : AppColors.success;
    final stockText = !inStock
        ? 'نفد المخزون'.tr
        : isLowStock
        ? '${'مخزون منخفض'.tr}: ${product.totalStock}'
        : '${product.totalStock} ${'قطعة'.tr}';
    final imageRadius = BorderRadius.circular(ProductCardDesign.imageRadius);

    return Material(
      color: ProductCardDesign.cardBackground,
      borderRadius: BorderRadius.circular(ProductCardDesign.cardRadius),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(ProductCardDesign.cardRadius),
        child: Container(
          padding: ProductCardDesign.cardPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ProductCardDesign.cardRadius),
            border: Border.all(
              color: ProductCardDesign.cardBorderColor,
              width: ProductCardDesign.cardBorderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ProductCardDesign.imageBackground,
                    borderRadius: imageRadius,
                    border: Border.all(
                      color: ProductCardDesign.imageBorderColor,
                      width: ProductCardDesign.imageBorderWidth,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: inStock
                            ? 1
                            : ProductCardDesign.outOfStockImageOpacity,
                        child:
                            product.coverImage == null ||
                                product.coverImage!.isEmpty
                            ? Center(
                                child: Text(
                                  'بدون صورة'.tr,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              )
                            : AppNetworkImage(
                                product.coverImage!,
                                fit: ProductCardDesign.imageFit,
                                alignment: Alignment.center,
                                contentPadding:
                                    ProductCardDesign.imageInnerPadding,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    'بدون صورة'.tr,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                      ),
                      PositionedDirectional(
                        top: ProductCardDesign.favoriteInset,
                        start: ProductCardDesign.favoriteInset,
                        child: AppStatusBadge(
                          label: product.statusLabel,
                          tone: productStatusTone(product.status),
                        ),
                      ),
                      if (product.has3dModel)
                        PositionedDirectional(
                          top: ProductCardDesign.favoriteInset,
                          end: ProductCardDesign.favoriteInset,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Text(
                              '3D',
                              style: TextStyle(
                                color: AppColors.onPrimary,
                                fontSize: 10,
                                fontWeight: AppFont.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ProductCardDesign.infoTopSpacing),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFont.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppFormat.price(product.price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ProductCardDesign.priceSize,
                  fontWeight: ProductCardDesign.priceWeight,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: stockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      stockText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.tiny,
                        fontWeight: AppFont.semiBold,
                        color: stockColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  9) حقول بيانات المتجر المشتركة — SHOP DETAILS FORM FIELDS (بدون أيقونات)
// =============================================================================

class ShopDetailsFormFields extends StatelessWidget {
  const ShopDetailsFormFields({
    super.key,
    required this.shopNameController,
    required this.descriptionController,
    required this.cityController,
    required this.addressController,
    required this.registerController,
    required this.ownerNameController,
    required this.phoneController,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController shopNameController;
  final TextEditingController descriptionController;
  final TextEditingController cityController;
  final TextEditingController addressController;
  final TextEditingController registerController;
  final TextEditingController ownerNameController;
  final TextEditingController phoneController;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'معلومات المتجر'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: AppFont.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: shopNameController,
                label: 'اسم المحل'.tr,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                validator: (v) => Validators.required(v, field: 'اسم المحل'.tr),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: descriptionController,
                label: 'وصف المحل'.tr,
                maxLines: 3,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                validator: (v) => Validators.required(v, field: 'وصف المحل'.tr),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: cityController,
                label: 'المدينة'.tr,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                validator: (v) => Validators.required(v, field: 'المدينة'.tr),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: addressController,
                label: 'العنوان'.tr,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                validator: (v) => Validators.required(v, field: 'العنوان'.tr),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: registerController,
                label: 'السجل التجاري'.tr,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                validator: (v) =>
                    Validators.required(v, field: 'السجل التجاري'.tr),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'بيانات المالك والتواصل'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: AppFont.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: ownerNameController,
                label: 'اسم صاحب المحل'.tr,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                validator: (v) =>
                    Validators.required(v, field: 'اسم صاحب المحل'.tr),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: phoneController,
                label: 'رقم الهاتف'.tr,
                keyboardType: TextInputType.phone,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                validator: Validators.phone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  10) إدارة الوسائط والمستندات المشتركة — SHOP MEDIA MANAGER CARD (بدون أيقونات)
// =============================================================================

class ShopMediaManagerCard extends ConsumerStatefulWidget {
  const ShopMediaManagerCard({
    super.key,
    required this.shop,
    this.canEdit = true,
  });

  final Shop? shop;
  final bool canEdit;

  @override
  ConsumerState<ShopMediaManagerCard> createState() =>
      _ShopMediaManagerCardState();
}

class _ShopMediaManagerCardState extends ConsumerState<ShopMediaManagerCard> {
  String? _activeUpload;

  Future<void> _handleUpload({
    required String key,
    required Future<PickedBytes?> Function() picker,
    required String bucket,
    required String folder,
    required Future<bool> Function(String url) onUploaded,
    required String successMessage,
    required String failMessage,
  }) async {
    final picked = await picker();
    if (picked == null) return;
    setState(() => _activeUpload = key);
    try {
      final url = await ref
          .read(shopStorageRepositoryProvider)
          .uploadBytes(
            bucket: bucket,
            folder: folder,
            fileName: picked.fileName,
            bytes: picked.bytes,
            contentType: picked.contentType,
          );
      final ok = await onUploaded(url);
      if (!mounted) return;
      showAppSnackBar(
        context,
        ok ? successMessage.tr : failMessage.tr,
        isError: !ok,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        ref.read(shopStorageRepositoryProvider).mapError(error),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _activeUpload = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(shopImagesProvider).valueOrNull ?? const [];
    final docs = ref.watch(shopDocumentsProvider).valueOrNull ?? const [];
    final busy =
        _activeUpload != null || ref.watch(shopCatalogActionProvider).isLoading;
    final canUpload = widget.canEdit && !busy;
    final shop = widget.shop;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'الهوية البصرية والمستندات'.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: AppFont.bold),
                ),
              ),
              if (_activeUpload != null)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MediaUploadTile(
                  title: 'شعار المحل'.tr,
                  subtitle: (shop?.logoPath?.isNotEmpty ?? false)
                      ? 'تم الرفع'.tr
                      : 'غير مرفوع'.tr,
                  imageUrl: shop?.logoPath,
                  loading: _activeUpload == 'logo',
                  onTap: canUpload
                      ? () => _handleUpload(
                          key: 'logo',
                          picker: MediaPicker.pickImage,
                          bucket: 'shop-media',
                          folder: 'logo',
                          onUploaded: (url) => ref
                              .read(shopCatalogActionProvider.notifier)
                              .setLogo(url),
                          successMessage: 'تم رفع الشعار',
                          failMessage: 'تعذر رفع الشعار',
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MediaUploadTile(
                  title: 'صورة الغلاف'.tr,
                  subtitle: (shop?.coverPath?.isNotEmpty ?? false)
                      ? 'تم الرفع'.tr
                      : 'غير مرفوع'.tr,
                  imageUrl: shop?.coverPath,
                  loading: _activeUpload == 'cover',
                  onTap: canUpload
                      ? () => _handleUpload(
                          key: 'cover',
                          picker: MediaPicker.pickImage,
                          bucket: 'shop-media',
                          folder: 'cover',
                          onUploaded: (url) => ref
                              .read(shopCatalogActionProvider.notifier)
                              .setCover(url),
                          successMessage: 'تم رفع صورة الغلاف',
                          failMessage: 'تعذر رفع صورة الغلاف',
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${'صور المعرض'.tr} (${images.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
                ),
              ),
              TextButton(
                onPressed: canUpload
                    ? AppHaptics.action(
                        () => _handleUpload(
                          key: 'gallery',
                          picker: MediaPicker.pickImage,
                          bucket: 'shop-media',
                          folder: 'gallery',
                          onUploaded: (url) => ref
                              .read(shopCatalogActionProvider.notifier)
                              .addShopImage(url),
                          successMessage: 'تم رفع صورة المحل',
                          failMessage: 'تعذر رفع الصورة',
                        ),
                      )
                    : null,
                child: Text('إضافة صورة'.tr),
              ),
            ],
          ),
          if (images.isNotEmpty)
            SizedBox(
              height: SellerDesign.mediaThumbSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Container(
                      width: SellerDesign.mediaThumbSize,
                      height: SellerDesign.mediaThumbSize,
                      color: SellerDesign.uploadBoxBackground,
                      child: AppNetworkImage(
                        images[index].filePath,
                        fit: BoxFit.cover,
                        width: SellerDesign.mediaThumbSize,
                        height: SellerDesign.mediaThumbSize,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Text(
              'أضف صوراً حقيقية لمتجرك لتعزيز ثقة العملاء.'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'مستندات التوثيق'.tr} (${docs.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    Text(
                      docs.isEmpty
                          ? 'ارفع السجل التجاري أو إثبات المحل'.tr
                          : '${docs.length} ${'مستند مرفوع'.tr}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: canUpload
                    ? AppHaptics.action(
                        () => _handleUpload(
                          key: 'doc',
                          picker: MediaPicker.pickDocument,
                          bucket: 'shop-documents',
                          folder: 'docs',
                          onUploaded: (path) => ref
                              .read(shopCatalogActionProvider.notifier)
                              .addDocument(docType: 'إثبات محل'.tr, path: path),
                          successMessage: 'تم رفع المستند',
                          failMessage: 'تعذر رفع المستند',
                        ),
                      )
                    : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AuthDesign.socialButtonBackground,
                  foregroundColor: AuthDesign.socialButtonForeground,
                  side: BorderSide(
                    color: AuthDesign.socialButtonBorder,
                    width: AppBorders.width,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ButtonDesign.radius),
                  ),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                ),
                child: Text('رفع مستند'.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaUploadTile extends StatelessWidget {
  const _MediaUploadTile({
    required this.title,
    required this.subtitle,
    required this.loading,
    this.imageUrl,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool loading;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Material(
      color: SellerDesign.uploadBoxBackground,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: hasImage
                  ? AppColors.primaryBorder
                  : SellerDesign.uploadBoxBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: loading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : hasImage
                      ? AppNetworkImage(
                          imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 76,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surfaceAlt,
                            alignment: Alignment.center,
                            child: Text(
                              'رفع'.tr,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceAlt,
                          alignment: Alignment.center,
                          child: Text(
                            'اضغط للرفع'.tr,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: AppFont.bold),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: AppFont.tiny,
                  color: hasImage ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  11) شريط تقدم موحد — SHOP PROGRESS BAR
// =============================================================================

class ShopProgressBar extends StatelessWidget {
  const ShopProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        height: height,
        color: AppColors.surfaceAlt,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: clamped,
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              color: color ?? AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  12) صف خيار إعدادات موحد — SHOP PREFERENCE TILE (بدون أيقونات)
// =============================================================================

class ShopPreferenceTile extends StatelessWidget {
  const ShopPreferenceTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.onTap,
    this.selected = false,
    this.showCheck = false,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool selected;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? AppColors.white : AppColors.icon,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLang.tr(title),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLang.tr(subtitle),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (showCheck)
                Icon(
                  selected
                      ? AppIcons.checkCircleFilled
                      : AppIcons.radioUnchecked,
                  color: selected ? AppColors.primary : AppColors.iconMuted,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  13) صف قائمة ملف المتجر الموحد — SHOP PROFILE MENU ROW (مطابق لبروفايل العميل)
// =============================================================================

class ShopProfileMenuRow extends StatelessWidget {
  const ShopProfileMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
      subtitle: subtitle != null
          ? Text(
              AppLang.tr(subtitle!),
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : null,
      trailing: Icon(
        AppIcons.forward,
        color: isDestructive ? AppColors.error : ProfileDesign.menuChevron,
      ),
    );
  }
}
