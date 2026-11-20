import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/core/widgets/app_text_field.dart';
import 'package:fashion_marketplace/features/shop/presentation/widgets/product_form_steps.dart';
import 'package:go_router/go_router.dart';
import 'package:fashion_marketplace/core/utils/media_picker.dart';
import 'package:fashion_marketplace/features/admin/domain/models/catalog_models.dart';
import 'package:fashion_marketplace/features/shop/data/shop_catalog_repository.dart';
import 'package:fashion_marketplace/features/shop/data/shop_storage_repository.dart';
import 'package:fashion_marketplace/features/shop/domain/models/shop_product.dart';
import 'package:fashion_marketplace/features/shop/presentation/providers/shop_catalog_providers.dart';
import 'package:fashion_marketplace/features/shop/presentation/screens/shop_product_form_screen.dart';

const product = ShopProduct(
  id: 'p',
  shopId: 's',
  name: 'فستان',
  description: 'وصف المنتج',
  price: 150,
  status: 'draft',
  categoryId: 'cat',
  details: {'material': 'قطن'},
  variants: [
    ProductVariant(id: 'v', productId: 'p', color: 'أسود', size: 'M', stock: 3),
  ],
  images: [],
);

class Repo extends Fake implements ShopCatalogRepository {
  Map<String, dynamic>? saved;
  @override
  Future<ShopProduct> saveProductForm(Map<String, dynamic> data) async {
    saved = data;
    return product;
  }
}

class Storage extends Fake implements ShopStorageRepository {
  int uploads = 0;
  @override
  Future<String> uploadBytes({
    required String bucket,
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    uploads++;
    expect(fileName.endsWith('.png'), isTrue);
    expect(contentType, 'image/png');
    return 'https://example.com/$uploads.png';
  }
}

void main() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jV1sAAAAASUVORK5CYII=',
  );
  Future<void> host(
    WidgetTester tester, {
    required Repo repo,
    required Storage storage,
    required Future<Uint8List> Function(Uint8List) remove,
    double width = 390,
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/edit',
          builder: (_, _) => const ShopProductFormScreen(productId: 'p'),
        ),
        GoRoute(
          path: '/shop/products',
          builder: (_, _) => const Scaffold(body: Text('products')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopProductProvider('p').overrideWith((ref) async => product),
          shopCategoriesProvider.overrideWith(
            (ref) async => [
              const CatalogCategory(id: 'cat', name: 'فساتين', isActive: true),
            ],
          ),
          shopCatalogRepositoryProvider.overrideWithValue(repo),
          shopStorageRepositoryProvider.overrideWithValue(storage),
          shopProductImagePickerProvider.overrideWithValue(
            () async => [PickedBytes(bytes: bytes, fileName: 'front.jpg')],
          ),
          shopProductBackgroundRemoverProvider.overrideWithValue(remove),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'narrow editor retains details and saves a new category with the draft',
    (tester) async {
      final repo = Repo();
      await host(
        tester,
        repo: repo,
        storage: Storage(),
        remove: (b) async => b,
        width: 320,
        scale: 1.4,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('المواصفات'));
      await tester.pumpAndSettle();
      final initialProgress = tester
          .widget<ProductFormSteps>(find.byType(ProductFormSteps))
          .progress[1];
      final brand = find.descendant(
        of: find.widgetWithText(AppTextField, 'الماركة'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(brand);
      await tester.enterText(brand, 'ماركة');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductFormSteps>(find.byType(ProductFormSteps))
            .progress[1],
        greaterThan(initialProgress),
      );
      await tester.enterText(brand, '');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductFormSteps>(find.byType(ProductFormSteps))
            .progress[1],
        initialProgress,
      );
      await tester.tap(find.text('الأساسيات'));
      await tester.pumpAndSettle();
      final catField = find.text('فساتين');
      await tester.ensureVisible(catField);
      await tester.tap(catField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة تصنيف جديد').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'اسم التصنيف'),
          matching: find.byType(TextFormField),
        ),
        'ملابس صيفية',
      );
      await tester.tap(find.text('استخدام التصنيف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ كمسودة'));
      await tester.pumpAndSettle();
      expect(repo.saved?['new_category_name'], 'ملابس صيفية');
      expect((repo.saved?['details'] as Map)['material'], 'قطن');
      expect(repo.saved?['id'], 'p');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'image selection automatically removes background, uploads PNG, and allows removal',
    (tester) async {
      final repo = Repo();
      final storage = Storage();
      final pending = Completer<Uint8List>();
      int calls = 0;
      await host(
        tester,
        repo: repo,
        storage: storage,
        remove: (b) {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.text('الصور'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('اختيار صور المنتج'));
      await tester.pump();
      await tester.pump();
      expect(calls, 1);
      expect(storage.uploads, 0);
      expect(find.text('الصورة الرئيسية'), findsOneWidget);
      await tester.ensureVisible(find.text('التالي: المقاسات'));
      await tester.tap(find.text('التالي: المقاسات'));
      await tester.pumpAndSettle();
      expect(find.text('كل خيار وكمّيته'), findsOneWidget);
      pending.complete(bytes);
      await tester.pumpAndSettle();
      expect(storage.uploads, 1);
      await tester.tap(find.text('الصور'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('حذف الصورة'));
      await tester.tap(find.byTooltip('حذف الصورة'));
      await tester.pumpAndSettle();
      expect(find.text('الصورة الرئيسية'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed background removal remains retryable and never uploads the original',
    (tester) async {
      final repo = Repo();
      final storage = Storage();
      await host(
        tester,
        repo: repo,
        storage: storage,
        remove: (b) async => throw StateError('processing failed'),
      );
      await tester.tap(find.text('الصور'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('اختيار صور المنتج'));
      await tester.pumpAndSettle();
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(storage.uploads, 0);
      await tester.tap(find.text('حفظ كمسودة'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
