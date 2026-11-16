import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fashion_marketplace/features/admin/domain/models/catalog_models.dart';
import 'package:fashion_marketplace/features/customer/data/customer_repository.dart';
import 'package:fashion_marketplace/features/customer/presentation/widgets/category_department_grid.dart';

void main() {
  test(
    'department fetch retains products assigned to child categories',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/categories')) {
            return http.Response(
              jsonEncode([
                {'id': 'root', 'name': 'ملابس'},
                {'id': 'child', 'name': 'هودي', 'parent_id': 'root'},
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          expect(request.url.queryParameters['category_id'], contains('child'));
          return http.Response(
            jsonEncode([
              {
                'id': 'product',
                'name': 'هودي',
                'category_id': 'child',
                'shop_id': 'shop',
                'price': 100,
                'status': 'published',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final page = await CustomerRepository(
        client: client,
      ).getProductsPage(categoryId: 'root');
      expect(page.items.single.categoryId, 'child');
      await client.dispose();
    },
  );

  test(
    'branch resolution includes descendants and terminates on malformed cycles',
    () {
      final categories = [
        const CatalogCategory(
          id: 'a',
          name: 'A',
          isActive: true,
          parentId: 'b',
        ),
        const CatalogCategory(
          id: 'b',
          name: 'B',
          isActive: true,
          parentId: 'a',
        ),
        const CatalogCategory(id: 'c', name: 'C', isActive: true),
      ];
      expect(categoryBranchIds(categories, 'a'), {'a', 'b'});
    },
  );

  test('hierarchicalCategoryOptions places each root before its children', () {
    final categories = [
      const CatalogCategory(
        id: 'hoodie',
        name: 'هودي',
        isActive: true,
        parentId: 'clothing',
      ),
      const CatalogCategory(id: 'shoes', name: 'أحذية', isActive: true),
      const CatalogCategory(id: 'clothing', name: 'ملابس', isActive: true),
      const CatalogCategory(
        id: 'sneakers',
        name: 'سنيكرز',
        isActive: true,
        parentId: 'shoes',
      ),
    ];
    final ordered = hierarchicalCategoryOptions(categories);
    expect(
      ordered.map((e) => (e.category.id, e.parent?.id)).toList(),
      [
        ('shoes', null),
        ('sneakers', 'shoes'),
        ('clothing', null),
        ('hoodie', 'clothing'),
      ],
    );
  });

  testWidgets(
    'six departments sit in one RTL row, hide children and remain tappable on small screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final names = [
        'ملابس',
        'أحذية',
        'إكسسوارات',
        'حقائب',
        'إلكترونيات',
        'عطور وتجميل',
      ];
      final icons = [
        'clothing',
        'shoes',
        'accessories',
        'bags',
        'electronics',
        'beauty',
      ];
      String? selected;
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: RepaintBoundary(
                  key: previewKey,
                  child: CategoryDepartmentGrid(
                    categories: [
                      for (var i = 0; i < 6; i++)
                        CatalogCategory(
                          id: '$i',
                          name: names[i],
                          isActive: true,
                          iconKey: icons[i],
                        ),
                      const CatalogCategory(
                        id: 'h',
                        name: 'هودي',
                        isActive: true,
                        parentId: '0',
                      ),
                    ],
                    onSelected: (c) => selected = c.id,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('هودي'), findsNothing);
      expect(
        tester.getCenter(find.text('ملابس')).dx,
        greaterThan(tester.getCenter(find.text('أحذية')).dx),
      );
      expect(
        tester.getCenter(find.text('أحذية')).dx,
        greaterThan(tester.getCenter(find.text('حقائب')).dx),
      );
      await tester.tap(find.text('ملابس'));
      expect(selected, '0');
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            previewKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/category-grid-preview.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
  );
}
