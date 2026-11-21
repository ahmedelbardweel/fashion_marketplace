import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/push_notification_settings_card.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gaza_region_picker_sheet.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customer/presentation/providers/customer_providers.dart';
import '../../domain/models/catalog_models.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_logout.dart';
import '../widgets/decart_settings_card.dart';
import '../widgets/tryon_cost_controls_card.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _populateFields() {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    _nameController.text = user.fullName ?? '';
    _phoneController.text = user.phone ?? '';
    _cityController.text = user.city ?? '';
    _addressController.text = user.address ?? '';
  }

  void _openEditAdminProfileSheet() {
    _populateFields();
    var isSaving = false;

    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> save() async {
            final name = _nameController.text.trim();
            final phone = _phoneController.text.trim();
            final city = _cityController.text.trim();
            final address = _addressController.text.trim();

            if (name.isEmpty) {
              showAppSnackBar(
                context,
                'يرجى كتابة الاسم الكامل'.tr,
                isError: true,
              );
              return;
            }
            if (city.isNotEmpty) {
              final regions =
                  ref.read(adminGazaRegionsProvider).asData?.value ??
                  kDefaultGazaRegions;
              if (!isValidGazaRegionSelection(city, regions)) {
                showAppSnackBar(
                  context,
                  'يرجى اختيار المدينة من مناطق قطاع غزة المعتمدة'.tr,
                  isError: true,
                );
                return;
              }
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
              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              if (mounted) {
                showAppSnackBar(context, 'تم حفظ بيانات حساب الإدارة بنجاح'.tr);
              }
            } catch (_) {
              if (sheetCtx.mounted) setSheetState(() => isSaving = false);
              if (mounted) {
                showAppSnackBar(
                  context,
                  'تعذر تحديث البيانات'.tr,
                  isError: true,
                );
              }
            }
          }

          return AppBottomSheetScaffold(
            title: 'تعديل بيانات حساب الإدارة'.tr,
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
                GazaRegionFormField(
                  controller: _cityController,
                  enabled: !isSaving,
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

  void _openDecartSheet() {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      child: AppBottomSheetScaffold(
        title: 'تجربة الملابس — Decart'.tr,
        child: const DecartSettingsCard(embedded: true),
      ),
    );
  }

  void _openTryonControlsSheet() {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      child: AppBottomSheetScaffold(
        title: 'التحكم في تكلفة التجربة الافتراضية'.tr,
        child: const TryonCostControlsCard(embedded: true),
      ),
    );
  }

  void _openPlatformSettingsSheet() {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.88,
      child: Consumer(
        builder: (sheetCtx, sheetRef, _) {
          final settingsAsync = sheetRef.watch(adminSettingsProvider);
          final busy = sheetRef.watch(adminActionProvider).isLoading;
          return AppBottomSheetScaffold(
            title: 'إعدادات المنصة العامة'.tr,
            child: settingsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => AppButton(
                label: 'إعادة تحميل إعدادات المنصة'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: () => sheetRef.invalidate(adminSettingsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const AdminEmptyState(
                    title: 'لا توجد إعدادات عامة بعد',
                    message: 'ستظهر هنا ثوابت وإعدادات المنصة بمجرد إضافتها.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items) ...[
                      AdminFeatureTile(
                        title: item.label,
                        subtitle: item.key,
                        trailingValue: item.value,
                        onTap: busy ? () {} : () => _editSetting(item),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              },
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
                AdminPreferenceTile(
                  icon: AppIcons.sun,
                  title: 'الوضع النهاري (Light Mode)',
                  subtitle: 'خلفية فاتحة ومريحة للإضاءة العالية',
                  selected: currentMode == ThemeMode.light,
                  onTap: () {
                    sheetRef.read(themeModeProvider.notifier).state =
                        ThemeMode.light;
                    Navigator.of(sheetCtx).pop();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AdminPreferenceTile(
                  icon: IconsaxPlusLinear.moon,
                  title: 'الوضع الليلي (Dark Mode)',
                  subtitle: 'ألوان داكنة مريحة للعين في الإضاءة الخافتة',
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
                AdminPreferenceTile(
                  icon: IconsaxPlusLinear.global,
                  title: 'العربية',
                  subtitle: 'اللغة الافتراضية للتطبيق (RTL)',
                  selected: currentLocale.languageCode == 'ar',
                  onTap: () {
                    sheetRef.read(appLocaleProvider.notifier).state =
                        const Locale('ar');
                    Navigator.of(sheetCtx).pop();
                    showAppSnackBar(context, 'تم اختيار اللغة العربية'.tr);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AdminPreferenceTile(
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

  Future<void> _editSetting(PlatformSetting setting) async {
    final controller = TextEditingController(text: setting.value);
    final formKey = GlobalKey<FormState>();

    final saved = await AppBottomSheet.show<bool>(
      context: context,
      child: AppBottomSheetScaffold(
        title: setting.label.tr,
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: controller,
                label: 'القيمة'.tr,
                validator: (value) =>
                    Validators.required(value, field: 'القيمة'.tr),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'حفظ'.tr,
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.of(context).pop(true);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'إلغاء'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    final value = controller.text;
    controller.dispose();
    if (saved != true || !mounted) return;

    final actions = ref.read(adminActionProvider.notifier);
    final ok = await actions.updateSetting(key: setting.key, value: value);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(adminActionProvider).error;
      showAppSnackBar(
        context,
        error == null ? 'تعذر الحفظ'.tr : actions.errorMessage(error),
        isError: true,
      );
      return;
    }
    showAppSnackBar(context, 'تم تحديث الإعداد'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);
    final decartStatus = ref.watch(adminDecartStatusProvider).asData?.value;
    final decartCredits = ref.watch(adminDecartCreditsProvider).asData?.value;
    final tryonControls = ref.watch(adminTryonControlsProvider).asData?.value;
    final settingsCount =
        ref.watch(adminSettingsProvider).asData?.value.length ?? 0;

    final name = user?.displayName ?? 'الإدارة'.tr;
    final initial = name.characters.first.toUpperCase();
    final contactLine = [
      if (user?.phone != null && user!.phone!.trim().isNotEmpty)
        user.phone!.trim(),
      if (user?.city != null && user!.city!.trim().isNotEmpty)
        user.city!.trim(),
    ].join(' · ');

    final decartSubtitle = decartCredits?.hasBalance == true
        ? '${'المتبقي'.tr}: ${decartCredits!.formattedCredits} ${'توكن'.tr} (${decartCredits.formattedUsd})'
        : (decartStatus == null
              ? 'مفتاح ربط خدمة تجربة الملابس بالذكاء الاصطناعي'
              : (decartStatus.configured
                    ? 'مفتاح محفوظ ومشفّر بأمان — اضغط للاستبدال'
                    : 'لم يتم إعداد مفتاح Decart بعد'));

    final decartBadge = decartCredits?.hasBalance == true
        ? '${decartCredits!.formattedCredits} ${'توكن'.tr}'
        : null;

    final tryonSubtitle = tryonControls == null
        ? 'مدة الجلسة والحد اليومي وتفعيل الخدمة'
        : (tryonControls.enabled
              ? '${'مفعّلة'.tr} · ${tryonControls.sessionDurationSeconds} ${'ثانية'.tr} · ${tryonControls.dailyAttemptsLimit} ${'محاولة/يوم'.tr}'
              : 'الخدمة متوقفة مؤقتاً لتوفير التكلفة');

    return AdminScaffold(
      title: 'حساب الإدارة'.tr,
      showBack: false,
      body: AppRefreshIndicator(
        onRefresh: () => Future.wait([
          ref.read(authControllerProvider.notifier).refreshProfile(),
          ref.refresh(adminSettingsProvider.future),
          ref.refresh(adminDecartStatusProvider.future),
          ref.refresh(adminDecartCreditsProvider.future),
          ref.refresh(adminTryonControlsProvider.future),
        ]),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1) Admin Header Card (100% matching Shop & Customer Profile)
              AppCard(
                onTap: _openEditAdminProfileSheet,
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
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: ProfileDesign.nameSize,
                              fontWeight: ProfileDesign.nameWeight,
                              color: AppColors.text,
                            ),
                          ),
                          if (user?.email.isNotEmpty ?? false) ...[
                            const SizedBox(height: 2),
                            Text(
                              user!.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            contactLine.isNotEmpty
                                ? contactLine
                                : 'إدارة المنصة'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 2) Platform & AI Configuration (Clean grouped rows opening Bottom Sheets)
              Text(
                'إعدادات المنصة والذكاء الاصطناعي'.tr,
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
                    AdminProfileMenuRow(
                      icon: AppIcons.sparkles,
                      title: 'تجربة الملابس — Decart API',
                      subtitle: decartSubtitle,
                      trailingBadge: decartBadge,
                      onTap: _openDecartSheet,
                    ),
                    const Divider(height: 1),
                    AdminProfileMenuRow(
                      icon: AppIcons.tryOn,
                      title: 'التحكم في تكلفة التجربة الافتراضية',
                      subtitle: tryonSubtitle,
                      onTap: _openTryonControlsSheet,
                    ),
                    const Divider(height: 1),
                    AdminProfileMenuRow(
                      icon: AppIcons.settings,
                      title: 'إعدادات المنصة العامة',
                      subtitle: settingsCount > 0
                          ? '${'تعديل الثوابت والقيم العامة'.tr} ($settingsCount)'
                          : 'تعديل الثوابت والقيم العامة للتطبيق',
                      onTap: _openPlatformSettingsSheet,
                    ),
                    const Divider(height: 1),
                    AdminProfileMenuRow(
                      icon: AppIcons.payment,
                      title: 'الإيرادات والعمولات والاتفاقيات',
                      subtitle:
                          'نسب الاتفاق مع المحلات، المستحقات، وطلبات التسوية',
                      onTap: () => context.push(AppRoutes.adminRevenue),
                    ),
                    const Divider(height: 1),
                    AdminProfileMenuRow(
                      icon: AppIcons.location,
                      title: 'مناطق قطاع غزة والتوصيل',
                      subtitle: 'إدارة المحافظات الخمس والأحياء ورسوم التوصيل',
                      onTap: () => context.push(AppRoutes.adminRegions),
                    ),
                    const Divider(height: 1),
                    AdminProfileMenuRow(
                      icon: AppIcons.bell,
                      title: 'الإشعارات الجماعية والموجهة',
                      subtitle: 'إرسال تنبيهات للعملاء والمحلات ومناطق غزة',
                      onTap: () => context.push(AppRoutes.adminNotifications),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 3) App Preferences (100% matching Shop & Customer Profile)
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
                    AdminProfileMenuRow(
                      icon: AppIcons.edit,
                      title: 'تعديل بيانات حساب الإدارة',
                      subtitle: 'الاسم الكامل، رقم الهاتف، المنطقة، والعنوان',
                      onTap: _openEditAdminProfileSheet,
                    ),
                    const Divider(height: 1),
                    AdminProfileMenuRow(
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
                    AdminProfileMenuRow(
                      icon: IconsaxPlusLinear.global,
                      title: 'لغة التطبيق',
                      subtitle: locale.languageCode == 'en'
                          ? 'English'
                          : 'العربية',
                      onTap: _openLanguageSheet,
                    ),
                    const Divider(height: 1),
                    const PushNotificationSettingsRow(),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 4) Account Management (100% matching Shop & Customer Profile)
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
                    AdminProfileMenuRow(
                      icon: AppIcons.logout,
                      title: 'تسجيل الخروج',
                      subtitle: 'الخروج من حساب الإدارة على هذا الجهاز',
                      onTap: () => confirmAdminLogout(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
