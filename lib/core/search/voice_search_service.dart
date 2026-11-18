import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'text_search_engine.dart';

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
  // Levantine / Gulf / Egyptian conversational fillers
  'بدّي',
  'بدنا',
  'ممكن',
  'حابب',
  'حاب',
  'حابه',
  'نفسي',
  'ودي',
  'عندكم',
  'عندك',
  'فيه',
  'موجود',
  'اللي',
  'الي',
  'يكون',
  'شي',
  'اشي',
  'إشي',
  'حاجة',
  'حاجه',
  'لون',
  'لونو',
  'مقاسو',
  'قياس',
  'كمان',
  'طيب',
  'يعني',
  'هيك',
  'هاد',
  'هذا',
  'هذه',
  'هاي',
  'لي',
  'بليز',
  'some',
  'any',
  'get',
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
  'تشيرت': 'تيشيرت',
  't-shirt': 'تيشيرت',
  'جكيت': 'جاكيت',
  'جاكت': 'جاكيت',
  'بنطال': 'بنطلون',
  'بناطيل': 'بنطلون',
  'شوز': 'حذاء',
  'جزمه': 'حذاء',
  'كوتشي': 'حذاء',
  'سنيكرز': 'حذاء',
  'بوت': 'حذاء',
  'شنطه': 'حقيبة',
  'عبايه': 'عباية',
  'بلوزه': 'بلوزة',
  'تنوره': 'تنورة',
  'بيجامه': 'بيجامة',
  'درزن': '',
  'كحلى': 'كحلي',
  'بيجي': 'بيج',
  'روز': 'وردي',
  'زهري': 'وردي',
  'بمبي': 'وردي',
  'بينك': 'وردي',
  'رمادى': 'رمادي',
  'رصاصي': 'رمادي',
  'سكني': 'رمادي',
  'تحت ال': 'تحت',
  'فوق ال': 'فوق',
};

final Set<String> _kNormalizedStopWords = _kSpokenStopWords
    .map(normalizeSearchText)
    .where((s) => s.isNotEmpty)
    .toSet();

/// Fashion domain bias phrases supplied to platform speech recognizers.
const List<String> _kVoiceContextualPhrases = [
  'هودي',
  'سويت شيرت',
  'تيشيرت',
  'قميص',
  'بنطلون',
  'جينز',
  'فستان',
  'عباية',
  'جاكيت',
  'بلوفر',
  'حذاء',
  'حقيبة',
  'طقم',
  'بيجامة',
  'أوفر سايز',
  'أسود',
  'أبيض',
  'أزرق',
  'كحلي',
  'أحمر',
  'بيج',
  'رمادي',
  'وردي',
  'زيتوني',
  'رجالي',
  'نسائي',
  'أطفال',
  'شيكل',
  'أقل من',
  'XS',
  'S',
  'M',
  'L',
  'XL',
  'XXL',
];

/// Cleans a raw spoken transcript into crisp, high-accuracy search keywords
/// while preserving product names, colors, sizes, shop names, and numbers.
String cleanVoiceSearchQuery(String rawTranscript) {
  var cleaned = rawTranscript
      .replaceAll('تي شيرت', 'تيشيرت')
      .replaceAll('تي شرت', 'تيشيرت')
      .replaceAll('أوف وايت', 'بيج')
      .replaceAll('اوف وايت', 'بيج')
      .replaceAll('إكس إكس إل', 'XXL')
      .replaceAll('دبل إكس لارج', 'XXL')
      .replaceAll('دبل إكس', 'XXL')
      .replaceAll('إكس لارج', 'XL')
      .replaceAll('اكس لارج', 'XL')
      .replaceAll('إكس سمول', 'XS')
      .replaceAll('اكس سمول', 'XS')
      .replaceAllMapped(
        RegExp(
          r'(^|\s)(تحت|فوق|اقل من|أقل من|اكثر من|أكثر من|ارخص من|أرخص من|اعلى من|أعلى من|بحدود|لحد|من)\s+ال\s*(\d+)',
        ),
        (m) => '${m[1]}${m[2]} ${m[3]}',
      )
      .replaceAll(RegExp(r'[،,.؟?!؛:"«»()\[\]{}\-_]'), ' ')
      .trim();
  if (cleaned.isEmpty) return '';

  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  final kept = <String>[];
  String? prevNorm;
  for (final word in words) {
    final norm = normalizeSearchText(word);
    if (norm.isEmpty) continue;
    if (_kSpokenStopWords.contains(word.toLowerCase()) ||
        _kNormalizedStopWords.contains(norm)) {
      continue;
    }
    final mapped =
        _kSpokenSynonyms[word.toLowerCase()] ?? _kSpokenSynonyms[norm] ?? word;
    if (mapped.isEmpty) continue;
    final mappedNorm = normalizeSearchText(mapped);
    if (mappedNorm == prevNorm) continue; // drop STT stutter repetitions
    prevNorm = mappedNorm;
    kept.add(mapped);
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

/// Picks the most catalog-relevant transcript among the recognizer's
/// alternatives: confidence plus a bonus for every recognized fashion term
/// (colors, sizes, garments, materials) and price number.
String pickBestVoiceTranscript(List<({String text, double confidence})> options) {
  if (options.isEmpty) return '';
  var bestText = options.first.text;
  var bestScore = double.negativeInfinity;
  for (var i = 0; i < options.length; i++) {
    final option = options[i];
    final cleaned = cleanVoiceSearchQuery(option.text);
    if (cleaned.trim().isEmpty) continue;
    var known = 0;
    for (final word in normalizeSearchText(cleaned).split(' ')) {
      if (word.isEmpty) continue;
      if (isKnownSearchTerm(word) || RegExp(r'^\d+$').hasMatch(word)) known++;
    }
    final confidence = option.confidence > 0 ? option.confidence : 0.5;
    // Slight preference for the recognizer's own ranking order.
    final score = confidence + known * 0.25 - i * 0.02;
    if (score > bestScore) {
      bestScore = score;
      bestText = option.text;
    }
  }
  return bestText;
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
      listenOptions: SpeechListenOptions(
        localeId: autoLocale,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(milliseconds: 2200),
        partialResults: true,
        cancelOnError: false,
        // Search mode uses the recognizer's short-query (web search) language
        // model, which is far more accurate for product keywords than dictation.
        listenMode: ListenMode.search,
        contextualPhrases: _kVoiceContextualPhrases,
      ),
      onSoundLevelChange: onSoundLevelChange,
      onResult: (SpeechRecognitionResult result) {
        final raw = result.finalResult && result.alternates.length > 1
            ? pickBestVoiceTranscript([
                for (final alt in result.alternates)
                  (text: alt.recognizedWords.trim(), confidence: alt.confidence),
              ]).trim()
            : result.recognizedWords.trim();
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
