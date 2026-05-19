import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/tafsir/tafsir.dart';
import '../../domain/tafsir/tafsir_repository.dart';
import '../../domain/tafsir/tafsir_source.dart';
import 'manifest.dart';
import 'tafsir_database.dart';

class TafsirRepositorySqlite implements TafsirRepository {
  TafsirRepositorySqlite({required this.database, required this.manifest});

  final TafsirDatabase database;
  final TafsirManifest manifest;

  Database get _db => database.db;

  @override
  Future<Result<Tafsir>> getTafsirForAyah(AyahKey key) async {
    try {
      final rows = await _db.rawQuery(
        'SELECT surah, ayah, text FROM tafsir WHERE surah = ? AND ayah = ? LIMIT 1',
        [key.surah, key.ayah],
      );
      if (rows.isEmpty) {
        return Result.err(
          NotFoundFailure('tafsir not found: $key', key: '$key'),
        );
      }
      return Result.ok(_rowToTafsir(rows.first));
    } catch (e, st) {
      return Result.err(_dbErr('getTafsirForAyah($key) failed: $e', e, st));
    }
  }

  @override
  Future<Result<List<Tafsir>>> getTafsirForSurah(int number) async {
    if (number < 1 || number > 114) {
      return Result.err(
        NotFoundFailure(
          'tafsir not found for surah $number',
          key: 'surah=$number',
        ),
      );
    }
    try {
      final rows = await _db.rawQuery(
        'SELECT surah, ayah, text FROM tafsir WHERE surah = ? ORDER BY ayah',
        [number],
      );
      if (rows.isEmpty) {
        return Result.err(
          NotFoundFailure(
            'no tafsir entries for surah $number',
            key: 'surah=$number',
          ),
        );
      }
      return Result.ok(rows.map(_rowToTafsir).toList(growable: false));
    } catch (e, st) {
      return Result.err(_dbErr('getTafsirForSurah($number) failed: $e', e, st));
    }
  }

  @override
  Future<Result<TafsirSource>> getSource() async {
    return Result.ok(manifest.source);
  }
}

Tafsir _rowToTafsir(Map<String, Object?> row) {
  return Tafsir(
    key: AyahKey(row['surah'] as int, row['ayah'] as int),
    text: row['text'] as String,
  );
}

DataAccessFailure _dbErr(String message, Object cause, StackTrace st) =>
    DataAccessFailure(message, cause: cause, stackTrace: st);
