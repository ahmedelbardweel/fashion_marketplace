import '../../../core/l10n/app_translations.dart';

enum DecartSessionStatus {
  idle,
  initializing,
  connecting,
  connected,
  disconnected,
  error,
}

/// Distinct anatomical body and accessory zones that the user can select on
/// the color-coded body diagram or auto-detect from the product metadata.
enum TryonBodyZone {
  upperBody(
    arabicTitle: 'الجزء العلوي (بلوزة / قميص / جاكيت)',
    shortLabel: 'الجزء العلوي',
    bodyPartDescription:
        'الصدر والكتفين والذراعين (بلوزة، تيشيرت، قميص، هودي، جاكيت)',
    framingInstruction:
        'وجّه الكاميرا ليظهر الجزء العلوي والكتفين في إضاءة واضحة.',
    colorHex: 0xFF00ACC1, // Cyan / Teal
    protocolRegion: 'upper body garment',
  ),
  lowerPants(
    arabicTitle: 'البنطلون الكامل (الرجلين بالكامل)',
    shortLabel: 'بنطلون كامل',
    bodyPartDescription:
        'من الخصر حتى الكاحلين (بنطلون جينز، رسمي، كارغو، رياضي)',
    framingInstruction:
        'وجّه الكاميرا نحو منطقة الخصر والرجلين في إضاءة واضحة.',
    colorHex: 0xFF3B82F6, // Royal Blue
    protocolRegion: 'lower body garment',
  ),
  lowerShorts(
    arabicTitle: 'الشورت (أعلى الركبة)',
    shortLabel: 'شورت / ركبة',
    bodyPartDescription:
        'من الخصر حتى الركبتين فقط مع الحفاظ على الساقين السفليتين',
    framingInstruction: 'وجّه الكاميرا نحو الخصر والركبتين في إضاءة واضحة.',
    colorHex: 0xFFF59E0B, // Amber / Orange
    protocolRegion: 'lower body garment',
  ),
  fullBody(
    arabicTitle: 'طقم كامل / فستان / عباية',
    shortLabel: 'طقم كامل / فستان',
    bodyPartDescription:
        'الجذع والرجلين معاً كقطعة متكاملة (فستان، عباية، بدلة، طقم)',
    framingInstruction: 'قف أمام الكاميرا ليظهر الجسم في إضاءة واضحة.',
    colorHex: 0xFFA855F7, // Purple / Violet
    protocolRegion: 'outfit',
  ),
  footwear(
    arabicTitle: 'البوت والحذاء (القدمين)',
    shortLabel: 'بوات / القدمين',
    bodyPartDescription:
        'القدمين والكاحلين فقط (بوات، سنيكرز، بوت جلدي، حذاء رسمي)',
    framingInstruction: 'وجّه الكاميرا نحو القدمين والكاحلين في إضاءة واضحة.',
    colorHex: 0xFF10B981, // Emerald Green
    protocolRegion: 'footwear',
  ),
  headFace(
    arabicTitle: 'الرأس والوجه والرقبة (نظارات / قبعة / عقد)',
    shortLabel: 'رأس / نظارات',
    bodyPartDescription:
        'النظارات الشمسية والطبية، القبعات، الحجاب، الأقراط، العقود والشالات',
    framingInstruction:
        'أظهر الوجه والرأس والرقبة بوضوح أمام الكاميرا في إضاءة جيدة.',
    colorHex: 0xFFEC4899, // Rose / Pink
    protocolRegion: 'head and face accessory',
  ),
  wristHand(
    arabicTitle: 'الساعات والمعصم واليد (ساعة / سوار / خاتم)',
    shortLabel: 'ساعة / معصم',
    bodyPartDescription:
        'ساعات اليد، الأساور، الخواتم والقفازات على المعصم أو اليد',
    framingInstruction:
        'ارفع يدك ومعصمك بوضوح أمام الكاميرا وثبّتهما في إضاءة واضحة.',
    colorHex: 0xFF6366F1, // Indigo
    protocolRegion: 'wrist and hand accessory',
  ),
  bags(
    arabicTitle: 'الحقائب والشنط (كتف / يد / ظهر)',
    shortLabel: 'شنط / حقائب',
    bodyPartDescription:
        'حقائب اليد، شنط الكتف والكروس، وحقائب الظهر',
    framingInstruction:
        'أظهر الكتف واليد بوضوح أمام الكاميرا ليظهر حمل الحقيبة بشكل طبيعي.',
    colorHex: 0xFFF97316, // Warm Orange
    protocolRegion: 'bag accessory',
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

  bool get isAccessory =>
      this == TryonBodyZone.headFace ||
      this == TryonBodyZone.wristHand ||
      this == TryonBodyZone.bags;

  /// Auto-detects the default body or accessory zone from product name & category.
  static TryonBodyZone infer(String name, [String? category]) {
    final text = '${category ?? ''} $name'.toLowerCase();
    if (RegExp(r'dress[ -]?shirts?').hasMatch(text)) {
      return TryonBodyZone.upperBody;
    }
    if (RegExp(
      r'\b(?:smart)?watch(?:es)?\b|\bbracelets?\b|\bbangles?\b|\brings?\b|\bgloves?\b|(?:^|\s)(?:ال)?(?:ساع(?:ة|ات)|سوار|أسور|اسور|أساور|اساور|خاتم|خواتم|دبل(?:ة|ه)|قفاز)',
    ).hasMatch(text)) {
      return TryonBodyZone.wristHand;
    }
    if (RegExp(
      r'\bsunglass(?:es)?\b|\bglasses\b|\beyewear\b|\bhats?\b|\bcaps?\b|\bbeanies?\b|\bscarf\b|\bscarves\b|\bhijabs?\b|\bshawls?\b|\bnecklaces?\b|\bpendants?\b|\bchains?\b|\bchokers?\b|\bearrings?\b|\bheadbands?\b|\bcrowns?\b|نظار|قبعة|قبعات|كاب|طاقي|حجاب|طرح(?:ة|ه)|شال|وشاح|عقد|سلسل|قلاد|حلق|أقراط|اقراط|تاج|طوق',
    ).hasMatch(text)) {
      return TryonBodyZone.headFace;
    }
    if (RegExp(
      r'\bhandbags?\b|\bbackpacks?\b|\bbags?\b|\bpurses?\b|\btotes?\b|\bclutches?\b|\bcrossbody\b|\bsatchels?\b|\bwallets?\b|حقيب|حقائب|شنط|جزدان|محفظ',
    ).hasMatch(text)) {
      return TryonBodyZone.bags;
    }
    if (RegExp(
      r'\bshoes?\b|\bsneakers?\b|\bboots?\b|\bheels?\b|\bsandals?\b|\bslippers?\b|\bloafer\b|حذاء|أحذية|احذية|بوات|بوت|سنيكرز|صندل|كعب|شبشب',
    ).hasMatch(text)) {
      return TryonBodyZone.footwear;
    }
    if (RegExp(
      r'\bshorts?\b|\bskirts?\b|شورت|برمودا|تنور|جيبة',
    ).hasMatch(text)) {
      return TryonBodyZone.lowerShorts;
    }
    if (RegExp(
      r'\bdress(?:es)?\b|\bjumpsuits?\b|\babayas?\b|\bsuits?\b|\boutfits?\b|\bkaftans?\b|فستان|فساتين|عباي|عباء|جمبسوت|طقم|بدل|جلابي|ثوب|قفطان',
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
    return TryonBodyZone.infer(name, category).protocolRegion;
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
    TryonBodyZone.headFace =>
      'Target anatomical zone: HEAD / FACE / NECK ACCESSORY ONLY (glasses, headwear, earrings, or necklace placed naturally on the head, face, ears, or neck). Keep facial identity, clothing, hands, and background 100% untouched.',
    TryonBodyZone.wristHand =>
      'Target anatomical zone: WRIST / HAND ACCESSORY ONLY (watch, bracelet, ring, or glove fitted naturally onto the visible wrist or hand). Keep fingers, face, clothing, and background 100% untouched.',
    TryonBodyZone.bags =>
      'Target anatomical zone: BAG ACCESSORY ONLY (handbag, shoulder bag, or backpack carried naturally on the shoulder or in hand). Keep face, clothing, body proportions, and background 100% untouched.',
  };

  String get prompt =>
      '${effectiveZone.isAccessory ? 'Add' : 'Substitute'} the $region with ${_short(name, 80)} from the supplied garment image. '
      '${category == null ? '' : 'Garment type: ${_short(category!, 50)}. '}'
      '${description == null ? '' : 'Visible product details: ${_short(description!, 160)}. '}'
      '$_zonePlacementDirective '
      'Reproduce the exact fabric weave, material texture, sheen, stitching seams, collar/hem structure, '
      'exact color shade, patterns, and visible logos or prints from the reference product image with photorealistic fidelity. '
      'Do not invent, simplify, or redesign any detail. '
      'Strictly preserve the person\'s real face, facial identity, expression, hair, skin tone, hands, '
      'and exact natural body size, width, and proportions without any slimming, enlarging, or reshaping. '
      'Keep the original background, objects, camera framing, perspective, and distance unchanged. '
      'Edit only the selected item; never zoom, crop, replace the person, or regenerate the scene. '
      'Drape and fit the item naturally onto the person\'s actual body posture and scene lighting.';

  void validate() {
    final uri = Uri.tryParse(imageUrl);
    if (name.trim().isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw TryonFailure('يلزم اسم قطعة ورابط HTTPS صالح لصورتها.'.tr);
    }
  }
}

class TryonSessionEvent {
  const TryonSessionEvent(this.status, {this.error});
  final DecartSessionStatus status;
  final String? error;
}

/// Domain boundary for realtime virtual try-on.
abstract class TryonSession {
  Stream<TryonSessionEvent> get events;
  bool get isUsingFrontCamera;
  Future<void> start(GarmentSelection garment);
  Future<void> select(GarmentSelection garment);
  Future<void> switchCamera();
  Future<void> stop();
  Future<void> dispose();
}
