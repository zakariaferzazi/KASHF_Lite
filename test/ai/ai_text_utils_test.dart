import 'package:flutter_test/flutter_test.dart';

import 'package:kashf_lite/services/ai/ai_text_utils.dart';

void main() {
  group('hasLatinLetters', () {
    test('returns true when the string contains ASCII letters', () {
      expect(hasLatinLetters('Lattafa'), isTrue);
      expect(hasLatinLetters('#Dior'), isTrue);
      expect(hasLatinLetters('Hello 123'), isTrue);
    });

    test('returns false for purely Arabic / numeric strings', () {
      expect(hasLatinLetters('لاتافا'), isFalse);
      expect(hasLatinLetters('123 + 24%'), isFalse);
    });
  });

  group('isMostlyArabic', () {
    test('returns true for Arabic-dominant strings', () {
      expect(isMostlyArabic('مرحبا بكم'), isTrue);
      expect(isMostlyArabic('للطافة'), isTrue);
    });

    test('returns false for Latin-dominant strings', () {
      expect(isMostlyArabic('Lattafa Brand'), isFalse);
    });

    test('returns false for empty / digit-only strings', () {
      expect(isMostlyArabic(''), isFalse);
      expect(isMostlyArabic('12345'), isFalse);
    });
  });

  group('localiseBrandOrTag', () {
    test('passes through English text unchanged when locale is en', () {
      expect(localiseBrandOrTag('Lattafa', locale: 'en'), 'Lattafa');
      expect(localiseBrandOrTag('#Lattafa', locale: 'en'), '#Lattafa');
    });

    test('passes through already-Arabic strings unchanged', () {
      expect(localiseBrandOrTag('لاتافا', locale: 'ar'), 'لاتافا');
      expect(localiseBrandOrTag('#لاتافا', locale: 'ar'), '#لاتافا');
    });

    test('transliterates known brand to Arabic', () {
      expect(localiseBrandOrTag('Lattafa', locale: 'ar'), 'لاتافا');
      expect(localiseBrandOrTag('#Lattafa', locale: 'ar'), '#لاتافا');
      expect(localiseBrandOrTag('Dior', locale: 'ar'), 'ديور');
      expect(localiseBrandOrTag('Starbucks', locale: 'ar'), 'ستاربكس');
    });

    test('transliterates known status / category words', () {
      expect(localiseBrandOrTag('Monitored', locale: 'ar'), 'تحت المراقبة');
      expect(localiseBrandOrTag('Analyzing', locale: 'ar'), 'قيد التحليل');
      expect(localiseBrandOrTag('Perfume', locale: 'ar'), 'عطر');
    });

    test('keeps unknown Latin words intact (no info loss)', () {
      expect(localiseBrandOrTag('Quiborium', locale: 'ar'), 'Quiborium');
    });

    test('preserves the leading # prefix through transliteration', () {
      expect(localiseBrandOrTag('#Dior', locale: 'ar'), '#ديور');
      expect(localiseBrandOrTag('#Shein', locale: 'ar'), '#شي إن');
    });

    test('returns empty string unchanged', () {
      expect(localiseBrandOrTag('', locale: 'ar'), '');
      expect(localiseBrandOrTag('', locale: 'en'), '');
    });
  });
}
