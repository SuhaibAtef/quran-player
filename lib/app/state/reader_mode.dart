/// Whether the reader presents the printed-mushaf page layout (page mode,
/// via `qcf_quran_plus`) or a continuous text scroll sourced from
/// `QuranRepository` (text mode).
///
/// The string [storageKey] is what gets persisted to `SharedPreferences`.
/// Persisting the enum *index* would silently re-map if a future change
/// inserted a third mode in the middle of the enum; the string is stable.
enum ReaderMode {
  page('page'),
  text('text');

  const ReaderMode(this.storageKey);

  final String storageKey;

  /// Parses a stored value back to a mode. Falls back to [ReaderMode.page]
  /// for missing, empty, or unknown values — never throws.
  static ReaderMode fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return ReaderMode.page;
    for (final mode in ReaderMode.values) {
      if (mode.storageKey == raw) return mode;
    }
    return ReaderMode.page;
  }
}
