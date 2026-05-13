// SOLE allowed import of `package:qcf_quran_plus/` in the project.
// Every other layer drives the printed-mushaf coordinate system through the
// framework-free `MushafLocator` contract in `lib/domain/quran/`.
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/logger.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/mushaf_locator.dart';

/// `qcf_quran_plus`-backed [MushafLocator].
///
/// Builds an in-memory `(page → ayahs)` and `(ayah → page)` map at
/// construction time by walking the package's static `pageData`. After
/// construction, every method is O(1) (or O(n) in the number of ayahs on a
/// page, which is small).
class QcfMushafLocator implements MushafLocator {
  QcfMushafLocator._(this._pageToAyahs, this._ayahToPage);

  /// Initialises a [QcfMushafLocator] by precomputing the page lookups.
  ///
  /// Returns [DataAccessFailure] if the precompute throws (the package's data
  /// constants somehow malformed) or [DataIntegrityFailure] if it produces a
  /// page count other than [kMushafPageCount] / total ayah count other than
  /// 6,236 — those are ground-truth invariants of the printed Madani mushaf.
  static Result<QcfMushafLocator> create() {
    try {
      final pageToAyahs = <int, List<AyahKey>>{};
      final ayahToPage = <AyahKey, int>{};

      final pageData = qcf.pageData;
      if (pageData.length != kMushafPageCount) {
        return Result.err(
          DataIntegrityFailure(
            'qcf_quran_plus pageData has ${pageData.length} pages '
            '(expected $kMushafPageCount)',
          ),
        );
      }

      for (var pageIndex = 0; pageIndex < pageData.length; pageIndex++) {
        final pageNumber = pageIndex + 1;
        final entries = pageData[pageIndex] as List;
        final ayahs = <AyahKey>[];
        for (final raw in entries) {
          final entry = raw as Map;
          final surah = entry['surah'] as int;
          final start = entry['start'] as int;
          final end = entry['end'] as int;
          for (var ayah = start; ayah <= end; ayah++) {
            final keyResult = AyahKey.tryNew(surah, ayah);
            if (keyResult is Err<AyahKey>) {
              return Result.err(
                DataIntegrityFailure(
                  'qcf_quran_plus emitted invalid coords '
                  '($surah:$ayah) on page $pageNumber',
                ),
              );
            }
            final key = (keyResult as Ok<AyahKey>).value;
            ayahs.add(key);
            ayahToPage[key] = pageNumber;
          }
        }
        pageToAyahs[pageNumber] = ayahs;
      }

      if (ayahToPage.length != qcf.totalVerseCount) {
        return Result.err(
          DataIntegrityFailure(
            'qcf_quran_plus precompute produced ${ayahToPage.length} ayahs '
            '(expected ${qcf.totalVerseCount})',
          ),
        );
      }

      return Result.ok(QcfMushafLocator._(pageToAyahs, ayahToPage));
    } catch (e, st) {
      appLogger.severe('QcfMushafLocator init threw: $e');
      return Result.err(
        DataAccessFailure(
          'qcf_quran_plus precompute failed',
          cause: e,
          stackTrace: st,
        ),
      );
    }
  }

  final Map<int, List<AyahKey>> _pageToAyahs;
  final Map<AyahKey, int> _ayahToPage;

  @override
  Result<int> pageForAyah(AyahKey key) {
    final page = _ayahToPage[key];
    if (page == null) {
      return Result.err(InvalidInputFailure('no page for ayah $key'));
    }
    return Result.ok(page);
  }

  @override
  Result<AyahKey> firstAyahOnPage(int page) {
    if (page < 1 || page > kMushafPageCount) {
      return Result.err(InvalidInputFailure('page out of range: $page'));
    }
    final ayahs = _pageToAyahs[page];
    if (ayahs == null || ayahs.isEmpty) {
      return Result.err(DataIntegrityFailure('page $page is empty'));
    }
    return Result.ok(ayahs.first);
  }

  @override
  Result<List<AyahKey>> ayahsOnPage(int page) {
    if (page < 1 || page > kMushafPageCount) {
      return Result.err(InvalidInputFailure('page out of range: $page'));
    }
    final ayahs = _pageToAyahs[page];
    if (ayahs == null || ayahs.isEmpty) {
      return Result.err(DataIntegrityFailure('page $page is empty'));
    }
    // Defensive copy: callers should not be able to mutate the cached list.
    return Result.ok(List<AyahKey>.unmodifiable(ayahs));
  }

  @override
  Result<int> pageForSurah(int surahNumber) {
    final keyResult = AyahKey.tryNew(surahNumber, 1);
    if (keyResult is Err<AyahKey>) {
      return Result.err(keyResult.failure);
    }
    return pageForAyah((keyResult as Ok<AyahKey>).value);
  }
}

/// No-op locator used when the rendering package fails to initialise. Every
/// call returns [UnsupportedFailure] so callers fold to text-mode rendering
/// without ever throwing across the boundary.
class TextOnlyMushafLocator implements MushafLocator {
  const TextOnlyMushafLocator();

  static const _failure = UnsupportedFailure(
    'mushaf rendering unavailable (text-only fallback)',
  );

  @override
  Result<int> pageForAyah(AyahKey key) => Result.err(_failure);

  @override
  Result<AyahKey> firstAyahOnPage(int page) => Result.err(_failure);

  @override
  Result<List<AyahKey>> ayahsOnPage(int page) => Result.err(_failure);

  @override
  Result<int> pageForSurah(int surahNumber) => Result.err(_failure);
}
