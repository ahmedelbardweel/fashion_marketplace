import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../router/routes.dart';

class RegisterChoiceScreen extends StatelessWidget {
  const RegisterChoiceScreen({super.key});

  void _openInfo(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      child: const AppBottomSheetScaffold(
        title: 'أنواع الحسابات',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('حساب المتسوق يتيح التصفح والشراء وتجربة الملابس افتراضياً.'),
            SizedBox(height: AppSpacing.md),
            Text(
              'حساب المتجر يتيح التسجيل وإرسال طلب انضمام للإدارة لعرض وبيع منتجاتك.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthDesign.pageBackground,
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        actions: [
          IconButton(
            tooltip: 'معلومات الحسابات',
            onPressed: AppHaptics.action(() => _openInfo(context)),
            icon: const Icon(AppIcons.info, color: AppColors.icon),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر نوع الحساب',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: AppFont.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'حدد طريقة استخدامك للتطبيق للمتابعة',
                style: TextStyle(
                  fontSize: 14,
                  color: AuthDesign.subtitleColor,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                onTap: () => context.push(AppRoutes.registerCustomer),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: const Icon(
                        AppIcons.user,
                        color: AppColors.icon,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حساب متسوق',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تصفح الأزياء وتجربة الملابس والشراء',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      AppIcons.forward,
                      color: AppColors.icon,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                onTap: () => context.push(AppRoutes.registerShop),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: const Icon(
                        AppIcons.shop,
                        color: AppColors.icon,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حساب متجر أزياء',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تسجيل متجرك وعرض منتجاتك واستقبال الطلبات',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      AppIcons.forward,
                      color: AppColors.icon,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'لدي حساب بالفعل · تسجيل الدخول',
                variant: AppButtonVariant.text,
                onPressed: () => context.go(AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
