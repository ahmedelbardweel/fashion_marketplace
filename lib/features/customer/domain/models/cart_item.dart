class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.shopId,
    required this.shopName,
    this.variantId,
    required this.color,
    required this.size,
    required this.unitPrice,
    required this.quantity,
    this.imagePath,
    required this.maxStock,
  });

  final String id;
  final String productId;
  final String productName;
  final String shopId;
  final String shopName;
  final String? variantId;
  final String color;
  final String size;
  final double unitPrice;
  final int quantity;
  final String? imagePath;
  final int maxStock;

  double get totalPrice => unitPrice * quantity;

  String get variantDescription => '$color / $size';

  CartItem copyWith({
    int? quantity,
  }) {
    return CartItem(
      id: id,
      productId: productId,
      productName: productName,
      shopId: shopId,
      shopName: shopName,
      variantId: variantId,
      color: color,
      size: size,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      imagePath: imagePath,
      maxStock: maxStock,
    );
  }

  Map<String, dynamic> toOrderPayload() {
    return {
      'product_id': productId,
      'variant_id': variantId,
      'product_name': productName,
      'variant_info': variantDescription,
      'unit_price': unitPrice,
      'quantity': quantity,
      'image_path': imagePath,
    };
  }
}
