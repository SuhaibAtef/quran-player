import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/tafsir/tafsir_source.dart';

const String tafsirManifestAssetPath = 'assets/tafsir/manifest.json';

class TafsirManifest {
  const TafsirManifest({
    required this.schemaVersion,
    required this.dataset,
    required this.source,
    required this.ayahCount,
    required this.dbSha256,
    required this.textSha256,
    required this.fetchCommit,
    required this.fetchEdition,
  });

  final int schemaVersion;
  final String dataset;
  final TafsirSource source;
  final int ayahCount;
  final String dbSha256;
  final String textSha256;
  final String fetchCommit;
  final String fetchEdition;
}

Result<TafsirManifest> parseTafsirManifest(String json) {
  try {
    final raw = jsonDecode(json);
    if (raw is! Map<String, dynamic>) {
      return Result.err(DataIntegrityFailure('manifest is not a JSON object'));
    }

    int requireInt(String key) {
      final v = raw[key];
      if (v is int) return v;
      throw FormatException('missing or non-integer field: $key');
    }

    Map<String, dynamic> requireMap(String key) {
      final v = raw[key];
      if (v is Map<String, dynamic>) return v;
      throw FormatException('missing or non-object field: $key');
    }

    String requireString(Map<String, dynamic> m, String key) {
      final v = m[key];
      if (v is String && v.isNotEmpty) return v;
      throw FormatException('missing or empty field: $key');
    }

    final schemaVersion = requireInt('schemaVersion');
    final dataset = raw['dataset'] is String ? raw['dataset'] as String : '';
    final src = requireMap('source');
    final counts = requireMap('counts');
    final checksums = requireMap('checksums');

    final source = TafsirSource(
      name: requireString(src, 'name'),
      publisher: requireString(src, 'publisher'),
      version: requireString(src, 'version'),
      url: requireString(src, 'url'),
      license: requireString(src, 'license'),
      retrievedAtUtc: DateTime.parse(requireString(src, 'retrievedAtUtc')),
    );

    final ayahCount = counts['ayahs'];
    if (ayahCount is! int) {
      throw const FormatException('counts.ayahs must be an integer');
    }

    return Result.ok(
      TafsirManifest(
        schemaVersion: schemaVersion,
        dataset: dataset,
        source: source,
        ayahCount: ayahCount,
        dbSha256: requireString(checksums, 'dbSha256'),
        textSha256: requireString(checksums, 'textSha256'),
        fetchCommit: src['fetchCommit'] is String
            ? src['fetchCommit'] as String
            : '',
        fetchEdition: src['fetchEdition'] is String
            ? src['fetchEdition'] as String
            : '',
      ),
    );
  } on FormatException catch (e, st) {
    return Result.err(
      DataIntegrityFailure(
        'manifest parse error: ${e.message}',
        cause: e,
        stackTrace: st,
      ),
    );
  } catch (e, st) {
    return Result.err(
      DataIntegrityFailure(
        'manifest parse error: $e',
        cause: e,
        stackTrace: st,
      ),
    );
  }
}

Future<Result<TafsirManifest>> loadTafsirManifestFromBundle(
  AssetBundle bundle, {
  String assetPath = tafsirManifestAssetPath,
}) async {
  try {
    final raw = await bundle.loadString(assetPath);
    return parseTafsirManifest(raw);
  } catch (e, st) {
    return Result.err(
      DataAccessFailure(
        'failed to load tafsir manifest from bundle: $e',
        cause: e,
        stackTrace: st,
      ),
    );
  }
}
