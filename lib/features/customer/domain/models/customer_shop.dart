class CustomerShop {
  const CustomerShop({
    required this.id,
    required this.name,
    this.description,
    this.city,
    this.address,
    this.logoPath,
    this.coverPath,
    this.productsCount = 0,
  });

  factory CustomerShop.fromMap(Map<String, dynamic> map, {int productsCount = 0}) {
    return CustomerShop(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'متجر',
      description: map['description']?.toString(),
      city: map['city']?.toString(),
      address: map['address']?.toString(),
      logoPath: map['logo_path']?.toString(),
      coverPath: map['cover_path']?.toString(),
      productsCount: productsCount,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? city;
  final String? address;
  final String? logoPath;
  final String? coverPath;
  final int productsCount;
}
