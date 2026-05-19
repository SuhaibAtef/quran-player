import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../core/error/failure.dart';

/// Maps a host-side `Failure` into the workspace package's `McpError` shape.
///
/// Lives in the host app rather than the package because the package is
/// intentionally isolated from `package:quran_player/core/error/`. Tool
/// handlers that surface a repository failure call this at the boundary.
McpError mcpErrorFromFailure(Failure failure) {
  return switch (failure) {
    InvalidInputFailure() ||
    ValidationFailure() => McpError(McpErrorCode.invalidInput, failure.message),
    NotFoundFailure() => McpError(McpErrorCode.notFound, failure.message),
    DataIntegrityFailure() => McpError(
      McpErrorCode.dataIntegrity,
      failure.message,
    ),
    UnsupportedFailure() => McpError(
      McpErrorCode.invalidInput,
      failure.message,
    ),
    DataAccessFailure() ||
    IoFailure() ||
    NetworkFailure() => McpError(McpErrorCode.unavailable, failure.message),
    UnknownFailure() => McpError(McpErrorCode.unknown, failure.message),
  };
}
