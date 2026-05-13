import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/quran/ayah.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/quran_repository.dart';
import '../../domain/quran/quran_source.dart';
import '../../domain/quran/quran_search_result.dart';
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
  Future<Result<List<QuranSearchResult>>> searchAyahs(
    String query, {
    int limit = 50,
  }) async {
    final normalized = _normalizeSearchQuery(query);
    if (normalized.isEmpty) {
      return const Result.err(InvalidInputFailure('search query is empty'));
    }
    final normalizedArabic = _normalizeArabicForSearch(normalized);
    if (normalizedArabic.isEmpty) {
      return const Result.err(InvalidInputFailure('search query is empty'));
    }
    if (limit < 1 || limit > 100) {
      return Result.err(
        InvalidInputFailure('search limit must be between 1 and 100'),
      );
    }

    try {
      final rows = await _db.rawQuery(
        '''
        SELECT
          a.surah,
          a.ayah,
          a.text,
          s.name_arabic,
          s.name_latin
        FROM ayah_fts f
        JOIN ayahs a ON a.rowid = f.rowid
        JOIN surahs s ON s.number = a.surah
        WHERE ayah_fts MATCH ?
        ORDER BY bm25(ayah_fts), a.surah, a.ayah
        ''',
        [_toFtsExpression(normalizedArabic)],
      );
      final results = <QuranSearchResult>[];
      for (final row in rows) {
        final text = row['text'] as String;
        if (!_normalizeArabicForSearch(text).contains(normalizedArabic)) {
          continue;
        }
        results.add(_rowToSearchResult(row));
        if (results.length >= limit) break;
      }
      return Result.ok(results);
    } catch (e, st) {
      return Result.err(_dbErr('searchAyahs failed: $e', e, st));
    }
  }

  @override
  Future<Result<QuranSource>> getSource() async {
    return Result.ok(manifest.source);
  }
}

Surah _rowToSurah(Map<String, Object?> row) {
  final rawRevelation = row['revelation'] as String;
  final revelation = switch (rawRevelation) {
    'meccan' => Revelation.meccan,
    'medinan' => Revelation.medinan,
    // The schema has CHECK(revelation IN ('meccan','medinan')); reaching this
    // arm means the DB was tampered with or the constraint was dropped. Fail
    // loudly — the repository's try/catch wraps this as DataAccessFailure
    // for the caller.
    _ => throw FormatException(
      'invalid surahs.revelation value for surah ${row['number']}: '
      '"$rawRevelation"',
    ),
  };
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

QuranSearchResult _rowToSearchResult(Map<String, Object?> row) {
  return QuranSearchResult(
    key: AyahKey(row['surah'] as int, row['ayah'] as int),
    text: row['text'] as String,
    surahNameArabic: row['name_arabic'] as String,
    surahNameLatin: row['name_latin'] as String,
  );
}

String _normalizeSearchQuery(String query) {
  return query.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizeArabicForSearch(String input) {
  final withoutMarks = input
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ـ', ' ');
  final lettersOnly = withoutMarks.replaceAll(
    RegExp(r'[^\u0621-\u064A\u0660-\u0669\u06F0-\u06F9 ]'),
    ' ',
  );
  return lettersOnly.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _toFtsExpression(String normalizedArabic) {
  final terms = normalizedArabic
      .replaceAll(' ', '')
      .runes
      .map((r) => String.fromCharCode(r))
      .toSet()
      .toList(growable: false);
  return terms.join(' ');
}

DataAccessFailure _dbErr(String message, Object cause, StackTrace st) =>
    DataAccessFailure(message, cause: cause, stackTrace: st);
