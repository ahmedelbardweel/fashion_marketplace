import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
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
  bool _isEditing = false;
  bool _isSaving = false;

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

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      showAppSnackBar(context, 'يرجى كتابة الاسم ورقم الهاتف', isError: true);
      return;
    }

    setState(() => _isSaving = true);
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
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      if (mounted) {
        showAppSnackBar(context, 'تم حفظ بيانات الملف الشخصي بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showAppSnackBar(context, 'تعذر تحديث البيانات', isError: true);
      }
    }
  }

  void _confirmLogout() {
    AppBottomSheet.show(
      context: context,
      child: Builder(
        builder: (ctx) {
          return CustomerActionSheet(
            title: const Text('تسجيل الخروج'),
            content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
            ),
            actions: [
              TextButton(
                onPressed: AppHaptics.action(() => Navigator.of(ctx).pop()),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: AppHaptics.action(() {
                  Navigator.of(ctx).pop();
                  ref.read(authControllerProvider.notifier).signOut();
                }),
                child: const Text('تسجيل الخروج'),
              ),
            ],
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
    final initial =
        (user?.fullName != null && user!.fullName!.trim().isNotEmpty)
        ? user.fullName!.trim().characters.first.toUpperCase()
        : 'ع';

    return CustomerScaffold(
      title: 'الملف الشخصي',
      showBack: true,
      showSearch: false,
      actions: [
        IconButton(
          tooltip: 'تسجيل الخروج',
          icon: const Icon(AppIcons.logout, color: AppColors.icon),
          onPressed: AppHaptics.action(_confirmLogout),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Card
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: ProfileDesign.avatarSize,
                    height: ProfileDesign.avatarSize,
                    decoration: const BoxDecoration(
                      color: ProfileDesign.avatarBackground,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
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
                          user?.fullName ?? 'عميل المتجر',
                          style: const TextStyle(
                            fontSize: ProfileDesign.nameSize,
                            fontWeight: ProfileDesign.nameWeight,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Profile Edit Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'البيانات وعنوان التوصيل',
                  style: TextStyle(
                    fontSize: SectionDesign.titleSize,
                    fontWeight: SectionDesign.titleWeight,
                    color: AppColors.text,
                  ),
                ),
                TextButton.icon(
                  icon: Icon(
                    _isEditing ? AppIcons.close : AppIcons.edit,
                    size: 16,
                  ),
                  label: Text(_isEditing ? 'إلغاء' : 'تعديل'),
                  onPressed: AppHaptics.action(() {
                    setState(() {
                      if (_isEditing) _populateFields();
                      _isEditing = !_isEditing;
                    });
                  }),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    prefixIcon: AppIcons.user,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    prefixIcon: AppIcons.phone,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _cityController,
                    label: 'المدينة',
                    prefixIcon: AppIcons.city,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _addressController,
                    label: 'العنوان التفصيلي',
                    prefixIcon: AppIcons.location,
                    enabled: _isEditing,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'حفظ التعديلات',
                      isLoading: _isSaving,
                      onPressed: _saveProfile,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Quick Navigation Shortcuts
            const Text(
              'روابط سريعة',
              style: TextStyle(
                fontSize: SectionDesign.titleSize,
                fontWeight: SectionDesign.titleWeight,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileMenuRow(
                    icon: AppIcons.orders,
                    title: 'سجل طلباتي ومشترياتي',
                    onTap: () => context.push(AppRoutes.customerOrders),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuRow(
                    icon: AppIcons.heart,
                    title: 'قائمة المفضلة',
                    onTap: () => context.push(AppRoutes.customerFavorites),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuRow(
                    icon: AppIcons.compare,
                    title: 'مقارنة الملابس المختارة',
                    onTap: () => context.push(AppRoutes.customerCompare),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuRow(
                    icon: AppIcons.bell,
                    title: 'الإشعارات والتحديثات',
                    onTap: () => context.push(AppRoutes.customerNotifications),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: 'تسجيل الخروج',
              variant: AppButtonVariant.outlined,
              onPressed: _confirmLogout,
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
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: AppHaptics.action(onTap),
      leading: Container(
        width: ProfileDesign.menuIconBoxSize,
        height: ProfileDesign.menuIconBoxSize,
        decoration: BoxDecoration(
          color: ProfileDesign.menuIconBackground,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, size: 20, color: ProfileDesign.menuIcon),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: AppFont.semiBold,
          color: AppColors.text,
        ),
      ),
      trailing: const Icon(
        AppIcons.forward,
        color: ProfileDesign.menuChevron,
      ),
    );
  }
}
