import 'package:flutter_test/flutter_test.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/mcp/mcp_server_service.dart';
import 'package:quran_player/domain/mcp/mcp_error.dart';
import 'package:quran_player/domain/mcp/mcp_playback_bridge.dart';
import 'package:quran_player/domain/mcp/mcp_playback_command.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_search_result.dart';

import '../../_fakes/fake_audio_repository.dart';
import '../../_fakes/fake_quran_repository.dart';

void main() {
  group('McpServerService', () {
    test('lists read-only and playback tools plus Quran resources', () {
      final service = _service();

      expect(
        service.listTools().map((t) => t.name),
        containsAll(McpServerService.toolNames),
      );
      expect(
        service.listResources().map((r) => r.uri),
        containsAll(McpServerService.resourceUris),
      );
    });

    test('returns verified Quran and reciter data through tools', () async {
      final service = _service();

      final ayah = await service.callTool('get_ayah', {
        'surah': 2,
        'ayah': 255,
      });
      expect((ayah['ayah']! as Map)['reference'], '2:255');
      expect((ayah['ayah']! as Map)['text'], contains('الكرسي'));

      final surah = await service.callTool('get_surah', {'surah': 1});
      expect((surah['surah']! as Map)['nameLatin'], 'Al-Fatihah');
      expect(surah['ayahs'], hasLength(2));

      final search = await service.callTool('search_quran', {
        'query': 'الله',
        'limit': 1,
      });
      expect(search['results'], hasLength(1));

      final reciters = await service.callTool('list_reciters');
      expect(
        (reciters['reciters']! as List).single,
        containsPair('id', 'test-reciter'),
      );
    });

    test('returns verified data through resources', () async {
      final service = _service();

      final metadata = await service.readResource('quran://metadata');
      expect((metadata['metadata']! as Map)['name'], 'TestSource');

      final surahs = await service.readResource('quran://surahs');
      expect(surahs['surahs'], hasLength(2));

      final ayah = await service.readResource('quran://ayah/2/255');
      expect((ayah['ayah']! as Map)['reference'], '2:255');
    });

    test('maps invalid input and bootstrap failures to MCP errors', () async {
      final service = _service(
        dataAvailable: () =>
            const Result.err(DataIntegrityFailure('integrity failed')),
      );

      expect(
        () => service.callTool('search_quran', {'query': ''}),
        throwsA(isA<McpException>()),
      );

      try {
        await service.callTool('list_surahs');
        fail('expected MCP exception');
      } on McpException catch (e) {
        expect(e.error.code, McpErrorCode.dataIntegrity);
      }
    });

    test('denied playback command does not touch the player bridge', () async {
      final bridge = _FakePlaybackBridge();
      final service = _service(
        bridge: bridge,
        permission: (_) async =>
            const Result.err(DataAccessFailure('permission denied')),
      );

      try {
        await service.callTool('play_ayah', {'surah': 2, 'ayah': 255});
        fail('expected MCP exception');
      } on McpException catch (e) {
        expect(e.error.code, McpErrorCode.permissionDenied);
      }
      expect(bridge.applied, isEmpty);
    });

    test('approved playback command invokes the bridge', () async {
      final bridge = _FakePlaybackBridge();
      final service = _service(bridge: bridge);

      await service.callTool('play_surah', {'surah': 1});

      expect(bridge.applied.single.type, McpPlaybackCommandType.playSurah);
      expect(bridge.applied.single.surah, 1);
    });
  });
}

McpServerService _service({
  McpPlaybackBridge? bridge,
  McpPermissionRequest? permission,
  McpDataAvailable? dataAvailable,
}) {
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
    playbackBridge: bridge ?? _FakePlaybackBridge(),
    requestPermission: permission ?? (_) async => const Result.ok(null),
    dataAvailable: dataAvailable,
  );
}

class _FakePlaybackBridge implements McpPlaybackBridge {
  final applied = <McpPlaybackCommand>[];

  @override
  bool isAvailable = true;

  @override
  Future<Result<void>> apply(McpPlaybackCommand command) async {
    applied.add(command);
    return const Result.ok(null);
  }
}
