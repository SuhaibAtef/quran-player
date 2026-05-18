import '../../core/error/result.dart';
import '../quran/ayah_key.dart';
import 'bookmark.dart';

/// Persistence contract for user bookmarks, backed by the `bookmark` table in
/// the user-writable `user.db`.
///
/// Kept framework-free so a future MCP bookmark-tools change can read through
/// this contract the way the MCP host adapters read through `QuranRepository`.
abstract class BookmarkRepository {
  /// All bookmarks, most recently added first.
  Future<Result<List<Bookmark>>> list();

  /// Adds a bookmark for [key] and returns it. Idempotent — bookmarking an
  /// ayah that is already bookmarked leaves the original entry intact and
  /// returns it unchanged.
  Future<Result<Bookmark>> add(AyahKey key);

  /// Removes the bookmark for [key]. Returns `true` when a bookmark was
  /// removed, `false` when [key] was not bookmarked.
  Future<Result<bool>> remove(AyahKey key);

  /// Whether [key] is currently bookmarked.
  Future<Result<bool>> isBookmarked(AyahKey key);
}
