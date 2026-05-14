import '../../core/error/failure.dart';

enum McpErrorCode {
  invalidInput,
  notFound,
  dataIntegrity,
  unavailable,
  permissionDenied,
  playerFailure,
  unknown,
}

class McpError {
  const McpError(this.code, this.message);

  final McpErrorCode code;
  final String message;

  Map<String, Object?> toJson() => {'code': code.name, 'message': message};

  static McpError fromFailure(Failure failure) {
    return switch (failure) {
      InvalidInputFailure() || ValidationFailure() => McpError(
        McpErrorCode.invalidInput,
        failure.message,
      ),
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
}

class McpException implements Exception {
  const McpException(this.error);

  final McpError error;

  @override
  String toString() => '${error.code.name}: ${error.message}';
}
