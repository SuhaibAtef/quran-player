import '../../domain/audio/audio_source_attribution.dart';
import '../../domain/audio/reciter.dart';

class QuranComAudioSource {
  const QuranComAudioSource._();

  static final apiBaseUri = Uri.parse('https://api.quran.com/api/v4/');
  static final verseAudioBaseUri = Uri.parse(
    'https://verses.quran.foundation/',
  );

  static const defaultReciter = Reciter(
    id: 'quran-com-9',
    sourceId: 9,
    name: 'Mohamed Siddiq al-Minshawi',
    style: 'Murattal',
  );

  static const attribution = AudioSourceAttribution(
    providerName: 'Quran.com / Quran Foundation',
    providerUrl: 'https://api-docs.quran.com/',
    terms: 'Public Quran Foundation content API; no client secret is embedded.',
    attribution:
        'Verse audio is streamed from Quran.com / Quran Foundation public '
        'content APIs. Default reciter: Mohamed Siddiq al-Minshawi.',
    requiresAuth: false,
  );
}
