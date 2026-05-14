import 'package:flutter_test/flutter_test.dart';
import 'package:quran_player/domain/audio/audio_playback_state.dart';
import 'package:quran_player/domain/mcp/mcp_playback_command.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/features/mcp_status/state/mcp_playback_bridge.dart';
import 'package:quran_player/features/player/playback/fake_audio_playback_engine.dart';
import 'package:quran_player/features/player/state/audio_player_controller.dart';

import '../../_fakes/fake_audio_repository.dart';

void main() {
  test('approved MCP commands reuse the app player controller', () async {
    final engine = FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(
      repository: FakeAudioRepository(),
      engine: engine,
    );
    addTearDown(controller.dispose);
    final bridge = AppMcpPlaybackBridge(controller);

    await bridge.apply(
      const McpPlaybackCommand(
        id: '1',
        type: McpPlaybackCommandType.playSurah,
        surah: 1,
      ),
    );
    expect(controller.state.status, AudioPlayerStatus.playing);
    expect(controller.state.currentItem?.track.ayahKey, AyahKey(1, 1));

    await bridge.apply(
      const McpPlaybackCommand(
        id: '2',
        type: McpPlaybackCommandType.pausePlayback,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AudioPlayerStatus.paused);

    await bridge.apply(
      const McpPlaybackCommand(
        id: '3',
        type: McpPlaybackCommandType.resumePlayback,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AudioPlayerStatus.playing);

    await bridge.apply(
      const McpPlaybackCommand(
        id: '4',
        type: McpPlaybackCommandType.stopPlayback,
      ),
    );
    expect(controller.state.status, AudioPlayerStatus.idle);
  });

  test(
    'play ayah starts at the requested ayah in the existing queue',
    () async {
      final controller = AudioPlayerController(
        repository: FakeAudioRepository(),
        engine: FakeAudioPlaybackEngine(),
      );
      addTearDown(controller.dispose);
      final bridge = AppMcpPlaybackBridge(controller);

      await bridge.apply(
        McpPlaybackCommand(
          id: '1',
          type: McpPlaybackCommandType.playAyah,
          ayahKey: AyahKey(1, 2),
        ),
      );

      expect(controller.state.currentItem?.track.ayahKey, AyahKey(1, 2));
    },
  );
}
