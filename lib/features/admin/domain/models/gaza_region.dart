class GazaRegion {
  const GazaRegion({
    required this.id,
    required this.name,
    this.nameEn,
    this.parentId,
    this.governorateCode,
    this.deliveryFee = 10,
    this.estimatedDelivery = 'نفس اليوم',
    this.isDeliveryAvailable = true,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String? parentId;
  final String name;
  final String? nameEn;
  final String? governorateCode;
  final double deliveryFee;
  final String estimatedDelivery;
  final bool isDeliveryAvailable;
  final bool isActive;
  final int sortOrder;

  bool get isGovernorate => parentId == null || parentId!.isEmpty;

  factory GazaRegion.fromMap(Map<String, dynamic> map) {
    return GazaRegion(
      id: map['id']?.toString() ?? '',
      parentId: map['parent_id']?.toString(),
      name: map['name']?.toString() ?? '',
      nameEn: map['name_en']?.toString(),
      governorateCode: map['governorate_code']?.toString(),
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 10,
      estimatedDelivery:
          (map['estimated_delivery'] as String?)?.trim().isNotEmpty == true
          ? (map['estimated_delivery'] as String).trim()
          : 'نفس اليوم',
      isDeliveryAvailable: map['is_delivery_available'] as bool? ?? true,
      isActive: map['is_active'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

typedef GazaGovernorateGroup = ({
  GazaRegion governorate,
  List<GazaRegion> areas,
});

/// Groups flat [regions] into ordered Gaza governorates (North -> South)
/// along with their sorted child neighborhoods.
List<GazaGovernorateGroup> groupGazaRegions(List<GazaRegion> regions) {
  final govs =
      regions.where((r) => r.isGovernorate).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final byParent = <String, List<GazaRegion>>{};
  for (final r in regions) {
    if (!r.isGovernorate) {
      (byParent[r.parentId!] ??= []).add(r);
    }
  }
  return govs.map((gov) {
    final areas = List<GazaRegion>.from(byParent[gov.id] ?? const [])
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return (governorate: gov, areas: areas);
  }).toList();
}

/// Smart matcher for whether a free-text [location] (e.g. "gaza", "غزة",
/// "غزة · الرمال الشمالي", "Khan Younis") belongs to [group].
bool matchesGazaGovernorate(String? location, GazaGovernorateGroup group) {
  final raw = location?.trim().toLowerCase() ?? '';
  if (raw.isEmpty) return false;

  final gov = group.governorate;
  final code = (gov.governorateCode ?? '').toLowerCase();

  // Check child neighborhoods first (most specific)
  for (final area in group.areas) {
    final ar = area.name.trim().toLowerCase();
    final en = area.nameEn?.trim().toLowerCase() ?? '';
    if (ar.isNotEmpty && raw.contains(ar)) return true;
    if (en.isNotEmpty && raw.contains(en)) return true;
  }

  // Distinguish North Gaza from Gaza City cleanly
  final isNorthGazaText =
      raw.contains('شمال غزة') || raw.contains('north gaza');
  if (code == 'north_gaza' || gov.name.contains('شمال')) {
    return isNorthGazaText;
  }
  if (code == 'gaza' || gov.name == 'غزة') {
    if (isNorthGazaText) return false;
    return raw == 'غزة' ||
        raw == 'gaza' ||
        raw.contains('gaza city') ||
        raw.startsWith('غزة ') ||
        raw.startsWith('غزة·') ||
        raw.startsWith('غزة-') ||
        raw.contains('مدينة غزة') ||
        raw.contains('gaza');
  }

  if (raw.contains(gov.name.trim().toLowerCase())) return true;
  if (gov.nameEn != null &&
      gov.nameEn!.trim().isNotEmpty &&
      raw.contains(gov.nameEn!.trim().toLowerCase())) {
    return true;
  }
  if (code == 'khan_yunis' &&
      (raw.contains('خانيونس') || raw.contains('khan younis'))) {
    return true;
  }
  if (code == 'middle' &&
      (raw.contains('الوسطى') || raw.contains('دير البلح'))) {
    return true;
  }
  return false;
}

/// Canonical Gaza Strip governorates fallback used offline or before DB seed.
const List<GazaRegion> kDefaultGazaRegions = [
  GazaRegion(
    id: 'gov_north_gaza',
    name: 'شمال غزة',
    nameEn: 'North Gaza',
    governorateCode: 'north_gaza',
    deliveryFee: 15,
    estimatedDelivery: '2 - 4 ساعات',
    sortOrder: 1,
  ),
  GazaRegion(
    id: 'gov_gaza',
    name: 'غزة',
    nameEn: 'Gaza City',
    governorateCode: 'gaza',
    deliveryFee: 10,
    estimatedDelivery: '1 - 2 ساعة',
    sortOrder: 2,
  ),
  GazaRegion(
    id: 'gov_middle',
    name: 'الوسطى',
    nameEn: 'Middle Area',
    governorateCode: 'middle',
    deliveryFee: 15,
    estimatedDelivery: '2 - 4 ساعات',
    sortOrder: 3,
  ),
  GazaRegion(
    id: 'gov_khan_yunis',
    name: 'خان يونس',
    nameEn: 'Khan Yunis',
    governorateCode: 'khan_yunis',
    deliveryFee: 18,
    estimatedDelivery: 'نفس اليوم',
    sortOrder: 4,
  ),
  GazaRegion(
    id: 'gov_rafah',
    name: 'رفح',
    nameEn: 'Rafah',
    governorateCode: 'rafah',
    deliveryFee: 20,
    estimatedDelivery: 'نفس اليوم',
    sortOrder: 5,
  ),
  GazaRegion(id: 'area_jabalia', parentId: 'gov_north_gaza', name: 'جباليا', nameEn: 'Jabalia', deliveryFee: 15, sortOrder: 1),
  GazaRegion(id: 'area_beit_lahia', parentId: 'gov_north_gaza', name: 'بيت لاهيا', nameEn: 'Beit Lahia', deliveryFee: 15, sortOrder: 2),
  GazaRegion(id: 'area_beit_hanoun', parentId: 'gov_north_gaza', name: 'بيت حانون', nameEn: 'Beit Hanoun', deliveryFee: 18, sortOrder: 3),
  GazaRegion(id: 'area_rimal_n', parentId: 'gov_gaza', name: 'الرمال الشمالي', nameEn: 'North Rimal', deliveryFee: 10, sortOrder: 1),
  GazaRegion(id: 'area_rimal_s', parentId: 'gov_gaza', name: 'الرمال الجنوبي', nameEn: 'South Rimal', deliveryFee: 10, sortOrder: 2),
  GazaRegion(id: 'area_tel_hawa', parentId: 'gov_gaza', name: 'تل الهوى', nameEn: 'Tel Al-Hawa', deliveryFee: 10, sortOrder: 3),
  GazaRegion(id: 'area_nasr', parentId: 'gov_gaza', name: 'النصر', nameEn: 'Al-Nasr', deliveryFee: 10, sortOrder: 4),
  GazaRegion(id: 'area_radwan', parentId: 'gov_gaza', name: 'الشيخ رضوان', nameEn: 'Sheikh Radwan', deliveryFee: 10, sortOrder: 5),
  GazaRegion(id: 'area_shujaiya', parentId: 'gov_gaza', name: 'الشجاعية', nameEn: 'Shuja\'iyya', deliveryFee: 12, sortOrder: 6),
  GazaRegion(id: 'area_deir', parentId: 'gov_middle', name: 'دير البلح', nameEn: 'Deir Al-Balah', deliveryFee: 15, sortOrder: 1),
  GazaRegion(id: 'area_nuseirat', parentId: 'gov_middle', name: 'النصيرات', nameEn: 'Nuseirat', deliveryFee: 15, sortOrder: 2),
  GazaRegion(id: 'area_bureij', parentId: 'gov_middle', name: 'البريج', nameEn: 'Bureij', deliveryFee: 15, sortOrder: 3),
  GazaRegion(id: 'area_maghazi', parentId: 'gov_middle', name: 'المغازي', nameEn: 'Maghazi', deliveryFee: 15, sortOrder: 4),
  GazaRegion(id: 'area_zawaida', parentId: 'gov_middle', name: 'الزوايدة', nameEn: 'Al-Zawaida', deliveryFee: 15, sortOrder: 5),
  GazaRegion(id: 'area_khan_center', parentId: 'gov_khan_yunis', name: 'وسط خان يونس', nameEn: 'Central Khan Yunis', deliveryFee: 18, sortOrder: 1),
  GazaRegion(id: 'area_mawasi_ky', parentId: 'gov_khan_yunis', name: 'المواصي - خان يونس', nameEn: 'Al-Mawasi (Khan Yunis)', deliveryFee: 18, sortOrder: 2),
  GazaRegion(id: 'area_qarara', parentId: 'gov_khan_yunis', name: 'القرارة', nameEn: 'Al-Qarara', deliveryFee: 18, sortOrder: 3),
  GazaRegion(id: 'area_bani_suheila', parentId: 'gov_khan_yunis', name: 'بني سهيلا', nameEn: 'Bani Suheila', deliveryFee: 18, sortOrder: 4),
  GazaRegion(id: 'area_rafah_center', parentId: 'gov_rafah', name: 'وسط رفح', nameEn: 'Central Rafah', deliveryFee: 20, sortOrder: 1),
  GazaRegion(id: 'area_tel_sultan', parentId: 'gov_rafah', name: 'تل السلطان', nameEn: 'Tel Al-Sultan', deliveryFee: 20, sortOrder: 2),
  GazaRegion(id: 'area_shaboura', parentId: 'gov_rafah', name: 'الشابورة', nameEn: 'Al-Shaboura', deliveryFee: 20, sortOrder: 3),
];
