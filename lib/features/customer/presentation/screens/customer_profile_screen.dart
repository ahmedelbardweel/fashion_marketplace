import '../widgets/customer_action_sheet.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/customer_providers.dart';
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
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.black,
                  foregroundColor: AppColors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(authControllerProvider.notifier).signOut();
                },
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

    return CustomerScaffold(
      title: 'الملف الشخصي',
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'تسجيل الخروج',
          icon: const Icon(Icons.logout, color: AppColors.black),
          onPressed: _confirmLogout,
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
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.black,
                    child: Text(
                      (user?.fullName != null &&
                              user!.fullName!.trim().isNotEmpty)
                          ? user.fullName!.trim()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.gray500),
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
                Text(
                  'البيانات وعنوان التوصيل',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 16),
                  label: Text(_isEditing ? 'إلغاء' : 'تعديل'),
                  onPressed: () {
                    setState(() {
                      if (_isEditing) _populateFields();
                      _isEditing = !_isEditing;
                    });
                  },
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
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _cityController,
                    label: 'المدينة',
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _addressController,
                    label: 'العنوان التفصيلي',
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
            Text(
              'روابط سريعة',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),

            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('سجل طلباتي ومشترياتي'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push(AppRoutes.customerOrders),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.favorite_border),
                    title: const Text('قائمة المفضلة'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push(AppRoutes.customerFavorites),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.compare_arrows_rounded),
                    title: const Text('مقارنة الملابس المختارة'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push(AppRoutes.customerCompare),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('الإشعارات والتحديثات'),
                    trailing: const Icon(Icons.chevron_left),
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
