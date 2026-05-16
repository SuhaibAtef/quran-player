import '../mcp_error.dart';

int requiredInt(Map<String, Object?> args, String field) {
  final value = args[field];
  if (value is int) return value;
  throw McpException(
    McpError(McpErrorCode.invalidInput, 'Expected integer field "$field".'),
  );
}

String requiredString(Map<String, Object?> args, String field) {
  final value = args[field];
  if (value is String) return value;
  throw McpException(
    McpError(McpErrorCode.invalidInput, 'Expected string field "$field".'),
  );
}

String? optionalString(Map<String, Object?> args, String field) {
  final value = args[field];
  if (value == null) return null;
  if (value is String) return value;
  throw McpException(
    McpError(McpErrorCode.invalidInput, 'Expected string field "$field".'),
  );
}

int validateSurahNumber(int value) {
  if (value < 1 || value > 114) {
    throw const McpException(
      McpError(McpErrorCode.invalidInput, 'Surah must be in 1..114.'),
    );
  }
  return value;
}

({int surah, int ayah}) requireAyahKeyArgs(Map<String, Object?> args) {
  final surah = validateSurahNumber(requiredInt(args, 'surah'));
  final ayah = requiredInt(args, 'ayah');
  if (ayah < 1) {
    throw const McpException(
      McpError(McpErrorCode.invalidInput, 'Ayah must be >= 1.'),
    );
  }
  return (surah: surah, ayah: ayah);
}
