import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/push_notification_settings_card.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/shop.dart';
import '../providers/shop_catalog_providers.dart';
import '../providers/shop_providers.dart';
import '../widgets/shop_components.dart';
import '../widgets/shop_shell.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _register = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    _address.dispose();
    _register.dispose();
    _ownerName.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _populateFields(Shop shop) {
    final user = ref.read(authControllerProvider).user;
    _name.text = shop.name;
    _description.text = shop.description ?? '';
    _city.text = shop.city ?? '';
    _address.text = shop.address ?? '';
    _register.text = shop.commercialRegister ?? '';
    _ownerName.text = user?.fullName ?? shop.ownerName ?? '';
    _phone.text = user?.phone ?? shop.ownerPhone ?? '';
  }

  void _openEditShopSheet(Shop shop) {
    _populateFields(shop);
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> save() async {
            FocusScope.of(sheetCtx).unfocus();
            if (formKey.currentState?.validate() != true) return;
            setSheetState(() => isSaving = true);
            final actions = ref.read(shopCatalogActionProvider.notifier);
            final ok = await actions.updateProfile(
              shopName: _name.text,
              description: _description.text,
              city: _city.text,
              address: _address.text,
              commercialRegister: _register.text,
              ownerName: _ownerName.text,
              phone: _phone.text,
            );
            if (!mounted) return;
            if (!ok) {
              if (sheetCtx.mounted) setSheetState(() => isSaving = false);
              final error = ref.read(shopCatalogActionProvider).error;
              showAppSnackBar(
                context,
                error == null
                    ? 'تعذر حفظ الملف'.tr
                    : actions.errorMessage(error),
                isError: true,
              );
              return;
            }
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
            showAppSnackBar(context, 'تم تحديث ملف المحل'.tr);
          }

          return AppBottomSheetScaffold(
            title: 'تعديل بيانات المتجر والمالك'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShopDetailsFormFields(
                    shopNameController: _name,
                    descriptionController: _description,
                    cityController: _city,
                    addressController: _address,
                    registerController: _register,
                    ownerNameController: _ownerName,
                    phoneController: _phone,
                    enabled: shop.canEdit && !isSaving,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'حفظ التعديلات'.tr,
                    isLoading: isSaving,
                    onPressed: shop.canEdit ? save : null,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'إلغاء'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openMediaSheet() {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      child: Consumer(
        builder: (sheetCtx, sheetRef, _) {
          final latestShop = sheetRef.watch(myShopProvider).asData?.value;
          final busy = sheetRef.watch(shopCatalogActionProvider).isLoading;
          return AppBottomSheetScaffold(
            title: 'الهوية البصرية والمستندات'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShopMediaManagerCard(
                  shop: latestShop,
                  canEdit: (latestShop?.canEdit ?? false) && !busy,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'إغلاق'.tr,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openThemeSheet() {
    AppBottomSheet.show(
      context: context,
      child: Consumer(
        builder: (sheetCtx, sheetRef, _) {
          final currentMode = sheetRef.watch(themeModeProvider);
          return AppBottomSheetScaffold(
            title: 'مظهر التطبيق'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShopPreferenceTile(
                  icon: AppIcons.sun,
                  title: 'الوضع النهاري (Light Mode)',
                  subtitle: 'خلفية فاتحة ومريحة للإضاءة العالية',
                  selected: currentMode == ThemeMode.light,
                  showCheck: true,
                  onTap: () {
                    sheetRef.read(themeModeProvider.notifier).state =
                        ThemeMode.light;
                    Navigator.of(sheetCtx).pop();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopPreferenceTile(
                  icon: IconsaxPlusLinear.moon,
                  title: 'الوضع الليلي (Dark Mode)',
                  subtitle: 'ألوان داكنة مريحة للعين في الإضاءة الخافتة',
                  selected: currentMode == ThemeMode.dark,
                  showCheck: true,
                  onTap: () {
                    sheetRef.read(themeModeProvider.notifier).state =
                        ThemeMode.dark;
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openLanguageSheet() {
    AppBottomSheet.show(
      context: context,
      child: Consumer(
        builder: (sheetCtx, sheetRef, _) {
          final currentLocale = sheetRef.watch(appLocaleProvider);
          return AppBottomSheetScaffold(
            title: 'لغة التطبيق'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShopPreferenceTile(
                  icon: IconsaxPlusLinear.global,
                  title: 'العربية',
                  subtitle: 'اللغة الافتراضية للتطبيق (RTL)',
                  selected: currentLocale.languageCode == 'ar',
                  showCheck: true,
                  onTap: () {
                    sheetRef.read(appLocaleProvider.notifier).state =
                        const Locale('ar');
                    Navigator.of(sheetCtx).pop();
                    showAppSnackBar(context, 'تم اختيار اللغة العربية'.tr);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ShopPreferenceTile(
                  icon: IconsaxPlusLinear.global,
                  title: 'English',
                  subtitle: 'Switch interface direction to English (LTR)',
                  selected: currentLocale.languageCode == 'en',
                  showCheck: true,
                  onTap: () {
                    sheetRef.read(appLocaleProvider.notifier).state =
                        const Locale('en');
                    Navigator.of(sheetCtx).pop();
                    showAppSnackBar(context, 'Language switched to English');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteShop() {
    var isDeleting = false;
    AppBottomSheet.show(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          return AppBottomSheetScaffold(
            title: 'حذف المحل نهائياً'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.error, color: AppColors.error, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'سيتم إغلاق متجرك وإيقاف جميع منتجاتك وحسابك ولن تتمكن من استعادتها مرة أخرى.'
                              .tr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.semiBold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppPalette.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : AppHaptics.action(() async {
                          setSheetState(() => isDeleting = true);
                          try {
                            await ref
                                .read(shopRepositoryProvider)
                                .deleteShopAccount();
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            await ref
                                .read(authControllerProvider.notifier)
                                .signOut();
                          } catch (_) {
                            if (ctx.mounted) {
                              setSheetState(() => isDeleting = false);
                            }
                            if (mounted) {
                              showAppSnackBar(
                                context,
                                'تعذر حذف المحل حالياً، حاول مرة أخرى'.tr,
                                isError: true,
                              );
                            }
                          }
                        }),
                  child: Text(
                    isDeleting ? 'جاري حذف المحل...'.tr : 'تأكيد حذف المحل'.tr,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'إلغاء'.tr,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final shopAsync = ref.watch(myShopProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return ShopScaffold(
      title: 'ملف المتجر'.tr,
      showBack: false,
      body: shopAsync.skeletonWhen(
        placeholder: LoadingFixtures.shop,
        skipLoadingOnReload: true,
        error: (error, _) => ListView(
          padding: AppSpacing.page,
          children: [
            ShopNoticeBanner(
              title: 'تعذر تحميل ملف المتجر',
              message: ref.read(shopRepositoryProvider).mapError(error),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(myShopProvider),
            ),
          ],
        ),
        data: (shop) {
          if (shop == null) {
            return ShopCenteredEmptyView(
              onRefresh: () => ref.refresh(myShopProvider.future),
              title: 'لم يتم العثور على بيانات المحل',
              message: 'حاول تحديث الصفحة أو التواصل مع الدعم.',
            );
          }

          final shopName = shop.name.trim().isNotEmpty ? shop.name : 'متجري'.tr;
          final initial = shopName.characters.first.toUpperCase();
          final hasLogo = shop.logoPath != null && shop.logoPath!.isNotEmpty;
          final phone = user?.phone ?? shop.ownerPhone;
          final city = shop.city;
          final contactLine = [
            if (phone != null && phone.trim().isNotEmpty) phone.trim(),
            if (city != null && city.trim().isNotEmpty) city.trim(),
          ].join(' · ');

          return AppRefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(authControllerProvider.notifier).refreshProfile(),
                ref.refresh(myShopProvider.future),
                ref.refresh(shopImagesProvider.future),
                ref.refresh(shopDocumentsProvider.future),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1) Shop Header Card (matching Customer Profile Header)
                  AppCard(
                    onTap: shop.canEdit ? () => _openEditShopSheet(shop) : null,
                    child: Row(
                      children: [
                        Container(
                          width: ProfileDesign.avatarSize,
                          height: ProfileDesign.avatarSize,
                          decoration: BoxDecoration(
                            color: ProfileDesign.avatarBackground,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: hasLogo
                              ? AppNetworkImage(
                                  shop.logoPath!,
                                  fit: BoxFit.cover,
                                  width: ProfileDesign.avatarSize,
                                  height: ProfileDesign.avatarSize,
                                  errorBuilder: (_, _, _) => Text(
                                    initial,
                                    style: TextStyle(
                                      color: ProfileDesign.avatarText,
                                      fontSize: 26,
                                      fontWeight: AppFont.extraBold,
                                    ),
                                  ),
                                )
                              : Text(
                                  initial,
                                  style: TextStyle(
                                    color: ProfileDesign.avatarText,
                                    fontSize: 26,
                                    fontWeight: AppFont.extraBold,
                                  ),
                                ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ProfileDesign.nameSize,
                                  fontWeight: ProfileDesign.nameWeight,
                                  color: AppColors.text,
                                ),
                              ),
                              if (user?.email != null &&
                                  user!.email.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                              if (contactLine.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  contactLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (shop.canEdit) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Icon(
                              AppIcons.edit,
                              size: 18,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (!shop.isApprovedVisible) ...[
                    const SizedBox(height: AppSpacing.md),
                    ShopNoticeBanner(
                      title:
                          '${'حالة توثيق المتجر'.tr}: ${shop.visibleStatus.labelAr.tr}',
                      message:
                          shop.visibleRejectionReason ??
                          'يمكنك متابعة حالة طلب الانضمام أو استكمال بياناتك من صفحة الحالة.',
                      tone: shopStatusTone(shop.visibleStatus),
                      actionLabel: 'عرض حالة الطلب',
                      onAction: () => context.push(AppRoutes.shopStatus),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // 2) Shop & App Settings (matching Customer Profile Section 1)
                  Text(
                    'إعدادات المتجر والتطبيق'.tr,
                    style: TextStyle(
                      fontSize: SectionDesign.titleSize,
                      fontWeight: SectionDesign.titleWeight,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: SectionDesign.spacingBelow),

                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ShopProfileMenuRow(
                          icon: AppIcons.edit,
                          title: 'تعديل بيانات المتجر والمالك',
                          subtitle:
                              'اسم المحل، الوصف، المدينة، العنوان، السجل التجاري، والهاتف',
                          onTap: shop.canEdit
                              ? () => _openEditShopSheet(shop)
                              : null,
                        ),
                        const Divider(height: 1),
                        ShopProfileMenuRow(
                          icon: AppIcons.addPhoto,
                          title: 'الهوية البصرية والمستندات',
                          subtitle:
                              'الشعار، صورة الغلاف، صور المعرض، ومستندات التوثيق',
                          onTap: _openMediaSheet,
                        ),
                        const Divider(height: 1),
                        ShopProfileMenuRow(
                          icon: AppIcons.banners,
                          title: 'بنرات المتجر',
                          subtitle:
                              'التحكم في بنرات العروض والإعلانات الظاهرة للعملاء',
                          onTap: () => context.go(AppRoutes.shopBanners),
                        ),
                        const Divider(height: 1),
                        ShopProfileMenuRow(
                          icon: themeMode == ThemeMode.dark
                              ? IconsaxPlusLinear.moon
                              : AppIcons.sun,
                          title: 'مظهر التطبيق (الوضع الليلي / النهاري)',
                          subtitle: themeMode == ThemeMode.dark
                              ? 'الوضع الليلي (Dark Mode)'
                              : 'الوضع النهاري (Light Mode)',
                          onTap: _openThemeSheet,
                        ),
                        const Divider(height: 1),
                        ShopProfileMenuRow(
                          icon: IconsaxPlusLinear.global,
                          title: 'لغة التطبيق',
                          subtitle: locale.languageCode == 'en'
                              ? 'English'
                              : 'العربية',
                          onTap: _openLanguageSheet,
                        ),
                        const Divider(height: 1),
                        ShopProfileMenuRow(
                          icon: AppIcons.shieldTick,
                          title: 'حالة طلب الانضمام',
                          subtitle: shop.visibleStatus.labelAr,
                          onTap: () => context.push(AppRoutes.shopStatus),
                        ),
                        const Divider(height: 1),
                        const PushNotificationSettingsRow(),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 3) Account Management (matching Customer Profile Section 2)
                  Text(
                    'إدارة الحساب'.tr,
                    style: TextStyle(
                      fontSize: SectionDesign.titleSize,
                      fontWeight: SectionDesign.titleWeight,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: SectionDesign.spacingBelow),

                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ShopProfileMenuRow(
                          icon: AppIcons.logout,
                          title: 'تسجيل الخروج',
                          subtitle: 'الخروج من حسابك الحالي على هذا الجهاز',
                          onTap: () => confirmShopLogout(context, ref),
                        ),
                        const Divider(height: 1),
                        ShopProfileMenuRow(
                          icon: AppIcons.delete,
                          title: 'حذف المحل',
                          subtitle:
                              'إغلاق المتجر وإيقاف جميع المنتجات والحساب نهائياً',
                          isDestructive: true,
                          onTap: _confirmDeleteShop,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
