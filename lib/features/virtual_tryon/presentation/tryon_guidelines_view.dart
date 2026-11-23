import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// First-time onboarding screen shown before measurements & body-zone selection.
/// Explains optimal conditions (strong lighting, clean lens, fast internet,
/// AI preview expectations) and requires accepting the terms to proceed.
class TryonGuidelinesView extends StatefulWidget {
  const TryonGuidelinesView({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.sessionDurationSeconds = 30,
    this.dailyLimit = 3,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;
  final int sessionDurationSeconds;
  final int dailyLimit;

  @override
  State<TryonGuidelinesView> createState() => _TryonGuidelinesViewState();
}

class _TryonGuidelinesViewState extends State<TryonGuidelinesView> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildGuidelineCard({
      required IconData icon,
      required String title,
      required String description,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'رجوع'.tr,
                    onPressed: widget.onBack,
                    icon: Icon(AppIcons.back, color: AppColors.icon),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'تعليمات التجربة الافتراضية'.tr,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            AppIcons.shieldTick,
                            color: AppColors.primary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'للحصول على أفضل نتيجة قبل البدء'.tr,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'تظهر هذه الإرشادات في المرة الأولى فقط لمساعدتك على الحصول على تجربة واقعية وسلسة.'
                                    .tr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildGuidelineCard(
                    icon: AppIcons.sun,
                    title: 'إضاءة قوية وواضحة'.tr,
                    description:
                        'قف في مكان بإضاءة أمامية قوية وموزعة جيداً، وتجنب العتمة أو وجود نافذة مضيئة خلفك.'
                            .tr,
                  ),
                  buildGuidelineCard(
                    icon: AppIcons.camera,
                    title: 'كاميرا نظيفة وثابتة'.tr,
                    description:
                        'امسح عدسة الكاميرا جيداً قبل البدء ليظهر الوجه وتفاصيل الملابس أو الإكسسوارات بوضوح.'
                            .tr,
                  ),
                  buildGuidelineCard(
                    icon: IconsaxPlusLinear.wifi,
                    title: 'إنترنت قوي ومستقر'.tr,
                    description:
                        'استخدم شبكة Wi-Fi سريعة أو بيانات جوال قوية (4G/5G) لضمان استقرار البث المباشر دون تقطيع.'
                            .tr,
                  ),
                  buildGuidelineCard(
                    icon: AppIcons.sparkles,
                    title: 'تفسير وتوضيح التجربة'.tr,
                    description:
                        'تعمل التجربة بالذكاء الاصطناعي لإعطائك تصوراً تقريبياً للقطعة على جسمك أو يدك؛ قد تختلف درجات الألوان أو التفاصيل الدقيقة قليلاً حسب الإضاءة. يتم إيقاف الجلسة تلقائياً عند الخروج.'
                            .tr,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          IconsaxPlusLinear.timer_1,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'مدة كل جلسة: ${widget.sessionDurationSeconds} ثانية · الحد اليومي: ${widget.dailyLimit} محاولات'
                                .tr,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      value: _accepted,
                      onChanged: (v) => setState(() => _accepted = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      checkColor: AppColors.onPrimary,
                      side: BorderSide(
                        color: AppColors.borderStrong,
                        width: 1.5,
                      ),
                      title: Text(
                        'أوافق على الشروط والتعليمات'.tr,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.surfaceAlt,
                      disabledForegroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _accepted ? widget.onContinue : null,
                    child: Text(
                      'التالي'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
