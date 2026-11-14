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
      _showGarments = true,
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
      // Preload product & catalog for Step 1 (Interactive Body Zone Selector)
      unawaited(_controller.preloadCatalog());
    } catch (_) {
      if (mounted) {
        setState(
          () => _rendererError = 'تعذر تهيئة الكاميرا على هذا الجهاز.'.tr,
        );
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

  Future<void> _start() async {
    if (!_ready || !mounted || !_foreground) return;
    setState(() {
      _started = true;
      _showOriginal = false;
      _showGarments = true;
    });
    await _controller.start();
  }

  Future<void> _returnToBodyMap() async {
    await _controller.suspend();
    if (!mounted) return;
    setState(() {
      _started = false;
      _showOriginal = false;
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
                    selectedZone: currentState.selectedZone,
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
      final controller = _controller;
      Future(() {
        if (controller.mounted) {
          unawaited(controller.suspend());
        }
      });
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
        (_started && state.status == DecartSessionStatus.disconnected);
    final zoneColor = Color(state.selectedZone.colorHex);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'رجوع'.tr,
                    onPressed: () {
                      if (_started) {
                        unawaited(_returnToBodyMap());
                      } else {
                        context.pop();
                      }
                    },
                    icon: Icon(AppIcons.back),
                  ),
                  Expanded(
                    child: Text(
                      'غرفة التجربة الذكية'.tr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_started)
                    IconButton(
                      tooltip: 'تغيير مكان اللبس'.tr,
                      onPressed: () => _openBodyZoneModal(context),
                      icon: Icon(
                        Icons.accessibility_new_rounded,
                        color: zoneColor,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            TryonSteps(current: step),

            // Main Stage Area
            Expanded(
              child: !_started && !failed
                  ? InteractiveBodyZoneSelector(
                      selectedZone: state.selectedZone,
                      selectedProduct: state.selectedProduct,
                      availableProducts: state.availableProducts,
                      onZoneSelected: _controller.selectBodyZone,
                      onProductSelected: _controller.selectGarment,
                      onContinue: _start,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => Column(
                        children: [
                          Expanded(
                            child: Container(
                              color: const Color(0xFF0B0F19),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // 1. Base Local Camera Stream
                                  if (_ready)
                                    RTCVideoView(
                                      _localRenderer,
                                      mirror: state.isFrontCamera,
                                      objectFit: RTCVideoViewObjectFit
                                          .RTCVideoViewObjectFitCover,
                                    ),

                                  // 2. Processed Decart Remote Try-On Stream (Full Fidelity)
                                  if (_ready)
                                    AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      opacity:
                                          state.isConnected && !_showOriginal
                                          ? 1.0
                                          : 0.0,
                                      child: IgnorePointer(
                                        ignoring:
                                            !state.isConnected || _showOriginal,
                                        child: RTCVideoView(
                                          _renderer,
                                          mirror: false,
                                          objectFit: RTCVideoViewObjectFit
                                              .RTCVideoViewObjectFitCover,
                                        ),
                                      ),
                                    ),

                                  // 3. Stage 2 Zone-Colored Framing Overlay (Lighting Check only)
                                  if (!guard.approved &&
                                      guard.analyzing &&
                                      !failed)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: ZoneFramedGuidePainter(
                                          zone: state.selectedZone,
                                        ),
                                      ),
                                    ),

                                  // 4. Top Live Controls (Zone Pill + Compare + Camera Switch)
                                  if (!failed)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      right: 12,
                                      child: Row(
                                        children: [
                                          // Active Body Zone Badge (Tappable)
                                          Material(
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              onTap: () =>
                                                  _openBodyZoneModal(context),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 7,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: zoneColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 7),
                                                    Text(
                                                      state
                                                          .selectedZone
                                                          .shortLabel,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                            FilledButton.tonalIcon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.black
                                                    .withValues(alpha: 0.65),
                                                foregroundColor: Colors.white,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              onPressed: () => setState(
                                                () => _showOriginal =
                                                    !_showOriginal,
                                              ),
                                              icon: Icon(
                                                _showOriginal
                                                    ? AppIcons.garment
                                                    : AppIcons.compare,
                                                size: 16,
                                              ),
                                              label: Text(
                                                _showOriginal
                                                    ? 'عرض القطعة'.tr
                                                    : 'الصورة الأصلية'.tr,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton.filledTonal(
                                              style: IconButton.styleFrom(
                                                backgroundColor: Colors.black
                                                    .withValues(alpha: 0.65),
                                                foregroundColor: Colors.white,
                                              ),
                                              tooltip: 'تبديل الكاميرا'.tr,
                                              onPressed:
                                                  _controller.switchCamera,
                                              icon: const Icon(
                                                Icons.cameraswitch_rounded,
                                                size: 19,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                  // 5. Error Panel
                                  if (failed)
                                    Center(
                                      child: _errorPanel(
                                        state,
                                        state.errorMessage ??
                                            guard.error ??
                                            _rendererError ??
                                            'توقفت التجربة. يمكنك إعادة المحاولة الآن.'
                                                .tr,
                                      ),
                                    ),

                                  // 6. Connecting Indicator after Lighting Approved
                                  if (!failed &&
                                      (!guard.analyzing || guard.approved) &&
                                      !state.isConnected)
                                    Center(
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 18,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AppBusyLabel(
                                                label:
                                                    'جارٍ تركيب القطعة على (${state.selectedZone.shortLabel}) بنفس الخامة والتفاصيل…',
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'مع الحفاظ الكامل على الوجه وحجم الجسم الطبيعي',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.gray500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Stage Panel: Lighting-Only Check OR Garment Switcher
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * .46,
                            ),
                            child: SingleChildScrollView(
                              child: failed
                                  ? const SizedBox.shrink()
                                  : !guard.approved && guard.analyzing
                                  ? LightingOnlyChecklist(
                                      assessment: guard.assessment,
                                      selectedZone: state.selectedZone,
                                      onSkipLighting:
                                          _guard.forceApproveLighting,
                                      onChangeZone: () =>
                                          _openBodyZoneModal(context),
                                    )
                                  : _garments(state),
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

  Widget _errorPanel(DecartTryonState state, String message) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.focus, size: 36, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if (state.retryPending)
                  AppBusyLabel(
                    label:
                        'جارٍ استئناف التجربة تلقائياً… (${state.retryAttempt}/3)'
                            .tr,
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _controller.retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('إعادة المحاولة الآن'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _returnToBodyMap,
                    icon: const Icon(Icons.accessibility_new_rounded, size: 18),
                    label: const Text('العودة لتحديد مكان اللبس على المجسم'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _garments(DecartTryonState state) {
    final zoneColor = Color(state.selectedZone.colorHex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: zoneColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showOriginal
                      ? 'صورتك الأصلية للمقارنة'.tr
                      : 'مركّب على: ${state.selectedZone.arabicTitle}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _showOriginal ? AppColors.gray700 : zoneColor,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openBodyZoneModal(context),
                icon: Icon(
                  Icons.accessibility_new_rounded,
                  size: 16,
                  color: zoneColor,
                ),
                label: Text(
                  'تغيير المكان',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: zoneColor,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'اختيار قطعة'.tr,
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
            state.selectedProduct?.name ?? 'قطعتك'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            'نفس خامات وتفاصيل المنتج • الحفاظ التام على الوجه وحجم الجسم الطبيعي',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.gray500),
          ),
          if (state.isUpdating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppBusyLabel(
                label:
                    'جارٍ تطبيق القطعة على (${state.selectedZone.shortLabel})…',
              ),
            ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (_showGarments &&
              state.isConnected &&
              !state.isUpdating &&
              state.availableProducts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                height: 96,
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
        },
        child: Container(
          width: 84,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? tileColor.withValues(alpha: .10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tileColor : AppColors.border,
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
                        errorBuilder: (_, _, _) => const Icon(AppIcons.garment),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
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
                  fontSize: 10.5,
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
