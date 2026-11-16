import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../router/routes.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  final VoidCallback? onFinished;

  /// Pre-decodes the initial onboarding screenshots into [ImageCache] so the
  /// first slide opens with zero decode jank.
  static Future<void> warmUpInitialSlides(BuildContext context) async {
    for (var i = 0; i < 2 && i < _customerSlides.length; i++) {
      if (!context.mounted) return;
      try {
        await precacheImage(AssetImage(_customerSlides[i].assetPath), context);
      } catch (_) {
        // Ignore decode errors during pre-warm; Image widget handles fallback.
      }
    }
  }

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _stepIndex = 0;
  late final PageController _pageController;
  bool _precacheStarted = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheStarted) {
      _precacheStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_precacheSlidesSequentially());
        }
      });
    }
  }

  Future<void> _precacheSlidesSequentially() async {
    for (var i = 0; i < _customerSlides.length; i++) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(_customerSlides[i].assetPath), context);
      } catch (_) {}
      // Yield between decodes so UI transitions stay responsive.
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_stepIndex < _customerSlides.length - 1) {
      await _pageController.nextPage(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    ref.read(onboardingCompletedProvider.notifier).state = true;
    unawaited(AppPreferences.setOnboardingCompleted(true));
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (auth.status == AuthStatus.authenticated) {
      if (context.canPop()) {
        context.pop();
      } else if (auth.user != null) {
        context.go(AppRoutes.homeForRole(auth.user!.role.name));
      } else {
        context.go(AppRoutes.login);
      }
      return;
    }
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isAuthenticated = auth.status == AuthStatus.authenticated;
    final isLast = _stepIndex == _customerSlides.length - 1;

    final primaryLabel = !isLast
        ? 'التالي'.tr
        : (isAuthenticated ? 'تم'.tr : 'ابدأ التسوق'.tr);

    return Scaffold(
      backgroundColor: AuthDesign.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AuthDesign.maxFormWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1) Top Bar: Logo + Skip/Close
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      const AppLogoMark(size: 30),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AuthDesign.subtitleColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: AppHaptics.action(_finish),
                        child: Text(
                          isAuthenticated ? 'إغلاق'.tr : 'تخطي'.tr,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: AppFont.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2) Customer Walkthrough Slides (isolated repaint layer for smooth paging)
                Expanded(
                  child: RepaintBoundary(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _customerSlides.length,
                      onPageChanged: (index) =>
                          setState(() => _stepIndex = index),
                      itemBuilder: (context, index) => _TourSlideBody(
                        key: ValueKey('customer_slide_$index'),
                        slide: _customerSlides[index],
                      ),
                    ),
                  ),
                ),

                // 3) Dots Indicator + Primary AppButton Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_customerSlides.length, (i) {
                          final active = i == _stepIndex;
                          return AnimatedContainer(
                            duration: AppMotion.fast,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : HomeDesign.bannerDotInactive,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(label: primaryLabel, onPressed: _nextStep),
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

class _PhoneSlideData {
  const _PhoneSlideData({
    required this.assetPath,
    required this.aspectRatio,
    required this.title,
    required this.description,
  });

  final String assetPath;
  final double aspectRatio;
  final String title;
  final String description;
}

const List<_PhoneSlideData> _customerSlides = [
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_login.png',
    aspectRatio: 491.0 / 931.0,
    title: 'تسجيل الدخول بجوجل',
    description: 'سجّل دخولك بسرعة وأمان عبر حساب Google أو بريدك الإلكتروني.',
  ),
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_home.png',
    aspectRatio: 509.0 / 969.0,
    title: 'تصفّح الأقسام في الرئيسية',
    description:
        'استكشف العروض والأقسام الرئيسية وابحث أو فلتر للوصول السريع للمنتجات.',
  ),
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_catalog.png',
    aspectRatio: 489.0 / 957.0,
    title: 'البحث وفلترة المنتجات',
    description:
        'انتقل لتبويب المنتجات وحدّد التصنيف أو السعر أو المتوفر فقط لعرض النتائج فوراً.',
  ),
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_product.png',
    aspectRatio: 447.0 / 891.0,
    title: 'اختيار القطعة والمقاس',
    description: 'اختر اللون والمقاس والكمية المناسبة ثم اضغط إضافة إلى السلة.',
  ),
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_cart.png',
    aspectRatio: 467.0 / 891.0,
    title: 'مراجعة سلة المشتريات',
    description:
        'تحقق من القطع والكميات والإجمالي النهائي ثم اضغط إتمام الشراء.',
  ),
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_checkout.png',
    aspectRatio: 485.0 / 939.0,
    title: 'تأكيد الطلب والدفع',
    description: 'أدخل رقم هاتف المستلم وطريقة الدفع ثم اضغط تأكيد الطلب الآن.',
  ),
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_confirmed.png',
    aspectRatio: 463.0 / 909.0,
    title: 'إتمام الطلب',
    description:
        'تظهر رسالة تأكيد الطلب ورقم التتبع للانتقال لمتابعة طلباتك — مثال توضيحي.',
  ),
  _PhoneSlideData(
    assetPath: 'assets/images/onboarding/customer_orders.png',
    aspectRatio: 491.0 / 937.0,
    title: 'متابعة الطلب والاستلام',
    description:
        'راقب حالة طلبك في «طلباتي» حتى تتحول إلى «تم التوصيل» — مثال توضيحي.',
  ),
];

class _TourSlideBody extends StatefulWidget {
  const _TourSlideBody({super.key, required this.slide});

  final _PhoneSlideData slide;

  @override
  State<_TourSlideBody> createState() => _TourSlideBodyState();
}

class _TourSlideBodyState extends State<_TourSlideBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _phoneSlide;
  late final Animation<double> _phoneFade;
  late final Animation<double> _phoneScale;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
    );
    _phoneSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _phoneFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
      ),
    );
    _phoneScale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.16, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.90, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _TourSlideBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slide != widget.slide) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 460;
        final phoneMaxH = (constraints.maxHeight - (compact ? 94 : 124)).clamp(
          150.0,
          520.0,
        );
        final availW = (constraints.maxWidth - AppSpacing.md * 2).clamp(
          80.0,
          340.0,
        );
        final frameH = math.min(
          phoneMaxH.clamp(120.0, 560.0),
          availW / widget.slide.aspectRatio,
        );
        final frameW = frameH * widget.slide.aspectRatio;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: phoneMaxH,
                child: Center(
                  child: FadeTransition(
                    opacity: _phoneFade,
                    child: SlideTransition(
                      position: _phoneSlide,
                      child: ScaleTransition(
                        scale: _phoneScale,
                        child: RepaintBoundary(
                          child: SizedBox(
                            width: frameW,
                            height: frameH,
                            child: Image.asset(
                              widget.slide.assetPath,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 12 : 20),
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.slide.title.tr,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 17.5 : 20,
                          fontWeight: AppFont.extraBold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          widget.slide.description.tr,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 12.5 : 14,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: compact ? 4 : 10),
            ],
          ),
        );
      },
    );
  }
}
