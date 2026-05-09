// Maintainer-only build tool. Produces `assets/quran/quran.sqlite` and
// `assets/quran/manifest.json` from the upstream Tanzil Uthmani edition.
//
// Run: `dart run tool/build_quran_db.dart` (or `just build-quran-db`).
//
// The runtime app does NOT import anything under `tool/`. Build-tool-only
// dependencies are `http`, `archive`, and `sqlite3` (all under
// `dev_dependencies` in pubspec.yaml). `crypto` is also imported here, but
// it ships at runtime as well — the app's integrity checker hashes the
// bundled DB with SHA-256.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _defaultSourceUrl = 'https://api.alquran.cloud/v1/quran/quran-uthmani';

// Pinned SHA-256 of the canonicalised text payload (see [_canonicalText]).
// Reproduces a deterministic build whenever the upstream serves the same
// 6,236-ayah Uthmani edition. Empty string = bootstrap mode (records the
// observed hash without enforcing it).
const _defaultExpectedTextSha256 =
    '5e6accd845ed3668a0ed45937a4626957b1f38d05598e3df573c6ad39fb45621';

const _defaultOutDir = 'assets/quran';

const _sourceName = 'Tanzil';
const _sourceEdition = 'Uthmani';
const _sourceVersion = '1.0.2';
const _sourceLicense =
    'Tanzil Quran Text License (non-commercial, attribution). '
    'See https://tanzil.net/docs/tanzil_license';
const _sourceUpstream = 'https://tanzil.net/download/';
const _sourceDistribution =
    'Distributed via Islamic Network alquran.cloud API.';

const _schemaVersion = 1;
const _expectedSurahCount = 114;
const _expectedAyahCount = 6236;

Future<void> main(List<String> argv) async {
  final args = _Args.parse(argv);

  stdout.writeln('=> downloading ${args.sourceUrl}');
  final body = await _downloadJson(args.sourceUrl);

  stdout.writeln('=> parsing payload');
  final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
  if (payload['code'] != 200) {
    _abort('upstream returned non-200 code: ${payload['code']}');
  }
  final data = payload['data'] as Map<String, dynamic>;
  final surahsJson = (data['surahs'] as List).cast<Map<String, dynamic>>();
  if (surahsJson.length != _expectedSurahCount) {
    _abort(
      'expected $_expectedSurahCount surahs, upstream returned ${surahsJson.length}',
    );
  }

  final surahs = <_SurahRow>[];
  final ayahs = <_AyahRow>[];
  for (final s in surahsJson) {
    final number = s['number'] as int;
    final nameArabicRaw = (s['name'] as String).trim();
    final nameLatin = (s['englishName'] as String).trim();
    final revelation = (s['revelationType'] as String).toLowerCase();
    if (revelation != 'meccan' && revelation != 'medinan') {
      _abort('surah $number: unknown revelation type "$revelation"');
    }
    final ayahList = (s['ayahs'] as List).cast<Map<String, dynamic>>();

    surahs.add(
      _SurahRow(
        number: number,
        nameArabic: _stripSurahPrefix(nameArabicRaw),
        nameLatin: nameLatin,
        revelation: revelation,
        ayahCount: ayahList.length,
      ),
    );

    for (final a in ayahList) {
      final ayahNum = a['numberInSurah'] as int;
      final text = (a['text'] as String).replaceAll('﻿', '').trim();
      if (text.isEmpty) {
        _abort('surah $number ayah $ayahNum is empty');
      }
      ayahs.add(_AyahRow(surah: number, ayah: ayahNum, text: text));
    }
  }
  if (ayahs.length != _expectedAyahCount) {
    _abort('expected $_expectedAyahCount ayahs, parsed ${ayahs.length}');
  }
  if (surahs.length != _expectedSurahCount) {
    _abort('expected $_expectedSurahCount surahs, parsed ${surahs.length}');
  }
  for (var i = 0; i < surahs.length; i++) {
    if (surahs[i].number != i + 1) {
      _abort(
        'surah numbering broken at index $i: got ${surahs[i].number}, expected ${i + 1}',
      );
    }
  }

  // Sort deterministically.
  surahs.sort((a, b) => a.number.compareTo(b.number));
  ayahs.sort((a, b) {
    final c = a.surah.compareTo(b.surah);
    return c != 0 ? c : a.ayah.compareTo(b.ayah);
  });

  // Detect duplicates (cheap; mostly a guard against parser regressions).
  final seen = <String>{};
  for (final a in ayahs) {
    final key = '${a.surah}:${a.ayah}';
    if (!seen.add(key)) {
      _abort('duplicate ayah $key');
    }
  }

  final canonical = _canonicalText(ayahs);
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
  final dbPath = p.join(outDir.path, 'quran.sqlite');
  final manifestPath = p.join(outDir.path, 'manifest.json');
  if (File(dbPath).existsSync()) File(dbPath).deleteSync();

  stdout.writeln('=> writing $dbPath');
  final retrievedAt = DateTime.now().toUtc();
  _writeDatabase(
    dbPath: dbPath,
    surahs: surahs,
    ayahs: ayahs,
    textSha256: textSha,
  );

  // Hash the final DB file.
  final dbBytes = File(dbPath).readAsBytesSync();
  final dbSha = sha256.convert(dbBytes).toString();

  // Write manifest.
  final manifest = {
    'schemaVersion': _schemaVersion,
    'source': {
      'name': _sourceName,
      'edition': _sourceEdition,
      'version': _sourceVersion,
      'url': _sourceUpstream,
      'distribution': _sourceDistribution,
      'fetchUrl': args.sourceUrl,
      'license': _sourceLicense,
      'retrievedAtUtc': retrievedAt.toIso8601String(),
    },
    'counts': {'surahs': surahs.length, 'ayahs': ayahs.length},
    'checksums': {'dbSha256': dbSha, 'textSha256': textSha},
  };
  const encoder = JsonEncoder.withIndent('  ');
  File(manifestPath).writeAsStringSync('${encoder.convert(manifest)}\n');
  stdout.writeln('=> wrote $manifestPath');
  stdout.writeln('   dbSha256   = $dbSha');
  stdout.writeln('   textSha256 = $textSha');
  stdout.writeln('   surahs     = ${surahs.length}');
  stdout.writeln('   ayahs      = ${ayahs.length}');
  stdout.writeln('=> done');
}

Future<List<int>> _downloadJson(String url) async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) {
    _abort('GET $url -> HTTP ${res.statusCode}');
  }
  return res.bodyBytes;
}

String _canonicalText(List<_AyahRow> ayahs) {
  // Stable line-oriented form independent of JSON whitespace/order.
  final buf = StringBuffer();
  for (final a in ayahs) {
    buf.writeln('${a.surah}|${a.ayah}|${a.text}');
  }
  return buf.toString();
}

String _stripSurahPrefix(String name) {
  // Upstream often returns "سُورَةُ ٱلْفَاتِحَةِ" — drop the leading "سُورَةُ" word
  // for display; preserve diacritics on the proper noun.
  const prefix = 'سُورَةُ ';
  if (name.startsWith(prefix)) return name.substring(prefix.length).trim();
  const altPrefix = 'سورة ';
  if (name.startsWith(altPrefix)) {
    return name.substring(altPrefix.length).trim();
  }
  return name;
}

void _writeDatabase({
  required String dbPath,
  required List<_SurahRow> surahs,
  required List<_AyahRow> ayahs,
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
      CREATE TABLE surahs (
        number       INTEGER PRIMARY KEY CHECK(number BETWEEN 1 AND 114),
        name_arabic  TEXT NOT NULL,
        name_latin   TEXT NOT NULL,
        revelation   TEXT NOT NULL CHECK(revelation IN ('meccan','medinan')),
        ayah_count   INTEGER NOT NULL CHECK(ayah_count > 0)
      );
    ''');
    db.execute('''
      CREATE TABLE ayahs (
        surah   INTEGER NOT NULL REFERENCES surahs(number),
        ayah    INTEGER NOT NULL CHECK(ayah > 0),
        text    TEXT NOT NULL,
        PRIMARY KEY (surah, ayah)
      );
    ''');
    db.execute('CREATE INDEX idx_ayahs_surah ON ayahs(surah);');
    db.execute('''
      CREATE VIRTUAL TABLE ayah_fts USING fts5(
        text,
        content='ayahs',
        content_rowid='rowid',
        tokenize='unicode61 remove_diacritics 2'
      );
    ''');

    // Insert meta.
    final metaInsert = db.prepare('INSERT INTO meta(key, value) VALUES (?, ?)');
    void putMeta(String k, String v) {
      metaInsert.execute([k, v]);
    }

    putMeta('schema_version', '$_schemaVersion');
    putMeta('source_name', _sourceName);
    putMeta('source_edition', _sourceEdition);
    putMeta('source_version', _sourceVersion);
    putMeta('source_url', _sourceUpstream);
    putMeta('source_distribution', _sourceDistribution);
    putMeta('source_license', _sourceLicense);
    putMeta('text_sha256', textSha256);
    // Note: retrievedAtUtc lives in manifest.json only, NOT in the DB. Keeping
    // the DB byte-deterministic for the same text payload makes PR diffs
    // meaningful and lets dbSha256 be a real tamper detector.
    metaInsert.dispose();

    // Insert surahs.
    final surahInsert = db.prepare(
      'INSERT INTO surahs(number, name_arabic, name_latin, revelation, ayah_count) '
      'VALUES (?, ?, ?, ?, ?)',
    );
    db.execute('BEGIN');
    for (final s in surahs) {
      surahInsert.execute([
        s.number,
        s.nameArabic,
        s.nameLatin,
        s.revelation,
        s.ayahCount,
      ]);
    }
    db.execute('COMMIT');
    surahInsert.dispose();

    // Insert ayahs.
    final ayahInsert = db.prepare(
      'INSERT INTO ayahs(surah, ayah, text) VALUES (?, ?, ?)',
    );
    db.execute('BEGIN');
    for (final a in ayahs) {
      ayahInsert.execute([a.surah, a.ayah, a.text]);
    }
    db.execute('COMMIT');
    ayahInsert.dispose();

    // Populate FTS5 external-content index from the ayahs content table.
    db.execute("INSERT INTO ayah_fts(ayah_fts) VALUES('rebuild');");

    db.execute('VACUUM;');
  } finally {
    db.dispose();
  }
}

class _Args {
  _Args({
    required this.sourceUrl,
    required this.expectedTextSha,
    required this.outDir,
  });

  factory _Args.parse(List<String> argv) {
    var sourceUrl = _defaultSourceUrl;
    var expectedTextSha = _defaultExpectedTextSha256;
    var outDir = _defaultOutDir;
    for (var i = 0; i < argv.length; i++) {
      final a = argv[i];
      String next() {
        if (i + 1 >= argv.length) _abort('missing value for $a');
        return argv[++i];
      }

      switch (a) {
        case '--source-url':
          sourceUrl = next();
        case '--source-sha256':
          expectedTextSha = next();
        case '--out-dir':
          outDir = next();
        case '-h':
        case '--help':
          _printUsageAndExit();
        default:
          _abort('unknown argument: $a');
      }
    }
    return _Args(
      sourceUrl: sourceUrl,
      expectedTextSha: expectedTextSha,
      outDir: outDir,
    );
  }

  final String sourceUrl;
  final String expectedTextSha;
  final String outDir;
}

Never _printUsageAndExit() {
  stdout.writeln(
    'Usage: dart run tool/build_quran_db.dart\n'
    '  [--source-url <url>]      default: $_defaultSourceUrl\n'
    '  [--source-sha256 <hex>]   pin expected SHA-256 of canonical text\n'
    '  [--out-dir <path>]        default: $_defaultOutDir',
  );
  exit(0);
}

Never _abort(String message) {
  stderr.writeln('error: $message');
  exit(1);
}

class _SurahRow {
  _SurahRow({
    required this.number,
    required this.nameArabic,
    required this.nameLatin,
    required this.revelation,
    required this.ayahCount,
  });

  final int number;
  final String nameArabic;
  final String nameLatin;
  final String revelation;
  final int ayahCount;
}

class _AyahRow {
  _AyahRow({required this.surah, required this.ayah, required this.text});

  final int surah;
  final int ayah;
  final String text;
}
