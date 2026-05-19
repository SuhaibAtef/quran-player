import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../core/error/result.dart';
import '../../../data/audio/providers.dart';
import '../../../domain/audio/audio_playback_state.dart';
import '../../../domain/audio/audio_queue_item.dart';
import '../../../domain/audio/audio_repository.dart';
import '../../../domain/quran/ayah_key.dart';
import '../playback/audio_playback_engine.dart';
import '../playback/media_kit_audio_playback_engine.dart';
import '../playback/unavailable_audio_playback_engine.dart';

final audioPlaybackEngineProvider = Provider<AudioPlaybackEngine>((ref) {
  late final AudioPlaybackEngine engine;
  try {
    MediaKit.ensureInitialized();
    engine = MediaKitAudioPlaybackEngine();
  } on Object catch (e) {
    engine = UnavailableAudioPlaybackEngine('$e');
  }
  ref.onDispose(engine.dispose);
  return engine;
});

final audioPlayerControllerProvider =
    StateNotifierProvider<AudioPlayerController, AudioPlaybackState>((ref) {
      return AudioPlayerController(
        repository: ref.watch(audioRepositoryProvider),
        engine: ref.watch(audioPlaybackEngineProvider),
      );
    });

final activePlaybackAyahProvider = Provider<AyahKey?>((ref) {
  final item = ref.watch(audioPlayerControllerProvider).currentItem;
  return item?.track.ayahKey;
});

class AudioPlayerController extends StateNotifier<AudioPlaybackState> {
  AudioPlayerController({
    required AudioRepository repository,
    required AudioPlaybackEngine engine,
  }) : _repository = repository,
       _engine = engine,
       super(const AudioPlaybackState.idle()) {
    _subscriptions = [
      _engine.positionStream.listen(_onPosition),
      _engine.durationStream.listen(_onDuration),
      _engine.playingStream.listen(_onPlaying),
      _engine.bufferingStream.listen(_onBuffering),
      _engine.completedStream.listen(_onCompleted),
      _engine.errorStream.listen(_onError),
      _engine.currentIndexStream.listen(_onCurrentIndex),
    ];
  }

  final AudioRepository _repository;
  final AudioPlaybackEngine _engine;
  late final List<StreamSubscription<Object?>> _subscriptions;

  Future<void> startSurah(int surahNumber) async {
    state = state.copyWith(
      status: AudioPlayerStatus.loading,
      message: 'Loading audio...',
    );
    final reciterResult = await _repository.getDefaultReciter();
    if (reciterResult is Err) {
      _fail((reciterResult as Err).failure.message);
      return;
    }
    final reciter = (reciterResult as Ok).value;
    final queueResult = await _repository.getSurahAudioQueue(
      surahNumber,
      reciter.id as String,
    );
    if (queueResult is Err<List<AudioQueueItem>>) {
      _fail(queueResult.failure.message);
      return;
    }
    final queue = (queueResult as Ok<List<AudioQueueItem>>).value;
    if (queue.isEmpty) {
      _fail('No audio found for this surah');
      return;
    }
    state = AudioPlaybackState(
      status: AudioPlayerStatus.loading,
      queue: queue,
      currentIndex: 0,
      position: Duration.zero,
      duration: queue.first.track.duration,
      reciter: reciter,
    );
    await _loadCurrent(play: true);
  }

  Future<void> startAyah(AyahKey key) async {
    state = state.copyWith(
      status: AudioPlayerStatus.loading,
      message: 'Loading audio...',
    );
    final reciterResult = await _repository.getDefaultReciter();
    if (reciterResult is Err) {
      _fail((reciterResult as Err).failure.message);
      return;
    }
    final reciter = (reciterResult as Ok).value;
    final queueResult = await _repository.getSurahAudioQueue(
      key.surah,
      reciter.id as String,
    );
    if (queueResult is Err<List<AudioQueueItem>>) {
      _fail(queueResult.failure.message);
      return;
    }
    final queue = (queueResult as Ok<List<AudioQueueItem>>).value;
    final index = queue.indexWhere((i) => i.track.ayahKey == key);
    if (index < 0) {
      _fail('No audio found for $key');
      return;
    }
    state = AudioPlaybackState(
      status: AudioPlayerStatus.loading,
      queue: queue,
      currentIndex: index,
      position: Duration.zero,
      duration: queue[index].track.duration,
      reciter: reciter,
    );
    await _loadCurrent(play: true);
  }

  Future<void> play() async {
    if (!state.hasQueue) return;
    final result = await _engine.play();
    if (result is Err<void>) _fail(result.failure.message);
  }

  Future<void> pause() async {
    if (!state.hasQueue) return;
    final result = await _engine.pause();
    if (result is Err<void>) _fail(result.failure.message);
  }

  Future<void> seek(Duration position) async {
    if (!state.hasQueue) return;
    final result = await _engine.seek(position);
    if (result is Err<void>) _fail(result.failure.message);
  }

  Future<void> next() async {
    if (!state.canGoNext) return;
    state = state.copyWith(
      status: AudioPlayerStatus.loading,
      currentIndex: state.currentIndex + 1,
      position: Duration.zero,
      duration: state.queue[state.currentIndex + 1].track.duration,
      clearMessage: true,
    );
    final result = await _engine.next();
    if (result is Err<void>) {
      _fail(result.failure.message);
      return;
    }
    state = state.copyWith(status: AudioPlayerStatus.playing);
  }

  Future<void> previous() async {
    if (!state.canGoPrevious) return;
    state = state.copyWith(
      status: AudioPlayerStatus.loading,
      currentIndex: state.currentIndex - 1,
      position: Duration.zero,
      duration: state.queue[state.currentIndex - 1].track.duration,
      clearMessage: true,
    );
    final result = await _engine.previous();
    if (result is Err<void>) {
      _fail(result.failure.message);
      return;
    }
    state = state.copyWith(status: AudioPlayerStatus.playing);
  }

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(
      status: AudioPlayerStatus.loading,
      currentIndex: index,
      position: Duration.zero,
      duration: state.queue[index].track.duration,
      clearMessage: true,
    );
    final result = await _engine.jumpTo(index);
    if (result is Err<void>) {
      _fail(result.failure.message);
      return;
    }
    state = state.copyWith(status: AudioPlayerStatus.playing);
  }

  Future<void> clear() async {
    await _engine.pause();
    state = const AudioPlaybackState.idle();
  }

  Future<void> _loadCurrent({required bool play}) async {
    if (state.queue.isEmpty) return;
    final result = await _engine.loadQueue(
      state.queue.map((item) => item.track.uri).toList(growable: false),
      initialIndex: state.currentIndex,
      play: play,
    );
    if (result is Err<void>) {
      _fail(result.failure.message);
      return;
    }
    state = state.copyWith(
      status: play ? AudioPlayerStatus.playing : AudioPlayerStatus.paused,
      position: Duration.zero,
      duration: state.queue[state.currentIndex].track.duration,
      clearMessage: true,
    );
  }

  void _onCurrentIndex(int index) {
    if (!state.hasQueue || index < 0 || index >= state.queue.length) return;
    if (index == state.currentIndex) return;
    state = state.copyWith(
      currentIndex: index,
      position: Duration.zero,
      duration: state.queue[index].track.duration,
      status: AudioPlayerStatus.playing,
      clearMessage: true,
    );
  }

  void _onPosition(Duration position) {
    if (!state.hasQueue) return;
    state = state.copyWith(position: position);
  }

  void _onDuration(Duration duration) {
    if (!state.hasQueue) return;
    state = state.copyWith(duration: duration);
  }

  void _onPlaying(bool playing) {
    if (!state.hasQueue) return;
    state = state.copyWith(
      status: playing ? AudioPlayerStatus.playing : AudioPlayerStatus.paused,
      clearMessage: true,
    );
  }

  void _onBuffering(bool buffering) {
    if (!state.hasQueue) return;
    if (buffering) {
      state = state.copyWith(status: AudioPlayerStatus.buffering);
    }
  }

  void _onCompleted(bool completed) {
    if (!completed || !state.hasQueue) return;
    state = state.copyWith(status: AudioPlayerStatus.completed);
  }

  void _onError(String error) {
    if (error.isEmpty) return;
    _fail(error);
  }

  void _fail(String message) {
    state = state.copyWith(status: AudioPlayerStatus.error, message: message);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
