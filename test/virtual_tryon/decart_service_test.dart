import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fashion_marketplace/core/services/decart_realtime_service.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/decart_session_config.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/webrtc_camera_source.dart';

class Track extends Fake implements MediaStreamTrack {
  bool stopped = false;
  @override
  String get kind => 'video';
  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class VideoStream extends Fake implements MediaStream {
  final track = Track();
  bool disposed = false;
  @override
  List<MediaStreamTrack> getTracks() => [track];
  @override
  List<MediaStreamTrack> getVideoTracks() => [track];
  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class Camera extends WebRtcCameraSource {
  final stream = VideoStream();
  @override
  Future<MediaStream> open() async => stream;
}

class Sender extends Fake implements RTCRtpSender {}

class Peer extends RTCPeerConnection {
  final candidates = <RTCIceCandidate>[];
  bool answered = false;
  bool closed = false;
  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async => Sender();
  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) async => RTCSessionDescription('offer-sdp', 'offer');
  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    onIceCandidate?.call(RTCIceCandidate('local', '0', 0));
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    answered = true;
  }

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {
    expect(answered, isTrue, reason: 'ICE must wait for remote SDP');
    candidates.add(candidate);
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SocketSink extends Fake implements WebSocketSink {
  final sent = <Map<String, dynamic>>[];
  final closed = Completer<void>();
  @override
  void add(dynamic value) =>
      sent.add(jsonDecode(value as String) as Map<String, dynamic>);
  @override
  Future<void> close([int? code, String? reason]) async {
    if (!closed.isCompleted) closed.complete();
  }
}

class Socket extends Fake implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  @override
  final SocketSink sink = SocketSink();
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  Future<void> get ready async {}
  void receive(Map<String, dynamic> message) =>
      incoming.add(jsonEncode(message));
}

void main() {
  const garment = GarmentSelection(
    id: 'a',
    name: 'Hoodie',
    imageUrl: 'https://example.com/a.png',
  );
  late Camera camera;
  late Peer peer;
  late Socket socket;
  late DecartRealtimeService service;
  late List<TryonSessionEvent> events;
  setUp(() {
    camera = Camera();
    peer = Peer();
    socket = Socket();
    events = [];
    service = DecartRealtimeService(
      camera: camera,
      acknowledgmentTimeout: const Duration(seconds: 1),
      loadConfig: () async =>
          DecartSessionConfig(clientToken: 'temporary', model: 'lucy-vton-3.6'),
      peerFactory: (_) async => peer,
      socketFactory: (_) => socket,
      payloadLoader: (g) async =>
          jsonEncode({'type': 'set_image', 'prompt': g.prompt}),
    );
    service.events.listen(events.add);
  });
  tearDown(() async {
    await service.dispose();
    await socket.incoming.close();
  });

  test(
    'queues ICE; only remote frame plus ack and connected peer are ready',
    () async {
      final starting = service.start(garment);
      await Future<void>.delayed(Duration.zero);
      expect(socket.sink.sent.map((e) => e['type']), [
        'offer',
        'ice-candidate',
        'set_image',
      ]);
      socket.receive({
        'type': 'ice-candidate',
        'candidate': {'candidate': 'remote', 'sdpMid': '0', 'sdpMLineIndex': 0},
      });
      socket.receive({'type': 'answer', 'sdp': 'answer-sdp'});
      await Future<void>.delayed(Duration.zero);
      expect(peer.candidates.length, 1);
      peer.onConnectionState!(
        RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      );
      final remote = VideoStream();
      peer.onTrack!(RTCTrackEvent(streams: [remote], track: remote.track));
      await Future<void>.delayed(Duration.zero);
      expect(events.last.status, isNot(DecartSessionStatus.connected));
      service.notifyFirstRemoteFrame();
      await Future<void>.delayed(Duration.zero);
      expect(events.last.status, isNot(DecartSessionStatus.connected));
      socket.receive({'type': 'set_image_ack', 'success': true});
      await Future<void>.delayed(Duration.zero);
      await starting;
      expect(events.last.status, DecartSessionStatus.connected);
      await service.stop();
      expect(camera.stream.track.stopped, true);
      expect(camera.stream.disposed, true);
      expect(remote.disposed, true);
      expect(peer.closed, true);
    },
  );

  test(
    'missing acknowledgment fails and releases camera without local fallback',
    () async {
      final starting = service.start(garment);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(events.last.status, DecartSessionStatus.error);
      expect(
        events.where((e) => e.status == DecartSessionStatus.connected),
        isEmpty,
      );
      expect(camera.stream.track.stopped, true);
      expect(peer.closed, true);
    },
  );

  test(
    'socket closure during startup cancels pending ack and releases resources',
    () async {
      final starting = service.start(garment);
      await Future<void>.delayed(Duration.zero);
      await socket.incoming.close();
      await Future<void>.delayed(Duration.zero);
      await starting;
      expect(events.last.status, DecartSessionStatus.error);
      expect(camera.stream.disposed, true);
      expect(peer.closed, true);
    },
  );
}
