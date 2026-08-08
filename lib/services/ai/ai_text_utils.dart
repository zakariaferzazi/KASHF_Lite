/// Small helpers for localising AI-generated brand / hashtag
/// strings in the dashboard cards.
library;

/// Returns `true` if [input] contains any Latin letters (a-z / A-Z).
bool hasLatinLetters(String input) {
  for (var i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
      return true;
    }
  }
  return false;
}

/// True if [input] is dominated by Arabic script (>= half the
/// non-whitespace characters are Arabic).
bool isMostlyArabic(String input) {
  var arabic = 0;
  var letters = 0;
  for (var i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    if (c >= 0x0600 && c <= 0x06FF) {
      arabic++;
      letters++;
    } else if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
      letters++;
    }
  }
  if (letters == 0) return false;
  return arabic / letters >= 0.5;
}

/// Returns `true` if [input] starts with `#`.
bool startsWithHash(String input) {
  return input.startsWith('#');
}

/// A small transliteration map for the brand names the model is
/// most likely to emit. When the active locale is Arabic and
/// the AI returns a brand written in Latin letters, we look
/// the word up here and return its Arabic spelling. Misses
/// fall back to returning [input] unchanged so we never lose
/// information.
const Map<String, String> _brandAr = <String, String>{
  'lattafa': 'لاتافا',
  'dior': 'ديور',
  'sauvage': 'سوفاج',
  'bvlgari': 'بولغاري',
  'oud satin': 'عود ساتان',
  'iphone': 'آيفون',
  'adidas': 'أديداس',
  'ultraboost': 'ألترابوست',
  'starbucks': 'ستاربكس',
  'tiktok': 'تيك توك',
  'shein': 'شي إن',
  'nivea': 'نيفيا',
  'samsung': 'سامسونج',
  'apple': 'أبل',
  'yasmine': 'ياسمين',
  'gucci': 'غوتشي',
  'chanel': 'شانيل',
  'prada': 'برادا',
  'versace': 'فيرساتشي',
  'hermes': 'هيرميس',
  'puma': 'بوما',
  'nike': 'نايكي',
  'mango': 'مانجو',
  'zara': 'زارا',
  'h&m': 'اتش آند ام',
  'new launch': 'إطلاق جديد',
  'summer campaign': 'حملة صيفية',
  'monitored': 'تحت المراقبة',
  'analyzing': 'قيد التحليل',
  'collecting': 'قيد الجمع',
  'new updates': 'تحديثات جديدة',
  'paused': 'متوقفة',
  'escalated': 'متصاعدة',
  'live': 'مباشر',
  'perfume': 'عطر',
  'beauty': 'جمال',
  'fashion': 'أزياء',
  'tech': 'تقنية',
  'f&b': 'أغذية ومشروبات',
  'electronics': 'إلكترونيات',
};

/// Normalises a brand / hashtag string for display in the
/// [locale] locale. When [locale] is Arabic and the input
/// contains Latin letters, we attempt to transliterate known
/// brands and otherwise keep the original (so we never lose
/// information the user might recognise). The leading `#` is
/// preserved and rendered with the original script.
String localiseBrandOrTag(String input, {required String locale}) {
  if (input.isEmpty) return input;
  if (locale != 'ar') return input;

  // If the string is already mostly Arabic, keep it as-is.
  if (isMostlyArabic(input)) return input;

  // Try a direct dictionary lookup on the full string.
  final lower = input.toLowerCase().trim();
  if (_brandAr.containsKey(lower)) {
    final mapped = _brandAr[lower]!;
    return lower.startsWith('#') ? '#$mapped' : mapped;
  }

  // Walk the words and transliterate any that are in the
  // dictionary. Unknown words stay in Latin.
  final out = StringBuffer();
  for (final part in lower.split(RegExp(r'(\s+|[-_/])'))) {
    if (part.isEmpty) continue;
    final mapped = _brandAr[part];
    if (mapped != null) {
      out.write(mapped);
    } else {
      out.write(part);
    }
  }
  // Preserve the leading '#' if it was there.
  if (input.startsWith('#') && !out.toString().startsWith('#')) {
    return '#${out.toString()}';
  }
  return out.toString();
}
