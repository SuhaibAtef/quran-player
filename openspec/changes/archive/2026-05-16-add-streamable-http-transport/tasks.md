## 1. mcp_dart API verification (do this BEFORE any code changes)

- [x] 1.1 Read `mcp_dart` 2.1.1's transport + server source to confirm the API. Findings:
      - Transport file is `lib/src/server/streamable_https.dart`. Constructor: `StreamableHTTPServerTransport({required StreamableHTTPServerTransportOptions options})`. Options: `sessionIdGenerator`, `onsessioninitialized`, `enableJsonResponse` (default false → SSE; set true), `eventStore`, `enableDnsRebindingProtection` (default **true** → set false since we enforce loopback ourselves), `allowedHosts`/`allowedOrigins`.
      - Per-request entry point: `Future<void> handleRequest(HttpRequest req, [dynamic parsedBody])`. Takes the raw `HttpRequest`. Perfect for our gate-then-forward pattern.
      - `McpServer.connect(Transport)` is `async`. Tear-down via `transport.close()` + `server.close()`.
      - Resources: `registerResource(name, uri, ResourceMetadata?, ReadResourceCallback)` where `ResourceMetadata` is a record typedef `({String? description, String? mimeType})` and `ReadResourceCallback` is `FutureOr<ReadResourceResult> Function(Uri, RequestHandlerExtra)`. `ReadResourceResult(contents: [TextResourceContents(uri:, mimeType:, text:)])`. Templates use `registerResourceTemplate(name, ResourceTemplateRegistration(...), ...)` — more complex; deferred.
- [x] 1.2 No deviation from design.md S1 / S3 — the API matched the assumptions. One refinement: `enableDnsRebindingProtection` defaults to `true`; we explicitly set it `false` (we enforce loopback at the listener + per-request check).

## 2. Resource registration through mcp_dart

- [x] 2.1 Add a resource registration loop to `mcp_dart_adapter.dart` (`_registerResources`) that walks `mcpResourceDefinitions` and registers each static `quran://...` URI via `s.registerResource(...)`. The read callback routes through `Dispatcher.readResource(uri)` so scope/audit semantics are preserved.
- [x] 2.2 Templated URIs (`quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`) — *not registered as `mcp_dart` resource templates in this first cut. The adapter skips any URI containing `{` and an inline comment documents that clients use the equivalent `get_surah` / `get_ayah` tools. README + spec note the limitation.*
- [x] 2.3 Delete the now-unused `McpDartAdapter.readResource` shortcut method.

## 3. Wire StreamableHTTPServerTransport into the existing HttpServer

- [x] 3.1 `mcp_dart_adapter.dart` gains an async `start()` that builds the `McpServer`, registers tools + resources, constructs `StreamableHTTPServerTransport` (`sessionIdGenerator` = 32-char hex from `Random.secure()`, `enableDnsRebindingProtection: false`, `enableJsonResponse: true`), and `await`s `s.connect(transport)`. A `handleRequest(HttpRequest)` method forwards to `transport.handleRequest(...)`. A `stop()` closes both.
- [x] 3.2 `server.dart`'s `_serve` loop now: runs the loopback + bearer gates, 404s any non-`/mcp` path, then forwards to `_adapter.handleRequest(request)`. The transport owns JSON-RPC parsing, session-id management, response framing. `QuranMcpServer.start()` awaits `_adapter.start()` before binding; `stop()` calls `_adapter.stop()`.
- [x] 3.3 Deleted `_handleResource` and the `mcpResourcePathPrefix` constant.
- [x] 3.4 Deleted the `GET /mcp` discovery branch (and the whole `_handleMcp` / `_handle` method tree).

## 4. Bearer + loopback gates stay verbatim

- [x] 4.1 Bearer-token check and `connectionInfo.remoteAddress.isLoopback` check in `server.dart`'s `_serve` loop are unchanged and run before `_adapter.handleRequest(...)`. Verified by the integration test's bearer-gate cases (401 with no session, no audit row).

## 5. Integration test: real ephemeral server, JSON-RPC roundtrips

- [x] 5.1 Added `packages/quran_mcp_server/test/streamable_http_transport_test.dart` — boots a real `QuranMcpServer` on `port: 0`, talks JSON-RPC over `dart:io` `HttpClient`, tears down in `tearDown`. Helper `initialize()` drives the MCP handshake and returns the session id.
- [x] 5.2 Test: initialize + `tools/list` — asserts `id`, `jsonrpc: "2.0"`, `result.tools.length == 11`, and a `mcp-session-id` response header.
- [x] 5.3 Test: `tools/call` `get_ayah` (Mode A) — asserts the canonical text in the result content, an `audit_log` row with `result_status='ok'`.
- [x] 5.4 Test: `tools/call` `play_surah` (Mode B) with playback scope OFF — asserts the `CallToolResult` `isError:true` with `scope_denied` in the content, an `audit_log` row with `result_status='scope_denied'`, and the audio bridge was NOT invoked.
- [x] 5.5 Test: bearer-token gate — valid body without `Authorization` → `401`, no `mcp-session-id` header, no `audit_log` row. Also a wrong-token case.
- [x] 5.6 Test: session reuse — `tools/list` then a second `tools/list` with the same `mcp-session-id`, both succeed.
- [x] 5.7 Test: `resources/list` returns the three static `quran://...` entries (templated URIs deferred — see 2.2).
- [x] 5.8 Test: `resources/read` for `quran://surahs` returns the surah list and writes an audit row.
- [x] 5.9 *(found during 5.4)* Fixed `McpErrorCode` serialization: `toJson` emitted the camelCase enum name (`scopeDenied`); spec + MCP convention want snake_case (`scope_denied`). Added a `wireName` extension mapping each code to snake_case. The integration test caught the divergence the realignment's dispatcher-level tests missed.

## 6. README + AGENTS update

- [x] 6.1 README *MCP local integration* rewritten: streamable-HTTP framing note, an "Connect with MCP Inspector" subsection, and a "Connect with curl (JSON-RPC `2.0`)" subsection with a worked initialize → tools/list → tools/call sequence plus the unauthorized-`401` example.
- [x] 6.2 `AGENTS.md` *Project state* "Local MCP surface" bullet now states authorized requests are forwarded to `mcp_dart`'s `StreamableHTTPServerTransport` (standard JSON-RPC `2.0` + `mcp-session-id`).
- [x] 6.3 `AGENTS.md` *Notes for future work* MCP entry updated: describes the transport handoff and adds the rule that the bearer + loopback gates MUST stay in `server.dart` ahead of the transport.

## 7. Verification

- [x] 7.1 `just check` clean — format, analyze, host 140/140 + package 32/32 (was 23; +9 streamable HTTP integration tests).
- [x] 7.2 `openspec validate add-streamable-http-transport` clean.
- [x] 7.3 `isolation_test.dart` passes — `package:mcp_dart` still imported only by `adapter/mcp_dart_adapter.dart` after the rewrite.
- [ ] 7.4 Manual smoke: enable MCP in Settings, copy the URL+token; run `npx @modelcontextprotocol/inspector`, paste the URL into the Streamable HTTP transport field, paste the token into the Authorization header field, click "List Tools" → see all 11; click `get_ayah` → enter `surah=2 ayah=255` → see Ayat al-Kursi text.
- [ ] 7.5 Manual smoke: toggle `Allow MCP playback control` OFF in Settings, call `play_surah` with `surah=36` from MCP Inspector, confirm the response is a JSON-RPC error with `scope_denied` and the player state is unchanged.
- [ ] 7.6 Manual smoke: confirm an audit_log entry is appended for each call by visiting the MCP Status page and checking the "Recent audit log (last 20)" section.

## 8. Sequencing reminder (NOT a code task)

- [ ] 8.1 This branch is stacked on `feature/realign-mcp-server-implementation`. Before opening this PR: ensure the realignment PR has merged to `develop`, then run `git fetch && git rebase --onto develop feature/realign-mcp-server-implementation` to drop the dependency commits cleanly. Push, then open the PR against `develop`.
