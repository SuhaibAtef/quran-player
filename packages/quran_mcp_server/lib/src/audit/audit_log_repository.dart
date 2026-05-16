import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'audit_entry.dart';

/// Persistent audit log for every MCP tool call (Mode A reads and Mode B
/// writes alike). Backed by the `audit_log` table in `user.db`.
class AuditLogRepository {
  AuditLogRepository(this._db);

  final Database _db;

  /// How many milliseconds make up seven days. Public for tests that want to
  /// insert backdated rows.
  static const int sevenDaysMillis = 7 * 24 * 60 * 60 * 1000;

  Future<void> append(AuditEntry entry) async {
    await _db.insert('audit_log', {
      'ts_utc': entry.tsUtcMillis,
      'tool_name': entry.toolName,
      'args_summary': entry.argsSummary,
      'result_status': entry.resultStatus.sqlValue,
      'scope_at_time': entry.scopeAtTime,
    });
  }

  /// Deletes rows whose `ts_utc` is more than seven days older than [nowUtc].
  /// Returns the number of deleted rows.
  Future<int> prune7Days({DateTime? nowUtc}) async {
    final cutoff =
        (nowUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch -
        sevenDaysMillis;
    return _db.delete('audit_log', where: 'ts_utc < ?', whereArgs: [cutoff]);
  }

  Future<int> clear() async {
    return _db.delete('audit_log');
  }

  Future<List<AuditEntry>> recent(int limit) async {
    final rows = await _db.query(
      'audit_log',
      orderBy: 'ts_utc DESC',
      limit: limit,
    );
    return rows.map(_rowToEntry).toList(growable: false);
  }

  AuditEntry _rowToEntry(Map<String, Object?> row) {
    return AuditEntry(
      id: row['id'] as int?,
      tsUtcMillis: row['ts_utc']! as int,
      toolName: row['tool_name']! as String,
      argsSummary: row['args_summary']! as String,
      resultStatus: AuditResultStatusSql.fromSqlValue(
        row['result_status']! as String,
      ),
      scopeAtTime: row['scope_at_time']! as String,
    );
  }
}
