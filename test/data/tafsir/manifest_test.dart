import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/data/tafsir/manifest.dart';

final _validManifest = <String, dynamic>{
  'schemaVersion': 1,
  'dataset': 'tafsir-muyassar',
  'source': {
    'name': 'al-Muyassar',
    'publisher': 'King Fahd Complex for the Printing of the Holy Quran',
    'version': 'King Fahd Complex Madinah-mushaf edition',
    'url': 'https://qurancomplex.gov.sa/',
    'distribution': 'spa5k/tafsir_api',
    'fetchCommit': 'a3499db2c9a6381e77f72ddcc52fe644cab1a77a',
    'fetchEdition': 'ar-tafsir-muyassar',
    'license': 'Free non-commercial redistribution with attribution',
    'retrievedAtUtc': '2026-05-14T00:00:00Z',
  },
  'counts': {'ayahs': 6236},
  'checksums': {'dbSha256': 'a' * 64, 'textSha256': 'b' * 64},
};

void main() {
  group('parseTafsirManifest', () {
    test('parses a valid manifest', () {
      final result = parseTafsirManifest(jsonEncode(_validManifest));
      expect(result.isOk, isTrue);
      final manifest = result.valueOrNull!;
      expect(manifest.schemaVersion, 1);
      expect(manifest.dataset, 'tafsir-muyassar');
      expect(manifest.ayahCount, 6236);
      expect(manifest.dbSha256, 'a' * 64);
      expect(manifest.textSha256, 'b' * 64);
      expect(manifest.source.name, 'al-Muyassar');
      expect(
        manifest.source.publisher,
        'King Fahd Complex for the Printing of the Holy Quran',
      );
      expect(manifest.source.url, 'https://qurancomplex.gov.sa/');
      expect(manifest.source.retrievedAtUtc.isUtc, isTrue);
      expect(manifest.fetchCommit, 'a3499db2c9a6381e77f72ddcc52fe644cab1a77a');
      expect(manifest.fetchEdition, 'ar-tafsir-muyassar');
    });

    test('fails on non-object root', () {
      final result = parseTafsirManifest('"not an object"');
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on missing schemaVersion', () {
      final m = Map<String, dynamic>.from(_validManifest)
        ..remove('schemaVersion');
      final result = parseTafsirManifest(jsonEncode(m));
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on missing source.publisher', () {
      final m = Map<String, dynamic>.from(_validManifest);
      m['source'] = Map<String, dynamic>.from(_validManifest['source']! as Map)
        ..remove('publisher');
      final result = parseTafsirManifest(jsonEncode(m));
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on non-integer counts.ayahs', () {
      final m = Map<String, dynamic>.from(_validManifest);
      m['counts'] = {'ayahs': 'six thousand and change'};
      final result = parseTafsirManifest(jsonEncode(m));
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });

    test('fails on malformed JSON', () {
      final result = parseTafsirManifest('{not json');
      expect(result.failureOrNull, isA<DataIntegrityFailure>());
    });
  });
}
