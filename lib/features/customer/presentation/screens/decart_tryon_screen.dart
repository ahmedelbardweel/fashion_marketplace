import '../../../../core/widgets/app_skeleton.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/decart_realtime_service.dart';
import '../../domain/models/customer_product.dart';
import '../../../virtual_tryon/presentation/remote_video_binding.dart';
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
  late final Future<void> _rendererInitialization;
  late DecartRealtimeService _service;
  late DecartTryonNotifier _controller;
  RemoteVideoBinding? _videoBinding;
  bool _ready = false;
  bool _showGarments = false;
  String? _rendererError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rendererInitialization = _renderer.initialize();
    // Attach the renderer before dialing: the first frame is the readiness signal.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await _rendererInitialization;
      if (!mounted) return;
      _service = ref.read(decartRealtimeServiceProvider(widget.productId));
      _controller = ref.read(decartTryonProvider(widget.productId).notifier);
      _videoBinding = RemoteVideoBinding(_renderer, () {
        if (mounted) _service.notifyFirstRemoteFrame();
      });
      _service.onRemoteStream = (stream) {
        if (mounted) _videoBinding?.attach(stream);
      };
      setState(() => _ready = true);
      await _controller.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _rendererError = 'تعذر تهيئة عارض الفيديو على هذا الجهاز.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ready &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      unawaited(_controller.suspend());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ready) {
      _service.onRemoteStream = null;
      _videoBinding?.attach(null);
      _videoBinding?.dispose();
      _renderer.srcObject = null;
      unawaited(_controller.suspend());
    }
    unawaited(
      _rendererInitialization
          .then((_) => _renderer.dispose())
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(decartTryonProvider(widget.productId));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            RepaintBoundary(
              child: RTCVideoView(
                _renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                mirror: false, // Preserve garment text/logos from the server.
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'رجوع',
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            state.isConnected
                                ? 'التجربة المباشرة'
                                : 'تجربة الملابس',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'تبديل الكاميرا',
                        onPressed: _ready && state.isConnected
                            ? _controller.switchCamera
                            : null,
                        icon: const Icon(Icons.flip_camera_ios_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _statusPanel(state),
                      ),
                    ),
                  ),
                ),
                if (state.isUpdating)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: AppBusyLabel(label: 'جارٍ تبديل القطعة…'),
                  ),
                if (state.errorMessage != null && state.isConnected)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                _garments(state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPanel(DecartTryonState state) {
    final error = _rendererError ?? state.errorMessage;
    if (_rendererError != null ||
        state.status == DecartSessionStatus.error ||
        state.status == DecartSessionStatus.disconnected) {
      return _panel(
        key: const ValueKey('error'),
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            error ?? 'توقفت الجلسة. اضغط للاتصال مجدداً.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (_ready)
            FilledButton(
              onPressed: _controller.retry,
              child: const Text('إعادة الاتصال'),
            ),
        ],
      );
    }
    if (!_ready ||
        state.isOverlayLoading ||
        state.status == DecartSessionStatus.idle) {
      return _panel(
        key: const ValueKey('loading'),
        children: [
          const AppSkeleton(
            child: Icon(Icons.videocam_outlined, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            state.status == DecartSessionStatus.connecting
                ? 'بانتظار أول إطار من الفيديو المعالج…'
                : 'جارٍ تجهيز الكاميرا والاتصال…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _panel({required Key key, required List<Widget> children}) =>
      Container(
        key: key,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _garments(DecartTryonState state) => Container(
    color: Colors.black.withValues(alpha: 0.8),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'ثبّت الهاتف بالطول وابتعد ليظهر جسمك كاملاً',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
            IconButton(
              tooltip: _showGarments ? 'إخفاء الملابس' : 'اختيار الملابس',
              onPressed: () => setState(() => _showGarments = !_showGarments),
              color: Colors.white,
              icon: Icon(
                _showGarments ? Icons.expand_more : Icons.checkroom_outlined,
              ),
            ),
          ],
        ),
        Text(
          state.isUpdating
              ? 'جارٍ تطبيق القطعة…'
              : state.selectedProduct?.name ?? 'قطع الملابس',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
        if (_showGarments) const SizedBox(height: 8),
        if (_showGarments)
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: state.availableProducts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final product = state.availableProducts[index];
                return _garmentTile(product, state);
              },
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
        onTap: _ready && state.isConnected
            ? () => _controller.selectGarment(product)
            : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 88,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.18 : 0.08),
            border: Border.all(
              color: selected ? Colors.greenAccent : Colors.white24,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Expanded(
                child: AppNetworkImage(
                  product.tryonReferenceImage!,
                  fit: BoxFit.contain,
                  cacheWidth: 192,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.checkroom, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
