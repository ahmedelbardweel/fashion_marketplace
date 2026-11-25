import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/supabase_config.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../core/services/decart_vton_sdk_service.dart';
import '../../../../core/services/vidu_tryon_service.dart';
import '../../../virtual_tryon/data/decart_session_config.dart';
import '../../../virtual_tryon/data/tryon_errors.dart';
import '../../../virtual_tryon/domain/tryon_quota.dart';
import '../../../virtual_tryon/domain/tryon_session.dart';
import '../../../virtual_tryon/data/automatic_tryon_recovery.dart';
import '../../../virtual_tryon/presentation/tryon_quota_provider.dart';
import '../../domain/models/customer_product.dart';
import 'customer_providers.dart';

export '../../../virtual_tryon/domain/tryon_session.dart'
    show DecartSessionStatus, TryonBodyZone;

typedef LoadTryonCatalog = Future<List<CustomerProduct>> Function();

class DecartTryonState {
  const DecartTryonState({
    this.status = DecartSessionStatus.idle,
    this.selectedProduct,
    this.selectedImageUrl,
    this.appliedProductId,
    this.appliedImageUrl,
    this.availableProducts = const [],
    this.selectedZone = TryonBodyZone.upperBody,
    this.zoneManuallySelected = false,
    this.isFrontCamera = true,
    this.isUpdating = false,
    this.errorMessage,
    this.retryPending = false,
    this.retryAttempt = 0,
  });
  final DecartSessionStatus status;
  final CustomerProduct? selectedProduct;
  final String? selectedImageUrl;
  final String? appliedProductId;
  final String? appliedImageUrl;
  final List<CustomerProduct> availableProducts;
  final TryonBodyZone selectedZone;
  final bool zoneManuallySelected;
  final bool isFrontCamera;
  final bool isUpdating;
  final String? errorMessage;
  final bool retryPending;
  final int retryAttempt;
  bool get isConnected => status == DecartSessionStatus.connected;
  bool get isOverlayLoading =>
      status == DecartSessionStatus.initializing ||
      status == DecartSessionStatus.connecting;
  String? get effectiveImageUrl =>
      (selectedImageUrl?.isNotEmpty ?? false)
      ? selectedImageUrl
      : selectedProduct?.tryonReferenceImage;
  TryonBodyZone get effectiveZone =>
      zoneManuallySelected || selectedProduct == null
      ? selectedZone
      : TryonBodyZone.infer(
          selectedProduct!.name,
          selectedProduct!.categoryName,
        );

  DecartTryonState copyWith({
    DecartSessionStatus? status,
    CustomerProduct? selectedProduct,
    String? selectedImageUrl,
    String? appliedProductId,
    String? appliedImageUrl,
    List<CustomerProduct>? availableProducts,
    TryonBodyZone? selectedZone,
    bool? zoneManuallySelected,
    bool? isFrontCamera,
    bool? isUpdating,
    String? errorMessage,
    bool clearApplied = false,
    bool clearSelectedImage = false,
    bool? retryPending,
    int? retryAttempt,
  }) => DecartTryonState(
    status: status ?? this.status,
    selectedProduct: selectedProduct ?? this.selectedProduct,
    selectedImageUrl: clearSelectedImage
        ? null
        : selectedImageUrl ?? this.selectedImageUrl,
    appliedProductId: clearApplied
        ? null
        : appliedProductId ?? this.appliedProductId,
    appliedImageUrl: clearApplied
        ? null
        : appliedImageUrl ?? this.appliedImageUrl,
    availableProducts: availableProducts ?? this.availableProducts,
    selectedZone: selectedZone ?? this.selectedZone,
    zoneManuallySelected: zoneManuallySelected ?? this.zoneManuallySelected,
    isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    isUpdating: isUpdating ?? this.isUpdating,
    errorMessage: errorMessage, // null deliberately clears an earlier failure.
    retryPending: retryPending ?? this.retryPending,
    retryAttempt: retryAttempt ?? this.retryAttempt,
  );
}

final decartVtonSdkServiceProvider = Provider.autoDispose
    .family<DecartVtonSdkService, String>((ref, productId) {
      final quotaNotifier = ref.read(tryonQuotaProvider.notifier);
      final service = DecartVtonSdkService(
        loadConfig: () async {
          try {
            final response = await NetworkGuard.run(
              () => SupabaseConfig.client.functions.invoke('decart-session'),
              timeout: AppTimeouts.edgeFunction,
            );
            final config = DecartSessionConfig.fromJson(
              Map<String, dynamic>.from(response.data as Map),
            );
            quotaNotifier.updateFromSessionConfig(config);
            return config;
          } on AppNetworkException catch (error) {
            throw TryonFailure(error.userMessage);
          } on FunctionException catch (error) {
            final details = error.details;
            if (details is Map) {
              final code = details['code']?.toString();
              if (code == 'all_keys_depleted') {
                quotaNotifier.markBlocked(TryonBlockReason.tokensDepleted);
              } else if (code == 'tryon_disabled') {
                quotaNotifier.markBlocked(TryonBlockReason.disabledByAdmin);
              } else if (code == 'daily_limit_reached') {
                quotaNotifier.markBlocked(
                  TryonBlockReason.dailyLimitReached,
                  dailyLimit: (details['dailyLimit'] as num?)?.toInt(),
                );
              } else if (error.status == 503 &&
                  details['error']?.toString() == 'Service not configured') {
                quotaNotifier.markBlocked(TryonBlockReason.tokensDepleted);
              }
            }
            throw sessionFunctionFailure(error.status, error.details);
          } on TryonFailure {
            rethrow;
          } catch (error) {
            throw TryonFailure(
              AppErrorMapper.message(
                error,
                fallback:
                    'تعذر إعداد الجلسة. تحقق من تسجيل الدخول واتصالك بالإنترنت.',
              ),
            );
          }
        },
      );
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });

final viduLiveTryonSessionProvider = Provider.autoDispose
    .family<ViduLiveTryonSession, String>((ref, productId) {
      final quotaNotifier = ref.read(tryonQuotaProvider.notifier);
      final service = ViduLiveTryonSession(
        onQuotaUpdated: quotaNotifier.updateFromSessionConfig,
        onQuotaBlocked: quotaNotifier.markBlocked,
      );
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });

final decartTryonProvider = StateNotifierProvider.autoDispose
    .family<DecartTryonNotifier, DecartTryonState, String>((ref, id) {
      final activeProvider = ref.watch(
        tryonQuotaProvider.select(
          (q) => q.valueOrNull?.activeProvider ?? TryonProvider.decart,
        ),
      );
      final TryonSession service = activeProvider == TryonProvider.vidu
          ? ref.watch(viduLiveTryonSessionProvider(id))
          : ref.watch(decartVtonSdkServiceProvider(id));
      // Capture dependencies now, never read a disposed Ref after an await.
      final repository = ref.read(customerRepositoryProvider);
      return DecartTryonNotifier(service, () async {
        final initial = await repository.getProductDetails(id);
        final catalog = await repository.getProducts(limit: kProductPageSize);
        return {
          for (final item in catalog) item.id: item,
          ?initial?.id: initial!,
        }.values.toList();
      }, id);
    });

/// Presentation depends on the domain interface, and can run against a fake.
class DecartTryonNotifier extends StateNotifier<DecartTryonState> {
  DecartTryonNotifier(this._session, this._loadCatalog, this._initialId)
    : super(const DecartTryonState()) {
    _subscription = _session.events.listen((event) {
      if (!mounted) return;
      state = state.copyWith(
        status: event.status,
        errorMessage: event.error,
        isFrontCamera: _session.isUsingFrontCamera,
        isUpdating: event.status == DecartSessionStatus.connected
            ? state.isUpdating
            : false,
      );
      if (event.status == DecartSessionStatus.error) _scheduleRecovery();
    });
  }
  final TryonSession _session;
  final LoadTryonCatalog _loadCatalog;
  final String _initialId;
  late final StreamSubscription<TryonSessionEvent> _subscription;
  Timer? _debounce;
  CustomerProduct? _pending;
  String? _pendingImageUrl;
  bool _draining = false;
  bool _starting = false;
  bool _suspended = false;
  final _recovery = AutomaticTryonRecovery();
  Timer? _retryTimer;
  Completer<void>? _startFinished;
  int _revision = 0;

  void _scheduleRecovery() {
    if (!mounted ||
        _suspended ||
        _starting ||
        _retryTimer != null ||
        state.status != DecartSessionStatus.error)
      return;
    final delay = _recovery.nextDelay(state.errorMessage);
    if (delay == null) return;
    state = state.copyWith(
      errorMessage: state.errorMessage,
      retryPending: true,
      retryAttempt: _recovery.attempts,
    );
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (mounted && !_suspended) unawaited(start());
    });
  }

  Future<void> resume() async {
    // A paused catalog request or capture validation may still be unwinding.
    final revision = _revision;
    await _startFinished?.future;
    if (mounted && _suspended && revision == _revision) await start();
  }

  static bool supports(CustomerProduct product) {
    return product.name.trim().isNotEmpty &&
        (product.tryonReferenceImage?.isNotEmpty ?? false);
  }

  GarmentSelection _garment(CustomerProduct product, {String? imageUrl}) {
    final resolvedImage = (imageUrl?.trim().isNotEmpty ?? false)
        ? imageUrl!.trim()
        : ((state.selectedProduct?.id == product.id &&
                  (state.selectedImageUrl?.trim().isNotEmpty ?? false))
              ? state.selectedImageUrl!.trim()
              : (product.tryonReferenceImage ?? ''));
    return GarmentSelection(
      id: product.id,
      name: product.name,
      imageUrl: resolvedImage,
      category: product.categoryName,
      description: product.description,
      targetZone: state.zoneManuallySelected
          ? state.selectedZone
          : TryonBodyZone.infer(product.name, product.categoryName),
    );
  }

  /// Preloads the initial product and catalog during Step 1 (Body Map screen)
  /// so the user sees the product and its auto-detected body zone before starting the camera.
  Future<void> preloadCatalog() async {
    if (!mounted || state.availableProducts.isNotEmpty || _starting) return;
    try {
      final catalog = await _loadCatalog();
      if (!mounted || state.availableProducts.isNotEmpty) return;
      final garments = catalog.where(supports).toList();
      if (garments.isEmpty) return;
      final initial =
          garments.where((p) => p.id == _initialId).firstOrNull ??
          garments.first;
      state = state.copyWith(
        availableProducts: garments,
        selectedProduct: initial,
        selectedImageUrl: initial.tryonReferenceImage,
        selectedZone: state.zoneManuallySelected
            ? state.selectedZone
            : TryonBodyZone.infer(initial.name, initial.categoryName),
      );
    } catch (_) {
      // Errors will be surfaced if start() is invoked and fails.
    }
  }

  /// Explicitly sets the target anatomical body zone from the interactive body diagram.
  void selectBodyZone(TryonBodyZone zone) {
    if (!mounted) return;
    final changed = state.selectedZone != zone || !state.zoneManuallySelected;
    state = state.copyWith(
      selectedZone: zone,
      zoneManuallySelected: true,
      errorMessage: state.errorMessage,
    );
    if (changed && state.isConnected && state.selectedProduct != null) {
      ++_revision;
      _pending = state.selectedProduct;
      _pendingImageUrl = state.effectiveImageUrl;
      state = state.copyWith(isUpdating: true);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 120), _drain);
    }
  }

  Future<void> start() async {
    if (!mounted || _starting || state.isConnected) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _suspended = false;
    _starting = true;
    final finished = _startFinished = Completer<void>();
    final revision = ++_revision;
    state = state.copyWith(
      status: DecartSessionStatus.initializing,
      clearApplied: true,
      retryPending: false,
    );
    try {
      if (state.availableProducts.isEmpty) {
        final catalog = await _loadCatalog();
        if (!mounted || revision != _revision) return;
        final garments = catalog.where(supports).toList();
        if (garments.isEmpty) {
          throw TryonFailure('لا توجد قطع بصور أمامية متاحة للتجربة.'.tr);
        }
        final initial = garments.where((p) => p.id == _initialId).firstOrNull;
        if (initial == null) {
          throw TryonFailure(
            'المنتج المطلوب غير متاح للتجربة أو لا يملك صورة أمامية مناسبة. لم يتم استبداله بمنتج آخر.'.tr,
          );
        }
        state = state.copyWith(
          availableProducts: garments,
          selectedProduct: initial,
          selectedImageUrl: initial.tryonReferenceImage,
          selectedZone: state.zoneManuallySelected
              ? state.selectedZone
              : TryonBodyZone.infer(initial.name, initial.categoryName),
        );
      }
      final selected = state.selectedProduct!;
      final chosenUrl = state.effectiveImageUrl ?? selected.tryonReferenceImage;
      await _session.start(_garment(selected, imageUrl: chosenUrl));
      if (!mounted || revision != _revision) return;
      // Service emits errors itself; an applied ID is only useful after ready.
      if (state.status != DecartSessionStatus.error) {
        state = state.copyWith(
          appliedProductId: selected.id,
          appliedImageUrl: chosenUrl,
          selectedImageUrl: chosenUrl,
          isFrontCamera: _session.isUsingFrontCamera,
        );
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        state = state.copyWith(
          status: DecartSessionStatus.error,
          errorMessage: error is TryonFailure
              ? error.message
              : 'تعذر تحميل قطع الملابس أو بدء الجلسة.'.tr,
        );
      }
    } finally {
      _starting = false;
      finished.complete();
      _startFinished = null;
      _scheduleRecovery();
    }
  }

  void selectGarment(
    CustomerProduct product, {
    String? imageUrl,
    bool keepManualZone = false,
  }) {
    if (!mounted) return;
    final targetImage = (imageUrl?.trim().isNotEmpty ?? false)
        ? imageUrl!.trim()
        : product.tryonReferenceImage;
    final inferredZone = keepManualZone && state.zoneManuallySelected
        ? state.selectedZone
        : TryonBodyZone.infer(product.name, product.categoryName);
    if (!state.isConnected) {
      state = state.copyWith(
        selectedProduct: product,
        selectedImageUrl: targetImage,
        selectedZone: inferredZone,
        zoneManuallySelected: keepManualZone && state.zoneManuallySelected,
      );
      return;
    }
    if (state.selectedProduct?.id == product.id &&
        state.effectiveImageUrl == targetImage) {
      return;
    }
    ++_revision;
    _pending = product;
    _pendingImageUrl = targetImage;
    state = state.copyWith(
      selectedProduct: product,
      selectedImageUrl: targetImage,
      selectedZone: inferredZone,
      zoneManuallySelected: keepManualZone && state.zoneManuallySelected,
      isUpdating: true,
    );
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _drain);
  }

  /// Switches to another color/image of the currently selected product live.
  void selectGarmentImage(String imageUrl) {
    final current = state.selectedProduct;
    if (current == null || imageUrl.trim().isEmpty) return;
    selectGarment(current, imageUrl: imageUrl, keepManualZone: true);
  }

  Future<void> _drain() async {
    if (_draining || !mounted) return;
    _draining = true;
    try {
      while (_pending != null && mounted && state.isConnected) {
        final product = _pending!;
        final imageUrl = _pendingImageUrl ?? product.tryonReferenceImage;
        final revision = _revision;
        _pending = null;
        _pendingImageUrl = null;
        try {
          await _session.select(_garment(product, imageUrl: imageUrl));
          if (!mounted || revision != _revision) continue;
          state = state.copyWith(
            appliedProductId: product.id,
            appliedImageUrl: imageUrl,
            isUpdating: false,
          );
        } catch (error) {
          if (!mounted || revision != _revision) continue;
          state = state.copyWith(
            isUpdating: false,
            errorMessage: error is TryonFailure
                ? error.message
                : 'تعذر تحديث القطعة.'.tr,
          );
          // Allow the same rejected selection to be retried on the next tap.
          final applied = state.availableProducts
              .where((p) => p.id == state.appliedProductId)
              .firstOrNull;
          if (applied != null) {
            state = state.copyWith(
              selectedProduct: applied,
              selectedImageUrl:
                  state.appliedImageUrl ?? applied.tryonReferenceImage,
              errorMessage: state.errorMessage,
            );
          }
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> switchCamera() async {
    // Allow toggling camera both before connecting and during a live session.
    try {
      await _session.switchCamera();
      if (mounted) {
        state = state.copyWith(isFrontCamera: _session.isUsingFrontCamera);
      }
    } catch (_) {
      if (mounted) state = state.copyWith(errorMessage: 'تعذر تبديل الكاميرا.'.tr);
    }
  }

  Future<void> suspend() async {
    _suspended = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    ++_revision;
    _pending = null;
    _debounce?.cancel();
    if (mounted) {
      state = state.copyWith(
        status: DecartSessionStatus.disconnected,
        isUpdating: false,
        retryPending: false,
      );
    }
    await _session.stop();
  }

  Future<void> retry() => start();

  @override
  void dispose() {
    _suspended = true;
    _retryTimer?.cancel();
    ++_revision;
    _debounce?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_session.stop());
    super.dispose();
  }
}
