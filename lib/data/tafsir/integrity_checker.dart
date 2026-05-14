import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../quran/quran_database.dart';
import 'manifest.dart';
import 'tafsir_database.dart';

const int tafsirExpectedSchemaVersion = 1;
const int tafsirExpectedAyahCount = 6236;

const String _verifiedSignatureKey = 'tafsir.integrity.verified_db_signature';

class TafsirIntegrityReport {
  const TafsirIntegrityReport({
    required this.dbSha256,
    required this.skippedHash,
  });

  final String dbSha256;
  final bool skippedHash;
}

Future<Result<TafsirIntegrityReport>> verifyTafsirIntegrity({
  required TafsirDatabase tafsirDatabase,
  required QuranDatabase quranDatabase,
  required TafsirManifest manifest,
  required SharedPreferences prefs,
}) async {
  final structural = await _verifyStructural(
    tafsirDatabase.db,
    quranDatabase.db,
    manifest,
  );
  if (structural is Err<void>) {
    return Result.err(structural.failure);
  }

  final stat = FileStat.statSync(tafsirDatabase.filePath);
  final currentSig = _VerifiedSignature(
    dbSha256: manifest.dbSha256,
    fileLength: stat.size,
    mtimeMs: stat.modified.millisecondsSinceEpoch,
  );

  final cached = _readCachedSignature(prefs);
  if (cached != null && cached == currentSig) {
    return Result.ok(
      TafsirIntegrityReport(dbSha256: manifest.dbSha256, skippedHash: true),
    );
  }

  final fileSha = await _hashFile(tafsirDatabase.filePath);
  if (fileSha != manifest.dbSha256) {
    return Result.err(
      DataIntegrityFailure(
        'tafsir database SHA-256 mismatch:\n'
        '  manifest: ${manifest.dbSha256}\n'
        '  on-disk:  $fileSha',
      ),
    );
  }

  await prefs.setString(_verifiedSignatureKey, currentSig.toJson());
  return Result.ok(
    TafsirIntegrityReport(dbSha256: manifest.dbSha256, skippedHash: false),
  );
}

class _VerifiedSignature {
  const _VerifiedSignature({
    required this.dbSha256,
    required this.fileLength,
    required this.mtimeMs,
  });

  final String dbSha256;
  final int fileLength;
  final int mtimeMs;

  String toJson() => jsonEncode({
    'dbSha256': dbSha256,
    'fileLength': fileLength,
    'mtimeMs': mtimeMs,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _VerifiedSignature &&
          other.dbSha256 == dbSha256 &&
          other.fileLength == fileLength &&
          other.mtimeMs == mtimeMs;

  @override
  int get hashCode => Object.hash(dbSha256, fileLength, mtimeMs);
}

_VerifiedSignature? _readCachedSignature(SharedPreferences prefs) {
  final raw = prefs.getString(_verifiedSignatureKey);
  if (raw == null) return null;
  try {
    final m = jsonDecode(raw);
    if (m is! Map<String, dynamic>) return null;
    final sha = m['dbSha256'];
    final len = m['fileLength'];
    final mtime = m['mtimeMs'];
    if (sha is! String || len is! int || mtime is! int) return null;
    return _VerifiedSignature(dbSha256: sha, fileLength: len, mtimeMs: mtime);
  } catch (_) {
    return null;
  }
}

Future<Result<void>> _verifyStructural(
  Database tafsirDb,
  Database quranDb,
  TafsirManifest manifest,
) async {
  if (manifest.schemaVersion != tafsirExpectedSchemaVersion) {
    return Result.err(
      DataIntegrityFailure(
        'tafsir manifest schemaVersion ${manifest.schemaVersion} != expected $tafsirExpectedSchemaVersion',
      ),
    );
  }

  final metaRow = await tafsirDb.rawQuery(
    "SELECT value FROM meta WHERE key = 'schema_version'",
  );
  if (metaRow.isEmpty) {
    return Result.err(
      const DataIntegrityFailure('tafsir meta.schema_version row is missing'),
    );
  }
  final dbSchemaVersion = int.tryParse(metaRow.first['value'] as String? ?? '');
  if (dbSchemaVersion != tafsirExpectedSchemaVersion) {
    return Result.err(
      DataIntegrityFailure(
        'tafsir meta.schema_version=$dbSchemaVersion != expected $tafsirExpectedSchemaVersion',
      ),
    );
  }

  final tafsirCount = _firstIntValue(
    await tafsirDb.rawQuery('SELECT COUNT(*) FROM tafsir'),
  );
  if (tafsirCount != tafsirExpectedAyahCount) {
    return Result.err(
      DataIntegrityFailure(
        'tafsir row count $tafsirCount != expected $tafsirExpectedAyahCount',
      ),
    );
  }
  if (manifest.ayahCount != tafsirExpectedAyahCount) {
    return Result.err(
      DataIntegrityFailure(
        'tafsir manifest counts.ayahs ${manifest.ayahCount} != expected $tafsirExpectedAyahCount',
      ),
    );
  }

  // No duplicate (surah, ayah) keys.
  final dupCount = _firstIntValue(
    await tafsirDb.rawQuery('''
      SELECT COUNT(*) FROM (
        SELECT surah, ayah, COUNT(*) c FROM tafsir
        GROUP BY surah, ayah HAVING c > 1
      )
    '''),
  );
  if (dupCount != null && dupCount > 0) {
    return Result.err(
      DataIntegrityFailure(
        'found $dupCount duplicate (surah, ayah) keys in tafsir',
      ),
    );
  }

  // Cross-check: every tafsir (surah, ayah) must reference a real Quran ayah.
  // Build the valid-key set from the Quran DB once, then scan tafsir.
  final quranKeys = <String>{};
  for (final row in await quranDb.rawQuery('SELECT surah, ayah FROM ayahs')) {
    quranKeys.add('${row['surah']}:${row['ayah']}');
  }
  final tafsirRows = await tafsirDb.rawQuery(
    'SELECT surah, ayah FROM tafsir ORDER BY surah, ayah',
  );
  final orphans = <String>[];
  for (final row in tafsirRows) {
    final key = '${row['surah']}:${row['ayah']}';
    if (!quranKeys.contains(key)) orphans.add(key);
    if (orphans.length >= 5) break;
  }
  if (orphans.isNotEmpty) {
    return Result.err(
      DataIntegrityFailure(
        'tafsir references unknown ayahs: ${orphans.join(", ")}'
        '${orphans.length >= 5 ? " (and possibly more)" : ""}',
      ),
    );
  }

  return const Result.ok(null);
}

Future<String> _hashFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return sha256.convert(bytes).toString();
}

int? _firstIntValue(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return null;
  final v = rows.first.values.first;
  return v is int ? v : null;
}
