sealed class Failure {
  const Failure(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause, super.stackTrace});
}

class IoFailure extends Failure {
  const IoFailure(super.message, {super.cause, super.stackTrace});
}

class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.field,
    super.cause,
    super.stackTrace,
  });

  final String? field;
}

class InvalidInputFailure extends Failure {
  const InvalidInputFailure(super.message, {super.cause, super.stackTrace});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(
    super.message, {
    this.key,
    super.cause,
    super.stackTrace,
  });

  final String? key;
}

class DataAccessFailure extends Failure {
  const DataAccessFailure(super.message, {super.cause, super.stackTrace});
}

class DataIntegrityFailure extends Failure {
  const DataIntegrityFailure(super.message, {super.cause, super.stackTrace});
}

class UnsupportedFailure extends Failure {
  const UnsupportedFailure(super.message, {super.cause, super.stackTrace});
}
