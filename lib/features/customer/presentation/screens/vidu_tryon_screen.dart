import 'dart:async';
import 'dart:typed_data';

import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/tryon_bandwidth_guard.dart';
import '../../../../core/services/vidu_tryon_service.dart';
import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../virtual_tryon/domain/tryon_quota.dart';
import '../../../virtual_tryon/domain/tryon_session.dart';
import '../../../virtual_tryon/presentation/tryon_quota_provider.dart';
import '../../domain/models/customer_product.dart';
import '../providers/customer_providers.dart';

/// High-resolution Reference-to-Image Virtual Try-On powered by Vidu AI (`viduq2`).
class ViduTryonScreen extends ConsumerStatefulWidget {
  const ViduTryonScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ViduTryonScreen> createState() => _ViduTryonScreenState();
}

class _ViduTryonScreenState extends ConsumerState<ViduTryonScreen> {
  final _picker = ImagePicker();
  final _service = ViduTryonService();

  bool _loadingCatalog = true;
  CustomerProduct? _selectedProduct;
  String? _selectedGarmentImage;
  List<CustomerProduct> _catalog = const [];
  TryonBodyZone _selectedZone = TryonBodyZone.upperBody;
  bool _zoneManual = false;

  Uint8List? _personPhotoBytes;
  String _personPhotoName = 'user_photo.jpg';

  bool _generating = false;
  bool _disposed = false;
  bool _networkFocusAcquired = false;
  String _stageMessage = '';
  String? _resultImageUrl;
  bool _showOriginalComparison = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        TryonNetworkFocus.instance.autoDetectBandwidthMode(
          resetManualOverride: true,
        ),
      );
      unawaited(_loadInitialData());
    });
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

  @override
  void dispose() {
    _disposed = true;
    _releaseNetworkFocus();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      final initial = await repo.getProductDetails(widget.productId);
      final products = await repo.getProducts(limit: 12);
      final merged = <String, CustomerProduct>{
        for (final p in products)
          if ((p.tryonReferenceImage?.isNotEmpty ?? false)) p.id: p,
        if (initial != null && (initial.tryonReferenceImage?.isNotEmpty ?? false))
          initial.id: initial,
      }.values.toList();

      if (!mounted) return;
      final chosen =
          merged.where((p) => p.id == widget.productId).firstOrNull ??
          initial ??
          merged.firstOrNull;
      setState(() {
        _catalog = merged;
        _selectedProduct = chosen;
        _selectedGarmentImage = chosen?.tryonReferenceImage;
        if (chosen != null) {
          _selectedZone = TryonBodyZone.infer(chosen.name, chosen.categoryName);
        }
        _loadingCatalog = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCatalog = false;
          _errorMessage = 'تعذر تحميل بيانات المنتج حالياً.'.tr;
        });
      }
    }
  }

  void _selectProduct(CustomerProduct product, {String? imageUrl}) {
    final targetImg = (imageUrl?.trim().isNotEmpty ?? false)
        ? imageUrl!.trim()
        : product.tryonReferenceImage;
    setState(() {
      _selectedProduct = product;
      _selectedGarmentImage = targetImg;
      if (!_zoneManual) {
        _selectedZone = TryonBodyZone.infer(product.name, product.categoryName);
      }
      _resultImageUrl = null;
      _showOriginalComparison = false;
      _errorMessage = null;
    });
  }

  Future<void> _pickUserPhoto(ImageSource source) async {
    if (_generating) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _personPhotoBytes = bytes;
        _personPhotoName = picked.name.isNotEmpty ? picked.name : 'photo.jpg';
        _resultImageUrl = null;
        _showOriginalComparison = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'تعذر الوصول إلى الصورة. تأكد من منح الإذن للتطبيق.'.tr,
          isError: true,
        );
      }
    }
  }

  Future<void> _generate() async {
    if (_generating) return;
    final photo = _personPhotoBytes;
    final garmentUrl = _selectedGarmentImage?.trim();
    if (photo == null) {
      showAppSnackBar(
        context,
        'يرجى التقاط صورتك أو اختيارها من المعرض أولاً.'.tr,
        isError: true,
      );
      return;
    }
    if (garmentUrl == null || garmentUrl.isEmpty) {
      showAppSnackBar(
        context,
        'لا توجد صورة صالحة لهذه القطعة حالياً.'.tr,
        isError: true,
      );
      return;
    }

    setState(() {
      _generating = true;
      _errorMessage = null;
      _resultImageUrl = null;
      _showOriginalComparison = false;
      _stageMessage = 'جارٍ تحضير الصورة...';
    });

    final mode = TryonNetworkFocus.instance.bandwidthMode.value;
    _acquireNetworkFocus();

    try {
      final result = await _service.generateTryonImage(
        personPhotoBytes: photo,
        personPhotoName: _personPhotoName,
        garmentImageUrl: garmentUrl,
        garmentName: _selectedProduct?.name,
        garmentCategory: _selectedProduct?.categoryName,
        bodyZone: _selectedZone,
        bandwidthMode: mode,
        onStageChanged: (stage) {
          if (mounted) setState(() => _stageMessage = stage);
        },
        isCancelled: () => _disposed || !mounted,
      );

      if (!mounted) return;
      final quotaNotifier = ref.read(tryonQuotaProvider.notifier);
      if (result.dailyLimit != null && result.usedToday != null) {
        final current = ref.read(tryonQuotaProvider).valueOrNull ?? const TryonQuota();
        quotaNotifier.updateFromQuota(
          current.copyWith(
            dailyLimit: result.dailyLimit,
            usedToday: result.usedToday,
            remainingToday:
                result.remainingToday ??
                (result.dailyLimit! - result.usedToday!).clamp(0, result.dailyLimit!),
            clearBlockReasonOverride: true,
          ),
        );
      } else {
        unawaited(quotaNotifier.refresh());
      }

      setState(() {
        _resultImageUrl = result.imageUrl;
        _generating = false;
      });
    } on ViduTryonException catch (error) {
      if (!mounted || error.code == 'cancelled') return;
      final blocked = blockReasonFromViduCode(error.code);
      if (blocked != null) {
        ref
            .read(tryonQuotaProvider.notifier)
            .markBlocked(blocked, dailyLimit: error.dailyLimit);
      } else if (error.refunded) {
        unawaited(ref.read(tryonQuotaProvider.notifier).refresh());
      }
      setState(() {
        _generating = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _errorMessage = 'حدث خطأ غير متوقع أثناء توليد الصورة. حاول مجدداً.'.tr;
      });
    } finally {
      _releaseNetworkFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(tryonQuotaProvider).valueOrNull ?? const TryonQuota();
    final product = _selectedProduct;
    final gallery = product?.tryonReferenceImages ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('التجربة الافتراضية بالصور'.tr),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  '${quota.remainingToday}/${quota.dailyLimit} ${'محاولة'.tr}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFont.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingCatalog
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1) Result View OR Photo Upload / Preview Canvas
                    if (_resultImageUrl != null)
                      _buildResultSection()
                    else
                      _buildPhotoStage(),

                    const SizedBox(height: AppSpacing.md),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // 2) Selected Garment Card + Color/Image Variants
                    if (product != null) _buildGarmentCard(product, gallery),

                    const SizedBox(height: AppSpacing.md),

                    // 3) Network Quality Mode (Data Saver / High Quality)
                    _buildBandwidthSelector(),

                    const SizedBox(height: AppSpacing.md),

                    // 4) Body Zone Selector
                    _buildBodyZoneSelector(),

                    // 4) Quick Catalog Switcher (Try another piece on the same photo)
                    if (_catalog.length > 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildCatalogStrip(),
                    ],

                    const SizedBox(height: AppSpacing.lg),

                    // 5) Primary Generate CTA
                    if (_resultImageUrl == null)
                      AppButton(
                        label: _generating
                            ? _stageMessage
                            : 'جرّب القطعة الآن (دقة عالية)'.tr,
                        isLoading: _generating,
                        onPressed: (_generating || _personPhotoBytes == null || quota.isBlocked)
                            ? null
                            : _generate,
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'تجربة مجدداً'.tr,
                              onPressed: quota.isBlocked ? null : _generate,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppButton(
                              label: 'تغيير صورتي'.tr,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _pickUserPhoto(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPhotoStage() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_personPhotoBytes == null) ...[
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primaryDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'ارفع صورتك لتجربة القطعة بالذكاء الاصطناعي'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'لأفضل نتيجة: اختر صورة واضحة بوقفة أمامية وإضاءة جيدة.'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'التقاط صورة'.tr,
                    onPressed: _generating
                        ? null
                        : () => _pickUserPhoto(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'من المعرض'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: _generating
                        ? null
                        : () => _pickUserPhoto(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ] else ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.memory(
                      _personPhotoBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                if (_generating)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _stageMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'يستغرق عادةً من 8 إلى 20 ثانية'.tr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_generating)
                  PositionedDirectional(
                    top: AppSpacing.sm,
                    end: AppSpacing.sm,
                    child: Row(
                      children: [
                        _MiniIconPill(
                          icon: Icons.camera_alt_rounded,
                          tooltip: 'التقاط صورة جديدة'.tr,
                          onTap: () => _pickUserPhoto(ImageSource.camera),
                        ),
                        const SizedBox(width: 6),
                        _MiniIconPill(
                          icon: Icons.photo_library_rounded,
                          tooltip: 'اختيار من المعرض'.tr,
                          onTap: () => _pickUserPhoto(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showOriginalComparison
                          ? 'الصورة الأصلية'.tr
                          : 'النتيجة بالذكاء الاصطناعي'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: AppHaptics.action(() {
                  setState(
                    () => _showOriginalComparison = !_showOriginalComparison,
                  );
                }),
                icon: Icon(
                  _showOriginalComparison
                      ? Icons.auto_awesome_rounded
                      : Icons.compare_rounded,
                  size: 16,
                ),
                label: Text(
                  _showOriginalComparison ? 'عرض النتيجة'.tr : 'مقارنة الأصل'.tr,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.5,
                child: _showOriginalComparison && _personPhotoBytes != null
                    ? Image.memory(
                        _personPhotoBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : _NetImage(
                        url: _resultImageUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'يمكنك التكبير باللمس لمعاينة تفاصيل القماش والمقاس.'.tr,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildGarmentCard(CustomerProduct product, List<String> gallery) {
    final activeImg = _selectedGarmentImage ?? product.tryonReferenceImage ?? '';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: 60,
                  height: 72,
                  child: activeImg.isNotEmpty
                      ? _NetImage(url: activeImg, fit: BoxFit.cover)
                      : Container(color: AppColors.surfaceAlt),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppStatusBadge(
                      label: _zoneLabel(_selectedZone),
                      tone: BadgeTone.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (gallery.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gallery.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final imgUrl = gallery[index];
                  final selected = imgUrl == activeImg;
                  return GestureDetector(
                    onTap: _generating
                        ? null
                        : AppHaptics.action(() {
                            setState(() {
                              _selectedGarmentImage = imgUrl;
                              _resultImageUrl = null;
                            });
                          }),
                    child: Container(
                      width: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _NetImage(url: imgUrl, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBandwidthSelector() {
    return ValueListenableBuilder<TryonBandwidthMode>(
      valueListenable: TryonNetworkFocus.instance.bandwidthMode,
      builder: (context, mode, _) {
        final isDataSaver = mode == TryonBandwidthMode.dataSaver;
        return AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isDataSaver
                        ? Icons.data_saver_on_rounded
                        : Icons.hd_rounded,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'وضع الشبكة والجودة'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: AppFont.bold,
                      ),
                    ),
                  ),
                  Text(
                    isDataSaver ? '1080p · رفع سريع'.tr : '2K · فائق الدقة'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: AppFont.semiBold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<TryonBandwidthMode>(
                segments: [
                  ButtonSegment<TryonBandwidthMode>(
                    value: TryonBandwidthMode.dataSaver,
                    label: Text('توفير النت'.tr),
                    icon: const Icon(Icons.data_saver_on_rounded, size: 16),
                  ),
                  ButtonSegment<TryonBandwidthMode>(
                    value: TryonBandwidthMode.highQuality,
                    label: Text('جودة عالية'.tr),
                    icon: const Icon(Icons.hd_rounded, size: 16),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: _generating
                    ? null
                    : (selection) {
                        if (selection.isNotEmpty) {
                          TryonNetworkFocus.instance.setManualBandwidthMode(
                            selection.first,
                          );
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBodyZoneSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'منطقة ارتداء القطعة'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final zone in TryonBodyZone.values)
              ChoiceChip(
                label: Text(_zoneLabel(zone)),
                selected: _selectedZone == zone,
                onSelected: _generating
                    ? null
                    : (_) {
                        setState(() {
                          _selectedZone = zone;
                          _zoneManual = true;
                        });
                      },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCatalogStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'جرّب قطعاً أخرى على نفس صورتك'.tr,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: AppFont.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _catalog.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _catalog[index];
              final selected = item.id == _selectedProduct?.id;
              final img = item.tryonReferenceImage ?? '';
              return GestureDetector(
                onTap: _generating
                    ? null
                    : AppHaptics.action(() => _selectProduct(item)),
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: img.isNotEmpty
                      ? _NetImage(url: img, fit: BoxFit.cover)
                      : Container(color: AppColors.surfaceAlt),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _zoneLabel(TryonBodyZone zone) => zone.shortLabel.tr;
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => Container(
        color: AppColors.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
      ),
    );
  }
}

class _MiniIconPill extends StatelessWidget {
  const _MiniIconPill({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: AppHaptics.action(onTap),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}
