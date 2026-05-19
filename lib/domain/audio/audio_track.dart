import '../quran/ayah_key.dart';

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.ayahKey,
    required this.reciterId,
    required this.uri,
    required this.sourceUrl,
    this.duration,
    this.format,
  });

  final String id;
  final AyahKey ayahKey;
  final String reciterId;
  final Uri uri;
  final String sourceUrl;
  final Duration? duration;
  final String? format;
}
