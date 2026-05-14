import '../quran/ayah_key.dart';

enum McpPlaybackCommandType {
  playSurah,
  playAyah,
  pausePlayback,
  resumePlayback,
  stopPlayback,
  setRepeat,
}

enum McpPlaybackDecision { pending, approved, denied, timedOut, unavailable }

enum McpRepeatMode { off }

class McpPlaybackCommand {
  const McpPlaybackCommand({
    required this.id,
    required this.type,
    this.surah,
    this.ayahKey,
    this.repeatMode,
    this.clientName,
  });

  final String id;
  final McpPlaybackCommandType type;
  final int? surah;
  final AyahKey? ayahKey;
  final McpRepeatMode? repeatMode;
  final String? clientName;

  String get label {
    return switch (type) {
      McpPlaybackCommandType.playSurah => 'Play Surah $surah',
      McpPlaybackCommandType.playAyah => 'Play Ayah $ayahKey',
      McpPlaybackCommandType.pausePlayback => 'Pause playback',
      McpPlaybackCommandType.resumePlayback => 'Resume playback',
      McpPlaybackCommandType.stopPlayback => 'Stop playback',
      McpPlaybackCommandType.setRepeat => 'Set repeat ${repeatMode?.name}',
    };
  }
}

class McpPlaybackDecisionRecord {
  const McpPlaybackDecisionRecord({
    required this.command,
    required this.decision,
    required this.decidedAt,
    this.message,
  });

  final McpPlaybackCommand command;
  final McpPlaybackDecision decision;
  final DateTime decidedAt;
  final String? message;
}

class McpPlaybackPermissionState {
  const McpPlaybackPermissionState({this.pending, this.recent = const []});

  final McpPlaybackCommand? pending;
  final List<McpPlaybackDecisionRecord> recent;

  McpPlaybackPermissionState copyWith({
    McpPlaybackCommand? pending,
    bool clearPending = false,
    List<McpPlaybackDecisionRecord>? recent,
  }) {
    return McpPlaybackPermissionState(
      pending: clearPending ? null : pending ?? this.pending,
      recent: recent ?? this.recent,
    );
  }
}
