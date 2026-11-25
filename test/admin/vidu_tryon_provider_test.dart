import 'package:fashion_marketplace/features/admin/data/admin_repository.dart';
import 'package:fashion_marketplace/features/admin/domain/models/decart_settings_status.dart';
import 'package:fashion_marketplace/features/admin/presentation/providers/admin_providers.dart';
import 'package:fashion_marketplace/features/admin/presentation/widgets/vidu_settings_card.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/decart_session_config.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_quota.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/tryon_quota_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdminRepository extends Fake implements AdminRepository {
  int viduAdds = 0;
  String? lastKey;
  String? lastLabel;
  TryonProvider? switchedTo;

  @override
  Future<void> addViduApiKey({required String apiKey, String? label}) async {
    viduAdds++;
    lastKey = apiKey;
    lastLabel = label;
  }

  @override
  Future<TryonCostControls> setTryonProvider(TryonProvider provider) async {
    switchedTo = provider;
    return TryonCostControls(activeProvider: provider);
  }
}

void main() {
  group('TryonProvider & Dual-Provider Models', () {
    test('TryonProvider.fromString resolves vidu and defaults to decart', () {
      expect(TryonProvider.fromString('vidu'), TryonProvider.vidu);
      expect(TryonProvider.fromString('VIDU'), TryonProvider.vidu);
      expect(TryonProvider.fromString('decart'), TryonProvider.decart);
      expect(TryonProvider.fromString(null), TryonProvider.decart);
      expect(TryonProvider.fromString('other'), TryonProvider.decart);
    });

    test('TryonQuota parses active_provider cleanly', () {
      final viduQuota = TryonQuota.fromMap({
        'enabled': true,
        'active_provider': 'vidu',
        'tokens_available': true,
        'daily_limit': 5,
        'used_today': 1,
        'remaining_today': 4,
      });
      expect(viduQuota.activeProvider, TryonProvider.vidu);
      expect(viduQuota.isBlocked, isFalse);
      expect(viduQuota.remainingToday, 4);

      final decartQuota = TryonQuota.fromMap({'enabled': true});
      expect(decartQuota.activeProvider, TryonProvider.decart);
    });

    test('TryonCostControls parses active_provider cleanly', () {
      final controls = TryonCostControls.fromMap({
        'enabled': true,
        'session_duration_seconds': 45,
        'daily_attempts_limit': 6,
        'active_provider': 'vidu',
      });
      expect(controls.activeProvider, TryonProvider.vidu);
      expect(controls.sessionDurationSeconds, 45);
      expect(controls.dailyAttemptsLimit, 6);
    });

    test('DecartCreditsBalance parses Vidu credits without fake Decart USD', () {
      final balance = DecartCreditsBalance.fromMap({
        'provider': 'vidu',
        'configured': true,
        'credits': 1000,
        'usd': null,
        'totalKeys': 1,
        'activeKeys': 1,
        'keys': [
          {
            'id': 'k1',
            'label': 'Vidu Main',
            'keyHint': 'vda_1023…S4a2',
            'isActive': true,
            'credits': 1000,
            'usd': null,
            'status': 'active',
          },
        ],
      }, defaultProvider: TryonProvider.vidu);

      expect(balance.provider, TryonProvider.vidu);
      expect(balance.hasBalance, isTrue);
      expect(balance.formattedCredits, '1000');
      expect(balance.hasUsd, isFalse);
      expect(balance.keys.single.hasUsd, isFalse);
      expect(balance.keys.single.formattedCredits, '1000');
    });

    test('TryonQuotaNotifier.updateFromSessionConfig preserves Vidu provider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(tryonQuotaProvider.notifier);
      notifier.updateFromQuota(
        const TryonQuota(
          enabled: true,
          activeProvider: TryonProvider.vidu,
          dailyLimit: 5,
          usedToday: 0,
          remainingToday: 5,
        ),
      );

      notifier.updateFromSessionConfig(
        DecartSessionConfig(
          clientToken: 'vidu_live',
          model: 'vidu-s2-editing',
          iceServers: const [],
          relayOnly: false,
          sessionDurationSeconds: 45,
          dailyLimit: 5,
          usedToday: 1,
          remainingToday: 4,
        ),
      );

      final updated = container.read(tryonQuotaProvider).requireValue;
      expect(updated.activeProvider, TryonProvider.vidu);
      expect(updated.usedToday, 1);
      expect(updated.remainingToday, 4);
      expect(updated.sessionDurationSeconds, 45);
    });
  });

  group('ViduSettingsCard widget', () {
    Future<void> mount(WidgetTester tester, _FakeAdminRepository repo) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminRepositoryProvider.overrideWithValue(repo),
            adminViduStatusProvider.overrideWith(
              (_) async => const DecartSettingsStatus(configured: false),
            ),
            adminViduCreditsProvider.overrideWith(
              (_) async => const DecartCreditsBalance(
                configured: false,
                provider: TryonProvider.vidu,
              ),
            ),
            adminViduKeysProvider.overrideWith((_) async => const []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ViduSettingsCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('accepts official vda_ key and clears field after save', (
      tester,
    ) async {
      final repo = _FakeAdminRepository();
      await mount(tester, repo);

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'حساب Vidu الأساسي');
      await tester.enterText(
        fields.at(1),
        'vda_1023124478671986688_abcdefghij1234567890',
      );
      await tester.tap(find.text('إضافة مفتاح Vidu للقائمة'));
      await tester.pumpAndSettle();

      expect(repo.viduAdds, 1);
      expect(repo.lastLabel, 'حساب Vidu الأساسي');
      expect(repo.lastKey, 'vda_1023124478671986688_abcdefghij1234567890');
      expect(find.textContaining('تمت إضافة مفتاح Vidu بنجاح'), findsOneWidget);
    });

    testWidgets('rejects non-vda keys (such as Decart dct_ keys)', (
      tester,
    ) async {
      final repo = _FakeAdminRepository();
      await mount(tester, repo);

      final fields = find.byType(TextFormField);
      await tester.enterText(
        fields.at(1),
        'dct_wasla_123456789012345678901234',
      );
      await tester.tap(find.text('إضافة مفتاح Vidu للقائمة'));
      await tester.pumpAndSettle();

      expect(repo.viduAdds, 0);
      expect(find.textContaining('vda_'), findsWidgets);
    });
  });
}
