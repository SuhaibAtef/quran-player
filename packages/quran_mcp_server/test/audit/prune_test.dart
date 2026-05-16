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
    tempDir = await Directory.systemTemp.createTemp('user_db_prune_test_');
    db = await openUserDb(absolutePath: p.join(tempDir.path, 'user.db'));
    repo = AuditLogRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'prune7Days deletes rows older than 7 days and keeps newer ones (R4 scenario 1)',
    () async {
      final now = DateTime.utc(2026, 5, 14, 12);
      final eightDaysAgo = now
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch;
      final sixDaysAgo = now
          .subtract(const Duration(days: 6))
          .millisecondsSinceEpoch;
      final justNow = now.millisecondsSinceEpoch;

      AuditEntry at(int ts) => AuditEntry(
        tsUtcMillis: ts,
        toolName: 'search_quran',
        argsSummary: 'q=$ts',
        resultStatus: AuditResultStatus.ok,
        scopeAtTime: 'readonly',
      );

      await repo.append(at(eightDaysAgo));
      await repo.append(at(sixDaysAgo));
      await repo.append(at(justNow));

      final deleted = await repo.prune7Days(nowUtc: now);

      expect(deleted, equals(1));

      final remaining = await repo.recent(20);
      final remainingTimes = remaining.map((e) => e.tsUtcMillis).toList()
        ..sort();
      expect(remainingTimes, equals([sixDaysAgo, justNow]));
    },
  );

  test(
    'prune7Days returns zero when nothing is eligible (R4 scenario 2)',
    () async {
      final now = DateTime.utc(2026, 5, 14, 12);
      await repo.append(
        AuditEntry(
          tsUtcMillis: now
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch,
          toolName: 'list_surahs',
          argsSummary: '',
          resultStatus: AuditResultStatus.ok,
          scopeAtTime: 'readonly',
        ),
      );
      final deleted = await repo.prune7Days(nowUtc: now);
      expect(deleted, equals(0));
    },
  );
}
