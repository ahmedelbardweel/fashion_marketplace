import 'dart:async';
import 'dart:io' as io;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decart_vton_flutter/decart_vton_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/supabase_config.dart';
import '../../../../core/network/tryon_bandwidth_guard.dart';
import '../../../../core/services/decart_vton_sdk_service.dart';
import '../../../../core/services/vidu_tryon_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../virtual_tryon/data/decart_session_config.dart';
import '../../../virtual_tryon/data/tryon_onboarding_store.dart';
import '../../../virtual_tryon/domain/tryon_quota.dart';
import '../../../virtual_tryon/presentation/tryon_guidelines_view.dart';
import '../../../virtual_tryon/presentation/tryon_preparation.dart';
import '../../../virtual_tryon/presentation/tryon_quota_provider.dart';
import '../../domain/models/customer_product.dart';
import '../providers/decart_tryon_provider.dart';

class DecartTryonScreen extends ConsumerStatefulWidget {
  const DecartTryonScreen({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<DecartTryonScreen> createState() => _DecartTryonScreenState();
}

class _DecartTryonScreenState extends ConsumerState<DecartTryonScreen>
    with WidgetsBindingObserver {
  static const int _warmupDurationSeconds = 10;
  static const List<double> _zoomPresets = [0.5, 1.0, 1.5, 2.0];
  static const MethodChannel _soundChannel = MethodChannel(
    'fashion/tryon_sound',
  );
  static const MethodChannel _brightnessChannel = MethodChannel(
    'fashion/screen_brightness',
  );

  DecartVtonSdkService? _decartService;
  ViduLiveTryonSession? _viduService;
  TryonProvider _boundProvider = TryonProvider.decart;
  bool _listenersBound = false;

  DecartTryonNotifier get _controller =>
      ref.read(decartTryonProvider(widget.productId).notifier);

  bool get _isVidu => _viduService != null;
  ValueNotifier<bool> get _isGeneratingListenable =>
      _viduService?.isGenerating ?? _decartService!.isGenerating;
  ValueNotifier<VtonConnectionQuality> get _qualityListenable =>
      _viduService?.connectionQuality ?? _decartService!.connectionQuality;
  ValueNotifier<DecartSessionConfig?> get _sessionConfigListenable =>
      _viduService?.sessionConfig ?? _decartService!.sessionConfig;

  void _unbindServiceListeners() {
    if (!_listenersBound) return;
    _listenersBound = false;
    _isGeneratingListenable.removeListener(_generationChanged);
    _qualityListenable.removeListener(_generationChanged);
    _sessionConfigListenable.removeListener(_configChanged);
  }

  void _bindProvider(TryonProvider provider) {
    if (_listenersBound && _boundProvider == provider) return;
    _unbindServiceListeners();
    _boundProvider = provider;
    if (provider == TryonProvider.vidu) {
      _viduService = ref.read(viduLiveTryonSessionProvider(widget.productId));
      _decartService = null;
    } else {
      _decartService = ref.read(decartVtonSdkServiceProvider(widget.productId));
      _viduService = null;
    }
    _isGeneratingListenable.addListener(_generationChanged);
    _qualityListenable.addListener(_generationChanged);
    _sessionConfigListenable.addListener(_configChanged);
    _listenersBound = true;
  }
  bool _ready = false,
      _started = false,
      _showGarments = false,
      _showOtherProductsInDock = false,
      _showOriginal = false;
  bool _foreground = true;
  bool _checkingGuidelines = true;
  bool _guidelinesAccepted = false;
  TryonQuota _quota = const TryonQuota();
  Timer? _countdownTimer;
  Timer? _warmupTimer;
  final ValueNotifier<int> _warmupSecondsNotifier = ValueNotifier<int>(
    _warmupDurationSeconds,
  );
  final ValueNotifier<int> _remainingSecondsNotifier = ValueNotifier<int>(30);
  final ValueNotifier<double> _zoomNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> _switchingCameraNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<double> _cameraFlipTurnsNotifier = ValueNotifier<double>(
    0.0,
  );
  bool _warmupActive = false;
  bool _ringLightEnabled = false;
  bool _hasConnectedInSession = false;
  bool _networkFocusAcquired = false;
  bool _isPinching = false;
  bool _lastGenerating = false;
  bool _lastQualityPoor = false;
  double _pinchBaseZoom = 1.0;
  bool _sessionTimedOut = false;
  String? _rendererError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final activeProvider =
        ref.read(tryonQuotaProvider).valueOrNull?.activeProvider ??
        TryonProvider.decart;
    _bindProvider(activeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    var accepted = false;
    try {
      // Default to Data Saver, then run a single 0-byte latency check BEFORE
      // Try-On starts (never during live streaming) to auto-select the best mode.
      unawaited(
        TryonNetworkFocus.instance.autoDetectBandwidthMode(
          resetManualOverride: true,
        ),
      );
      // Preload product & catalog immediately for Step 1 (Interactive Body Zone Selector)
      unawaited(
        _controller.preloadCatalog().then((_) {
          if (!mounted) return;
          final refUrl = ref
              .read(decartTryonProvider(widget.productId))
              .effectiveImageUrl;
          if (_isVidu) {
            unawaited(_viduService!.prewarmGarmentImage(refUrl));
          } else {
            unawaited(_decartService!.prewarmGarmentImage(refUrl));
          }
        }),
      );
      final uid = ref.read(authControllerProvider).user?.id ?? 'guest';
      accepted = await TryonOnboardingStore.hasAccepted(uid);
      unawaited(_loadQuota());
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (!mounted) return;
      setState(() {
        _guidelinesAccepted = accepted;
        _checkingGuidelines = false;
        _ready = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
        _guidelinesAccepted = accepted;
        _checkingGuidelines = false;
        _ready = true;
      });
      }
    }
  }

  void _configChanged() {
    if (!mounted) return;
    final cfg = _sessionConfigListenable.value;
    if (cfg == null) return;
    setState(() {
      _quota = _quota.copyWith(
        enabled: true,
        activeProvider: cfg.model.toLowerCase().startsWith('vidu')
            ? TryonProvider.vidu
            : _quota.activeProvider,
        sessionDurationSeconds: cfg.sessionDurationSeconds,
        dailyLimit: cfg.dailyLimit,
        usedToday: cfg.usedToday,
        remainingToday:
            cfg.remainingToday ??
            (cfg.dailyLimit - cfg.usedToday).clamp(0, cfg.dailyLimit),
        clearBlockReasonOverride: true,
      );
      if (_countdownTimer == null) {
        _remainingSecondsNotifier.value = cfg.sessionDurationSeconds;
      }
    });
  }

  Future<void> _loadQuota() async {
    try {
      final data = await SupabaseConfig.client.rpc('get_my_tryon_quota');
      if (!mounted || data is! Map) return;
      final loaded = TryonQuota.fromMap(Map<String, dynamic>.from(data));
      ref.read(tryonQuotaProvider.notifier).updateFromQuota(loaded);
      setState(() {
        _quota = loaded;
        if (_countdownTimer == null && !_started) {
          _remainingSecondsNotifier.value = loaded.sessionDurationSeconds;
        }
      });
    } catch (_) {
      // Graceful fallback when migration 019 is not yet deployed or offline.
    }
  }

  Future<void> _acceptGuidelines() async {
    final uid = ref.read(authControllerProvider).user?.id ?? 'guest';
    await TryonOnboardingStore.markAccepted(uid);
    if (!mounted) return;
    setState(() => _guidelinesAccepted = true);
  }

  void _startCountdown() {
    if (_countdownTimer != null || _sessionTimedOut) return;
    final total = _sessionConfigListenable.value?.sessionDurationSeconds ??
        _quota.sessionDurationSeconds;
    _remainingSecondsNotifier.value = total;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _remainingSecondsNotifier.value;
      if (current <= 1) {
        timer.cancel();
        _countdownTimer = null;
        _handleSessionTimeout();
      } else {
        // ValueNotifier updates ONLY the tiny countdown pill — zero full-screen rebuilds!
        _remainingSecondsNotifier.value = current - 1;
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _playCountdownCue({bool finish = false}) {
    if (finish) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    unawaited(
      _soundChannel.invokeMethod<void>(finish ? 'go' : 'tick').catchError((_) {
        unawaited(SystemSound.play(SystemSoundType.click));
      }),
    );
  }

  void _startWarmup() {
    _warmupTimer?.cancel();
    _warmupSecondsNotifier.value = _warmupDurationSeconds;
    _warmupActive = true;
    _playCountdownCue();
    _warmupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _warmupSecondsNotifier.value;
      if (current <= 1) {
        timer.cancel();
        _warmupTimer = null;
        _warmupSecondsNotifier.value = 0;
        _playCountdownCue(finish: true);
        setState(() => _warmupActive = false);
      } else {
        // ValueNotifier updates ONLY the centered digit — zero PlatformView rebuilds!
        _warmupSecondsNotifier.value = current - 1;
        _playCountdownCue();
      }
    });
  }

  void _stopWarmup() {
    _warmupTimer?.cancel();
    _warmupTimer = null;
    _warmupSecondsNotifier.value = 0;
    if (_warmupActive && mounted) {
      setState(() => _warmupActive = false);
    } else {
      _warmupActive = false;
    }
  }

  void _acquireNetworkFocus() {
    if (_networkFocusAcquired) return;
    _networkFocusAcquired = true;
    final user = ref.read(authControllerProvider).user;
    TryonNetworkFocus.instance.acquire(
      userId: user?.id,
      userRole: user?.role.name,
    );
  }

  void _releaseNetworkFocus() {
    if (!_networkFocusAcquired) return;
    _networkFocusAcquired = false;
    TryonNetworkFocus.instance.release();
  }

  void _toggleRingLight() {
    HapticFeedback.selectionClick();
    final next = !_ringLightEnabled;
    setState(() => _ringLightEnabled = next);
    unawaited(
      _brightnessChannel
          .invokeMethod<void>(next ? 'setMax' : 'restore')
          .catchError((_) {}),
    );
  }

  void _disableRingLight({bool updateUi = true}) {
    if (!_ringLightEnabled) return;
    if (updateUi && mounted) {
      setState(() => _ringLightEnabled = false);
    } else {
      _ringLightEnabled = false;
    }
    unawaited(
      _brightnessChannel.invokeMethod<void>('restore').catchError((_) {}),
    );
  }

  void _stopAndExitToProduct() {
    HapticFeedback.lightImpact();
    _warmupTimer?.cancel();
    _warmupTimer = null;
    _warmupActive = false;
    _warmupSecondsNotifier.value = 0;
    _stopCountdown();
    // Pop IMMEDIATELY (0ms UI latency) before tearing down native WebRTC/camera
    // and resuming background network services so the route transition stays 60fps.
    if (mounted) {
      context.pop();
    }
    final controller = _controller;
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (controller.mounted) {
        unawaited(controller.suspend());
      }
      _releaseNetworkFocus();
    });
  }

  void _handleSessionTimeout() {
    _releaseNetworkFocus();
    unawaited(_controller.suspend());
    unawaited(_loadQuota());
    if (!mounted) return;
    _remainingSecondsNotifier.value = 0;
    setState(() {
      _sessionTimedOut = true;
      _showGarments = false;
    });
  }

  String _formatCountdown(int seconds) {
    final clamped = seconds.clamp(0, 3599);
    final mins = (clamped ~/ 60).toString().padLeft(2, '0');
    final secs = (clamped % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _generationChanged() {
    if (!mounted) return;
    final generating = _isGeneratingListenable.value;
    final quality = _qualityListenable.value;
    final isPoor =
        quality == VtonConnectionQuality.poor ||
        quality == VtonConnectionQuality.unusable;

    // Only rebuild when generating or poor-connection state actually flips
    // (ignores high-frequency identical WebRTC telemetry ticks).
    if (generating != _lastGenerating || isPoor != _lastQualityPoor) {
      _lastGenerating = generating;
      _lastQualityPoor = isPoor;
      setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (_switchingCameraNotifier.value) return;
    HapticFeedback.selectionClick();
    _switchingCameraNotifier.value = true;
    _cameraFlipTurnsNotifier.value += 0.5;
    try {
      await _controller.switchCamera();
    } finally {
      if (mounted) _switchingCameraNotifier.value = false;
    }
  }

  Future<void> _start() async {
    if (!mounted || !_foreground) return;
    if (!_quota.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إيقاف خدمة التجربة الافتراضية مؤقتاً من قبل الإدارة.'.tr,
          ),
        ),
      );
      return;
    }
    if (!_quota.hasRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'استنفدت محاولاتك اليومية للتجربة (${_quota.dailyLimit} محاولات). يمكنك التجربة مجدداً غداً.'
                .tr,
          ),
        ),
      );
      return;
    }
    _stopCountdown();
    if (!mounted || !_foreground) return;
    _acquireNetworkFocus();
    _remainingSecondsNotifier.value = _quota.sessionDurationSeconds;
    _zoomNotifier.value = 1.0;
    setState(() {
      _started = true;
      _hasConnectedInSession = false;
      _sessionTimedOut = false;
      _showOriginal = false;
      _showGarments = false;
    });
    _startWarmup();
    await _controller.start();
  }

  void _returnToBodyMap() {
    HapticFeedback.lightImpact();
    _warmupTimer?.cancel();
    _warmupTimer = null;
    _warmupSecondsNotifier.value = 0;
    _stopCountdown();
    _zoomNotifier.value = 1.0;

    // Switch back to the Body Map IMMEDIATELY on this frame (0ms delay),
    // never blocking the UI on native WebRTC/Camera2 disconnect.
    if (mounted) {
      setState(() {
        _started = false;
        _warmupActive = false;
        _hasConnectedInSession = false;
        _sessionTimedOut = false;
        _showOriginal = false;
        _showGarments = false;
      });
    } else {
      _warmupActive = false;
    }

    // Tear down the native stream asynchronously right after the UI switches,
    // and defer background sync/quota refresh so the transition has zero lag.
    unawaited(_controller.suspend());
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      _releaseNetworkFocus();
      if (mounted && !_started) {
        unawaited(_loadQuota());
      }
    });
  }

  void _openBodyZoneModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final currentState = ref.watch(decartTryonProvider(widget.productId));
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.55,
            maxChildSize: 0.92,
            builder: (context, _) => Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: InteractiveBodyZoneSelector(
                    measurementProfileId:
                        ref.watch(authControllerProvider).user?.id ?? 'guest',
                    selectedZone: currentState.effectiveZone,
                    selectedProduct: currentState.selectedProduct,
                    availableProducts: currentState.availableProducts,
                    onZoneSelected: (zone) {
                      _controller.selectBodyZone(zone);
                    },
                    onProductSelected: (product) {
                      _controller.selectGarment(product);
                    },
                    onContinue: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openLightingTipsSheet(BuildContext context, TryonBodyZone activeZone) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final zoneColor = Color(activeZone.colorHex);
        Widget tipRow(IconData icon, Color accent, String title, String body) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'نصائح لأفضل ثبات للوجه والجسم'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'هذه الإرشادات لتحسين دقة المعاينة ولا توقف البث المباشر.'.tr,
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                tipRow(
                  Icons.wb_sunny_outlined,
                  const Color(0xFFF59E0B),
                  'إضاءة أمامية متوازنة'.tr,
                  'لثبات الوجه والجسم: قف في إضاءة أمامية واضحة دون ضوء خلفي قوي.'.tr,
                ),
                tipRow(
                  Icons.accessibility_new_rounded,
                  zoneColor,
                  activeZone.shortLabel.tr,
                  activeZone.framingInstruction.tr,
                ),
                tipRow(
                  Icons.face_retouching_natural_rounded,
                  AppColors.primary,
                  'ثبات الوضعية والاتصال'.tr,
                  'تجنب الحركة السريعة واستخدم شبكة إنترنت مستقرة لنتيجة أدق.'.tr,
                ),
                const SizedBox(height: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text('حسناً'.tr),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _disableRingLight();
      _stopWarmup();
      _stopCountdown();
      _releaseNetworkFocus();
      if (_ready && _started) {
        unawaited(_controller.suspend());
        if (mounted) {
          setState(() {
            _started = false;
            _hasConnectedInSession = false;
            _showGarments = false;
            _showOriginal = false;
            _sessionTimedOut = false;
          });
        }
      }
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      unawaited(_loadQuota());
    }
  }

  @override
  void dispose() {
    _disableRingLight(updateUi: false);
    _warmupTimer?.cancel();
    _releaseNetworkFocus();
    WidgetsBinding.instance.removeObserver(this);
    _unbindServiceListeners();
    _stopCountdown();
    _warmupSecondsNotifier.dispose();
    _remainingSecondsNotifier.dispose();
    _zoomNotifier.dispose();
    _switchingCameraNotifier.dispose();
    _cameraFlipTurnsNotifier.dispose();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (_ready) {
      final controller = _controller;
      Future(() {
        if (controller.mounted) {
          unawaited(controller.suspend());
        }
      });
    }
    unawaited(SystemChrome.setPreferredOrientations([]));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeProvider = ref.watch(
      tryonQuotaProvider.select(
        (q) => q.valueOrNull?.activeProvider ?? TryonProvider.decart,
      ),
    );
    _bindProvider(activeProvider);
    final state = ref.watch(decartTryonProvider(widget.productId));
    if (state.isConnected) {
      _hasConnectedInSession = true;
    }
    final activeZone = state.effectiveZone;
    final rawFailed =
        !_sessionTimedOut &&
        (_rendererError != null ||
            state.status == DecartSessionStatus.error ||
            (_started &&
                _hasConnectedInSession &&
                state.status == DecartSessionStatus.disconnected));
    // Never flash transient error banners while the 10s warm-up countdown is
    // actively handshaking or auto-recovering.
    final failed = rawFailed && !(_warmupActive && state.retryPending);
    final zoneColor = Color(activeZone.colorHex);
    final showOverlay =
        state.isConnected &&
        !_warmupActive &&
        !_showOriginal &&
        _foreground &&
        !failed;

    // Only surface a calm, steady app-style snackbar when an unrecoverable state
    // stops the session — never expose internal vendor/billing/key details.
    final fatalNotice = (failed && !state.retryPending)
        ? _buildFriendlyNotice(state.errorMessage ?? _rendererError)
        : null;

    if (fatalNotice != null && _warmupActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopWarmup());
    }

    final quality = _qualityListenable.value;
    final isPoorSignal =
        quality == VtonConnectionQuality.poor ||
        quality == VtonConnectionQuality.unusable;

    if (state.isConnected &&
        _started &&
        !_warmupActive &&
        !_sessionTimedOut &&
        !failed) {
      if (_countdownTimer == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _started && !_warmupActive && !_sessionTimedOut) {
            _startCountdown();
          }
        });
      }
    } else if (!_started || failed || _sessionTimedOut) {
      _stopCountdown();
    }

    if (_checkingGuidelines) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: AppSkeleton(
            enabled: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_guidelinesAccepted) {
      return TryonGuidelinesView(
        sessionDurationSeconds: _quota.sessionDurationSeconds,
        dailyLimit: _quota.dailyLimit,
        onBack: () => context.pop(),
        onContinue: _acceptGuidelines,
      );
    }

    if (!_started && !failed) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'رجوع'.tr,
                      onPressed: () => context.pop(),
                      icon: Icon(AppIcons.back, color: AppColors.icon),
                    ),
                    Expanded(
                      child: Text(
                        'تجربة الملابس'.tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تعليمات التجربة الافتراضية'.tr,
                      onPressed: () =>
                          setState(() => _guidelinesAccepted = false),
                      icon: Icon(AppIcons.info, color: AppColors.icon),
                    ),
                  ],
                ),
              ),
              _buildQuotaBanner(),
              Expanded(
                child: InteractiveBodyZoneSelector(
                  measurementProfileId:
                      ref.watch(authControllerProvider).user?.id ?? 'guest',
                  selectedZone: activeZone,
                  selectedProduct: state.selectedProduct,
                  availableProducts: state.availableProducts,
                  onZoneSelected: _controller.selectBodyZone,
                  onProductSelected: _controller.selectGarment,
                  onContinue: _start,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final showGarmentDock =
        state.isConnected &&
        _showGarments &&
        !failed &&
        (state.availableProducts.isNotEmpty ||
            (state.selectedProduct?.tryonReferenceImages.isNotEmpty ?? false));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_started) {
          _returnToBodyMap();
        } else {
          context.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1) Isolated Native Decart VTON Stream with Zero-Rebuild Pinch/Preset Zoom
            if (_ready && isVtonNativePlatformSupported)
              Positioned.fill(
                child: RepaintBoundary(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: (_) {
                      _isPinching = true;
                      _pinchBaseZoom = _zoomNotifier.value;
                    },
                    onScaleEnd: (_) => _isPinching = false,
                    onScaleUpdate: (details) {
                      if (details.pointerCount < 2) return;
                      final next = (_pinchBaseZoom * details.scale).clamp(
                        0.5,
                        2.5,
                      );
                      if ((next - _zoomNotifier.value).abs() > 0.015) {
                        _zoomNotifier.value = next;
                      }
                    },
                    child: ClipRect(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _zoomNotifier,
                        builder: (context, zoom, _) {
                          final wide = zoom <= 0.65;
                          final fit = wide
                              ? VtonVideoFit.contain
                              : VtonVideoFit.cover;
                          return AnimatedScale(
                            scale: wide ? 1.0 : zoom,
                            duration: _isPinching
                                ? Duration.zero
                                : const Duration(milliseconds: 140),
                            curve: Curves.easeOutCubic,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(color: Colors.black),
                                if (_isVidu && !kIsWeb && io.Platform.isAndroid)
                                  const AndroidView(
                                    viewType: 'fashion/vidu_rtc_view',
                                    creationParamsCodec: StandardMessageCodec(),
                                  )
                                else if (_isVidu && !kIsWeb && io.Platform.isIOS)
                                  const UiKitView(
                                    viewType: 'fashion/vidu_rtc_view',
                                    creationParamsCodec: StandardMessageCodec(),
                                  )
                                else ...[
                                  VtonLocalPreview(
                                    fit: fit,
                                    mirror: state.isFrontCamera,
                                  ),
                                  // Exact 1.0 / 0.0 Opacity skips offscreen saveLayer
                                  // allocation on Android Hybrid Composition PlatformViews.
                                  Opacity(
                                    opacity: showOverlay ? 1.0 : 0.0,
                                    child: IgnorePointer(
                                      child: VtonRemoteView(fit: fit),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              )
            else if (_ready)
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'التجربة المباشرة بتقنية Lucy VTON متاحة على هواتف أندرويد وآيفون فقط.'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            // 1.4) Full-Screen Studio Border Ring Light Overlay (auto max brightness)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _ringLightEnabled ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: const _ScreenRingLightOverlay(),
                ),
              ),
            ),

            // 1.5) Lightweight Frosted Blur + Giant Centered 10s Countdown
            // Mounted ONLY while warming up so zero blur/ImageReader cost remains live.
            if (_started && _warmupActive && !_sessionTimedOut && !failed)
              Positioned.fill(
                child: RepaintBoundary(child: _buildWarmupOverlay()),
              ),

            // Subtle top gradient so floating controls & status bar stay crisp
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.50),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2) Clean, Zero-Overflow Floating Top Controls over Camera
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.48),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () => _openBodyZoneModal(context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: zoneColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        activeZone.shortLabel.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.tune_rounded,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_ready)
                        _CameraFloatingCircleButton(
                          icon: _ringLightEnabled
                              ? Icons.wb_sunny_rounded
                              : Icons.wb_sunny_outlined,
                          active: _ringLightEnabled,
                          tooltip: _ringLightEnabled
                              ? 'إيقاف إضاءة الشاشة'.tr
                              : 'تشغيل إضاءة الشاشة (سطوع أقصى)'.tr,
                          onTap: _toggleRingLight,
                          onLongPress: () =>
                              _openLightingTipsSheet(context, activeZone),
                        ),
                    ],
                  ),
                ),
              ),
              ),
            ),

            // 2.5) Calm Compact Top Center Status & Timer Pill (zero noisy popups)
            if (_started && !_warmupActive && !_sessionTimedOut && !failed)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 58,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: Center(
                      child: state.isConnected
                          ? ValueListenableBuilder<int>(
                              valueListenable: _remainingSecondsNotifier,
                              builder: (context, remaining, _) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: (remaining <= 5
                                          ? const Color(0xFFEF4444)
                                          : remaining <= 10
                                          ? const Color(0xFFF59E0B)
                                          : Colors.black)
                                      .withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _formatCountdown(remaining),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    if (state.isUpdating) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'جارٍ التبديل…'.tr,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ] else if (isPoorSignal) ...[
                                      const SizedBox(width: 7),
                                      const Icon(
                                        Icons.wifi_rounded,
                                        size: 13,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: _isVidu
                                  ? ValueListenableBuilder<String>(
                                      valueListenable:
                                          _viduService!.stageMessage,
                                      builder: (context, stageText, _) => Text(
                                        stageText.trim().isNotEmpty
                                            ? stageText
                                            : 'جارٍ تجهيز الإطلالة…'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'جارٍ تجهيز الإطلالة…'.tr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                    ),
                  ),
                ),
              ),

            // 2.7) Session Time Ended Overlay
            if (_sessionTimedOut)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.82),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF262626),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.timer_off_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'انتهى وقت الجلسة'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'انتهت مدة التجربة المحددة (${_quota.sessionDurationSeconds} ثانية). تم إغلاق الكاميرا تلقائياً.'
                                .tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'المتبقي لك اليوم: ${_quota.remainingToday} من ${_quota.dailyLimit} محاولات'
                                .tr,
                            style: TextStyle(
                              color: _quota.hasRemaining
                                  ? AppColors.primary
                                  : const Color(0xFFEF4444),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.24,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _returnToBodyMap,
                                  child: Text('العودة'.tr),
                                ),
                              ),
                              if (_quota.hasRemaining) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _start,
                                    child: Text('محاولة جديدة'.tr),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 3) Bottom Floating Alerts + Garment Dock + Zoom Control + Stop Try-On Bar
            if (!_warmupActive && !_sessionTimedOut)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RepaintBoundary(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (fatalNotice != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CameraStatusSnackBar(
                                message: fatalNotice.message,
                                onRetry: fatalNotice.canRetry
                                    ? _controller.retry
                                    : null,
                              ),
                            ),
                          if (showGarmentDock) ...[
                            _garmentDock(state),
                            const SizedBox(height: 10),
                          ],
                          if (_ready && !failed) ...[
                            _buildZoomAndFlipRow(state),
                            const SizedBox(height: 10),
                          ],
                          _buildBottomActionBar(state),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  _CameraNotice _buildFriendlyNotice(String? rawMessage) {
    final raw = (rawMessage ?? '').trim();
    final lower = raw.toLowerCase();

    // Never expose internal provider names, API keys, credits, or billing to customers.
    final isDailyOrServiceCap =
        lower.contains('decart') ||
        lower.contains('lucy') ||
        lower.contains('credit') ||
        lower.contains('balance') ||
        lower.contains('billing') ||
        lower.contains('quota') ||
        lower.contains('402') ||
        raw.contains('نفد رصيد') ||
        raw.contains('مفتاح') ||
        raw.contains('الاشتراك') ||
        raw.contains('شحن الرصيد') ||
        raw.contains('محاولاتك اليومية') ||
        raw.contains('إيقاف خدمة') ||
        raw.contains('غير مهيأة') ||
        raw.contains('غير متوفرة');

    if (isDailyOrServiceCap) {
      return _CameraNotice(
        message: 'انتهت جلسات التجربة المتاحة لليوم، نراك مجدداً قريباً.'.tr,
        canRetry: false,
      );
    }

    if (raw.contains('الكاميرا') || lower.contains('camera')) {
      return _CameraNotice(
        message: raw.isNotEmpty
            ? raw.tr
            : 'يرجى السماح بالوصول إلى الكاميرا ثم إعادة المحاولة.'.tr,
        canRetry: true,
      );
    }

    return _CameraNotice(
      message: 'تعذر إكمال البث حالياً، تحقق من الإنترنت وجرّب مجدداً.'.tr,
      canRetry: true,
    );
  }

  Widget _buildWarmupOverlay() {
    return ClipRect(
      child: BackdropFilter(
        // sigma 7 delivers smooth frosted glass at ~7x lower GPU memory bandwidth
        // than sigma 18 over Android Hybrid Composition PlatformViews.
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          color: Colors.black.withValues(alpha: 0.34),
          alignment: Alignment.center,
          child: ValueListenableBuilder<int>(
            valueListenable: _warmupSecondsNotifier,
            builder: (context, seconds, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.78, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              ),
              child: Text(
                '$seconds',
                key: ValueKey(seconds),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 124,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
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

  Widget _buildZoomAndFlipRow(DecartTryonState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildZoomControlPill(),
        const SizedBox(width: 10),
        ValueListenableBuilder<bool>(
          valueListenable: _switchingCameraNotifier,
          builder: (context, switching, _) {
            final disabled = switching || state.isUpdating;
            return Tooltip(
              message: 'تبديل الكاميرا'.tr,
              child: Material(
                color: Colors.black.withValues(alpha: 0.56),
                shape: CircleBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: disabled ? null : _switchCamera,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _cameraFlipTurnsNotifier,
                        builder: (context, turns, _) => AnimatedRotation(
                          turns: turns,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.cameraswitch_rounded,
                            size: 19,
                            color: disabled ? Colors.white38 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildZoomControlPill() {
    String formatZoom(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}x' : '${v.toStringAsFixed(1)}x';

    return ValueListenableBuilder<double>(
      valueListenable: _zoomNotifier,
      builder: (context, zoom, _) {
        bool isPresetSelected(double preset) => (zoom - preset).abs() < 0.18;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final preset in _zoomPresets) ...[
                GestureDetector(
                  onTap: () {
                    _isPinching = false;
                    _zoomNotifier.value = preset;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isPresetSelected(preset)
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      formatZoom(preset),
                      style: TextStyle(
                        color: isPresetSelected(preset)
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 11.5,
                        fontWeight: isPresetSelected(preset)
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar(DecartTryonState state) {
    final canInteract = state.isConnected && !state.isUpdating;
    final hasVariants =
        (state.selectedProduct?.tryonReferenceImages.length ?? 0) > 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          // Hanger / Colors & Garments Toggle
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: canInteract
                  ? () => setState(() => _showGarments = !_showGarments)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _showGarments
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.garment,
                      size: 16,
                      color: canInteract ? Colors.white : Colors.white38,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        hasVariants ? 'ألوان القطعة'.tr : 'القطع'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: canInteract ? Colors.white : Colors.white38,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Prominent Stop Try-On Button -> Exits straight to Product Details
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _stopAndExitToProduct,
              icon: const Icon(Icons.stop_circle_rounded, size: 18),
              label: Text(
                'إيقاف التجربة'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Compare / Original Camera Toggle
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: state.isConnected
                  ? () {
                      final next = !_showOriginal;
                      setState(() => _showOriginal = next);
                      if (_isVidu) {
                        unawaited(_viduService!.setShowOriginal(next));
                      }
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _showOriginal
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showOriginal ? AppIcons.garment : AppIcons.compare,
                      size: 16,
                      color: state.isConnected ? Colors.white : Colors.white38,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _showOriginal ? 'القطعة'.tr : 'الأصلية'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: state.isConnected
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaBanner() {
    final blocked = _quota.isBlocked;
    final color = blocked ? AppColors.error : AppColors.primary;
    final text = blocked
        ? (_quota.friendlyBlockedMessage ??
                  'ميزة تجربة الملابس الافتراضية متوقفة مؤقتاً من قبل الإدارة. يرجى المحاولة لاحقاً.')
              .tr
        : 'متبقي ${_quota.remainingToday} من ${_quota.dailyLimit} محاولات اليوم · ${_quota.sessionDurationSeconds} ثانية'
              .tr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              blocked ? Icons.block_rounded : IconsaxPlusLinear.timer_1,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: blocked ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TryonBandwidthMode>(
              valueListenable: TryonNetworkFocus.instance.bandwidthMode,
              builder: (context, mode, _) {
                final isSaver = mode == TryonBandwidthMode.dataSaver;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final next = isSaver
                        ? TryonBandwidthMode.highQuality
                        : TryonBandwidthMode.dataSaver;
                    TryonNetworkFocus.instance.setManualBandwidthMode(next);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          IconsaxPlusLinear.wifi,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSaver ? 'توفير النت'.tr : 'جودة عالية'.tr,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _garmentDock(DecartTryonState state) {
    final product = state.selectedProduct;
    final variantImages = product?.tryonReferenceImages ?? const <String>[];
    final hasMultipleVariants = variantImages.length > 1;
    final hasOtherProducts = state.availableProducts.length > 1;
    final showVariants = hasMultipleVariants && !_showOtherProductsInDock;

    return IgnorePointer(
      ignoring: state.isUpdating,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: state.isUpdating ? 0.65 : 1.0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasMultipleVariants) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        showVariants
                            ? '${'ألوان وصور القطعة'.tr} (${variantImages.length})'
                            : '${'قطع أخرى للتجربة'.tr} (${state.availableProducts.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasOtherProducts)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _dockModeChip(
                              label: 'ألوان القطعة'.tr,
                              selected: showVariants,
                              onTap: () => setState(
                                () => _showOtherProductsInDock = false,
                              ),
                            ),
                            _dockModeChip(
                              label: 'قطع أخرى'.tr,
                              selected: !showVariants,
                              onTap: () => setState(
                                () => _showOtherProductsInDock = true,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: showVariants ? 84 : 92,
                child: showVariants
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: variantImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _productImageVariantTile(
                          imageUrl: variantImages[i],
                          index: i,
                          product: product!,
                          state: state,
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.availableProducts.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) =>
                            _garmentTile(state.availableProducts[i], state),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dockModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _productImageVariantTile({
    required String imageUrl,
    required int index,
    required CustomerProduct product,
    required DecartTryonState state,
  }) {
    final selected = state.effectiveImageUrl == imageUrl;
    final colors = product.availableColors.toList();
    final label = index < colors.length
        ? colors[index].tr
        : (AppLang.isEn ? 'Style ${index + 1}' : 'خيار ${index + 1}');
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _controller.selectGarmentImage(imageUrl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 78,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.white : Colors.white30,
              width: selected ? 2.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppNetworkImage(
                    imageUrl,
                    fit: BoxFit.contain,
                    cacheWidth: 192,
                    errorBuilder: (_, _, _) => const Icon(
                      AppIcons.garment,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _garmentTile(CustomerProduct product, DecartTryonState state) {
    final selected = state.selectedProduct?.id == product.id;
    final itemZone = TryonBodyZone.infer(product.name, product.categoryName);
    final tileColor = Color(itemZone.colorHex);
    return Semantics(
      button: true,
      selected: selected,
      label: product.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _controller.selectGarment(product);
          if (product.tryonReferenceImages.length > 1) {
            setState(() => _showOtherProductsInDock = false);
          }
        },
        child: Container(
          width: 80,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? tileColor.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tileColor : Colors.white.withValues(alpha: 0.16),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AppNetworkImage(
                        product.tryonReferenceImage!,
                        fit: BoxFit.contain,
                        cacheWidth: 192,
                        errorBuilder: (_, _, _) => const Icon(
                          AppIcons.garment,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tileColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraNotice {
  const _CameraNotice({
    required this.message,
    this.canRetry = false,
  });

  final String message;
  final bool canRetry;
}

class _CameraFloatingCircleButton extends StatelessWidget {
  const _CameraFloatingCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onLongPress,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.94)
            : Colors.black.withValues(alpha: 0.48),
        shape: CircleBorder(
          side: BorderSide(
            color: active
                ? const Color(0xFFFDE68A)
                : Colors.white.withValues(alpha: 0.16),
            width: active ? 1.8 : 1.0,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 19,
              color: onTap == null
                  ? Colors.white38
                  : active
                  ? const Color(0xFFD97706)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Luminous border-perimeter studio fill light that surrounds the entire screen
/// edge to illuminate the user's face and outfit in dim environments.
class _ScreenRingLightOverlay extends StatelessWidget {
  const _ScreenRingLightOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScreenRingLightPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ScreenRingLightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const innerCornerRadius = Radius.circular(36);
    const frameThickness = 22.0;

    // Crisp pure-white frame around all four edges of the screen with zero inner shadow.
    final outer = Path()..addRect(rect);
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(frameThickness),
          innerCornerRadius,
        ),
      );
    final framePath = Path.combine(PathOperation.difference, outer, inner);
    final framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(framePath, framePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Minimal, steady app-standard SnackBar without icons or blinking animations.
class _CameraStatusSnackBar extends StatelessWidget {
  const _CameraStatusSnackBar({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: SnackBarDesign.background,
        borderRadius: BorderRadius.circular(SnackBarDesign.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: SnackBarDesign.text,
                fontSize: 13,
                fontWeight: AppFont.semiBold,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRetry,
              child: Text(
                'إعادة'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
