import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_design.dart';
import '../utils/app_haptics.dart';
import '../widgets/app_bottom_sheet.dart';
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

/// Manages the ChatGPT-style floating voice orb overlay at the bottom of the screen
/// (no bottom sheet, non-blocking, 60/120fps CustomPainter waveform).
class VoiceSearchFloatingOverlay {
  VoiceSearchFloatingOverlay._();

  static OverlayEntry? _activeEntry;
  static final ValueNotifier<bool> isActiveNotifier = ValueNotifier<bool>(
    false,
  );

  static bool get isActive => _activeEntry != null;

  static void show({
    required BuildContext context,
    required ValueChanged<String> onResult,
  }) {
    if (_activeEntry != null) {
      dismiss();
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ChatGptVoiceOrbOverlayWidget(
        onSubmit: (text) {
          dismiss();
          if (text.trim().isNotEmpty) {
            onResult(text.trim());
          }
        },
        onCancel: () {
          unawaited(VoiceSearchService.instance.cancelListening());
          dismiss();
        },
      ),
    );

    _activeEntry = entry;
    isActiveNotifier.value = true;
    overlay.insert(entry);
  }

  static void dismiss() {
    final entry = _activeEntry;
    _activeEntry = null;
    isActiveNotifier.value = false;
    try {
      entry?.remove();
    } catch (_) {}
  }
}

/// Legacy helper kept for backward compatibility if called anywhere else;
/// delegates to the floating overlay and resolves with the spoken string.
Future<String?> showVoiceSearchSheet(BuildContext context) {
  final completer = Completer<String?>();
  VoiceSearchFloatingOverlay.show(
    context: context,
    onResult: (text) {
      if (!completer.isCompleted) {
        completer.complete(text);
      }
    },
  );
  return completer.future;
}

/// Opens the visual search bottom sheet (Camera or Gallery), analyzes the
/// selected product image, and returns the [VisualSearchQuery].
Future<VisualSearchQuery?> showVisualSearchSheet(BuildContext context) {
  return AppBottomSheet.show<VisualSearchQuery>(
    context: context,
    child: const _VisualSearchSheetBody(),
  );
}

// =============================================================================
// ChatGPT-Style Floating Bottom Voice Orb & Real-Time Waveform Overlay
// =============================================================================

class _ChatGptVoiceOrbOverlayWidget extends StatefulWidget {
  const _ChatGptVoiceOrbOverlayWidget({
    required this.onSubmit,
    required this.onCancel,
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ChatGptVoiceOrbOverlayWidget> createState() =>
      _ChatGptVoiceOrbOverlayWidgetState();
}

class _ChatGptVoiceOrbOverlayWidgetState
    extends State<_ChatGptVoiceOrbOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  final ValueNotifier<double> _soundLevel = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _liveTranscript = ValueNotifier<String>('');
  final ValueNotifier<String?> _errorText = ValueNotifier<String?>(null);

  Timer? _silenceSubmitTimer;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginListening());
  }

  @override
  void dispose() {
    _silenceSubmitTimer?.cancel();
    _waveController.dispose();
    _soundLevel.dispose();
    _liveTranscript.dispose();
    _errorText.dispose();
    super.dispose();
  }

  Future<void> _beginListening() async {
    try {
      await VoiceSearchService.instance.startListening(
        onSoundLevelChange: (level) {
          // Normalize typical speech_to_text dB range (-2..10) into (0.0..1.0)
          final normalized = ((level + 2.0) / 10.0).clamp(0.05, 1.0);
          _soundLevel.value = normalized;
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              !_submitted &&
              _liveTranscript.value.trim().isNotEmpty) {
            _finishAndSubmit();
          }
        },
        onError: (err) {
          if (_liveTranscript.value.trim().isNotEmpty) {
            _finishAndSubmit();
          } else {
            _errorText.value = 'لم نتمكن من سماعك، حاول مرة أخرى'.tr;
            Future<void>.delayed(const Duration(milliseconds: 1500), () {
              if (mounted && !_submitted) {
                widget.onCancel();
              }
            });
          }
        },
        onResult: (text, isFinal) {
          _liveTranscript.value = text;
          _silenceSubmitTimer?.cancel();

          if (isFinal && text.trim().isNotEmpty) {
            _finishAndSubmit();
          } else if (text.trim().isNotEmpty) {
            // Auto-submit smoothly after 1.6s of silence once words are spoken
            _silenceSubmitTimer = Timer(
              const Duration(milliseconds: 1600),
              _finishAndSubmit,
            );
          }
        },
      );
    } catch (_) {
      _errorText.value = 'تأكد من منح صلاحية الميكروفون'.tr;
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (mounted && !_submitted) {
          widget.onCancel();
        }
      });
    }
  }

  void _finishAndSubmit() {
    if (_submitted) return;
    _submitted = true;
    _silenceSubmitTimer?.cancel();
    unawaited(VoiceSearchService.instance.stopListening());
    final cleaned = cleanVoiceSearchQuery(_liveTranscript.value);
    widget.onSubmit(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 16,
      right: 16,
      bottom: math.max(bottomInset + 84, 96),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live Speech Bubble (automatically detects RTL Arabic vs LTR English)
            ValueListenableBuilder<String?>(
              valueListenable: _errorText,
              builder: (context, err, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: _liveTranscript,
                  builder: (context, transcript, _) {
                    final display =
                        err ??
                        (transcript.isEmpty
                            ? 'تحدث الآن...'.tr
                            : transcript);
                    final isAr = isArabicSpeech(display);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: err != null
                              ? AppColors.error
                              : AppColors.primaryBorder,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Directionality(
                        textDirection: isAr
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: Text(
                          display,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: transcript.isEmpty
                                ? AppFont.medium
                                : AppFont.bold,
                            color: err != null
                                ? AppColors.error
                                : (transcript.isEmpty
                                      ? AppColors.textMuted
                                      : AppColors.text),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            // ChatGPT-style Floating Wave Orb + Quick Cancel Button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cancel (X) Circle
                GestureDetector(
                  onTap: AppHaptics.action(widget.onCancel),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderStrong),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      AppIcons.close,
                      size: 19,
                      color: AppColors.icon,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Main ChatGPT-style Animated Waveform Circle Orb
                RepaintBoundary(
                  child: GestureDetector(
                    onTap: AppHaptics.action(() {
                      if (_liveTranscript.value.trim().isNotEmpty) {
                        _finishAndSubmit();
                      } else {
                        widget.onCancel();
                      }
                    }),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _waveController,
                        _soundLevel,
                      ]),
                      builder: (context, _) {
                        final level = _soundLevel.value;
                        final haloScale = 1.0 + (level * 0.28);
                        return SizedBox(
                          width: 84,
                          height: 84,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: haloScale,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.38,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: CustomPaint(
                                  painter: _ChatGptWaveOrbPainter(
                                    phase: _waveController.value,
                                    amplitude: level,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// High-performance 60/120fps CustomPainter drawing the ChatGPT-style
/// fluid vertical voice bars inside the floating circle orb.
class _ChatGptWaveOrbPainter extends CustomPainter {
  const _ChatGptWaveOrbPainter({
    required this.phase,
    required this.amplitude,
    required this.color,
  });

  final double phase;
  final double amplitude;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const barCount = 5;
    const barWidth = 4.2;
    const spacing = 4.6;
    const totalWidth = (barCount * barWidth) + ((barCount - 1) * spacing);
    final startX = (size.width - totalWidth) / 2.0;
    final centerY = size.height / 2.0;

    // Envelope weights so center bars are taller like ChatGPT voice mode
    const weights = [0.48, 0.78, 1.0, 0.78, 0.48];
    final effectiveAmp = math.max(0.18, amplitude);

    for (var i = 0; i < barCount; i++) {
      final wave = math.sin((phase * 2 * math.pi) + (i * 0.95));
      final dynamicFactor = 0.35 + (0.65 * ((wave + 1.0) / 2.0));
      final barHeight =
          (8.0 + (22.0 * effectiveAmp * weights[i] * dynamicFactor)).clamp(
            6.0,
            30.0,
          );

      final left = startX + i * (barWidth + spacing);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(left + barWidth / 2.0, centerY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(99),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatGptWaveOrbPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color;
  }
}

// =============================================================================
// Visual Image Search Sheet (Camera / Gallery)
// =============================================================================

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
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 85,
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
                    icon: AppIcons.camera,
                    title: 'تصوير بالكاميرا'.tr,
                    subtitle: 'التقط صورة مباشرة للمنتج'.tr,
                    onTap: () => _pickAndAnalyze(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _VisualSourceCard(
                    icon: Icons.photo_library_outlined,
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
                child: Icon(icon, size: 25, color: AppColors.primaryDark),
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
