import '../../features/admin/domain/models/catalog_models.dart';
import '../../features/admin/domain/models/admin_stats.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/customer/domain/models/customer_product.dart'
    as customer;
import '../../features/customer/domain/models/customer_order.dart';
import '../../features/customer/domain/models/customer_shop.dart';
import '../../features/shop/domain/models/shop.dart';
import '../../features/shop/domain/models/shop_product.dart' as seller;

/// Presentation-only shapes. No IDs or values here are sent to a repository.
abstract final class LoadingFixtures {
  static const map = <String, dynamic>{
    'id': 'loading-placeholder-0001',
    'shop_id': 'loading-shop-0001',
    'owner_id': 'loading-owner-0001',
    'name': 'اسم العنصر المعروض',
    'title': 'عنوان المحتوى',
    'subtitle': 'تفاصيل المحتوى المعروض',
    'description': 'وصف وتفاصيل المحتوى المعروض في هذه الصفحة',
    'body': 'تفاصيل الإشعار والمعلومات المرتبطة به',
    'shop_name': 'اسم متجر الأزياء',
    'city': 'المدينة',
    'address': 'عنوان المتجر',
    'status': 'pending',
    'visible_status': 'pending',
    'email': 'name@example.test',
    'full_name': 'اسم المستخدم',
    'phone': '0000000000',
    'price': 120,
    'total': 240,
    'created_at': '2026-01-01T00:00:00Z',
  };
  static List<T> copies<T>(T value, [int count = 4]) =>
      List.filled(count, value);
  static final product = customer.CustomerProduct.fromMap(
    map,
    variants: [
      customer.ProductVariant.fromMap({
        ...map,
        'color': 'أسود',
        'size': 'M',
        'stock': 12,
      }),
    ],
    images: [
      customer.ProductImage.fromMap({
        ...map,
        'file_path': 'skeleton://image',
        'kind': 'gallery',
      }),
    ],
  );
  static final products = copies(product, 6);
  static final customerShop = CustomerShop.fromMap({
    ...map,
    'logo_path': 'skeleton://logo',
    'cover_path': 'skeleton://cover',
  });
  static final customerShops = copies(customerShop);
  static final order = CustomerOrder.fromMap(
    map,
    items: [
      CustomerOrderItem.fromMap({
        ...map,
        'product_name': 'اسم قطعة الملابس',
        'variant_info': 'أسود · M',
        'quantity': 2,
      }),
    ],
  );
  static final orders = copies(order);
  static final categories = copies(CatalogCategory.fromMap(map));
  static final banners = copies(AdminBanner.fromMap(map), 2);
  static final notifications = copies(AdminNotification.fromMap(map));
  static final adminProducts = copies(AdminProduct.fromMap(map));
  static final adminOrders = copies(AdminOrder.fromMap(map));
  static final users = copies(AppUser.fromMap(map));
  static final shop = Shop.fromMap(map);
  static final shops = copies(shop);
  static final stats = AdminStats.fromMap(const {
    'customers': 24,
    'shops': 12,
    'products': 48,
    'orders': 32,
  });
  static final shopStats = seller.ShopStats.fromMap(const {
    'products': 24,
    'orders': 12,
    'sales_total': 1200,
  });
  static final shopProducts = copies(
    seller.ShopProduct.fromMap({...map, 'status': 'published'}),
  );
  static final shopOrders = copies(seller.ShopOrder.fromMap(map));
  static final media = copies(
    seller.ShopMediaItem.fromMap({
      ...map,
      'file_path': 'skeleton://image',
      'kind': 'gallery',
    }),
    2,
  );
  static final documents = copies(
    ShopDocument.fromMap({...map, 'doc_type': 'سجل تجاري'}),
    2,
  );
  static final settings = copies(
    PlatformSetting.fromMap(const {
      'key': 'setting',
      'label': 'إعداد المنصة',
      'value': 'قيمة الإعداد',
    }),
  );
}
