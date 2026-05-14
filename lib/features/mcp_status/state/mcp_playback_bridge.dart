import '../../../core/error/result.dart';
import '../../../domain/mcp/mcp_playback_bridge.dart';
import '../../../domain/mcp/mcp_playback_command.dart';
import '../../player/state/audio_player_controller.dart';

class AppMcpPlaybackBridge implements McpPlaybackBridge {
  const AppMcpPlaybackBridge(this._controller);

  final AudioPlayerController _controller;

  @override
  bool get isAvailable => true;

  @override
  Future<Result<void>> apply(McpPlaybackCommand command) async {
    switch (command.type) {
      case McpPlaybackCommandType.playSurah:
        await _controller.startSurah(command.surah!);
      case McpPlaybackCommandType.playAyah:
        await _controller.startAyah(command.ayahKey!);
      case McpPlaybackCommandType.pausePlayback:
        await _controller.pause();
      case McpPlaybackCommandType.resumePlayback:
        await _controller.play();
      case McpPlaybackCommandType.stopPlayback:
        await _controller.clear();
      case McpPlaybackCommandType.setRepeat:
        // Repeat controls are not implemented yet. `off` is the only
        // supported mode and is already the current player behavior.
        break;
    }
    return const Result.ok(null);
  }
}
