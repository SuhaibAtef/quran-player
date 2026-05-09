import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import 'manifest.dart';
import 'quran_database.dart';

const int expectedSchemaVersion = 1;
const int expectedSurahCount = 114;
const int expectedAyahCount = 6236;

// Cache key holding a JSON-encoded `_VerifiedSignature` (dbSha256 + file
// length + mtime). Any drift in length/mtime invalidates the cache and forces
// a fresh hash.
const String _verifiedSignatureKey = 'quran.integrity.verified_db_signature';

class IntegrityReport {
  const IntegrityReport({required this.dbSha256, required this.skippedHash});

  final String dbSha256;
  final bool skippedHash;
}

Future<Result<IntegrityReport>> verifyQuranIntegrity({
  required QuranDatabase database,
  required QuranManifest manifest,
  required SharedPreferences prefs,
}) async {
  final structural = await _verifyStructural(database.db, manifest);
  if (structural is Err<void>) {
    return Result.err(structural.failure);
  }

  // Capture the on-disk file's signature so the cache can detect any drift
  // (re-materialisation, partial upgrade, local corruption, manual edit).
  final stat = FileStat.statSync(database.filePath);
  final currentSig = _VerifiedSignature(
    dbSha256: manifest.dbSha256,
    fileLength: stat.size,
    mtimeMs: stat.modified.millisecondsSinceEpoch,
  );

  // Hash-skip cache: skip the expensive SHA pass only when the cached
  // signature matches manifest.dbSha256 AND the file's length + mtime are
  // identical to what we recorded after the last successful verify.
  final cached = _readCachedSignature(prefs);
  if (cached != null && cached == currentSig) {
    return Result.ok(
      IntegrityReport(dbSha256: manifest.dbSha256, skippedHash: true),
    );
  }

  final fileSha = await _hashFile(database.filePath);
  if (fileSha != manifest.dbSha256) {
    return Result.err(
      DataIntegrityFailure(
        'database SHA-256 mismatch:\n'
        '  manifest: ${manifest.dbSha256}\n'
        '  on-disk:  $fileSha',
      ),
    );
  }

  await prefs.setString(_verifiedSignatureKey, currentSig.toJson());
  return Result.ok(
    IntegrityReport(dbSha256: manifest.dbSha256, skippedHash: false),
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
  Database db,
  QuranManifest manifest,
) async {
  if (manifest.schemaVersion != expectedSchemaVersion) {
    return Result.err(
      DataIntegrityFailure(
        'manifest schemaVersion ${manifest.schemaVersion} != expected $expectedSchemaVersion',
      ),
    );
  }

  // schema_version row in DB
  final metaRow = await db.rawQuery(
    "SELECT value FROM meta WHERE key = 'schema_version'",
  );
  if (metaRow.isEmpty) {
    return Result.err(
      const DataIntegrityFailure('meta.schema_version row is missing'),
    );
  }
  final dbSchemaVersion = int.tryParse(metaRow.first['value'] as String? ?? '');
  if (dbSchemaVersion != expectedSchemaVersion) {
    return Result.err(
      DataIntegrityFailure(
        'meta.schema_version=$dbSchemaVersion != expected $expectedSchemaVersion',
      ),
    );
  }

  final surahCount = _firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM surahs'),
  );
  if (surahCount != expectedSurahCount) {
    return Result.err(
      DataIntegrityFailure(
        'surah count $surahCount != expected $expectedSurahCount',
      ),
    );
  }
  if (manifest.surahCount != expectedSurahCount) {
    return Result.err(
      DataIntegrityFailure(
        'manifest counts.surahs ${manifest.surahCount} != expected $expectedSurahCount',
      ),
    );
  }

  final ayahCount = _firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM ayahs'),
  );
  if (ayahCount != expectedAyahCount) {
    return Result.err(
      DataIntegrityFailure(
        'ayah count $ayahCount != expected $expectedAyahCount',
      ),
    );
  }
  if (manifest.ayahCount != expectedAyahCount) {
    return Result.err(
      DataIntegrityFailure(
        'manifest counts.ayahs ${manifest.ayahCount} != expected $expectedAyahCount',
      ),
    );
  }

  // All surah numbers 1..114 present.
  final missingSurahs = await db.rawQuery('''
    WITH RECURSIVE expected(n) AS (
      SELECT 1 UNION ALL SELECT n + 1 FROM expected WHERE n < 114
    )
    SELECT n FROM expected WHERE n NOT IN (SELECT number FROM surahs)
  ''');
  if (missingSurahs.isNotEmpty) {
    final missing = missingSurahs.map((r) => r['n']).join(', ');
    return Result.err(DataIntegrityFailure('missing surah numbers: $missing'));
  }

  // No duplicate (surah, ayah) keys. With a PRIMARY KEY this can't physically
  // happen on a sane SQLite, but a tampered DB might drop the constraint.
  final dupCount = _firstIntValue(
    await db.rawQuery('''
      SELECT COUNT(*) FROM (
        SELECT surah, ayah, COUNT(*) c FROM ayahs
        GROUP BY surah, ayah HAVING c > 1
      )
    '''),
  );
  if (dupCount != null && dupCount > 0) {
    return Result.err(
      DataIntegrityFailure('found $dupCount duplicate (surah, ayah) keys'),
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
