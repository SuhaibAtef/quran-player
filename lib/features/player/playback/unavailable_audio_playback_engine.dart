import 'dart:async';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import 'audio_playback_engine.dart';

class UnavailableAudioPlaybackEngine implements AudioPlaybackEngine {
  const UnavailableAudioPlaybackEngine([
    this.reason = 'audio backend unavailable',
  ]);

  final String reason;

  @override
  Stream<bool> get bufferingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<int> get currentIndexStream => const Stream<int>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<String> get errorStream => Stream<String>.value(reason);

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<Result<void>> dispose() async => const Result.ok(null);

  @override
  Future<Result<void>> jumpTo(int index) async => _failure();

  @override
  Future<Result<void>> loadQueue(
    List<Uri> uris, {
    int initialIndex = 0,
    bool play = false,
  }) async => _failure();

  @override
  Future<Result<void>> next() async => _failure();

  @override
  Future<Result<void>> pause() async => _failure();

  @override
  Future<Result<void>> play() async => _failure();

  @override
  Future<Result<void>> previous() async => _failure();

  @override
  Future<Result<void>> seek(Duration position) async => _failure();

  Result<void> _failure() {
    return Result.err(UnsupportedFailure(reason));
  }
}
