import '../../domain/audio/reciter.dart';
import '../../domain/quran/ayah.dart';
import '../../domain/quran/quran_search_result.dart';
import '../../domain/quran/quran_source.dart';
import '../../domain/quran/surah.dart';

Map<String, Object?> quranSourceToMcpJson(QuranSource source) => {
  'name': source.name,
  'edition': source.edition,
  'version': source.version,
  'url': source.url,
  'license': source.license,
  'retrievedAtUtc': source.retrievedAtUtc.toIso8601String(),
};

Map<String, Object?> surahToMcpJson(Surah surah) => {
  'number': surah.number,
  'nameArabic': surah.nameArabic,
  'nameLatin': surah.nameLatin,
  'revelation': surah.revelation.name,
  'ayahCount': surah.ayahCount,
};

Map<String, Object?> ayahToMcpJson(Ayah ayah) => {
  'reference': ayah.key.toString(),
  'surah': ayah.key.surah,
  'ayah': ayah.key.ayah,
  'text': ayah.text,
};

Map<String, Object?> searchResultToMcpJson(QuranSearchResult result) => {
  'reference': result.key.toString(),
  'surah': result.key.surah,
  'ayah': result.key.ayah,
  'text': result.text,
  'surahNameArabic': result.surahNameArabic,
  'surahNameLatin': result.surahNameLatin,
};

Map<String, Object?> reciterToMcpJson(Reciter reciter) => {
  'id': reciter.id,
  'sourceId': reciter.sourceId,
  'name': reciter.name,
  'style': reciter.style,
  if (reciter.imageUri != null) 'imageUri': reciter.imageUri.toString(),
};
