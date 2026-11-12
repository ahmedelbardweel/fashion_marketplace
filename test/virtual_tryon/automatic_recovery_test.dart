import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fashion_marketplace/features/customer/domain/models/customer_product.dart';
import 'package:fashion_marketplace/features/customer/presentation/providers/decart_tryon_provider.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/automatic_tryon_recovery.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/body_analysis_failure.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/tryon_errors.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_session.dart';

import 'tryon_controller_test.dart' show FakeSession, product;

class _RecoveringSession extends FakeSession {
  String? failure = BodyAnalysisFailure('frame_decode').message;
  final garments = <String>[];
  @override
  Future<void> start(GarmentSelection garment) async {
    starts++;
    garments.add(garment.id);
    controller.add(
      TryonSessionEvent(
        failure == null
            ? DecartSessionStatus.connected
            : DecartSessionStatus.error,
        error: failure,
      ),
    );
  }
}

void main() {
  test(
    'permission, config, unsupported analysis and unknown failures do not loop',
    () {
      for (final message in [
        cameraFailure(StateError('NotAllowedError')).message,
        sessionHttpFailure(401).message,
        sessionHttpFailure(429).message,
        sessionHttpFailure(503).message,
        BodyAnalysisFailure('unsupported').message,
        BodyAnalysisFailure('bridge_missing').message,
        'unknown',
      ]) {
        final recovery = AutomaticTryonRecovery();
        expect(recovery.nextDelay(message), isNull, reason: message);
        expect(recovery.attempts, 0);
      }
    },
  );

  testWidgets(
    'transient failure retries three times with backoff and preserves garment',
    (tester) async {
      final session = _RecoveringSession();
      final notifier = DecartTryonNotifier(
        session,
        () async => [product('a')],
        'a',
      );
      await notifier.start();
      expect(notifier.state.retryPending, isTrue);
      expect(session.starts, 1);
      for (final seconds in [2, 4, 8]) {
        await tester.pump(Duration(seconds: seconds - 1));
        final before = session.starts;
        await tester.pump(const Duration(seconds: 1));
        expect(session.starts, before + 1);
      }
      expect(session.garments, ['a', 'a', 'a', 'a']);
      expect(notifier.state.retryPending, isFalse);
      expect(notifier.state.retryAttempt, 3);
      await tester.pump(const Duration(minutes: 1));
      expect(session.starts, 4);
      notifier.dispose();
      await session.dispose();
    },
  );

  testWidgets(
    'background cancels retries; resume and successful recovery do not duplicate start',
    (tester) async {
      final session = _RecoveringSession();
      final notifier = DecartTryonNotifier(
        session,
        () async => [product('a')],
        'a',
      );
      await notifier.start();
      await notifier.suspend();
      await tester.pump(const Duration(seconds: 10));
      expect(session.starts, 1);
      expect(notifier.state.retryPending, isFalse);
      session.failure = null;
      await notifier.resume();
      expect(session.starts, 2);
      expect(notifier.state.isConnected, isTrue);
      await tester.pump(const Duration(seconds: 20));
      expect(session.starts, 2);
      notifier.dispose();
      await session.dispose();
    },
  );

  testWidgets('dispose cancels a scheduled automatic retry', (tester) async {
    final session = _RecoveringSession();
    final notifier = DecartTryonNotifier(
      session,
      () async => [product('a')],
      'a',
    );
    await notifier.start();
    notifier.dispose();
    await tester.pump(const Duration(seconds: 10));
    expect(session.starts, 1);
    await session.dispose();
  });

  testWidgets(
    'resume waits for obsolete startup; another pause cancels that resume',
    (tester) async {
      final session = _RecoveringSession()..failure = null;
      final catalog = Completer<List<CustomerProduct>>();
      final notifier = DecartTryonNotifier(session, () => catalog.future, 'a');
      final starting = notifier.start();
      await notifier.suspend();
      final resuming = notifier.resume();
      await notifier.suspend();
      catalog.complete([product('a')]);
      await starting;
      await resuming;
      expect(session.starts, 0);
      await notifier.resume();
      expect(session.starts, 1);
      notifier.dispose();
      await session.dispose();
    },
  );
}
