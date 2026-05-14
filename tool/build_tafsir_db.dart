// Maintainer-only build tool. Produces `assets/tafsir/muyassar.sqlite` and
// `assets/tafsir/manifest.json` from the spa5k/tafsir_api mirror of the
// King Fahd Complex's al-Muyassar tafsir, at a pinned commit SHA.
//
// Run: `dart run tool/build_tafsir_db.dart` (or `just build-tafsir-db`).
//
// The runtime app does NOT import anything under `tool/`. The download is
// 114 per-surah JSON files from raw.githubusercontent.com — small enough
// to fetch inline. The commit SHA is the integrity anchor for the upstream;
// our own SHA-256 of the canonical text payload pins the build output.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

// Pinned commit SHA on spa5k/tafsir_api (main branch as of 2026-05-14).
// Bumps must record a new SHA AND verify the tafsir content has not been
// removed or altered, per the design.md license trail.
const _defaultSourceCommit = 'a3499db2c9a6381e77f72ddcc52fe644cab1a77a';

const _defaultEdition = 'ar-tafsir-muyassar';
const _defaultOutDir = 'assets/tafsir';
const _defaultQuranDbPath = 'assets/quran/quran.sqlite';

// Pinned SHA-256 of the canonicalised tafsir text payload. Empty string =
// bootstrap mode (records the observed hash without enforcing it). Reproduces
// a deterministic build for the al-Muyassar commit pinned above.
const _defaultExpectedTextSha256 =
    '033a175166173fbcf6a26dd7771a543f511be88028bdc3131821e53f010ef385';

const _sourceName = 'al-Muyassar';
const _sourcePublisher = 'King Fahd Complex for the Printing of the Holy Quran';
const _sourceVersion = 'King Fahd Complex Madinah-mushaf edition';
const _sourceUpstream = 'https://qurancomplex.gov.sa/';
const _sourceDistribution =
    'Redistributed via spa5k/tafsir_api (MIT). '
    'Pinned to commit $_defaultSourceCommit, slug $_defaultEdition.';
const _sourceLicense =
    'Tafsir text by the King Fahd Complex (free non-commercial '
    'redistribution with attribution). Redistribution layer: MIT '
    '(spa5k/tafsir_api).';

const _schemaVersion = 1;
const _expectedAyahCount = 6236;
const _expectedSurahCount = 114;

Future<void> main(List<String> argv) async {
  final args = _Args.parse(argv);

  stdout.writeln('=> building al-Muyassar tafsir DB');
  stdout.writeln('   source commit: ${args.sourceCommit}');
  stdout.writeln('   edition:       ${args.edition}');
  stdout.writeln('   out dir:       ${args.outDir}');

  final entries = <_TafsirRow>[];
  for (var surah = 1; surah <= _expectedSurahCount; surah++) {
    final url = _surahUrl(args.sourceCommit, args.edition, surah);
    final body = await _downloadJson(url);
    final parsed = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    final ayahs = (parsed['ayahs'] as List).cast<Map<String, dynamic>>();
    for (final a in ayahs) {
      final s = a['surah'] as int;
      final ayahNum = a['ayah'] as int;
      final text = (a['text'] as String).trim();
      if (s != surah) {
        _abort(
          'surah $surah payload contains ayah with surah=$s (expected $surah)',
        );
      }
      if (text.isEmpty) {
        _abort('surah $surah ayah $ayahNum has empty tafsir text');
      }
      entries.add(_TafsirRow(surah: s, ayah: ayahNum, text: text));
    }
  }

  if (entries.length != _expectedAyahCount) {
    _abort(
      'expected $_expectedAyahCount tafsir entries, parsed ${entries.length}',
    );
  }

  // Sort deterministically.
  entries.sort((a, b) {
    final c = a.surah.compareTo(b.surah);
    return c != 0 ? c : a.ayah.compareTo(b.ayah);
  });

  // Detect duplicates.
  final seen = <String>{};
  for (final e in entries) {
    final key = '${e.surah}:${e.ayah}';
    if (!seen.add(key)) {
      _abort('duplicate tafsir entry $key');
    }
  }

  // Cross-check every (surah, ayah) references a real Quran ayah.
  _validateAgainstQuranDb(entries, args.quranDbPath);

  // Canonical hash of the text payload.
  final canonical = _canonicalText(entries);
  final textSha = sha256.convert(utf8.encode(canonical)).toString();
  if (args.expectedTextSha.isNotEmpty && args.expectedTextSha != textSha) {
    _abort(
      'text SHA-256 mismatch:\n  expected: ${args.expectedTextSha}\n  observed: $textSha',
    );
  }
  if (args.expectedTextSha.isEmpty) {
    stdout.writeln(
      '   warning: no --source-sha256 pinned; observed textSha256=$textSha',
    );
  }

  // Write DB.
  final outDir = Directory(args.outDir);
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  final dbPath = p.join(outDir.path, 'muyassar.sqlite');
  final manifestPath = p.join(outDir.path, 'manifest.json');
  if (File(dbPath).existsSync()) File(dbPath).deleteSync();

  stdout.writeln('=> writing $dbPath');
  final retrievedAt = DateTime.now().toUtc();
  _writeDatabase(dbPath: dbPath, entries: entries, textSha256: textSha);

  final dbBytes = File(dbPath).readAsBytesSync();
  final dbSha = sha256.convert(dbBytes).toString();

  // Manifest.
  final manifest = {
    'schemaVersion': _schemaVersion,
    'dataset': 'tafsir-muyassar',
    'source': {
      'name': _sourceName,
      'publisher': _sourcePublisher,
      'version': _sourceVersion,
      'url': _sourceUpstream,
      'distribution': _sourceDistribution,
      'fetchCommit': args.sourceCommit,
      'fetchEdition': args.edition,
      'license': _sourceLicense,
      'retrievedAtUtc': retrievedAt.toIso8601String(),
    },
    'counts': {'ayahs': entries.length},
    'checksums': {'dbSha256': dbSha, 'textSha256': textSha},
  };
  const encoder = JsonEncoder.withIndent('  ');
  File(manifestPath).writeAsStringSync('${encoder.convert(manifest)}\n');
  stdout.writeln('=> wrote $manifestPath');
  stdout.writeln('   dbSha256   = $dbSha');
  stdout.writeln('   textSha256 = $textSha');
  stdout.writeln('   ayahs      = ${entries.length}');
  stdout.writeln('=> done');
}

String _surahUrl(String commit, String edition, int surah) =>
    'https://raw.githubusercontent.com/spa5k/tafsir_api/$commit/tafsir/$edition/$surah.json';

Future<List<int>> _downloadJson(String url) async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) {
    _abort('GET $url -> HTTP ${res.statusCode}');
  }
  return res.bodyBytes;
}

String _canonicalText(List<_TafsirRow> entries) {
  final buf = StringBuffer();
  for (final e in entries) {
    buf.writeln('${e.surah}|${e.ayah}|${e.text}');
  }
  return buf.toString();
}

void _validateAgainstQuranDb(List<_TafsirRow> entries, String quranDbPath) {
  final file = File(quranDbPath);
  if (!file.existsSync()) {
    _abort(
      'quran DB not found at $quranDbPath. Run `just build-quran-db` first.',
    );
  }
  final db = sqlite3.open(quranDbPath, mode: OpenMode.readOnly);
  try {
    final result = db.select(
      "SELECT value FROM meta WHERE key = 'schema_version'",
    );
    if (result.isEmpty) {
      _abort('quran DB at $quranDbPath has no schema_version meta row');
    }
    // Build set of valid (surah, ayah) pairs in one pass.
    final validKeys = <String>{};
    final rows = db.select('SELECT surah, ayah FROM ayahs');
    for (final row in rows) {
      validKeys.add('${row['surah']}:${row['ayah']}');
    }
    final orphans = <String>[];
    for (final e in entries) {
      final key = '${e.surah}:${e.ayah}';
      if (!validKeys.contains(key)) orphans.add(key);
    }
    if (orphans.isNotEmpty) {
      _abort(
        'tafsir references ${orphans.length} non-existent ayahs in the bundled '
        'Quran DB; first few: ${orphans.take(5).join(", ")}',
      );
    }
  } finally {
    db.dispose();
  }
}

void _writeDatabase({
  required String dbPath,
  required List<_TafsirRow> entries,
  required String textSha256,
}) {
  final db = sqlite3.open(dbPath);
  try {
    db.execute('PRAGMA journal_mode = DELETE;');
    db.execute('PRAGMA encoding = "UTF-8";');
    db.execute('''
      CREATE TABLE meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE tafsir (
        surah   INTEGER NOT NULL CHECK(surah BETWEEN 1 AND 114),
        ayah    INTEGER NOT NULL CHECK(ayah > 0),
        text    TEXT NOT NULL,
        PRIMARY KEY (surah, ayah)
      );
    ''');
    db.execute('CREATE INDEX idx_tafsir_surah ON tafsir(surah);');

    final metaInsert = db.prepare('INSERT INTO meta(key, value) VALUES (?, ?)');
    void putMeta(String k, String v) => metaInsert.execute([k, v]);

    putMeta('schema_version', '$_schemaVersion');
    putMeta('source_name', _sourceName);
    putMeta('source_publisher', _sourcePublisher);
    putMeta('source_version', _sourceVersion);
    putMeta('source_url', _sourceUpstream);
    putMeta('source_distribution', _sourceDistribution);
    putMeta('source_license', _sourceLicense);
    putMeta('text_sha256', textSha256);
    // retrievedAtUtc lives in manifest.json only (DB stays byte-deterministic
    // for the same source content — same rationale as the Quran build tool).
    metaInsert.dispose();

    final tafsirInsert = db.prepare(
      'INSERT INTO tafsir(surah, ayah, text) VALUES (?, ?, ?)',
    );
    db.execute('BEGIN');
    for (final e in entries) {
      tafsirInsert.execute([e.surah, e.ayah, e.text]);
    }
    db.execute('COMMIT');
    tafsirInsert.dispose();

    db.execute('VACUUM;');
  } finally {
    db.dispose();
  }
}

class _Args {
  _Args({
    required this.sourceCommit,
    required this.edition,
    required this.expectedTextSha,
    required this.outDir,
    required this.quranDbPath,
  });

  final String sourceCommit;
  final String edition;
  final String expectedTextSha;
  final String outDir;
  final String quranDbPath;

  static _Args parse(List<String> argv) {
    var sourceCommit = _defaultSourceCommit;
    var edition = _defaultEdition;
    var expectedTextSha = _defaultExpectedTextSha256;
    var outDir = _defaultOutDir;
    var quranDbPath = _defaultQuranDbPath;
    for (var i = 0; i < argv.length; i++) {
      final a = argv[i];
      String value() {
        if (i + 1 >= argv.length) _abort('missing value for $a');
        return argv[++i];
      }

      switch (a) {
        case '--source-commit':
          sourceCommit = value();
        case '--edition':
          edition = value();
        case '--source-sha256':
          expectedTextSha = value();
        case '--out-dir':
          outDir = value();
        case '--quran-db':
          quranDbPath = value();
        default:
          _abort('unknown arg: $a');
      }
    }
    return _Args(
      sourceCommit: sourceCommit,
      edition: edition,
      expectedTextSha: expectedTextSha,
      outDir: outDir,
      quranDbPath: quranDbPath,
    );
  }
}

class _TafsirRow {
  const _TafsirRow({
    required this.surah,
    required this.ayah,
    required this.text,
  });

  final int surah;
  final int ayah;
  final String text;
}

Never _abort(String msg) {
  stderr.writeln('ERROR: $msg');
  exit(1);
}
