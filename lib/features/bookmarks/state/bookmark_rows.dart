import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../data/quran/providers.dart';
import '../../../domain/bookmarks/bookmark.dart';
import '../../../domain/quran/ayah.dart';
import '../../../domain/quran/ayah_key.dart';
import '../../../domain/quran/surah.dart';
import 'bookmarks_controller.dart';

/// A bookmark enriched with the surah name and canonical ayah text needed to
/// render a Bookmarks list row.
///
/// Text and names come straight from `QuranRepository` — the Bookmarks page
/// never invents references or displays text from outside the verified Quran
/// database.
class BookmarkRow {
  const BookmarkRow({
    required this.key,
    required this.surahName,
    required this.ayahText,
  });

  final AyahKey key;
  final String surahName;
  final String ayahText;
}

/// Resolves the [bookmarksProvider] list into display rows, newest-first.
/// Rebuilds whenever the bookmark set changes.
final bookmarkRowsProvider = FutureProvider<List<BookmarkRow>>((ref) async {
  final bookmarks =
      ref.watch(bookmarksProvider).valueOrNull ?? const <Bookmark>[];
  if (bookmarks.isEmpty) return const [];

  final repo = ref.watch(quranRepositoryProvider);
  final surahsResult = await repo.listSurahs();
  if (surahsResult is! Ok<List<Surah>>) {
    final failure = (surahsResult as Err<List<Surah>>).failure;
    throw StateError('could not load surah names: ${failure.message}');
  }
  final surahsByNumber = {
    for (final surah in surahsResult.value) surah.number: surah,
  };

  final rows = <BookmarkRow>[];
  for (final bookmark in bookmarks) {
    final ayahResult = await repo.getAyah(bookmark.key);
    final surah = surahsByNumber[bookmark.key.surah];
    // A bookmark whose ayah can no longer be resolved is silently skipped
    // rather than rendered as a broken row.
    if (ayahResult is Ok<Ayah> && surah != null) {
      rows.add(
        BookmarkRow(
          key: bookmark.key,
          surahName: surah.nameLatin,
          ayahText: ayahResult.value.text,
        ),
      );
    }
  }
  return rows;
});
