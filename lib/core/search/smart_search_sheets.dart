import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_design.dart';
import '../utils/app_haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import 'visual_search_service.dart';
import 'voice_search_service.dart';

/// Holds the most recent active [VisualSearchQuery] so product and catalog
/// filters can rank by visual histogram & color similarity, and show a thumbnail
/// chip in the search toolbar.
class ActiveVisualSearchStore {
  ActiveVisualSearchStore._();

  static final ActiveVisualSearchStore instance = ActiveVisualSearchStore._();

  final ValueNotifier<VisualSearchQuery?> currentQuery =
      ValueNotifier<VisualSearchQuery?>(null);

  void setQuery(VisualSearchQuery? query) {
    currentQuery.value = query;
  }

  void clear() {
    if (currentQuery.value != null) {
      currentQuery.value = null;
    }
  }
}

/// Opens the interactive voice search bottom sheet and returns the spoken query.
Future<String?> showVoiceSearchSheet(BuildContext context) {
  return AppBottomSheet.show<String>(
    context: context,
    child: const _VoiceSearchSheetBody(),
  );
}

/// Opens the visual search bottom sheet (Camera or Gallery), analyzes the
/// selected product image, and returns the [VisualSearchQuery].
Future<VisualSearchQuery?> showVisualSearchSheet(BuildContext context) {
  return AppBottomSheet.show<VisualSearchQuery>(
    context: context,
    child: const _VisualSearchSheetBody(),
  );
}

class _VoiceSearchSheetBody extends StatefulWidget {
  const _VoiceSearchSheetBody();

  @override
  State<_VoiceSearchSheetBody> createState() => _VoiceSearchSheetBodyState();
}

class _VoiceSearchSheetBodyState extends State<_VoiceSearchSheetBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  String _recognizedText = '';
  String _selectedLang = AppLang.isEn ? 'en' : 'ar';
  double _soundLevel = 0.0;
  bool _isListening = false;
  String? _errorMessage;
  bool _autoPopped = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    unawaited(VoiceSearchService.instance.stopListening());
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _errorMessage = null;
      _isListening = true;
    });

    try {
      await VoiceSearchService.instance.startListening(
        preferredLanguageCode: _selectedLang,
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() {
            _soundLevel = level.clamp(-2.0, 10.0);
          });
        },
        onResult: (text, isFinal) {
          if (!mounted) return;
          setState(() {
            _recognizedText = text;
            if (isFinal) {
              _isListening = false;
            }
          });
          if (isFinal && text.trim().isNotEmpty && !_autoPopped) {
            _autoPopped = true;
            Future<void>.delayed(const Duration(milliseconds: 350), () {
              if (mounted) {
                Navigator.of(context).pop(text.trim());
              }
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _errorMessage =
            'تعذر الوصول إلى الميكروفون. تأكد من منح صلاحية التسجيل الصوتي.'.tr;
      });
    }
  }

  Future<void> _toggleLanguage(String lang) async {
    if (_selectedLang == lang) return;
    await VoiceSearchService.instance.stopListening();
    if (!mounted) return;
    setState(() {
      _selectedLang = lang;
      _recognizedText = '';
    });
    await _startRecording();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetScaffold(
      title: 'البحث الصوتي الذكي'.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'تحدث باسم المنتج، اللون، المتجر، أو القسم'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Language selector pills
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LangChip(
                label: 'العربية',
                selected: _selectedLang == 'ar',
                onTap: () => _toggleLanguage('ar'),
              ),
              const SizedBox(width: AppSpacing.xs),
              _LangChip(
                label: 'English',
                selected: _selectedLang == 'en',
                onTap: () => _toggleLanguage('en'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Animated Microphone Wave Circle
          GestureDetector(
            onTap: AppHaptics.action(() {
              if (_isListening) {
                VoiceSearchService.instance.stopListening();
                setState(() => _isListening = false);
              } else {
                _startRecording();
              }
            }),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final boost = _isListening
                    ? (_pulseController.value * 14.0) +
                          (math.max(0.0, _soundLevel) * 1.8)
                    : 0.0;
                return SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isListening)
                        Container(
                          width: 88 + boost,
                          height: 88 + boost,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.14),
                          ),
                        ),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? AppColors.primary
                              : AppColors.surfaceAlt,
                          border: Border.all(
                            color: _isListening
                                ? AppColors.primaryDark
                                : AppColors.borderStrong,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          size: 34,
                          color: _isListening
                              ? AppColors.onPrimary
                              : AppColors.icon,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            _errorMessage ??
                (_isListening
                    ? 'جارٍ الاستماع... تكلم الآن'.tr
                    : 'اضغط على المايكروفون للتحدث'.tr),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: AppFont.semiBold,
              color: _errorMessage != null
                  ? AppColors.error
                  : (_isListening ? AppColors.primaryDark : AppColors.textMuted),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Live recognized text box
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              _recognizedText.isEmpty
                  ? 'مثال: "قميص رجالي أسود" أو "فستان سهرة بيج"'.tr
                  : _recognizedText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: _recognizedText.isEmpty
                    ? AppFont.regular
                    : AppFont.bold,
                color: _recognizedText.isEmpty
                    ? AppColors.textMuted
                    : AppColors.text,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'إلغاء'.tr,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'بحث الآن'.tr,
                  leading: Icon(AppIcons.search, size: 18),
                  onPressed: _recognizedText.trim().isEmpty
                      ? null
                      : () {
                          final cleaned = cleanVoiceSearchQuery(
                            _recognizedText,
                          );
                          Navigator.of(context).pop(cleaned);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: AppHaptics.action(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? AppColors.primaryBorder : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? AppFont.bold : AppFont.medium,
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _VisualSearchSheetBody extends StatefulWidget {
  const _VisualSearchSheetBody();

  @override
  State<_VisualSearchSheetBody> createState() => _VisualSearchSheetBodyState();
}

class _VisualSearchSheetBodyState extends State<_VisualSearchSheetBody> {
  final ImagePicker _picker = ImagePicker();
  bool _analyzing = false;
  String? _errorMessage;

  Future<void> _pickAndAnalyze(ImageSource source) async {
    setState(() {
      _analyzing = true;
      _errorMessage = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) {
        if (mounted) setState(() => _analyzing = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final result = await VisualSearchService.instance.analyzeImageBytes(
        bytes,
        fileNameHint: picked.name,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage =
            'تعذر فتح الكاميرا أو قراءة الصورة. تأكد من منح الصلاحيات المطلوبة.'
                .tr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetScaffold(
      title: 'البحث الذكي بالصورة'.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'صوّر المنتج بالكاميرا أو ارفع صورته من جهازك للعثور عليه أو على المنتجات المشابهة له'
                .tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_analyzing) ...[
            const SizedBox(height: AppSpacing.lg),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'جارٍ تحليل ألوان وتفاصيل المنتج في الصورة...'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.semiBold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.error,
                    fontWeight: AppFont.semiBold,
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: _VisualSourceCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'تصوير بالكاميرا'.tr,
                    subtitle: 'التقط صورة مباشرة للمنتج'.tr,
                    onTap: () => _pickAndAnalyze(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _VisualSourceCard(
                    icon: Icons.photo_library_rounded,
                    title: 'رفع من الهاتف'.tr,
                    subtitle: 'اختر صورة من المعرض'.tr,
                    onTap: () => _pickAndAnalyze(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VisualSourceCard extends StatelessWidget {
  const _VisualSourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: AppHaptics.action(onTap),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Icon(icon, size: 26, color: AppColors.primaryDark),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFont.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
