import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/offline/network_monitor_service.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'onboarding_screen.dart';

final splashCompletedProvider = StateProvider<bool>((ref) => false);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 520);

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  Timer? _completionTimer;
  bool _warmedAssets = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _entranceDuration,
    );

    // Start gently visible (0.42 -> 1.0) so there is zero blank flash on launch.
    _logoOpacity = Tween<double>(begin: 0.42, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _logoScale = Tween<double>(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutQuart),
      ),
    );

    _controller.forward().whenComplete(_markSplashDone);

    // Guaranteed fallback if OS animations are disabled (animator_duration_scale=0).
    _completionTimer = Timer(
      const Duration(milliseconds: 580),
      _markSplashDone,
    );

    // Check internet immediately and restore session in parallel with the
    // short entrance animation so both offline & online launches enter right away.
    unawaited(_bootstrapFromSplash());
  }

  Future<void> _bootstrapFromSplash() async {
    final hasInterface =
        await NetworkMonitorService.instance.hasNetworkInterface();
    if (!hasInterface) {
      NetworkMonitorService.instance.reportNetworkFailure();
    } else {
      // Non-blocking reachability probe so dead Wi-Fi is detected quickly
      // without ever delaying entry past the splash animation.
      unawaited(
        NetworkMonitorService.instance
            .checkNow(force: true)
            .timeout(const Duration(seconds: 2), onTimeout: () => false),
      );
    }

    if (!mounted) return;
    await ref.read(authControllerProvider.notifier).restoreSession();
  }

  void _markSplashDone() {
    if (_completed || !mounted) return;
    _completed = true;
    _completionTimer?.cancel();
    ref.read(splashCompletedProvider.notifier).state = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_warmedAssets) {
      _warmedAssets = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!ref.read(onboardingCompletedProvider)) {
          unawaited(OnboardingScreen.warmUpInitialSlides(context));
        }
      });
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SplashDesign.background,
      body: SafeArea(
        child: Center(
          child: RepaintBoundary(
            child: FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: _logoScale,
                child: const AppLogoMark(size: SplashDesign.logoSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
