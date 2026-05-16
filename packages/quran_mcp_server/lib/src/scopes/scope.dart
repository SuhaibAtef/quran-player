/// MCP scopes a host can grant to clients.
///
/// Per spec mcp-server, the master `Enable MCP` toggle implicitly grants
/// [Scope.readonly]. The two Mode B scopes ([Scope.playback], [Scope.bookmark])
/// are independent and default OFF. Each tool handler asks `ScopeCheck(...)`
/// at call time and returns `McpError(scopeDenied, ...)` when off.
enum Scope { readonly, playback, bookmark }

/// Callable injected by the host so the server can ask the active Settings
/// state for any scope. Read on every call so toggling a scope OFF in
/// Settings affects the very next MCP request without restarting the server.
typedef ScopeCheck = bool Function(Scope scope);

extension ScopeCheckSnapshot on ScopeCheck {
  /// CSV of currently-on scopes in declaration order — `"readonly,playback"`.
  /// Used as `audit_log.scope_at_time`.
  String snapshotCsv() {
    final on = <String>[];
    for (final s in Scope.values) {
      if (this(s)) on.add(s.name);
    }
    return on.join(',');
  }
}
