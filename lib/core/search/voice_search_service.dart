import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Spoken filler words stripped from natural-language voice queries so that
/// conversational phrases like "بدي قميص رجالي لونه أسود" become "قميص رجالي أسود".
const Set<String> _kSpokenStopWords = {
  'ابحث',
  'ابحثلي',
  'بدي',
  'ابغى',
  'أبغى',
  'ابي',
  'أبي',
  'اريد',
  'أريد',
  'عايز',
  'عاوز',
  'وريني',
  'فرجيني',
  'اعطيني',
  'أعطيني',
  'عطيني',
  'هات',
  'جيب',
  'دور',
  'دورلي',
  'شوف',
  'شوفلي',
  'عن',
  'على',
  'في',
  'من',
  'لو',
  'سمحت',
  'فضلك',
  'لونه',
  'لونها',
  'بلون',
  'اللون',
  'مقاسه',
  'مقاسها',
  'بمقاس',
  'مقاس',
  'يا',
  'تطبيق',
  'منتج',
  'منتجات',
  'قطعه',
  'قطعة',
  'ملابس',
  'لبس',
  'search',
  'find',
  'show',
  'me',
  'for',
  'i',
  'want',
  'need',
  'looking',
  'please',
  'with',
  'color',
  'size',
  'a',
  'an',
  'the',
};

/// Normalizes common spoken dialect fashion terms into standard catalog terms.
const Map<String, String> _kSpokenSynonyms = {
  'تيشرت': 'تيشيرت',
  'تيرشيرت': 'تيشيرت',
  't-shirt': 'تيشيرت',
  'جكيت': 'جاكيت',
  'بنطال': 'بنطلون',
  'بناطيل': 'بنطلون',
  'شوز': 'حذاء',
  'جزمه': 'حذاء',
  'جزمة': 'حذاء',
  'بوت': 'حذاء',
  'شنطه': 'حقيبة',
  'شنطة': 'حقيبة',
  'عبايه': 'عباية',
  'بلوزه': 'بلوزة',
  'تنوره': 'تنورة',
  'درزن': '',
  'كحلى': 'كحلي',
  'بيجي': 'بيج',
  'روز': 'وردي',
  'زهري': 'وردي',
  'بمبي': 'وردي',
  'رمادى': 'رمادي',
  'رصاصي': 'رمادي',
};

/// Cleans a raw spoken transcript into crisp, high-accuracy search keywords
/// while preserving product names, colors, sizes, shop names, and numbers.
String cleanVoiceSearchQuery(String rawTranscript) {
  var cleaned = rawTranscript
      .replaceAll('تي شيرت', 'تيشيرت')
      .replaceAll('تي شرت', 'تيشيرت')
      .replaceAll('أوف وايت', 'بيج')
      .replaceAll('اوف وايت', 'بيج')
      .replaceAll(RegExp(r'[،,.؟?!؛:"«»()\[\]{}\-_]'), ' ')
      .trim();
  if (cleaned.isEmpty) return '';

  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  final kept = <String>[];
  for (final word in words) {
    final lower = word.toLowerCase();
    if (_kSpokenStopWords.contains(lower)) continue;
    final mapped = _kSpokenSynonyms[lower] ?? word;
    if (mapped.isNotEmpty) {
      kept.add(mapped);
    }
  }

  if (kept.isEmpty) return cleaned;
  return kept.join(' ');
}

/// Detects whether text is predominantly Arabic (`true`) or Latin/English (`false`).
bool isArabicSpeech(String text) {
  if (text.isEmpty) return true;
  final arabicMatches = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
  final latinMatches = RegExp(r'[a-zA-Z]').allMatches(text).length;
  return arabicMatches >= latinMatches;
}

class VoiceSearchService {
  VoiceSearchService._();

  static final VoiceSearchService instance = VoiceSearchService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  List<LocaleName> _cachedLocales = const [];
  String? _systemLocaleId;

  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String errorMsg)? onError,
  }) async {
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onStatus: (status) {
            isListeningNotifier.value = _speech.isListening;
            onStatus?.call(status);
          },
          onError: (err) {
            isListeningNotifier.value = false;
            onError?.call(err.errorMsg);
          },
          debugLogging: false,
        );
        if (_initialized) {
          try {
            _cachedLocales = await _speech.locales();
            final sys = await _speech.systemLocale();
            _systemLocaleId = sys?.localeId;
          } catch (_) {}
        }
      }
      return _initialized;
    } catch (e) {
      isListeningNotifier.value = false;
      debugPrint('[VoiceSearchService] Failed to initialize SpeechToText: $e');
      return false;
    }
  }

  /// Always resolves to an Arabic speech recognition locale (`ar`) so Arabic
  /// speech is recognized accurately regardless of the device's OS language.
  String _resolveAutoLocaleId() {
    final sys = _systemLocaleId;
    if (sys != null && sys.toLowerCase().startsWith('ar')) {
      return sys;
    }

    for (final loc in _cachedLocales) {
      final id = loc.localeId.toLowerCase();
      if (id == 'ar_sa' ||
          id == 'ar-sa' ||
          id == 'ar_ps' ||
          id == 'ar-ps' ||
          id == 'ar_jo' ||
          id == 'ar-jo' ||
          id == 'ar_eg' ||
          id == 'ar-eg' ||
          id == 'ar_ae' ||
          id == 'ar-ae') {
        return loc.localeId;
      }
    }
    for (final loc in _cachedLocales) {
      if (loc.localeId.toLowerCase().startsWith('ar')) {
        return loc.localeId;
      }
    }
    return 'ar_SA';
  }

  Future<void> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevelChange,
    void Function(String status)? onStatus,
    void Function(String errorMsg)? onError,
  }) async {
    final ok = await initialize(onStatus: onStatus, onError: onError);
    if (!ok) {
      throw StateError('خدمة التعرف الصوتي غير متوفرة على هذا الجهاز');
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    final autoLocale = _resolveAutoLocaleId();
    isListeningNotifier.value = true;

    await _speech.listen(
      localeId: autoLocale,
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(milliseconds: 2200),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
      onSoundLevelChange: onSoundLevelChange,
      onResult: (SpeechRecognitionResult result) {
        final raw = result.recognizedWords.trim();
        final processed = cleanVoiceSearchQuery(raw);
        if (result.finalResult) {
          isListeningNotifier.value = false;
        }
        onResult(processed.isNotEmpty ? processed : raw, result.finalResult);
      },
    );
  }

  Future<void> stopListening() async {
    isListeningNotifier.value = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    isListeningNotifier.value = false;
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
