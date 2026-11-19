import 'dart:async';

import 'package:decart_vton_flutter/decart_vton_flutter.dart';
import 'package:fashion_marketplace/core/services/decart_vton_sdk_service.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/decart_session_config.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/tryon_errors.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVtonClient implements VtonClient {
  final _events = StreamController<VtonEvent>.broadcast();

  bool initialized = false;
  VtonConnectionState state = VtonConnectionState.disconnected;
  VtonCameraFacing facing = VtonCameraFacing.front;
  VtonClientTokenProvider? tokenProvider;
  final List<VtonModel> connectedModels = [];
  final List<VtonOutfit?> connectedOutfits = [];
  final List<VtonOutfit> updatedOutfits = [];
  int disconnectCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<VtonEvent> get events => _events.stream;

  @override
  bool get isInitialized => initialized;

  @override
  VtonConnectionState get connectionState => state;

  @override
  VtonCameraFacing get cameraFacing => facing;

  @override
  Future<void> initialize({
    required VtonClientTokenProvider clientTokenProvider,
    VtonLogLevel logLevel = VtonLogLevel.warn,
    bool force = false,
  }) async {
    tokenProvider = clientTokenProvider;
    await clientTokenProvider();
    initialized = true;
  }

  @override
  Future<void> connect({
    required VtonModel model,
    VtonOutfit? initialOutfit,
    VtonCameraFacing camera = VtonCameraFacing.front,
  }) async {
    connectedModels.add(model);
    connectedOutfits.add(initialOutfit);
    facing = camera;
    state = VtonConnectionState.connected;
    _events.add(const VtonConnectionStateChanged(VtonConnectionState.connected));
  }

  @override
  Future<void> setOutfit({required VtonOutfit outfit}) async {
    updatedOutfits.add(outfit);
  }

  @override
  Future<VtonCameraFacing> switchCamera() async {
    facing = facing == VtonCameraFacing.front
        ? VtonCameraFacing.back
        : VtonCameraFacing.front;
    return facing;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    state = VtonConnectionState.disconnected;
    _events.add(
      const VtonConnectionStateChanged(VtonConnectionState.disconnected),
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _events.close();
  }

  void emitEvent(VtonEvent event) => _events.add(event);
}

void main() {
  GarmentSelection sampleGarment([String id = 'g1']) => GarmentSelection(
    id: id,
    name: 'Navy Hoodie',
    imageUrl: 'https://example.com/$id.jpg',
    targetZone: TryonBodyZone.upperBody,
  );

  test('refuses unsupported platforms before requesting permissions', () async {
    var permissionRequested = false;
    final service = DecartVtonSdkService(
      isPlatformSupported: false,
      ensureCameraPermission: () async {
        permissionRequested = true;
        return true;
      },
      loadConfig: () async => DecartSessionConfig(
        clientToken: 'ek_test',
        model: 'lucy-vton-latest',
      ),
    );

    await expectLater(
      () => service.start(sampleGarment()),
      throwsA(isA<TryonFailure>()),
    );
    expect(permissionRequested, isFalse);
    await service.dispose();
  });

  test('fails clearly when camera permission is denied', () async {
    final client = _FakeVtonClient();
    final service = DecartVtonSdkService(
      isPlatformSupported: true,
      createClient: () => client,
      ensureCameraPermission: () async => false,
      loadConfig: () async => DecartSessionConfig(
        clientToken: 'ek_test',
        model: 'lucy-vton-latest',
      ),
    );

    await expectLater(
      () => service.start(sampleGarment()),
      throwsA(
        isA<TryonFailure>().having(
          (e) => e.message,
          'message',
          contains('إذن الكاميرا'),
        ),
      ),
    );
    expect(client.initialized, isFalse);
    await service.dispose();
  });

  test('initializes with fresh token, connects with Lucy VTON and updates outfits', () async {
    final client = _FakeVtonClient();
    var tokenFetchCount = 0;
    final statuses = <TryonSessionEvent>[];

    final service = DecartVtonSdkService(
      isPlatformSupported: true,
      createClient: () => client,
      ensureCameraPermission: () async => true,
      resolveOutfit: (garment) async => VtonOutfit(
        prompt: garment.prompt,
        referenceImagePath: '/cache/${garment.id}.jpg',
      ),
      loadConfig: () async {
        tokenFetchCount++;
        return DecartSessionConfig(
          clientToken: 'ek_token_$tokenFetchCount',
          model: 'lucy-vton-3.6',
        );
      },
    );
    final sub = service.events.listen(statuses.add);

    await service.start(sampleGarment('item-1'));
    await Future<void>.delayed(Duration.zero);
    expect(tokenFetchCount, 1);
    expect(client.connectedModels, [VtonModel.lucyVtonLatest]);
    expect(client.connectedOutfits.single?.referenceImagePath, '/cache/item-1.jpg');
    expect(statuses.map((e) => e.status), containsAllInOrder([
      DecartSessionStatus.initializing,
      DecartSessionStatus.connecting,
      DecartSessionStatus.connected,
    ]));

    await service.select(sampleGarment('item-2'));
    expect(client.updatedOutfits.single.referenceImagePath, '/cache/item-2.jpg');

    await service.switchCamera();
    expect(service.isUsingFrontCamera, isFalse);

    client.emitEvent(
      const VtonConnectionStateChanged(VtonConnectionState.generating),
    );
    await Future<void>.delayed(Duration.zero);
    expect(service.isGenerating.value, isTrue);

    client.emitEvent(
      const VtonErrorOccurred(
        DecartVtonException(
          VtonErrorCode.invalidApiKey,
          'Expired token',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.status, DecartSessionStatus.error);
    expect(statuses.last.error, contains('مفتاح أو رصيد جلسة Decart'));

    await service.stop();
    expect(client.disconnectCalls, 1);

    await sub.cancel();
    await service.dispose();
    expect(client.disposeCalls, 1);
  });

  test('accepts JWT and ek_ client tokens while rejecting empty and dct_ keys', () {
    expect(validateVtonClientToken(' eyJhbGciOi.abc.xyz '), 'eyJhbGciOi.abc.xyz');
    expect(validateVtonClientToken('ek_live_123'), 'ek_live_123');
    expect(
      () => validateVtonClientToken('dct_wasla_123456'),
      throwsA(
        isA<DecartVtonException>().having(
          (e) => e.code,
          'code',
          VtonErrorCode.invalidApiKey,
        ),
      ),
    );
    expect(
      () => validateVtonClientToken('   '),
      throwsA(
        isA<DecartVtonException>().having(
          (e) => e.code,
          'code',
          VtonErrorCode.invalidApiKey,
        ),
      ),
    );
  });

  test('builds concise SDK prompts and maps/redacts VTON exceptions safely', () {
    final prompt = DecartVtonSdkService.buildSdkPrompt(sampleGarment('p1'));
    expect(prompt.length, lessThan(250));
    expect(prompt, contains('Substitute the current'));

    final creditErr = vtonExceptionToFailure(
      const DecartVtonException(
        VtonErrorCode.server,
        'HTTP 402 Insufficient credits',
        nativeCode: 'SERVER_ERROR',
      ),
    );
    expect(creditErr.message, contains('نفد رصيد'));

    final redacted = vtonExceptionToFailure(
      const DecartVtonException(
        VtonErrorCode.webrtc,
        'ICE failed at wss://api.decart.ai/v1/stream?api_key=eyJhbGciOi.secret dct_wasla_123456',
        nativeCode: 'WEBRTC_ICE_ERROR',
      ),
    );
    expect(redacted.message, contains('WEBRTC_ICE_ERROR'));
    expect(redacted.message, isNot(contains('wss://')));
    expect(redacted.message, isNot(contains('eyJhbGciOi')));
    expect(redacted.message, isNot(contains('dct_wasla_')));
  });
}
