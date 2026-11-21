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
    this.activeOffers = 0,
    this.todayOrders = 0,
    this.todaySales = 0,
    this.totalSales = 0,
    this.regionsTotal = 0,
    this.activeRegions = 0,
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
  final int activeOffers;
  final int todayOrders;
  final double todaySales;
  final double totalSales;
  final int regionsTotal;
  final int activeRegions;

  factory AdminStats.fromMap(Map<String, dynamic> map) {
    int readInt(String key) => (map[key] as num?)?.toInt() ?? 0;
    double readDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return AdminStats(
      customers: readInt('customers'),
      shops: readInt('shops'),
      pendingShops: readInt('pending_shops'),
      approvedShops: readInt('approved_shops'),
      suspendedShops: readInt('suspended_shops'),
      products: readInt('products'),
      hiddenProducts: readInt('hidden_products'),
      orders: readInt('orders'),
      categories: readInt('categories'),
      banners: readInt('banners'),
      notifications: readInt('notifications'),
      activeOffers: readInt('active_offers'),
      todayOrders: readInt('today_orders'),
      todaySales: readDouble('today_sales'),
      totalSales: readDouble('total_sales'),
      regionsTotal: readInt('regions_total'),
      activeRegions: readInt('active_regions'),
    );
  }
}
