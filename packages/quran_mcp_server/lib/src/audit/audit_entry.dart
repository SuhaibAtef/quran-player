/// Recognized values of `audit_log.result_status`.
///
/// The schema CHECK constraint mirrors this list verbatim — see
/// [`user_db_schema.dart`](../user_db/user_db_schema.dart).
enum AuditResultStatus {
  ok,
  scopeDenied,
  invalidInput,
  notFound,
  unavailable,
  error,
}

extension AuditResultStatusSql on AuditResultStatus {
  String get sqlValue => switch (this) {
    AuditResultStatus.ok => 'ok',
    AuditResultStatus.scopeDenied => 'scope_denied',
    AuditResultStatus.invalidInput => 'invalid_input',
    AuditResultStatus.notFound => 'not_found',
    AuditResultStatus.unavailable => 'unavailable',
    AuditResultStatus.error => 'error',
  };

  static AuditResultStatus fromSqlValue(String value) => switch (value) {
    'ok' => AuditResultStatus.ok,
    'scope_denied' => AuditResultStatus.scopeDenied,
    'invalid_input' => AuditResultStatus.invalidInput,
    'not_found' => AuditResultStatus.notFound,
    'unavailable' => AuditResultStatus.unavailable,
    'error' => AuditResultStatus.error,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unknown audit result status',
    ),
  };
}

class AuditEntry {
  const AuditEntry({
    this.id,
    required this.tsUtcMillis,
    required this.toolName,
    required this.argsSummary,
    required this.resultStatus,
    required this.scopeAtTime,
  });

  final int? id;
  final int tsUtcMillis;
  final String toolName;
  final String argsSummary;
  final AuditResultStatus resultStatus;

  /// Comma-separated list of scope names that were ON at call time.
  /// Example: `"readonly,playback"`.
  final String scopeAtTime;
}
