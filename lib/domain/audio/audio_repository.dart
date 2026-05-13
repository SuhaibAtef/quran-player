import '../../core/error/result.dart';
import '../quran/ayah_key.dart';
import 'audio_queue_item.dart';
import 'audio_source_attribution.dart';
import 'audio_track.dart';
import 'reciter.dart';

abstract class AudioRepository {
  Future<Result<Reciter>> getDefaultReciter();

  Future<Result<AudioSourceAttribution>> getSourceAttribution();

  Future<Result<AudioTrack>> getAyahAudio(AyahKey key, String reciterId);

  Future<Result<List<AudioQueueItem>>> getSurahAudioQueue(
    int surahNumber,
    String reciterId,
  );
}
