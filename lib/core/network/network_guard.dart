import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_translations.dart';
import '../offline/network_monitor_service.dart';

/// Optimal network timeouts tuned for mobile/variable connections across all roles.
abstract final class AppTimeouts {
  /// Fast reachability HEAD probe to Supabase gateway.
  static const Duration connectivityProbe = Duration(seconds: 4);

  /// Standard data reads (lists, product details, orders, stats, profiles).
  static const Duration read = Duration(seconds: 12);

  /// Mutations & RPC actions (checkout, approve/reject, save product, settlements).
  static const Duration action = Duration(seconds: 15);

  /// Authentication flows (sign-in, register, OAuth token exchange).
  static const Duration auth = Duration(seconds: 18);

  /// Edge Functions (Decart session/credits, push notifications).
  static const Duration edgeFunction = Duration(seconds: 20);

  /// Media/file uploads to Supabase Storage (images, logos, banners, receipts, docs).
  static const Duration upload = Duration(seconds: 35);

  /// Local image background removal processing guard.
  static const Duration backgroundCutout = Duration(seconds: 12);

  /// Interactive Google Sign-In picker timeout.
  static const Duration googleSignIn = Duration(seconds: 45);

  /// Sign-out cleanup timeout (never block user from signing out offline).
  static const Duration signOut = Duration(seconds: 5);
}

enum AppNetworkFailureKind {
  noInternet,
  unreachable,
  timeout,
  connectionDropped,
  serverUnavailable,
}

/// Typed, user-friendly network exception thrown across all roles and actions.
class AppNetworkException implements Exception {
  const AppNetworkException({
    required this.kind,
    this.timeout,
    this.statusCode,
  });

  factory AppNetworkException.noInternet() =>
      const AppNetworkException(kind: AppNetworkFailureKind.noInternet);

  factory AppNetworkException.unreachable() =>
      const AppNetworkException(kind: AppNetworkFailureKind.unreachable);

  factory AppNetworkException.timeout({Duration? timeout}) =>
      AppNetworkException(
        kind: AppNetworkFailureKind.timeout,
        timeout: timeout,
      );

  factory AppNetworkException.connectionDropped() =>
      const AppNetworkException(kind: AppNetworkFailureKind.connectionDropped);

  factory AppNetworkException.serverUnavailable({int? statusCode}) =>
      AppNetworkException(
        kind: AppNetworkFailureKind.serverUnavailable,
        statusCode: statusCode,
      );

  final AppNetworkFailureKind kind;
  final Duration? timeout;
  final int? statusCode;

  String get userMessage {
    switch (kind) {
      case AppNetworkFailureKind.noInternet:
        return 'لا يوجد اتصال بالإنترنت. تأكد من تشغيل الواي فاي أو بيانات الهاتف ثم حاول مرة أخرى.'
            .tr;
      case AppNetworkFailureKind.unreachable:
        return 'الجهاز متصل بالشبكة لكن لا يوجد إنترنت فعلي أو تعذر الوصول للخادم. تحقق من اتصالك وحاول مجدداً.'
            .tr;
      case AppNetworkFailureKind.timeout:
        if (timeout != null) {
          return AppLang.isEn
              ? 'Connection timed out after ${timeout!.inSeconds}s due to slow internet or server delay. Please try again.'
              : 'انتهت مهلة الاتصال (${timeout!.inSeconds} ثانية) بسبب بطء الإنترنت أو عدم استجابة الخادم. حاول مرة أخرى.';
        }
        return 'انتهت مهلة الاتصال بسبب بطء الإنترنت أو عدم استجابة الخادم. حاول مرة أخرى.'
            .tr;
      case AppNetworkFailureKind.connectionDropped:
        return 'انقطع الاتصال بالإنترنت أثناء تنفيذ العملية. تأكد من استقرار الشبكة وأعد المحاولة.'
            .tr;
      case AppNetworkFailureKind.serverUnavailable:
        return 'الخادم غير متاح مؤقتاً حالياً. يرجى المحاولة مرة أخرى بعد قليل.'
            .tr;
    }
  }

  @override
  String toString() => userMessage;
}

/// Global HTTP client injected into Supabase so EVERY query, RPC, Auth call,
/// Storage upload, and Edge Function across all roles automatically enforces:
/// 1) Instant OS network-interface check (fail fast when Wi-Fi & mobile data are OFF),
/// 2) Optimal operation-aware timeout (read 12s / action 15s / auth 18s / functions 20s / upload 35s),
/// 3) Real-time NetworkMonitor sync and clear typed [AppNetworkException] classification.
class AppHttpClient extends http.BaseClient {
  AppHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  Duration _timeoutForRequest(http.BaseRequest request) {
    final path = request.url.path.toLowerCase();
    final method = request.method.toUpperCase();
    if (path.contains('/storage/v1/')) {
      return AppTimeouts.upload;
    }
    if (path.contains('/functions/v1/')) {
      return AppTimeouts.edgeFunction;
    }
    if (path.contains('/auth/v1/')) {
      return AppTimeouts.auth;
    }
    if (path.contains('/rest/v1/rpc/') ||
        (method != 'GET' && method != 'HEAD')) {
      return AppTimeouts.action;
    }
    return AppTimeouts.read;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final hasInterface =
        await NetworkMonitorService.instance.hasNetworkInterface();
    if (!hasInterface) {
      NetworkMonitorService.instance.reportNetworkFailure();
      throw AppNetworkException.noInternet();
    }

    final timeout = _timeoutForRequest(request);
    try {
      final response = await _inner.send(request).timeout(timeout);
      NetworkMonitorService.instance.reportNetworkSuccess();

      // Also guard response body streaming so a dropped connection mid-body
      // can never hang indefinitely.
      final guardedStream = http.ByteStream(
        response.stream.timeout(
          timeout,
          onTimeout: (sink) {
            NetworkMonitorService.instance.reportNetworkFailure();
            sink.addError(AppNetworkException.timeout(timeout: timeout));
            sink.close();
          },
        ),
      );

      return http.StreamedResponse(
        guardedStream,
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on TimeoutException {
      NetworkMonitorService.instance.reportNetworkFailure();
      throw AppNetworkException.timeout(timeout: timeout);
    } catch (error) {
      if (error is AppNetworkException) rethrow;
      NetworkMonitorService.instance.reportNetworkFailure();
      final stillHasInterface =
          await NetworkMonitorService.instance.hasNetworkInterface();
      if (!stillHasInterface) {
        throw AppNetworkException.noInternet();
      }
      final lower = '${error.runtimeType} $error'.toLowerCase();
      if (lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('no address associated')) {
        throw AppNetworkException.unreachable();
      }
      if (error is http.ClientException ||
          lower.contains('handshakeexception') ||
          lower.contains('connection')) {
        throw AppNetworkException.connectionDropped();
      }
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Helper to guard explicit online-only actions (Auth, Uploads, Account Deletion,
/// Try-On Session, etc.) with active connectivity verification + strict timeout.
class NetworkGuard {
  NetworkGuard._();

  /// Checks both OS interface and live Supabase reachability; throws a descriptive
  /// [AppNetworkException] immediately if offline or unreachable.
  static Future<void> ensureOnline({bool forceProbe = false}) async {
    await NetworkMonitorService.instance.ensureConnected(
      forceProbe: forceProbe,
    );
  }

  /// Runs [action] with optional pre-flight connectivity verification and a hard [timeout].
  static Future<T> run<T>(
    Future<T> Function() action, {
    Duration timeout = AppTimeouts.action,
    bool requireConnection = true,
    bool forceProbe = false,
  }) async {
    if (requireConnection) {
      await ensureOnline(forceProbe: forceProbe);
    }
    try {
      final result = await action().timeout(timeout);
      NetworkMonitorService.instance.reportNetworkSuccess();
      return result;
    } on AppNetworkException {
      rethrow;
    } on TimeoutException {
      NetworkMonitorService.instance.reportNetworkFailure();
      throw AppNetworkException.timeout(timeout: timeout);
    } catch (error) {
      if (AppErrorMapper.isNetworkError(error)) {
        NetworkMonitorService.instance.reportNetworkFailure();
        final hasInterface =
            await NetworkMonitorService.instance.hasNetworkInterface();
        if (!hasInterface) {
          throw AppNetworkException.noInternet();
        }
        final lower = '${error.runtimeType} $error'.toLowerCase();
        if (lower.contains('socketexception') ||
            lower.contains('failed host lookup')) {
          throw AppNetworkException.unreachable();
        }
        throw AppNetworkException.connectionDropped();
      }
      rethrow;
    }
  }
}

/// Centralized, human-friendly error mapper for ALL roles (Auth, Customer, Shop, Admin).
class AppErrorMapper {
  AppErrorMapper._();

  static final RegExp _arabicChars = RegExp(r'[\u0600-\u06FF]');

  /// Returns true when [error] represents a network outage, timeout, or transport failure
  /// (used by offline-first repositories to fall back gracefully to local SQLite).
  static bool isNetworkError(Object error) {
    if (error is AppNetworkException ||
        error is TimeoutException ||
        error is http.ClientException ||
        error is AuthRetryableFetchException) {
      return true;
    }
    final msg = '${error.runtimeType} $error'.toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('handshakeexception') ||
        msg.contains('connection closed') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection aborted') ||
        msg.contains('network is unreachable') ||
        msg.contains('software caused connection abort') ||
        msg.contains('timed out') ||
        msg.contains('timeoutexception') ||
        msg.contains('xmlhttprequest error') ||
        msg.contains('no address associated with hostname') ||
        msg.contains('لا يوجد اتصال بالإنترنت') ||
        msg.contains('انتهت مهلة الاتصال');
  }

  /// Translates ANY exception into a clear, actionable message explaining WHY it failed.
  static String message(
    Object error, {
    String fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.',
  }) {
    // 1) Typed network failures (no internet / unreachable / timeout / dropped)
    if (error is AppNetworkException) {
      return error.userMessage;
    }
    if (error is TimeoutException) {
      return AppNetworkException.timeout().userMessage;
    }
    final typeName = error.runtimeType.toString().toLowerCase();
    if (typeName.contains('socketexception')) {
      return NetworkMonitorService.instance.isOnline
          ? AppNetworkException.unreachable().userMessage
          : AppNetworkException.noInternet().userMessage;
    }
    if (typeName.contains('handshakeexception') || error is http.ClientException) {
      return NetworkMonitorService.instance.isOnline
          ? AppNetworkException.connectionDropped().userMessage
          : AppNetworkException.noInternet().userMessage;
    }

    // 2) Supabase Auth errors (including network errors wrapped in AuthRetryableFetchException)
    if (error is AuthRetryableFetchException) {
      return NetworkMonitorService.instance.isOnline
          ? AppNetworkException.connectionDropped().userMessage
          : AppNetworkException.noInternet().userMessage;
    }
    if (error is AuthException) {
      final raw = error.message;
      final lower = raw.toLowerCase();
      if (_containsNetworkSignature(lower)) {
        return _networkMessageFromText(lower);
      }
      if (lower.contains('passed nonce and nonce in id_token')) {
        return 'يرجى تفعيل خيار Skip nonce checks داخل إعدادات Google في Supabase'
            .tr;
      }
      if (lower.contains('invalid login credentials')) {
        return 'البريد أو كلمة المرور غير صحيحة'.tr;
      }
      if (lower.contains('email not confirmed')) {
        return 'يجب تأكيد البريد الإلكتروني أولاً'.tr;
      }
      if (lower.contains('token has expired') ||
          lower.contains('otp_expired') ||
          lower.contains('invalid otp') ||
          lower.contains('invalid token')) {
        return 'رمز التحقق غير صحيح أو منتهي الصلاحية. تأكد من الرمز أو اطلب رمزاً جديداً.'
            .tr;
      }
      if (lower.contains('over_email_send_rate_limit') ||
          lower.contains('security purposes') ||
          lower.contains('once every')) {
        return 'يرجى الانتظار 60 ثانية قبل طلب رمز تحقق جديد.'.tr;
      }
      if (lower.contains('user already registered') ||
          lower.contains('already been registered')) {
        return 'هذا البريد مسجل مسبقاً'.tr;
      }
      if (lower.contains('password')) {
        return 'كلمة المرور غير مقبولة (يجب أن تكون 6 أحرف على الأقل)'.tr;
      }
      if (lower.contains('rate limit') ||
          lower.contains('too many requests') ||
          error.statusCode == '429') {
        return 'محاولات كثيرة متتالية. انتظر قليلاً ثم أعد المحاولة.'.tr;
      }
      if (lower.contains('jwt') ||
          lower.contains('token') && lower.contains('expired') ||
          lower.contains('refresh_token_not_found')) {
        return 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مجدداً.'.tr;
      }
      if (_arabicChars.hasMatch(raw)) {
        return raw.tr;
      }
      return 'تعذر إتمام المصادقة. تحقق من بياناتك واتصالك بالإنترنت.'.tr;
    }

    // 3) Supabase PostgreSQL / RPC errors
    if (error is PostgrestException) {
      final raw = error.message.trim();
      final lower = raw.toLowerCase();
      if (_containsNetworkSignature(lower)) {
        return _networkMessageFromText(lower);
      }
      // Preserve explicit Arabic domain/business rule messages returned by our RPCs
      if (_arabicChars.hasMatch(raw)) {
        return raw.tr;
      }
      switch (error.code) {
        case '42501':
          return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.'.tr;
        case '23505':
          if (lower.contains('phone') || raw.contains('الهاتف')) {
            return 'رقم الهاتف مسجل مسبقاً لحساب آخر'.tr;
          }
          return 'هذه البيانات مسجلة مسبقاً ولا يمكن تكرارها.'.tr;
        case '23503':
          return 'لا يمكن تنفيذ العملية لارتباط هذا العنصر ببيانات أخرى.'.tr;
        case '22P02':
        case '22023':
          return 'صيغة البيانات المدخلة غير صحيحة. راجع الحقول وحاول مجدداً.'.tr;
        case '57014':
          return 'استغرق الخادم وقتاً أطول من المعتاد. حاول مرة أخرى.'.tr;
        case 'PGRST301':
        case 'PGRST303':
          return 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مجدداً.'.tr;
        case 'PGRST202':
        case '42883':
        case '42P01':
          return 'هذه الخدمة غير مهيأة بالكامل على الخادم بعد.'.tr;
      }
      if (lower.contains('jwt') || lower.contains('expired')) {
        return 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مجدداً.'.tr;
      }
      if (lower.contains('permission denied') || lower.contains('rls')) {
        return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.'.tr;
      }
      return fallback.tr;
    }

    // 4) Supabase Storage upload/download errors
    if (error is StorageException) {
      final raw = error.message.trim();
      final lower = raw.toLowerCase();
      if (_containsNetworkSignature(lower)) {
        return _networkMessageFromText(lower);
      }
      if (error.statusCode == '413' ||
          lower.contains('payload too large') ||
          lower.contains('exceeded the maximum')) {
        return 'حجم الملف كبير جداً. اختر صورة أو ملفاً أصغر وحاول مجدداً.'.tr;
      }
      if (error.statusCode == '415' || lower.contains('mime type')) {
        return 'صيغة الملف غير مدعومة. يرجى اختيار صورة بصيغة JPG أو PNG.'.tr;
      }
      if (error.statusCode == '401' || error.statusCode == '403') {
        return 'انتهت الجلسة أو ليس لديك صلاحية لرفع الملفات.'.tr;
      }
      if (_arabicChars.hasMatch(raw)) {
        return raw.tr;
      }
      return 'تعذر رفع الملف إلى الخادم. تحقق من الإنترنت وحجم الملف وحاول مجدداً.'
          .tr;
    }

    // 5) Supabase Edge Function errors
    if (error is FunctionException) {
      final status = error.status;
      if (status == 401 || status == 403) {
        return 'انتهت جلسة الدخول أو غير مصرح بتنفيذ هذا الإجراء.'.tr;
      }
      if (status == 404) {
        return 'الخدمة المطلوبة غير متوفرة حالياً على الخادم.'.tr;
      }
      if (status == 429) {
        return 'طلبات كثيرة متتالية. انتظر قليلاً ثم أعد المحاولة.'.tr;
      }
      if (status >= 500) {
        return AppNetworkException.serverUnavailable(
          statusCode: status,
        ).userMessage;
      }
      return fallback.tr;
    }

    // 6) Platform exceptions (e.g. Google Sign-In, native channels)
    if (error is PlatformException) {
      final combined = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (combined.contains('network_error') ||
          combined.contains('network') ||
          combined.contains('7:')) {
        return AppNetworkException.noInternet().userMessage;
      }
      if (error.message != null && _arabicChars.hasMatch(error.message!)) {
        return error.message!.tr;
      }
    }

    // 7) Domain StateError / generic exceptions
    if (error is StateError && _arabicChars.hasMatch(error.message)) {
      return error.message.tr;
    }

    final rawText = error.toString();
    final lowerText = rawText.toLowerCase();
    if (_containsNetworkSignature(lowerText)) {
      return _networkMessageFromText(lowerText);
    }
    if (lowerText.contains('502') ||
        lowerText.contains('503') ||
        lowerText.contains('504')) {
      return AppNetworkException.serverUnavailable().userMessage;
    }

    return fallback.tr;
  }

  static bool _containsNetworkSignature(String lower) {
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('connection closed') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('no address associated with hostname');
  }

  static String _networkMessageFromText(String lower) {
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return AppNetworkException.timeout().userMessage;
    }
    if (!NetworkMonitorService.instance.isOnline) {
      return AppNetworkException.noInternet().userMessage;
    }
    return AppNetworkException.connectionDropped().userMessage;
  }
}
