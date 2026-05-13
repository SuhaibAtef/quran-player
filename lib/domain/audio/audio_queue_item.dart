import 'audio_track.dart';

class AudioQueueItem {
  const AudioQueueItem({
    required this.track,
    required this.surahName,
    required this.label,
  });

  final AudioTrack track;
  final String surahName;
  final String label;
}
