import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'user_db_schema.dart';

/// Opens (and migrates) the user-writable `user.db`.
///
/// The host app provides the absolute path so this package stays free of
/// Flutter / `path_provider`. Returns an opened, migrated [Database] or
/// rethrows whatever the underlying driver surfaces — the host wraps that in
/// its `userDbHealthProvider` and degrades gracefully (Quran/audio still work).
Future<Database> openUserDb({required String absolutePath}) async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    absolutePath,
    options: OpenDatabaseOptions(version: userDbSchemaVersion),
  );
  await _ensureSchema(db);
  return db;
}

Future<void> _ensureSchema(Database db) async {
  await db.transaction((txn) async {
    for (final stmt in [
      ...userDbSchemaV1Statements,
      ...userDbSchemaV2Statements,
    ]) {
      await txn.execute(stmt);
    }
    final existing = await txn.query(
      'schema_meta',
      where: 'key = ?',
      whereArgs: ['version'],
      limit: 1,
    );
    if (existing.isEmpty) {
      await txn.insert('schema_meta', {
        'key': 'version',
        'value': '$userDbSchemaVersion',
      });
      await txn.insert('schema_meta', {
        'key': 'created_at_utc',
        'value': '${DateTime.now().toUtc().millisecondsSinceEpoch}',
      });
    } else if (existing.first['value'] != '$userDbSchemaVersion') {
      // Existing DB created at an older schema version: the additive v2
      // statements above have already created the new tables; bring the
      // recorded version forward.
      await txn.update(
        'schema_meta',
        {'value': '$userDbSchemaVersion'},
        where: 'key = ?',
        whereArgs: ['version'],
      );
    }
  });
}
