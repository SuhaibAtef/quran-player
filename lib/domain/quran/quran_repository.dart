import '../../core/error/result.dart';
import 'ayah.dart';
import 'ayah_key.dart';
import 'quran_source.dart';
import 'quran_search_result.dart';
import 'surah.dart';

abstract class QuranRepository {
  Future<Result<List<Surah>>> listSurahs();

  Future<Result<Surah>> getSurah(int number);

  Future<Result<List<Ayah>>> getSurahAyahs(int number);

  Future<Result<Ayah>> getAyah(AyahKey key);

  Future<Result<List<QuranSearchResult>>> searchAyahs(
    String query, {
    int limit = 50,
  });

  Future<Result<QuranSource>> getSource();
}
