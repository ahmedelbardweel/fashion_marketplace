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
  });
  final String id;
  final String name;
  final String imageUrl;

  String get prompt =>
      'Real-time virtual try-on: Maintain exact facial features, body posture, '
      'and lighting of the person in the video feed. Replace upper clothing with '
      '$name, ensuring natural fabric draping and dynamic movement matching body gestures.';

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
