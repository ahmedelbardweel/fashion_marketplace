import 'dart:typed_data';

import 'package:fashion_marketplace/core/filtering/filter_models.dart';
import 'package:fashion_marketplace/core/search/visual_search_service.dart';
import 'package:fashion_marketplace/core/search/voice_search_service.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('VoiceSearchService query cleaning', () {
    test('strips conversational Arabic & English stop words accurately', () {
      expect(
        cleanVoiceSearchQuery('بدي قميص رجالي لونه أسود لو سمحت'),
        equals('قميص رجالي أسود'),
      );
      expect(
        cleanVoiceSearchQuery('ابحث عن فستان سهرة بيج'),
        equals('فستان سهرة بيج'),
      );
      expect(
        cleanVoiceSearchQuery('please show me a blue jacket'),
        equals('blue jacket'),
      );
    });
  });

  group('VisualSearchService image color & histogram analysis', () {
    test('detects dominant red garment on white studio background', () async {
      final canvas = img.Image(width: 80, height: 80);
      // White studio border
      img.fill(canvas, color: img.ColorRgb8(250, 250, 250));
      // Red garment in the center
      img.fillRect(
        canvas,
        x1: 16,
        y1: 14,
        x2: 64,
        y2: 66,
        color: img.ColorRgb8(215, 30, 40),
      );
      final pngBytes = Uint8List.fromList(img.encodePng(canvas));

      final query = await VisualSearchService.instance.analyzeImageBytes(
        pngBytes,
        fileNameHint: 'red_dress.png',
      );

      expect(query.primaryColorName, equals('أحمر'));
      expect(query.histogram.length, equals(64));
      expect(query.inferredKeywords, contains('فستان'));
    });
  });

  group('Similar products fallback engine', () {
    test('returns ranked similar products when exact match is not found', () {
      final products = [
        const CustomerProduct(
          id: 'p1',
          shopId: 's1',
          shopName: 'متجر النخبة',
          name: 'قميص كاجوال قطني',
          price: 120,
          status: 'published',
          variants: [
            ProductVariant(
              id: 'v1',
              productId: 'p1',
              color: 'كحلي',
              size: 'L',
              stock: 5,
              isActive: true,
            ),
          ],
          images: [],
        ),
        const CustomerProduct(
          id: 'p2',
          shopId: 's1',
          shopName: 'متجر النخبة',
          name: 'بنطلون جينز كلاسيك',
          price: 180,
          status: 'published',
          variants: [
            ProductVariant(
              id: 'v2',
              productId: 'p2',
              color: 'أزرق',
              size: 'M',
              stock: 3,
              isActive: true,
            ),
          ],
          images: [],
        ),
      ];

      const filter = ProductFilter(search: 'قميص حريري أخضر');
      final exact = applyCustomerProductFilter(products, filter);
      expect(exact, isEmpty);

      final similar = computeSimilarCustomerProducts(products, filter);
      expect(similar, isNotEmpty);
      // Product p1 ('قميص كاجوال قطني') shares the word 'قميص' and ranks first
      expect(similar.first.id, equals('p1'));
    });

    test('matches feminine/masculine colors, sizes, details, and price across all DB fields', () {
      final products = [
        const CustomerProduct(
          id: 'hoodie_blue',
          shopId: 's1',
          shopName: 'متجر ستايل',
          categoryName: 'ملابس شتوية',
          name: 'هودي شتوي مريح',
          price: 80,
          status: 'published',
          details: {'material': 'قطن 100%', 'fit': 'أوفر سايز'},
          variants: [
            ProductVariant(
              id: 'v_blue',
              productId: 'hoodie_blue',
              color: 'أزرق',
              size: 'M',
              stock: 10,
              isActive: true,
            ),
          ],
          images: [],
        ),
        const CustomerProduct(
          id: 'hoodie_black',
          shopId: 's1',
          shopName: 'متجر ستايل',
          categoryName: 'ملابس شتوية',
          name: 'هودي بسحاب',
          price: 95,
          status: 'published',
          variants: [
            ProductVariant(
              id: 'v_black',
              productId: 'hoodie_black',
              color: 'أسود',
              size: 'L',
              stock: 4,
              isActive: true,
            ),
          ],
          images: [],
        ),
      ];

      // Feminine color "زرقاء" matches variant color "أزرق"
      final blueHoodieMatch = applyCustomerProductFilter(
        products,
        const ProductFilter(search: 'هودي زرقاء'),
      );
      expect(blueHoodieMatch.map((p) => p.id), equals(['hoodie_blue']));

      // Arabic size synonym "ميديم" matches "M"
      final sizeMatch = applyCustomerProductFilter(
        products,
        const ProductFilter(search: 'هودي ميديم'),
      );
      expect(sizeMatch.map((p) => p.id), equals(['hoodie_blue']));

      // Product details JSON field ("أوفر سايز") & price ("80")
      final detailsMatch = applyCustomerProductFilter(
        products,
        const ProductFilter(search: 'أوفر سايز 80'),
      );
      expect(detailsMatch.map((p) => p.id), equals(['hoodie_blue']));

      // Feminine color "سوداء" + size "L"
      final blackHoodieMatch = applyCustomerProductFilter(
        products,
        const ProductFilter(search: 'الهودي سوداء L'),
      );
      expect(blackHoodieMatch.map((p) => p.id), equals(['hoodie_black']));
    });
  });
}
