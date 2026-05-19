import 'package:flutter_test/flutter_test.dart';

import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';

void main() {
  group('AyahKey.parse', () {
    test('round-trips a valid input', () {
      final result = AyahKey.parse('2:255');
      expect(result, isA<Ok<AyahKey>>());
      final key = (result as Ok<AyahKey>).value;
      expect(key.surah, 2);
      expect(key.ayah, 255);
      expect(key.toString(), '2:255');
    });

    test('handles whitespace', () {
      final result = AyahKey.parse('  1:1 ');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, equals(AyahKey(1, 1)));
    });

    test('rejects surah = 0', () {
      final result = AyahKey.parse('0:1');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<InvalidInputFailure>());
    });

    test('rejects surah > 114', () {
      final result = AyahKey.parse('115:1');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<InvalidInputFailure>());
    });

    test('rejects ayah = 0', () {
      final result = AyahKey.parse('2:0');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<InvalidInputFailure>());
    });

    test('rejects malformed strings', () {
      for (final input in const ['', 'abc', '2', '2:', ':255', '2:255:1']) {
        final result = AyahKey.parse(input);
        expect(result.isErr, isTrue, reason: '"$input" should fail to parse');
      }
    });

    test('rejects non-integer parts', () {
      final result = AyahKey.parse('two:five');
      expect(result.isErr, isTrue);
    });
  });

  group('AyahKey constructor', () {
    test('throws on out-of-range surah', () {
      expect(() => AyahKey(0, 1), throwsArgumentError);
      expect(() => AyahKey(115, 1), throwsArgumentError);
    });

    test('throws on out-of-range ayah', () {
      expect(() => AyahKey(1, 0), throwsArgumentError);
    });

    test('equality and hashCode', () {
      expect(AyahKey(2, 255), equals(AyahKey(2, 255)));
      expect(AyahKey(2, 255).hashCode, AyahKey(2, 255).hashCode);
      expect(AyahKey(2, 255), isNot(equals(AyahKey(2, 256))));
    });
  });

  group('AyahKey.tryNew', () {
    test('returns Ok for valid pair', () {
      final r = AyahKey.tryNew(2, 255);
      expect(r.isOk, isTrue);
    });

    test('returns InvalidInputFailure for invalid pair', () {
      final r = AyahKey.tryNew(0, 1);
      expect(r.failureOrNull, isA<InvalidInputFailure>());
    });
  });
}
