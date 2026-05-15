## 1. mcp_dart API verification (do this BEFORE any code changes)

- [ ] 1.1 Read `mcp_dart` 2.1.1's `lib/src/server/streamable_http_server_transport.dart` (and the example at `example/elicitation_http_server.dart`) to confirm:
      - The exact constructor signature of `StreamableHTTPServerTransport` and `StreamableHTTPServerTransportOptions` (particularly `sessionIdGenerator`, `onsessioninitialized`, `eventStore` if needed for our case).
      - The per-request dispatch entry point (e.g. `transport.handleRequest(req, res)` vs. event-based vs. attach-to-stream). Note the exact API in this task before proceeding.
      - The `McpServer.connect(transport)` lifecycle.
      - The resource registration API (`registerResource` / `registerResourceTemplate` / `setRequestHandler('resources/list', ...)` — whatever 2.1.1 exposes).
- [ ] 1.2 If 1.1 finds an API significantly different from what design.md S1 / S3 assume, document the deviation in design.md before writing implementation code.

## 2. Resource registration through mcp_dart

- [ ] 2.1 Add a resource registration loop to `packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart` that walks `mcpResourceDefinitions` and registers each through `mcp_dart`'s API (the exact call shape comes from 1.1). Each registered resource's read callback routes through `Dispatcher.readResource(uri)` so scope/audit semantics are preserved.
- [ ] 2.2 If the API supports URI templates with `{surah}` / `{ayah}` placeholders, register `quran://surah/{surah}` and `quran://ayah/{surah}/{ayah}` as templates. If not, document the limitation in `mcp_dart_adapter.dart` and note it in the README during Section 6.
- [ ] 2.3 Delete the now-unused `McpDartAdapter.readResource` shortcut method.

## 3. Wire StreamableHTTPServerTransport into the existing HttpServer

- [ ] 3.1 In `packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart`, construct `StreamableHTTPServerTransport` with `sessionIdGenerator: () => _generateSessionId()` (use `Random.secure()` UUID-style string). Connect it to the `McpServer` via `protocolServer.connect(transport)`. Expose the transport (or a `handleRequest(HttpRequest, HttpResponse)` wrapper) so `server.dart` can hand authorized requests to it.
- [ ] 3.2 In `packages/quran_mcp_server/lib/src/server.dart`, replace `_handleMcp` with a thinner handler that:
      - Verifies the request is `POST` (or whatever methods mcp_dart's transport supports — confirm in 1.1).
      - Forwards the `HttpRequest` / `HttpResponse` (after our existing bearer + loopback gates pass) into the transport via the entry point from 3.1.
      - Lets the transport own the JSON-RPC parsing, session-id management, response framing, and `mcp-session-id` header emission.
- [ ] 3.3 Delete `_handleResource` and the `mcpResourcePathPrefix` constant.
- [ ] 3.4 Delete the `GET /mcp` discovery branch from `_handleMcp`.

## 4. Bearer + loopback gates stay verbatim

- [ ] 4.1 Confirm via diff review that the bearer-token check and `connectionInfo.remoteAddress.isLoopback` check in `server.dart`'s `_serve` loop are unchanged. They MUST run before `transport.handleRequest(...)`. (Spec R: "bearer-token gate before transport" and "loopback check before transport".)

## 5. Integration test: real ephemeral server, JSON-RPC roundtrips

- [ ] 5.1 Add `packages/quran_mcp_server/test/streamable_http_transport_test.dart` that uses `RecordingQuranPort` + `RecordingAudioPort` to construct a `QuranMcpServer`, calls `server.start(port: 0)`, captures the OS-assigned port and bearer token from the returned `McpServerStatus`, and tears down the server in `tearDown`.
- [ ] 5.2 Test: `tools/list` JSON-RPC roundtrip — sends `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`, asserts response `id == 1`, `jsonrpc == "2.0"`, `result.tools.length == 11`, and the response includes a `mcp-session-id` header.
- [ ] 5.3 Test: `tools/call` for `get_ayah` (Mode A) — asserts JSON-RPC envelope with the expected text, asserts an `audit_log` row with `result_status='ok'` and `tool_name='get_ayah'`.
- [ ] 5.4 Test: `tools/call` for `play_surah` (Mode B) with playback scope OFF — asserts JSON-RPC error envelope with `scope_denied` indication, asserts an `audit_log` row with `result_status='scope_denied'`, asserts the audio bridge was NOT invoked.
- [ ] 5.5 Test: bearer-token gate — sends a valid JSON-RPC `tools/list` body without the `Authorization` header, asserts `401` response, asserts NO `mcp-session-id` header in the response, asserts NO `audit_log` row.
- [ ] 5.6 Test: session reuse — does `tools/list`, captures the `mcp-session-id`, sends a second `tools/list` with that header, asserts both succeed and the same session-id comes back.
- [ ] 5.7 Test: `resources/list` returns the five `quran://...` entries.
- [ ] 5.8 Test: `resources/read` for `quran://surahs` returns the surah list and writes an audit row.

## 6. README + AGENTS update

- [ ] 6.1 Replace the curl examples in `README.md` *MCP local integration* with the JSON-RPC `2.0` shape:
      - `tools/list` with `id` and `jsonrpc` fields
      - `tools/call` with the new params shape (`name` + `arguments`)
      - `resources/read`
      - The unauthorized-request `401` example
      - Add a paragraph: "Connect MCP Inspector by running `npx @modelcontextprotocol/inspector` and pasting the URL + token into its Streamable HTTP form."
- [ ] 6.2 Update `AGENTS.md` *Project state* to mention `mcp_dart`'s `StreamableHTTPServerTransport` is in use.
- [ ] 6.3 Update `AGENTS.md` *Notes for future work* MCP entry to remove the "we don't use mcp_dart's StreamableHTTPServerTransport" caveat.

## 7. Verification

- [ ] 7.1 `just check` clean — format, analyze, all tests pass including the new streamable HTTP integration tests.
- [ ] 7.2 `openspec validate add-streamable-http-transport` clean.
- [ ] 7.3 `flutter test packages/quran_mcp_server/test/isolation_test.dart` — confirms `package:mcp_dart` is still imported only by `adapter/mcp_dart_adapter.dart` after the changes.
- [ ] 7.4 Manual smoke: enable MCP in Settings, copy the URL+token; run `npx @modelcontextprotocol/inspector`, paste the URL into the Streamable HTTP transport field, paste the token into the Authorization header field, click "List Tools" → see all 11; click `get_ayah` → enter `surah=2 ayah=255` → see Ayat al-Kursi text.
- [ ] 7.5 Manual smoke: toggle `Allow MCP playback control` OFF in Settings, call `play_surah` with `surah=36` from MCP Inspector, confirm the response is a JSON-RPC error with `scope_denied` and the player state is unchanged.
- [ ] 7.6 Manual smoke: confirm an audit_log entry is appended for each call by visiting the MCP Status page and checking the "Recent audit log (last 20)" section.

## 8. Sequencing reminder (NOT a code task)

- [ ] 8.1 This branch is stacked on `feature/realign-mcp-server-implementation`. Before opening this PR: ensure the realignment PR has merged to `develop`, then run `git fetch && git rebase --onto develop feature/realign-mcp-server-implementation` to drop the dependency commits cleanly. Push, then open the PR against `develop`.
