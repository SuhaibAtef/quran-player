@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/data/quran/integrity_checker.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/quran_database.dart';
import 'package:quran_player/domain/quran/quran_source.dart';

const _bundledDbPath = 'assets/quran/quran.sqlite';
const _bundledManifestPath = 'assets/quran/manifest.json';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('verifies the unmodified bundled DB', () async {
    final ctx = await _ctx();
    final report = await verifyQuranIntegrity(
      database: ctx.database,
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
      final first = await verifyQuranIntegrity(
        database: ctx.database,
        manifest: ctx.manifest,
        prefs: ctx.prefs,
      );
      expect(first.isOk, isTrue);

      final second = await verifyQuranIntegrity(
        database: ctx.database,
        manifest: ctx.manifest,
        prefs: ctx.prefs,
      );
      expect(second.isOk, isTrue);
      expect(second.valueOrNull!.skippedHash, isTrue);
      await ctx.cleanup();
    },
    skip: _skipIfMissing(),
  );

  test(
    'cache invalidates when the on-disk file mtime changes',
    () async {
      final ctx = await _ctx();
      final first = await verifyQuranIntegrity(
        database: ctx.database,
        manifest: ctx.manifest,
        prefs: ctx.prefs,
      );
      expect(first.isOk, isTrue);
      expect(first.valueOrNull!.skippedHash, isFalse);

      // Bump the file's mtime forward without changing its bytes. The cache
      // must invalidate and force a fresh SHA pass.
      final path = ctx.database.filePath;
      final stat = FileStat.statSync(path);
      final bumped = stat.modified.add(const Duration(seconds: 5));
      File(path).setLastModifiedSync(bumped);

      final second = await verifyQuranIntegrity(
        database: ctx.database,
        manifest: ctx.manifest,
        prefs: ctx.prefs,
      );
      expect(second.isOk, isTrue);
      expect(
        second.valueOrNull!.skippedHash,
        isFalse,
        reason: 'mtime drift must force a re-hash',
      );
      await ctx.cleanup();
    },
    skip: _skipIfMissing(),
  );

  test('fails when the on-disk DB is tampered', () async {
    final ctx = await _ctx();
    // Mutate the on-disk file: append a byte. The connection has to be
    // closed before Windows lets us rewrite.
    final path = ctx.database.filePath;
    await ctx.database.close();
    final f = File(path);
    f.writeAsBytesSync([...f.readAsBytesSync(), 0], flush: true);
    final reopened = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final tampered = QuranDatabase(reopened, path);

    final report = await verifyQuranIntegrity(
      database: tampered,
      manifest: ctx.manifest,
      prefs: ctx.prefs,
    );
    expect(report.failureOrNull, isA<DataIntegrityFailure>());

    await reopened.close();
    if (ctx.tempDir.existsSync()) ctx.tempDir.deleteSync(recursive: true);
  }, skip: _skipIfMissing());

  test('fails on count mismatch (synthetic tiny DB)', () async {
    final tmp = await Directory.systemTemp.createTemp('quran_int_test_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final dbPath = p.join(tmp.path, 'tiny.sqlite');
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    await db.execute(
      '''CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);''',
    );
    await db.execute('''CREATE TABLE surahs (
        number INTEGER PRIMARY KEY, name_arabic TEXT NOT NULL,
        name_latin TEXT NOT NULL, revelation TEXT NOT NULL, ayah_count INTEGER NOT NULL);
    ''');
    await db.execute('''CREATE TABLE ayahs (
        surah INTEGER, ayah INTEGER, text TEXT NOT NULL,
        PRIMARY KEY(surah, ayah));
    ''');
    await db.insert('meta', {'key': 'schema_version', 'value': '1'});
    await db.insert('surahs', {
      'number': 1,
      'name_arabic': 'x',
      'name_latin': 'x',
      'revelation': 'meccan',
      'ayah_count': 1,
    });
    await db.insert('ayahs', {'surah': 1, 'ayah': 1, 'text': 'x'});

    final database = QuranDatabase(db, dbPath);

    final manifest = QuranManifest(
      schemaVersion: 1,
      source: _stubSource,
      surahCount: 114,
      ayahCount: 6236,
      dbSha256: 'unused-because-structural-fails-first',
      textSha256: 'unused',
      fetchUrl: '',
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final report = await verifyQuranIntegrity(
      database: database,
      manifest: manifest,
      prefs: prefs,
    );
    expect(report.failureOrNull, isA<DataIntegrityFailure>());
    await db.close();
  });
}

class _Ctx {
  _Ctx({
    required this.database,
    required this.manifest,
    required this.prefs,
    required this.tempDir,
  });

  final QuranDatabase database;
  final QuranManifest manifest;
  final SharedPreferences prefs;
  final Directory tempDir;

  Future<void> cleanup() async {
    await database.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  }
}

Future<_Ctx> _ctx() async {
  final manifestRaw = File(_bundledManifestPath).readAsStringSync();
  final manifest = parseManifest(manifestRaw).valueOrNull!;

  final tmp = await Directory.systemTemp.createTemp('quran_int_test_');
  final dbCopy = File(p.join(tmp.path, 'quran.sqlite'));
  dbCopy.writeAsBytesSync(File(_bundledDbPath).readAsBytesSync(), flush: true);

  final db = await databaseFactoryFfi.openDatabase(
    dbCopy.path,
    options: OpenDatabaseOptions(readOnly: true),
  );
  final prefs = await SharedPreferences.getInstance();

  return _Ctx(
    database: QuranDatabase(db, dbCopy.path),
    manifest: manifest,
    prefs: prefs,
    tempDir: tmp,
  );
}

bool _skipIfMissing() {
  final f = File(_bundledDbPath);
  return !(f.existsSync() && f.lengthSync() > 1000);
}

final QuranSource _stubSource = QuranSource(
  name: 'Stub',
  edition: 'Stub',
  version: '0',
  url: '',
  license: '',
  retrievedAtUtc: DateTime.utc(2026, 1, 1),
);
