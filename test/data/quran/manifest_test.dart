import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/data/quran/manifest.dart';

final _validManifest = <String, dynamic>{
  'schemaVersion': 1,
  'source': {
    'name': 'Tanzil',
    'edition': 'Uthmani',
    'version': '1.0.2',
    'url': 'https://tanzil.net/download/',
    'distribution': 'Distributed via Islamic Network alquran.cloud API.',
    'fetchUrl': 'https://api.alquran.cloud/v1/quran/quran-uthmani',
    'license': 'Tanzil license',
    'retrievedAtUtc': '2026-05-09T00:00:00Z',
  },
  'counts': {'surahs': 114, 'ayahs': 6236},
  'checksums': {'dbSha256': 'a' * 64, 'textSha256': 'b' * 64},
};

void main() {
  group('parseManifest', () {
    test('parses a valid manifest', () {
      final result = parseManifest(jsonEncode(_validManifest));
      expect(result.isOk, isTrue);
      final manifest = result.valueOrNull!;
      expect(manifest.schemaVersion, 1);
      expect(manifest.surahCount, 114);
      expect(manifest.ayahCount, 6236);
      expect(manifest.dbSha256, 'a' * 64);
      expect(manifest.textSha256, 'b' * 64);
      expect(manifest.source.name, 'Tanzil');
      expect(manifest.source.edition, 'Uthmani');
      expect(manifest.source.version, '1.0.2');
      expect(
        manifest.source.retrievedAtUtc.isUtc,
        isTrue,
        reason: 'retrievedAtUtc should parse as a UTC DateTime',
      );
      expect(
        manifest.fetchUrl,
        'https://api.alquran.cloud/v1/quran/quran-uthmani',
      );
    });

    test('fails on non-object root', () {
      final result = parseManifest('"not an object"');
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on missing schemaVersion', () {
      final m = Map<String, dynamic>.from(_validManifest)
        ..remove('schemaVersion');
      final result = parseManifest(jsonEncode(m));
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on missing source.name', () {
      final m = Map<String, dynamic>.from(_validManifest);
      m['source'] = Map<String, dynamic>.from(_validManifest['source']! as Map)
        ..remove('name');
      final result = parseManifest(jsonEncode(m));
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on non-integer counts', () {
      final m = Map<String, dynamic>.from(_validManifest);
      m['counts'] = {'surahs': 'one hundred fourteen', 'ayahs': 6236};
      final result = parseManifest(jsonEncode(m));
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on malformed JSON', () {
      final result = parseManifest('{not json');
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });
  });
}
