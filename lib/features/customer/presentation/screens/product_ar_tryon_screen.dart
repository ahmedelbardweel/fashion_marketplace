import 'package:fashion_marketplace/core/utils/app_haptics.dart';

import '../../../../core/widgets/app_skeleton.dart';
import '../widgets/customer_action_sheet.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/painters/garment_overlay_painter.dart';
import '../../../../core/services/garment_fitter.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../router/routes.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';

enum _BodyStatus { searching, detected }

class ProductArTryonScreen extends ConsumerStatefulWidget {
  const ProductArTryonScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductArTryonScreen> createState() =>
      _ProductArTryonScreenState();
}

class _ProductArTryonScreenState extends ConsumerState<ProductArTryonScreen>
    with WidgetsBindingObserver {
  // ── Camera ──────────────────────────────────────────────
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;
  bool _isCamReady = false;
  String? _camError;
  bool _isProcessingFrame = false;

  bool get _isMlSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // ── Pose Detection ──────────────────────────────────────
  PoseDetector? _poseDetector;
  GarmentTransform _transform = GarmentTransform.empty;
  final GarmentFitter _fitter = GarmentFitter();
  _BodyStatus _bodyStatus = _BodyStatus.searching;
  int _lostFrameCount = 0;
  static const _lostThreshold = 6;

  // ── Garment Images ──────────────────────────────────────
  ui.Image? _garmentFrontImage;
  ui.Image? _garmentBackImage;
  String? _loadedFrontUrl;
  String? _loadedBackUrl;

  // ── Screen Canvas ───────────────────────────────────────
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_isMlSupported) {
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.base,
        ),
      );
    }

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _camCtrl?.dispose();
      _camCtrl = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camCtrl?.dispose();
    if (_isMlSupported) {
      _poseDetector?.close();
    }
    _garmentFrontImage?.dispose();
    _garmentBackImage?.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────
  //  Camera Setup
  // ──────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _camError = 'لم يتم العثور على كاميرا في هذا الجهاز'.tr);
        return;
      }
      final frontIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _camIndex = frontIdx >= 0 ? frontIdx : 0;
      await _startCamera(_cameras[_camIndex]);
    } catch (e) {
      setState(() => _camError = 'تعذر تشغيل الكاميرا: $e'.tr);
    }
  }

  Future<void> _startCamera(CameraDescription desc) async {
    await _camCtrl?.dispose();

    final ctrl = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : null,
    );

    try {
      await ctrl.initialize();
      if (!mounted) return;

      // Real ML Kit stream on mobile
      if (_isMlSupported && ctrl.supportsImageStreaming()) {
        await ctrl.startImageStream(_onCameraFrame);
      }

      setState(() {
        _camCtrl = ctrl;
        _isCamReady = true;
        _camError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _camError = 'خطأ أثناء تشغيل الكاميرا: $e'.tr);
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2) return;
    _camIndex = (_camIndex + 1) % _cameras.length;
    _fitter.reset();
    setState(() {
      _bodyStatus = _BodyStatus.searching;
      _transform = GarmentTransform.empty;
      _lostFrameCount = 0;
    });
    _startCamera(_cameras[_camIndex]);
  }

  // ──────────────────────────────────────────────────────
  //  Real-time Frame Stream (ML Kit on Mobile)
  // ──────────────────────────────────────────────────────
  void _onCameraFrame(CameraImage image) {
    if (_isProcessingFrame) return;
    if (_garmentFrontImage == null) return;
    if (_poseDetector == null) return;
    _isProcessingFrame = true;

    _processFrame(image).then((_) {
      _isProcessingFrame = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    final camera = _cameras[_camIndex];
    final inputImage = _buildInputImage(image, camera);
    if (inputImage == null || _poseDetector == null) return;

    try {
      final poses = await _poseDetector!.processImage(inputImage);
      if (!mounted) return;

      if (poses.isNotEmpty && _canvasSize != Size.zero) {
        final isFront = camera.lensDirection == CameraLensDirection.front;
        final rotation =
            InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

        final newTransform = _fitter.fitGarment(
          pose: poses.first,
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
          canvasSize: _canvasSize,
          rotation: rotation,
          isFrontCamera: isFront,
        );

        if (newTransform.isDetected) {
          setState(() {
            _transform = newTransform;
            _bodyStatus = _BodyStatus.detected;
            _lostFrameCount = 0;
          });
          return;
        }
      }

      _lostFrameCount++;
      if (_lostFrameCount >= _lostThreshold &&
          _bodyStatus == _BodyStatus.detected) {
        setState(() {
          _bodyStatus = _BodyStatus.searching;
          _transform = GarmentTransform.empty;
        });
      }
    } catch (_) {
      // Continue smoothly
    }
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    return InputImage.fromBytes(
      bytes: allBytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  Desktop Testing Trigger (When not on mobile)
  // ──────────────────────────────────────────────────────
  void _toggleDesktopTryon() {
    if (_bodyStatus == _BodyStatus.detected) {
      setState(() {
        _bodyStatus = _BodyStatus.searching;
        _transform = GarmentTransform.empty;
      });
      return;
    }

    if (_canvasSize == Size.zero) return;

    final shoulderY = _canvasSize.height * 0.35;
    final shoulderHalfWidth = _canvasSize.width * 0.22;
    final centerX = _canvasSize.width * 0.5;

    final ls = Offset(centerX - shoulderHalfWidth, shoulderY);
    final rs = Offset(centerX + shoulderHalfWidth, shoulderY);
    final lh = Offset(
      centerX - shoulderHalfWidth * 0.85,
      shoulderY + _canvasSize.height * 0.26,
    );
    final rh = Offset(
      centerX + shoulderHalfWidth * 0.85,
      shoulderY + _canvasSize.height * 0.26,
    );
    final shoulderWidth = (rs - ls).distance;

    setState(() {
      _bodyStatus = _BodyStatus.detected;
      _transform = GarmentTransform(
        center: Offset(centerX, shoulderY + _canvasSize.height * 0.12),
        width: shoulderWidth * 1.52,
        height: (lh.dy - ls.dy) * 1.32,
        roll: 0.0,
        yaw: 0.0,
        pitch: 0.0,
        facing: BodyFacing.front,
        estimatedSize: 'M',
        isDetected: true,
        confidence: 0.98,
        leftShoulder: ls,
        rightShoulder: rs,
        leftHip: lh,
        rightHip: rh,
        bodyMidpoint: Offset(centerX, shoulderY + _canvasSize.height * 0.14),
        shoulderWidth: shoulderWidth,
      );
    });
  }

  // ──────────────────────────────────────────────────────
  //  Garment Images Loader
  // ──────────────────────────────────────────────────────
  Future<void> _loadGarmentAssets(CustomerProduct product) async {
    final frontUrl = product.arFrontImage;
    final backUrl = product.arBackImage;

    if (frontUrl != null && frontUrl != _loadedFrontUrl) {
      _loadedFrontUrl = frontUrl;
      final img = await _fetchUiImage(frontUrl);
      if (mounted && img != null) {
        setState(() => _garmentFrontImage = img);
      }
    }

    if (backUrl != null && backUrl != _loadedBackUrl) {
      _loadedBackUrl = backUrl;
      final img = await _fetchUiImage(backUrl);
      if (mounted && img != null) {
        setState(() => _garmentBackImage = img);
      }
    }
  }

  Future<ui.Image?> _fetchUiImage(String url) async {
    try {
      final completer = Completer<ui.Image>();
      final stream = NetworkImage(url)
          .resolve(const ImageConfiguration(size: Size(900, 900)));

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          completer.complete(info.image.clone());
          stream.removeListener(listener);
        },
        onError: (err, _) {
          if (!completer.isCompleted) completer.completeError(err);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);

      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  //  Capture Snapshot & Purchase
  // ──────────────────────────────────────────────────────
  Future<void> _captureSnapshot(CustomerProduct product) async {
    final suggestedSize = _transform.isDetected
        ? _transform.estimatedSize
        : 'M';

    final matchingVariant = product.variants.firstWhere(
      (v) => v.size.toUpperCase() == suggestedSize && v.stock > 0,
      orElse: () => product.variants.isNotEmpty
          ? product.variants.first
          : ProductVariant(
              id: '',
              productId: '',
              color: 'افتراضي'.tr,
              size: 'M',
              stock: 10,
              isActive: true,
            ),
    );

    AppBottomSheet.show(
      context: context,
      child: Builder(
        builder: (dialogCtx) => CustomerActionSheet(
          title: Row(
            children: [
              Icon(
                AppIcons.verified,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'مطابقة القياس بنجاح'.tr,
                style: Theme.of(dialogCtx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المقاس المناسب لك:'.tr,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            suggestedSize,
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.md),
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      AppFormat.price(product.price),
                      style: TextStyle(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'القطعة متناسقة تماماً مع قياسات جسمك! هل ترغب بإضافتها إلى سلتك؟'.tr,
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: AppHaptics.action(() => Navigator.of(dialogCtx).pop()),
              child: Text('متابعة التجربة'.tr),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
              ),
              onPressed: AppHaptics.action(() {
                Navigator.of(dialogCtx).pop();
                ref
                    .read(cartProvider.notifier)
                    .addItem(
                      product: product,
                      variantId: matchingVariant.id.isNotEmpty
                          ? matchingVariant.id
                          : null,
                      color: matchingVariant.color,
                      size: matchingVariant.size,
                      maxStock: matchingVariant.stock,
                    );
                showAppSnackBar(
                  context,
                  'تمت إضافة مقاس ($suggestedSize) بنجاح إلى سلتك!'.tr,
                );
                context.pop();
              }),
              child: Text('إضافة مقاس ($suggestedSize) للسلة'.tr),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(
      customerProductDetailsProvider(widget.productId),
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return Center(
              child: Text(
                'المنتج غير موجود'.tr,
                style: TextStyle(color: AppColors.white),
              ),
            );
          }

          if (_garmentFrontImage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadGarmentAssets(product);
            });
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Live Fullscreen Camera ──
              _buildCameraPreview(),

              // ── 2. Garment Overlay (ONLY VISIBLE WHEN BODY IS DETECTED) ──
              if (_garmentFrontImage != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final newSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    if (_canvasSize != newSize) {
                      _canvasSize = newSize;
                    }
                    // Animated opacity: 0 when searching (hidden), 1 when body detected!
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity:
                          (_bodyStatus == _BodyStatus.detected &&
                              _transform.isDetected)
                          ? 1.0
                          : 0.0,
                      child: CustomPaint(
                        size: newSize,
                        painter: GarmentOverlayPainter(
                          transform: _transform,
                          garmentImage: _garmentFrontImage!,
                          garmentBackImage: _garmentBackImage,
                          opacity: 0.96,
                        ),
                      ),
                    );
                  },
                ),

              // ── 3. Top Navigation & Status Bar ──
              Positioned(
                top: MediaQuery.of(context).padding.top + AppSpacing.sm,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    _circleIconBtn(
                      icon: AppIcons.back,
                      onTap: () => context.pop(),
                    ),

                    // Minimal status pill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _bodyStatus == _BodyStatus.detected
                              ? TryOnDesign.detectedStroke
                              : Colors.white24,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _bodyStatus == _BodyStatus.detected
                                ? AppIcons.checkCircleFilled
                                : AppIcons.bodyGuide,
                            size: 15,
                            color: _bodyStatus == _BodyStatus.detected
                                ? TryOnDesign.detectedStroke
                                : Colors.white70,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _bodyStatus == _BodyStatus.detected
                                ? 'تم تحديد الجسم (المقاس: ${_transform.estimatedSize})'.tr
                                : 'قف أمام الكاميرا لتحديد الجسم...'.tr,
                            style: TextStyle(
                              color: _bodyStatus == _BodyStatus.detected
                                  ? TryOnDesign.detectedStroke
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions: Decart AI mode + Switch camera
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _circleIconBtn(
                          icon: AppIcons.sparkles,
                          onTap: () => context.push(
                            AppRoutes.customerRealtimeTryonPath(
                              widget.productId,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _circleIconBtn(
                          icon: AppIcons.flipCamera,
                          onTap: _cameras.length > 1 ? _switchCamera : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 4. Desktop-only quick try-on trigger (hidden on mobile) ──
              if (!_isMlSupported)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: AppHaptics.action(_toggleDesktopTryon),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (_bodyStatus == _BodyStatus.detected)
                              ? AppColors.error.withValues(alpha: 0.85)
                              : AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          (_bodyStatus == _BodyStatus.detected)
                              ? 'إخفاء القطعة'.tr
                              : 'معاينة القطعة على الجسم'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── 5. Bottom Capture Button (Ultra-clean) ──
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: AppHaptics.action(() => _captureSnapshot(product)),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                        border: Border.all(color: Colors.black26, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        AppIcons.camera,
                        size: 32,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const AppSkeleton(
          child: Stack(
            children: [
              Center(
                child: Icon(
                  AppIcons.user,
                  size: 180,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(AppIcons.flipCamera, color: Colors.white),
                    Icon(AppIcons.camera, size: 64, color: Colors.white),
                    Icon(AppIcons.garment, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'حدث خطأ: $e'.tr,
            style: TextStyle(color: AppColors.white),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  Clean Camera Preview Widget
  // ──────────────────────────────────────────────────────
  Widget _buildCameraPreview() {
    if (_isCamReady && _camCtrl != null && _camCtrl!.value.isInitialized) {
      final previewSize = _camCtrl!.value.previewSize;
      final double pW = defaultTargetPlatform == TargetPlatform.android
          ? (previewSize?.height ?? 1)
          : (previewSize?.width ?? 1);
      final double pH = defaultTargetPlatform == TargetPlatform.android
          ? (previewSize?.width ?? 1)
          : (previewSize?.height ?? 1);

      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: pW,
            height: pH,
            child: CameraPreview(_camCtrl!),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              AppIcons.camera,
              size: 56,
              color: Colors.white30,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _camError ?? 'جاري تشغيل الكاميرا...'.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIconBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: AppHaptics.action(onTap),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.6),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
