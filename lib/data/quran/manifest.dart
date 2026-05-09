import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/quran/quran_source.dart';

const String quranManifestAssetPath = 'assets/quran/manifest.json';

class QuranManifest {
  const QuranManifest({
    required this.schemaVersion,
    required this.source,
    required this.surahCount,
    required this.ayahCount,
    required this.dbSha256,
    required this.textSha256,
    required this.fetchUrl,
  });

  final int schemaVersion;
  final QuranSource source;
  final int surahCount;
  final int ayahCount;
  final String dbSha256;
  final String textSha256;
  final String fetchUrl;
}

Result<QuranManifest> parseManifest(String json) {
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
    final src = requireMap('source');
    final counts = requireMap('counts');
    final checksums = requireMap('checksums');

    final source = QuranSource(
      name: requireString(src, 'name'),
      edition: requireString(src, 'edition'),
      version: requireString(src, 'version'),
      url: requireString(src, 'url'),
      license: requireString(src, 'license'),
      retrievedAtUtc: DateTime.parse(requireString(src, 'retrievedAtUtc')),
    );

    final surahCount = counts['surahs'];
    final ayahCount = counts['ayahs'];
    if (surahCount is! int || ayahCount is! int) {
      throw const FormatException(
        'counts.surahs / counts.ayahs must be integers',
      );
    }

    return Result.ok(
      QuranManifest(
        schemaVersion: schemaVersion,
        source: source,
        surahCount: surahCount,
        ayahCount: ayahCount,
        dbSha256: requireString(checksums, 'dbSha256'),
        textSha256: requireString(checksums, 'textSha256'),
        fetchUrl: src['fetchUrl'] is String ? src['fetchUrl'] as String : '',
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

Future<Result<QuranManifest>> loadManifestFromBundle(
  AssetBundle bundle, {
  String assetPath = quranManifestAssetPath,
}) async {
  try {
    final raw = await bundle.loadString(assetPath);
    return parseManifest(raw);
  } catch (e, st) {
    return Result.err(
      DataAccessFailure(
        'failed to load manifest from bundle: $e',
        cause: e,
        stackTrace: st,
      ),
    );
  }
}
