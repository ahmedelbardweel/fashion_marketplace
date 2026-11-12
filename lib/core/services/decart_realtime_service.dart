import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../features/virtual_tryon/data/decart_session_config.dart';
import '../../features/virtual_tryon/data/garment_payload_loader.dart';
import '../../features/virtual_tryon/data/webrtc_camera_source.dart';
import '../../features/virtual_tryon/data/tryon_errors.dart';
import '../../features/virtual_tryon/data/capture_guard.dart';
import '../../features/virtual_tryon/domain/tryon_session.dart';

export '../../features/virtual_tryon/domain/tryon_session.dart';

/// Native media plane + serialized WebSocket control plane. No video frame
/// buffers enter the signaling protocol. The capture guard samples bounded
/// snapshots locally; no permanent API key lives in the client.
class DecartRealtimeService implements TryonSession {
  DecartRealtimeService({
    required this.loadConfig,
    required this.captureGuard,
    this.acknowledgmentTimeout = const Duration(seconds: 15),
    WebRtcCameraSource? camera,
    http.Client? imageClient,
    Future<RTCPeerConnection> Function(Map<String, dynamic>)? peerFactory,
    WebSocketChannel Function(Uri)? socketFactory,
    this.payloadLoader,
  }) : _camera = camera ?? WebRtcCameraSource(),
       _images = imageClient ?? http.Client(),
       _peerFactory = peerFactory ?? createPeerConnection,
       _socketFactory = socketFactory ?? WebSocketChannel.connect;

  final Future<DecartSessionConfig> Function() loadConfig;
  final CaptureGuard captureGuard;
  final Duration acknowledgmentTimeout;
  final WebRtcCameraSource _camera;
  final http.Client _images;
  final Future<RTCPeerConnection> Function(Map<String, dynamic>) _peerFactory;
  final WebSocketChannel Function(Uri) _socketFactory;
  final Future<String> Function(GarmentSelection)? payloadLoader;
  final _events = StreamController<TryonSessionEvent>.broadcast();
  @override
  Stream<TryonSessionEvent> get events => _events.stream;
  @override
  bool get isUsingFrontCamera => _camera.front;

  // Presentation attaches an RTCVideoRenderer through this adapter callback.
  void Function(MediaStream?)? onRemoteStream;
  RTCPeerConnection? _peer;
  MediaStream? _local;
  MediaStream? _remote;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Future<void> _operations = Future.value();
  Future<void> _messages = Future.value();
  final List<RTCIceCandidate> _remoteIce = [];
  final List<Map<String, dynamic>> _localIce = [];
  Completer<void>? _imageAck;
  int? _selectionGeneration;
  Timer? _deadline;
  Timer? _disconnectDeadline;
  int _generation = 0;
  bool _disposed = false;
  bool _socketReady = false;
  bool _offerSent = false;
  bool _hasAnswer = false;
  bool _hasFrame = false;
  bool _initialAccepted = false;
  bool _peerConnected = false;
  bool _reportedConnected = false;

  bool _current(int generation) => !_disposed && generation == _generation;
  void _emit(DecartSessionStatus status, [String? error]) {
    if (!_disposed) _events.add(TryonSessionEvent(status, error: error));
  }

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> start(GarmentSelection garment) {
    if (_disposed) return Future.value();
    final generation = ++_generation;
    _cancelAck();
    return _serialize(() => _start(generation, garment));
  }

  Future<void> _start(int generation, GarmentSelection garment) async {
    await _cleanup();
    if (!_current(generation)) return;
    _emit(DecartSessionStatus.initializing);
    var stage = TryonStartupStage.camera;
    try {
      garment.validate();
      // If a permission dialog outlives cancellation, dispose its late stream.
      final capture = _camera.open().then((stream) async {
        if (!_current(generation)) {
          for (final track in stream.getTracks()) {
            await track.stop();
          }
          await stream.dispose();
          throw const TryonFailure('تم إلغاء الجلسة.');
        }
        return stream;
      });
      _local = await capture.timeout(const Duration(seconds: 30));
      if (!_current(generation)) return;
      stage = TryonStartupStage.session;
      final cameraTrack = _local!.getVideoTracks().firstOrNull;
      if (cameraTrack != null) await _camera.resetZoom(cameraTrack);
      if (!_current(generation)) return;
      // No token, peer, or uploaded camera frames before local validation + consent.
      await captureGuard.validate(
        _local!,
        garment,
        (message) => _fail(generation, message),
      );
      if (!_current(generation)) return;
      final config = await loadConfig().timeout(const Duration(seconds: 15));
      if (!_current(generation)) return;
      stage = TryonStartupStage.peer;
      _peer = await _peerFactory(config.peerConfiguration);
      if (!_current(generation)) return;
      final peer = _peer!;
      peer.onIceCandidate = (candidate) {
        if (!_current(generation)) return;
        final message = <String, dynamic>{
          'type': 'ice-candidate',
          'candidate': candidate.candidate?.isNotEmpty == true
              ? {
                  'candidate': candidate.candidate,
                  'sdpMid': candidate.sdpMid,
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                }
              : null,
        };
        if (_offerSent) {
          try {
            _send(message);
          } catch (_) {
            _fail(generation, 'تعذر إرسال بيانات الاتصال.');
          }
        } else {
          _localIce.add(message);
        }
      };
      peer.onTrack = (event) {
        if (!_current(generation) || event.track.kind != 'video') return;
        unawaited(_attachRemote(event, generation));
      };
      peer.onConnectionState = (state) {
        if (!_current(generation)) return;
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _peerConnected = true;
            _disconnectDeadline?.cancel();
            _maybeReady();
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _peerConnected = false;
            _reportedConnected = false;
            _emit(DecartSessionStatus.connecting);
            _disconnectDeadline?.cancel();
            _disconnectDeadline = Timer(
              const Duration(seconds: 8),
              () => _fail(generation, 'انقطع اتصال الفيديو. أعد المحاولة.'),
            );
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _fail(
              generation,
              'تعذر إنشاء اتصال الفيديو. تحقق من الشبكة وخادم TURN.',
            );
          default:
            break;
        }
      };
      for (final track in _local!.getVideoTracks()) {
        await peer.addTrack(track, _local!);
      }
      if (!_current(generation)) return;
      _emit(DecartSessionStatus.connecting);
      stage = TryonStartupStage.signaling;
      _socket = _socketFactory(config.signalingUri);
      _subscription = _socket!.stream.listen(
        (message) {
          // SDP and ICE must never race each other across async listeners.
          _messages = _messages
              .then((_) async {
                if (_current(generation)) {
                  await _handleMessage(message, generation);
                }
              })
              .catchError((Object _) {
                _fail(generation, 'وصلت رسالة اتصال غير صالحة من الخادم.');
              });
        },
        onError: (Object _) {
          _fail(generation, 'تعذر الاتصال بخادم التجربة.');
        },
        onDone: () {
          _fail(generation, 'أُغلق اتصال الخادم. أعد المحاولة.');
        },
      );
      await _socket!.ready.timeout(const Duration(seconds: 15));
      if (!_current(generation)) return;
      _socketReady = true;
      _deadline = Timer(const Duration(seconds: 35), () {
        _fail(generation, 'لم يصل فيديو معالج من الخادم ضمن المهلة.');
      });
      await _offer(generation);
      if (!_current(generation)) return;
      stage = TryonStartupStage.garment;
      await _select(garment);
      if (!_current(generation)) return;
      _initialAccepted = true;
      _maybeReady();
    } catch (error) {
      _fail(generation, startupFailure(error, stage).message);
    }
  }

  Future<void> _attachRemote(RTCTrackEvent event, int generation) async {
    try {
      final stream = event.streams.isNotEmpty
          ? event.streams.first
          : await createLocalMediaStream('decart-remote-$generation');
      if (!_current(generation)) {
        await stream.dispose();
        return;
      }
      if (event.streams.isEmpty) await stream.addTrack(event.track);
      if (!_current(generation)) {
        await stream.dispose();
        return;
      }
      _remote = stream;
      onRemoteStream?.call(stream);
    } catch (_) {
      _fail(generation, 'تعذر عرض الفيديو المرتجع.');
    }
  }

  /// Called after a native renderer callback or a browser video frame; never SDP/ICE.
  void notifyFirstRemoteFrame() {
    if (_remote == null || _disposed) return;
    _hasFrame = true;
    _maybeReady();
  }

  void _maybeReady() {
    if (_hasFrame &&
        _initialAccepted &&
        _peerConnected &&
        !_reportedConnected) {
      _deadline?.cancel();
      _reportedConnected = true;
      _emit(DecartSessionStatus.connected);
    }
  }

  Future<void> _offer(int generation, {bool restart = false}) async {
    _offerSent = false;
    _hasAnswer = false;
    final peer = _peer!;
    final offer = await peer.createOffer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': false,
      if (restart) 'iceRestart': true,
    });
    if (!_current(generation)) return;
    await peer.setLocalDescription(offer);
    if (!_current(generation)) return;
    _send({'type': 'offer', 'sdp': offer.sdp});
    _offerSent = true;
    for (final message in _localIce) {
      _send(message);
    }
    _localIce.clear();
  }

  Future<void> _handleMessage(dynamic raw, int generation) async {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    final peer = _peer!;
    switch (data['type']) {
      case 'answer':
        await peer.setRemoteDescription(
          RTCSessionDescription(data['sdp'] as String, 'answer'),
        );
        if (!_current(generation)) return;
        _hasAnswer = true;
        for (final candidate in _remoteIce) {
          await peer.addCandidate(candidate);
        }
        _remoteIce.clear();
      case 'ice-candidate':
        final value = data['candidate'];
        if (value == null) return;
        final candidate = RTCIceCandidate(
          value['candidate'] as String?,
          value['sdpMid'] as String?,
          (value['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_hasAnswer) {
          await peer.addCandidate(candidate);
        } else {
          _remoteIce.add(candidate);
        }
      case 'set_image_ack':
        final ack = _imageAck;
        if (ack != null && !ack.isCompleted) {
          if (data['success'] == true) {
            ack.complete();
          } else {
            ack.completeError(
              const TryonFailure('رفض الخادم صورة القطعة أو وصفها.'),
            );
          }
        }
      case 'prompt_ack':
        if (data['success'] == false) {
          _fail(generation, 'رفض الخادم وصف القطعة. اختر قطعة أخرى.');
        }
      case 'ice-restart':
        final turn = data['turn_config'] as Map<String, dynamic>?;
        if (turn != null) {
          final config = Map<String, dynamic>.from(peer.getConfiguration);
          config['iceServers'] = [
            ...?config['iceServers'] as List?,
            {
              'urls': turn['server_url'],
              'username': turn['username'],
              'credential': turn['credential'],
            },
          ];
          await peer.setConfiguration(config);
        }
        if (_current(generation)) await _offer(generation, restart: true);
      case 'error':
      case 'generation_ended':
        _fail(
          generation,
          'أنهى الخادم الجلسة أو رفض الاتصال. تحقق من الرصيد وإعدادات الخدمة.',
        );
      default:
        break; // session_id, generation_started/tick and forward-compatible events.
    }
  }

  void _send(Map<String, dynamic> data) {
    if (!_socketReady) throw const TryonFailure('قناة الاتصال غير جاهزة.');
    _socket!.sink.add(jsonEncode(data));
  }

  @override
  Future<void> select(GarmentSelection garment) async {
    final generation = _generation;
    final local = _local;
    if (local == null || !_reportedConnected) {
      throw const TryonFailure('أعد فحص الجسم قبل اختيار القطعة.');
    }
    await captureGuard.validate(
      local,
      garment,
      (message) => _fail(generation, message),
    );
    if (!_current(generation)) throw const TryonFailure('انتهت الجلسة.');
    await _select(garment);
  }

  Future<void> _select(GarmentSelection garment) async {
    final generation = _generation;
    if (!_socketReady || _selectionGeneration != null) {
      throw const TryonFailure('انتظر اكتمال تحديث القطعة الحالية.');
    }
    _selectionGeneration = generation;
    try {
      final loader = payloadLoader ?? GarmentPayloadLoader(_images).load;
      final payload = await loader(garment)
          .timeout(const Duration(seconds: 20));
      if (!_current(generation) || !_socketReady) {
        throw const TryonFailure('انتهت الجلسة.');
      }
      // Protocol acknowledgments have no request ID; one update in flight.
      final ack = Completer<void>();
      _imageAck = ack;
      try {
        _socket!.sink.add(payload);
        await ack.future.timeout(acknowledgmentTimeout);
      } on TimeoutException {
        _fail(generation, 'لم يؤكد الخادم تحديث القطعة. أعد الاتصال.');
        throw const TryonFailure('انتهت مهلة تأكيد القطعة.');
      } finally {
        if (identical(_imageAck, ack)) _imageAck = null;
      }
    } finally {
      if (_selectionGeneration == generation) _selectionGeneration = null;
    }
  }

  @override
  Future<void> switchCamera() => _serialize(() async {
    final track = _local?.getVideoTracks().firstOrNull;
    if (track == null || !_reportedConnected) return;
    try {
      // Switching invalidates the calibrated frame and requires a fresh session.
      captureGuard.cancel();
      final switched = await Helper.switchCamera(track);
      if (switched) {
        _camera.front = !_camera.front;
        await _camera.resetZoom(track);
      }
      _fail(_generation, 'تم تغيير الكاميرا. أعد فحص الجسم قبل التجربة.');
    } catch (_) {
      throw const TryonFailure('تعذر تبديل الكاميرا.');
    }
  });

  void _cancelAck() {
    _selectionGeneration = null;
    final ack = _imageAck;
    _imageAck = null;
    if (ack != null && !ack.isCompleted) {
      ack.completeError(const TryonFailure('انتهت الجلسة.'));
    }
  }

  void _fail(int generation, String message) {
    if (!_current(generation)) return;
    ++_generation;
    captureGuard.cancel();
    _cancelAck();
    _emit(DecartSessionStatus.error, message);
    unawaited(_serialize(_cleanup));
  }

  @override
  Future<void> stop() {
    ++_generation;
    captureGuard.cancel();
    _cancelAck();
    _emit(DecartSessionStatus.disconnected);
    return _serialize(_cleanup);
  }

  Future<void> _cleanup() async {
    _deadline?.cancel();
    _disconnectDeadline?.cancel();
    _socketReady = _offerSent = _hasAnswer = _hasFrame = false;
    _initialAccepted = _peerConnected = _reportedConnected = false;
    _remoteIce.clear();
    _localIce.clear();
    try {
      onRemoteStream?.call(null);
    } catch (_) {
      /* Continue releasing media. */
    }
    final subscription = _subscription;
    _subscription = null;
    final socket = _socket;
    _socket = null;
    final peer = _peer;
    _peer = null;
    final local = _local;
    _local = null;
    final remote = _remote;
    _remote = null;
    // One platform teardown failure must not skip remaining releases.
    Future<void> release(Future<void> Function() action) async {
      try {
        await action().timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Best effort teardown. */
      }
    }

    if (subscription != null) await release(subscription.cancel);
    if (socket != null) {
      await release(() async {
        await socket.sink.close();
      });
    }
    if (peer != null) {
      peer.onTrack = null;
      peer.onIceCandidate = null;
      peer.onConnectionState = null;
      await release(peer.close);
      await release(peer.dispose);
    }
    for (final stream in [local, remote]) {
      if (stream == null) continue;
      for (final track in stream.getTracks()) {
        await release(track.stop);
      }
      await release(stream.dispose);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    captureGuard.cancel();
    _cancelAck();
    await _serialize(_cleanup);
    _images.close();
    await _events.close();
  }
}
