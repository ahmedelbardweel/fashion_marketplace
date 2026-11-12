import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/screens/admin_banners_screen.dart';
import '../features/admin/presentation/screens/admin_categories_screen.dart';
import '../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../features/admin/presentation/screens/admin_notifications_screen.dart';
import '../features/admin/presentation/screens/admin_orders_screen.dart';
import '../features/admin/presentation/screens/admin_products_screen.dart';
import '../features/admin/presentation/screens/admin_reports_screen.dart';
import '../features/admin/presentation/screens/admin_settings_screen.dart';
import '../features/admin/presentation/screens/admin_shop_applications_screen.dart';
import '../features/admin/presentation/screens/admin_shop_review_screen.dart';
import '../features/admin/presentation/screens/admin_shops_manage_screen.dart';
import '../features/admin/presentation/screens/admin_stats_screen.dart';
import '../features/admin/presentation/screens/admin_users_screen.dart';
import '../features/auth/domain/models/user_role.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_choice_screen.dart';
import '../features/auth/presentation/screens/register_customer_screen.dart';
import '../features/auth/presentation/screens/register_shop_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/customer/presentation/screens/cart_screen.dart';
import '../features/customer/presentation/screens/checkout_screen.dart';
import '../features/customer/presentation/screens/customer_catalog_screen.dart';
import '../features/customer/presentation/screens/customer_complete_profile_screen.dart';
import '../features/customer/presentation/screens/customer_dashboard_screen.dart';
import '../features/customer/presentation/screens/customer_favorites_screen.dart';
import '../features/customer/presentation/screens/customer_notifications_screen.dart';
import '../features/customer/presentation/screens/customer_orders_screen.dart';
import '../features/customer/presentation/screens/customer_profile_screen.dart';
import '../features/customer/presentation/screens/customer_shops_screen.dart';
import '../features/customer/presentation/screens/order_details_screen.dart';
import '../features/customer/presentation/screens/decart_tryon_screen.dart';
import '../features/customer/presentation/screens/product_comparison_screen.dart';
import '../features/customer/presentation/screens/product_details_screen.dart';
import '../features/customer/presentation/screens/shop_public_profile_screen.dart';
import '../features/shop/domain/models/shop.dart';
import '../features/shop/presentation/screens/shop_application_status_screen.dart';
import '../features/shop/presentation/screens/shop_complete_profile_screen.dart';
import '../features/shop/presentation/screens/shop_dashboard_screen.dart';
import '../features/shop/presentation/screens/shop_notifications_screen.dart';
import '../features/shop/presentation/screens/shop_orders_screen.dart';
import '../features/shop/presentation/screens/shop_product_form_screen.dart';
import '../features/shop/presentation/screens/shop_products_screen.dart';
import '../features/shop/presentation/screens/shop_profile_screen.dart';
import '../features/shop/presentation/screens/shop_sales_screen.dart';
import 'routes.dart';
import 'session_gate.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class GoRouterRefresh extends ChangeNotifier {
  GoRouterRefresh(Ref ref) {
    ref.listen<AuthSessionState>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
    ref.listen<SessionGate>(
      sessionGateProvider,
      (previous, next) => notifyListeners(),
    );
    ref.listen<bool>(
      splashCompletedProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefresh(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final gate = ref.read(sessionGateProvider);
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      final isSplash = location == AppRoutes.splash;
      final isSplashDone = ref.read(splashCompletedProvider);
      if (!isSplashDone) {
        return isSplash ? null : AppRoutes.splash;
      }

      final isAuthRoute =
          location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.registerCustomer ||
          location == AppRoutes.registerShop;

      if (auth.status == AuthStatus.unknown) {
        return isSplash ? null : AppRoutes.splash;
      }

      if (auth.status == AuthStatus.unauthenticated) {
        if (isSplash) return AppRoutes.login;
        if (isAuthRoute) return null;
        return AppRoutes.login;
      }

      final user = auth.user;
      if (user == null) return AppRoutes.login;

      final onShopRoute = location.startsWith(AppRoutes.shopRoot);
      if (user.role == UserRole.shop && gate.shopLoading) {
        if (isSplash || onShopRoute) return null;
      }

      final destination = gate.destination();
      if (destination == null) {
        if (isSplash || onShopRoute) return null;
        return AppRoutes.splash;
      }

      if (isSplash || isAuthRoute) return destination;

      final goingAdmin = location.startsWith(AppRoutes.adminRoot);
      final goingShop = location.startsWith(AppRoutes.shopRoot);
      final goingCustomer = location.startsWith(AppRoutes.customerRoot);

      switch (user.role) {
        case UserRole.admin:
          if (goingShop || goingCustomer) return destination;
          return null;
        case UserRole.customer:
          if (goingAdmin || goingShop) return destination;
          if (!user.profileCompleted &&
              location != AppRoutes.customerCompleteProfile) {
            return AppRoutes.customerCompleteProfile;
          }
          if (user.profileCompleted &&
              location == AppRoutes.customerCompleteProfile) {
            return AppRoutes.customerHome;
          }
          return null;
        case UserRole.shop:
          if (goingAdmin || goingCustomer) return destination;
          final shopStatus = gate.shop?.visibleStatus;
          final rawStatus = gate.shop?.status;

          if (shopStatus == ShopStatus.approved) {
            if (location == AppRoutes.shopStatus ||
                location == AppRoutes.shopCompleteProfile) {
              return AppRoutes.shopHome;
            }
            return goingShop ? null : destination;
          }

          if (rawStatus == null ||
              rawStatus == ShopStatus.draft ||
              shopStatus == ShopStatus.draft) {
            return location == AppRoutes.shopCompleteProfile
                ? null
                : AppRoutes.shopCompleteProfile;
          }

          if (location == AppRoutes.shopStatus) return null;
          if (location == AppRoutes.shopCompleteProfile &&
              gate.canShopEditProfile) {
            return null;
          }
          return AppRoutes.shopStatus;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterChoiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerCustomer,
        builder: (context, state) => const RegisterCustomerScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerShop,
        builder: (context, state) => const RegisterShopScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminHome,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminStats,
        builder: (context, state) => const AdminStatsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminShopApplications,
        builder: (context, state) => const AdminShopApplicationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminShopReview,
        builder: (context, state) =>
            AdminShopReviewScreen(shopId: state.pathParameters['shopId']!),
      ),
      GoRoute(
        path: AppRoutes.adminShopsManage,
        builder: (context, state) => const AdminShopsManageScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCategories,
        builder: (context, state) => const AdminCategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminProducts,
        builder: (context, state) => const AdminProductsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminOrders,
        builder: (context, state) => const AdminOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminBanners,
        builder: (context, state) => const AdminBannersScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminNotifications,
        builder: (context, state) => const AdminNotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminReports,
        builder: (context, state) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminSettings,
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopHome,
        builder: (context, state) => const ShopDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopCompleteProfile,
        builder: (context, state) => const ShopCompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopStatus,
        builder: (context, state) => const ShopApplicationStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopProducts,
        builder: (context, state) => const ShopProductsScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopProductForm,
        builder: (context, state) => const ShopProductFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopProductEdit,
        builder: (context, state) =>
            ShopProductFormScreen(productId: state.pathParameters['productId']),
      ),
      GoRoute(
        path: AppRoutes.shopOrders,
        builder: (context, state) => const ShopOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopSales,
        builder: (context, state) => const ShopSalesScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopNotifications,
        builder: (context, state) => const ShopNotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.shopProfile,
        builder: (context, state) => const ShopProfileScreen(),
      ),
      // Customer Routes
      GoRoute(
        path: AppRoutes.customerHome,
        builder: (context, state) => const CustomerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerCompleteProfile,
        builder: (context, state) => const CustomerCompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerCatalog,
        builder: (context, state) => const CustomerCatalogScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerShops,
        builder: (context, state) => const CustomerShopsScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerShopProfile,
        builder: (context, state) => ShopPublicProfileScreen(
          shopId: state.pathParameters['shopId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.customerProductDetails,
        builder: (context, state) => ProductDetailsScreen(
          productId: state.pathParameters['productId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.customerArTryon,
        builder: (context, state) => DecartTryonScreen(
          productId: state.pathParameters['productId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.customerRealtimeTryon,
        builder: (context, state) => DecartTryonScreen(
          productId: state.pathParameters['productId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.customerFavorites,
        builder: (context, state) => const CustomerFavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerCompare,
        builder: (context, state) => const ProductComparisonScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerCart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerCheckout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerOrders,
        builder: (context, state) => const CustomerOrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerOrderDetails,
        builder: (context, state) =>
            OrderDetailsScreen(orderId: state.pathParameters['orderId'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.customerProfile,
        builder: (context, state) => const CustomerProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerNotifications,
        builder: (context, state) => const CustomerNotificationsScreen(),
      ),
    ],
  );
});
