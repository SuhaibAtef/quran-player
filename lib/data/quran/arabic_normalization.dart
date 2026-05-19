/// Canonical Arabic text normalisation for search.
///
/// Used by both the runtime repository (to normalise the user's query) and the
/// maintainer build tool (to populate the FTS5 index with already-normalised
/// text). Keeping a single source ensures the index and the query side agree
/// on alef-wasla/hamza/alef-maksura folding — without this, queries for plain
/// "الله" miss tokens like "ٱللَّه" that the bundled Tanzil text contains.
String normalizeArabicForSearch(String input) {
  final withoutMarks = input
      .replaceAll(RegExp(r'[ً-ٰٟۖ-ۭ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ـ', ' ');
  final lettersOnly = withoutMarks.replaceAll(RegExp(r'[^ء-ي٠-٩۰-۹ ]'), ' ');
  return lettersOnly.trim().replaceAll(RegExp(r'\s+'), ' ');
}
