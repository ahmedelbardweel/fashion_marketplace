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
  'ابي',
  'اريد',
  'أريد',
  'عايز',
  'عاوز',
  'وريني',
  'فرجيني',
  'اعطيني',
  'عطيني',
  'هات',
  'جيب',
  'دور',
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
  'مقاسه',
  'مقاسها',
  'بمقاس',
  'يا',
  'تطبيق',
  'منتج',
  'منتجات',
  'قطعه',
  'قطعة',
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

/// Cleans a raw spoken transcript into crisp search keywords while preserving
/// product names, colors, sizes, shop names, and numbers.
String cleanVoiceSearchQuery(String rawTranscript) {
  final cleaned = rawTranscript
      .replaceAll(RegExp(r'[،,.؟?!؛:"«»()\[\]{}]'), ' ')
      .trim();
  if (cleaned.isEmpty) return '';

  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  final kept = words
      .where((w) => !_kSpokenStopWords.contains(w.toLowerCase()))
      .toList();

  // If all words were stop words, return the original cleaned transcript
  if (kept.isEmpty) return cleaned;
  return kept.join(' ');
}

class VoiceSearchService {
  VoiceSearchService._();

  static final VoiceSearchService instance = VoiceSearchService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String errorMsg)? onError,
  }) async {
    try {
      _initialized = await _speech.initialize(
        onStatus: onStatus,
        onError: (err) => onError?.call(err.errorMsg),
        debugLogging: false,
      );
      return _initialized;
    } catch (e) {
      debugPrint('[VoiceSearchService] Failed to initialize SpeechToText: $e');
      return false;
    }
  }

  Future<void> startListening({
    required void Function(String recognizedText, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevelChange,
    String preferredLanguageCode = 'ar',
  }) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) {
        throw StateError('خدمة التعرف الصوتي غير متوفرة على هذا الجهاز');
      }
    }

    String? localeId;
    try {
      final locales = await _speech.locales();
      final prefix = preferredLanguageCode.toLowerCase();
      for (final loc in locales) {
        if (loc.localeId.toLowerCase().startsWith(prefix)) {
          localeId = loc.localeId;
          break;
        }
      }
    } catch (_) {}

    localeId ??= preferredLanguageCode == 'en' ? 'en_US' : 'ar_SA';

    await _speech.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
      ),
      onSoundLevelChange: onSoundLevelChange,
      onResult: (SpeechRecognitionResult result) {
        final raw = result.recognizedWords.trim();
        final processed = result.finalResult ? cleanVoiceSearchQuery(raw) : raw;
        onResult(processed, result.finalResult);
      },
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
