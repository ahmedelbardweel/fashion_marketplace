enum DecartSessionStatus {
  idle,
  initializing,
  connecting,
  connected,
  disconnected,
  error,
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
  });
  final String id;
  final String name;
  final String imageUrl;
  final String? category;
  final String? description;

  String get region {
    final text = '${category ?? ''} $name'.toLowerCase();
    if (RegExp(r'dress[ -]?shirts?').hasMatch(text))
      return 'upper body garment';
    if (RegExp(r'\bdress(?:es)?\b|\bjumpsuits?\b|فستان|فساتين|عباي|عباء|جمبسوت')
        .hasMatch(text))
      return 'outfit';
    if (RegExp(
      r'\bpants?\b|\btrousers?\b|\bjeans\b|\bskirts?\b|\bshorts?\b|بنطلون|بناطيل|تنور|شورت',
    ).hasMatch(text))
      return 'lower body garment';
    if (RegExp(r'\bshoes?\b|\bsneakers?\b|\bboots?\b|حذاء|أحذية|احذية')
        .hasMatch(text))
      return 'footwear';
    if (RegExp(
      r'shirts?|hoodies?|sweaters?|tops?|jerseys?|jackets?|تيشيرت|تيشرت|قميص|قمصان|هودي|كنز|بلوز|سويت|جاكيت',
    ).hasMatch(text))
      return 'upper body garment';
    return 'corresponding clothing item';
  }

  String _short(String value, int limit) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= limit ? text : text.substring(0, limit);
  }

  String get prompt =>
      'Substitute the $region with ${_short(name, 80)} from the supplied garment image. '
      '${category == null ? '' : 'Garment type: ${_short(category!, 50)}. '}'
      '${description == null ? '' : 'Visible product details: ${_short(description!, 160)}. '}'
      'Follow the reference image for garment shape, length, sleeves, neckline, '
      'colors, patterns, and visible logos or text. Preserve these details; '
      'do not invent or redesign them. Keep unrelated clothing unchanged.';

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
