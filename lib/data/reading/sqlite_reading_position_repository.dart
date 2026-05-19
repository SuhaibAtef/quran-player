import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/reading/reading_position.dart';
import '../../domain/reading/reading_position_repository.dart';

/// [ReadingPositionRepository] backed by the single-row `reading_position`
/// table in the user-writable `user.db` (schema v2). Operates on the
/// already-opened [Database] that `openUserDb` returns.
class SqliteReadingPositionRepository implements ReadingPositionRepository {
  SqliteReadingPositionRepository(this._db);

  final Database _db;

  static const _table = 'reading_position';

  /// The `reading_position` table holds exactly one row, always at `id = 1`.
  static const _rowId = 1;

  @override
  Future<Result<ReadingPosition?>> load() async {
    try {
      final rows = await _db.query(
        _table,
        where: 'id = ?',
        whereArgs: [_rowId],
        limit: 1,
      );
      if (rows.isEmpty) return const Result.ok(null);
      return Result.ok(_rowToPosition(rows.first));
    } catch (e, st) {
      return Result.err(_dbErr('load reading position failed: $e', e, st));
    }
  }

  @override
  Future<Result<ReadingPosition>> save(AyahKey key) async {
    try {
      final now = DateTime.now().toUtc();
      // Upsert on the fixed row id so only the most recent position is kept.
      await _db.insert(_table, {
        'id': _rowId,
        'surah': key.surah,
        'ayah': key.ayah,
        'updated_at_utc': now.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return Result.ok(ReadingPosition(key: key, updatedAt: now));
    } catch (e, st) {
      return Result.err(_dbErr('save reading position $key failed: $e', e, st));
    }
  }

  ReadingPosition _rowToPosition(Map<String, Object?> row) {
    return ReadingPosition(
      key: AyahKey(row['surah'] as int, row['ayah'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at_utc'] as int,
        isUtc: true,
      ),
    );
  }
}

DataAccessFailure _dbErr(String message, Object cause, StackTrace st) =>
    DataAccessFailure(message, cause: cause, stackTrace: st);
