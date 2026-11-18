/// High-accuracy Arabic/English product search engine.
///
/// Features:
/// * Diacritic/hamza-insensitive normalization + Arabic-Indic digits.
/// * Bidirectional synonym groups (colors, sizes, garments, materials, fits…),
///   including multi-word phrases ("اوف وايت", "سويت شيرت", "اوفر سايز").
/// * Light Arabic/English stemming (ال/وال/بال prefixes, ات/ون/ين/ه/s suffixes).
/// * Typo tolerance (bounded Levenshtein) for unknown words and catalog terms.
/// * Natural price phrases ("تحت 100", "بين 50 و 100", "اقل من مية شيكل").
/// * Weighted relevance scoring across fields (name > attributes > description).
library;

import 'dart:math' as math;

/// Number of server rows scanned per text/voice/image search (whole catalog
/// for typical stores) so matches are never limited to the newest items.
const int kSearchPoolSize = 400;

/// Rows scanned from the local encrypted offline database per search.
const int kLocalSearchPoolSize = 2000;

// =============================================================================
// Normalization
// =============================================================================

/// Normalizes Arabic & English text for forgiving, diacritic-insensitive search.
///
/// Unifies hamza forms (`أ إ آ ٱ` -> `ا`), `ة` -> `ه`, `ى`/`ئ` -> `ي`,
/// `ؤ` -> `و`, converts Arabic-Indic/Persian digits to ASCII, strips tashkeel,
/// tatweel and punctuation, and collapses extra whitespace.
String normalizeSearchText(String? input) {
  if (input == null || input.isEmpty) return '';
  final buffer = StringBuffer();
  var previousWasSpace = true;

  for (final rune in input.toLowerCase().runes) {
    // Strip Arabic diacritics (tashkeel) & tatweel (kashida).
    if ((rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640) {
      continue;
    }

    int mapped = rune;
    if (rune >= 0x0660 && rune <= 0x0669) {
      mapped = 0x30 + (rune - 0x0660); // ٠..٩
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      mapped = 0x30 + (rune - 0x06F0); // ۰..۹
    } else {
      switch (rune) {
        case 0x0622: // آ
        case 0x0623: // أ
        case 0x0625: // إ
        case 0x0671: // ٱ
          mapped = 0x0627; // ا
        case 0x0629: // ة
          mapped = 0x0647; // ه
        case 0x0649: // ى
        case 0x0626: // ئ
          mapped = 0x064A; // ي
        case 0x0624: // ؤ
          mapped = 0x0648; // و
        case 0x060C: // ،
        case 0x061B: // ؛
        case 0x061F: // ؟
        case 0x00AB: // «
        case 0x00BB: // »
          mapped = 0x20;
      }
    }

    if (mapped < 0x80 && _kAsciiPunctuationToSpace.contains(mapped)) {
      mapped = 0x20;
    }

    final char = String.fromCharCode(mapped);
    final isSpace = char.trim().isEmpty;
    if (isSpace) {
      if (!previousWasSpace) {
        buffer.write(' ');
        previousWasSpace = true;
      }
    } else {
      buffer.write(char);
      previousWasSpace = false;
    }
  }

  return buffer.toString().trim();
}

/// ASCII punctuation converted to spaces (keeps `.`, `%`, `#` for prices/hex).
final Set<int> _kAsciiPunctuationToSpace = ',?!;:"\'()[]{}|_~`/\\-*+=<>^'
    .runes
    .toSet();

// =============================================================================
// Synonym / equivalence groups
// =============================================================================

/// Bidirectional equivalence classes (all terms must be written in their
/// already-normalized form: `ه` instead of `ة`, `ا` instead of `أ`).
const List<List<String>> kSearchEquivalenceGroups = [
  // ---- Colors ----
  ['ازرق', 'زرقاء', 'زرقا', 'زرق', 'سماوي', 'لبني', 'بيبي بلو', 'بيبيبلو', 'ازرق فاتح', 'بلو', 'blue', 'sky', 'cyan', 'light blue'],
  ['كحلي', 'كحليه', 'كحلي غامق', 'ازرق غامق', 'نيلي', 'نيفي', 'navy', 'dark blue'],
  ['تركواز', 'تركوازي', 'فيروزي', 'تيل', 'تيفاني', 'teal', 'turquoise'],
  ['اسود', 'سوداء', 'سودا', 'سود', 'فحمي', 'بلاك', 'black', 'dark'],
  ['ابيض', 'بيضاء', 'بيضا', 'بيض', 'سكري', 'عاجي', 'ثلجي', 'لؤلؤي', 'وايت', 'white', 'ivory'],
  ['احمر', 'حمراء', 'حمرا', 'حمر', 'عنابي', 'نبيتي', 'خمري', 'مارون', 'دموي', 'red', 'burgundy', 'maroon', 'wine', 'crimson'],
  ['اخضر', 'خضراء', 'خضرا', 'خضر', 'زيتي', 'زيتوني', 'فستقي', 'نعناعي', 'عشبي', 'اخضر غامق', 'green', 'olive', 'mint', 'sage'],
  ['اصفر', 'صفراء', 'صفرا', 'صفر', 'ذهبي', 'خردلي', 'موستردي', 'كموني', 'ليموني', 'yellow', 'gold', 'mustard', 'lemon'],
  ['بيج', 'بيجي', 'رملي', 'كريمي', 'اوف وايت', 'اوفوايت', 'جملي', 'كاكي', 'كافيه', 'نود', 'نودز', 'beige', 'cream', 'camel', 'khaki', 'off white', 'offwhite', 'nude', 'sand'],
  ['بني', 'بنيه', 'عسلي', 'شوكولاته', 'كستنائي', 'هافان', 'اسمر', 'سمراء', 'قهوه', 'برونزي', 'brown', 'chocolate', 'coffee', 'bronze', 'tan'],
  ['رمادي', 'رماديه', 'رصاصي', 'فضي', 'سلفر', 'فيراني', 'سكني', 'سموكي', 'رمادي فاتح', 'رمادي غامق', 'gray', 'grey', 'silver', 'charcoal'],
  ['وردي', 'ورديه', 'زهري', 'زهريه', 'زهر', 'بمبي', 'بينك', 'فوشيا', 'روز', 'كشمير', 'كشميري', 'pink', 'rose', 'magenta', 'fuchsia', 'blush'],
  ['بنفسجي', 'بنفسجيه', 'موف', 'ليلكي', 'لافندر', 'ارجواني', 'بتنجاني', 'purple', 'violet', 'lavender', 'lilac', 'plum'],
  ['برتقالي', 'برتقاليه', 'اورنج', 'مشمشي', 'مرجاني', 'خوخي', 'نحاسي', 'orange', 'coral', 'peach'],
  ['ملون', 'ملونه', 'مزركش', 'مشجر', 'مورد', 'منقوش', 'colorful', 'printed', 'floral'],
  ['مقلم', 'مخطط', 'سترايب', 'striped', 'stripes'],
  ['كاروهات', 'مربعات', 'كاروه', 'plaid', 'checked'],
  // ---- Sizes ----
  ['xs', 'اكس سمول', 'صغير جدا', 'xsmall'],
  ['s', 'سمول', 'صغير', 'small'],
  ['m', 'ميديم', 'ميديوم', 'ميدم', 'وسط', 'متوسط', 'medium'],
  ['l', 'لارج', 'كبير', 'large'],
  ['xl', 'اكس لارج', 'اكس ال', 'كبير جدا', 'xlarge'],
  ['xxl', '2xl', 'دبل اكس', 'تو اكس', 'اكسين لارج', 'دبل اكس لارج', 'اكس اكس ال'],
  ['3xl', 'xxxl', 'ثري اكس', 'تري اكس'],
  ['فري سايز', 'فريسايز', 'مقاس واحد', 'free size', 'one size'],
  // ---- Garments & Departments ----
  ['هودي', 'هوديز', 'هوديات', 'سويت شيرت', 'سويتشيرت', 'hoodie', 'hoodies', 'sweatshirt'],
  ['كنزه', 'كنزات', 'بلوفر', 'سويتر', 'تريكو', 'كارديجان', 'كارديغان', 'pullover', 'sweater', 'knit', 'cardigan'],
  ['قميص', 'قمصان', 'شميز', 'shirt', 'polo', 'بولو'],
  ['تيشيرت', 'تي شيرت', 'تيشرت', 'تيشيرتات', 'توب', 'كروب توب', 'كروبتوب', 'بودي', 'تيرشيرت', 'tshirt', 't shirt', 'tee', 'crop top', 'bodysuit'],
  ['بلوزه', 'بلوزات', 'تيونيك', 'top', 'blouse', 'tunic'],
  ['بنطلون', 'بناطيل', 'بنطال', 'بنطلونات', 'شروال', 'كارجو', 'كارغو', 'تشينو', 'باجي', 'وايد ليج', 'وايدليج', 'pants', 'trousers', 'cargo', 'chino', 'baggy', 'wide leg'],
  ['جينز', 'دنيم', 'بنطلون جينز', 'jeans', 'denim'],
  ['شورت', 'شورتات', 'برموده', 'shorts'],
  ['ليقنز', 'ليجن', 'ليجنز', 'سترتش', 'leggings'],
  ['جاكيت', 'جواكيت', 'جاكيتات', 'جكيت', 'جاكت', 'ستره', 'بليزر', 'فيست', 'جيليه', 'jacket', 'blazer', 'vest', 'gilet'],
  ['معطف', 'معاطف', 'بالطو', 'كوت', 'ترنش', 'جاكيت طويل', 'coat', 'overcoat', 'trench'],
  ['فستان', 'فساتين', 'دريس', 'ماكسي', 'سواريه', 'dress', 'gown', 'maxi', 'midi'],
  ['تنوره', 'تنانير', 'جيبه', 'سكيرت', 'skirt'],
  ['عبايه', 'عبايات', 'عباءه', 'جلابيه', 'قفطان', 'كفتان', 'كيمونو', 'abaya', 'kaftan', 'kimono'],
  ['ثوب', 'دشداشه', 'كندوره', 'thobe'],
  ['جمبسوت', 'افرول', 'اوفرول', 'jumpsuit', 'romper', 'overall'],
  ['بيجامه', 'بجامه', 'بيجامات', 'ملابس نوم', 'لانجري', 'pajama', 'pyjama', 'pajamas', 'sleepwear'],
  ['حذاء', 'احذيه', 'شوز', 'سنيكرز', 'كوتشي', 'جزمه', 'بوت', 'بوط', 'هاف بوت', 'كعب', 'هيلز', 'لوفر', 'فلات', 'باليرينا', 'موكاسين', 'shoes', 'sneakers', 'boots', 'heels', 'loafers', 'flats'],
  ['صندل', 'صنادل', 'شبشب', 'شباشب', 'سليبر', 'شحاطه', 'sandals', 'slippers', 'slides'],
  ['حقيبه', 'حقائب', 'شنطه', 'شنط', 'كروس', 'كروس بودي', 'كروسبودي', 'توت باج', 'باكباك', 'شنطه ظهر', 'محفظه', 'جزدان', 'bag', 'handbag', 'backpack', 'tote', 'crossbody', 'wallet'],
  ['بدله', 'بدل', 'طقم', 'اطقم', 'ترنج', 'ترينج', 'بيجامه رياضيه', 'suit', 'set', 'tracksuit'],
  ['حجاب', 'شال', 'طرحه', 'لفه', 'سكارف', 'خمار', 'نقب', 'scarf', 'hijab', 'shawl'],
  ['قبعه', 'كاب', 'طاقيه', 'ايس كاب', 'بيني', 'برنيطه', 'cap', 'hat', 'beanie'],
  ['جوارب', 'شرابات', 'كلسات', 'كولون', 'socks', 'stockings'],
  ['حزام', 'احزمه', 'قشاط', 'belt'],
  ['نظاره', 'نظارات', 'نظاره شمسيه', 'sunglasses', 'glasses'],
  ['ساعه', 'ساعات', 'watch', 'watches'],
  ['اكسسوار', 'اكسسوارات', 'مجوهرات', 'خاتم', 'اسوره', 'سوار', 'عقد', 'سلسال', 'حلق', 'اقراط', 'accessories', 'accessory', 'jewelry'],
  ['رجالي', 'رجال', 'شبابي', 'men', 'mens', 'male'],
  ['نسائي', 'نساء', 'حريمي', 'بناتي', 'ستاتي', 'سيدات', 'women', 'womens', 'ladies', 'female'],
  ['اطفال', 'ولادي', 'بيبي', 'مواليد', 'kids', 'children', 'baby'],
  // ---- Materials ----
  ['قطن', 'قطني', 'قطنيه', 'cotton'],
  ['صوف', 'صوفي', 'صوفيه', 'wool', 'woolen'],
  ['جلد', 'جلدي', 'جلديه', 'شمواه', 'سويد', 'leather', 'suede'],
  ['حرير', 'حريري', 'حريريه', 'ساتان', 'شيفون', 'تول', 'دانتيل', 'silk', 'satin', 'chiffon', 'lace'],
  ['كتان', 'لينين', 'linen'],
  ['مخمل', 'قطيفه', 'كوردروي', 'velvet', 'corduroy'],
  ['فرو', 'فراء', 'فليس', 'مبطن', 'مبطنه', 'fur', 'fleece', 'lined'],
  ['بوليستر', 'ليكرا', 'جيرسيه', 'نايلون', 'polyester', 'lycra', 'jersey', 'nylon'],
  // ---- Fit & Style ----
  ['اوفر سايز', 'اوفرسايز', 'واسع', 'فضفاض', 'بوي فريند', 'oversize', 'oversized', 'loose', 'relaxed'],
  ['سليم فت', 'سليمفت', 'سليم', 'ضيق', 'سكيني', 'slim', 'skinny', 'fitted'],
  ['كاجوال', 'يومي', 'عملي', 'casual', 'everyday'],
  ['رسمي', 'كلاسيك', 'كلاسيكي', 'formal', 'classic', 'office'],
  ['رياضي', 'رياضيه', 'سبورت', 'جيم', 'sport', 'sports', 'athletic', 'gym'],
  ['سهره', 'سواريه', 'حفله', 'مناسبات', 'evening', 'party'],
  // ---- Seasons ----
  ['شتوي', 'شتويه', 'شتاء', 'شتا', 'دافي', 'دافئ', 'ثقيل', 'winter', 'warm'],
  ['صيفي', 'صيفيه', 'صيف', 'خفيف', 'خفيفه', 'summer', 'lightweight'],
  ['ربيعي', 'خريفي', 'spring', 'autumn', 'fall'],
];

/// Terms (normalized) -> indices of groups that contain them.
final Map<String, List<int>> _termToGroups = () {
  final map = <String, List<int>>{};
  for (var i = 0; i < kSearchEquivalenceGroups.length; i++) {
    for (final term in kSearchEquivalenceGroups[i]) {
      (map[term] ??= <int>[]).add(i);
    }
  }
  return map;
}();

/// Multi-word group terms sorted longest-first, for phrase tokenization.
final List<String> _multiWordTerms = () {
  final list = _termToGroups.keys.where((t) => t.contains(' ')).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return list;
}();

/// Single-word group terms (length >= 4) eligible as typo-correction targets.
final List<String> _fuzzyTargetTerms = _termToGroups.keys
    .where((t) => !t.contains(' ') && t.length >= 4)
    .toList(growable: false);

/// Filler words ignored inside typed/spoken queries (only when other tokens remain).
const Set<String> kSearchFillerWords = {
  'لون', 'لونه', 'لونها', 'بلون', 'باللون', 'بالون',
  'مقاس', 'مقاسه', 'مقاسها', 'بمقاس', 'بالمقاس', 'قياس', 'بقياس', 'حجم', 'بحجم', 'نمره',
  'في', 'عن', 'مع', 'او', 'و', 'لل', 'ل', 'ب', 'من', 'الى', 'على',
  'منتج', 'منتجات', 'قطعه', 'موديل', 'نوع', 'شي', 'اشي', 'حاجه', 'قريب', 'شبيه', 'مشابه',
  'سعر', 'بسعر', 'السعر', 'price',
  'the', 'a', 'an', 'for', 'with', 'of', 'in', 'color', 'colour', 'size',
};

const Set<String> _kCurrencyWords = {
  'شيكل', 'شيقل', 'شواقل', 'شيكلات', 'دينار', 'دنانير', 'دولار', 'ريال',
  'جنيه', 'درهم', 'nis', 'ils', 'usd', 'jod', 'sar', 'aed', 'egp', '₪', r'$',
};

/// Returns `true` when [term] (any form) belongs to a known synonym group.
bool isKnownSearchTerm(String term) {
  final norm = normalizeSearchText(term);
  if (norm.isEmpty) return false;
  return _groupsFor(norm).isNotEmpty;
}

/// Returns `true` when [a] and [b] are equal or synonyms (e.g. `زرقاء` / `أزرق`).
bool areSearchTermsEquivalent(String? a, String? b) {
  final na = normalizeSearchText(a);
  final nb = normalizeSearchText(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb || na.contains(nb) || nb.contains(na)) return true;
  final ga = _groupsFor(na);
  if (ga.isEmpty) return false;
  final gb = _groupsFor(nb);
  for (final g in ga) {
    if (gb.contains(g)) return true;
  }
  // Compound values like "ازرق فاتح" vs "سماوي".
  for (final word in nb.split(' ')) {
    for (final g in _groupsFor(word)) {
      if (ga.contains(g)) return true;
    }
  }
  return false;
}

Set<int> _groupsFor(String normalizedTerm) {
  final out = <int>{};
  final direct = _termToGroups[normalizedTerm];
  if (direct != null) out.addAll(direct);
  final bare = stripArabicDefiniteArticle(normalizedTerm);
  if (bare != normalizedTerm) {
    final g = _termToGroups[bare];
    if (g != null) out.addAll(g);
  }
  if (out.isEmpty) {
    final stem = searchStem(normalizedTerm);
    if (stem != normalizedTerm) {
      final g = _termToGroups[stem];
      if (g != null) out.addAll(g);
    }
  }
  return out;
}

// =============================================================================
// Stemming & fuzzy matching
// =============================================================================

/// Strips the leading Arabic definite article `ال` when word length > 3.
String stripArabicDefiniteArticle(String token) {
  if (token.startsWith('ال') && token.length > 3) {
    return token.substring(2);
  }
  return token;
}

final RegExp _latinWord = RegExp(r'^[a-z]+$');

/// Light, consistent stemmer for Arabic (prefix/suffix) & English plurals.
String searchStem(String word) {
  var s = word;
  if (s.length < 3) return s;

  if (_latinWord.hasMatch(s)) {
    if (s.length > 4 && s.endsWith('ies')) return '${s.substring(0, s.length - 3)}y';
    if (s.length > 4 && (s.endsWith('ses') || s.endsWith('xes') || s.endsWith('shes'))) {
      return s.substring(0, s.length - 2);
    }
    if (s.length > 3 && s.endsWith('s') && !s.endsWith('ss')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }

  if (s.length >= 6) {
    for (final p in const ['وال', 'بال', 'كال', 'فال']) {
      if (s.startsWith(p)) {
        s = s.substring(3);
        break;
      }
    }
  }
  if (s.length >= 5 && s.startsWith('لل')) s = s.substring(2);
  s = stripArabicDefiniteArticle(s);

  var changed = true;
  while (changed) {
    changed = false;
    for (final suf in const ['ات', 'ون', 'ين', 'ها', 'ه']) {
      if (s.endsWith(suf) && s.length - suf.length >= 3) {
        s = s.substring(0, s.length - suf.length);
        changed = true;
        break;
      }
    }
  }
  return s;
}

/// Bounded Levenshtein distance check (`true` when distance <= [maxDistance]).
bool isWithinEditDistance(String a, String b, int maxDistance) {
  if (a == b) return true;
  if ((a.length - b.length).abs() > maxDistance) return false;
  final m = a.length;
  final n = b.length;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    var rowMin = curr[0];
    final ca = a.codeUnitAt(i - 1);
    for (var j = 1; j <= n; j++) {
      final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = math.min(
        math.min(prev[j] + 1, curr[j - 1] + 1),
        prev[j - 1] + cost,
      );
      if (curr[j] < rowMin) rowMin = curr[j];
    }
    if (rowMin > maxDistance) return false;
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n] <= maxDistance;
}

int _allowedTypos(String token) {
  if (token.length >= 8) return 2;
  if (token.length >= 5) return 1;
  return 0;
}

// =============================================================================
// Price intent & number words
// =============================================================================

const Map<String, int> _kArabicNumberWords = {
  'عشر': 10, 'عشره': 10, 'عشرين': 20, 'ثلاثين': 30, 'تلاتين': 30,
  'اربعين': 40, 'خمسين': 50, 'ستين': 60, 'سبعين': 70, 'ثمانين': 80,
  'تمانين': 80, 'تسعين': 90, 'ميه': 100, 'مئه': 100, 'ميتين': 200,
  'مئتين': 200, 'ميتان': 200, 'ثلاثميه': 300, 'تلتميه': 300, 'تلاتميه': 300,
  'اربعميه': 400, 'اربعمئه': 400, 'خمسميه': 500, 'خمسمئه': 500,
  'ستميه': 600, 'سبعميه': 700, 'ثمانميه': 800, 'تمنميه': 800, 'تسعميه': 900,
  'الف': 1000, 'خمسه': 5, 'عشرة': 10,
  'ten': 10, 'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
  'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90, 'hundred': 100,
};

/// Converts spoken Arabic/English number words into digits
/// ("مية وخمسين" -> "150", "المية" -> "100", "خمسين" -> "50").
String replaceNumberWords(String normalized) {
  final words = normalized.split(' ');
  final out = <String>[];
  int? acc;
  for (final raw in words) {
    var w = raw;
    var joined = false;
    if (acc != null && w.length > 1 && w.startsWith('و')) {
      final rest = w.substring(1);
      final bareRest = stripArabicDefiniteArticle(rest);
      if (_kArabicNumberWords.containsKey(rest)) {
        w = rest;
        joined = true;
      } else if (_kArabicNumberWords.containsKey(bareRest)) {
        w = bareRest;
        joined = true;
      }
    }
    final directValue = _kArabicNumberWords[w];
    final bareValue = _kArabicNumberWords[stripArabicDefiniteArticle(w)];
    final value = directValue ?? bareValue;
    if (value != null && (acc == null || joined)) {
      acc = (acc ?? 0) + value;
      continue;
    }
    if (acc != null) {
      out.add(acc.toString());
      acc = null;
    }
    out.add(raw);
  }
  if (acc != null) out.add(acc.toString());
  return out.join(' ');
}

/// Parsed natural-language search intent.
class SearchIntent {
  const SearchIntent({required this.text, this.minPrice, this.maxPrice});

  /// Remaining free-text query (normalized) after extracting price phrases.
  final String text;
  final double? minPrice;
  final double? maxPrice;

  bool get hasPrice => minPrice != null || maxPrice != null;
}

const String _num = r'(\d+(?:\.\d+)?)';
const String _optAl = r'(?:ال\s*)?';
final RegExp _kBetweenPrice = RegExp(
  '(?:(?:بين|من|between|from)\\s*$_optAl$_num\\s*(?:و|الى|لل|ل|حتى|لغايه|to|and)\\s*$_optAl$_num)'
  '|(?:$_optAl$_num\\s*(?:الى|حتى|لغايه|to)\\s*$_optAl$_num)',
);
final RegExp _kMaxPrice = RegExp(
  '(?:تحت|اقل من|اقل|ارخص من|ارخص|بحدود|لحد|لغايه|حتى|ما يزيد عن|لا يزيد عن|لا يتجاوز|ما يتجاوز|max|under|below|less than|cheaper than|up to|upto)\\s*$_optAl$_num',
);
final RegExp _kMinPrice = RegExp(
  '(?:فوق|اكثر من|اكبر من|اعلى من|اغلى من|ابتداء من|يبدا من|min|over|above|more than|starting)\\s*$_optAl$_num',
);

/// Extracts price constraints from phrases like "هودي ازرق تحت 100 شيكل".
SearchIntent parseSearchIntent(String? query) {
  var text = normalizeSearchText(query);
  if (text.isEmpty) return const SearchIntent(text: '');
  text = replaceNumberWords(text);

  double? minPrice;
  double? maxPrice;

  final between = _kBetweenPrice.firstMatch(text);
  if (between != null) {
    final a = double.tryParse(between.group(1) ?? between.group(3) ?? '');
    final b = double.tryParse(between.group(2) ?? between.group(4) ?? '');
    if (a != null && b != null) {
      minPrice = math.min(a, b);
      maxPrice = math.max(a, b);
      text = text.replaceRange(between.start, between.end, ' ');
    }
  }
  if (maxPrice == null) {
    final m = _kMaxPrice.firstMatch(text);
    if (m != null) {
      maxPrice = double.tryParse(m.group(1)!);
      text = text.replaceRange(m.start, m.end, ' ');
    }
  }
  if (minPrice == null) {
    final m = _kMinPrice.firstMatch(text);
    if (m != null) {
      minPrice = double.tryParse(m.group(1)!);
      text = text.replaceRange(m.start, m.end, ' ');
    }
  }

  final remaining = text
      .split(' ')
      .where((w) => w.isNotEmpty && !_kCurrencyWords.contains(w))
      .join(' ');
  return SearchIntent(text: remaining, minPrice: minPrice, maxPrice: maxPrice);
}

// =============================================================================
// Prepared query & scoring
// =============================================================================

/// A searchable field with a relevance weight.
class SearchField {
  const SearchField(this.text, [this.weight = 1.0]);
  final String? text;
  final double weight;
}

class _QueryToken {
  _QueryToken({
    required this.raw,
    required this.stem,
    required this.substringTerms,
    required this.wordTerms,
    required this.isAttribute,
    required this.isNumeric,
    required this.typos,
  });

  final String raw;
  final String stem;
  final List<String> substringTerms; // len > 2, matched as substrings
  final Set<String> wordTerms; // short terms matched as whole words
  final bool isAttribute;
  final bool isNumeric;
  final int typos;
}

class _PreparedField {
  _PreparedField(this.text, this.paddedText, this.words, this.stems, this.weight);
  final String text;
  final String paddedText;
  final Set<String> words;
  final Set<String> stems;
  final double weight;
}

final RegExp _numericToken = RegExp(r'^\d+(?:\.\d+)?$');

/// A query parsed once and matched against many records efficiently.
class PreparedSearchQuery {
  PreparedSearchQuery._(this.normalized, this._tokens, this.intent);

  static PreparedSearchQuery? _lastPrepared;
  static String? _lastRaw;

  /// Parses (and memoizes) a raw typed/spoken query.
  factory PreparedSearchQuery.parse(String? raw) {
    final key = raw ?? '';
    if (_lastRaw == key && _lastPrepared != null) return _lastPrepared!;
    final intent = parseSearchIntent(raw);
    final prepared = PreparedSearchQuery._(
      intent.text,
      _tokenize(intent.text),
      intent,
    );
    _lastRaw = key;
    _lastPrepared = prepared;
    return prepared;
  }

  final String normalized;
  final List<_QueryToken> _tokens;
  final SearchIntent intent;

  bool get hasTextTokens => _tokens.isNotEmpty;
  int get tokenCount => _tokens.length;

  static List<_QueryToken> _tokenize(String text) {
    if (text.isEmpty) return const [];
    var working = ' $text ';
    final phraseTokens = <String>[];
    for (final phrase in _multiWordTerms) {
      final padded = ' $phrase ';
      if (working.contains(padded)) {
        phraseTokens.add(phrase);
        working = working.replaceAll(padded, ' ');
      }
    }
    final words = working.split(' ').where((w) => w.isNotEmpty).toList();
    final meaningful = words.where((w) => !kSearchFillerWords.contains(w)).toList();
    final rawTokens = <String>[
      ...phraseTokens,
      ...((meaningful.isEmpty && phraseTokens.isEmpty) ? words : meaningful),
    ];

    final seen = <String>{};
    final tokens = <_QueryToken>[];
    for (final raw in rawTokens) {
      if (!seen.add(raw)) continue;
      tokens.add(_buildToken(raw));
    }
    return tokens;
  }

  static _QueryToken _buildToken(String raw) {
    final isNumeric = _numericToken.hasMatch(raw);
    final bare = stripArabicDefiniteArticle(raw);
    final stem = searchStem(raw);
    final groups = isNumeric ? <int>{} : _groupsFor(raw);
    var typos = isNumeric ? 0 : _allowedTypos(bare);

    // Typo correction against catalog vocabulary ("بنطلوون" -> بنطلون group).
    if (groups.isEmpty && typos > 0) {
      for (final term in _fuzzyTargetTerms) {
        if (isWithinEditDistance(bare, term, typos)) {
          groups.addAll(_termToGroups[term]!);
        }
      }
    }

    final allTerms = <String>{raw, bare};
    for (final g in groups) {
      allTerms.addAll(kSearchEquivalenceGroups[g]);
    }

    final substringTerms = <String>[];
    final wordTerms = <String>{};
    for (final t in allTerms) {
      if (isNumeric || t.length <= 2 || _numericToken.hasMatch(t)) {
        wordTerms.add(t);
      } else {
        substringTerms.add(t);
      }
    }

    return _QueryToken(
      raw: raw,
      stem: stem,
      substringTerms: substringTerms,
      wordTerms: wordTerms,
      isAttribute: groups.isNotEmpty,
      isNumeric: isNumeric,
      // Known catalog terms are spelled correctly; avoid fuzzy noise.
      typos: groups.isNotEmpty && _termToGroups.containsKey(bare) ? 0 : typos,
    );
  }

  static List<_PreparedField> _prepareFields(Iterable<SearchField> fields) {
    final out = <_PreparedField>[];
    for (final f in fields) {
      final norm = normalizeSearchText(f.text);
      if (norm.isEmpty) continue;
      final words = <String>{};
      final stems = <String>{};
      for (final w in norm.split(' ')) {
        if (w.isEmpty) continue;
        words.add(w);
        final bare = stripArabicDefiniteArticle(w);
        words.add(bare);
        stems.add(searchStem(w));
      }
      out.add(_PreparedField(norm, ' $norm ', words, stems, f.weight));
    }
    return out;
  }

  static double _tokenQuality(_QueryToken t, _PreparedField f) {
    final raw = t.raw;
    if (f.words.contains(raw)) return 1.0;
    if (!t.isNumeric && raw.length > 2) {
      if (f.paddedText.contains(' $raw')) return 0.88; // word prefix
      if (f.text.contains(raw)) return 0.7; // inner substring
    }
    for (final eq in t.wordTerms) {
      if (f.words.contains(eq)) return eq == raw ? 1.0 : 0.9;
    }
    for (final eq in t.substringTerms) {
      if (f.paddedText.contains(' $eq')) return 0.86;
      if (f.text.contains(eq)) return 0.68;
    }
    if (!t.isNumeric && t.stem.length >= 3 && f.stems.contains(t.stem)) {
      return 0.78;
    }
    if (t.typos > 0) {
      for (final w in f.words) {
        if (w.length >= 4 && isWithinEditDistance(t.raw, w, t.typos)) {
          return 0.55;
        }
      }
    }
    return 0.0;
  }

  /// Returns a relevance score (> 0) when [fields] satisfy the query, else `null`.
  ///
  /// Attribute tokens (colors, sizes, garments, materials) and numbers are
  /// mandatory; unknown descriptive words may partially miss when the query is
  /// anchored by matched attributes, so long natural queries still find items.
  double? score(Iterable<SearchField> fields) {
    if (_tokens.isEmpty) return 1.0;
    final prepared = _prepareFields(fields);
    if (prepared.isEmpty) return null;

    var total = 0.0;
    var matchedAttributes = 0;
    var unknownTotal = 0;
    var unknownMatched = 0;

    for (final t in _tokens) {
      var best = 0.0;
      for (final f in prepared) {
        final q = _tokenQuality(t, f);
        if (q > 0) {
          final weighted = q * f.weight;
          if (weighted > best) best = weighted;
          if (q >= 1.0 && f.weight >= 3) break;
        }
      }
      final mandatory = t.isAttribute || t.isNumeric;
      if (best <= 0) {
        if (mandatory) return null;
        unknownTotal++;
        continue;
      }
      if (mandatory) {
        matchedAttributes++;
      } else {
        unknownTotal++;
        unknownMatched++;
      }
      total += best;
    }

    final unknownMissed = unknownTotal - unknownMatched;
    if (unknownMissed > 0) {
      final allowedMiss = matchedAttributes > 0
          ? unknownTotal ~/ 2
          : (_tokens.length >= 3 ? 1 : 0);
      if (unknownMissed > allowedMiss) return null;
      total *= (_tokens.length - unknownMissed) / _tokens.length;
    }

    // Phrase bonus: full query appears verbatim in a field (e.g., product name).
    if (_tokens.length >= 2) {
      for (final f in prepared) {
        if (f.text.contains(normalized)) {
          total += 1.5 * f.weight;
          break;
        }
      }
    }
    return total;
  }

  /// Soft overlap score used for "similar products" ranking (never `null`).
  double partialScore(Iterable<SearchField> fields) {
    if (_tokens.isEmpty) return 0.0;
    final prepared = _prepareFields(fields);
    var total = 0.0;
    for (final t in _tokens) {
      var best = 0.0;
      for (final f in prepared) {
        final q = _tokenQuality(t, f);
        if (q > best) best = q;
      }
      if (best <= 0 && t.raw.length >= 3) {
        final prefix = t.raw.substring(0, 3);
        if (prepared.any((f) => f.text.contains(prefix))) best = 0.4;
      }
      total += best * (t.isAttribute ? 1.5 : 1.3);
    }
    return total;
  }
}

/// Checks whether every meaningful token in [query] (or its synonyms, stems,
/// or near-typos) matches any value in [fields].
bool matchesSearchTokens(String? query, Iterable<String?> fields) {
  final normalizedQuery = normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;
  final prepared = PreparedSearchQuery.parse(query);
  if (!prepared.hasTextTokens) return true;
  return prepared.score(fields.map((f) => SearchField(f))) != null;
}
