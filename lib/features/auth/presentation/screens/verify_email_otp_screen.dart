import 'dart:async';
import 'dart:math' as math;

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../router/routes.dart';
import '../providers/auth_provider.dart';

class VerifyEmailOtpScreen extends ConsumerStatefulWidget {
  const VerifyEmailOtpScreen({
    super.key,
    required this.email,
    this.isLogin = false,
  });

  final String email;
  final bool isLogin;

  @override
  ConsumerState<VerifyEmailOtpScreen> createState() =>
      _VerifyEmailOtpScreenState();
}

class _VerifyEmailOtpScreenState extends ConsumerState<VerifyEmailOtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;

  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shakeController;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 60;
  bool _resending = false;
  String? _inlineError;
  String _lastAutoSubmittedCode = '';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _focusNode.addListener(_onFocusChanged);
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _codeController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  void _onCodeChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > _otpLength
        ? digits.substring(0, _otpLength)
        : digits;

    if (clipped != _codeController.text) {
      _codeController.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
    }

    if (_inlineError != null) {
      setState(() => _inlineError = null);
    } else {
      setState(() {});
    }

    if (clipped.isNotEmpty) {
      AppHaptics.selection();
    }

    if (clipped.length < _otpLength) {
      _lastAutoSubmittedCode = '';
    } else if (clipped.length == _otpLength &&
        clipped != _lastAutoSubmittedCode) {
      _lastAutoSubmittedCode = clipped;
      unawaited(_verify());
    }
  }

  Future<void> _verify() async {
    if (ref.read(authControllerProvider).isBusy) return;
    final code = _codeController.text.trim();
    if (code.length < _otpLength) {
      AppHaptics.error();
      setState(() {
        _inlineError = 'أدخل رمز التحقق المكوّن من 6 أرقام'.tr;
      });
      _triggerShake();
      _focusNode.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _inlineError = null);

    final notifier = ref.read(authControllerProvider.notifier);
    final ok = widget.isLogin
        ? await notifier.verifyLoginOtp(email: widget.email, code: code)
        : await notifier.verifySignupOtp(email: widget.email, code: code);

    if (!mounted) return;
    if (!ok) {
      AppHaptics.error();
      final error =
          ref.read(authControllerProvider).errorMessage ??
          'رمز التحقق غير صحيح أو منتهي الصلاحية'.tr;
      setState(() => _inlineError = error);
      _triggerShake();
      _focusNode.requestFocus();
      return;
    }

    AppHaptics.success();
    showAppSnackBar(
      context,
      widget.isLogin
          ? 'تم تسجيل الدخول بنجاح'.tr
          : 'تم تأكيد بريدك الإلكتروني بنجاح'.tr,
    );
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0 || _resending) return;
    setState(() {
      _resending = true;
      _inlineError = null;
    });
    final notifier = ref.read(authControllerProvider.notifier);
    final ok = widget.isLogin
        ? await notifier.resendLoginOtp(email: widget.email)
        : await notifier.resendSignupOtp(email: widget.email);
    if (!mounted) return;
    setState(() => _resending = false);
    if (!ok) {
      AppHaptics.error();
      final error = ref.read(authControllerProvider).errorMessage;
      showAppSnackBar(
        context,
        error ?? 'تعذر إعادة إرسال رمز التحقق'.tr,
        isError: true,
      );
      return;
    }
    AppHaptics.success();
    _lastAutoSubmittedCode = '';
    _codeController.clear();
    _startCooldown();
    _focusNode.requestFocus();
    showAppSnackBar(
      context,
      'تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني'.tr,
    );
  }

  void _changeEmail() {
    ref.read(authControllerProvider.notifier).clearPendingSignup();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  String _formatCountdown(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canResend = _cooldownSeconds == 0 && !_resending && !auth.isBusy;
    final hasError = _inlineError != null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                widget.isLogin
                    ? 'تأكيد تسجيل الدخول'.tr
                    : 'تأكيد البريد الإلكتروني'.tr,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isLogin
                      ? 'تأكيد تسجيل الدخول'.tr
                      : 'تحقق من بريدك الإلكتروني'.tr,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: AppFont.extraBold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى بريدك الإلكتروني'
                      .tr,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    onTap: auth.isBusy
                        ? null
                        : AppHaptics.action(_changeEmail),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.email,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: AppFont.bold,
                                  color: AppColors.primary,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            AppIcons.edit,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // --- Compact 6 Individual OTP Boxes (native keyboard paste & autofill) ---
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 312),
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final progress = _shakeController.value;
                        final offset =
                            math.sin(progress * math.pi * 6) *
                            (1 - progress) *
                            8;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: _OtpCodeBoxes(
                        length: _otpLength,
                        controller: _codeController,
                        focusNode: _focusNode,
                        enabled: !auth.isBusy,
                        hasError: hasError,
                        onChanged: _onCodeChanged,
                        onSubmitted: _verify,
                      ),
                    ),
                  ),
                ),

                if (hasError) ...[
                  const SizedBox(height: 10),
                  Text(
                    _inlineError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: AppFont.semiBold,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                AppButton(
                  label: widget.isLogin
                      ? 'تأكيد الرمز وتسجيل الدخول'.tr
                      : 'تأكيد الرمز وإتمام التسجيل'.tr,
                  isLoading: auth.isBusy,
                  onPressed: _verify,
                ),
                const SizedBox(height: AppSpacing.sm),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        'لم يصلك الرمز؟'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_resending)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else if (_cooldownSeconds > 0)
                        Text(
                          '${'إعادة إرسال الرمز بعد'.tr} ${_formatCountdown(_cooldownSeconds)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: AppFont.semiBold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        )
                      else
                        TextButton(
                          onPressed: canResend
                              ? AppHaptics.action(_resend)
                              : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'إعادة إرسال الرمز'.tr,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: AppFont.bold,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact 6-box individual OTP input backed by a full-area transparent
/// [TextField] so native device keyboard clipboard paste, long-press paste,
/// OS one-time-code autofill, and backspace all work natively.
class _OtpCodeBoxes extends StatelessWidget {
  const _OtpCodeBoxes({
    required this.length,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final int length;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final hasFocus = focusNode.hasFocus;
    final activeIndex = text.length < length ? text.length : length - 1;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Visual 6 individual digit boxes (non-interactive layer below)
            IgnorePointer(
              child: Row(
                children: List.generate(length, (index) {
                  final isFilled = index < text.length;
                  final char = isFilled ? text[index] : '';
                  final isActive = enabled && hasFocus && index == activeIndex;
                  final showCursor = isActive && !isFilled;

                  final Color bgColor;
                  final Color borderColor;
                  final double borderWidth;

                  if (hasError) {
                    bgColor = AppColors.errorSoft;
                    borderColor = AppColors.error;
                    borderWidth = 1.4;
                  } else if (isActive) {
                    bgColor = AppColors.primarySoft;
                    borderColor = AppColors.primary;
                    borderWidth = 1.8;
                  } else if (isFilled) {
                    bgColor = AppColors.surface;
                    borderColor = AppColors.primaryBorder;
                    borderWidth = 1.3;
                  } else {
                    bgColor = AppColors.surfaceAlt;
                    borderColor = AppColors.borderStrong;
                    borderWidth = 1.0;
                  }

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 3.5,
                        right: index == length - 1 ? 0 : 3.5,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: borderColor,
                            width: borderWidth,
                          ),
                        ),
                        child: isFilled
                            ? Text(
                                char,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: AppFont.extraBold,
                                  color: hasError
                                      ? AppColors.error
                                      : AppColors.text,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              )
                            : showCursor
                            ? const _BlinkingCursor()
                            : const SizedBox.shrink(),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Full-area transparent native TextField so device keyboard clipboard
            // bar, OS autofill, long-press Paste, and tap-to-focus work natively.
            Positioned.fill(
              child: Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    cursorColor: Colors.transparent,
                    selectionColor: Colors.transparent,
                    selectionHandleColor: Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableInteractiveSelection: true,
                  showCursor: false,
                  cursorColor: Colors.transparent,
                  maxLength: length,
                  style: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 1,
                    height: 1,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(length),
                  ],
                  decoration: const InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => onSubmitted(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
