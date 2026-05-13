import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/domain/audio/audio_queue_item.dart';
import 'package:quran_player/domain/audio/audio_repository.dart';
import 'package:quran_player/domain/audio/audio_source_attribution.dart';
import 'package:quran_player/domain/audio/audio_track.dart';
import 'package:quran_player/domain/audio/reciter.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

class FakeAudioRepository implements AudioRepository {
  FakeAudioRepository({List<AudioQueueItem>? queue})
    : queue = queue ?? defaultQueue;

  final List<AudioQueueItem> queue;

  static const reciter = Reciter(
    id: 'test-reciter',
    sourceId: 7,
    name: 'Test Reciter',
    style: 'Murattal',
  );

  static const attribution = AudioSourceAttribution(
    providerName: 'Test Audio',
    providerUrl: 'https://example.test',
    terms: 'test terms',
    attribution: 'test attribution',
    requiresAuth: false,
  );

  static final defaultQueue = <AudioQueueItem>[
    _item(AyahKey(1, 1), 'Al-Fatihah 1:1'),
    _item(AyahKey(1, 2), 'Al-Fatihah 1:2'),
    _item(AyahKey(1, 3), 'Al-Fatihah 1:3'),
  ];

  @override
  Future<Result<AudioTrack>> getAyahAudio(AyahKey key, String reciterId) async {
    for (final item in queue) {
      if (item.track.ayahKey == key) return Result.ok(item.track);
    }
    return const Result.err(DataAccessFailure('missing audio'));
  }

  @override
  Future<Result<Reciter>> getDefaultReciter() async => Result.ok(reciter);

  @override
  Future<Result<List<AudioQueueItem>>> getSurahAudioQueue(
    int surahNumber,
    String reciterId,
  ) async {
    return Result.ok(
      queue.where((i) => i.track.ayahKey.surah == surahNumber).toList(),
    );
  }

  @override
  Future<Result<AudioSourceAttribution>> getSourceAttribution() async {
    return Result.ok(attribution);
  }
}

AudioQueueItem _item(AyahKey key, String label) {
  return AudioQueueItem(
    track: AudioTrack(
      id: 'track-$key',
      ayahKey: key,
      reciterId: FakeAudioRepository.reciter.id,
      uri: Uri.parse('https://example.test/$key.mp3'),
      sourceUrl: '$key.mp3',
      duration: const Duration(seconds: 3),
      format: 'mp3',
    ),
    surahName: 'Al-Fatihah',
    label: label,
  );
}
