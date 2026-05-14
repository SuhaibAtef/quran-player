import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quran_mcp_server/src/audit/audit_entry.dart';
import 'package:quran_mcp_server/src/audit/audit_log_repository.dart';
import 'package:quran_mcp_server/src/user_db/user_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late AuditLogRepository repo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('user_db_audit_test_');
    db = await openUserDb(absolutePath: p.join(tempDir.path, 'user.db'));
    repo = AuditLogRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  AuditEntry sample({
    int? tsUtcMillis,
    String toolName = 'search_quran',
    String argsSummary = 'q=test',
    AuditResultStatus status = AuditResultStatus.ok,
    String scopeAtTime = 'readonly',
  }) {
    return AuditEntry(
      tsUtcMillis: tsUtcMillis ?? DateTime.now().toUtc().millisecondsSinceEpoch,
      toolName: toolName,
      argsSummary: argsSummary,
      resultStatus: status,
      scopeAtTime: scopeAtTime,
    );
  }

  test('append + recent round-trips a Mode A entry (R6 scenario 1)', () async {
    await repo.append(sample(toolName: 'search_quran'));
    final rows = await repo.recent(20);
    expect(rows, hasLength(1));
    expect(rows.first.toolName, 'search_quran');
    expect(rows.first.resultStatus, AuditResultStatus.ok);
    expect(rows.first.scopeAtTime, contains('readonly'));
  });

  test('append + recent round-trips a Mode B entry (R6 scenario 2)', () async {
    await repo.append(
      sample(
        toolName: 'pause_playback',
        argsSummary: '',
        scopeAtTime: 'readonly,playback',
      ),
    );
    final rows = await repo.recent(20);
    expect(rows.first.toolName, 'pause_playback');
    expect(rows.first.scopeAtTime, equals('readonly,playback'));
  });

  test(
    'append records failed call with non-ok status (R6 scenario 3)',
    () async {
      await repo.append(
        sample(
          toolName: 'get_ayah',
          argsSummary: 'surah=200',
          status: AuditResultStatus.invalidInput,
        ),
      );
      final rows = await repo.recent(20);
      expect(rows.first.toolName, 'get_ayah');
      expect(rows.first.resultStatus, AuditResultStatus.invalidInput);
    },
  );

  test('recent returns rows in DESC ts_utc order', () async {
    final base = DateTime.utc(2026, 5, 14, 12).millisecondsSinceEpoch;
    await repo.append(sample(tsUtcMillis: base + 0, toolName: 'a'));
    await repo.append(sample(tsUtcMillis: base + 100, toolName: 'b'));
    await repo.append(sample(tsUtcMillis: base + 50, toolName: 'c'));
    final rows = await repo.recent(20);
    expect(rows.map((e) => e.toolName).toList(), ['b', 'c', 'a']);
  });

  test('clear deletes all rows', () async {
    await repo.append(sample());
    await repo.append(sample());
    await repo.clear();
    expect(await repo.recent(20), isEmpty);
  });
}
