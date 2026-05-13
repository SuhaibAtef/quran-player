import '../../../core/error/result.dart';

abstract class AudioPlaybackEngine {
  Stream<Duration> get positionStream;

  Stream<Duration> get durationStream;

  Stream<bool> get playingStream;

  Stream<bool> get bufferingStream;

  Stream<bool> get completedStream;

  Stream<String> get errorStream;

  Stream<int> get currentIndexStream;

  Future<Result<void>> loadQueue(
    List<Uri> uris, {
    int initialIndex = 0,
    bool play = false,
  });

  Future<Result<void>> play();

  Future<Result<void>> pause();

  Future<Result<void>> next();

  Future<Result<void>> previous();

  Future<Result<void>> jumpTo(int index);

  Future<Result<void>> seek(Duration position);

  Future<Result<void>> dispose();
}
