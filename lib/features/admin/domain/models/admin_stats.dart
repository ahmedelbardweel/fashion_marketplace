class AdminStats {
  const AdminStats({
    required this.customers,
    required this.shops,
    required this.pendingShops,
    required this.approvedShops,
    required this.suspendedShops,
    required this.products,
    required this.hiddenProducts,
    required this.orders,
    required this.categories,
    required this.banners,
    required this.notifications,
  });

  final int customers;
  final int shops;
  final int pendingShops;
  final int approvedShops;
  final int suspendedShops;
  final int products;
  final int hiddenProducts;
  final int orders;
  final int categories;
  final int banners;
  final int notifications;

  factory AdminStats.fromMap(Map<String, dynamic> map) {
    int read(String key) => (map[key] as num?)?.toInt() ?? 0;
    return AdminStats(
      customers: read('customers'),
      shops: read('shops'),
      pendingShops: read('pending_shops'),
      approvedShops: read('approved_shops'),
      suspendedShops: read('suspended_shops'),
      products: read('products'),
      hiddenProducts: read('hidden_products'),
      orders: read('orders'),
      categories: read('categories'),
      banners: read('banners'),
      notifications: read('notifications'),
    );
  }
}
