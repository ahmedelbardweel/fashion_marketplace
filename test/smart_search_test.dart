import 'dart:typed_data';

import 'package:fashion_marketplace/core/filtering/filter_models.dart';
import 'package:fashion_marketplace/core/search/visual_search_service.dart';
import 'package:fashion_marketplace/core/search/voice_search_service.dart';
import 'package:fashion_marketplace/features/admin/domain/models/catalog_models.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_shop.dart';
import 'package:fashion_marketplace/features/shop/domain/models/shop_product.dart'
    hide ProductVariant;
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
      expect(
        cleanVoiceSearchQuery('ممكن تيشرت تيشرت أوفر سايز تحت ال 100 لو سمحت'),
        equals('تيشيرت أوفر سايز تحت 100'),
      );
    });

    test('picks highest-relevance transcript from recognizer alternates', () {
      final best = pickBestVoiceTranscript([
        (text: 'هودي ازاز', confidence: 0.78),
        (text: 'هودي ازرق ميديم', confidence: 0.72),
      ]);
      expect(best, equals('هودي ازرق ميديم'));
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
      expect(query.spatialColors.length, equals(27));
      expect(query.inferredKeywords, contains('فستان'));
    });

    test('focuses on central garment on cluttered real-world background', () async {
      final canvas = img.Image(width: 80, height: 80);
      // High-variance outdoor/room background on the border & sides
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 80; x++) {
          final noisy = ((x * 37 + y * 19) % 2 == 0)
              ? img.ColorRgb8(215, 200, 175)
              : img.ColorRgb8(60, 120, 45);
          canvas.setPixel(x, y, noisy);
        }
      }
      // Navy hoodie in the center
      img.fillRect(
        canvas,
        x1: 18,
        y1: 14,
        x2: 62,
        y2: 66,
        color: img.ColorRgb8(28, 52, 94),
      );
      final pngBytes = Uint8List.fromList(img.encodePng(canvas));

      final query = await VisualSearchService.instance.analyzeImageBytes(pngBytes);
      expect(query.primaryColorName, equals('كحلي'));
      expect(query.histogram.length, equals(64));
      expect(query.shapeSignature.length, equals(64));
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

    test('supports natural Arabic price phrases, typos, stemming, and relevance order', () {
      final catalog = [
        const CustomerProduct(
          id: 'p_desc_only',
          shopId: 's1',
          shopName: 'متجر ألفا',
          name: 'طقم رياضي متكامل',
          description: 'يتضمن بنطلون قطني مريح',
          price: 90,
          status: 'published',
          variants: [
            ProductVariant(
              id: 'v1',
              productId: 'p_desc_only',
              color: 'أسود',
              size: 'M',
              stock: 3,
              isActive: true,
            ),
          ],
          images: [],
        ),
        const CustomerProduct(
          id: 'p_expensive',
          shopId: 's1',
          shopName: 'متجر ألفا',
          name: 'بنطلون جينز فاخر',
          price: 180,
          status: 'published',
          variants: [
            ProductVariant(
              id: 'v2',
              productId: 'p_expensive',
              color: 'أسود',
              size: 'M',
              stock: 4,
              isActive: true,
            ),
          ],
          images: [],
        ),
        const CustomerProduct(
          id: 'p_title_exact',
          shopId: 's1',
          shopName: 'متجر ألفا',
          name: 'بنطلون كلاسيك قطن',
          price: 85,
          status: 'published',
          variants: [
            ProductVariant(
              id: 'v3',
              productId: 'p_title_exact',
              color: 'أسود',
              size: 'M',
              stock: 5,
              isActive: true,
            ),
          ],
          images: [],
        ),
      ];

      // Price phrase "تحت المية" filters <= 100 and ranks exact title match first
      final underHundred = applyCustomerProductFilter(
        catalog,
        const ProductFilter(search: 'بنطلون اسود تحت المية'),
      );
      expect(
        underHundred.map((p) => p.id).toList(),
        equals(['p_title_exact', 'p_desc_only']),
      );

      // Typo tolerance: "بنطلوون" still matches "بنطلون"
      final typoMatch = applyCustomerProductFilter(
        catalog,
        const ProductFilter(search: 'بنطلوون تحت ال 100'),
      );
      expect(
        typoMatch.map((p) => p.id).toList(),
        equals(['p_title_exact', 'p_desc_only']),
      );
    });

    test('ranks shops, shop products, and admin products accurately with synonyms & price intent', () {
      const shops = [
        CustomerShop(
          id: 's_desc',
          name: 'بوتيك الأناقة',
          description: 'تشكيلة نخبة مميزة',
          city: 'رام الله',
        ),
        CustomerShop(
          id: 's_name',
          name: 'متجر النخبة',
          description: 'أزياء عصرية',
          city: 'غزة',
        ),
      ];
      final rankedShops = filterCustomerShops(
        shops,
        const CustomerShopFilter(search: 'النخبه'),
      );
      expect(rankedShops.map((s) => s.id).toList(), equals(['s_name', 's_desc']));

      final shopProducts = [
        ShopProduct.fromMap({
          'id': 'sp_high',
          'shop_id': 's1',
          'name': 'معطف جلد فاخر',
          'price': 250,
          'status': 'published',
        }),
        ShopProduct.fromMap({
          'id': 'sp_low',
          'shop_id': 's1',
          'name': 'جاكيت جلد يومي',
          'price': 90,
          'status': 'published',
        }),
      ];
      expect(
        filterShopProducts(
          shopProducts,
          const ShopProductFilterState(search: 'جلد تحت 150'),
        ).map((e) => e.id).toList(),
        equals(['sp_low']),
      );

      final adminProducts = [
        AdminProduct.fromMap({
          'id': 'ap_miss',
          'name': 'فستان صيفي',
          'price': 300,
          'status': 'published',
        }),
        AdminProduct.fromMap({
          'id': 'ap_hit',
          'name': 'فستان سهرة أنيق',
          'price': 120,
          'status': 'published',
        }),
      ];
      expect(
        filterAdminProducts(
          adminProducts,
          const AdminProductFilterState(search: 'فساتين تحت 150'),
        ).map((e) => e.id).toList(),
        equals(['ap_hit']),
      );
    });
  });
}
