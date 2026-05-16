import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quran_mcp_server/quran_mcp_server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import '_fakes/fake_ports.dart';

/// End-to-end integration tests for the streamable HTTP transport.
///
/// Boots a real `QuranMcpServer` on an OS-assigned ephemeral port, talks to
/// it via `dart:io`'s `HttpClient` using JSON-RPC `2.0` envelopes, and
/// asserts the responses + side effects (audit log, audio bridge non-
/// invocation) match the spec.
void main() {
  late RecordingQuranPort quran;
  late RecordingAudioPort audio;
  late AuditLogRepository audit;
  late Database db;
  late Directory tempDir;
  late QuranMcpServer server;
  late McpServerStatus status;
  late HttpClient httpClient;

  Future<void> bootServer({required ScopeCheck scopeCheck}) async {
    server = QuranMcpServer(
      quran: quran,
      audio: audio,
      scopeCheck: scopeCheck,
      audit: audit,
    );
    status = await server.start(port: 0);
  }

  ScopeCheck scopeReadonlyOnly() =>
      (s) => s == Scope.readonly;
  ScopeCheck scopeReadonlyPlusPlayback() =>
      (s) => s == Scope.readonly || s == Scope.playback;

  setUp(() async {
    quran = RecordingQuranPort();
    audio = RecordingAudioPort();
    tempDir = await Directory.systemTemp.createTemp('streamable_http_test_');
    db = await openUserDb(absolutePath: p.join(tempDir.path, 'user.db'));
    audit = AuditLogRepository(db);
    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close(force: true);
    await server.stop();
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Sends a JSON-RPC request to the server's MCP endpoint with the bearer
  /// token. Returns the response body parsed as JSON, the response status
  /// code, and the `mcp-session-id` response header (if any).
  ///
  /// Pass [token] to override the auth header (use empty string to omit it).
  /// Pass [sessionId] to set the `mcp-session-id` request header for
  /// non-initialize calls.
  Future<({int status, Map<String, Object?> body, String? sessionId})> jsonRpc({
    required Object body,
    String? token,
    String? sessionId,
  }) async {
    final req = await httpClient.postUrl(status.uri!);
    req.headers.contentType = ContentType.json;
    req.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/event-stream',
    );
    final actualToken = token ?? status.authToken;
    if (actualToken != null && actualToken.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $actualToken');
    }
    if (sessionId != null) {
      req.headers.set('mcp-session-id', sessionId);
    }
    req.write(jsonEncode(body));
    final res = await req.close();
    final raw = await res.transform(utf8.decoder).join();
    Map<String, Object?> parsed = const {};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, Object?>) parsed = decoded;
      } on FormatException {
        // Some transports prepend SSE framing; strip and retry.
        final lastBrace = raw.lastIndexOf('{');
        if (lastBrace >= 0) {
          final inner = raw.substring(lastBrace);
          final decoded = jsonDecode(inner);
          if (decoded is Map<String, Object?>) parsed = decoded;
        }
      }
    }
    return (
      status: res.statusCode,
      body: parsed,
      sessionId: res.headers.value('mcp-session-id'),
    );
  }

  /// Drives the MCP `initialize` handshake. Returns the issued session id
  /// so callers can chain subsequent calls.
  Future<String> initialize() async {
    final res = await jsonRpc(
      body: {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': const <String, Object?>{},
          'clientInfo': const {'name': 'test-client', 'version': '0.0.1'},
        },
      },
    );
    expect(res.status, 200, reason: 'initialize must succeed: ${res.body}');
    expect(
      res.sessionId,
      isNotNull,
      reason: 'initialize response must carry mcp-session-id',
    );
    return res.sessionId!;
  }

  group('bearer-token gate', () {
    test('missing Authorization header returns 401 with no session', () async {
      await bootServer(scopeCheck: scopeReadonlyOnly());

      final res = await jsonRpc(
        token: '', // omit the header
        body: {'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'},
      );

      expect(res.status, HttpStatus.unauthorized);
      expect(
        res.sessionId,
        isNull,
        reason: 'transport must not issue a session for unauthorized request',
      );

      final rows = await audit.recent(20);
      expect(rows, isEmpty, reason: 'dispatcher must not be reached on 401');
    });

    test('wrong token returns 401', () async {
      await bootServer(scopeCheck: scopeReadonlyOnly());

      final res = await jsonRpc(
        token: 'definitely-not-the-real-token',
        body: {'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'},
      );

      expect(res.status, HttpStatus.unauthorized);
    });
  });

  group('initialize + tools/list', () {
    test(
      'initialize returns a session id and tools/list returns 11 tools',
      () async {
        await bootServer(scopeCheck: scopeReadonlyOnly());

        final sessionId = await initialize();

        final list = await jsonRpc(
          sessionId: sessionId,
          body: {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
        );

        expect(list.status, 200);
        expect(list.body['jsonrpc'], '2.0');
        expect(list.body['id'], 2);
        final result = list.body['result'] as Map<String, Object?>;
        final tools = result['tools'] as List;
        expect(tools, hasLength(mcpToolDefinitions.length));
        final names = tools
            .map((t) => (t as Map<String, Object?>)['name'] as String)
            .toSet();
        for (final def in mcpToolDefinitions) {
          expect(names, contains(def.name));
        }
      },
    );

    test('reusing the same session-id keeps the session alive', () async {
      await bootServer(scopeCheck: scopeReadonlyOnly());

      final sessionId = await initialize();

      final first = await jsonRpc(
        sessionId: sessionId,
        body: {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
      );
      final second = await jsonRpc(
        sessionId: sessionId,
        body: {'jsonrpc': '2.0', 'id': 3, 'method': 'tools/list'},
      );

      expect(first.status, 200);
      expect(second.status, 200);
      expect(second.body['id'], 3);
    });
  });

  group('tools/call', () {
    test('Mode A get_ayah returns ok and writes audit row', () async {
      await bootServer(scopeCheck: scopeReadonlyOnly());
      final sessionId = await initialize();

      final res = await jsonRpc(
        sessionId: sessionId,
        body: {
          'jsonrpc': '2.0',
          'id': 10,
          'method': 'tools/call',
          'params': {
            'name': 'get_ayah',
            'arguments': {'surah': 2, 'ayah': 255},
          },
        },
      );

      expect(res.status, 200);
      expect(res.body['id'], 10);
      final result = res.body['result'] as Map<String, Object?>;
      // The dispatcher returns {data: {...}} which our adapter wraps as
      // CallToolResult.content[0].text = jsonEncode(data).
      final content = result['content'] as List;
      expect(content, isNotEmpty);
      final text = (content.first as Map<String, Object?>)['text'] as String;
      expect(text, contains('"surah":2'));
      expect(text, contains('"ayah":255'));

      final rows = await audit.recent(20);
      expect(rows.first.toolName, 'get_ayah');
      expect(rows.first.resultStatus, AuditResultStatus.ok);
      expect(quran.calls, contains('getAyahJson(2,255)'));
    });

    test(
      'Mode B play_surah with playback scope OFF returns scope_denied; audio bridge not invoked; audit row written',
      () async {
        await bootServer(scopeCheck: scopeReadonlyOnly());
        final sessionId = await initialize();

        final res = await jsonRpc(
          sessionId: sessionId,
          body: {
            'jsonrpc': '2.0',
            'id': 11,
            'method': 'tools/call',
            'params': {
              'name': 'play_surah',
              'arguments': {'surah': 36},
            },
          },
        );

        expect(res.status, 200);
        // mcp_dart wraps tool results; an isError CallToolResult still rides
        // the JSON-RPC `result` channel (not `error`), with `isError:true`
        // inside the result and the McpError JSON in the content text.
        final result = res.body['result'] as Map<String, Object?>;
        expect(result['isError'], isTrue);
        final content = result['content'] as List;
        final text = (content.first as Map<String, Object?>)['text'] as String;
        expect(text, contains('scope_denied'));

        expect(
          audio.calls,
          isEmpty,
          reason: 'audio bridge must not be invoked when scope is denied',
        );

        final rows = await audit.recent(20);
        expect(rows.first.toolName, 'play_surah');
        expect(rows.first.resultStatus, AuditResultStatus.scopeDenied);
      },
    );

    test('Mode B pause_playback with playback scope ON succeeds', () async {
      await bootServer(scopeCheck: scopeReadonlyPlusPlayback());
      final sessionId = await initialize();

      final res = await jsonRpc(
        sessionId: sessionId,
        body: {
          'jsonrpc': '2.0',
          'id': 12,
          'method': 'tools/call',
          'params': {'name': 'pause_playback', 'arguments': const {}},
        },
      );

      expect(res.status, 200);
      final result = res.body['result'] as Map<String, Object?>;
      expect(result['isError'], anyOf(isNull, isFalse));
      expect(audio.calls, ['pausePlayback']);

      final rows = await audit.recent(20);
      expect(rows.first.toolName, 'pause_playback');
      expect(rows.first.resultStatus, AuditResultStatus.ok);
      expect(rows.first.scopeAtTime, contains('playback'));
    });
  });

  group('resources', () {
    test('resources/list returns the three static quran:// resources', () async {
      await bootServer(scopeCheck: scopeReadonlyOnly());
      final sessionId = await initialize();

      final res = await jsonRpc(
        sessionId: sessionId,
        body: {'jsonrpc': '2.0', 'id': 20, 'method': 'resources/list'},
      );

      expect(res.status, 200);
      final result = res.body['result'] as Map<String, Object?>;
      final resources = result['resources'] as List;
      final uris = resources
          .map((r) => (r as Map<String, Object?>)['uri'] as String)
          .toSet();

      // Static URIs are registered through mcp_dart's resource API.
      // Templated URIs (`quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`)
      // are intentionally not surfaced here yet; clients use the equivalent
      // tools (`get_surah`, `get_ayah`).
      expect(
        uris,
        containsAll(<String>{
          'quran://metadata',
          'quran://surahs',
          'quran://reciters',
        }),
      );
    });

    test('resources/read for quran://surahs returns the surah list', () async {
      await bootServer(scopeCheck: scopeReadonlyOnly());
      final sessionId = await initialize();

      final res = await jsonRpc(
        sessionId: sessionId,
        body: {
          'jsonrpc': '2.0',
          'id': 21,
          'method': 'resources/read',
          'params': {'uri': 'quran://surahs'},
        },
      );

      expect(res.status, 200);
      final result = res.body['result'] as Map<String, Object?>;
      final contents = result['contents'] as List;
      expect(contents, isNotEmpty);
      final first = contents.first as Map<String, Object?>;
      expect(first['uri'], 'quran://surahs');
      expect(first['mimeType'], 'application/json');
      expect(first['text'], isA<String>());

      final rows = await audit.recent(20);
      expect(rows.first.toolName, contains('quran://surahs'));
      expect(rows.first.resultStatus, AuditResultStatus.ok);
    });
  });
}
