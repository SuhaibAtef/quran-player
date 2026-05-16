## Why

The MCP server that landed in [`realign-mcp-server-implementation`](../realign-mcp-server-implementation/) ships a custom HTTP request/response shape (`POST /mcp` with `{"method":"...","params":{...}}` returning `{"result":...}` or `{"error":...}`). It works with `curl` and Postman but speaks no standardized MCP transport — no MCP Inspector, no Claude Desktop, no Cursor. Manual smoke testing requires the user to hand-craft JSON, and the only realistic interactive QA path is "trust the unit tests."

This change replaces the hand-rolled HTTP layer with `mcp_dart`'s `StreamableHTTPServerTransport`, putting the server on the standard MCP wire protocol (JSON-RPC `2.0` envelope + `mcp-session-id` header lifecycle) so any compliant streamable-HTTP client works. The bearer-token + loopback gate keeps running in front; every authorized request still flows through the existing `Dispatcher` (scope check + audit log).

## What Changes

- Replace the `POST /mcp` JSON shape with `mcp_dart`'s `StreamableHTTPServerTransport`. The transport speaks JSON-RPC `2.0` (`{"jsonrpc":"2.0","id":N,"method":"...","params":{...}}`) and manages a per-client session via the `mcp-session-id` request/response header.
- Connect the workspace package's `McpServer` (already constructed in `mcp_dart_adapter.dart`) to the transport via `server.connect(transport)`. Tool registration on `McpServer` is unchanged; the dispatcher / scope check / audit log wrapping that runs inside each tool callback is unchanged.
- Register the five `quran://...` resources through `mcp_dart`'s resource API so `resources/list` and `resources/read` work over the standard transport. Delete the hand-rolled `/resource/<uri>` HTTP path and `_handleResource` method.
- Keep the `HttpServer.bind(InternetAddress.loopbackIPv4, port)` listener and the bearer-token + per-request `connectionInfo.remoteAddress.isLoopback` checks. **Both checks run before the transport sees a request.** Unauthorized → `401`, never reaches `mcp_dart`. Non-loopback → `403`, never reaches `mcp_dart`.
- Drop the `GET /mcp` discovery endpoint (clients use `tools/list` / `resources/list` over the transport instead).
- **BREAKING for the hand-rolled shape only:** existing `curl` smoke commands that POST `{"method":"tools/list"}` (no `id`, no `jsonrpc`) stop working. The new shape requires the JSON-RPC envelope and a session-id handshake. Document the curl-with-JSON-RPC equivalent in the README.

## Capabilities

### New Capabilities
*(none)*

### Modified Capabilities

- `mcp-server`: ADDED requirements that lock the streamable HTTP wire protocol and session lifecycle, plus the resource discovery contract through the transport. The behavioural scenarios from `realign-mcp-server-implementation` (bearer-token gate, loopback enforcement, scope-denied semantics, audit-log writes, args_summary truncation) are unchanged at the contract level — only the transport that carries them changes.

## Impact

- **Code:**
  - `packages/quran_mcp_server/lib/src/server.dart`: replace `_handle` / `_handleMcp` / `_handleResource` with a thinner request handler that gates auth + loopback then forwards to `transport.handleRequest(req, res)` (or whatever the package's per-request entry point is named).
  - `packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart`: keep tool registration; add resource registration via `mcp_dart`'s resource template API; expose `transport` (or a `connect(httpRequest, httpResponse)` method) to `server.dart`.
  - The `Dispatcher`, `ToolHandlers`, `ScopeCheck`, `AuditLogRepository`, `McpQuranDataPort`, `McpAudioPort`, `HostQuranDataAdapter`, `HostAudioAdapter`, Settings UI, MCP Status UI, and `user.db` — **all unchanged**.
- **Dependencies:** none added or removed. `mcp_dart: ^2.1.1` is already in `packages/quran_mcp_server/pubspec.yaml`.
- **Tests:**
  - Replace the package's hand-rolled HTTP smoke (none currently — coverage was at the `Dispatcher` level) with a streamable-HTTP integration test that boots an in-memory `QuranMcpServer`, sends `initialize` / `tools/list` / `tools/call` / `resources/list` / `resources/read` over JSON-RPC, and asserts JSON-RPC envelopes come back with matching `id` fields.
  - Bearer-token-rejection test using a real JSON-RPC body to prove the gate runs before the transport.
  - Scope-denied integration test through the transport (Mode B `tools/call` with playback OFF → JSON-RPC error with `scope_denied` error code) including the audit-log row assertion.
  - The existing dispatcher / audit / args_summary unit tests are unchanged.
- **Docs:** README "MCP local integration" section gets new curl-with-JSON-RPC examples and a paragraph on connecting MCP Inspector. AGENTS.md *Project state* gets a one-line update mentioning streamable HTTP. THIRD_PARTY_NOTICES.md unchanged (`mcp_dart` already credited).
- **Hard constraints:** loopback-only (unchanged); bearer-token gate before transport (unchanged); `mcp_dart` only imported by `adapter/mcp_dart_adapter.dart` (unchanged); `Dispatcher` wraps every tool call with scope + audit (unchanged); no parallel data path (unchanged); `user.db` schema (unchanged).
- **Out of scope:** stdio transport (separate follow-up `add-stdio-mcp-sidecar` if needed for Claude Desktop's classic transport); SSE transport (legacy MCP shape, not pursued); new tools or resources; changes to the audit log or `user.db` schema.
- **Sequencing:** branch `feature/add-streamable-http-transport` is stacked on `feature/realign-mcp-server-implementation`. After the realignment PR merges to develop, this branch needs `git rebase --onto develop feature/realign-mcp-server-implementation` to drop the dependency commits cleanly. Open this PR after the realignment merges.
