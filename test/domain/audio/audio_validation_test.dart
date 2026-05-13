import 'package:flutter_test/flutter_test.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/domain/audio/audio_validation.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

void main() {
  test('validatePlayableUri resolves relative API URLs against base URI', () {
    final result = validatePlayableUri(
      'Alafasy/mp3/001001.mp3',
      baseUri: Uri.parse('https://verses.quran.foundation/'),
    );

    expect(result, isA<Ok<Uri>>());
    expect(
      (result as Ok<Uri>).value.toString(),
      'https://verses.quran.foundation/Alafasy/mp3/001001.mp3',
    );
  });

  test('validateSourceVerseKey rejects mismatched source keys', () {
    final result = validateSourceVerseKey('2:255', expected: AyahKey(1, 1));

    expect(result, isA<Err<AyahKey>>());
    expect((result as Err<AyahKey>).failure, isA<DataIntegrityFailure>());
  });
}
