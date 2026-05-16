/// Truncates a free-text query for storage in `audit_log.args_summary`.
///
/// Per spec mcp-server R7: queries up to [maxCodepoints] codepoints are stored
/// verbatim. Longer queries are stored as the first [maxCodepoints] codepoints
/// followed by the marker `…[+N more]` where `N` is the number of additional
/// codepoints not stored. Counts codepoints (Dart `runes`) so multi-byte
/// characters like Arabic letters and combining marks are handled correctly.
String truncateForArgsSummary(String input, {int maxCodepoints = 128}) {
  if (maxCodepoints <= 0) {
    throw ArgumentError.value(
      maxCodepoints,
      'maxCodepoints',
      'must be positive',
    );
  }
  final runes = input.runes.toList(growable: false);
  if (runes.length <= maxCodepoints) {
    return input;
  }
  final kept = String.fromCharCodes(runes.take(maxCodepoints));
  final extra = runes.length - maxCodepoints;
  return '$kept…[+$extra more]';
}
