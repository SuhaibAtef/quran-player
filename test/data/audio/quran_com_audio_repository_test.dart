import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/audio/quran_com_audio_api_client.dart';
import 'package:quran_player/data/audio/quran_com_audio_repository.dart';
import 'package:quran_player/data/audio/quran_com_audio_source.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

import '../../_fakes/fake_quran_repository.dart';

void main() {
  test('maps healthy surah audio response into ordered queue', () async {
    final repo = QuranComAudioRepository(
      quranRepository: FakeQuranRepository(
        ayahs: {
          for (var i = 1; i <= 7; i++)
            AyahKey(1, i): Ayah(key: AyahKey(1, i), text: 'ayah $i'),
        },
      ),
      apiClient: QuranComAudioApiClient(
        client: MockClient((request) async {
          return http.Response('''
{
  "audio_files": [
    {"verse_key":"1:1","url":"Alafasy/mp3/001001.mp3","duration":6,"format":"mp3","id":1},
    {"verse_key":"1:2","url":"Alafasy/mp3/001002.mp3","duration":5,"format":"mp3","id":2},
    {"verse_key":"1:3","url":"Alafasy/mp3/001003.mp3","duration":4,"format":"mp3","id":3},
    {"verse_key":"1:4","url":"Alafasy/mp3/001004.mp3","duration":4,"format":"mp3","id":4},
    {"verse_key":"1:5","url":"Alafasy/mp3/001005.mp3","duration":6,"format":"mp3","id":5},
    {"verse_key":"1:6","url":"Alafasy/mp3/001006.mp3","duration":5,"format":"mp3","id":6},
    {"verse_key":"1:7","url":"Alafasy/mp3/001007.mp3","duration":13,"format":"mp3","id":7}
  ]
}
''', 200);
        }),
      ),
    );

    final result = await repo.getSurahAudioQueue(
      1,
      QuranComAudioSource.defaultReciter.id,
    );

    expect(result, isA<Ok<List>>());
    final queue = (result as Ok<List>).value;
    expect(queue.length, 7);
    expect(queue.first.track.ayahKey, AyahKey(1, 1));
    expect(
      queue.first.track.uri.toString(),
      contains('verses.quran.foundation'),
    );
  });

  test('rejects mismatched source verse keys', () async {
    final repo = QuranComAudioRepository(
      quranRepository: FakeQuranRepository(
        ayahs: {AyahKey(1, 1): Ayah(key: AyahKey(1, 1), text: 'ayah')},
      ),
      apiClient: QuranComAudioApiClient(
        client: MockClient((request) async {
          return http.Response('''
{"audio_files":[{"verse_key":"2:1","url":"x.mp3","id":1}]}
''', 200);
        }),
      ),
    );

    final result = await repo.getSurahAudioQueue(
      1,
      QuranComAudioSource.defaultReciter.id,
    );

    expect(result, isA<Err<List>>());
    expect((result as Err<List>).failure, isA<DataIntegrityFailure>());
  });

  test('network failures return recoverable failure', () async {
    final client = QuranComAudioApiClient(
      client: MockClient((request) async => http.Response('too many', 429)),
    );

    final result = await client.getSurahRecitation(
      sourceRecitationId: QuranComAudioSource.defaultReciter.sourceId,
      chapterNumber: 1,
      page: 1,
    );

    expect(result, isA<Err<Map<String, Object?>>>());
    expect(
      (result as Err<Map<String, Object?>>).failure,
      isA<NetworkFailure>(),
    );
  });
}
