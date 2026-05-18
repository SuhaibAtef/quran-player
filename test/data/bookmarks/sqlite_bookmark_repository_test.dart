@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quran_mcp_server/quran_mcp_server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:quran_player/data/bookmarks/sqlite_bookmark_repository.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late String dbPath;
  late Database db;
  late SqliteBookmarkRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bookmark_repo_test_');
    dbPath = p.join(tempDir.path, 'user.db');
    db = await openUserDb(absolutePath: dbPath);
    repo = SqliteBookmarkRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('add then list round-trips a bookmark', () async {
    final added = await repo.add(AyahKey(2, 255));
    expect(added.valueOrNull?.key, AyahKey(2, 255));

    final list = await repo.list();
    expect(list.valueOrNull, hasLength(1));
    expect(list.valueOrNull!.single.key, AyahKey(2, 255));
  });

  test('add is idempotent on the unique (surah, ayah) key', () async {
    final first = await repo.add(AyahKey(2, 255));
    final second = await repo.add(AyahKey(2, 255));

    expect(second.valueOrNull?.id, first.valueOrNull?.id);
    expect((await repo.list()).valueOrNull, hasLength(1));
  });

  test('list orders bookmarks newest-first', () async {
    await repo.add(AyahKey(1, 1));
    await repo.add(AyahKey(18, 10));

    final keys = (await repo.list()).valueOrNull!
        .map((b) => b.key)
        .toList(growable: false);
    expect(keys, [AyahKey(18, 10), AyahKey(1, 1)]);
  });

  test('isBookmarked reflects whether the ayah is saved', () async {
    expect((await repo.isBookmarked(AyahKey(2, 255))).valueOrNull, isFalse);
    await repo.add(AyahKey(2, 255));
    expect((await repo.isBookmarked(AyahKey(2, 255))).valueOrNull, isTrue);
  });

  test('remove deletes a saved bookmark and reports it', () async {
    await repo.add(AyahKey(2, 255));
    final removed = await repo.remove(AyahKey(2, 255));

    expect(removed.valueOrNull, isTrue);
    expect((await repo.list()).valueOrNull, isEmpty);
  });

  test('remove of a non-bookmarked ayah reports false', () async {
    final removed = await repo.remove(AyahKey(2, 255));
    expect(removed.valueOrNull, isFalse);
  });

  test('bookmarks survive reopening the database', () async {
    await repo.add(AyahKey(2, 255));
    await db.close();

    db = await openUserDb(absolutePath: dbPath);
    repo = SqliteBookmarkRepository(db);

    expect((await repo.list()).valueOrNull, hasLength(1));
  });
}
