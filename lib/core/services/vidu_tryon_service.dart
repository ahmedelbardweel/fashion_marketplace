import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../network/network_guard.dart';
import '../network/tryon_bandwidth_guard.dart';
import '../utils/app_image_compressor.dart';
import '../utils/map_utils.dart';
import '../../features/virtual_tryon/domain/tryon_quota.dart';
import '../../features/virtual_tryon/domain/tryon_session.dart';

class ViduTryonException implements Exception {
  const ViduTryonException(
    this.message, {
    this.code,
    this.dailyLimit,
    this.refunded = false,
  });

  final String message;
  final String? code;
  final int? dailyLimit;
  final bool refunded;

  @override
  String toString() => message;
}

class ViduTryonResult {
  const ViduTryonResult({
    required this.taskId,
    required this.imageUrl,
    this.dailyLimit,
    this.usedToday,
    this.remainingToday,
  });

  final String taskId;
  final String imageUrl;
  final int? dailyLimit;
  final int? usedToday;
  final int? remainingToday;
}

class ViduTryonService {
  ViduTryonService({SupabaseClient? client})
    : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  Future<ViduTryonResult> generateTryonImage({
    required Uint8List personPhotoBytes,
    required String personPhotoName,
    required String garmentImageUrl,
    String? garmentName,
    String? garmentCategory,
    TryonBodyZone bodyZone = TryonBodyZone.upperBody,
    TryonBandwidthMode bandwidthMode = TryonBandwidthMode.dataSaver,
    void Function(String stageMessage)? onStageChanged,
    bool Function()? isCancelled,
  }) async {
    await NetworkGuard.ensureOnline();

    final isDataSaver = bandwidthMode == TryonBandwidthMode.dataSaver;
    onStageChanged?.call(
      isDataSaver
          ? 'جارٍ ضغط الصورة لوضع توفير الإنترنت...'
          : 'جارٍ تجهيز الصورة بدقة عالية...',
    );
    final compressed = await AppImageCompressor.compressForUpload(
      bytes: personPhotoBytes,
      fileName: personPhotoName,
      preset: isDataSaver
          ? ImageCompressPreset.tryonGarment
          : ImageCompressPreset.receipt,
    );
    if (isCancelled?.call() == true) {
      throw const ViduTryonException('تم إلغاء العملية.', code: 'cancelled');
    }

    final mime = compressed.contentType.startsWith('image/')
        ? compressed.contentType
        : 'image/jpeg';
    final personDataUri = 'data:$mime;base64,${base64Encode(compressed.bytes)}';

    onStageChanged?.call('جارٍ إرسال الطلب إلى Vidu AI...');

    late final Map<String, dynamic> created;
    try {
      final response = await NetworkGuard.run(
        () => _client.functions.invoke(
          'vidu-tryon',
          body: {
            'action': 'create',
            'personImage': personDataUri,
            'garmentImage': garmentImageUrl.trim(),
            if (garmentName != null && garmentName.trim().isNotEmpty)
              'garmentName': garmentName.trim(),
            if (garmentCategory != null && garmentCategory.trim().isNotEmpty)
              'garmentCategory': garmentCategory.trim(),
            'bodyZone': bodyZone.name,
            'aspectRatio': 'auto',
            'resolution': isDataSaver ? '1080p' : '2K',
          },
        ),
        timeout: Duration(milliseconds: bandwidthMode.connectTimeoutMs),
      );
      created = asStringMap(response.data);
    } on AppNetworkException catch (error) {
      throw ViduTryonException(error.userMessage, code: 'network');
    } on FunctionException catch (error) {
      throw _mapFunctionError(error);
    }

    final taskId = created['taskId']?.toString().trim() ?? '';
    if (taskId.isEmpty) {
      throw const ViduTryonException(
        'لم يسترجع السيرفر معرّف مهمة صالحاً. حاول مجدداً.',
        code: 'invalid_response',
      );
    }

    final dailyLimit = (created['dailyLimit'] as num?)?.toInt();
    final usedToday = (created['usedToday'] as num?)?.toInt();
    final remainingToday = (created['remainingToday'] as num?)?.toInt();

    onStageChanged?.call('جارٍ تصميم إطلالتك بدقة عالية...');

    const maxAttempts = 40; // ~80 seconds max
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (isCancelled?.call() == true) {
        throw const ViduTryonException('تم إلغاء العملية.', code: 'cancelled');
      }
      await Future<void>.delayed(
        Duration(milliseconds: attempt < 3 ? 1800 : 2200),
      );
      if (isCancelled?.call() == true) {
        throw const ViduTryonException('تم إلغاء العملية.', code: 'cancelled');
      }

      late final Map<String, dynamic> polled;
      try {
        final pollRes = await NetworkGuard.run(
          () => _client.functions.invoke(
            'vidu-tryon',
            body: {'action': 'status', 'taskId': taskId},
          ),
          timeout: const Duration(seconds: 20),
        );
        polled = asStringMap(pollRes.data);
      } on AppNetworkException {
        if (attempt >= maxAttempts - 1) {
          throw const ViduTryonException(
            'انقطع الاتصال أثناء متابعة النتيجة. حاول مجدداً.',
            code: 'network',
          );
        }
        continue;
      } on FunctionException catch (error) {
        if (error.status == 404) {
          throw _mapFunctionError(error);
        }
        if (attempt >= maxAttempts - 1) {
          throw _mapFunctionError(error);
        }
        continue;
      }

      final state = polled['state']?.toString().toLowerCase() ?? 'processing';
      if (state == 'queueing' || state == 'created') {
        onStageChanged?.call('الطلب في قائمة المعالجة...');
        continue;
      }
      if (state == 'processing') {
        onStageChanged?.call('جارٍ تلبيس القطعة وضبط الإضاءة والتفاصيل...');
        continue;
      }
      if (state == 'success') {
        final imageUrl = polled['imageUrl']?.toString().trim() ?? '';
        if (imageUrl.isEmpty) {
          throw const ViduTryonException(
            'اكتملت المعالجة لكن لم تصل صورة النتيجة. حاول مجدداً.',
            code: 'empty_result',
          );
        }
        return ViduTryonResult(
          taskId: taskId,
          imageUrl: imageUrl,
          dailyLimit: dailyLimit,
          usedToday: usedToday,
          remainingToday: remainingToday,
        );
      }
      if (state == 'failed') {
        final errCode = polled['errCode']?.toString();
        final refunded = polled['refunded'] == true;
        throw ViduTryonException(
          _friendlyViduFailure(errCode, refunded: refunded),
          code: errCode ?? 'generation_failed',
          refunded: refunded,
        );
      }
    }

    throw const ViduTryonException(
      'استغرقت المعالجة وقتاً أطول من المعتاد. يرجى المحاولة مجدداً بعد قليل.',
      code: 'timeout',
    );
  }

  ViduTryonException _mapFunctionError(FunctionException error) {
    final details = error.details;
    String? code;
    int? dailyLimit;
    if (details is Map) {
      code = details['code']?.toString();
      dailyLimit = (details['dailyLimit'] as num?)?.toInt();
    }

    if (error.status == 404 && code == null) {
      return const ViduTryonException(
        'خدمة Vidu غير منشورة بعد على السيرفر (vidu-tryon).',
        code: 'function_missing',
      );
    }
    if (code == 'provider_not_active') {
      return const ViduTryonException(
        'قامت الإدارة بتبديل محرك التجربة الافتراضية. أعد فتح الصفحة للتحديث.',
        code: 'provider_not_active',
      );
    }
    if (code == 'tryon_disabled') {
      return const ViduTryonException(
        'ميزة تجربة الملابس الافتراضية متوقفة مؤقتاً من قبل الإدارة.',
        code: 'tryon_disabled',
      );
    }
    if (code == 'daily_limit_reached') {
      return ViduTryonException(
        'استهلكت جميع محاولاتك اليومية لتجربة الملابس. ستعود محاولاتك تلقائياً غداً.',
        code: 'daily_limit_reached',
        dailyLimit: dailyLimit,
      );
    }
    if (code == 'all_keys_depleted' || error.status == 503) {
      return const ViduTryonException(
        'خدمة التجربة الافتراضية متوقفة مؤقتاً لنفاد الرصيد في التطبيق.',
        code: 'all_keys_depleted',
      );
    }
    if (error.status == 401) {
      return const ViduTryonException(
        'يرجى تسجيل الدخول مجدداً لاستخدام ميزة التجربة الافتراضية.',
        code: 'unauthorized',
      );
    }
    return const ViduTryonException(
      'تعذر إتمام تجربة الملابس حالياً. يرجى المحاولة مجدداً.',
      code: 'upstream_failed',
    );
  }

  String _friendlyViduFailure(String? errCode, {required bool refunded}) {
    final refundHint = refunded ? ' (تم إرجاع محاولتك اليومية تلقائياً)' : '';
    final lower = (errCode ?? '').toLowerCase();
    if (lower.contains('audit') ||
        lower.contains('moderation') ||
        lower.contains('policy') ||
        lower.contains('safety')) {
      return 'لم تُقبل الصورة من نظام الفحص التلقائي. جرّب صورة أخرى بملابس واضحة وإضاءة جيدة.$refundHint';
    }
    return 'تعذر توليد صورة التجربة لهذه الصورة. جرّب صورة أوضح بوقفة أمامية.$refundHint';
  }
}

TryonBlockReason? blockReasonFromViduCode(String? code) {
  return switch (code) {
    'tryon_disabled' => TryonBlockReason.disabledByAdmin,
    'all_keys_depleted' => TryonBlockReason.tokensDepleted,
    'daily_limit_reached' => TryonBlockReason.dailyLimitReached,
    _ => null,
  };
}
