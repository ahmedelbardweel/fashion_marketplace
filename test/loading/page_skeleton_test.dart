import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fashion_marketplace/core/widgets/app_skeleton.dart';
import 'package:fashion_marketplace/core/widgets/product_grid_card.dart';
import 'package:fashion_marketplace/features/customer/presentation/providers/customer_providers.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/customer_home_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/customer_catalog_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/customer_orders_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/customer_notifications_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/customer_shops_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/customer_favorites_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/product_details_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/order_details_screen.dart';
import 'package:fashion_marketplace/features/customer/presentation/screens/shop_public_profile_screen.dart';
import 'package:fashion_marketplace/features/customer/data/customer_repository.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:fashion_marketplace/features/admin/presentation/providers/admin_providers.dart';
import 'package:fashion_marketplace/features/admin/presentation/screens/admin_stats_screen.dart';
import 'package:fashion_marketplace/features/admin/presentation/screens/admin_orders_screen.dart';
import 'package:fashion_marketplace/features/admin/presentation/screens/admin_categories_screen.dart';
import 'package:fashion_marketplace/features/shop/presentation/providers/shop_catalog_providers.dart';
import 'package:fashion_marketplace/features/shop/presentation/screens/shop_sales_screen.dart';
import 'package:fashion_marketplace/features/shop/presentation/screens/shop_notifications_screen.dart';

Future<Never> pending(dynamic _) => Completer<Never>().future;

class _CustomerRepository extends Fake implements CustomerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getProducts) {
      return Future<List<CustomerProduct>>.value([]);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  final pages = <String, Widget>{
    'home': const CustomerHomeScreen(),
    'catalog': const CustomerCatalogScreen(),
    'favorites': const CustomerFavoritesScreen(),
    'orders': const CustomerOrdersScreen(),
    'notifications': const CustomerNotificationsScreen(),
    'shops': const CustomerShopsScreen(),
    'admin stats': const AdminStatsScreen(),
    'admin orders': const AdminOrdersScreen(),
    'admin categories': const AdminCategoriesScreen(),
    'shop sales': const ShopSalesScreen(),
    'shop notifications': const ShopNotificationsScreen(),
    'product detail': const ProductDetailsScreen(productId: 'test-product'),
    'order detail': const OrderDetailsScreen(orderId: 'test-order'),
    'shop profile': const ShopPublicProfileScreen(shopId: 'test-shop'),
  };
  for (final entry in pages.entries) {
    testWidgets(
      '${entry.key}: actual page loading layout fits a narrow RTL viewport',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => entry.value)],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerRepositoryProvider.overrideWithValue(
                _CustomerRepository(),
              ),
              customerProductDetailsProvider.overrideWith(
                (_, _) => Completer<Never>().future,
              ),
              customerOrderDetailsProvider.overrideWith(
                (_, _) => Completer<Never>().future,
              ),
              customerShopDetailsProvider.overrideWith(
                (_, _) => Completer<Never>().future,
              ),
              productReviewsProvider.overrideWith(
                (_, _) => Completer<Never>().future,
              ),
              customerBannersProvider.overrideWith(pending),
              customerCategoriesProvider.overrideWith(pending),
              customerShopsProvider.overrideWith(pending),
              customerProductsProvider.overrideWith(pending),
              customerFavoritesProvider.overrideWith(pending),
              customerOrdersProvider.overrideWith(pending),
              customerNotificationsProvider.overrideWith(pending),
              adminStatsProvider.overrideWith(pending),
              adminOrdersProvider.overrideWith(pending),
              adminCategoriesProvider.overrideWith(pending),
              shopStatsProvider.overrideWith(pending),
              shopNotificationsProvider.overrideWith(pending),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (_, child) => Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(390, 844),
                    textScaler: TextScaler.linear(entry.key == 'home' ? 1.2 : 1),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(AppSkeleton), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'skeleton uses the same card geometry and blocks placeholder actions',
    (tester) async {
      var taps = 0;
      Widget content() => SizedBox(
        width: 180,
        height: 310,
        child: ProductGridCard(
          title: 'قطعة ملابس',
          subtitle: 'متجر',
          meta: '120 ر.س',
          onTap: () => taps++,
        ),
      );
      Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );
      await tester.pumpWidget(host(AppSkeleton(child: content())));
      final skeletonSize = tester.getSize(find.byType(ProductGridCard));
      await tester.tap(find.byType(ProductGridCard), warnIfMissed: false);
      expect(taps, 0);
      await tester.pumpWidget(host(content()));
      expect(tester.getSize(find.byType(ProductGridCard)), skeletonSize);
      await tester.tap(find.byType(ProductGridCard));
      expect(taps, 1);
    },
  );

  testWidgets('data refresh retains content and errors keep their retry UI', (
    tester,
  ) async {
    Widget render(AsyncValue<String> value) => MaterialApp(
      home: value.skeletonWhen(
        placeholder: 'placeholder',
        data: (text) => Text(text),
        error: (_, _) => const Text('retry'),
      ),
    );
    await tester.pumpWidget(
      render(
        const AsyncLoading<String>().copyWithPrevious(
          const AsyncData('real content'),
        ),
      ),
    );
    expect(find.text('real content'), findsOneWidget);
    expect(find.byType(AppSkeleton), findsNothing);
    await tester.pumpWidget(
      render(AsyncError<String>(StateError('failure'), StackTrace.current)),
    );
    expect(find.text('retry'), findsOneWidget);
    expect(find.byType(AppSkeleton), findsNothing);
  });
}
