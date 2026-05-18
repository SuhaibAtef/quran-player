import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/user_db_provider.dart';
import '../../../core/error/result.dart';
import '../../../domain/bookmarks/bookmark.dart';
import '../../../domain/bookmarks/bookmark_repository.dart';
import '../../../domain/quran/ayah_key.dart';

/// The user's bookmarks, newest-first.
///
/// Resolves to an empty list when `user.db` is unavailable — callers that need
/// to distinguish "no bookmarks" from "storage down" read `userDbHealth`.
final bookmarksProvider =
    AsyncNotifierProvider<BookmarksController, List<Bookmark>>(
      BookmarksController.new,
    );

/// The set of currently-bookmarked ayahs — a cheap derived view the reader
/// watches to render its bookmark toggles without rebuilding on list order.
final bookmarkedKeysProvider = Provider<Set<AyahKey>>((ref) {
  final async = ref.watch(bookmarksProvider);
  return async.valueOrNull?.map((b) => b.key).toSet() ?? const {};
});

class BookmarksController extends AsyncNotifier<List<Bookmark>> {
  @override
  Future<List<Bookmark>> build() async {
    final repo = ref.watch(bookmarkRepositoryProvider);
    if (repo == null) return const [];
    final result = await repo.list();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(failure.message),
    };
  }

  /// Adds [key] when it is not bookmarked, removes it otherwise.
  Future<void> toggle(AyahKey key) async {
    final repo = ref.read(bookmarkRepositoryProvider);
    if (repo == null) return;
    final bookmarked = (state.valueOrNull ?? const <Bookmark>[]).any(
      (b) => b.key == key,
    );
    if (bookmarked) {
      await repo.remove(key);
    } else {
      await repo.add(key);
    }
    await _reload(repo);
  }

  /// Removes the bookmark for [key], if any.
  Future<void> remove(AyahKey key) async {
    final repo = ref.read(bookmarkRepositoryProvider);
    if (repo == null) return;
    await repo.remove(key);
    await _reload(repo);
  }

  Future<void> _reload(BookmarkRepository repo) async {
    final result = await repo.list();
    if (result case Ok(:final value)) {
      state = AsyncData(value);
    }
  }
}
