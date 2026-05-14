import 'package:flutter_test/flutter_test.dart';

import 'package:quran_player/data/quran/arabic_normalization.dart';

void main() {
  group('normalizeArabicForSearch', () {
    test('folds alef-wasla / hamza-alef variants to plain alef', () {
      expect(normalizeArabicForSearch('ٱللَّه'), 'الله');
      expect(normalizeArabicForSearch('أحمد'), 'احمد');
      expect(normalizeArabicForSearch('إبراهيم'), 'ابراهيم');
      expect(normalizeArabicForSearch('آدم'), 'ادم');
    });

    test('folds alef-maksura to ya', () {
      expect(normalizeArabicForSearch('هدى'), 'هدي');
    });

    test('strips fatha, kasra, damma, shadda, sukun, superscript alef', () {
      expect(
        normalizeArabicForSearch('قُلْ هُوَ ٱللَّهُ أَحَدٌ'),
        'قل هو الله احد',
      );
    });

    test('drops Quranic recitation marks (waqf, sajdah, hizb)', () {
      // U+06DA SMALL HIGH JEEM is one of the Quranic marks in the range
      // ۖ-ۭ. Must be stripped.
      expect(normalizeArabicForSearch('بِسْمِ ٱللَّهِۚ'), 'بسم الله');
    });

    test('collapses runs of whitespace and replaces tatweel', () {
      expect(normalizeArabicForSearch('  الـ\tرحمن  '), 'ال رحمن');
    });

    test('keeps Arabic-Indic and Eastern Arabic-Indic digits', () {
      // Taa marbuta (ة) is preserved as-is — the normalizer folds alef forms
      // and alef-maksura but does NOT collapse taa marbuta to ha.
      expect(normalizeArabicForSearch('سورة ٢ آية ٢٥٥'), 'سورة ٢ اية ٢٥٥');
      expect(normalizeArabicForSearch('۰۱۲۳'), '۰۱۲۳');
    });

    test('replaces Latin and ASCII punctuation with spaces', () {
      expect(normalizeArabicForSearch('الله،'), 'الله');
      expect(normalizeArabicForSearch('hello الله world'), 'الله');
      expect(normalizeArabicForSearch('الله,!?' ), 'الله');
    });

    test('returns empty for whitespace-only input', () {
      expect(normalizeArabicForSearch('   \t  '), isEmpty);
    });

    test('is idempotent', () {
      const samples = ['ٱللَّه', 'بِسْمِ ٱللَّهِ', 'هدى للمتقين'];
      for (final s in samples) {
        final once = normalizeArabicForSearch(s);
        final twice = normalizeArabicForSearch(once);
        expect(twice, once, reason: 'expected idempotence for "$s"');
      }
    });
  });
}
