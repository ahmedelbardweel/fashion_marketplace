import 'dart:async';

import 'package:fashion_marketplace/features/admin/data/admin_repository.dart';
import 'package:fashion_marketplace/features/admin/domain/models/decart_settings_status.dart';
import 'package:fashion_marketplace/features/admin/presentation/providers/admin_providers.dart';
import 'package:fashion_marketplace/features/admin/presentation/widgets/decart_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repository extends Fake implements AdminRepository {
  int writes = 0;
  String? submittedKey;
  Object? failure;
  Completer<void>? pending;

  @override
  Future<void> setDecartApiKey(String apiKey) async {
    writes++;
    submittedKey = apiKey;
    if (failure != null) throw failure!;
    await pending?.future;
  }
}

Future<void> _mount(WidgetTester tester, _Repository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(repo),
        adminDecartStatusProvider.overrideWith(
          (_) async => const DecartSettingsStatus(configured: true),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DecartSettingsCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final prefix in ['dct_app_', 'dct_new-app_']) {
    testWidgets('$prefix keys can be saved and are cleared afterwards', (
      tester,
    ) async {
      final repo = _Repository();
      await _mount(tester, repo);
      final key = '${prefix}12345678901234567890';
      await tester.enterText(find.byType(TextFormField), key);
      await tester.tap(find.text('حفظ المفتاح'));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.submittedKey, key);
      expect(find.textContaining('تم حفظ المفتاح.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  }

  for (final key in [
    'dct_app_short',
    'dct_new-app_short',
    'dct_unknown_12345678901234567890',
    'dct_new-app_1234567890 1234567890',
    'dct_new-app_${'a' * 513}',
  ]) {
    testWidgets(
      'malformed key is rejected: ${key.split('_').take(2).join('_')} (${key.length})',
      (tester) async {
        final repo = _Repository();
        await _mount(tester, repo);
        await tester.enterText(find.byType(TextFormField), key);
        await tester.tap(find.text('حفظ المفتاح'));
        await tester.pumpAndSettle();
        expect(repo.writes, 0);
        expect(find.textContaining('أدخل مفتاح Decart صالحاً'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'secret is hidden, duplicate saves blocked, cleared after success',
    (tester) async {
      final repo = _Repository()..pending = Completer<void>();
      await _mount(tester, repo);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'dct_app_12345678901234567890',
      );
      await tester.tap(find.text('حفظ المفتاح'));
      await tester.pump();
      expect(repo.writes, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.textContaining('تم حفظ المفتاح.'), findsOneWidget);
    },
  );

  testWidgets('invalid key is not submitted', (tester) async {
    final repo = _Repository();
    await _mount(tester, repo);
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.tap(find.text('حفظ المفتاح'));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
    expect(find.textContaining('أدخل مفتاح Decart صالحاً'), findsOneWidget);
  });

  testWidgets('failed saves do not display server details or claim success', (
    tester,
  ) async {
    final repo = _Repository()
      ..failure = const PostgrestException(
        message: 'private-server-details',
        code: '42501',
      );
    await _mount(tester, repo);
    await tester.enterText(
      find.byType(TextFormField),
      'dct_app_12345678901234567890',
    );
    await tester.tap(find.text('حفظ المفتاح'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private-server-details'), findsNothing);
    expect(find.textContaining('تم حفظ المفتاح.'), findsNothing);
    expect(
      find.textContaining('هذا الإعداد متاح للأدمن النشط فقط.'),
      findsOneWidget,
    );
    expect(find.textContaining('42501'), findsOneWidget);
  });

  for (final entry in <String, String>{
    '22023': 'تحديث قاعدة البيانات 011',
    '2201B': 'خطأ في قاعدة التحقق من المفتاح على السيرفر',
    'PGRST202': 'خدمة حفظ المفتاح غير مكتملة',
    '42883': 'خدمة حفظ المفتاح غير مكتملة',
    '42P01': 'خدمة حفظ المفتاح غير مكتملة',
    'PGRST301': 'جلسة تسجيل الدخول غير صالحة',
    'PGRST303': 'جلسة تسجيل الدخول غير صالحة',
    'XX000': 'رفض السيرفر حفظ المفتاح',
  }.entries) {
    testWidgets('save failure ${entry.key} has a safe actionable message', (
      tester,
    ) async {
      final repo = _Repository()
        ..failure = PostgrestException(
          message: 'private-server-details',
          details: 'private-request-body',
          hint: 'private-server-hint',
          code: entry.key,
        );
      await _mount(tester, repo);
      await tester.enterText(
        find.byType(TextFormField),
        'dct_new-app_12345678901234567890',
      );
      await tester.tap(find.text('حفظ المفتاح'));
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.textContaining('رمز الخطأ: ${entry.key}'), findsOneWidget);
      expect(find.textContaining('private-'), findsNothing);
      expect(find.textContaining('تم حفظ المفتاح.'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });
  }

  for (final entry in <Object, String>{
    const PostgrestException(message: 'private-message', code: 'private-code'):
        'رفض السيرفر حفظ المفتاح',
    const AuthException('private-auth'): 'تعذر التحقق من جلسة الدخول',
    TimeoutException('private-timeout'): 'انتهت مهلة الحفظ',
    http.ClientException('private-url'): 'تعذر الاتصال بالسيرفر',
    StateError('private-state'): 'خطأ غير متوقع في التطبيق',
  }.entries) {
    testWidgets('${entry.key.runtimeType} does not expose error details', (
      tester,
    ) async {
      final repo = _Repository()..failure = entry.key;
      await _mount(tester, repo);
      await tester.enterText(
        find.byType(TextFormField),
        'dct_new-app_12345678901234567890',
      );
      await tester.tap(find.text('حفظ المفتاح'));
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.textContaining('private-'), findsNothing);
      expect(find.textContaining('تم حفظ المفتاح.'), findsNothing);
    });
  }
}
