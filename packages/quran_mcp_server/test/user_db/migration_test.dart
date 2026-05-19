@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quran_mcp_server/src/user_db/user_db.dart';
import 'package:quran_mcp_server/src/user_db/user_db_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('user_db_migration_test_');
    dbPath = p.join(tempDir.path, 'user.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Writes a database carrying only the schema-v1 tables plus one seed
  /// `audit_log` row, then closes it — simulating a `user.db` last opened
  /// before this change shipped.
  Future<void> seedSchemaV1Database() async {
    final v1 = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 1),
    );
    await v1.transaction((txn) async {
      for (final stmt in userDbSchemaV1Statements) {
        await txn.execute(stmt);
      }
      await txn.insert('schema_meta', {'key': 'version', 'value': '1'});
    });
    await v1.insert('audit_log', {
      'ts_utc': 123,
      'tool_name': 'search_quran',
      'args_summary': 'q=seed',
      'result_status': 'ok',
      'scope_at_time': 'readonly',
    });
    await v1.close();
  }

  test(
    'an existing schema-v1 user.db upgrades to v2 without data loss',
    () async {
      await seedSchemaV1Database();

      final db = await openUserDb(absolutePath: dbPath);
      addTearDown(() async => db.close());

      final version = await db.query(
        'schema_meta',
        where: 'key = ?',
        whereArgs: ['version'],
        limit: 1,
      );
      expect(version.single['value'], '2');

      final tables = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table'",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();
      expect(tableNames, containsAll(<String>['bookmark', 'reading_position']));

      final audit = await db.query('audit_log');
      expect(audit, hasLength(1));
      expect(audit.single['args_summary'], 'q=seed');
    },
  );

  test('a fresh user.db is created directly at schema v2', () async {
    final db = await openUserDb(absolutePath: dbPath);
    addTearDown(() async => db.close());

    final version = await db.query(
      'schema_meta',
      where: 'key = ?',
      whereArgs: ['version'],
      limit: 1,
    );
    expect(version.single['value'], '2');

    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );
    final tableNames = tables.map((r) => r['name'] as String).toSet();
    expect(
      tableNames,
      containsAll(<String>['audit_log', 'bookmark', 'reading_position']),
    );
  });

  test('reopening an already-v2 user.db is idempotent', () async {
    final first = await openUserDb(absolutePath: dbPath);
    await first.insert('bookmark', {
      'surah': 2,
      'ayah': 255,
      'created_at_utc': 1,
    });
    await first.close();

    final second = await openUserDb(absolutePath: dbPath);
    addTearDown(() async => second.close());

    final bookmarks = await second.query('bookmark');
    expect(bookmarks, hasLength(1));
    expect(bookmarks.single['surah'], 2);
  });
}
