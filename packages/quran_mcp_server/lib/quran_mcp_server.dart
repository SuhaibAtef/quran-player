/// Public API surface of the Quran Companion MCP server workspace package.
///
/// This file re-exports only what the host Flutter app needs to wire the
/// server. The package's internals live under `src/` and are not part of the
/// public contract.
library;

export 'src/audit/args_summary.dart';
export 'src/audit/audit_entry.dart';
export 'src/audit/audit_log_repository.dart';
export 'src/dispatcher.dart' show DispatchResult;
export 'src/mcp_error.dart';
export 'src/mcp_lifecycle.dart';
export 'src/ports.dart';
export 'src/scopes/scope.dart';
export 'src/server.dart' show QuranMcpServer, mcpEndpointPath;
export 'src/tools/tool_definition.dart';
export 'src/tools/tool_handlers.dart'
    show mcpResourceDefinitions, mcpToolDefinitions, modeBToolNames;
export 'src/user_db/user_db.dart' show openUserDb;
