import 'package:media_kit/media_kit.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import 'audio_playback_engine.dart';

class MediaKitAudioPlaybackEngine implements AudioPlaybackEngine {
  MediaKitAudioPlaybackEngine({Player? player}) : _player = player ?? Player();

  final Player _player;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<int> get currentIndexStream {
    return _player.stream.playlist.map((playlist) => playlist.index);
  }

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<String> get errorStream => _player.stream.error;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Future<Result<void>> loadQueue(
    List<Uri> uris, {
    int initialIndex = 0,
    bool play = false,
  }) {
    return _guard(() {
      return _player.open(
        Playlist(
          uris.map((uri) => Media(uri.toString())).toList(growable: false),
          index: initialIndex,
        ),
        play: play,
      );
    });
  }

  @override
  Future<Result<void>> jumpTo(int index) => _guard(() => _player.jump(index));

  @override
  Future<Result<void>> next() => _guard(_player.next);

  @override
  Future<Result<void>> pause() => _guard(_player.pause);

  @override
  Future<Result<void>> play() => _guard(_player.play);

  @override
  Future<Result<void>> previous() => _guard(_player.previous);

  @override
  Future<Result<void>> seek(Duration position) {
    return _guard(() => _player.seek(position));
  }

  @override
  Future<Result<void>> dispose() => _guard(_player.dispose);

  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Result.ok(null);
    } on Object catch (e, st) {
      return Result.err(
        DataAccessFailure('audio playback failed', cause: e, stackTrace: st),
      );
    }
  }
}
