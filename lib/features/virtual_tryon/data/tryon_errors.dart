import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

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
    return const TryonFailure(
      'إذن الكاميرا مرفوض. اسمح لهذا الموقع باستخدام الكاميرا من إعدادات المتصفح ثم أعد المحاولة.',
    );
  }
  if (text.contains('notfounderror') ||
      text.contains('cameranotfound') ||
      text.contains('devicesnotfound')) {
    return const TryonFailure(
      'لم يعثر المتصفح على كاميرا. صِل كاميرا بالكمبيوتر ثم أعد المحاولة.',
    );
  }
  if (text.contains('notreadableerror') ||
      text.contains('cameranotreadable') ||
      text.contains('trackstarterror') ||
      text.contains('could not start video')) {
    return const TryonFailure(
      'تعذر تشغيل الكاميرا. قد تكون مستخدمة في تطبيق أو تبويب آخر؛ أغلقه وأعد المحاولة.',
    );
  }
  if (text.contains('overconstrained') ||
      text.contains('constraintnotsatisfied')) {
    return const TryonFailure(
      'الكاميرا لا تدعم إعدادات الفيديو المطلوبة. جرّب كاميرا أخرى.',
    );
  }
  if (text.contains('securityerror') ||
      text.contains('camerasecurity') ||
      text.contains('cameranotsupported') ||
      text.contains('insecure context')) {
    return const TryonFailure(
      'الوصول إلى الكاميرا غير متاح. افتح التطبيق عبر HTTPS أو localhost في متصفح يدعم الكاميرا.',
    );
  }
  if (error is TimeoutException) {
    return const TryonFailure(
      'انتهت مهلة تشغيل الكاميرا. تحقق من طلب الإذن ثم أعد المحاولة.',
    );
  }
  if (error is MissingPluginException) {
    return const TryonFailure(
      'إضافة الكاميرا غير مهيأة. أعد تشغيل التطبيق بالكامل بعد تحديث الحزم.',
    );
  }
  return const TryonFailure(
    'فشل فتح الكاميرا. تحقق من توصيلها ومن إذن استخدامها في المتصفح أو إعدادات الجهاز.',
  );
}

TryonFailure startupFailure(Object error, TryonStartupStage stage) {
  if (error is TryonFailure) return error;
  if (stage == TryonStartupStage.camera) return cameraFailure(error);
  return TryonFailure(switch (stage) {
    TryonStartupStage.camera => 'تعذر فتح الكاميرا.',
    TryonStartupStage.session =>
      'تعذر تجهيز جلسة التجربة من الخادم. تحقق من الشبكة وتسجيل الدخول.',
    TryonStartupStage.peer =>
      'تعذر تهيئة اتصال الفيديو. جرّب متصفحاً حديثاً يدعم WebRTC.',
    TryonStartupStage.signaling =>
      'تعذر فتح قناة الاتصال بخادم التجربة. تحقق من الشبكة ثم أعد المحاولة.',
    TryonStartupStage.garment => 'تعذر تحميل صورة القطعة. تحقق من رابط الصورة والسماح بتحميلها من المتصفح (CORS).',
  });
}

TryonFailure sessionHttpFailure(int status) => TryonFailure(switch (status) {
  401 ||
  403 => 'انتهت صلاحية تسجيل الدخول أو رُفض الوصول للجلسة. سجّل الدخول مجدداً.',
  404 =>
    'خدمة التجربة غير منشورة على الخادم. يلزم نشر decart-session على Supabase.',
  429 => 'عدد محاولات الاتصال كبير. انتظر قليلاً ثم أعد المحاولة.',
  502 => 'تعذر إصدار رمز جلسة Decart. يلزم التحقق من مفتاح الخدمة وصلاحية الحساب على الخادم.',
  503 => 'خدمة التجربة غير مهيأة أو غير متاحة حالياً. تحقق من إعدادات الخادم ومفتاح Decart.',
  _ => 'تعذر تجهيز جلسة التجربة من الخادم (HTTP $status).',
});
