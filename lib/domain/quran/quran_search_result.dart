import 'ayah_key.dart';

class QuranSearchResult {
  const QuranSearchResult({
    required this.key,
    required this.text,
    required this.surahNameArabic,
    required this.surahNameLatin,
  });

  final AyahKey key;
  final String text;
  final String surahNameArabic;
  final String surahNameLatin;
}
