enum DecartSessionStatus {
  idle,
  initializing,
  connecting,
  connected,
  disconnected,
  error,
}

/// Distinct anatomical body zones that the user can explicitly select on the
/// color-coded body diagram before starting the Virtual Try-On.
enum TryonBodyZone {
  upperBody(
    arabicTitle: 'الجزء العلوي (بلوزة / قميص / جاكيت)',
    shortLabel: 'الجزء العلوي',
    bodyPartDescription: 'الصدر والكتفين والذراعين (بلوزة، تيشيرت، قميص، هودي، جاكيت)',
    framingInstruction: 'وجّه الكاميرا ليظهر الجزء العلوي والكتفين في إضاءة واضحة.',
    colorHex: 0xFF00ACC1, // Cyan / Teal
    protocolRegion: 'upper body garment',
  ),
  lowerPants(
    arabicTitle: 'البنطلون الكامل (الرجلين بالكامل)',
    shortLabel: 'بنطلون كامل',
    bodyPartDescription: 'من الخصر حتى الكاحلين (بنطلون جينز، رسمي، كارغو، رياضي)',
    framingInstruction: 'وجّه الكاميرا نحو منطقة الخصر والرجلين في إضاءة واضحة.',
    colorHex: 0xFF3B82F6, // Royal Blue
    protocolRegion: 'lower body garment',
  ),
  lowerShorts(
    arabicTitle: 'الشورت (أعلى الركبة)',
    shortLabel: 'شورت / ركبة',
    bodyPartDescription: 'من الخصر حتى الركبتين فقط مع الحفاظ على الساقين السفليتين',
    framingInstruction: 'وجّه الكاميرا نحو الخصر والركبتين في إضاءة واضحة.',
    colorHex: 0xFFF59E0B, // Amber / Orange
    protocolRegion: 'lower body garment',
  ),
  fullBody(
    arabicTitle: 'طقم كامل / فستان / عباية',
    shortLabel: 'طقم كامل / فستان',
    bodyPartDescription: 'الجذع والرجلين معاً كقطعة متكاملة (فستان، عباية، بدلة، طقم)',
    framingInstruction: 'قف أمام الكاميرا ليظهر الجسم في إضاءة واضحة.',
    colorHex: 0xFFA855F7, // Purple / Violet
    protocolRegion: 'outfit',
  ),
  footwear(
    arabicTitle: 'البوت والحذاء (القدمين)',
    shortLabel: 'بوات / القدمين',
    bodyPartDescription: 'القدمين والكاحلين فقط (بوات، سنيكرز، بوت جلدي، حذاء رسمي)',
    framingInstruction: 'وجّه الكاميرا نحو القدمين والكاحلين في إضاءة واضحة.',
    colorHex: 0xFF10B981, // Emerald Green
    protocolRegion: 'footwear',
  );

  const TryonBodyZone({
    required this.arabicTitle,
    required this.shortLabel,
    required this.bodyPartDescription,
    required this.framingInstruction,
    required this.colorHex,
    required this.protocolRegion,
  });

  final String arabicTitle;
  final String shortLabel;
  final String bodyPartDescription;
  final String framingInstruction;
  final int colorHex;
  final String protocolRegion;

  /// Auto-detects the default body zone from product name & category.
  static TryonBodyZone infer(String name, [String? category]) {
    final text = '${category ?? ''} $name'.toLowerCase();
    if (RegExp(r'dress[ -]?shirts?').hasMatch(text)) {
      return TryonBodyZone.upperBody;
    }
    if (RegExp(
      r'\bshoes?\b|\bsneakers?\b|\bboots?\b|\bheels?\b|\bsandals?\b|\bslippers?\b|\bloafer\b|حذاء|أحذية|احذية|بوات|بوت|سنيكرز|صندل|كعب',
    ).hasMatch(text)) {
      return TryonBodyZone.footwear;
    }
    if (RegExp(
      r'\bshorts?\b|\bskirts?\b|شورت|برمودا|تنور|جيبة',
    ).hasMatch(text)) {
      return TryonBodyZone.lowerShorts;
    }
    if (RegExp(
      r'\bdress(?:es)?\b|\bjumpsuits?\b|\babayas?\b|\bsuits?\b|\boutfits?\b|فستان|فساتين|عباي|عباء|جمبسوت|طقم|بدل',
    ).hasMatch(text)) {
      return TryonBodyZone.fullBody;
    }
    if (RegExp(
      r'\bpants?\b|\btrousers?\b|\bjeans\b|\bjoggers?\b|\bleggings?\b|بنطلون|بناطيل|جينز|سروال|لغينغ',
    ).hasMatch(text)) {
      return TryonBodyZone.lowerPants;
    }
    return TryonBodyZone.upperBody;
  }
}

class TryonFailure implements Exception {
  const TryonFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class GarmentSelection {
  const GarmentSelection({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.category,
    this.description,
    this.targetZone,
  });
  final String id;
  final String name;
  final String imageUrl;
  final String? category;
  final String? description;
  final TryonBodyZone? targetZone;

  TryonBodyZone get effectiveZone =>
      targetZone ?? TryonBodyZone.infer(name, category);

  String get region {
    if (targetZone != null) return targetZone!.protocolRegion;
    final text = '${category ?? ''} $name'.toLowerCase();
    if (RegExp(r'dress[ -]?shirts?').hasMatch(text)) {
      return 'upper body garment';
    }
    if (RegExp(
      r'\bdress(?:es)?\b|\bjumpsuits?\b|\babayas?\b|\bsuits?\b|فستان|فساتين|عباي|عباء|جمبسوت|طقم|بدل',
    ).hasMatch(text)) {
      return 'outfit';
    }
    if (RegExp(
      r'\bpants?\b|\btrousers?\b|\bjeans\b|\bskirts?\b|\bshorts?\b|بنطلون|بناطيل|جينز|تنور|شورت|برمودا',
    ).hasMatch(text)) {
      return 'lower body garment';
    }
    if (RegExp(
      r'\bshoes?\b|\bsneakers?\b|\bboots?\b|\bheels?\b|حذاء|أحذية|احذية|بوات|بوت|سنيكرز|كعب',
    ).hasMatch(text)) {
      return 'footwear';
    }
    if (RegExp(
      r'shirts?|hoodies?|sweaters?|tops?|jerseys?|jackets?|coats?|blazers?|تي\s*شيرت|تي\s*شرت|تيشيرت|قميص|قمصان|هودي|كنز|بلوز|سويت|جاكيت|بلوفر|سترة|معطف|بليزر|كارديغان',
    ).hasMatch(text)) {
      return 'upper body garment';
    }
    return 'corresponding clothing item';
  }

  String _short(String value, int limit) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= limit ? text : text.substring(0, limit);
  }

  String get _zonePlacementDirective => switch (effectiveZone) {
    TryonBodyZone.upperBody =>
      'Target anatomical zone: UPPER BODY ONLY (chest, shoulders, torso, and sleeves matching the reference cut). Keep pants/shorts, legs, footwear, hands, neck, head, and face 100% untouched.',
    TryonBodyZone.lowerPants =>
      'Target anatomical zone: FULL LEGS / PANTS ONLY (from waist and hips down to the ankles). Keep the upper body shirt/top, footwear/shoes, hands, head, and face 100% untouched.',
    TryonBodyZone.lowerShorts =>
      'Target anatomical zone: SHORTS / UPPER LEGS ONLY (from waist and hips down to just above the knees). Keep the lower calves/shins bare or unchanged, and keep the upper body top, footwear, hands, head, and face 100% untouched.',
    TryonBodyZone.fullBody =>
      'Target anatomical zone: FULL BODY OUTFIT (torso, waist, and legs as a cohesive dress/suit/abaya matching the reference length). Keep footwear, hands, neck, head, and face 100% untouched.',
    TryonBodyZone.footwear =>
      'Target anatomical zone: FOOTWEAR / FEET AND ANKLES ONLY (left and right shoes/boots/sneakers on the feet). Keep the legs, pants/shorts, upper body clothing, hands, head, and face 100% untouched.',
  };

  String get prompt =>
      'Substitute the $region with ${_short(name, 80)} from the supplied garment image. '
      '${category == null ? '' : 'Garment type: ${_short(category!, 50)}. '}'
      '${description == null ? '' : 'Visible product details: ${_short(description!, 160)}. '}'
      '$_zonePlacementDirective '
      'Reproduce the exact fabric weave, material texture, sheen, stitching seams, collar/hem structure, '
      'exact color shade, patterns, and visible logos or prints from the reference product image with photorealistic fidelity. '
      'Do not invent, simplify, or redesign any detail. '
      'Strictly preserve the person\'s real face, facial identity, expression, hair, skin tone, hands, '
      'and exact natural body size, width, and proportions without any slimming, enlarging, or reshaping. '
      'Drape and fit the garment naturally onto the person\'s actual body posture and scene lighting.';

  void validate() {
    final uri = Uri.tryParse(imageUrl);
    if (name.trim().isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw const TryonFailure('يلزم اسم قطعة ورابط HTTPS صالح لصورتها.');
    }
  }
}

class TryonSessionEvent {
  const TryonSessionEvent(this.status, {this.error});
  final DecartSessionStatus status;
  final String? error;
}

/// Domain boundary: no Flutter, WebRTC or network types.
abstract interface class TryonSession {
  Stream<TryonSessionEvent> get events;
  bool get isUsingFrontCamera;
  Future<void> start(GarmentSelection garment);
  Future<void> select(GarmentSelection garment);
  Future<void> switchCamera();
  Future<void> stop();
  Future<void> dispose();
}
