import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/bookmarks/bookmark.dart';
import '../../domain/bookmarks/bookmark_repository.dart';
import '../../domain/quran/ayah_key.dart';

/// [BookmarkRepository] backed by the `bookmark` table in the user-writable
/// `user.db` (schema v2). Operates on the already-opened [Database] that
/// `openUserDb` returns.
class SqliteBookmarkRepository implements BookmarkRepository {
  SqliteBookmarkRepository(this._db);

  final Database _db;

  static const _table = 'bookmark';

  @override
  Future<Result<List<Bookmark>>> list() async {
    try {
      final rows = await _db.query(
        _table,
        orderBy: 'created_at_utc DESC, id DESC',
      );
      return Result.ok(rows.map(_rowToBookmark).toList(growable: false));
    } catch (e, st) {
      return Result.err(_dbErr('list bookmarks failed: $e', e, st));
    }
  }

  @override
  Future<Result<Bookmark>> add(AyahKey key) async {
    try {
      // ON CONFLICT IGNORE makes a repeat add a no-op against UNIQUE(surah,
      // ayah); the row is then read back so the caller always gets the
      // canonical persisted bookmark.
      await _db.insert(_table, {
        'surah': key.surah,
        'ayah': key.ayah,
        'created_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final rows = await _db.query(
        _table,
        where: 'surah = ? AND ayah = ?',
        whereArgs: [key.surah, key.ayah],
        limit: 1,
      );
      if (rows.isEmpty) {
        return Result.err(
          DataAccessFailure('bookmark missing after add: $key'),
        );
      }
      return Result.ok(_rowToBookmark(rows.first));
    } catch (e, st) {
      return Result.err(_dbErr('add bookmark $key failed: $e', e, st));
    }
  }

  @override
  Future<Result<bool>> remove(AyahKey key) async {
    try {
      final count = await _db.delete(
        _table,
        where: 'surah = ? AND ayah = ?',
        whereArgs: [key.surah, key.ayah],
      );
      return Result.ok(count > 0);
    } catch (e, st) {
      return Result.err(_dbErr('remove bookmark $key failed: $e', e, st));
    }
  }

  @override
  Future<Result<bool>> isBookmarked(AyahKey key) async {
    try {
      final rows = await _db.query(
        _table,
        columns: ['id'],
        where: 'surah = ? AND ayah = ?',
        whereArgs: [key.surah, key.ayah],
        limit: 1,
      );
      return Result.ok(rows.isNotEmpty);
    } catch (e, st) {
      return Result.err(_dbErr('isBookmarked $key failed: $e', e, st));
    }
  }

  Bookmark _rowToBookmark(Map<String, Object?> row) {
    return Bookmark(
      id: row['id'] as int?,
      key: AyahKey(row['surah'] as int, row['ayah'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at_utc'] as int,
        isUtc: true,
      ),
    );
  }
}

DataAccessFailure _dbErr(String message, Object cause, StackTrace st) =>
    DataAccessFailure(message, cause: cause, stackTrace: st);
