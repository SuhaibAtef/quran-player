import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'asset_source.dart';

/// A tiny synthetic [MushafAssetSource] with no QUL data.
///
/// It builds a healthy three-page mini-layout in memory and serves a generated
/// box-glyph stub font for every page. It exists so the engine — and the
/// package `example/` — is runnable and testable without downloading any QUL
/// resource. It is **not** a mushaf: the layout is invented and the font draws
/// plain boxes.
class DemoMushafAssetSource implements MushafAssetSource {
  DemoMushafAssetSource();

  Uint8List? _layout;
  Uint8List? _words;
  Uint8List? _font;

  @override
  Future<Uint8List> layoutDb() async => _layout ??= await buildDemoLayoutDb();

  @override
  Future<Uint8List> wordDb() async => _words ??= await buildDemoWordDb();

  @override
  Future<Uint8List> pageFont(int page) async => _font ??= demoStubFontBytes();
}

/// One `pages` row of the demo layout.
class DemoPageRow {
  const DemoPageRow({
    required this.page,
    required this.line,
    required this.type,
    required this.isCentered,
    this.firstWordId,
    this.lastWordId,
    this.surahNumber,
  });

  final int page;
  final int line;
  final String type;
  final bool isCentered;
  final int? firstWordId;
  final int? lastWordId;
  final int? surahNumber;
}

/// One `words` row of the demo layout.
class DemoWordRow {
  const DemoWordRow({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.word,
    required this.text,
  });

  final int id;
  final int surah;
  final int ayah;
  final int word;
  final String text;
}

/// The demo layout's `pages` rows: a three-page mini-mushaf — surah 1 (3
/// ayahs) on page 1, surah 2 opening on page 2, surah 2 continuing on page 3.
const List<DemoPageRow> demoPageRows = <DemoPageRow>[
  DemoPageRow(
    page: 1,
    line: 1,
    type: 'surah_name',
    isCentered: true,
    surahNumber: 1,
  ),
  DemoPageRow(
    page: 1,
    line: 2,
    type: 'ayah',
    isCentered: false,
    firstWordId: 1,
    lastWordId: 3,
  ),
  DemoPageRow(
    page: 1,
    line: 3,
    type: 'ayah',
    isCentered: false,
    firstWordId: 4,
    lastWordId: 6,
  ),
  DemoPageRow(
    page: 1,
    line: 4,
    type: 'ayah',
    isCentered: true,
    firstWordId: 7,
    lastWordId: 9,
  ),
  DemoPageRow(
    page: 2,
    line: 1,
    type: 'surah_name',
    isCentered: true,
    surahNumber: 2,
  ),
  DemoPageRow(page: 2, line: 2, type: 'basmallah', isCentered: true),
  DemoPageRow(
    page: 2,
    line: 3,
    type: 'ayah',
    isCentered: false,
    firstWordId: 10,
    lastWordId: 13,
  ),
  DemoPageRow(
    page: 2,
    line: 4,
    type: 'ayah',
    isCentered: false,
    firstWordId: 14,
    lastWordId: 16,
  ),
  DemoPageRow(
    page: 2,
    line: 5,
    type: 'ayah',
    isCentered: false,
    firstWordId: 17,
    lastWordId: 21,
  ),
  DemoPageRow(
    page: 3,
    line: 1,
    type: 'ayah',
    isCentered: false,
    firstWordId: 22,
    lastWordId: 25,
  ),
  DemoPageRow(
    page: 3,
    line: 2,
    type: 'ayah',
    isCentered: false,
    firstWordId: 26,
    lastWordId: 28,
  ),
  DemoPageRow(
    page: 3,
    line: 3,
    type: 'ayah',
    isCentered: true,
    firstWordId: 29,
    lastWordId: 32,
  ),
];

/// The demo layout's `words` rows — id-contiguous, matching [demoPageRows].
final List<DemoWordRow> demoWordRows = _buildDemoWordRows();

List<DemoWordRow> _buildDemoWordRows() {
  // (surah, ayah, wordCount) for each ayah, in canonical order.
  const ayahs = <List<int>>[
    [1, 1, 3],
    [1, 2, 3],
    [1, 3, 3],
    [2, 1, 4],
    [2, 2, 3],
    [2, 3, 5],
    [2, 4, 4],
    [2, 5, 3],
    [2, 6, 4],
  ];
  final rows = <DemoWordRow>[];
  var id = 1;
  for (final ayah in ayahs) {
    for (var w = 1; w <= ayah[2]; w++) {
      rows.add(
        DemoWordRow(
          id: id++,
          surah: ayah[0],
          ayah: ayah[1],
          word: w,
          // ASCII text the box-glyph stub font covers — rendering data only.
          text: 'w${ayah[0]}${ayah[1]}$w',
        ),
      );
    }
  }
  return rows;
}

/// Builds the demo QUL layout database bytes (`pages` table).
Future<Uint8List> buildDemoLayoutDb() => buildLayoutDbBytes(demoPageRows);

/// Builds the demo QUL word-script database bytes (`words` table).
Future<Uint8List> buildDemoWordDb() => buildWordDbBytes(demoWordRows);

/// Builds a QUL-shaped layout database from [rows]. Non-applicable integer
/// columns are stored as `''`, mirroring the real QUL distribution.
Future<Uint8List> buildLayoutDbBytes(List<DemoPageRow> rows) {
  return _buildDbBytes('layout', (db) async {
    await db.execute(
      'CREATE TABLE pages('
      'page_number INTEGER, line_number INTEGER, line_type TEXT, '
      'is_centered INTEGER, first_word_id INTEGER, last_word_id INTEGER, '
      'surah_number INTEGER)',
    );
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('pages', <String, Object?>{
        'page_number': row.page,
        'line_number': row.line,
        'line_type': row.type,
        'is_centered': row.isCentered ? 1 : 0,
        'first_word_id': row.firstWordId ?? '',
        'last_word_id': row.lastWordId ?? '',
        'surah_number': row.surahNumber ?? '',
      });
    }
    await batch.commit(noResult: true);
  });
}

/// Builds a QUL-shaped word-script database from [rows].
Future<Uint8List> buildWordDbBytes(List<DemoWordRow> rows) {
  return _buildDbBytes('words', (db) async {
    await db.execute(
      'CREATE TABLE words('
      'id INTEGER PRIMARY KEY, location TEXT, surah INTEGER, ayah INTEGER, '
      'word INTEGER, text TEXT)',
    );
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('words', <String, Object?>{
        'id': row.id,
        'location': '${row.surah}:${row.ayah}:${row.word}',
        'surah': row.surah,
        'ayah': row.ayah,
        'word': row.word,
        'text': row.text,
      });
    }
    await batch.commit(noResult: true);
  });
}

/// Builds an SQLite database from raw [createStatements] with no rows — used
/// by tests to craft schema-mismatch inputs.
Future<Uint8List> buildRawDbBytes(List<String> createStatements) {
  return _buildDbBytes('raw', (db) async {
    for (final sql in createStatements) {
      await db.execute(sql);
    }
  });
}

bool _ffiInitialized = false;

Future<Uint8List> _buildDbBytes(
  String name,
  Future<void> Function(Database db) populate,
) async {
  if (!_ffiInitialized) {
    sqfliteFfiInit();
    _ffiInitialized = true;
  }
  final scratch = await Directory.systemTemp.createTemp('tarteel_qul_fx_');
  final file = File(p.join(scratch.path, '$name.db'));
  try {
    // No-isolate factory — safe to call from any zone, including a
    // `flutter_test` widget-test zone (see layout_repository.dart).
    final db = await databaseFactoryFfiNoIsolate.openDatabase(file.path);
    try {
      await populate(db);
    } finally {
      await db.close();
    }
    return file.readAsBytes();
  } finally {
    try {
      await scratch.delete(recursive: true);
    } catch (_) {
      // A leftover temp file is harmless.
    }
  }
}

/// Decoded bytes of the box-glyph stub font served for every demo page.
Uint8List demoStubFontBytes() => base64.decode(_stubFontBase64);

/// A generated TrueType font whose glyphs are plain boxes covering printable
/// ASCII. It is **not** a mushaf font — it carries no QUL/KFGQPC data — and
/// exists only so the demo source can hand the engine loadable font bytes.
const String _stubFontBase64 =
    'AAEAAAAKAIAAAwAgT1MvMkQ4QVIAAAEoAAAAYGNtYXAADADRAAACTAAAADRnbHlm2yLatQAAA0QAAAmMaGVhZC3KsyQAAACsAAAA'
    'NmhoZWEFegHiAAAA5AAAACRobXR4EVgPAAAAAYgAAADCbG9jYXKQcC0AAAKAAAAAwm1heHAAYgAGAAABCAAAACBuYW1lZvmPqQAA'
    'DNAAAAB+cG9zdMgZezgAAA1QAAACXgABAAAAAQAAmYW+1V8PPPUAAwPoAAAAAOYuN8QAAAAA5i43xABQAAACCAK8AAAAAwACAAAA'
    'AAAAAAEAAAMg/zgAAAJYAFAAUAIIAAEAAAAAAAAAAAAAAAAAAAABAAEAAABgAAQAAQAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAwJY'
    'AZAABQAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAPz8/PwAAACAAfgMg/zgAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAgAAACWABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQ'
    'AFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAA'
    'UABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUABQAFAAUAAAAAAAAgAAAAMAAAAU'
    'AAMAAQAAABQABAAgAAAABAAEAAEAAAB+//8AAAAg////4QABAAAAAAAAAAAAAAANABoAJwA0AEEATgBbAGgAdQCCAI8AnACpALYA'
    'wwDQAN0A6gD3AQQBEQEeASsBOAFFAVIBXwFsAXkBhgGTAaABrQG6AccB1AHhAe4B+wIIAhUCIgIvAjwCSQJWAmMCcAJ9AooClwKk'
    'ArECvgLLAtgC5QLyAv8DDAMZAyYDMwNAA00DWgNnA3QDgQOOA5sDqAO1A8IDzwPcA+kD9gQDBBAEHQQqBDcERARRBF4EawR4BIUE'
    'kgSfBKwEuQTGAAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAAD'
    'AAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggC'
    'vAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAA'
    'AggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEA'
    'UAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwA'
    'AAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5I'
    'ArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVAB'
    'uP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyER'
    'IVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAA'
    'MyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwA'
    'AwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAII'
    'ArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAA'
    'AAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAAB'
    'AFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8'
    'AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+'
    'SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQ'
    'Abj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMh'
    'ESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMA'
    'ADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8'
    'AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAAC'
    'CAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQ'
    'AAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAA'
    'AQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgC'
    'vAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREhUAG4'
    '/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAzIREh'
    'UAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAADAAAz'
    'IREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggCvAAD'
    'AAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAAAggC'
    'vAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEAUAAA'
    'AggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwAAAEA'
    'UAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5IArwA'
    'AAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAQBQAAACCAK8AAMAADMhESFQAbj+SAK8AAABAFAAAAIIArwAAwAAMyERIVABuP5I'
    'ArwAAAEAUAAAAggCvAADAAAzIREhUAG4/kgCvAAAAAAEADYAAQAAAAAAAQARAAAAAQAAAAAAAgAHABEAAwABBAkAAQAiABgAAwAB'
    'BAkAAgAOADpUYXJ0ZWVsUXVsRml4dHVyZVJlZ3VsYXIAVABhAHIAdABlAGUAbABRAHUAbABGAGkAeAB0AHUAcgBlAFIAZQBnAHUA'
    'bABhAHIAAAACAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAAAAECAQMBBAEFAQYBBwEIAQkBCgELAQwBDQEOAQ8BEAER'
    'ARIBEwEUARUBFgEXARgBGQEaARsBHAEdAR4BHwEgASEBIgEjASQBJQEmAScBKAEpASoBKwEsAS0BLgEvATABMQEyATMBNAE1ATYB'
    'NwE4ATkBOgE7ATwBPQE+AT8BQAFBAUIBQwFEAUUBRgFHAUgBSQFKAUsBTAFNAU4BTwFQAVEBUgFTAVQBVQFWAVcBWAFZAVoBWwFc'
    'AV0BXgFfAWADZzIwA2cyMQNnMjIDZzIzA2cyNANnMjUDZzI2A2cyNwNnMjgDZzI5A2cyQQNnMkIDZzJDA2cyRANnMkUDZzJGA2cz'
    'MANnMzEDZzMyA2czMwNnMzQDZzM1A2czNgNnMzcDZzM4A2czOQNnM0EDZzNCA2czQwNnM0QDZzNFA2czRgNnNDADZzQxA2c0MgNn'
    'NDMDZzQ0A2c0NQNnNDYDZzQ3A2c0OANnNDkDZzRBA2c0QgNnNEMDZzREA2c0RQNnNEYDZzUwA2c1MQNnNTIDZzUzA2c1NANnNTUD'
    'ZzU2A2c1NwNnNTgDZzU5A2c1QQNnNUIDZzVDA2c1RANnNUUDZzVGA2c2MANnNjEDZzYyA2c2MwNnNjQDZzY1A2c2NgNnNjcDZzY4'
    'A2c2OQNnNkEDZzZCA2c2QwNnNkQDZzZFA2c2RgNnNzADZzcxA2c3MgNnNzMDZzc0A2c3NQNnNzYDZzc3A2c3OANnNzkDZzdBA2c3'
    'QgNnN0MDZzdEA2c3RQAA';
