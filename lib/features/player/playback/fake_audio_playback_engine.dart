import 'dart:async';

import '../../../core/error/result.dart';
import 'audio_playback_engine.dart';

class FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _currentIndex = StreamController<int>.broadcast();

  Uri? loadedUri;
  List<Uri> loadedQueue = const [];
  int currentIndex = 0;
  int loadQueueCalls = 0;
  bool disposed = false;
  Duration lastSeek = Duration.zero;

  @override
  Stream<bool> get bufferingStream => _buffering.stream;

  @override
  Stream<bool> get completedStream => _completed.stream;

  @override
  Stream<int> get currentIndexStream => _currentIndex.stream;

  @override
  Stream<Duration> get durationStream => _duration.stream;

  @override
  Stream<String> get errorStream => _error.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Future<Result<void>> loadQueue(
    List<Uri> uris, {
    int initialIndex = 0,
    bool play = false,
  }) async {
    loadQueueCalls += 1;
    loadedQueue = List.unmodifiable(uris);
    currentIndex = initialIndex;
    loadedUri = uris[initialIndex];
    _currentIndex.add(initialIndex);
    _position.add(Duration.zero);
    _playing.add(play);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> jumpTo(int index) async {
    if (index < 0 || index >= loadedQueue.length) return const Result.ok(null);
    currentIndex = index;
    loadedUri = loadedQueue[index];
    _currentIndex.add(index);
    _position.add(Duration.zero);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> next() async {
    return jumpTo(currentIndex + 1);
  }

  @override
  Future<Result<void>> pause() async {
    _playing.add(false);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> play() async {
    _playing.add(true);
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> previous() async {
    return jumpTo(currentIndex - 1);
  }

  @override
  Future<Result<void>> seek(Duration position) async {
    lastSeek = position;
    _position.add(position);
    return const Result.ok(null);
  }

  void emitDuration(Duration value) => _duration.add(value);

  void emitCompleted() => _completed.add(true);

  void emitError(String message) => _error.add(message);

  @override
  Future<Result<void>> dispose() async {
    disposed = true;
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _buffering.close();
    await _completed.close();
    await _error.close();
    await _currentIndex.close();
    return const Result.ok(null);
  }
}
