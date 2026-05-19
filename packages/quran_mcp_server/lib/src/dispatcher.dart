import 'audit/audit_entry.dart';
import 'audit/audit_log_repository.dart';
import 'mcp_error.dart';
import 'scopes/scope.dart';
import 'tools/tool_handlers.dart';

/// Result of a dispatched tool call. Either [data] is set (success — caller
/// renders it as a tool result), or [error] is set (failure — caller renders
/// it as a structured MCP error response).
class DispatchResult {
  const DispatchResult._({this.data, this.error});

  final Map<String, Object?>? data;
  final McpError? error;

  bool get isError => error != null;
}

/// Wraps every tool / resource call with:
/// - scope check for Mode B tools (returns `scope_denied` without invoking
///   the handler if the scope is off)
/// - audit_log write after the call (success or failure)
///
/// The dispatcher NEVER throws — handler exceptions are caught and turned
/// into [DispatchResult.error]. The protocol adapter only sees structured
/// outcomes.
class Dispatcher {
  Dispatcher({required this.handlers, required this.scopeCheck, this.audit});

  final ToolHandlers handlers;
  final ScopeCheck scopeCheck;

  /// May be null when `user.db` failed to open. In that case, calls still
  /// execute but no audit row is written (graceful degrade per R5).
  final AuditLogRepository? audit;

  Future<DispatchResult> callTool(
    String name,
    Map<String, Object?> args,
  ) async {
    final scopeAtTime = scopeCheck.snapshotCsv();

    if (modeBToolNames.contains(name) && !scopeCheck(Scope.playback)) {
      final err = McpError(
        McpErrorCode.scopeDenied,
        'Tool "$name" requires the playback scope. '
        'Enable "Allow MCP playback control" in Settings.',
      );
      await _appendAudit(
        toolName: name,
        argsSummary: renderArgsSummary(name, args),
        status: AuditResultStatus.scopeDenied,
        scopeAtTime: scopeAtTime,
      );
      return DispatchResult._(error: err);
    }

    try {
      final data = await handlers.call(name, args);
      await _appendAudit(
        toolName: name,
        argsSummary: renderArgsSummary(name, args),
        status: AuditResultStatus.ok,
        scopeAtTime: scopeAtTime,
      );
      return DispatchResult._(data: data);
    } on McpException catch (e) {
      await _appendAudit(
        toolName: name,
        argsSummary: renderArgsSummary(name, args),
        status: _statusForCode(e.error.code),
        scopeAtTime: scopeAtTime,
      );
      return DispatchResult._(error: e.error);
    } on Object catch (e) {
      final err = McpError(McpErrorCode.unknown, e.toString());
      await _appendAudit(
        toolName: name,
        argsSummary: renderArgsSummary(name, args),
        status: AuditResultStatus.error,
        scopeAtTime: scopeAtTime,
      );
      return DispatchResult._(error: err);
    }
  }

  Future<DispatchResult> readResource(String uri) async {
    final scopeAtTime = scopeCheck.snapshotCsv();
    try {
      final data = await handlers.readResource(uri);
      await _appendAudit(
        toolName: 'resource:$uri',
        argsSummary: '',
        status: AuditResultStatus.ok,
        scopeAtTime: scopeAtTime,
      );
      return DispatchResult._(data: data);
    } on McpException catch (e) {
      await _appendAudit(
        toolName: 'resource:$uri',
        argsSummary: '',
        status: _statusForCode(e.error.code),
        scopeAtTime: scopeAtTime,
      );
      return DispatchResult._(error: e.error);
    } on Object catch (e) {
      await _appendAudit(
        toolName: 'resource:$uri',
        argsSummary: '',
        status: AuditResultStatus.error,
        scopeAtTime: scopeAtTime,
      );
      return DispatchResult._(
        error: McpError(McpErrorCode.unknown, e.toString()),
      );
    }
  }

  Future<void> _appendAudit({
    required String toolName,
    required String argsSummary,
    required AuditResultStatus status,
    required String scopeAtTime,
  }) async {
    final repo = audit;
    if (repo == null) return;
    await repo.append(
      AuditEntry(
        tsUtcMillis: DateTime.now().toUtc().millisecondsSinceEpoch,
        toolName: toolName,
        argsSummary: argsSummary,
        resultStatus: status,
        scopeAtTime: scopeAtTime,
      ),
    );
  }

  AuditResultStatus _statusForCode(McpErrorCode code) => switch (code) {
    McpErrorCode.invalidInput => AuditResultStatus.invalidInput,
    McpErrorCode.notFound => AuditResultStatus.notFound,
    McpErrorCode.unavailable => AuditResultStatus.unavailable,
    McpErrorCode.scopeDenied => AuditResultStatus.scopeDenied,
    _ => AuditResultStatus.error,
  };
}
