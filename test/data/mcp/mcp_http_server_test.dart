import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/mcp/mcp_http_server.dart';
import 'package:quran_player/data/mcp/mcp_server_service.dart';
import 'package:quran_player/domain/mcp/mcp_playback_bridge.dart';
import 'package:quran_player/domain/mcp/mcp_playback_command.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_search_result.dart';

import '../../_fakes/fake_audio_repository.dart';
import '../../_fakes/fake_quran_repository.dart';

void main() {
  test('rejects Streamable HTTP requests without bearer token', () async {
    final handle = await const McpHttpServerFactory().start(_service());
    addTearDown(handle.stop);

    final response = await http.post(
      handle.uri,
      headers: const {
        'accept': 'application/json, text/event-stream',
        'content-type': 'application/json',
      },
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}),
    );

    expect(response.statusCode, HttpStatus.unauthorized);
    expect(response.body, contains('Unauthorized'));
  });

  test(
    'serves MCP initialize, tools/list, and tools/call with bearer token',
    () async {
      final handle = await const McpHttpServerFactory().start(_service());
      addTearDown(handle.stop);

      final initialize = await _postJson(handle, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2025-06-18',
          'capabilities': {},
          'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
        },
      });

      expect(initialize.statusCode, HttpStatus.ok);
      final sessionId = initialize.headers['mcp-session-id'];
      expect(sessionId, isNotNull);
      final initializeJson = _json(initialize);
      expect(
        initializeJson['result'],
        containsPair('protocolVersion', '2025-06-18'),
      );

      final tools = await _postJson(handle, {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      }, sessionId: sessionId);

      expect(tools.statusCode, HttpStatus.ok);
      expect(tools.body, contains('get_ayah'));
      expect(tools.body, contains('play_surah'));

      final ayah = await _postJson(handle, {
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'get_ayah',
          'arguments': {'surah': 2, 'ayah': 255},
        },
      }, sessionId: sessionId);

      expect(ayah.statusCode, HttpStatus.ok);
      final ayahJson = _json(ayah);
      expect(
        ayahJson['result']['structuredContent']['ayah'],
        containsPair('reference', '2:255'),
      );
    },
  );
}

Future<http.Response> _postJson(
  McpHttpServerHandle handle,
  Map<String, Object?> body, {
  String? sessionId,
}) {
  final headers = {
    'accept': 'application/json, text/event-stream',
    'authorization': 'Bearer ${handle.authToken}',
    'content-type': 'application/json',
  };
  if (sessionId != null) headers['mcp-session-id'] = sessionId;

  return http.post(handle.uri, headers: headers, body: jsonEncode(body));
}

Map<String, dynamic> _json(http.Response response) {
  return jsonDecode(response.body) as Map<String, dynamic>;
}

McpServerService _service() {
  return McpServerService(
    quranRepository: FakeQuranRepository(
      ayahs: {
        AyahKey(1, 1): Ayah(key: AyahKey(1, 1), text: 'بسم الله الرحمن الرحيم'),
        AyahKey(1, 2): Ayah(key: AyahKey(1, 2), text: 'الحمد لله رب العالمين'),
        AyahKey(2, 255): Ayah(key: AyahKey(2, 255), text: 'آية الكرسي الله'),
      },
      searchResult: Result.ok([
        QuranSearchResult(
          key: AyahKey(2, 255),
          text: 'آية الكرسي الله',
          surahNameArabic: 'البقرة',
          surahNameLatin: 'Al-Baqarah',
        ),
      ]),
    ),
    audioRepository: FakeAudioRepository(),
    playbackBridge: _FakePlaybackBridge(),
    requestPermission: (_) async => const Result.ok(null),
  );
}

class _FakePlaybackBridge implements McpPlaybackBridge {
  @override
  bool isAvailable = true;

  @override
  Future<Result<void>> apply(McpPlaybackCommand command) async {
    return const Result.ok(null);
  }
}
