import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quran_mcp_server/quran_mcp_server.dart';
import 'package:quran_mcp_server/src/dispatcher.dart';
import 'package:quran_mcp_server/src/tools/tool_handlers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import '../_fakes/fake_ports.dart';

/// Spec mcp-server R3: Mode B tool handlers SHALL return a structured
/// `scope_denied` McpError when the playback scope is OFF, and SHALL NOT
/// invoke the audio bridge.
void main() {
  late RecordingQuranPort quran;
  late RecordingAudioPort audio;
  late AuditLogRepository audit;
  late Database db;
  late Directory tempDir;

  ScopeCheck withPlaybackOff() =>
      (s) => s == Scope.readonly;
  ScopeCheck withPlaybackOn() =>
      (s) => s == Scope.readonly || s == Scope.playback;

  setUp(() async {
    quran = RecordingQuranPort();
    audio = RecordingAudioPort();
    tempDir = await Directory.systemTemp.createTemp('scope_check_test_');
    db = await openUserDb(absolutePath: p.join(tempDir.path, 'user.db'));
    audit = AuditLogRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Map<String, Object?> argsFor(String tool) {
    switch (tool) {
      case 'play_surah':
        return {'surah': 36};
      case 'play_ayah':
        return {'surah': 2, 'ayah': 255};
      case 'set_repeat':
        return {'mode': 'off'};
      case 'pause_playback':
      case 'resume_playback':
      case 'stop_playback':
        return const {};
    }
    throw StateError('Unknown tool: $tool');
  }

  for (final tool in modeBToolNames) {
    test(
      '$tool returns scope_denied when playback scope is OFF (R3)',
      () async {
        final dispatcher = Dispatcher(
          handlers: ToolHandlers(quran: quran, audio: audio),
          scopeCheck: withPlaybackOff(),
          audit: audit,
        );

        final result = await dispatcher.callTool(tool, argsFor(tool));

        expect(result.isError, isTrue, reason: '$tool should be denied');
        expect(result.error!.code, McpErrorCode.scopeDenied);
        expect(
          audio.calls,
          isEmpty,
          reason: '$tool must not invoke the audio bridge',
        );

        // Audit row appended with status=scope_denied.
        final rows = await audit.recent(20);
        expect(rows, hasLength(1));
        expect(rows.first.toolName, tool);
        expect(rows.first.resultStatus, AuditResultStatus.scopeDenied);
        expect(rows.first.scopeAtTime, 'readonly');
      },
    );
  }

  test(
    'Mode B tool succeeds and writes ok audit row when scope is ON',
    () async {
      final dispatcher = Dispatcher(
        handlers: ToolHandlers(quran: quran, audio: audio),
        scopeCheck: withPlaybackOn(),
        audit: audit,
      );

      final result = await dispatcher.callTool('pause_playback', const {});
      expect(result.isError, isFalse);
      expect(audio.calls, ['pausePlayback']);

      final rows = await audit.recent(20);
      expect(rows.first.resultStatus, AuditResultStatus.ok);
      expect(rows.first.scopeAtTime, 'readonly,playback');
    },
  );

  test(
    'Mode A search_quran appends an audit row with truncated query (R6+R7)',
    () async {
      final dispatcher = Dispatcher(
        handlers: ToolHandlers(quran: quran, audio: audio),
        scopeCheck: withPlaybackOff(),
        audit: audit,
      );

      final longQuery = 'a' * 200;
      final result = await dispatcher.callTool('search_quran', {
        'query': longQuery,
        'limit': 5,
      });

      expect(result.isError, isFalse);
      final rows = await audit.recent(20);
      expect(rows.first.toolName, 'search_quran');
      expect(rows.first.argsSummary, equals('query=${'a' * 128}…[+72 more]'));
    },
  );

  test(
    'failed Mode A call appends invalid_input audit row (R6 scenario 3)',
    () async {
      final dispatcher = Dispatcher(
        handlers: ToolHandlers(quran: quran, audio: audio),
        scopeCheck: withPlaybackOff(),
        audit: audit,
      );

      final result = await dispatcher.callTool('get_ayah', {
        'surah': 200,
        'ayah': 1,
      });

      expect(result.isError, isTrue);
      expect(result.error!.code, McpErrorCode.invalidInput);

      final rows = await audit.recent(20);
      expect(rows.first.resultStatus, AuditResultStatus.invalidInput);
    },
  );
}
