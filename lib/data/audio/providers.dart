import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/audio_repository.dart';
import '../quran/providers.dart';
import 'quran_com_audio_api_client.dart';
import 'quran_com_audio_repository.dart';

final quranComAudioApiClientProvider = Provider<QuranComAudioApiClient>((ref) {
  return QuranComAudioApiClient();
});

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return QuranComAudioRepository(
    quranRepository: ref.watch(quranRepositoryProvider),
    apiClient: ref.watch(quranComAudioApiClientProvider),
  );
});
