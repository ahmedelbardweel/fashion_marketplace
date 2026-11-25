/// Active AI engine powering the Virtual Try-On experience.
enum TryonProvider {
  decart('decart'),
  vidu('vidu');

  const TryonProvider(this.apiValue);

  final String apiValue;

  String get displayName => switch (this) {
    TryonProvider.decart => 'Decart AI',
    TryonProvider.vidu => 'Vidu AI',
  };

  String get shortLabel => switch (this) {
    TryonProvider.decart => 'Decart',
    TryonProvider.vidu => 'Vidu',
  };

  String get modeDescription => switch (this) {
    TryonProvider.decart => 'بث مباشر بالكاميرا (Decart Live)',
    TryonProvider.vidu => 'بث مباشر بالكاميرا (Vidu Stream Live)',
  };

  static TryonProvider fromString(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase();
    return switch (normalized) {
      'vidu' => TryonProvider.vidu,
      _ => TryonProvider.decart,
    };
  }
}
