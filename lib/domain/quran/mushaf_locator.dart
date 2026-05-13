import '../../core/error/result.dart';
import 'ayah_key.dart';

/// The standard Madani printed mushaf has exactly 604 pages.
const int kMushafPageCount = 604;

/// Maps between [AyahKey] coordinates and printed-mushaf page numbers.
///
/// The reader uses this to navigate between page mode (driven by a printed
/// mushaf renderer such as `qcf_quran_plus`) and text mode (driven by the
/// `QuranRepository`). Future audio, search, bookmark, and MCP changes drive
/// the reader to a position via this contract — they MUST NOT depend on the
/// rendering package directly.
abstract class MushafLocator {
  /// Page (1..[kMushafPageCount]) that contains [key].
  Result<int> pageForAyah(AyahKey key);

  /// First [AyahKey] on the given [page] (1..[kMushafPageCount]).
  Result<AyahKey> firstAyahOnPage(int page);

  /// All [AyahKey]s on the given [page] (1..[kMushafPageCount]), ordered
  /// canonically. Used by page-mode user actions that need to resolve the
  /// glyphs the user touched back into ayah text via the repository.
  Result<List<AyahKey>> ayahsOnPage(int page);

  /// Page that contains the first ayah of the given surah.
  ///
  /// Equivalent to [pageForAyah] called with `AyahKey(surahNumber, 1)`.
  Result<int> pageForSurah(int surahNumber);
}
