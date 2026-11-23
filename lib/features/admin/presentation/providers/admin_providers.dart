import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/filtering/filter_models.dart';
import '../../../../core/pagination/paginated_state.dart';
export '../../../../core/pagination/paginated_state.dart';

import '../../../auth/domain/models/app_user.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../customer/presentation/providers/customer_providers.dart';
import '../../../shop/domain/models/shop.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../../../shop/domain/models/shop_product.dart';
import '../../data/admin_repository.dart';
import '../../domain/models/admin_stats.dart';
import '../../domain/models/catalog_models.dart';
import '../../domain/models/decart_settings_status.dart';
import '../../domain/models/gaza_region.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/models/revenue_models.dart';
import '../../domain/models/subscription_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

bool _isAdmin(Ref ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.isAuthenticated && auth.user?.role == UserRole.admin;
}

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  if (!_isAdmin(ref)) {
    return const AdminStats(
      customers: 0,
      shops: 0,
      pendingShops: 0,
      approvedShops: 0,
      suspendedShops: 0,
      products: 0,
      hiddenProducts: 0,
      orders: 0,
      categories: 0,
      banners: 0,
      notifications: 0,
    );
  }
  return ref.watch(adminRepositoryProvider).fetchStats();
});

final adminUsersProvider = FutureProvider.autoDispose<List<AppUser>>((
  ref,
) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final adminManagedShopsProvider = FutureProvider.autoDispose<List<Shop>>((
  ref,
) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchManagedShops();
});

final adminCategoriesProvider =
    FutureProvider.autoDispose<List<CatalogCategory>>((ref) async {
      if (!_isAdmin(ref)) return const [];
      return ref.watch(adminRepositoryProvider).fetchCategories();
    });

final adminProductFilterProvider = StateProvider<AdminProductFilterState>((
  ref,
) {
  return AdminProductFilterState.empty;
});

/// Paginated admin product controller fetching [kProductPageSize] (6) items
/// per request with server-pushed filters and debounced search.
class PaginatedAdminProductsNotifier
    extends PaginatedListNotifier<AdminProduct> {
  PaginatedAdminProductsNotifier({
    required AdminRepository repository,
    required bool isAdmin,
    AdminProductFilterState initialFilter = AdminProductFilterState.empty,
  }) : _repository = repository,
       _isAdmin = isAdmin,
       _filter = initialFilter,
       super(
         fetcher: (offset, limit) => _fetchFilteredPage(
           repository: repository,
           isAdmin: isAdmin,
           offset: offset,
           limit: limit,
           filter: initialFilter,
         ),
         itemId: (item) => item.id,
       );

  final AdminRepository _repository;
  final bool _isAdmin;
  AdminProductFilterState _filter;
  Timer? _searchDebounce;

  static Future<PaginatedPage<AdminProduct>> _fetchFilteredPage({
    required AdminRepository repository,
    required bool isAdmin,
    required int offset,
    required int limit,
    required AdminProductFilterState filter,
  }) async {
    if (!isAdmin) {
      return const PaginatedPage<AdminProduct>(items: [], rawCount: 0);
    }
    final page = await repository.fetchProductsPage(
      limit: limit,
      offset: offset,
      status: filter.status,
      minPrice: filter.minPrice,
      maxPrice: filter.maxPrice,
      search: filter.search,
      sort: filter.sort,
    );
    final refined = filterAdminProducts(page.items, filter);
    return PaginatedPage<AdminProduct>(
      items: refined,
      rawCount: page.rawCount ?? page.items.length,
      totalCount: page.totalCount,
    );
  }

  void updateFilter(AdminProductFilterState next, {bool force = false}) {
    if (!force && next == _filter) return;
    final searchChanged = next.search != _filter.search;
    _filter = next;
    _searchDebounce?.cancel();

    if (searchChanged && next.search.trim().isNotEmpty) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _resetForCurrentFilter();
      });
    } else {
      _resetForCurrentFilter();
    }
  }

  void _resetForCurrentFilter() {
    final activeFilter = _filter;
    resetWithFetcher(
      (offset, limit) => _fetchFilteredPage(
        repository: _repository,
        isAdmin: _isAdmin,
        offset: offset,
        limit: limit,
        filter: activeFilter,
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final adminProductsPaginatedProvider =
    StateNotifierProvider.autoDispose<
      PaginatedAdminProductsNotifier,
      PaginatedListState<AdminProduct>
    >((ref) {
      final isAdmin = _isAdmin(ref);
      final repository = ref.watch(adminRepositoryProvider);
      final initialFilter = ref.read(adminProductFilterProvider);
      final notifier = PaginatedAdminProductsNotifier(
        repository: repository,
        isAdmin: isAdmin,
        initialFilter: initialFilter,
      );
      ref.listen<AdminProductFilterState>(
        adminProductFilterProvider,
        (previous, next) => notifier.updateFilter(next),
      );
      return notifier;
    });

final adminOrdersProvider = FutureProvider.autoDispose<List<AdminOrder>>((
  ref,
) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchOrders();
});

final adminBannersProvider = FutureProvider.autoDispose<List<AdminBanner>>((
  ref,
) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchBanners();
});

final adminActiveOffersProvider =
    FutureProvider.autoDispose<List<AdminProduct>>((ref) async {
      if (!_isAdmin(ref)) return const [];
      return ref.watch(adminRepositoryProvider).fetchActiveOffers();
    });

/// Active Gaza Strip regions available across Customer, Shop, and Admin forms.
final gazaRegionsProvider = FutureProvider.autoDispose<List<GazaRegion>>((
  ref,
) async {
  return ref.watch(adminRepositoryProvider).fetchGazaRegions(activeOnly: true);
});

/// Full Gaza Strip regions list (including inactive) for Admin management.
final adminGazaRegionsProvider = FutureProvider.autoDispose<List<GazaRegion>>((
  ref,
) async {
  if (!_isAdmin(ref)) return const [];
  return ref.watch(adminRepositoryProvider).fetchGazaRegions(activeOnly: false);
});

/// Active bank & e-wallet transfer methods for Customers (Checkout & Order Details).
final activePaymentMethodsProvider =
    FutureProvider.autoDispose<List<PaymentMethod>>((ref) async {
      return ref
          .watch(adminRepositoryProvider)
          .fetchPaymentMethods(activeOnly: true);
    });

/// Full list of bank & e-wallet transfer methods (active + paused) for Admin.
final adminPaymentMethodsProvider =
    FutureProvider.autoDispose<List<PaymentMethod>>((ref) async {
      if (!_isAdmin(ref)) return const [];
      return ref
          .watch(adminRepositoryProvider)
          .fetchPaymentMethods(activeOnly: false);
    });

final adminRevenueOverviewProvider =
    FutureProvider.autoDispose<AdminRevenueOverview>((ref) async {
      if (!_isAdmin(ref)) return const AdminRevenueOverview();
      return ref.watch(adminRepositoryProvider).fetchRevenueOverview();
    });

final adminSubscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
      if (!_isAdmin(ref)) return const [];
      return ref
          .watch(adminRepositoryProvider)
          .fetchSubscriptionPlans(activeOnly: false);
    });

final adminSubscriptionPayoutOverviewProvider =
    FutureProvider.autoDispose<AdminSubscriptionPayoutOverview>((ref) async {
      if (!_isAdmin(ref)) return const AdminSubscriptionPayoutOverview();
      return ref
          .watch(adminRepositoryProvider)
          .fetchSubscriptionPayoutOverview();
    });

final adminShopFinancialStatementProvider = FutureProvider.autoDispose
    .family<ShopFinancialStatement, String>((ref, shopId) async {
      if (!_isAdmin(ref)) {
        return ShopFinancialStatement(shopId: shopId, shopName: '');
      }
      return ref
          .watch(adminRepositoryProvider)
          .fetchShopFinancialStatement(shopId);
    });

final adminShopLedgerProvider = FutureProvider.autoDispose.family<
  ({List<CommissionLedgerEntry> ledger, List<ShopSettlement> settlements}),
  String
>((ref, shopId) async {
  if (!_isAdmin(ref)) {
    return (
      ledger: const <CommissionLedgerEntry>[],
      settlements: const <ShopSettlement>[],
    );
  }
  return ref.watch(adminRepositoryProvider).fetchShopLedger(shopId);
});

final adminNotificationsProvider =
    FutureProvider.autoDispose<List<AdminNotification>>((ref) async {
      if (!_isAdmin(ref)) return const [];
      return ref.watch(adminRepositoryProvider).fetchNotifications();
    });

final adminDecartStatusProvider =
    FutureProvider.autoDispose<DecartSettingsStatus>((ref) async {
      if (!_isAdmin(ref)) throw StateError('Admin access required');
      return ref.watch(adminRepositoryProvider).fetchDecartStatus();
    });

final adminDecartCreditsProvider =
    FutureProvider.autoDispose<DecartCreditsBalance>((ref) async {
      if (!_isAdmin(ref)) {
        return const DecartCreditsBalance(configured: false);
      }
      return ref.watch(adminRepositoryProvider).fetchDecartCredits();
    });

final adminDecartKeysProvider =
    FutureProvider.autoDispose<List<DecartApiKeyEntry>>((ref) async {
      if (!_isAdmin(ref)) return const [];
      return ref.watch(adminRepositoryProvider).fetchDecartKeys();
    });

final adminTryonControlsProvider =
    FutureProvider.autoDispose<TryonCostControls>((ref) async {
      if (!_isAdmin(ref)) throw StateError('Admin access required');
      return ref.watch(adminRepositoryProvider).fetchTryonControls();
    });

final adminSettingsProvider = FutureProvider.autoDispose<List<PlatformSetting>>(
  (ref) async {
    if (!_isAdmin(ref)) return const [];
    return ref.watch(adminRepositoryProvider).fetchSettings();
  },
);

final adminShopDocumentsProvider = FutureProvider.autoDispose
    .family<List<ShopDocument>, String>((ref, shopId) async {
      if (!_isAdmin(ref)) return const [];
      return ref.watch(adminRepositoryProvider).fetchShopDocuments(shopId);
    });

final adminShopImagesProvider = FutureProvider.autoDispose
    .family<List<ShopMediaItem>, String>((ref, shopId) async {
      if (!_isAdmin(ref)) return const [];
      return ref.watch(adminRepositoryProvider).fetchShopImages(shopId);
    });

final adminActionProvider =
    StateNotifierProvider<AdminActionController, AsyncValue<void>>(
      (ref) => AdminActionController(ref),
    );

class AdminActionController extends StateNotifier<AsyncValue<void>> {
  AdminActionController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  AdminRepository get _repo => _ref.read(adminRepositoryProvider);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return false;
    }
  }

  String errorMessage(Object error) => _repo.mapError(error);

  Future<bool> setUserActive({required String userId, required bool isActive}) {
    return _run(() async {
      await _repo.setUserActive(userId: userId, isActive: isActive);
      _ref.invalidate(adminUsersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> setShopSuspended({
    required String shopId,
    required bool suspend,
  }) {
    return _run(() async {
      await _repo.setShopSuspended(shopId: shopId, suspend: suspend);
      _ref.invalidate(adminManagedShopsProvider);
      _ref.invalidate(adminShopApplicationsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> upsertCategory({
    required String name,
    String? description,
    bool isActive = true,
    String? id,
    String? parentId,
    String? iconKey,
  }) {
    return _run(() async {
      await _repo.upsertCategory(
        name: name,
        description: description,
        isActive: isActive,
        id: id,
        parentId: parentId,
        iconKey: iconKey,
      );
      _ref.invalidate(adminCategoriesProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> setProductStatus({
    required String productId,
    required String status,
  }) {
    return _run(() async {
      await _repo.setProductStatus(productId: productId, status: status);
      if (_ref.exists(adminProductsPaginatedProvider)) {
        _ref.read(adminProductsPaginatedProvider.notifier).refresh();
      }
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> upsertBanner({
    required String title,
    String? subtitle,
    String? imagePath,
    String? ctaLabel,
    int sortOrder = 0,
    bool isActive = true,
    String? id,
  }) {
    return _run(() async {
      await _repo.upsertBanner(
        title: title,
        subtitle: subtitle,
        imagePath: imagePath,
        ctaLabel: ctaLabel,
        sortOrder: sortOrder,
        isActive: isActive,
        id: id,
      );
      _ref.invalidate(adminBannersProvider);
      _ref.invalidate(customerBannersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> deleteBanner(String id) {
    return _run(() async {
      await _repo.deleteBanner(id);
      _ref.invalidate(adminBannersProvider);
      _ref.invalidate(customerBannersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> cancelProductOffer(String productId) {
    return _run(() async {
      await _repo.cancelProductOffer(productId);
      _ref.invalidate(adminActiveOffersProvider);
      if (_ref.exists(adminProductsPaginatedProvider)) {
        _ref.read(adminProductsPaginatedProvider.notifier).refresh();
      }
      _ref.invalidate(adminBannersProvider);
      _ref.invalidate(customerBannersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
  }) {
    return _run(() async {
      await _repo.updateOrderStatus(orderId: orderId, status: status);
      _ref.invalidate(adminOrdersProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<int?> verifyOrderPayment({
    required String orderId,
    required bool approved,
    String? issueNote,
    bool applyToGroup = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final count = await _repo.verifyOrderPayment(
        orderId: orderId,
        approved: approved,
        issueNote: issueNote,
        applyToGroup: applyToGroup,
      );
      _ref.invalidate(adminOrdersProvider);
      _ref.invalidate(adminStatsProvider);
      _ref.invalidate(adminSubscriptionPayoutOverviewProvider);
      state = const AsyncValue.data(null);
      return count;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      return null;
    }
  }

  Future<bool> upsertRegion({
    required String name,
    String? nameEn,
    String? parentId,
    double deliveryFee = 10,
    String estimatedDelivery = 'نفس اليوم',
    bool isDeliveryAvailable = true,
    bool isActive = true,
    int sortOrder = 0,
    String? id,
  }) {
    return _run(() async {
      await _repo.upsertRegion(
        name: name,
        nameEn: nameEn,
        parentId: parentId,
        deliveryFee: deliveryFee,
        estimatedDelivery: estimatedDelivery,
        isDeliveryAvailable: isDeliveryAvailable,
        isActive: isActive,
        sortOrder: sortOrder,
        id: id,
      );
      _ref.invalidate(adminGazaRegionsProvider);
      _ref.invalidate(gazaRegionsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> deleteRegion(String id) {
    return _run(() async {
      await _repo.deleteRegion(id);
      _ref.invalidate(adminGazaRegionsProvider);
      _ref.invalidate(gazaRegionsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> toggleRegionDelivery({
    required String id,
    required bool isDeliveryAvailable,
  }) {
    return _run(() async {
      await _repo.toggleRegionDelivery(
        id: id,
        isDeliveryAvailable: isDeliveryAvailable,
      );
      _ref.invalidate(adminGazaRegionsProvider);
      _ref.invalidate(gazaRegionsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> sendNotification({
    required String title,
    required String body,
    required String audience,
    String? targetRegion,
  }) {
    return _run(() async {
      await _repo.sendNotification(
        title: title,
        body: body,
        audience: audience,
        targetRegion: targetRegion,
      );
      _ref.invalidate(adminNotificationsProvider);
      _ref.invalidate(adminStatsProvider);
    });
  }

  Future<bool> updateSetting({required String key, required String value}) {
    return _run(() async {
      await _repo.updateSetting(key: key, value: value);
      _ref.invalidate(adminSettingsProvider);
    });
  }

  Future<bool> updateShopAgreement({
    required String shopId,
    required String commissionType,
    required double commissionRate,
    double commissionFixedFee = 0,
    double creditLimit = 300,
    String settlementCycle = 'weekly',
    bool autoSuspendOnLimit = true,
    String? agreementNotes,
  }) {
    return _run(() async {
      await _repo.updateShopAgreement(
        shopId: shopId,
        commissionType: commissionType,
        commissionRate: commissionRate,
        commissionFixedFee: commissionFixedFee,
        creditLimit: creditLimit,
        settlementCycle: settlementCycle,
        autoSuspendOnLimit: autoSuspendOnLimit,
        agreementNotes: agreementNotes,
      );
      _ref.invalidate(adminRevenueOverviewProvider);
      _ref.invalidate(adminManagedShopsProvider);
    });
  }

  Future<bool> setShopFinancialHold({
    required String shopId,
    required bool hold,
  }) {
    return _run(() async {
      await _repo.setShopFinancialHold(shopId: shopId, hold: hold);
      _ref.invalidate(adminRevenueOverviewProvider);
      _ref.invalidate(adminManagedShopsProvider);
    });
  }

  Future<bool> reviewSettlement({
    required String settlementId,
    required bool approve,
    String? adminNote,
  }) {
    return _run(() async {
      await _repo.reviewSettlement(
        settlementId: settlementId,
        approve: approve,
        adminNote: adminNote,
      );
      _ref.invalidate(adminRevenueOverviewProvider);
    });
  }

  Future<bool> upsertPaymentMethod({
    String? id,
    required String name,
    required String accountNumber,
    String type = 'bank',
    String? nameEn,
    String? iban,
    String? accountHolder,
    String? instructions,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    return _run(() async {
      await _repo.upsertPaymentMethod(
        id: id,
        name: name,
        accountNumber: accountNumber,
        type: type,
        nameEn: nameEn,
        iban: iban,
        accountHolder: accountHolder,
        instructions: instructions,
        isActive: isActive,
        sortOrder: sortOrder,
      );
      _ref.invalidate(adminPaymentMethodsProvider);
      _ref.invalidate(activePaymentMethodsProvider);
    });
  }

  Future<bool> togglePaymentMethod({
    required String id,
    required bool isActive,
  }) {
    return _run(() async {
      await _repo.togglePaymentMethod(id: id, isActive: isActive);
      _ref.invalidate(adminPaymentMethodsProvider);
      _ref.invalidate(activePaymentMethodsProvider);
    });
  }

  Future<bool> deletePaymentMethod(String id) {
    return _run(() async {
      await _repo.deletePaymentMethod(id);
      _ref.invalidate(adminPaymentMethodsProvider);
      _ref.invalidate(activePaymentMethodsProvider);
    });
  }

  Future<bool> recordShopPayment({
    required String shopId,
    required double amount,
    String paymentMethod = 'cash',
    String? referenceNumber,
    String? note,
  }) {
    return _run(() async {
      await _repo.recordShopPayment(
        shopId: shopId,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        note: note,
      );
      _ref.invalidate(adminRevenueOverviewProvider);
      _ref.invalidate(adminShopLedgerProvider(shopId));
    });
  }

  Future<bool> upsertSubscriptionPlan({
    String? id,
    required String name,
    String? nameEn,
    String? description,
    required double price,
    required int durationDays,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    return _run(() async {
      await _repo.upsertSubscriptionPlan(
        id: id,
        name: name,
        nameEn: nameEn,
        description: description,
        price: price,
        durationDays: durationDays,
        isActive: isActive,
        sortOrder: sortOrder,
      );
      _ref.invalidate(adminSubscriptionPlansProvider);
      _ref.invalidate(activeSubscriptionPlansProvider);
    });
  }

  Future<bool> toggleSubscriptionPlan({
    required String id,
    required bool isActive,
  }) {
    return _run(() async {
      await _repo.toggleSubscriptionPlan(id: id, isActive: isActive);
      _ref.invalidate(adminSubscriptionPlansProvider);
      _ref.invalidate(activeSubscriptionPlansProvider);
    });
  }

  Future<bool> deleteSubscriptionPlan(String id) {
    return _run(() async {
      await _repo.deleteSubscriptionPlan(id);
      _ref.invalidate(adminSubscriptionPlansProvider);
      _ref.invalidate(activeSubscriptionPlansProvider);
    });
  }

  Future<bool> reviewSubscription({
    required String subscriptionId,
    required bool approve,
    String? rejectionReason,
    String? shopId,
  }) {
    return _run(() async {
      await _repo.reviewSubscription(
        subscriptionId: subscriptionId,
        approve: approve,
        rejectionReason: rejectionReason,
      );
      _ref.invalidate(adminSubscriptionPayoutOverviewProvider);
      _ref.invalidate(adminShopApplicationsProvider);
      _ref.invalidate(adminManagedShopsProvider);
      _ref.invalidate(adminStatsProvider);
      if (shopId != null) {
        _ref.invalidate(adminShopFinancialStatementProvider(shopId));
        _ref.invalidate(adminShopByIdProvider(shopId));
      }
    });
  }

  Future<bool> recordShopPayout({
    required String shopId,
    required double amount,
    String paymentMethod = 'bank_transfer',
    String? referenceNo,
    String? receiptUrl,
    String? notes,
  }) {
    return _run(() async {
      await _repo.recordShopPayout(
        shopId: shopId,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNo: referenceNo,
        receiptUrl: receiptUrl,
        notes: notes,
      );
      _ref.invalidate(adminSubscriptionPayoutOverviewProvider);
      _ref.invalidate(adminShopFinancialStatementProvider(shopId));
    });
  }
}
