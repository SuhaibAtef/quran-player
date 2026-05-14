import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/tafsir/integrity_checker.dart';
import 'package:quran_player/data/tafsir/manifest.dart';
import 'package:quran_player/data/tafsir/providers.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/tafsir/tafsir.dart';
import 'package:quran_player/domain/tafsir/tafsir_repository.dart';
import 'package:quran_player/domain/tafsir/tafsir_source.dart';

/// In-memory tafsir repository for widget tests. Returns a stub for any ayah
/// key so callers exercising the repository surface don't NPE.
class FakeTafsirRepository implements TafsirRepository {
  FakeTafsirRepository({TafsirSource? source})
    : _source = source ?? _defaultSource;

  static final TafsirSource _defaultSource = TafsirSource(
    name: 'TestTafsir',
    publisher: 'Test Publisher',
    version: 'test',
    url: 'about:blank',
    license: 'test',
    retrievedAtUtc: DateTime.utc(2026, 1, 1),
  );

  final TafsirSource _source;

  @override
  Future<Result<Tafsir>> getTafsirForAyah(AyahKey key) async =>
      Result.ok(Tafsir(key: key, text: 'fake tafsir for $key'));

  @override
  Future<Result<List<Tafsir>>> getTafsirForSurah(int number) async {
    if (number < 1 || number > 114) {
      return Result.err(
        NotFoundFailure('surah $number out of range', key: 'surah=$number'),
      );
    }
    return Result.ok([
      Tafsir(key: AyahKey(number, 1), text: 'fake tafsir for $number:1'),
    ]);
  }

  @override
  Future<Result<TafsirSource>> getSource() async => Result.ok(_source);
}

TafsirBootstrap fakeTafsirBootstrap() {
  final manifest = TafsirManifest(
    schemaVersion: 1,
    dataset: 'tafsir-muyassar',
    source: FakeTafsirRepository._defaultSource,
    ayahCount: 6236,
    dbSha256: '0' * 64,
    textSha256: '0' * 64,
    fetchCommit: 'test',
    fetchEdition: 'test',
  );
  return TafsirBootstrap(
    repository: FakeTafsirRepository(),
    manifest: manifest,
    report: const TafsirIntegrityReport(dbSha256: 'fake', skippedHash: true),
  );
}
