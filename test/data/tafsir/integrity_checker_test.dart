@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/data/quran/manifest.dart' as quran_manifest;
import 'package:quran_player/data/quran/quran_database.dart';
import 'package:quran_player/data/tafsir/integrity_checker.dart';
import 'package:quran_player/data/tafsir/manifest.dart';
import 'package:quran_player/data/tafsir/tafsir_database.dart';
import 'package:quran_player/domain/tafsir/tafsir_source.dart';

const _bundledQuranDbPath = 'assets/quran/quran.sqlite';
const _bundledQuranManifestPath = 'assets/quran/manifest.json';
const _bundledTafsirDbPath = 'assets/tafsir/muyassar.sqlite';
const _bundledTafsirManifestPath = 'assets/tafsir/manifest.json';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('verifies the unmodified bundled tafsir DB', () async {
    final ctx = await _ctx();
    final report = await verifyTafsirIntegrity(
      tafsirDatabase: ctx.tafsirDb,
      quranDatabase: ctx.quranDb,
      manifest: ctx.manifest,
      prefs: ctx.prefs,
    );
    expect(report.isOk, isTrue, reason: report.failureOrNull?.toString());
    expect(report.valueOrNull!.skippedHash, isFalse);
    await ctx.cleanup();
  }, skip: _skipIfMissing());

  test(
    'caches verified dbSha and skips re-hashing on the next call',
    () async {
      final ctx = await _ctx();
      final first = await verifyTafsirIntegrity(
        tafsirDatabase: ctx.tafsirDb,
        quranDatabase: ctx.quranDb,
        manifest: ctx.manifest,
        prefs: ctx.prefs,
      );
      expect(first.isOk, isTrue);

      final second = await verifyTafsirIntegrity(
        tafsirDatabase: ctx.tafsirDb,
        quranDatabase: ctx.quranDb,
        manifest: ctx.manifest,
        prefs: ctx.prefs,
      );
      expect(second.isOk, isTrue);
      expect(second.valueOrNull!.skippedHash, isTrue);
      await ctx.cleanup();
    },
    skip: _skipIfMissing(),
  );

  test('fails when the on-disk tafsir DB is tampered', () async {
    final ctx = await _ctx();
    // Mutate the on-disk file: append a byte.
    final path = ctx.tafsirDb.filePath;
    await ctx.tafsirDb.close();
    final f = File(path);
    f.writeAsBytesSync([...f.readAsBytesSync(), 0], flush: true);
    final reopened = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final tampered = TafsirDatabase(reopened, path);

    final report = await verifyTafsirIntegrity(
      tafsirDatabase: tampered,
      quranDatabase: ctx.quranDb,
      manifest: ctx.manifest,
      prefs: ctx.prefs,
    );
    expect(report.failureOrNull, isA<DataIntegrityFailure>());

    await reopened.close();
    await ctx.quranDb.close();
    if (ctx.tempDir.existsSync()) ctx.tempDir.deleteSync(recursive: true);
  }, skip: _skipIfMissing());

  test(
    'fails on row-count mismatch (synthetic tafsir DB with too few rows)',
    () async {
      final tmp = await Directory.systemTemp.createTemp('tafsir_int_test_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final tafsirPath = p.join(tmp.path, 'tiny.sqlite');
      final db = await databaseFactoryFfi.openDatabase(tafsirPath);
      await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);',
      );
      await db.execute('''CREATE TABLE tafsir (
          surah INTEGER, ayah INTEGER, text TEXT NOT NULL,
          PRIMARY KEY(surah, ayah));
      ''');
      await db.insert('meta', {'key': 'schema_version', 'value': '1'});
      await db.insert('tafsir', {'surah': 1, 'ayah': 1, 'text': 'x'});

      // Need a minimal Quran DB for the cross-check step.
      final quranPath = p.join(tmp.path, 'quran.sqlite');
      final quranDb = await databaseFactoryFfi.openDatabase(quranPath);
      await quranDb.execute('''CREATE TABLE ayahs (
          surah INTEGER, ayah INTEGER, text TEXT NOT NULL,
          PRIMARY KEY(surah, ayah));
      ''');
      await quranDb.insert('ayahs', {'surah': 1, 'ayah': 1, 'text': 'x'});

      final manifest = TafsirManifest(
        schemaVersion: 1,
        dataset: 'tafsir-muyassar',
        source: _stubSource,
        ayahCount: 6236,
        dbSha256: 'unused-because-structural-fails-first',
        textSha256: 'unused',
        fetchCommit: '',
        fetchEdition: '',
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final report = await verifyTafsirIntegrity(
        tafsirDatabase: TafsirDatabase(db, tafsirPath),
        quranDatabase: QuranDatabase(quranDb, quranPath),
        manifest: manifest,
        prefs: prefs,
      );
      expect(report.failureOrNull, isA<DataIntegrityFailure>());
      await db.close();
      await quranDb.close();
    },
  );

  test(
    'fails when tafsir references an ayah missing from the Quran DB',
    () async {
      final tmp = await Directory.systemTemp.createTemp('tafsir_int_test_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final tafsirPath = p.join(tmp.path, 'orphan.sqlite');
      final db = await databaseFactoryFfi.openDatabase(tafsirPath);
      await db.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);',
      );
      await db.execute('''CREATE TABLE tafsir (
          surah INTEGER, ayah INTEGER, text TEXT NOT NULL,
          PRIMARY KEY(surah, ayah));
      ''');
      await db.insert('meta', {'key': 'schema_version', 'value': '1'});
      // Insert 6,236 fake rows so the count check passes. One row points at
      // (1, 7000), which the Quran DB does not have — that's the orphan.
      await db.execute('BEGIN');
      await db.insert('tafsir', {'surah': 1, 'ayah': 7000, 'text': 'orphan'});
      for (var i = 1; i <= 6235; i++) {
        await db.insert('tafsir', {'surah': 1, 'ayah': i, 'text': 'x'});
      }
      await db.execute('COMMIT');

      // Quran DB with exactly (surah=1, ayah=1..6235). The tafsir row at
      // (1, 7000) has no Quran counterpart and must be flagged.
      final quranPath = p.join(tmp.path, 'quran.sqlite');
      final quranDb = await databaseFactoryFfi.openDatabase(quranPath);
      await quranDb.execute('''CREATE TABLE ayahs (
          surah INTEGER, ayah INTEGER, text TEXT NOT NULL,
          PRIMARY KEY(surah, ayah));
      ''');
      await quranDb.execute('BEGIN');
      for (var i = 1; i <= 6235; i++) {
        await quranDb.insert('ayahs', {'surah': 1, 'ayah': i, 'text': 'x'});
      }
      await quranDb.execute('COMMIT');

      final manifest = TafsirManifest(
        schemaVersion: 1,
        dataset: 'tafsir-muyassar',
        source: _stubSource,
        ayahCount: 6236,
        dbSha256: 'unused',
        textSha256: 'unused',
        fetchCommit: '',
        fetchEdition: '',
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final report = await verifyTafsirIntegrity(
        tafsirDatabase: TafsirDatabase(db, tafsirPath),
        quranDatabase: QuranDatabase(quranDb, quranPath),
        manifest: manifest,
        prefs: prefs,
      );
      expect(report.failureOrNull, isA<DataIntegrityFailure>());
      expect(
        (report.failureOrNull! as DataIntegrityFailure).message,
        contains('1:7000'),
      );

      await db.close();
      await quranDb.close();
    },
  );
}

class _Ctx {
  _Ctx({
    required this.tafsirDb,
    required this.quranDb,
    required this.manifest,
    required this.prefs,
    required this.tempDir,
  });

  final TafsirDatabase tafsirDb;
  final QuranDatabase quranDb;
  final TafsirManifest manifest;
  final SharedPreferences prefs;
  final Directory tempDir;

  Future<void> cleanup() async {
    await tafsirDb.close();
    await quranDb.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  }
}

Future<_Ctx> _ctx() async {
  final tafsirManifestRaw = File(_bundledTafsirManifestPath).readAsStringSync();
  final manifest = parseTafsirManifest(tafsirManifestRaw).valueOrNull!;
  // Drain the Quran manifest just to confirm the test fixtures are sane.
  final quranManifestRaw = File(_bundledQuranManifestPath).readAsStringSync();
  expect(
    quran_manifest.parseManifest(quranManifestRaw).isOk,
    isTrue,
    reason: 'bundled Quran manifest must parse for this test',
  );

  final tmp = await Directory.systemTemp.createTemp('tafsir_int_test_');
  final tafsirCopy = File(p.join(tmp.path, 'muyassar.sqlite'))
    ..writeAsBytesSync(
      File(_bundledTafsirDbPath).readAsBytesSync(),
      flush: true,
    );
  final quranCopy = File(
    p.join(tmp.path, 'quran.sqlite'),
  )..writeAsBytesSync(File(_bundledQuranDbPath).readAsBytesSync(), flush: true);

  final tafsirDb = await databaseFactoryFfi.openDatabase(
    tafsirCopy.path,
    options: OpenDatabaseOptions(readOnly: true),
  );
  final quranDb = await databaseFactoryFfi.openDatabase(
    quranCopy.path,
    options: OpenDatabaseOptions(readOnly: true),
  );
  final prefs = await SharedPreferences.getInstance();

  return _Ctx(
    tafsirDb: TafsirDatabase(tafsirDb, tafsirCopy.path),
    quranDb: QuranDatabase(quranDb, quranCopy.path),
    manifest: manifest,
    prefs: prefs,
    tempDir: tmp,
  );
}

bool _skipIfMissing() {
  final t = File(_bundledTafsirDbPath);
  final q = File(_bundledQuranDbPath);
  return !(t.existsSync() &&
      t.lengthSync() > 1000 &&
      q.existsSync() &&
      q.lengthSync() > 1000);
}

final TafsirSource _stubSource = TafsirSource(
  name: 'Stub',
  publisher: 'Stub Publisher',
  version: 'Stub v0',
  url: 'https://example.invalid/',
  license: 'Stub license',
  retrievedAtUtc: DateTime.utc(2026, 1, 1),
);
