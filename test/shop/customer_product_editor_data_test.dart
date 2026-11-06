import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';

void main() {
  test('customer preserves cover order, hides retired options and retains details on favorite updates', () {
    final product = CustomerProduct.fromMap({'id':'p','details':{'material':'قطن'}},
      images: const [ProductImage(id:'b',productId:'p',filePath:'second',kind:'gallery',sortOrder:1),ProductImage(id:'a',productId:'p',filePath:'cover',kind:'gallery',sortOrder:0)],
      variants: const [ProductVariant(id:'active',productId:'p',color:'أسود',size:'M',stock:3,isActive:true),ProductVariant(id:'retired',productId:'p',color:'أبيض',size:'L',stock:0,isActive:false)]);
    expect(product.coverImage,'cover');
    expect(product.variants.single.id,'active');
    expect(product.copyWith(isFavorite:true).details['material'],'قطن');
  });
}
