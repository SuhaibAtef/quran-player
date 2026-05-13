import 'package:flutter_test/flutter_test.dart';
import 'package:quran_player/domain/audio/audio_playback_state.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/features/player/playback/fake_audio_playback_engine.dart';
import 'package:quran_player/features/player/state/audio_player_controller.dart';

import '../../_fakes/fake_audio_repository.dart';

void main() {
  test('loads queue, plays, pauses, seeks, and exposes active ayah', () async {
    final engine = FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(
      repository: FakeAudioRepository(),
      engine: engine,
    );
    addTearDown(controller.dispose);

    await controller.startSurah(1);
    expect(controller.state.status, AudioPlayerStatus.playing);
    expect(controller.state.queue.length, 3);
    expect(controller.state.currentItem?.track.ayahKey, AyahKey(1, 1));
    expect(engine.loadedQueue, hasLength(3));
    expect(engine.loadQueueCalls, 1);

    await controller.pause();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AudioPlayerStatus.paused);

    await controller.play();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AudioPlayerStatus.playing);

    await controller.seek(const Duration(seconds: 2));
    expect(engine.lastSeek, const Duration(seconds: 2));
  });

  test('next, previous, completion, and clear update queue state', () async {
    final engine = FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(
      repository: FakeAudioRepository(),
      engine: engine,
    );
    addTearDown(controller.dispose);

    await controller.startSurah(1);
    await controller.next();
    expect(controller.state.currentItem?.track.ayahKey, AyahKey(1, 2));
    expect(engine.loadQueueCalls, 1);

    await controller.previous();
    expect(controller.state.currentItem?.track.ayahKey, AyahKey(1, 1));
    expect(engine.loadQueueCalls, 1);

    await controller.jumpTo(2);
    engine.emitCompleted();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, AudioPlayerStatus.completed);

    await controller.clear();
    expect(controller.state.status, AudioPlayerStatus.idle);
    expect(controller.state.currentItem, isNull);
  });
}
