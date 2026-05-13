@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/mushaf_locator_qcf.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/mushaf_locator.dart';

/// Smoke constants. The page numbers below are properties of the standard
/// 604-page Madani mushaf — they double as a tamper detector against
/// accidental data drift in `qcf_quran_plus`.
const int _pageForAlFatihah1 = 1;
const int _pageForAyatAlKursi = 42;

void main() {
  group('QcfMushafLocator (against bundled qcf_quran_plus data)', () {
    late MushafLocator locator;

    setUpAll(() {
      final created = QcfMushafLocator.create();
      expect(
        created,
        isA<Ok<QcfMushafLocator>>(),
        reason:
            'create() must succeed against the real package data; '
            'failure: ${created.failureOrNull}',
      );
      locator = (created as Ok<QcfMushafLocator>).value;
    });

    test('Al-Fatihah ayah 1 lives on page $_pageForAlFatihah1', () {
      final res = locator.pageForAyah(AyahKey(1, 1));
      expect(res, isA<Ok<int>>());
      expect((res as Ok<int>).value, _pageForAlFatihah1);
    });

    test('Ayat al-Kursi (2:255) lives on page $_pageForAyatAlKursi', () {
      final res = locator.pageForAyah(AyahKey(2, 255));
      expect(res, isA<Ok<int>>());
      expect((res as Ok<int>).value, _pageForAyatAlKursi);
    });

    test('round-trip: page → first ayah → page', () {
      const samplePages = <int>[1, 42, 100, 300, kMushafPageCount];
      for (final page in samplePages) {
        final firstAyah = locator.firstAyahOnPage(page);
        expect(
          firstAyah,
          isA<Ok<AyahKey>>(),
          reason: 'firstAyahOnPage($page) must succeed',
        );
        final ayah = (firstAyah as Ok<AyahKey>).value;
        final back = locator.pageForAyah(ayah);
        expect(back, isA<Ok<int>>(), reason: 'pageForAyah($ayah) must succeed');
        expect((back as Ok<int>).value, page);
      }
    });

    test('ayahsOnPage returns same-surah ayahs ordered ascending', () {
      final res = locator.ayahsOnPage(1);
      expect(res, isA<Ok<List<AyahKey>>>());
      final ayahs = (res as Ok<List<AyahKey>>).value;
      expect(ayahs, isNotEmpty);
      expect(ayahs.first.surah, 1);
      for (var i = 1; i < ayahs.length; i++) {
        expect(
          ayahs[i].ayah,
          greaterThan(ayahs[i - 1].ayah),
          reason: 'ayahs on a single page should be in ascending order',
        );
      }
    });

    test('pageForSurah equals pageForAyah(surah, 1)', () {
      const surahs = <int>[1, 2, 18, 36, 67, 114];
      for (final s in surahs) {
        final viaSurah = locator.pageForSurah(s);
        final viaAyah = locator.pageForAyah(AyahKey(s, 1));
        expect(viaSurah, isA<Ok<int>>());
        expect(viaAyah, isA<Ok<int>>());
        expect((viaSurah as Ok<int>).value, (viaAyah as Ok<int>).value);
      }
    });

    test('pageForSurah rejects out-of-range surah', () {
      for (final s in <int>[0, -1, 115, 999]) {
        final res = locator.pageForSurah(s);
        expect(res, isA<Err<int>>());
        expect((res as Err<int>).failure, isA<InvalidInputFailure>());
      }
    });

    test('firstAyahOnPage rejects out-of-range page', () {
      for (final p in <int>[0, -1, 605, 999]) {
        final res = locator.firstAyahOnPage(p);
        expect(res, isA<Err<AyahKey>>());
        expect((res as Err<AyahKey>).failure, isA<InvalidInputFailure>());
      }
    });

    test('ayahsOnPage rejects out-of-range page', () {
      for (final p in <int>[0, -1, 605, 999]) {
        final res = locator.ayahsOnPage(p);
        expect(res, isA<Err<List<AyahKey>>>());
        expect((res as Err<List<AyahKey>>).failure, isA<InvalidInputFailure>());
      }
    });
  });

  group('TextOnlyMushafLocator', () {
    const fallback = TextOnlyMushafLocator();

    test('every method returns UnsupportedFailure', () {
      final r1 = fallback.pageForAyah(AyahKey(1, 1));
      final r2 = fallback.firstAyahOnPage(1);
      final r3 = fallback.ayahsOnPage(1);
      final r4 = fallback.pageForSurah(1);
      expect((r1 as Err<int>).failure, isA<UnsupportedFailure>());
      expect((r2 as Err<AyahKey>).failure, isA<UnsupportedFailure>());
      expect((r3 as Err<List<AyahKey>>).failure, isA<UnsupportedFailure>());
      expect((r4 as Err<int>).failure, isA<UnsupportedFailure>());
    });
  });
}
