import 'package:flutter_test/flutter_test.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/mushaf_engine.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/mushaf_locator.dart';
import 'package:tarteel_qul/fixtures.dart';
import 'package:tarteel_qul/tarteel_qul.dart' as qul;

/// `QulMushafLocator` is exercised against `tarteel_qul`'s `DemoMushafAssetSource`
/// — a deterministic three-page mini-layout — so the test does not depend on
/// the gitignored QUL download. It verifies the host adapter: the
/// `MushafResult` → `Result`, `qul.AyahKey` → `AyahKey`, and out-of-range
/// translation. The real 604-page QUL data is validated by `openMushafEngine`'s
/// runtime smoke test and the change's manual checks.
void main() {
  group('QulMushafLocator (over the demo layout)', () {
    late MushafLocator locator;

    setUpAll(() async {
      final opened = await qul.MushafLayoutRepository.open(
        DemoMushafAssetSource(),
      );
      locator = QulMushafLocator(
        (opened as qul.MushafOk<qul.MushafLayoutRepository>).value,
      );
    });

    test('pageForAyah resolves a known ayah', () {
      final res = locator.pageForAyah(AyahKey(1, 1));
      expect(res, isA<Ok<int>>());
      expect((res as Ok<int>).value, 1);
    });

    test('firstAyahOnPage round-trips with pageForAyah', () {
      final first = locator.firstAyahOnPage(1);
      expect(first, isA<Ok<AyahKey>>());
      final ayah = (first as Ok<AyahKey>).value;
      expect(ayah.surah, 1);
      expect(ayah.ayah, 1);
      final back = locator.pageForAyah(ayah);
      expect((back as Ok<int>).value, 1);
    });

    test('ayahsOnPage returns same-surah ayahs ascending', () {
      final res = locator.ayahsOnPage(1);
      expect(res, isA<Ok<List<AyahKey>>>());
      final ayahs = (res as Ok<List<AyahKey>>).value;
      expect(ayahs, isNotEmpty);
      expect(ayahs.every((k) => k.surah == 1), isTrue);
      for (var i = 1; i < ayahs.length; i++) {
        expect(ayahs[i].ayah, greaterThan(ayahs[i - 1].ayah));
      }
    });

    test('pageForSurah equals pageForAyah(surah, 1)', () {
      for (final surah in <int>[1, 2]) {
        final viaSurah = locator.pageForSurah(surah);
        final viaAyah = locator.pageForAyah(AyahKey(surah, 1));
        expect(viaSurah, isA<Ok<int>>());
        expect(viaAyah, isA<Ok<int>>());
        expect((viaSurah as Ok<int>).value, (viaAyah as Ok<int>).value);
      }
    });

    test('a continuation page reports its first ayah', () {
      final first = locator.firstAyahOnPage(3);
      expect(first, isA<Ok<AyahKey>>());
      expect((first as Ok<AyahKey>).value.surah, 2);
      expect(first.value.ayah, 4);
    });

    test('firstAyahOnPage rejects out-of-range pages with InvalidInput', () {
      for (final page in <int>[0, -1, 700]) {
        final res = locator.firstAyahOnPage(page);
        expect(res, isA<Err<AyahKey>>());
        expect((res as Err<AyahKey>).failure, isA<InvalidInputFailure>());
      }
    });

    test('ayahsOnPage rejects out-of-range pages with InvalidInput', () {
      for (final page in <int>[0, 700]) {
        final res = locator.ayahsOnPage(page);
        expect(res, isA<Err<List<AyahKey>>>());
        expect((res as Err<List<AyahKey>>).failure, isA<InvalidInputFailure>());
      }
    });

    test('pageForSurah rejects out-of-range surahs with InvalidInput', () {
      for (final surah in <int>[0, -1, 115, 999]) {
        final res = locator.pageForSurah(surah);
        expect(res, isA<Err<int>>());
        expect((res as Err<int>).failure, isA<InvalidInputFailure>());
      }
    });

    test('pageForAyah rejects a nonexistent ayah with InvalidInput', () {
      final res = locator.pageForAyah(AyahKey(1, 999));
      expect(res, isA<Err<int>>());
      expect((res as Err<int>).failure, isA<InvalidInputFailure>());
    });
  });

  group('TextOnlyMushafLocator', () {
    const fallback = TextOnlyMushafLocator();

    test('every method returns UnsupportedFailure', () {
      expect(
        (fallback.pageForAyah(AyahKey(1, 1)) as Err<int>).failure,
        isA<UnsupportedFailure>(),
      );
      expect(
        (fallback.firstAyahOnPage(1) as Err<AyahKey>).failure,
        isA<UnsupportedFailure>(),
      );
      expect(
        (fallback.ayahsOnPage(1) as Err<List<AyahKey>>).failure,
        isA<UnsupportedFailure>(),
      );
      expect(
        (fallback.pageForSurah(1) as Err<int>).failure,
        isA<UnsupportedFailure>(),
      );
    });
  });
}
