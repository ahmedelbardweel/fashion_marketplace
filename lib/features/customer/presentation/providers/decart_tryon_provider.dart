import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/supabase_config.dart';
import '../../../../core/services/decart_realtime_service.dart';
import '../../../virtual_tryon/data/decart_session_config.dart';
import '../../../virtual_tryon/data/tryon_errors.dart';
import '../../../virtual_tryon/data/capture_guard.dart';
import '../../../virtual_tryon/data/automatic_tryon_recovery.dart';
import '../../domain/models/customer_product.dart';
import 'customer_providers.dart';

export '../../../../core/services/decart_realtime_service.dart'
    show DecartSessionStatus;

typedef LoadTryonCatalog = Future<List<CustomerProduct>> Function();

class DecartTryonState {
  const DecartTryonState({
    this.status = DecartSessionStatus.idle,
    this.selectedProduct,
    this.appliedProductId,
    this.availableProducts = const [],
    this.isFrontCamera = true,
    this.isUpdating = false,
    this.errorMessage,
    this.retryPending = false,
    this.retryAttempt = 0,
  });
  final DecartSessionStatus status;
  final CustomerProduct? selectedProduct;
  final String? appliedProductId;
  final List<CustomerProduct> availableProducts;
  final bool isFrontCamera;
  final bool isUpdating;
  final String? errorMessage;
  final bool retryPending;
  final int retryAttempt;
  bool get isConnected => status == DecartSessionStatus.connected;
  bool get isOverlayLoading =>
      status == DecartSessionStatus.initializing ||
      status == DecartSessionStatus.connecting;

  DecartTryonState copyWith({
    DecartSessionStatus? status,
    CustomerProduct? selectedProduct,
    String? appliedProductId,
    List<CustomerProduct>? availableProducts,
    bool? isFrontCamera,
    bool? isUpdating,
    String? errorMessage,
    bool clearApplied = false,
    bool? retryPending,
    int? retryAttempt,
  }) => DecartTryonState(
    status: status ?? this.status,
    selectedProduct: selectedProduct ?? this.selectedProduct,
    appliedProductId: clearApplied
        ? null
        : appliedProductId ?? this.appliedProductId,
    availableProducts: availableProducts ?? this.availableProducts,
    isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    isUpdating: isUpdating ?? this.isUpdating,
    errorMessage: errorMessage, // null deliberately clears an earlier failure.
    retryPending: retryPending ?? this.retryPending,
    retryAttempt: retryAttempt ?? this.retryAttempt,
  );
}

final captureGuardProvider = ChangeNotifierProvider.autoDispose
    .family<CaptureGuardController, String>(
      (ref, id) => CaptureGuardController(),
    );

final decartRealtimeServiceProvider = Provider.autoDispose
    .family<DecartRealtimeService, String>((ref, productId) {
      final service = DecartRealtimeService(
        captureGuard: ref.read(captureGuardProvider(productId)),
        loadConfig: () async {
          try {
            final response = await SupabaseConfig.client.functions.invoke(
              'decart-session',
            );
            return DecartSessionConfig.fromJson(
              Map<String, dynamic>.from(response.data as Map),
            );
          } on FunctionException catch (error) {
            throw sessionHttpFailure(error.status);
          } on TryonFailure {
            rethrow;
          } catch (_) {
            throw const TryonFailure(
              'تعذر إعداد الجلسة. تحقق من تسجيل الدخول ونشر خدمة decart-session.',
            );
          }
        },
      );
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });

final decartTryonProvider = StateNotifierProvider.autoDispose
    .family<DecartTryonNotifier, DecartTryonState, String>((ref, id) {
      final service = ref.watch(decartRealtimeServiceProvider(id));
      // Capture dependencies now, never read a disposed Ref after an await.
      final repository = ref.read(customerRepositoryProvider);
      return DecartTryonNotifier(service, () async {
        final initial = await repository.getProductDetails(id);
        final catalog = await repository.getProducts();
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

  GarmentSelection _garment(CustomerProduct product) => GarmentSelection(
    id: product.id,
    name: product.name,
    imageUrl: product.tryonReferenceImage ?? '',
    category: product.categoryName,
    description: product.description,
  );

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
          throw const TryonFailure('لا توجد قطع بصور أمامية متاحة للتجربة.');
        }
        final initial = garments.where((p) => p.id == _initialId).firstOrNull;
        if (initial == null) {
          throw const TryonFailure(
            'المنتج المطلوب غير متاح للتجربة أو لا يملك صورة أمامية مناسبة. لم يتم استبداله بمنتج آخر.',
          );
        }
        state = state.copyWith(
          availableProducts: garments,
          selectedProduct: initial,
        );
      }
      final selected = state.selectedProduct!;
      await _session.start(_garment(selected));
      if (!mounted || revision != _revision) return;
      // Service emits errors itself; an applied ID is only useful after ready.
      if (state.status != DecartSessionStatus.error) {
        state = state.copyWith(
          appliedProductId: selected.id,
          isFrontCamera: _session.isUsingFrontCamera,
        );
      }
    } catch (error) {
      if (mounted && revision == _revision) {
        state = state.copyWith(
          status: DecartSessionStatus.error,
          errorMessage: error is TryonFailure
              ? error.message
              : 'تعذر تحميل قطع الملابس أو بدء الجلسة.',
        );
      }
    } finally {
      _starting = false;
      finished.complete();
      _startFinished = null;
      _scheduleRecovery();
    }
  }

  void selectGarment(CustomerProduct product) {
    if (!mounted ||
        !state.isConnected ||
        state.selectedProduct?.id == product.id) {
      return;
    }
    ++_revision;
    _pending = product;
    state = state.copyWith(selectedProduct: product, isUpdating: true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _drain);
  }

  Future<void> _drain() async {
    if (_draining || !mounted) return;
    _draining = true;
    try {
      while (_pending != null && mounted && state.isConnected) {
        final product = _pending!;
        final revision = _revision;
        _pending = null;
        try {
          await _session.select(_garment(product));
          if (!mounted || revision != _revision) continue;
          state = state.copyWith(
            appliedProductId: product.id,
            isUpdating: false,
          );
        } catch (error) {
          if (!mounted || revision != _revision) continue;
          state = state.copyWith(
            isUpdating: false,
            errorMessage: error is TryonFailure
                ? error.message
                : 'تعذر تحديث القطعة.',
          );
          // Allow the same rejected selection to be retried on the next tap.
          final applied = state.availableProducts
              .where((p) => p.id == state.appliedProductId)
              .firstOrNull;
          if (applied != null) {
            state = state.copyWith(
              selectedProduct: applied,
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
    if (!state.isConnected) return;
    try {
      await _session.switchCamera();
      if (mounted) {
        state = state.copyWith(isFrontCamera: _session.isUsingFrontCamera);
      }
    } catch (_) {
      if (mounted) state = state.copyWith(errorMessage: 'تعذر تبديل الكاميرا.');
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
