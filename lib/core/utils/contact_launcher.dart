import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_translations.dart';
import 'app_haptics.dart';
import 'snackbar_utils.dart';

/// Normalizes a phone number (especially Palestinian 059/056 numbers) for WhatsApp.
String normalizeWhatsAppPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) {
    digits = digits.substring(1);
  }
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0') && digits.length == 10) {
    // Local Palestinian/Gaza mobile number (059xxxxxxx / 056xxxxxxx)
    digits = '970${digits.substring(1)}';
  }
  return digits;
}

Future<bool> launchPhoneCall(BuildContext context, String phone) async {
  final clean = phone.trim();
  if (clean.isEmpty) return false;
  final uri = Uri(scheme: 'tel', path: clean);
  try {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      showAppSnackBar(context, 'تعذر فتح تطبيق الاتصال'.tr, isError: true);
    }
    return launched;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'تعذر فتح تطبيق الاتصال'.tr, isError: true);
    }
    return false;
  }
}

Future<bool> launchWhatsAppChat(
  BuildContext context, {
  required String phone,
  String? message,
}) async {
  final normalized = normalizeWhatsAppPhone(phone);
  if (normalized.isEmpty) return false;
  final uri = Uri.https('wa.me', '/$normalized', {
    if (message != null && message.trim().isNotEmpty) 'text': message.trim(),
  });
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showAppSnackBar(context, 'تعذر فتح واتساب على هذا الجهاز'.tr, isError: true);
    }
    return launched;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'تعذر فتح واتساب على هذا الجهاز'.tr, isError: true);
    }
    return false;
  }
}

Future<void> copyTextWithFeedback(
  BuildContext context, {
  required String text,
  required String label,
}) async {
  await Clipboard.setData(ClipboardData(text: text.trim()));
  AppHaptics.selection();
  if (!context.mounted) return;
  showAppSnackBar(context, '${'تم نسخ'.tr} $label');
}

/// Formats a shop-configured delivery appointment into a crisp single-line label.
String formatDeliveryScheduleSummary({
  DateTime? scheduledAt,
  String? timeWindow,
  DateTime? now,
}) {
  final parts = <String>[];
  if (scheduledAt != null) {
    final local = scheduledAt.toLocal();
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final target = DateTime(local.year, local.month, local.day);
    final diff = target.difference(today).inDays;

    final datePart =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    if (diff == 0) {
      parts.add('${'اليوم'.tr} ($datePart)');
    } else if (diff == 1) {
      parts.add('${'غداً'.tr} ($datePart)');
    } else {
      parts.add('$datePart/${local.year}');
    }
  }
  final cleanWindow = timeWindow?.trim() ?? '';
  if (cleanWindow.isNotEmpty) {
    parts.add(cleanWindow.tr);
  }
  return parts.join(' · ');
}
