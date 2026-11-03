import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/models/app_user.dart';
import '../features/auth/domain/models/user_role.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/shop/domain/models/shop.dart';
import '../features/shop/presentation/providers/shop_providers.dart';
import 'routes.dart';

class SessionGate {
  const SessionGate({
    required this.status,
    this.user,
    this.shop,
    this.shopLoading = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final Shop? shop;
  final bool shopLoading;

  String? destination() {
    if (status != AuthStatus.authenticated || user == null) return null;

    switch (user!.role) {
      case UserRole.admin:
        return AppRoutes.adminHome;
      case UserRole.customer:
        if (!user!.profileCompleted) {
          return AppRoutes.customerCompleteProfile;
        }
        return AppRoutes.customerHome;
      case UserRole.shop:
        if (shopLoading && shop == null) return null;
        return shopDestination(shop);
    }
  }

  static String shopDestination(Shop? shop) {
    if (shop == null || shop.status == ShopStatus.draft) {
      return AppRoutes.shopCompleteProfile;
    }

    switch (shop.visibleStatus) {
      case ShopStatus.approved:
        return AppRoutes.shopHome;
      case ShopStatus.draft:
        return AppRoutes.shopCompleteProfile;
      case ShopStatus.pending:
      case ShopStatus.rejected:
      case ShopStatus.suspended:
        return AppRoutes.shopStatus;
    }
  }

  bool get canShopEditProfile {
    if (shop == null) return true;
    return shop!.visibleStatus == ShopStatus.draft ||
        shop!.visibleStatus == ShopStatus.rejected;
  }
}

final sessionGateProvider = Provider<SessionGate>((ref) {
  final auth = ref.watch(authControllerProvider);

  if (!auth.isAuthenticated || auth.user?.role != UserRole.shop) {
    return SessionGate(
      status: auth.status,
      user: auth.user,
    );
  }

  final shopAsync = ref.watch(myShopProvider);
  final hasShopValue = shopAsync.hasValue;
  return SessionGate(
    status: auth.status,
    user: auth.user,
    shop: shopAsync.asData?.value,
    shopLoading: shopAsync.isLoading && !hasShopValue,
  );
});
