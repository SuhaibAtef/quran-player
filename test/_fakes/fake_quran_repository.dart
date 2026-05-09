import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_repository.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/domain/quran/surah.dart';

/// Minimal in-memory repository for widget tests. The shape is correct; the
/// data is fixture-only and intentionally tiny.
class FakeQuranRepository implements QuranRepository {
  FakeQuranRepository({
    List<Surah>? surahs,
    Map<AyahKey, Ayah>? ayahs,
    QuranSource? source,
  }) : _surahs = surahs ?? _defaultSurahs,
       _ayahs = ayahs ?? const {},
       _source = source ?? _defaultSource;

  final List<Surah> _surahs;
  final Map<AyahKey, Ayah> _ayahs;
  final QuranSource _source;

  static final QuranSource _defaultSource = QuranSource(
    name: 'TestSource',
    edition: 'test',
    version: '0',
    url: 'about:blank',
    license: 'test',
    retrievedAtUtc: DateTime.utc(2026, 1, 1),
  );

  static const List<Surah> _defaultSurahs = [
    Surah(
      number: 1,
      nameArabic: 'الفاتحة',
      nameLatin: 'Al-Fatihah',
      revelation: Revelation.meccan,
      ayahCount: 7,
    ),
    Surah(
      number: 2,
      nameArabic: 'البقرة',
      nameLatin: 'Al-Baqarah',
      revelation: Revelation.medinan,
      ayahCount: 286,
    ),
  ];

  @override
  Future<Result<List<Surah>>> listSurahs() async => Result.ok(_surahs);

  @override
  Future<Result<Surah>> getSurah(int number) async {
    final s = _surahs
        .where((e) => e.number == number)
        .cast<Surah?>()
        .firstWhere((_) => true, orElse: () => null);
    if (s == null) {
      return Result.err(NotFoundFailure('surah $number not in fake'));
    }
    return Result.ok(s);
  }

  @override
  Future<Result<List<Ayah>>> getSurahAyahs(int number) async {
    final list = _ayahs.entries
        .where((e) => e.key.surah == number)
        .map((e) => e.value)
        .toList();
    if (list.isEmpty) {
      return Result.err(NotFoundFailure('no ayahs in fake for surah $number'));
    }
    return Result.ok(list);
  }

  @override
  Future<Result<Ayah>> getAyah(AyahKey key) async {
    final a = _ayahs[key];
    if (a == null) return Result.err(NotFoundFailure('ayah $key not in fake'));
    return Result.ok(a);
  }

  @override
  Future<Result<QuranSource>> getSource() async => Result.ok(_source);
}
