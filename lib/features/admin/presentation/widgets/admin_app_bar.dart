import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_empty.dart';
import 'admin_bottom_nav.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.showBack = true,
    this.actions,
  });

  final String title;
  final Widget? titleWidget;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(AppBarDesign.height);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    final overlayStyle = AppColors.isDark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AppBar(
      toolbarHeight: AppBarDesign.height,
      backgroundColor: AdminDesign.appBarBackground,
      foregroundColor: AppBarDesign.titleColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: overlayStyle,
      shape: Border(
        bottom: BorderSide(color: AppBarDesign.borderColor, width: 1),
      ),
      leading: canPop
          ? IconButton(
              tooltip: 'رجوع'.tr,
              onPressed: AppHaptics.action(
                () => Navigator.of(context).maybePop(),
              ),
              icon: Icon(AppIcons.back, color: AppBarDesign.iconColor),
            )
          : const Padding(
              padding: EdgeInsetsDirectional.only(start: AppSpacing.sm),
              child: Center(child: AppLogoMark()),
            ),
      leadingWidth: canPop ? 56 : 48,
      titleSpacing: canPop ? 0 : AppSpacing.xs,
      centerTitle: false,
      title: titleWidget != null
          ? Row(
              children: [
                if (canPop) ...[
                  const AppLogoMark(),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(child: titleWidget!),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canPop) ...[
                  const AppLogoMark(),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    AppLang.tr(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppBarDesign.titleSize,
                      fontWeight: AppBarDesign.titleWeight,
                      color: AppBarDesign.titleColor,
                    ),
                  ),
                ),
              ],
            ),
      actions: actions,
    );
  }
}

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.titleWidget,
    this.showBack = true,
    this.showBottomNav = true,
    this.actions,
    this.bottom,
  });

  final String title;
  final Widget? titleWidget;
  final Widget body;
  final bool showBack;
  final bool showBottomNav;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SellerDesign.pageBackground,
      appBar: AdminAppBar(
        title: title,
        titleWidget: titleWidget,
        showBack: showBack,
        actions: actions,
      ),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bottom != null)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: AppBorders.side),
              ),
              child: SafeArea(
                top: false,
                bottom: !showBottomNav,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: bottom,
                ),
              ),
            ),
          if (showBottomNav) const AdminBottomNav(),
        ],
      ),
    );
  }
}

/// Clean shadow-free feature tile matching ShopFeatureTile (zero dev codes, zero body icons).
class AdminFeatureTile extends StatelessWidget {
  const AdminFeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.code,
    this.badge,
    this.trailingValue,
    this.badgeTone = BadgeTone.primary,
  });

  /// Kept optional for backward compatibility; never displayed.
  final String? code;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final String? trailingValue;
  final BadgeTone badgeTone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SellerDesign.statCardBackground,
      borderRadius: BorderRadius.circular(CardDesign.radius),
      child: InkWell(
        onTap: AppHaptics.action(onTap),
        borderRadius: BorderRadius.circular(CardDesign.radius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: SellerDesign.statCardBorder),
            borderRadius: BorderRadius.circular(CardDesign.radius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLang.tr(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppLang.tr(subtitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null && badge!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                AppStatusBadge(label: badge!, tone: badgeTone),
              ],
              if (trailingValue != null && trailingValue!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  trailingValue!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: AppFont.extraBold,
                    color: AppColors.text,
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
