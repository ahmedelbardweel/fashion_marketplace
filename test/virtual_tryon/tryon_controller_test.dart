import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/garment_payload_loader.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:fashion_marketplace/features/customer/presentation/providers/decart_tryon_provider.dart';

CustomerProduct product(String id, {String category = 'Hoodies'}) =>
    CustomerProduct(
      id: id,
      shopId: 'shop',
      shopName: 'Store',
      name: 'Garment $id',
      categoryName: category,
      price: 10,
      status: 'active',
      variants: const [],
      images: [
        ProductImage(
          id: id,
          productId: id,
          filePath: 'https://example.com/$id.png',
          kind: 'ar',
          sortOrder: 0,
        ),
      ],
    );

class FakeSession implements TryonSession {
  final controller = StreamController<TryonSessionEvent>.broadcast(sync: true);
  final selections = <String>[];
  Completer<void>? update;
  int starts = 0;
  int stops = 0;
  @override
  Stream<TryonSessionEvent> get events => controller.stream;
  @override
  bool get isUsingFrontCamera => true;
  @override
  Future<void> start(GarmentSelection garment) async {
    starts++;
    controller.add(const TryonSessionEvent(DecartSessionStatus.connected));
  }

  @override
  Future<void> select(GarmentSelection garment) async {
    selections.add(garment.id);
    await update?.future;
  }

  @override
  Future<void> switchCamera() async {}
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

void main() {
  test('reference selection excludes rear and 3D assets but accepts background filenames', () {
    CustomerProduct withImage(String path, String kind) => CustomerProduct.fromMap(
      const {'id': 'x', 'name': 'Dress'}, images: [ProductImage(
        id: 'image', productId: 'x', filePath: 'https://example.com/$path',
        kind: kind, sortOrder: 0,
      )]);
    expect(withImage('dress-back.png', 'ar').tryonReferenceImage, isNull);
    expect(withImage('dress.glb', 'gallery').tryonReferenceImage, isNull);
    expect(withImage('dress-background-removed.png', 'ar').tryonReferenceImage,
      'https://example.com/dress-background-removed.png');
  });
  test('prompt targets the garment region and retains product details', () {
    for (final entry in {
      'فستان سهرة': 'outfit',
      'Red dress': 'outfit',
      'Dresses': 'outfit',
      'بنطلون': 'lower body garment',
      'Football jersey': 'upper body garment',
      'Dress shirt': 'upper body garment',
    }.entries) {
      final garment = GarmentSelection(
        id: 'x',
        name: entry.key,
        imageUrl: 'https://example.com/item.png',
        description: 'Red stripes and printed number 10',
      );
      expect(garment.region, entry.value);
      expect(garment.prompt, startsWith('Substitute the ${entry.value} with'));
      expect(garment.prompt, contains('Red stripes and printed number 10'));
    }
  });

  test('requested dress is selected instead of the first shirt', () async {
    final session = FakeSession();
    final notifier = DecartTryonNotifier(
      session,
      () async => [product('shirt'), product('dress', category: 'Dresses')],
      'dress',
    );
    await notifier.start();
    expect(notifier.state.appliedProductId, 'dress');
    expect(session.starts, 1);
    notifier.dispose();
    await session.dispose();
  });

  test(
    'missing requested product never silently starts a different garment',
    () async {
      final session = FakeSession();
      final notifier = DecartTryonNotifier(
        session,
        () async => [product('shirt')],
        'missing',
      );
      await notifier.start();
      expect(session.starts, 0);
      expect(notifier.state.errorMessage, contains('لم يتم استبداله'));
      expect(notifier.state.appliedProductId, isNull);
      notifier.dispose();
      await session.dispose();
    },
  );

  test(
    'reference payload preserves exact prompt and transfers image bytes',
    () async {
      final garment = GarmentSelection(
        id: '1',
        name: 'Navy hoodie',
        imageUrl: 'https://example.com/1.png',
      );
      final client = MockClient(
        (request) async => http.Response.bytes(
          [1, 2, 3],
          200,
          headers: {'content-type': 'image/png'},
        ),
      );
      final message = jsonDecode(
        await GarmentPayloadLoader(client).load(garment),
      );
      expect(message['type'], 'set_image');
      expect(message['image_data'], 'AQID');
      expect(message['enhance_prompt'], false);
      expect(message['prompt'], garment.prompt);
      expect(
        garment.prompt,
        startsWith('Substitute the upper body garment with Navy hoodie'),
      );
      expect(garment.prompt, contains('supplied garment image'));
      client.close();
    },
  );

  test('rejects insecure URLs, oversized responses and non-images', () async {
    expect(
      () => const GarmentSelection(
        id: 'x',
        name: 'Top',
        imageUrl: 'http://example.com/a',
      ).validate(),
      throwsA(isA<TryonFailure>()),
    );
    final garment = GarmentSelection(
      id: '1',
      name: 'Top',
      imageUrl: 'https://example.com/a',
    );
    for (final response in [
      http.Response('html', 200, headers: {'content-type': 'text/html'}),
      http.Response('', 404),
      http.Response(
        '',
        200,
        headers: {'content-type': 'image/png', 'content-length': '9999999'},
      ),
    ]) {
      final client = MockClient((_) async => response);
      await expectLater(
        GarmentPayloadLoader(client).load(garment),
        throwsA(isA<TryonFailure>()),
      );
      client.close();
    }
  });

  testWidgets('rapid selections keep only the latest unsent garment', (
    tester,
  ) async {
    final session = FakeSession();
    final products = [product('a'), product('b'), product('c'), product('d')];
    final notifier = DecartTryonNotifier(session, () async => products, 'a');
    await notifier.start();
    session.update = Completer<void>();
    notifier.selectGarment(products[1]);
    await tester.pump(const Duration(milliseconds: 130));
    notifier.selectGarment(products[2]);
    notifier.selectGarment(products[3]);
    await tester.pump(const Duration(milliseconds: 130));
    expect(session.selections, ['b']);
    expect(notifier.state.appliedProductId, 'a');
    session.update!.complete();
    await tester.pump();
    expect(session.selections, ['b', 'd']);
    expect(notifier.state.appliedProductId, 'd');
    expect(notifier.state.isUpdating, false);
    notifier.dispose();
    await session.dispose();
  });

  test('dispose during catalog loading never starts capture', () async {
    final session = FakeSession();
    final catalog = Completer<List<CustomerProduct>>();
    final notifier = DecartTryonNotifier(session, () => catalog.future, 'a');
    final starting = notifier.start();
    notifier.dispose();
    catalog.complete([product('a')]);
    await starting;
    expect(session.starts, 0);
    expect(session.stops, 1);
    await session.dispose();
  });

  test('failure can be cleared by retry and catalog supports other garment regions', () async {
    final session = FakeSession();
    var fail = true;
    final notifier = DecartTryonNotifier(session, () async {
      if (fail) throw const TryonFailure('catalog failed');
      return [product('a'), product('shoe', category: 'Shoes')];
    }, 'a');
    await notifier.start();
    expect(notifier.state.errorMessage, 'catalog failed');
    fail = false;
    await notifier.retry();
    expect(notifier.state.errorMessage, isNull);
    expect(notifier.state.availableProducts.map((p) => p.id), ['a', 'shoe']);
    notifier.dispose();
    await session.dispose();
  });

  testWidgets('rejected update preserves applied garment and allows retry', (
    tester,
  ) async {
    final session = FakeSession();
    final products = [product('a'), product('b')];
    final notifier = DecartTryonNotifier(session, () async => products, 'a');
    await notifier.start();
    session.update = Completer<void>();
    notifier.selectGarment(products[1]);
    await tester.pump(const Duration(milliseconds: 130));
    session.update!.completeError(const TryonFailure('rejected'));
    await tester.pump();
    expect(notifier.state.appliedProductId, 'a');
    expect(notifier.state.selectedProduct?.id, 'a');
    expect(notifier.state.errorMessage, 'rejected');
    session.update = null;
    notifier.selectGarment(products[1]);
    await tester.pump(const Duration(milliseconds: 130));
    expect(notifier.state.appliedProductId, 'b');
    expect(notifier.state.errorMessage, isNull);
    notifier.dispose();
    await session.dispose();
  });
}
