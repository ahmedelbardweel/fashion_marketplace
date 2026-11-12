import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/customer_providers.dart';
import '../widgets/customer_action_sheet.dart';
import '../widgets/customer_shell.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    final user = ref.read(authControllerProvider).user;
    if (user != null) {
      _nameController.text = user.fullName ?? '';
      _phoneController.text = user.phone ?? '';
      _cityController.text = user.city ?? '';
      _addressController.text = user.address ?? '';
    }
  }

  void _openEditProfileSheet() {
    _populateFields();
    bool isSaving = false;

    AppBottomSheet.show(
      context: context,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> save() async {
            final name = _nameController.text.trim();
            final phone = _phoneController.text.trim();
            final city = _cityController.text.trim();
            final address = _addressController.text.trim();

            if (name.isEmpty || phone.isEmpty) {
              showAppSnackBar(
                context,
                'يرجى كتابة الاسم ورقم الهاتف'.tr,
                isError: true,
              );
              return;
            }

            setSheetState(() => isSaving = true);
            try {
              final updated = await ref
                  .read(customerRepositoryProvider)
                  .updateProfile(
                    fullName: name,
                    phone: phone,
                    city: city,
                    address: address,
                  );
              ref.read(authControllerProvider.notifier).setUser(updated);
              if (sheetCtx.mounted) {
                Navigator.of(sheetCtx).pop();
              }
              if (mounted) {
                showAppSnackBar(context, 'تم حفظ بيانات الملف الشخصي بنجاح'.tr);
              }
            } catch (_) {
              if (sheetCtx.mounted) {
                setSheetState(() => isSaving = false);
              }
              if (mounted) {
                showAppSnackBar(context, 'تعذر تحديث البيانات'.tr, isError: true);
              }
            }
          }

          return AppBottomSheetScaffold(
            title: 'تعديل البيانات وعنوان التوصيل'.tr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'الاسم الكامل'.tr,
                  prefixIcon: AppIcons.user,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف'.tr,
                  prefixIcon: AppIcons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _cityController,
                  label: 'المدينة'.tr,
                  prefixIcon: AppIcons.city,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _addressController,
                  label: 'العنوان التفصيلي'.tr,
                  prefixIcon: AppIcons.location,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'حفظ التعديلات'.tr,
                  isLoading: isSaving,
                  onPressed: save,
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'إلغاء'.tr,
                  variant: AppButtonVariant.outlined,
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
                _SheetOptionTile(
                  icon: AppIcons.sun,
                  title: 'الوضع النهاري (Light Mode)'.tr,
                  subtitle: 'خلفية فاتحة ومريحة للإضاءة العالية'.tr,
                  selected: currentMode == ThemeMode.light,
                  onTap: () {
                    sheetRef.read(themeModeProvider.notifier).state =
                        ThemeMode.light;
                    Navigator.of(sheetCtx).pop();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _SheetOptionTile(
                  icon: IconsaxPlusLinear.moon,
                  title: 'الوضع الليلي (Dark Mode)'.tr,
                  subtitle: 'ألوان داكنة مريحة للعين في الإضاءة الخافتة'.tr,
                  selected: currentMode == ThemeMode.dark,
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
                _SheetOptionTile(
                  icon: IconsaxPlusLinear.global,
                  title: 'العربية'.tr,
                  subtitle: 'اللغة الافتراضية للتطبيق (RTL)'.tr,
                  selected: currentLocale.languageCode == 'ar',
                  onTap: () {
                    sheetRef.read(appLocaleProvider.notifier).state =
                        const Locale('ar');
                    Navigator.of(sheetCtx).pop();
                    showAppSnackBar(context, 'تم اختيار اللغة العربية'.tr);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _SheetOptionTile(
                  icon: IconsaxPlusLinear.global,
                  title: 'English',
                  subtitle: 'Switch interface direction to English (LTR)',
                  selected: currentLocale.languageCode == 'en',
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

  void _confirmLogout() {
    AppBottomSheet.show(
      context: context,
      child: Builder(
        builder: (ctx) {
          return CustomerActionSheet(
            title: Text('تسجيل الخروج'.tr),
            content: Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟'.tr,
            ),
            actions: [
              TextButton(
                onPressed: AppHaptics.action(() => Navigator.of(ctx).pop()),
                child: Text('إلغاء'.tr),
              ),
              ElevatedButton(
                onPressed: AppHaptics.action(() {
                  Navigator.of(ctx).pop();
                  ref.read(authControllerProvider.notifier).signOut();
                }),
                child: Text('تسجيل الخروج'.tr),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteAccount() {
    bool isDeleting = false;
    AppBottomSheet.show(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          return AppBottomSheetScaffold(
            title: 'حذف الحساب نهائياً'.tr,
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
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'سيتم إيقاف حسابك وحذف بياناتك الشخصية ولن تتمكن من استعادتها مرة أخرى.'.tr,
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
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : AppHaptics.action(() async {
                          setSheetState(() => isDeleting = true);
                          try {
                            await ref
                                .read(customerRepositoryProvider)
                                .deleteAccount();
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
                                'تعذر حذف الحساب حالياً، حاول مرة أخرى'.tr,
                                isError: true,
                              );
                            }
                          }
                        }),
                  child: Text(
                    isDeleting ? 'جاري حذف الحساب...'.tr : 'تأكيد حذف الحساب'.tr,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'إلغاء'.tr,
                  variant: AppButtonVariant.outlined,
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
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final initial =
        (user?.fullName != null && user!.fullName!.trim().isNotEmpty)
        ? user.fullName!.trim().characters.first.toUpperCase()
        : 'ع'.tr;

    return CustomerScaffold(
      title: 'حسابي'.tr,
      currentNavIndex: 4,
      showBack: false,
      showSearch: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Card
            AppCard(
              onTap: _openEditProfileSheet,
              child: Row(
                children: [
                  Container(
                    width: ProfileDesign.avatarSize,
                    height: ProfileDesign.avatarSize,
                    decoration: BoxDecoration(
                      color: ProfileDesign.avatarBackground,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
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
                          user?.fullName ?? 'عميل المتجر'.tr,
                          style: TextStyle(
                            fontSize: ProfileDesign.nameSize,
                            fontWeight: ProfileDesign.nameWeight,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (user?.phone != null &&
                            user!.phone!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${user.phone!}${user.city != null && user.city!.trim().isNotEmpty ? ' · ${user.city}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Account & App Preferences
            Text(
              'إعدادات الحساب والتطبيق'.tr,
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
                  _ProfileMenuRow(
                    icon: AppIcons.edit,
                    title: 'تعديل البيانات وعنوان التوصيل'.tr,
                    subtitle: 'الاسم، رقم الهاتف، المدينة، والعنوان التفصيلي'.tr,
                    onTap: _openEditProfileSheet,
                  ),
                  const Divider(height: 1),
                  _ProfileMenuRow(
                    icon: themeMode == ThemeMode.dark
                        ? IconsaxPlusLinear.moon
                        : AppIcons.sun,
                    title: 'مظهر التطبيق (الوضع الليلي / النهاري)'.tr,
                    subtitle: themeMode == ThemeMode.dark
                        ? 'الوضع الليلي (Dark Mode)'.tr
                        : 'الوضع النهاري (Light Mode)'.tr,
                    onTap: _openThemeSheet,
                  ),
                  const Divider(height: 1),
                  _ProfileMenuRow(
                    icon: IconsaxPlusLinear.global,
                    title: 'لغة التطبيق'.tr,
                    subtitle: locale.languageCode == 'en'
                        ? 'English'
                        : 'العربية'.tr,
                    onTap: _openLanguageSheet,
                  ),
                ],
              ),
            ),



            const SizedBox(height: AppSpacing.md),

            // Account Actions (Logout & Delete Account)
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
                  _ProfileMenuRow(
                    icon: AppIcons.logout,
                    title: 'تسجيل الخروج'.tr,
                    subtitle: 'الخروج من حسابك الحالي على هذا الجهاز'.tr,
                    onTap: _confirmLogout,
                  ),
                  const Divider(height: 1),
                  _ProfileMenuRow(
                    icon: AppIcons.delete,
                    title: 'حذف الحساب'.tr,
                    subtitle: 'إيقاف الحساب وحذف جميع البيانات نهائياً'.tr,
                    isDestructive: true,
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.text;
    final iconBg = isDestructive
        ? AppColors.errorSoft
        : ProfileDesign.menuIconBackground;
    final iconColor = isDestructive ? AppColors.error : ProfileDesign.menuIcon;

    return ListTile(
      onTap: AppHaptics.action(onTap),
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
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: AppFont.semiBold,
          color: color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            )
          : null,
      trailing: Icon(
        AppIcons.forward,
        color: isDestructive ? AppColors.error : ProfileDesign.menuChevron,
      ),
    );
  }
}

class _SheetOptionTile extends StatelessWidget {
  const _SheetOptionTile({
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
    return InkWell(
      onTap: AppHaptics.action(onTap),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.white,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? AppColors.white : AppColors.icon,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? AppIcons.checkCircleFilled : AppIcons.radioUnchecked,
              color: selected ? AppColors.primary : AppColors.iconMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
