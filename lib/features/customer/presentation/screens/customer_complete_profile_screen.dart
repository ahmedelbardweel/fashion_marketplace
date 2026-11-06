import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/customer_providers.dart';

class CustomerCompleteProfileScreen extends ConsumerStatefulWidget {
  const CustomerCompleteProfileScreen({super.key});

  @override
  ConsumerState<CustomerCompleteProfileScreen> createState() =>
      _CustomerCompleteProfileScreenState();
}

class _CustomerCompleteProfileScreenState
    extends ConsumerState<CustomerCompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(completeCustomerProfileProvider.notifier);
    final ok = await controller.submit(
      fullName: _nameController.text,
      phone: _phoneController.text,
      city: _cityController.text,
      address: _addressController.text,
    );

    if (!mounted) return;
    if (!ok) {
      final error = ref.read(completeCustomerProfileProvider).error;
      showAppSnackBar(
        context,
        error == null
            ? 'تعذر حفظ الملف الشخصي'
            : controller.errorMessage(error),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(completeCustomerProfileProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال الملف الشخصي'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: AppHaptics.action(
              busy
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signOut(),
            ),
            child: const Text('خروج'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.page,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أكمل بياناتك للمتابعة',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'هذه البيانات مطلوبة لاستخدام المتجر وإتمام الطلبات لاحقاً',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  validator: Validators.fullName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _cityController,
                  label: 'المدينة',
                  validator: (value) =>
                      Validators.required(value, field: 'المدينة'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _addressController,
                  label: 'العنوان',
                  validator: (value) =>
                      Validators.required(value, field: 'العنوان'),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'حفظ والمتابعة',
                  isLoading: busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
