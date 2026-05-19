/// Eastern Arabic-Indic digits ٠-٩, indexed by their Western digit value.
const _easternArabicDigits = <String>[
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩',
];

/// Formats [value] for display in UI chrome using [localeName]'s digit set —
/// Eastern Arabic-Indic digits (٠-٩) under Arabic, ASCII digits otherwise.
///
/// Substitution is explicit rather than `intl`-driven: `NumberFormat` keeps
/// `ar` on ASCII digits, so a deterministic mapping is what actually delivers
/// the Arabic digit set.
///
/// Display only. Stable identifiers — ayah keys, route parameters, persisted
/// storage keys, MCP arguments — MUST keep ASCII digits and never pass
/// through here. Pass the active locale via
/// `AppLocalizations.of(context).localeName`.
String localizedNumber(int value, String localeName) {
  final ascii = value.toString();
  if (!localeName.toLowerCase().startsWith('ar')) return ascii;
  final buffer = StringBuffer();
  for (final unit in ascii.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buffer.write(_easternArabicDigits[unit - 0x30]);
    } else {
      // Preserve a leading minus sign or any other character as-is.
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}
