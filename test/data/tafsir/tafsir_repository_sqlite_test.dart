@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/data/tafsir/manifest.dart';
import 'package:quran_player/data/tafsir/tafsir_database.dart';
import 'package:quran_player/data/tafsir/tafsir_repository_sqlite.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

const _bundledDbPath = 'assets/tafsir/muyassar.sqlite';
const _bundledManifestPath = 'assets/tafsir/manifest.json';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late TafsirRepositorySqlite repo;
  late Directory tempDir;

  Future<void> setupReal() async {
    final manifestRaw = File(_bundledManifestPath).readAsStringSync();
    final manifest = parseTafsirManifest(manifestRaw).valueOrNull!;
    tempDir = await Directory.systemTemp.createTemp('tafsir_repo_test_');
    final dbPath = p.join(tempDir.path, 'muyassar.sqlite');
    File(
      dbPath,
    ).writeAsBytesSync(File(_bundledDbPath).readAsBytesSync(), flush: true);
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    repo = TafsirRepositorySqlite(
      database: TafsirDatabase(db, dbPath),
      manifest: manifest,
    );
  }

  group('TafsirRepositorySqlite (against real bundled DB)', () {
    setUp(() async => setupReal());
    tearDown(() async {
      await repo.database.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('getTafsirForAyah(2:255) returns non-empty tafsir', () async {
      final result = await repo.getTafsirForAyah(AyahKey(2, 255));
      expect(result.isOk, isTrue);
      final t = result.valueOrNull!;
      expect(t.key, equals(AyahKey(2, 255)));
      expect(t.text, isNotEmpty);
    });

    test('getTafsirForSurah(1) returns 7 entries ordered 1..7', () async {
      final result = await repo.getTafsirForSurah(1);
      expect(result.isOk, isTrue);
      final entries = result.valueOrNull!;
      expect(entries.length, 7);
      for (var i = 0; i < entries.length; i++) {
        expect(entries[i].key.surah, 1);
        expect(entries[i].key.ayah, i + 1);
      }
    });

    test('getTafsirForSurah(2) returns 286 entries', () async {
      final result = await repo.getTafsirForSurah(2);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.length, 286);
    });

    test('getTafsirForAyah(1:99) (out of range) returns NotFound', () async {
      // AyahKey allows 1:99 (only ayah > 0 is enforced); repo must say not-found.
      final result = await repo.getTafsirForAyah(AyahKey(1, 99));
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('getTafsirForSurah(115) returns NotFound', () async {
      final result = await repo.getTafsirForSurah(115);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('getSource() returns the manifest source', () async {
      final result = await repo.getSource();
      expect(result.isOk, isTrue);
      final source = result.valueOrNull!;
      expect(source.name, 'al-Muyassar');
      expect(
        source.publisher,
        'King Fahd Complex for the Printing of the Holy Quran',
      );
    });
  }, skip: _skipIfMissing());
}

bool _skipIfMissing() {
  final f = File(_bundledDbPath);
  return !(f.existsSync() && f.lengthSync() > 1000);
}
