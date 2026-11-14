import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../router/routes.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (!ok) {
      final error = ref.read(authControllerProvider).errorMessage;
      showAppSnackBar(context, error ?? 'فشل تسجيل الدخول'.tr, isError: true);
    }
  }

  Future<void> _submitGoogle() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(authControllerProvider).errorMessage;
      showAppSnackBar(
        context,
        error ?? 'تعذر تسجيل الدخول عبر Google'.tr,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AuthDesign.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.page,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AuthDesign.maxFormWidth,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: AppLogoMark(size: AuthDesign.logoSize),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Shopy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AuthDesign.titleSize,
                        fontWeight: AuthDesign.titleWeight,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'تسجيل الدخول'.tr,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: AppFont.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'أدخل بيانات حسابك للمتابعة إلى عالم الأزياء'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: AuthDesign.subtitleColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني'.tr,
                      hint: 'name@example.com',
                      prefixIcon: AppIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _passwordController,
                      label: 'كلمة المرور'.tr,
                      hint: '********',
                      prefixIcon: AppIcons.lock,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) =>
                          Validators.required(value, field: 'كلمة المرور'.tr),
                      onFieldSubmitted: (_) => _submit(),
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
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'دخول'.tr,
                      isLoading: auth.isBusy,
                      onPressed: auth.isGoogleBusy ? null : _submit,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AuthDesign.dividerColor,
                            thickness: AppBorders.width,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: Text(
                            'أو'.tr,
                            style: TextStyle(
                              fontSize: AuthDesign.dividerTextSize,
                              fontWeight: AppFont.medium,
                              color: AuthDesign.dividerTextColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AuthDesign.dividerColor,
                            thickness: AppBorders.width,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppGoogleAuthButton(
                      isLoading: auth.isGoogleBusy,
                      onPressed: auth.isBusy ? null : _submitGoogle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'إنشاء حساب جديد'.tr,
                      variant: AppButtonVariant.outlined,
                      onPressed: (auth.isBusy || auth.isGoogleBusy)
                          ? null
                          : () => context.push(AppRoutes.register),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
