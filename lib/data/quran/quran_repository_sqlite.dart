import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/quran/ayah.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/quran_repository.dart';
import '../../domain/quran/quran_source.dart';
import '../../domain/quran/surah.dart';
import 'manifest.dart';
import 'quran_database.dart';

class QuranRepositorySqlite implements QuranRepository {
  QuranRepositorySqlite({required this.database, required this.manifest});

  final QuranDatabase database;
  final QuranManifest manifest;

  Database get _db => database.db;

  @override
  Future<Result<List<Surah>>> listSurahs() async {
    try {
      final rows = await _db.rawQuery(
        'SELECT number, name_arabic, name_latin, revelation, ayah_count '
        'FROM surahs ORDER BY number',
      );
      return Result.ok(rows.map(_rowToSurah).toList(growable: false));
    } catch (e, st) {
      return Result.err(_dbErr('listSurahs failed: $e', e, st));
    }
  }

  @override
  Future<Result<Surah>> getSurah(int number) async {
    try {
      final rows = await _db.rawQuery(
        'SELECT number, name_arabic, name_latin, revelation, ayah_count '
        'FROM surahs WHERE number = ? LIMIT 1',
        [number],
      );
      if (rows.isEmpty) {
        return Result.err(
          NotFoundFailure('surah not found: $number', key: 'surah=$number'),
        );
      }
      return Result.ok(_rowToSurah(rows.first));
    } catch (e, st) {
      return Result.err(_dbErr('getSurah($number) failed: $e', e, st));
    }
  }

  @override
  Future<Result<List<Ayah>>> getSurahAyahs(int number) async {
    try {
      final rows = await _db.rawQuery(
        'SELECT surah, ayah, text FROM ayahs WHERE surah = ? ORDER BY ayah',
        [number],
      );
      if (rows.isEmpty) {
        return Result.err(
          NotFoundFailure('no ayahs for surah $number', key: 'surah=$number'),
        );
      }
      return Result.ok(rows.map(_rowToAyah).toList(growable: false));
    } catch (e, st) {
      return Result.err(_dbErr('getSurahAyahs($number) failed: $e', e, st));
    }
  }

  @override
  Future<Result<Ayah>> getAyah(AyahKey key) async {
    try {
      final rows = await _db.rawQuery(
        'SELECT surah, ayah, text FROM ayahs WHERE surah = ? AND ayah = ? LIMIT 1',
        [key.surah, key.ayah],
      );
      if (rows.isEmpty) {
        return Result.err(NotFoundFailure('ayah not found: $key', key: '$key'));
      }
      return Result.ok(_rowToAyah(rows.first));
    } catch (e, st) {
      return Result.err(_dbErr('getAyah($key) failed: $e', e, st));
    }
  }

  @override
  Future<Result<QuranSource>> getSource() async {
    return Result.ok(manifest.source);
  }
}

Surah _rowToSurah(Map<String, Object?> row) {
  final revelation = (row['revelation'] as String) == 'medinan'
      ? Revelation.medinan
      : Revelation.meccan;
  return Surah(
    number: row['number'] as int,
    nameArabic: row['name_arabic'] as String,
    nameLatin: row['name_latin'] as String,
    revelation: revelation,
    ayahCount: row['ayah_count'] as int,
  );
}

Ayah _rowToAyah(Map<String, Object?> row) {
  return Ayah(
    key: AyahKey(row['surah'] as int, row['ayah'] as int),
    text: row['text'] as String,
  );
}

DataAccessFailure _dbErr(String message, Object cause, StackTrace st) =>
    DataAccessFailure(message, cause: cause, stackTrace: st);
