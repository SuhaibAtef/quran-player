import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../core/error/result.dart';
import '../../domain/audio/audio_repository.dart';
import '../../domain/quran/ayah_key.dart';
import '../../features/player/state/audio_player_controller.dart';
import 'mcp_dtos.dart';
import 'mcp_error_mapper.dart';

/// Bridges the workspace package's `McpAudioPort` to the host's
/// `AudioRepository` (for reciter metadata) and `AudioPlayerController` (for
/// playback control). Mode B tools call into this only after the dispatcher
/// has confirmed the playback scope is ON.
class HostAudioAdapter implements McpAudioPort {
  HostAudioAdapter({required this.audioRepository, required this.controller});

  final AudioRepository audioRepository;
  final AudioPlayerController controller;

  @override
  bool get isAvailable => true;

  @override
  Future<Map<String, Object?>> getDefaultReciterJson() async {
    final reciter = _unwrap(await audioRepository.getDefaultReciter());
    return reciterToMcpJson(reciter);
  }

  @override
  Future<void> playSurah(int surah) async {
    await controller.startSurah(surah);
  }

  @override
  Future<void> playAyah(int surah, int ayah) async {
    final key = _unwrap(AyahKey.tryNew(surah, ayah));
    await controller.startAyah(key);
  }

  @override
  Future<void> pausePlayback() async {
    await controller.pause();
  }

  @override
  Future<void> resumePlayback() async {
    await controller.play();
  }

  @override
  Future<void> stopPlayback() async {
    await controller.clear();
  }

  @override
  Future<void> setRepeat(String mode) async {
    // Repeat controls are not implemented yet. `off` is the only supported
    // mode and is already the current player behaviour.
    if (mode != 'off') {
      throw McpException(
        McpError(
          McpErrorCode.invalidInput,
          'Unsupported repeat mode "$mode". Supported mode: off.',
        ),
      );
    }
  }

  T _unwrap<T>(Result<T> result) {
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw McpException(mcpErrorFromFailure(failure)),
    };
  }
}
