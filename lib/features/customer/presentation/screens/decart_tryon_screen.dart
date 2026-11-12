import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/decart_realtime_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../virtual_tryon/data/capture_guard.dart';
import '../../../virtual_tryon/domain/capture_quality.dart';
import '../../../virtual_tryon/domain/remote_frame_gate.dart';
import '../../../virtual_tryon/presentation/remote_video_binding.dart';
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
  final _renderer = RTCVideoRenderer();
  final _localRenderer = RTCVideoRenderer();
  final _remoteFrames = RemoteFrameGate<MediaStream>();
  late final Future<void> _rendererInitialization;
  late DecartRealtimeService _service;
  late DecartTryonNotifier _controller;
  late CaptureGuardController _guard;
  RemoteVideoBinding? _videoBinding;
  bool _ready = false,
      _started = false,
      _showGarments = false,
      _showOriginal = false;
  bool _foreground = true;
  String? _rendererError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rendererInitialization = Future.wait([
      _renderer.initialize(),
      _localRenderer.initialize(),
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await _rendererInitialization;
      if (!mounted) return;
      _localRenderer.addListener(_rendererChanged);
      _renderer.addListener(_rendererChanged);
      _service = ref.read(decartRealtimeServiceProvider(widget.productId));
      _controller = ref.read(decartTryonProvider(widget.productId).notifier);
      _guard = ref.read(captureGuardProvider(widget.productId));
      _guard.addListener(_bindLocal);
      _videoBinding = RemoteVideoBinding(_renderer, () {
        if (mounted) {
          _remoteFrames.markRendered(_renderer.srcObject);
          _guard.outputStream = _remoteFrames.readyStream;
          _service.notifyFirstRemoteFrame();
        }
      });
      _service.onRemoteStream = (stream) {
        _remoteFrames.attach(stream);
        _guard.outputStream = null;
        if (mounted) _videoBinding?.attach(stream);
      };
      setState(() => _ready = true);
      if (_foreground) unawaited(_start());
    } catch (_) {
      if (mounted) {
        setState(() => _rendererError = 'تعذر تهيئة الكاميرا على هذا الجهاز.');
      }
    }
  }

  void _bindLocal() {
    if (mounted && _guard.approved) {
      _guard.outputStream = _remoteFrames.readyStream;
    }
    if (mounted && _localRenderer.srcObject != _guard.stream) {
      _localRenderer.srcObject = _guard.stream;
    }
  }

  void _rendererChanged() {
    if (mounted) setState(() {});
  }

  double get _captureAspect =>
      _localRenderer.videoHeight > 0 && _localRenderer.videoWidth > 0
      ? _localRenderer.videoWidth / _localRenderer.videoHeight
      : 9 / 16;

  Future<void> _start() async {
    if (!_ready || !mounted || !_foreground) return;
    setState(() {
      _started = true;
      _showOriginal = false;
      _showGarments = false;
    });
    await _controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      if (_ready) unawaited(_controller.suspend());
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      if (_ready) unawaited(_started ? _controller.resume() : _start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localRenderer.removeListener(_rendererChanged);
    _renderer.removeListener(_rendererChanged);
    if (_ready) {
      _guard.removeListener(_bindLocal);
      _service.onRemoteStream = null;
      _remoteFrames.attach(null);
      _videoBinding?.attach(null);
      _videoBinding?.dispose();
      _localRenderer.srcObject = null;
      unawaited(_controller.suspend());
    }
    unawaited(
      _rendererInitialization
          .then((_) async {
            await _renderer.dispose();
            await _localRenderer.dispose();
          })
          .catchError((Object _) {}),
    );
    unawaited(SystemChrome.setPreferredOrientations([]));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(decartTryonProvider(widget.productId));
    final guard = ref.watch(captureGuardProvider(widget.productId));
    final step = !_started
        ? 0
        : guard.approved
        ? 2
        : 1;
    final failed =
        _rendererError != null ||
        state.status == DecartSessionStatus.error ||
        state.status == DecartSessionStatus.disconnected;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'رجوع',
                    onPressed: () => context.pop(),
                    icon: const Icon(AppIcons.back),
                  ),
                  Expanded(
                    child: Text(
                      'غرفة التجربة',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            TryonSteps(current: step),
            Expanded(
              child: !_started && !failed
                  ? const TryonIntroduction()
                  : LayoutBuilder(
                      builder: (context, constraints) => Column(
                        children: [
                          Expanded(
                            child: Container(
                              color: const Color(0xFF111111),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (_ready)
                                    RTCVideoView(
                                      _localRenderer,
                                      mirror: false,
                                      objectFit: RTCVideoViewObjectFit
                                          .RTCVideoViewObjectFitContain,
                                    ),
                                  if (_ready)
                                    ClipPath(
                                      clipper: GarmentRegionClipper(
                                        points: guard.assessment.points,
                                        aspect: _captureAspect,
                                        region: guard.garment?.region ?? '',
                                        enabled:
                                            guard.approved &&
                                            guard.outputAligned &&
                                            guard.canApprove &&
                                            state.isConnected &&
                                            !state.isUpdating &&
                                            !_showOriginal &&
                                            _matchingFrames(guard),
                                      ),
                                      child: RTCVideoView(
                                        _renderer,
                                        mirror: false,
                                        objectFit: RTCVideoViewObjectFit
                                            .RTCVideoViewObjectFitContain,
                                      ),
                                    ),
                                  if (!guard.approved &&
                                      guard.analyzing &&
                                      !failed)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: BodyGuidePainter(
                                          guard.assessment.points,
                                          _captureAspect,
                                          region:
                                              guard.garment?.region ??
                                              'upper body garment',
                                        ),
                                      ),
                                    ),
                                  if (guard.approved && state.isConnected)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () => setState(
                                          () => _showOriginal = !_showOriginal,
                                        ),
                                        icon: Icon(
                                          _showOriginal
                                              ? AppIcons.garment
                                              : AppIcons.compare,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _showOriginal
                                              ? 'عرض القطعة'
                                              : 'الصورة الأصلية',
                                        ),
                                      ),
                                    ),
                                  if (failed)
                                    Center(
                                      child: _errorPanel(
                                        state,
                                        state.errorMessage ??
                                            guard.error ??
                                            _rendererError ??
                                            'توقفت التجربة. أعد فحص الجسم للمتابعة.',
                                      ),
                                    ),
                                  if (!failed &&
                                      (!guard.analyzing || guard.approved) &&
                                      !state.isConnected)
                                    const Center(
                                      child: Card(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: AppBusyLabel(
                                            label: 'جارٍ تجهيز التجربة…',
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * .52,
                            ),
                            child: SingleChildScrollView(
                              child: failed
                                  ? const SizedBox.shrink()
                                  : !guard.approved && guard.analyzing
                                  ? CaptureChecklist(
                                      assessment: guard.assessment,
                                      region:
                                          guard.garment?.region ??
                                          'upper body garment',
                                    )
                                  : _garments(state, guard),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchingFrames(CaptureGuardController guard) {
    final frame = guard.observation;
    if (frame == null ||
        _renderer.videoWidth <= 0 ||
        _renderer.videoHeight <= 0) {
      return false;
    }
    final sourceAspect = frame.width / frame.height;
    return (_captureAspect / sourceAspect - 1).abs() < .035 &&
        ((_renderer.videoWidth / _renderer.videoHeight) / sourceAspect - 1)
                .abs() <
            .035;
  }

  Widget _errorPanel(
    DecartTryonState state,
    String message,
  ) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.focus,
              size: 36,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (state.retryPending)
              AppBusyLabel(
                label: 'جارٍ استئناف الفحص تلقائياً… (${state.retryAttempt}/3)',
              )
            else if (state.retryAttempt >= 3)
              const Text(
                'لم نتمكن من استئناف التجربة تلقائياً. تحقق من السبب أعلاه ثم ادخل غرفة التجربة مجدداً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.gray500),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _garments(
    DecartTryonState state,
    CaptureGuardController guard,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              AppIcons.shieldTick,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _showOriginal
                    ? 'صورتك الأصلية'
                    : 'المعالجة في منطقة القطعة فقط',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'اختيار قطعة',
              onPressed: state.isConnected && !state.isUpdating
                  ? () => setState(() => _showGarments = !_showGarments)
                  : null,
              icon: Icon(
                _showGarments ? AppIcons.chevronDown : AppIcons.garment,
              ),
            ),
          ],
        ),
        Text(
          state.selectedProduct?.name ?? 'قطعتك',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'معاينة للشكل، وليست توصية بمقاس الشراء.',
          style: TextStyle(fontSize: 11, color: AppColors.gray500),
        ),
        if (state.isConnected && !_matchingFrames(guard))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'أبعاد الفيديو المعالج لا تطابق الكاميرا. أُخفيت القطعة للحفاظ على موضع الجسم.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (state.isUpdating) const AppBusyLabel(label: 'جارٍ تطبيق القطعة…'),
        if (state.isConnected &&
            guard.approved &&
            !guard.outputAligned &&
            !state.isUpdating)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              guard.assessment.issue?.message ??
                  'جارٍ مطابقة القطعة مع وضعيتك…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (state.errorMessage != null)
          Text(state.errorMessage!, textAlign: TextAlign.center),
        if (_showGarments && state.isConnected && !state.isUpdating)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.availableProducts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) =>
                    _garmentTile(state.availableProducts[i], state),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _garmentTile(CustomerProduct product, DecartTryonState state) {
    final selected = state.selectedProduct?.id == product.id;
    return Semantics(
      button: true,
      selected: selected,
      label: product.name,
      child: InkWell(
        onTap: () {
          setState(() => _showGarments = false);
          _controller.selectGarment(product);
        },
        child: Container(
          width: 82,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: .06)
                : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: AppNetworkImage(
                  product.tryonReferenceImage!,
                  fit: BoxFit.contain,
                  cacheWidth: 192,
                  errorBuilder: (_, _, _) => const Icon(AppIcons.garment),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
