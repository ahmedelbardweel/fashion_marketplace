import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
import '../providers/auth_provider.dart';

class RegisterShopScreen extends ConsumerStatefulWidget {
  const RegisterShopScreen({super.key});

  @override
  ConsumerState<RegisterShopScreen> createState() => _RegisterShopScreenState();
}

class _RegisterShopScreenState extends ConsumerState<RegisterShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _shopNameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .registerShop(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
          phone: _phoneController.text,
          shopName: _shopNameController.text,
        );

    if (!mounted) return;
    if (!ok) {
      final error = ref.read(authControllerProvider).errorMessage;
      showAppSnackBar(context, error ?? 'فشل إنشاء حساب المحل', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل محل')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.page,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أنشئ حساب المحل',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'بعد التسجيل أكمل البيانات وأرسل طلب الانضمام. المنتجات غير متاحة قبل موافقة الإدارة.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _shopNameController,
                  label: 'اسم المحل',
                  hint: 'اسم المتجر',
                  textInputAction: TextInputAction.next,
                  validator: Validators.shopName,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _nameController,
                  label: 'اسم المسؤول',
                  hint: 'الاسم الكامل',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.fullName,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  hint: '05xxxxxxxx',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  hint: 'shop@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  hint: '8 أحرف على الأقل مع أرقام',
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                  suffix: IconButton(
                    onPressed: AppHaptics.action(
                      () => setState(() => _obscure = !_obscure),
                    ),
                    icon: Icon(
                      _obscure ? AppIcons.eye : AppIcons.eyeOff,
                      color: AppColors.icon,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _confirmController,
                  label: 'تأكيد كلمة المرور',
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  validator: (value) => Validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    onPressed: AppHaptics.action(
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    icon: Icon(
                      _obscureConfirm ? AppIcons.eye : AppIcons.eyeOff,
                      color: AppColors.icon,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'إنشاء حساب المحل',
                  isLoading: auth.isBusy,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'العودة لتسجيل الدخول',
                  variant: AppButtonVariant.text,
                  onPressed: auth.isBusy
                      ? null
                      : () => context.go(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
