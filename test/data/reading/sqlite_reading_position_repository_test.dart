@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quran_mcp_server/quran_mcp_server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran_player/data/reading/sqlite_reading_position_repository.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late String dbPath;
  late Database db;
  late SqliteReadingPositionRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reading_pos_repo_test_');
    dbPath = p.join(tempDir.path, 'user.db');
    db = await openUserDb(absolutePath: dbPath);
    repo = SqliteReadingPositionRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('load returns null before any position is saved', () async {
    expect((await repo.load()).valueOrNull, isNull);
  });

  test('save then load round-trips the position', () async {
    await repo.save(AyahKey(18, 10));
    expect((await repo.load()).valueOrNull?.key, AyahKey(18, 10));
  });

  test('save keeps only the most recent position', () async {
    await repo.save(AyahKey(2, 255));
    await repo.save(AyahKey(36, 1));

    expect((await repo.load()).valueOrNull?.key, AyahKey(36, 1));
    final rows = await db.query('reading_position');
    expect(rows, hasLength(1));
  });

  test('the saved position survives reopening the database', () async {
    await repo.save(AyahKey(18, 10));
    await db.close();

    db = await openUserDb(absolutePath: dbPath);
    repo = SqliteReadingPositionRepository(db);

    expect((await repo.load()).valueOrNull?.key, AyahKey(18, 10));
  });
}
