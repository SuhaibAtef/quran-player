import '../../core/error/result.dart';
import '../quran/ayah_key.dart';
import 'tafsir.dart';
import 'tafsir_source.dart';

abstract class TafsirRepository {
  Future<Result<Tafsir>> getTafsirForAyah(AyahKey key);

  Future<Result<List<Tafsir>>> getTafsirForSurah(int number);

  Future<Result<TafsirSource>> getSource();
}
