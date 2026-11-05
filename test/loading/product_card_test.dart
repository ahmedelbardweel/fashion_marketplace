import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/core/widgets/product_grid_card.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:fashion_marketplace/features/customer/presentation/providers/customer_providers.dart';
import 'package:fashion_marketplace/features/customer/presentation/widgets/product_cart_sheet.dart';

void main() {
  for (final width in [240.0, 320.0, 390.0, 768.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('cards fit width $width and text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1000),
                textScaler: TextScaler.linear(scale),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: GridView.builder(
                    gridDelegate: ProductGridDelegate(textScale: scale),
                    itemCount: 6,
                    itemBuilder: (_, _) => ProductGridCard(
                      title: 'فستان طويل بتصميم مميز ومريح لجميع المناسبات',
                      subtitle: 'متجر الأزياء الجديدة',
                      meta: '150.00 ر.س',
                      onAddToCart: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('cart sheet requires a variant and adds the chosen option', (
    tester,
  ) async {
    const product = CustomerProduct(
      id: 'p',
      shopId: 's',
      shopName: 'متجر',
      name: 'فستان',
      price: 150,
      status: 'published',
      images: [],
      variants: [
        ProductVariant(
          id: 'v1',
          productId: 'p',
          color: 'أسود',
          size: 'S',
          stock: 2,
          isActive: true,
        ),
        ProductVariant(
          id: 'v2',
          productId: 'p',
          color: 'أبيض',
          size: 'M',
          stock: 3,
          isActive: true,
        ),
        ProductVariant(
          id: 'v3',
          productId: 'p',
          color: 'أحمر',
          size: 'L',
          stock: 0,
          isActive: true,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        customerProductDetailsProvider('p')
            .overrideWith((ref) async => product),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProductCartSheet(context, 'p'),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(find.text('أحمر · L'), findsNothing);
    await tester.tap(find.text('أبيض · M'));
    await tester.pump();
    await tester.tap(find.text('تأكيد الإضافة إلى السلة'));
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).single.variantId, 'v2');
    expect(container.read(cartProvider).single.quantity, 1);
    expect(tester.takeException(), isNull);
  });
}
