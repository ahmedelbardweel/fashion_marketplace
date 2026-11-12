import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'إعداد التطبيق'.tr,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: AppColors.black,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'انسخ .env.example إلى .env وضع SUPABASE_URL و SUPABASE_ANON_KEY من لوحة Supabase، ثم نفّذ SQL الموجود في supabase/migrations/001_auth_profiles.sql'.tr,
                  style: TextStyle(color: AppColors.gray700, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
