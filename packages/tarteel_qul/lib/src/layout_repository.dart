import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'asset_source.dart';
import 'ayah_key.dart';
import 'models.dart';
import 'result.dart';

/// Columns the engine requires on the QUL layout `pages` table.
const _requiredPageColumns = <String>{
  'page_number',
  'line_number',
  'line_type',
  'is_centered',
  'first_word_id',
  'last_word_id',
  'surah_number',
};

/// Columns the engine requires on the QUL `words` table.
const _requiredWordColumns = <String>{'id', 'surah', 'ayah', 'word', 'text'};

/// Parses a QUL mushaf layout database (`pages`) joined against a QUL
/// word-script database (`words`) into typed [MushafPage] models, and exposes
/// the page↔ayah coordinate API.
///
/// Both databases are small; [open] reads them fully into memory and closes
/// the SQLite handles, so every method below is a synchronous in-memory lookup.
class MushafLayoutRepository {
  MushafLayoutRepository._({
    required this.pageCount,
    required this.linesPerPage,
    required Map<int, MushafPage> pages,
    required Map<AyahKey, int> ayahToPage,
    required Map<int, List<AyahKey>> pageToAyahs,
  }) : _pages = pages,
       _ayahToPage = ayahToPage,
       _pageToAyahs = pageToAyahs;

  /// Highest `page_number` in the layout — derived from data, not hard-coded.
  final int pageCount;

  /// Highest `line_number` in the layout — derived from data, not hard-coded.
  final int linesPerPage;

  final Map<int, MushafPage> _pages;
  final Map<AyahKey, int> _ayahToPage;
  final Map<int, List<AyahKey>> _pageToAyahs;

  /// Opens, validates, and parses the layout + word databases supplied by
  /// [source]. Returns a structured failure — never throws — when a database
  /// fails to open, is missing an expected table or column, or the
  /// layout↔word join is broken.
  static Future<MushafResult<MushafLayoutRepository>> open(
    MushafAssetSource source,
  ) async {
    _ensureFfiInitialized();

    Directory? scratch;
    Database? layoutDb;
    Database? wordDb;
    try {
      scratch = await Directory.systemTemp.createTemp('tarteel_qul_');

      final layoutBytes = await source.layoutDb();
      final wordBytes = await source.wordDb();

      layoutDb = await _openReadOnly(
        await _materialise(scratch, 'layout.db', layoutBytes),
      );
      wordDb = await _openReadOnly(
        await _materialise(scratch, 'words.db', wordBytes),
      );

      final layoutCheck = await _validateColumns(
        layoutDb,
        'pages',
        _requiredPageColumns,
      );
      if (layoutCheck != null) return MushafResult.err(layoutCheck);

      final wordCheck = await _validateColumns(
        wordDb,
        'words',
        _requiredWordColumns,
      );
      if (wordCheck != null) return MushafResult.err(wordCheck);

      final wordRows = await wordDb.rawQuery(
        'SELECT id, surah, ayah, word, text FROM words ORDER BY id',
      );
      if (wordRows.isEmpty) {
        return MushafResult.err(
          const MushafFailure(
            MushafFailureKind.schema,
            'word database `words` table is empty',
          ),
        );
      }

      final wordsById = <int, MushafWord>{};
      for (final row in wordRows) {
        final id = _toInt(row['id']);
        final surah = _toInt(row['surah']);
        final ayah = _toInt(row['ayah']);
        final wordIndex = _toInt(row['word']);
        final text = row['text'];
        if (id == null ||
            surah == null ||
            ayah == null ||
            wordIndex == null ||
            text is! String) {
          return MushafResult.err(
            MushafFailure(
              MushafFailureKind.schema,
              'word row has a missing or mistyped column: $row',
            ),
          );
        }
        wordsById[id] = MushafWord(
          id: id,
          text: text,
          surah: surah,
          ayah: ayah,
          wordIndex: wordIndex,
        );
      }

      final pageRows = await layoutDb.rawQuery(
        'SELECT page_number, line_number, line_type, is_centered, '
        'first_word_id, last_word_id, surah_number '
        'FROM pages ORDER BY page_number, line_number',
      );
      if (pageRows.isEmpty) {
        return MushafResult.err(
          const MushafFailure(
            MushafFailureKind.schema,
            'layout database `pages` table is empty',
          ),
        );
      }

      final linesByPage = <int, List<MushafLine>>{};
      var maxPage = 0;
      var maxLine = 0;
      for (final row in pageRows) {
        final pageNumber = _toInt(row['page_number']);
        final lineNumber = _toInt(row['line_number']);
        if (pageNumber == null || lineNumber == null) {
          return MushafResult.err(
            MushafFailure(
              MushafFailureKind.schema,
              'layout row has a non-integer page/line number: $row',
            ),
          );
        }
        final type = _lineType(row['line_type']);
        if (type == null) {
          return MushafResult.err(
            MushafFailure(
              MushafFailureKind.schema,
              'layout row has an unrecognised line_type '
              '"${row['line_type']}" on page $pageNumber',
            ),
          );
        }
        final lineResult = _buildLine(
          pageNumber: pageNumber,
          lineNumber: lineNumber,
          type: type,
          isCentered: _toInt(row['is_centered']) == 1,
          firstWordId: _toInt(row['first_word_id']),
          lastWordId: _toInt(row['last_word_id']),
          surahNumber: _toInt(row['surah_number']),
          wordsById: wordsById,
        );
        if (lineResult is MushafErr<MushafLine>) {
          return MushafResult.err(lineResult.failure);
        }
        linesByPage
            .putIfAbsent(pageNumber, () => <MushafLine>[])
            .add((lineResult as MushafOk<MushafLine>).value);
        if (pageNumber > maxPage) maxPage = pageNumber;
        if (lineNumber > maxLine) maxLine = lineNumber;
      }

      final pages = <int, MushafPage>{};
      final ayahToPage = <AyahKey, int>{};
      final pageToAyahs = <int, List<AyahKey>>{};
      for (final pageNumber in linesByPage.keys.toList()..sort()) {
        final lines = linesByPage[pageNumber]!;
        pages[pageNumber] = MushafPage(pageNumber: pageNumber, lines: lines);
        final ayahsOnPage = <AyahKey>[];
        final seen = <AyahKey>{};
        for (final line in lines) {
          for (final word in line.words) {
            final key = word.ayahKey;
            ayahToPage.putIfAbsent(key, () => pageNumber);
            if (seen.add(key)) ayahsOnPage.add(key);
          }
        }
        pageToAyahs[pageNumber] = List<AyahKey>.unmodifiable(ayahsOnPage);
      }

      return MushafResult.ok(
        MushafLayoutRepository._(
          pageCount: maxPage,
          linesPerPage: maxLine,
          pages: pages,
          ayahToPage: ayahToPage,
          pageToAyahs: pageToAyahs,
        ),
      );
    } catch (e) {
      return MushafResult.err(
        MushafFailure(
          MushafFailureKind.dataAccess,
          'failed to open QUL databases: $e',
        ),
      );
    } finally {
      await _closeQuietly(layoutDb);
      await _closeQuietly(wordDb);
      await _deleteQuietly(scratch);
    }
  }

  /// The page with the given 1-based [pageNumber], or an out-of-range failure.
  MushafResult<MushafPage> page(int pageNumber) {
    final fail = _requirePage(pageNumber);
    if (fail != null) return MushafResult.err(fail);
    return MushafResult.ok(_pages[pageNumber]!);
  }

  /// The page containing [key].
  MushafResult<int> pageForAyah(AyahKey key) {
    final page = _ayahToPage[key];
    if (page == null) {
      return MushafResult.err(
        MushafFailure(
          MushafFailureKind.outOfRange,
          'no page contains ayah ${key.surah}:${key.ayah}',
        ),
      );
    }
    return MushafResult.ok(page);
  }

  /// The first ayah on the given 1-based [page], in canonical order.
  MushafResult<AyahKey> firstAyahOnPage(int page) {
    final fail = _requirePage(page);
    if (fail != null) return MushafResult.err(fail);
    final ayahs = _pageToAyahs[page]!;
    if (ayahs.isEmpty) {
      return MushafResult.err(
        MushafFailure(
          MushafFailureKind.schema,
          'page $page carries no ayah words',
        ),
      );
    }
    return MushafResult.ok(ayahs.first);
  }

  /// Every ayah on the given 1-based [page], in canonical order.
  MushafResult<List<AyahKey>> ayahsOnPage(int page) {
    final fail = _requirePage(page);
    if (fail != null) return MushafResult.err(fail);
    return MushafResult.ok(_pageToAyahs[page]!);
  }

  /// The page containing the first ayah of [surahNumber] — equivalent to
  /// `pageForAyah(AyahKey(surahNumber, 1))`.
  MushafResult<int> pageForSurah(int surahNumber) =>
      pageForAyah(AyahKey(surahNumber, 1));

  MushafFailure? _requirePage(int page) {
    if (page < 1 || page > pageCount) {
      return MushafFailure(
        MushafFailureKind.outOfRange,
        'page $page is outside 1..$pageCount',
      );
    }
    return null;
  }

  // --- parsing helpers -----------------------------------------------------

  static MushafResult<MushafLine> _buildLine({
    required int pageNumber,
    required int lineNumber,
    required MushafLineType type,
    required bool isCentered,
    required int? firstWordId,
    required int? lastWordId,
    required int? surahNumber,
    required Map<int, MushafWord> wordsById,
  }) {
    if (type != MushafLineType.ayah) {
      return MushafResult.ok(
        MushafLine(
          lineNumber: lineNumber,
          type: type,
          isCentered: isCentered,
          surahNumber: type == MushafLineType.surahName ? surahNumber : null,
        ),
      );
    }
    if (firstWordId == null || lastWordId == null || firstWordId > lastWordId) {
      return MushafResult.err(
        MushafFailure(
          MushafFailureKind.schema,
          'ayah line $lineNumber on page $pageNumber has an invalid word '
          'range ($firstWordId..$lastWordId)',
        ),
      );
    }
    final words = <MushafWord>[];
    for (var id = firstWordId; id <= lastWordId; id++) {
      final word = wordsById[id];
      if (word == null) {
        return MushafResult.err(
          MushafFailure(
            MushafFailureKind.schema,
            'layout references word id $id on page $pageNumber but the word '
            'database has no such row',
          ),
        );
      }
      words.add(word);
    }
    return MushafResult.ok(
      MushafLine(
        lineNumber: lineNumber,
        type: type,
        isCentered: isCentered,
        words: words,
      ),
    );
  }

  static MushafLineType? _lineType(Object? raw) => switch (raw) {
    'ayah' => MushafLineType.ayah,
    'surah_name' => MushafLineType.surahName,
    'basmallah' => MushafLineType.basmallah,
    _ => null,
  };

  /// QUL layout databases store `''` (not NULL) in integer columns that do not
  /// apply to a row — e.g. `first_word_id` on a `surah_name` line. Treat any
  /// non-numeric value as "absent".
  static int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  // --- database helpers ----------------------------------------------------

  static bool _ffiInitialized = false;
  static void _ensureFfiInitialized() {
    if (_ffiInitialized) return;
    sqfliteFfiInit();
    _ffiInitialized = true;
  }

  static Future<String> _materialise(
    Directory scratch,
    String name,
    Uint8List bytes,
  ) async {
    final file = File(p.join(scratch.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<Database> _openReadOnly(String path) =>
      // The no-isolate factory runs SQLite on the calling isolate. `open` is a
      // one-shot read-everything-then-close, so the brief main-isolate work is
      // fine — and it avoids the background-isolate handshake, which deadlocks
      // when first invoked inside a `flutter_test` widget-test zone.
      databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );

  /// Returns a [MushafFailure] if [table] is absent or missing a [required]
  /// column; `null` when the schema is acceptable.
  static Future<MushafFailure?> _validateColumns(
    Database db,
    String table,
    Set<String> required,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    if (info.isEmpty) {
      return MushafFailure(
        MushafFailureKind.schema,
        'database is missing the required `$table` table',
      );
    }
    final present = info.map((row) => row['name'] as String).toSet();
    final missing = required.difference(present);
    if (missing.isNotEmpty) {
      return MushafFailure(
        MushafFailureKind.schema,
        '`$table` table is missing columns: ${missing.join(', ')}',
      );
    }
    return null;
  }

  static Future<void> _closeQuietly(Database? db) async {
    if (db == null) return;
    try {
      await db.close();
    } catch (_) {
      // Closing a read-only handle should not fail; ignore if it does.
    }
  }

  static Future<void> _deleteQuietly(Directory? dir) async {
    if (dir == null) return;
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // A leftover temp file is harmless; the OS reclaims it.
    }
  }
}
