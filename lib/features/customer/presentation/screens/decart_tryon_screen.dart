import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decart_vton_flutter/decart_vton_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/decart_vton_sdk_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../virtual_tryon/presentation/tryon_preparation.dart';
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
  late DecartVtonSdkService _service;
  late DecartTryonNotifier _controller;
  bool _ready = false,
      _started = false,
      _showGarments = false,
      _showOriginal = false;
  bool _foreground = true;
  bool _switchingCamera = false;
  String? _rendererError;

  Timer? _snackHideTimer;
  Timer? _snackNextTimer;
  Timer? _lightingTipTimer;
  bool _showLightingTip = true;
  bool _snackVisible = false;
  bool _snackSyncScheduled = false;
  int _snackIndex = 0;
  _CameraAlert? _displayedAlert;
  List<_CameraAlert> _latestAlerts = const [];
  String _lastAlertKeySet = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = ref.read(decartVtonSdkServiceProvider(widget.productId));
    _controller = ref.read(decartTryonProvider(widget.productId).notifier);
    _service.isGenerating.addListener(_generationChanged);
    _service.connectionQuality.addListener(_generationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      // Preload product & catalog immediately for Step 1 (Interactive Body Zone Selector)
      unawaited(_controller.preloadCatalog());
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  void _generationChanged() {
    if (!mounted) return;
    if (_service.isGenerating.value &&
        _showLightingTip &&
        _lightingTipTimer == null) {
      _lightingTipTimer = Timer(const Duration(seconds: 12), () {
        if (!mounted) return;
        setState(() => _showLightingTip = false);
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera) return;
    setState(() => _switchingCamera = true);
    try {
      await _controller.switchCamera();
    } finally {
      if (mounted) setState(() => _switchingCamera = false);
    }
  }

  Future<void> _start() async {
    if (!mounted || !_foreground) return;
    setState(() {
      _started = true;
      _showLightingTip = true;
      _lightingTipTimer?.cancel();
      _lightingTipTimer = null;
      _showOriginal = false;
      _showGarments = false;
    });
    await _controller.start();
  }

  Future<void> _returnToBodyMap() async {
    _cancelSnackTimers();
    await _controller.suspend();
    if (!mounted) return;
    setState(() {
      _started = false;
      _showOriginal = false;
      _showGarments = false;
      _snackVisible = false;
      _displayedAlert = null;
      _latestAlerts = const [];
      _lastAlertKeySet = '';
    });
  }

  void _cancelSnackTimers() {
    _snackHideTimer?.cancel();
    _snackHideTimer = null;
    _snackNextTimer?.cancel();
    _snackNextTimer = null;
  }

  List<_CameraAlert> _collectCameraAlerts(
    DecartTryonState state, {
    required bool failed,
    required bool generating,
    required TryonBodyZone activeZone,
    required VtonConnectionQuality quality,
  }) {
    if (!_started && !failed) return const [];
    final alerts = <_CameraAlert>[];
    final seenKeys = <String>{};

    void addAlert(_CameraAlert alert) {
      if (seenKeys.add(alert.key)) alerts.add(alert);
    }

    if (failed) {
      final errMsg =
          state.errorMessage?.tr ??
          _rendererError ??
          'توقفت التجربة. يمكنك إعادة المحاولة الآن.'.tr;
      addAlert(
        _CameraAlert(
          key: 'fatal:$errMsg:${state.retryPending}',
          message: errMsg,
          icon: Icons.error_outline_rounded,
          accent: const Color(0xFFEF4444),
          canRetry: !state.retryPending,
        ),
      );
      if (state.retryPending) {
        addAlert(
          _CameraAlert(
            key: 'retry:${state.retryAttempt}',
            message:
                'جارٍ استئناف التجربة تلقائياً… (${state.retryAttempt}/3)'.tr,
            icon: Icons.refresh_rounded,
            accent: AppColors.primary,
          ),
        );
      }
      return alerts;
    }

    if (!state.isConnected) {
      addAlert(
        _CameraAlert(
          key: 'wait:connecting',
          message: 'انتظر لحظة، جارٍ تجهيز الإطلالة…'.tr,
          icon: Icons.auto_awesome_rounded,
          accent: AppColors.primary,
        ),
      );
      return alerts;
    }

    if (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty) {
      addAlert(
        _CameraAlert(
          key: 'session_err:${state.errorMessage}',
          message: state.errorMessage!.tr,
          icon: Icons.error_outline_rounded,
          accent: const Color(0xFFEF4444),
        ),
      );
    }

    if (!state.isUpdating && !_showOriginal && generating) {
      if (quality == VtonConnectionQuality.poor ||
          quality == VtonConnectionQuality.unusable) {
        addAlert(
          _CameraAlert(
            key: 'net_quality:${quality.name}',
            message: 'اتصال الإنترنت ضعيف حالياً؛ قد تقل دقة المعاينة مؤقتاً.'.tr,
            icon: Icons.wifi_tethering_error_rounded,
            accent: const Color(0xFFF59E0B),
          ),
        );
      }
      if (_showLightingTip) {
        addAlert(
          _CameraAlert(
            key: 'tip:lighting',
            message:
                'لثبات الوجه والجسم: قف في إضاءة أمامية واضحة دون ضوء خلفي قوي.'.tr,
            icon: Icons.wb_sunny_outlined,
            accent: const Color(0xFFF59E0B),
          ),
        );
        addAlert(
          _CameraAlert(
            key: 'tip:zone:${activeZone.name}',
            message: activeZone.framingInstruction.tr,
            icon: Icons.accessibility_new_rounded,
            accent: Color(activeZone.colorHex),
          ),
        );
      }
    }

    if (state.isUpdating) {
      addAlert(
        _CameraAlert(
          key: 'wait:updating',
          message: 'جارٍ تبديل القطعة…'.tr,
          icon: Icons.checkroom_rounded,
          accent: AppColors.primary,
        ),
      );
    } else if (!_showOriginal && !generating) {
      addAlert(
        _CameraAlert(
          key: 'live_warming',
          message: 'جارٍ تطبيق القطعة على جسمك…'.tr,
          icon: Icons.auto_awesome_rounded,
          accent: AppColors.primary,
        ),
      );
    }

    return alerts;
  }

  void _syncAlerts(List<_CameraAlert> alerts) {
    _latestAlerts = alerts;
    final keySet = alerts.map((e) => e.key).join('|');
    final changed = keySet != _lastAlertKeySet;
    _lastAlertKeySet = keySet;

    if (alerts.isEmpty) {
      if (_displayedAlert != null ||
          _snackVisible ||
          _snackHideTimer != null ||
          _snackNextTimer != null) {
        _scheduleSnackSync(() {
          if (!mounted || _latestAlerts.isNotEmpty) return;
          _cancelSnackTimers();
          setState(() {
            _snackVisible = false;
            _displayedAlert = null;
            _snackIndex = 0;
          });
        });
      }
      return;
    }

    final shouldInterruptImmediately =
        changed &&
        (_displayedAlert == null ||
            (alerts.first.canRetry && !(_displayedAlert?.canRetry ?? false)));

    if ((_snackHideTimer == null && _snackNextTimer == null) ||
        shouldInterruptImmediately) {
      _scheduleSnackSync(() {
        if (!mounted || _latestAlerts.isEmpty) return;
        _showAlertAt(0);
      });
    }
  }

  void _scheduleSnackSync(VoidCallback action) {
    if (_snackSyncScheduled) return;
    _snackSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snackSyncScheduled = false;
      action();
    });
  }

  void _showAlertAt(int index) {
    if (!mounted || _latestAlerts.isEmpty) return;
    _cancelSnackTimers();
    final safeIndex = index % _latestAlerts.length;
    setState(() {
      _snackIndex = safeIndex;
      _displayedAlert = _latestAlerts[safeIndex];
      _snackVisible = true;
    });
    _snackHideTimer = Timer(const Duration(seconds: 5), _onSnackFiveSeconds);
  }

  void _onSnackFiveSeconds() {
    _snackHideTimer = null;
    if (!mounted) return;
    final previousKey = _displayedAlert?.key;
    setState(() => _snackVisible = false);

    if (_latestAlerts.isEmpty) {
      _displayedAlert = null;
      return;
    }

    final nextIndex = (_snackIndex + 1) % _latestAlerts.length;
    final hasOtherAlert =
        _latestAlerts.length > 1 || _latestAlerts.first.key != previousKey;
    final pauseDuration = hasOtherAlert
        ? const Duration(milliseconds: 550)
        : const Duration(milliseconds: 1800);

    _snackNextTimer = Timer(pauseDuration, () {
      _snackNextTimer = null;
      if (!mounted || _latestAlerts.isEmpty) {
        if (mounted) setState(() => _displayedAlert = null);
        return;
      }
      _showAlertAt(nextIndex);
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
      backgroundColor: const Color(0xFF14171D),
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
      if (_ready && _started) unawaited(_controller.suspend());
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      if (_ready && _started) unawaited(_controller.resume());
    }
  }

  @override
  void dispose() {
    _cancelSnackTimers();
    WidgetsBinding.instance.removeObserver(this);
    _service.isGenerating.removeListener(_generationChanged);
    _service.connectionQuality.removeListener(_generationChanged);
    _lightingTipTimer?.cancel();
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
    final state = ref.watch(decartTryonProvider(widget.productId));
    final activeZone = state.effectiveZone;
    final failed =
        _rendererError != null ||
        state.status == DecartSessionStatus.error ||
        (_started && state.status == DecartSessionStatus.disconnected);
    final zoneColor = Color(activeZone.colorHex);
    final showOverlay =
        state.isConnected &&
        !_showOriginal &&
        !_switchingCamera &&
        _foreground &&
        !failed;

    final alerts = _collectCameraAlerts(
      state,
      failed: failed,
      generating: _service.isGenerating.value,
      activeZone: activeZone,
      quality: _service.connectionQuality.value,
    );
    _syncAlerts(alerts);

    if (!_started && !failed) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'رجوع'.tr,
                      onPressed: () => context.pop(),
                      icon: Icon(AppIcons.back),
                    ),
                    Expanded(
                      child: Text(
                        'تجربة الملابس'.tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
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
        !state.isUpdating &&
        !failed &&
        state.availableProducts.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
            // 1) Edge-to-Edge Full-Screen Native Decart VTON Stream
            if (_ready && isVtonNativePlatformSupported)
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Colors.black),
                    VtonLocalPreview(
                      fit: VtonVideoFit.cover,
                      mirror: state.isFrontCamera,
                    ),
                    AnimatedOpacity(
                      opacity: showOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: const IgnorePointer(
                        child: VtonRemoteView(fit: VtonVideoFit.cover),
                      ),
                    ),
                  ],
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

            // 2) Minimal Floating Top Controls over Camera
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _CameraFloatingCircleButton(
                        icon: AppIcons.back,
                        tooltip: 'رجوع'.tr,
                        onTap: () {
                          if (_started) {
                            unawaited(_returnToBodyMap());
                          } else {
                            context.pop();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Material(
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
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: zoneColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  activeZone.shortLabel.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
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
                      const Spacer(),
                      if (state.isConnected) ...[
                        Material(
                          color: Colors.black.withValues(alpha: 0.48),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () =>
                                setState(() => _showOriginal = !_showOriginal),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showOriginal
                                        ? AppIcons.garment
                                        : AppIcons.compare,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _showOriginal
                                        ? 'عرض القطعة'.tr
                                        : 'الصورة الأصلية'.tr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CameraFloatingCircleButton(
                          icon: AppIcons.garment,
                          tooltip: 'اختيار قطعة'.tr,
                          active: _showGarments,
                          onTap: state.isUpdating
                              ? null
                              : () => setState(
                                  () => _showGarments = !_showGarments,
                                ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_ready) ...[
                        _CameraFloatingCircleButton(
                          icon: Icons.wb_sunny_outlined,
                          tooltip: 'نصائح الإضاءة والوضعية'.tr,
                          onTap: () =>
                              _openLightingTipsSheet(context, activeZone),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_ready)
                        _CameraFloatingCircleButton(
                          icon: Icons.cameraswitch_rounded,
                          tooltip: 'تبديل الكاميرا'.tr,
                          onTap: _switchingCamera || state.isUpdating
                              ? null
                              : _switchCamera,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 3) Bottom Floating 5-Second Auto-Rotating SnackBar + Optional Garment Dock
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_displayedAlert != null)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: showGarmentDock ? 10 : 0,
                          ),
                          child: _CameraStatusSnackBar(
                            alert: _displayedAlert!,
                            visible: _snackVisible,
                            onRetry: _displayedAlert!.canRetry
                                ? _controller.retry
                                : null,
                          ),
                        ),
                      if (showGarmentDock) _garmentDock(state),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _garmentDock(DecartTryonState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.availableProducts.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) =>
              _garmentTile(state.availableProducts[i], state),
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
        onTap: () => _controller.selectGarment(product),
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

class _CameraAlert {
  const _CameraAlert({
    required this.key,
    required this.message,
    required this.icon,
    required this.accent,
    this.canRetry = false,
  });

  final String key;
  final String message;
  final IconData icon;
  final Color accent;
  final bool canRetry;
}

class _CameraFloatingCircleButton extends StatelessWidget {
  const _CameraFloatingCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppColors.primary.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.48),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 19,
              color: onTap == null ? Colors.white38 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraStatusSnackBar extends StatelessWidget {
  const _CameraStatusSnackBar({
    required this.alert,
    required this.visible,
    this.onRetry,
  });

  final _CameraAlert alert;
  final bool visible;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible || onRetry == null,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.35),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 240),
          opacity: visible ? 1.0 : 0.0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Container(
              key: ValueKey(alert.key),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xE011161F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: alert.accent.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: alert.accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(alert.icon, size: 17, color: alert.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: alert.accent.withValues(alpha: 0.25),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onRetry,
                      child: Text(
                        'إعادة'.tr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
