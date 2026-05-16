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

class McpError {
  const McpError(this.code, this.message);

  final McpErrorCode code;
  final String message;

  Map<String, Object?> toJson() => {'code': code.name, 'message': message};
}

class McpException implements Exception {
  const McpException(this.error);

  final McpError error;

  @override
  String toString() => '${error.code.name}: ${error.message}';
}
