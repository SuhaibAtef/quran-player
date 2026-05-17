import 'package:flutter/foundation.dart';

import 'ayah_key.dart';

/// The role a [MushafLine] plays on its page, mirroring the QUL layout's
/// `pages.line_type` column.
enum MushafLineType {
  /// A line of Quran text — carries one or more [MushafWord]s.
  ayah,

  /// An ornamental surah-title line — carries a [MushafLine.surahNumber] but
  /// no words.
  surahName,

  /// A basmala line — carries neither words nor a surah number.
  basmallah,
}

/// One word on a mushaf line: the glyph-code string the per-page font renders,
/// plus the surah/ayah coordinates that map it back to canonical text.
@immutable
class MushafWord {
  const MushafWord({
    required this.id,
    required this.text,
    required this.surah,
    required this.ayah,
    required this.wordIndex,
  });

  /// `words.id` — the engine's stable identity for this word, and the value
  /// joined against the layout's `first_word_id..last_word_id` range.
  final int id;

  /// The glyph-code string rendered by the page font (1–3 codepoints). This is
  /// rendering data only — never canonical Quran text.
  final String text;

  /// 1-based surah number.
  final int surah;

  /// 1-based ayah number within [surah].
  final int ayah;

  /// 1-based index of this word within its ayah (`words.word`).
  final int wordIndex;

  /// The ayah this word belongs to.
  AyahKey get ayahKey => AyahKey(surah, ayah);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MushafWord &&
          other.id == id &&
          other.text == text &&
          other.surah == surah &&
          other.ayah == ayah &&
          other.wordIndex == wordIndex;

  @override
  int get hashCode => Object.hash(id, text, surah, ayah, wordIndex);

  @override
  String toString() => 'MushafWord(#$id $surah:$ayah:$wordIndex)';
}

/// One rendered line of a [MushafPage].
@immutable
class MushafLine {
  const MushafLine({
    required this.lineNumber,
    required this.type,
    required this.isCentered,
    this.surahNumber,
    this.words = const <MushafWord>[],
  });

  /// 1-based line number within the page.
  final int lineNumber;

  final MushafLineType type;

  /// Whether the line is centered rather than justified to the full text-block
  /// width.
  final bool isCentered;

  /// The surah this line titles — set only for [MushafLineType.surahName].
  final int? surahNumber;

  /// The line's words in id order — populated only for [MushafLineType.ayah].
  final List<MushafWord> words;

  @override
  String toString() =>
      'MushafLine($lineNumber, ${type.name}, centered=$isCentered, '
      'words=${words.length})';
}

/// A fully resolved mushaf page: its lines in `line_number` order.
@immutable
class MushafPage {
  const MushafPage({required this.pageNumber, required this.lines});

  /// 1-based page number.
  final int pageNumber;

  final List<MushafLine> lines;

  @override
  String toString() => 'MushafPage($pageNumber, ${lines.length} lines)';
}
