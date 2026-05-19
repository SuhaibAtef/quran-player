/// Structured error returned by MCP tool and resource handlers.
///
/// Pure data type — the host app is responsible for mapping its own
/// `Failure` hierarchy into an `McpError` at the boundary, since this package
/// is intentionally isolated from `package:quran_player/core/error/` to keep
/// the workspace dependency graph acyclic.
enum McpErrorCode {
  invalidInput,
  notFound,
  dataIntegrity,
  unavailable,
  permissionDenied,
  playerFailure,
  scopeDenied,
  unknown,
}

extension McpErrorCodeWire on McpErrorCode {
  /// snake_case wire name. Matches the spec scenarios (`scope_denied`,
  /// `invalid_input`, etc.) and MCP-ecosystem conventions for error codes.
  String get wireName => switch (this) {
    McpErrorCode.invalidInput => 'invalid_input',
    McpErrorCode.notFound => 'not_found',
    McpErrorCode.dataIntegrity => 'data_integrity',
    McpErrorCode.unavailable => 'unavailable',
    McpErrorCode.permissionDenied => 'permission_denied',
    McpErrorCode.playerFailure => 'player_failure',
    McpErrorCode.scopeDenied => 'scope_denied',
    McpErrorCode.unknown => 'unknown',
  };
}

class McpError {
  const McpError(this.code, this.message);

  final McpErrorCode code;
  final String message;

  Map<String, Object?> toJson() => {'code': code.wireName, 'message': message};
}

class McpException implements Exception {
  const McpException(this.error);

  final McpError error;

  @override
  String toString() => '${error.code.wireName}: ${error.message}';
}
