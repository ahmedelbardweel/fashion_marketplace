import 'package:fashion_marketplace/core/l10n/app_translations.dart';
import 'package:fashion_marketplace/features/admin/data/admin_repository.dart';
import 'package:fashion_marketplace/features/admin/domain/models/decart_settings_status.dart';
import 'package:fashion_marketplace/features/admin/presentation/providers/admin_providers.dart';
import 'package:fashion_marketplace/features/admin/presentation/widgets/tryon_cost_controls_card.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/decart_session_config.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/tryon_errors.dart';
import 'package:fashion_marketplace/features/virtual_tryon/data/tryon_onboarding_store.dart';
import 'package:fashion_marketplace/features/virtual_tryon/domain/tryon_quota.dart';
import 'package:fashion_marketplace/features/virtual_tryon/presentation/tryon_guidelines_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdminRepo extends Fake implements AdminRepository {
  bool? savedEnabled;
  int? savedDuration;
  int? savedLimit;
  TryonProvider? savedProvider;

  @override
  Future<TryonCostControls> updateTryonControls({
    required bool enabled,
    required int sessionDurationSeconds,
    required int dailyAttemptsLimit,
    TryonProvider? activeProvider,
  }) async {
    savedEnabled = enabled;
    savedDuration = sessionDurationSeconds;
    savedLimit = dailyAttemptsLimit;
    savedProvider = activeProvider;
    return TryonCostControls(
      enabled: enabled,
      sessionDurationSeconds: sessionDurationSeconds,
      dailyAttemptsLimit: dailyAttemptsLimit,
      activeProvider: activeProvider ?? TryonProvider.decart,
    );
  }
}

void main() {
  testWidgets(
    'TryonGuidelinesView blocks Next until checkbox is accepted and translates to English',
    (tester) async {
      addTearDown(() => AppLang.isEn = false);
      var continued = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TryonGuidelinesView(
            sessionDurationSeconds: 30,
            dailyLimit: 3,
            onBack: () {},
            onContinue: () => continued++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضاءة قوية وواضحة'), findsOneWidget);
      expect(find.text('كاميرا نظيفة وثابتة'), findsOneWidget);
      expect(find.text('إنترنت قوي ومستقر'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(continued, 0);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(continued, 1);

      AppLang.isEn = true;
      await tester.pumpWidget(
        MaterialApp(
          home: TryonGuidelinesView(
            sessionDurationSeconds: 45,
            dailyLimit: 5,
            onBack: () {},
            onContinue: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Strong, Clear Lighting'), findsOneWidget);
      expect(find.text('I agree to the terms and guidelines'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Session duration: 45s · Daily limit: 5 tries per day'),
        200,
      );
      expect(
        find.text('Session duration: 45s · Daily limit: 5 tries per day'),
        findsOneWidget,
      );
    },
  );

  test('TryonOnboardingStore persists acceptance per user account', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await TryonOnboardingStore.hasAccepted('user-a'), isFalse);
    expect(await TryonOnboardingStore.hasAccepted('user-b'), isFalse);

    await TryonOnboardingStore.markAccepted('user-a');
    expect(await TryonOnboardingStore.hasAccepted('user-a'), isTrue);
    expect(await TryonOnboardingStore.hasAccepted('user-b'), isFalse);
  });

  test('TryonQuota, DecartSessionConfig, and sessionFunctionFailure enforce limits in AR & EN', () {
    addTearDown(() => AppLang.isEn = false);

    final quota = TryonQuota.fromMap({
      'enabled': true,
      'session_duration_seconds': 30,
      'daily_limit': 3,
      'used_today': 2,
      'remaining_today': 1,
    });
    expect(quota.hasRemaining, isTrue);
    expect(quota.sessionDurationSeconds, 30);

    final cfg = DecartSessionConfig.fromJson({
      'apiKey': 'eyJtest.token',
      'model': 'lucy-vton-latest',
      'sessionDurationSeconds': 30,
      'dailyLimit': 3,
      'usedToday': 1,
      'remainingToday': 2,
    });
    expect(cfg.sessionDurationSeconds, 30);
    expect(cfg.remainingToday, 2);

    final arLimit = sessionFunctionFailure(429, {
      'code': 'daily_limit_reached',
      'dailyLimit': 3,
    });
    expect(arLimit.message, contains('3 محاولات'));

    AppLang.isEn = true;
    final enLimit = sessionFunctionFailure(429, {
      'code': 'daily_limit_reached',
      'dailyLimit': 3,
    });
    expect(enLimit.message, contains('3 daily try-on attempts'));

    final enDisabled = sessionFunctionFailure(503, {'code': 'tryon_disabled'});
    expect(enDisabled.message, contains('temporarily paused'));
  });

  test(
    'TryonQuota detects daily limit, depleted tokens, and admin disable in AR & EN',
    () {
      addTearDown(() => AppLang.isEn = false);

      final dailyOut = TryonQuota.fromMap({
        'enabled': true,
        'tokens_available': true,
        'daily_limit': 3,
        'used_today': 3,
        'remaining_today': 0,
        'block_reason': 'daily_limit_reached',
      });
      expect(dailyOut.isBlocked, isTrue);
      expect(dailyOut.hasRemaining, isFalse);
      expect(dailyOut.blockReason, TryonBlockReason.dailyLimitReached);
      expect(dailyOut.friendlyBlockedMessage, contains('3 محاولات'));
      expect(dailyOut.blockedBadgeLabel, 'انتهت المحاولات');

      final tokensOut = TryonQuota.fromMap({
        'enabled': true,
        'tokens_available': false,
        'daily_limit': 3,
        'used_today': 0,
        'remaining_today': 3,
        'block_reason': 'tokens_depleted',
      });
      expect(tokensOut.isBlocked, isTrue);
      expect(tokensOut.hasRemaining, isFalse);
      expect(tokensOut.blockReason, TryonBlockReason.tokensDepleted);
      expect(tokensOut.friendlyBlockedMessage, contains('رصيد التجربة'));
      expect(tokensOut.blockedBadgeLabel, 'متوقف مؤقتاً');

      final disabled = TryonQuota.fromMap({
        'enabled': false,
        'tokens_available': true,
        'daily_limit': 3,
        'used_today': 0,
        'remaining_today': 3,
      });
      expect(disabled.isBlocked, isTrue);
      expect(disabled.blockReason, TryonBlockReason.disabledByAdmin);
      expect(disabled.friendlyBlockedMessage, contains('من قبل الإدارة'));

      AppLang.isEn = true;
      expect(
        dailyOut.friendlyBlockedMessage!.tr,
        contains('all 3 try-on attempts'),
      );
      expect(
        tokensOut.friendlyBlockedMessage!.tr,
        contains('credits have run out'),
      );
      expect(
        disabled.friendlyBlockedMessage!.tr,
        contains('temporarily paused by the administration'),
      );
    },
  );

  testWidgets('TryonCostControlsCard validates and saves admin cost settings', (
    tester,
  ) async {
    final repo = _FakeAdminRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          adminTryonControlsProvider.overrideWith(
            (_) async => const TryonCostControls(
              enabled: true,
              sessionDurationSeconds: 30,
              dailyAttemptsLimit: 3,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: TryonCostControlsCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), '45');
    await tester.enterText(fields.at(1), '5');
    await tester.tap(find.text('حفظ إعدادات التكلفة'));
    await tester.pumpAndSettle();

    expect(repo.savedEnabled, isTrue);
    expect(repo.savedDuration, 45);
    expect(repo.savedLimit, 5);
    expect(
      find.text('تم حفظ إعدادات التحكم في تكلفة التجربة بنجاح.'),
      findsOneWidget,
    );
  });
}
