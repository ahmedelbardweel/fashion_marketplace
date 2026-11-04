import '../domain/tryon_session.dart';

class DecartSessionConfig {
  DecartSessionConfig({
    required this.clientToken,
    required this.model,
    this.iceServers = const [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    this.relayOnly = false,
  });

  factory DecartSessionConfig.fromJson(Map<String, dynamic> json) {
    final token = json['apiKey'] as String?;
    final model = json['model'] as String?;
    if (token == null || token.isEmpty || model == null || model.isEmpty) {
      throw const TryonFailure('إعداد جلسة التجربة غير صالح.');
    }
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
    );
  }

  final String clientToken;
  final String model;
  final List<Map<String, dynamic>> iceServers;
  final bool relayOnly;

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
