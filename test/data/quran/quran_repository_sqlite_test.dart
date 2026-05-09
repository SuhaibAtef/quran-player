@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/quran_database.dart';
import 'package:quran_player/data/quran/quran_repository_sqlite.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

const _bundledDbPath = 'assets/quran/quran.sqlite';
const _bundledManifestPath = 'assets/quran/manifest.json';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late QuranRepositorySqlite repo;
  late Directory tempDir;

  Future<void> setupReal() async {
    final manifestRaw = File(_bundledManifestPath).readAsStringSync();
    final manifest = parseManifest(manifestRaw).valueOrNull!;
    tempDir = await Directory.systemTemp.createTemp('quran_repo_test_');
    final dbPath = p.join(tempDir.path, 'quran.sqlite');
    File(
      dbPath,
    ).writeAsBytesSync(File(_bundledDbPath).readAsBytesSync(), flush: true);
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    repo = QuranRepositorySqlite(
      database: QuranDatabase(db, dbPath),
      manifest: manifest,
    );
  }

  group('QuranRepositorySqlite (against real bundled DB)', () {
    setUp(() async => setupReal());
    tearDown(() async {
      await repo.database.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('listSurahs returns 114 ordered surahs', () async {
      final result = await repo.listSurahs();
      expect(result.isOk, isTrue);
      final surahs = result.valueOrNull!;
      expect(surahs.length, 114);
      for (var i = 0; i < surahs.length; i++) {
        expect(surahs[i].number, i + 1);
      }
    });

    test('getSurah(1) returns Al-Fatihah with 7 ayahs', () async {
      final result = await repo.getSurah(1);
      expect(result.isOk, isTrue);
      final s = result.valueOrNull!;
      expect(s.number, 1);
      expect(s.ayahCount, 7);
      expect(s.nameLatin.toLowerCase(), contains('faatih'));
    });

    test('getAyah(2:255) returns non-empty Ayat al-Kursi', () async {
      final result = await repo.getAyah(AyahKey(2, 255));
      expect(result.isOk, isTrue);
      final a = result.valueOrNull!;
      expect(a.text, isNotEmpty);
      expect(a.key, equals(AyahKey(2, 255)));
    });

    test('getSurahAyahs(1) returns 7 ayahs in order', () async {
      final result = await repo.getSurahAyahs(1);
      expect(result.isOk, isTrue);
      final ayahs = result.valueOrNull!;
      expect(ayahs.length, 7);
      for (var i = 0; i < ayahs.length; i++) {
        expect(ayahs[i].key.ayah, i + 1);
      }
    });

    test('getSurah(115) returns NotFoundFailure', () async {
      // AyahKey rejects out-of-range, but the repository is asked directly
      // for a number; it should return notFound rather than throw.
      final result = await repo.getSurah(115);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('getAyah(1:8) returns NotFoundFailure', () async {
      // AyahKey allows 1:8 (only ayah > 0 is enforced); repo must say not-found.
      final result = await repo.getAyah(AyahKey(1, 8));
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('getSource() returns the manifest source', () async {
      final result = await repo.getSource();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.name, 'Tanzil');
      expect(result.valueOrNull!.edition, 'Uthmani');
    });
  }, skip: _skipIfMissing());

  test('unknown surahs.revelation value surfaces as DataAccessFailure '
      '(no silent meccan coercion)', () async {
    final tmp = await Directory.systemTemp.createTemp('quran_repo_bad_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final dbPath = p.join(tmp.path, 'bad.sqlite');
    // Build a synthetic DB WITHOUT the CHECK constraint on revelation,
    // mirroring what a corrupted/tampered upstream might look like.
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    await db.execute(
      'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);',
    );
    await db.execute('''CREATE TABLE surahs (
          number INTEGER PRIMARY KEY, name_arabic TEXT NOT NULL,
          name_latin TEXT NOT NULL, revelation TEXT NOT NULL,
          ayah_count INTEGER NOT NULL);
      ''');
    await db.execute('''CREATE TABLE ayahs (
          surah INTEGER, ayah INTEGER, text TEXT NOT NULL,
          PRIMARY KEY(surah, ayah));
      ''');
    await db.insert('surahs', {
      'number': 1,
      'name_arabic': 'x',
      'name_latin': 'x',
      'revelation': 'martian', // bogus value
      'ayah_count': 1,
    });

    final manifestRaw = File(_bundledManifestPath).readAsStringSync();
    final manifest = parseManifest(manifestRaw).valueOrNull!;
    final badRepo = QuranRepositorySqlite(
      database: QuranDatabase(db, dbPath),
      manifest: manifest,
    );

    final result = await badRepo.getSurah(1);
    expect(result.failureOrNull, isA<DataAccessFailure>());
    expect(result.failureOrNull!.message, contains('getSurah'));
    // The original FormatException from _rowToSurah should surface as the
    // cause so reviewers can trace back to the bad value.
    expect(result.failureOrNull!.cause.toString(), contains('martian'));

    await db.close();
  }, skip: _skipIfMissing());
}

bool _skipIfMissing() {
  final f = File(_bundledDbPath);
  return !(f.existsSync() && f.lengthSync() > 1000);
}
