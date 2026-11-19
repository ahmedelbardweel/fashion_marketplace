import '../domain/tryon_session.dart';

class DecartSessionConfig {
  DecartSessionConfig({
    required this.clientToken,
    required this.model,
    this.iceServers = const [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    this.relayOnly = false,
    this.sessionDurationSeconds = 30,
    this.dailyLimit = 3,
    this.usedToday = 0,
    this.remainingToday,
  });

  factory DecartSessionConfig.fromJson(Map<String, dynamic> json) {
    final token = json['apiKey'] as String?;
    final model = json['model'] as String?;
    if (token == null || token.isEmpty || model == null || model.isEmpty) {
      throw const TryonFailure('إعداد جلسة التجربة غير صالح.');
    }
    final duration = ((json['sessionDurationSeconds'] as num?)?.toInt() ?? 30)
        .clamp(10, 300);
    final limit = ((json['dailyLimit'] as num?)?.toInt() ?? 3).clamp(1, 100);
    final used = ((json['usedToday'] as num?)?.toInt() ?? 1).clamp(0, 1000);
    final remaining = (json['remainingToday'] as num?)?.toInt();
    return DecartSessionConfig(
      clientToken: token,
      model: model,
      iceServers:
          (json['iceServers'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
      relayOnly: json['relayOnly'] == true,
      sessionDurationSeconds: duration,
      dailyLimit: limit,
      usedToday: used,
      remainingToday: remaining?.clamp(0, 100),
    );
  }

  final String clientToken;
  final String model;
  final List<Map<String, dynamic>> iceServers;
  final bool relayOnly;
  final int sessionDurationSeconds;
  final int dailyLimit;
  final int usedToday;
  final int? remainingToday;

  Uri get signalingUri => Uri.https('api.decart.ai', '/v1/stream', {
    'api_key': clientToken,
    'model': model,
  }).replace(scheme: 'wss');

  Map<String, dynamic> get peerConfiguration => {
    'iceServers': iceServers,
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': relayOnly ? 'relay' : 'all',
  };
}
