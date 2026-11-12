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
      child: AppBottomSheetScaffold(
        title: 'أنواع الحسابات'.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('حساب المتسوق يتيح التصفح والشراء وتجربة الملابس افتراضياً.'.tr),
            SizedBox(height: AppSpacing.md),
            Text(
              'حساب المتجر يتيح التسجيل وإرسال طلب انضمام للإدارة لعرض وبيع منتجاتك.'.tr,
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
        title: Text('إنشاء حساب'.tr),
        actions: [
          IconButton(
            tooltip: 'معلومات الحسابات'.tr,
            onPressed: AppHaptics.action(() => _openInfo(context)),
            icon: Icon(AppIcons.info, color: AppColors.icon),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختر نوع الحساب'.tr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: AppFont.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'حدد طريقة استخدامك للتطبيق للمتابعة'.tr,
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
                      child: Icon(
                        AppIcons.user,
                        color: AppColors.icon,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حساب متسوق'.tr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تصفح الأزياء وتجربة الملابس والشراء'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
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
                      child: Icon(
                        AppIcons.shop,
                        color: AppColors.icon,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حساب متجر أزياء'.tr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: AppFont.bold,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'تسجيل متجرك وعرض منتجاتك واستقبال الطلبات'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      AppIcons.forward,
                      color: AppColors.icon,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'لدي حساب بالفعل · تسجيل الدخول'.tr,
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
