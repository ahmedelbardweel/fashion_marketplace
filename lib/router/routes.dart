class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const registerCustomer = '/register/customer';
  static const registerShop = '/register/shop';

  static const adminRoot = '/admin';
  static const adminHome = '/admin/home';
  static const adminStats = '/admin/stats';
  static const adminShopApplications = '/admin/shop-applications';
  static const adminShopReview = '/admin/shops/:shopId';
  static const adminShopsManage = '/admin/shops-manage';
  static const adminCategories = '/admin/categories';
  static const adminProducts = '/admin/products';
  static const adminUsers = '/admin/users';
  static const adminOrders = '/admin/orders';
  static const adminBanners = '/admin/banners';
  static const adminNotifications = '/admin/notifications';
  static const adminReports = '/admin/reports';
  static const adminSettings = '/admin/settings';

  static const shopRoot = '/shop';
  static const shopHome = '/shop/home';
  static const shopCompleteProfile = '/shop/complete-profile';
  static const shopStatus = '/shop/status';
  static const shopProducts = '/shop/products';
  static const shopProductForm = '/shop/product/new';
  static const shopProductEdit = '/shop/product/:productId';
  static const shopOrders = '/shop/orders';
  static const shopSales = '/shop/sales';
  static const shopNotifications = '/shop/notifications';
  static const shopProfile = '/shop/profile';

  static const customerRoot = '/customer';
  static const customerHome = '/customer/home';
  static const customerCompleteProfile = '/customer/complete-profile';
  static const customerCatalog = '/customer/catalog';
  static const customerShops = '/customer/shops';
  static const customerShopProfile = '/customer/shops/:shopId';
  static const customerProductDetails = '/customer/products/:productId';
  static const customerArTryon = '/customer/products/:productId/ar';
  static const customerRealtimeTryon =
      '/customer/products/:productId/realtime-tryon';
  static const customerFavorites = '/customer/favorites';
  static const customerCompare = '/customer/compare';
  static const customerCart = '/customer/cart';
  static const customerCheckout = '/customer/checkout';
  static const customerOrders = '/customer/orders';
  static const customerOrderDetails = '/customer/orders/:orderId';
  static const customerProfile = '/customer/profile';
  static const customerNotifications = '/customer/notifications';

  static String adminShopReviewPath(String shopId) => '/admin/shops/$shopId';
  static String shopProductEditPath(String productId) =>
      '/shop/product/$productId';
  static String customerShopProfilePath(String shopId) =>
      '/customer/shops/$shopId';
  static String customerProductDetailsPath(String productId) =>
      '/customer/products/$productId';
  static String customerArTryonPath(String productId) =>
      '/customer/products/$productId/ar';
  static String customerRealtimeTryonPath(String productId) =>
      '/customer/products/$productId/realtime-tryon';
  static String customerOrderDetailsPath(String orderId) =>
      '/customer/orders/$orderId';

  static String homeForRole(String role) {
    switch (role) {
      case 'admin':
        return adminHome;
      case 'shop':
        return shopHome;
      case 'customer':
      default:
        return customerHome;
    }
  }
}
