import 'dart:async';

import 'package:camera/camera.dart';
import 'package:decart_vton_flutter/decart_vton_flutter.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_translations.dart';
import '../domain/tryon_session.dart';

enum TryonStartupStage { camera, session, peer, signaling, garment }

/// Map known errors to useful messages without exposing tokens or signed URLs.
TryonFailure cameraFailure(Object error) {
  if (error is TryonFailure) return error;
  final code = error is CameraException
      ? error.code
      : error is PlatformException
      ? '${error.code} ${error.message ?? ''}'
      : error.toString();
  final text = code.toLowerCase();
  if (text.contains('notallowederror') ||
      text.contains('permissiondenied') ||
      text.contains('cameraaccessdenied') ||
      text.contains('permission denied')) {
    return TryonFailure(
      'إذن الكاميرا مرفوض. اسمح لهذا الموقع باستخدام الكاميرا من إعدادات المتصفح ثم أعد المحاولة.'.tr,
    );
  }
  if (text.contains('notfounderror') ||
      text.contains('cameranotfound') ||
      text.contains('devicesnotfound')) {
    return TryonFailure(
      'لم يعثر المتصفح على كاميرا. صِل كاميرا بالكمبيوتر ثم أعد المحاولة.'.tr,
    );
  }
  if (text.contains('notreadableerror') ||
      text.contains('cameranotreadable') ||
      text.contains('trackstarterror') ||
      text.contains('could not start video')) {
    return TryonFailure(
      'تعذر تشغيل الكاميرا. قد تكون مستخدمة في تطبيق أو تبويب آخر؛ أغلقه وأعد المحاولة.'.tr,
    );
  }
  if (text.contains('overconstrained') ||
      text.contains('constraintnotsatisfied')) {
    return TryonFailure(
      'الكاميرا لا تدعم إعدادات الفيديو المطلوبة. جرّب كاميرا أخرى.'.tr,
    );
  }
  if (text.contains('securityerror') ||
      text.contains('camerasecurity') ||
      text.contains('cameranotsupported') ||
      text.contains('insecure context')) {
    return TryonFailure(
      'الوصول إلى الكاميرا غير متاح. افتح التطبيق عبر HTTPS أو localhost في متصفح يدعم الكاميرا.'.tr,
    );
  }
  if (error is TimeoutException) {
    return TryonFailure(
      'انتهت مهلة تشغيل الكاميرا. تحقق من طلب الإذن ثم أعد المحاولة.'.tr,
    );
  }
  if (error is MissingPluginException) {
    return TryonFailure(
      'إضافة الكاميرا غير مهيأة. أعد تشغيل التطبيق بالكامل بعد تحديث الحزم.'.tr,
    );
  }
  return TryonFailure(
    'فشل فتح الكاميرا. تحقق من توصيلها ومن إذن استخدامها في المتصفح أو إعدادات الجهاز.'.tr,
  );
}

TryonFailure startupFailure(Object error, TryonStartupStage stage) {
  if (error is TryonFailure) return error;
  if (stage == TryonStartupStage.camera) return cameraFailure(error);
  return TryonFailure(
    (switch (stage) {
      TryonStartupStage.camera => 'تعذر فتح الكاميرا.',
      TryonStartupStage.session =>
        'تعذر تجهيز جلسة التجربة من الخادم. تحقق من الشبكة وتسجيل الدخول.',
      TryonStartupStage.peer =>
        'تعذر تهيئة اتصال الفيديو. جرّب متصفحاً حديثاً يدعم WebRTC.',
      TryonStartupStage.signaling =>
        'تعذر فتح قناة الاتصال بخادم التجربة. تحقق من الشبكة ثم أعد المحاولة.',
      TryonStartupStage.garment =>
        'تعذر تحميل صورة القطعة. تحقق من رابط الصورة والسماح بتحميلها من المتصفح (CORS).',
    }).tr,
  );
}

TryonFailure sessionHttpFailure(int status) => TryonFailure(
  (switch (status) {
    401 ||
    403 => 'انتهت صلاحية تسجيل الدخول أو رُفض الوصول للجلسة. سجّل الدخول مجدداً.',
    404 =>
      'خدمة التجربة غير منشورة على الخادم. يلزم نشر decart-session على Supabase.',
    429 => 'عدد محاولات الاتصال كبير. انتظر قليلاً ثم أعد المحاولة.',
    502 =>
      'تعذر إصدار رمز جلسة Decart. يلزم التحقق من مفتاح الخدمة وصلاحية الحساب على الخادم.',
    503 =>
      'خدمة التجربة غير مهيأة أو غير متاحة حالياً. تحقق من إعدادات الخادم ومفتاح Decart.',
    _ => 'تعذر تجهيز جلسة التجربة من الخادم (HTTP $status).',
  }).tr,
);

TryonFailure vtonExceptionToFailure(DecartVtonException error) {
  final lower = error.message.toLowerCase();
  if (lower.contains('credit') ||
      lower.contains('balance') ||
      lower.contains('quota') ||
      lower.contains('billing') ||
      lower.contains('payment') ||
      lower.contains('402')) {
    return TryonFailure(
      'نفد رصيد حساب Decart أو انتهى الاشتراك. يرجى من الإدارة شحن الرصيد أو تحديث المفتاح.'.tr,
    );
  }

  final base = (switch (error.code) {
    VtonErrorCode.permissionDenied =>
      'يلزم منح إذن الكاميرا لتشغيل تجربة الملابس المباشرة.',
    VtonErrorCode.cameraUnavailable =>
      'تعذر فتح الكاميرا. تأكد من عدم استخدامها في تطبيق آخر.',
    VtonErrorCode.invalidApiKey =>
      'مفتاح أو رصيد جلسة Decart غير صالح أو منتهي. يرجى من الإدارة تحديث المفتاح من لوحة التحكم.',
    VtonErrorCode.modelNotFound =>
      'نموذج Lucy VTON المطلوب غير متاح حالياً على الخادم.',
    VtonErrorCode.connectionTimeout =>
      'انتهت مهلة الاتصال بخادم التجربة. تحقق من سرعة الإنترنت ثم أعد المحاولة.',
    VtonErrorCode.webrtc ||
    VtonErrorCode.websocket ||
    VtonErrorCode.signaling ||
    VtonErrorCode.network =>
      'تعذر استقرار اتصال الفيديو عبر الشبكة. تحقق من الإنترنت وأعد المحاولة.',
    VtonErrorCode.promptRejected =>
      'لم يتم قبول وصف القطعة على الخادم. جرّب قطعة أخرى.',
    VtonErrorCode.server =>
      'حدث خطأ مؤقت في خادم Decart. أعد المحاولة بعد قليل.',
    VtonErrorCode.invalidInput ||
    VtonErrorCode.invalidOptions =>
      'بيانات القطعة أو إعدادات الجلسة غير صالحة.',
    VtonErrorCode.notInitialized ||
    VtonErrorCode.notConnected =>
      'انقطعت الجلسة الحالية. أعد تشغيل المعاينة المباشرة.',
    VtonErrorCode.cancelled => 'تم إيقاف عملية التجربة.',
    VtonErrorCode.unknown =>
      'حدث خطأ غير متوقع أثناء المعاينة المباشرة. أعد المحاولة.',
  }).tr;

  final tag = _sanitizeVtonDiagnostic(error);
  return TryonFailure(tag == null ? base : '$base ($tag)');
}

String? _sanitizeVtonDiagnostic(DecartVtonException error) {
  final code = (error.nativeCode ?? error.code.name).trim();
  var detail = error.message
      .replaceAll(RegExp(r'(?:https?|wss?)://\S+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\b(?:dct_|ek_|eyJ)[A-Za-z0-9._-]+\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (detail.length > 72) {
    detail = '${detail.substring(0, 72)}…';
  }
  if (code.isEmpty && detail.isEmpty) return null;
  if (detail.isEmpty) return code;
  if (code.isEmpty) return detail;
  return '$code: $detail';
}
