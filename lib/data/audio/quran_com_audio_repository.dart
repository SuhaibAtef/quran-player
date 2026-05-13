import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/audio/audio_queue_item.dart';
import '../../domain/audio/audio_repository.dart';
import '../../domain/audio/audio_source_attribution.dart';
import '../../domain/audio/audio_track.dart';
import '../../domain/audio/audio_validation.dart';
import '../../domain/audio/reciter.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/quran_repository.dart';
import 'quran_com_audio_api_client.dart';
import 'quran_com_audio_source.dart';

class QuranComAudioRepository implements AudioRepository {
  QuranComAudioRepository({
    required QuranRepository quranRepository,
    required QuranComAudioApiClient apiClient,
    Uri? verseAudioBaseUri,
  }) : _quranRepository = quranRepository,
       _apiClient = apiClient,
       _verseAudioBaseUri =
           verseAudioBaseUri ?? QuranComAudioSource.verseAudioBaseUri;

  final QuranRepository _quranRepository;
  final QuranComAudioApiClient _apiClient;
  final Uri _verseAudioBaseUri;

  @override
  Future<Result<Reciter>> getDefaultReciter() async {
    return const Result.ok(QuranComAudioSource.defaultReciter);
  }

  @override
  Future<Result<AudioSourceAttribution>> getSourceAttribution() async {
    return const Result.ok(QuranComAudioSource.attribution);
  }

  @override
  Future<Result<AudioTrack>> getAyahAudio(AyahKey key, String reciterId) async {
    final reciterResult = _resolveReciter(reciterId);
    if (reciterResult is Err<Reciter>) return Result.err(reciterResult.failure);
    final reciter = (reciterResult as Ok<Reciter>).value;
    final queueResult = await getSurahAudioQueue(key.surah, reciter.id);
    if (queueResult is Err<List<AudioQueueItem>>) {
      return Result.err(queueResult.failure);
    }
    final queue = (queueResult as Ok<List<AudioQueueItem>>).value;
    for (final item in queue) {
      if (item.track.ayahKey == key) return Result.ok(item.track);
    }
    return Result.err(NotFoundFailure('audio not found for $key', key: '$key'));
  }

  @override
  Future<Result<List<AudioQueueItem>>> getSurahAudioQueue(
    int surahNumber,
    String reciterId,
  ) async {
    if (surahNumber < 1 || surahNumber > 114) {
      return Result.err(
        InvalidInputFailure('surah out of range: $surahNumber'),
      );
    }
    final reciterResult = _resolveReciter(reciterId);
    if (reciterResult is Err<Reciter>) {
      return Result.err(reciterResult.failure);
    }
    final reciter = (reciterResult as Ok<Reciter>).value;

    final surahResult = await _quranRepository.getSurah(surahNumber);
    if (surahResult is Err) {
      return Result.err((surahResult as Err).failure);
    }
    final surah = (surahResult as Ok).value;

    final ayahsResult = await _quranRepository.getSurahAyahs(surahNumber);
    if (ayahsResult is Err) {
      return Result.err((ayahsResult as Err).failure);
    }
    final expectedKeys = (ayahsResult as Ok).value
        .map<AyahKey>((a) => a.key as AyahKey)
        .toList(growable: false);

    final items = <AudioQueueItem>[];
    var page = 1;
    while (true) {
      final response = await _apiClient.getSurahRecitation(
        sourceRecitationId: reciter.sourceId,
        chapterNumber: surahNumber,
        page: page,
      );
      if (response is Err<Map<String, Object?>>) {
        return Result.err(response.failure);
      }
      final parsed = _parsePage(
        (response as Ok<Map<String, Object?>>).value,
        reciter: reciter,
        surahName: surah.nameLatin as String,
      );
      if (parsed is Err<_ParsedAudioPage>) return Result.err(parsed.failure);
      final pageData = (parsed as Ok<_ParsedAudioPage>).value;
      items.addAll(pageData.items);
      if (pageData.nextPage == null) break;
      page = pageData.nextPage!;
      if (page < 1 || page > 200) {
        return const Result.err(
          DataAccessFailure('audio API pagination did not terminate'),
        );
      }
    }

    return validateQueueOrder(items, expectedKeys);
  }

  Result<Reciter> _resolveReciter(String reciterId) {
    if (reciterId == QuranComAudioSource.defaultReciter.id) {
      return const Result.ok(QuranComAudioSource.defaultReciter);
    }
    return Result.err(NotFoundFailure('unknown reciter: $reciterId'));
  }

  Result<_ParsedAudioPage> _parsePage(
    Map<String, Object?> json, {
    required Reciter reciter,
    required String surahName,
  }) {
    final rawFiles = json['audio_files'];
    if (rawFiles is! List) {
      return const Result.err(
        DataAccessFailure('audio API response missing audio_files'),
      );
    }
    final items = <AudioQueueItem>[];
    for (final raw in rawFiles) {
      if (raw is! Map<String, Object?>) {
        return const Result.err(
          DataAccessFailure('audio API audio_files entry is not an object'),
        );
      }
      final verseKey = raw['verse_key'];
      final url = raw['url'];
      if (verseKey is! String || url is! String) {
        return const Result.err(
          DataAccessFailure('audio file missing verse_key or url'),
        );
      }
      final keyResult = validateSourceVerseKey(verseKey);
      if (keyResult is Err<AyahKey>) return Result.err(keyResult.failure);
      final key = (keyResult as Ok<AyahKey>).value;
      final uriResult = validatePlayableUri(url, baseUri: _verseAudioBaseUri);
      if (uriResult is Err<Uri>) return Result.err(uriResult.failure);
      final uri = (uriResult as Ok<Uri>).value;
      final durationSeconds = raw['duration'];
      final duration = durationSeconds is num
          ? Duration(milliseconds: (durationSeconds * 1000).round())
          : null;
      final format = raw['format'];
      final id = raw['id'];
      final track = AudioTrack(
        id: id == null ? '${reciter.id}-$key' : '${reciter.id}-$id',
        ayahKey: key,
        reciterId: reciter.id,
        uri: uri,
        sourceUrl: url,
        duration: duration,
        format: format is String ? format : null,
      );
      items.add(
        AudioQueueItem(
          track: track,
          surahName: surahName,
          label: '$surahName ${key.surah}:${key.ayah}',
        ),
      );
    }

    final pagination = json['pagination'];
    final meta = json['meta'];
    Object? nextPage;
    if (pagination is Map<String, Object?>) {
      nextPage = pagination['next_page'];
    } else if (meta is Map<String, Object?>) {
      nextPage = meta['next_page'];
    }
    return Result.ok(
      _ParsedAudioPage(
        items: items,
        nextPage: nextPage is num ? nextPage.toInt() : null,
      ),
    );
  }
}

class _ParsedAudioPage {
  const _ParsedAudioPage({required this.items, required this.nextPage});

  final List<AudioQueueItem> items;
  final int? nextPage;
}
