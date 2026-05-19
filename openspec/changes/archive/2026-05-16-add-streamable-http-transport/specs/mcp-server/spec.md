## ADDED Requirements

This change ADDS code-level requirements that lock the standard MCP wire protocol and session lifecycle into the `mcp-server` capability. The behavioural scenarios from [`realign-mcp-server-implementation`](../../../realign-mcp-server-implementation/specs/mcp-server/spec.md) (R1–R7) are unchanged at the contract level — only the transport that carries them changes.

### Requirement: MCP server SHALL speak the standard streamable HTTP wire protocol

The MCP server SHALL accept requests in the JSON-RPC `2.0` envelope shape (`{"jsonrpc":"2.0","id":<n>,"method":"<name>","params":{...}}`) and return responses in the matching JSON-RPC `2.0` shape (`{"jsonrpc":"2.0","id":<n>,"result":{...}}` or `{"jsonrpc":"2.0","id":<n>,"error":{...}}`). The transport SHALL be `mcp_dart`'s `StreamableHTTPServerTransport` connected to the package's `McpServer` instance.

#### Scenario: tools/list returns a JSON-RPC envelope with matching id

- **WHEN** an integration test sends `POST http://127.0.0.1:<port>/mcp` with body `{"jsonrpc":"2.0","id":42,"method":"tools/list"}` and the bearer token in the `Authorization` header
- **THEN** the response is a JSON-RPC `2.0` envelope with `id` equal to `42` and a `result.tools` array containing the eleven tools from `mcpToolDefinitions`
- **AND** the response includes the `mcp-session-id` header

#### Scenario: tools/call returns a JSON-RPC envelope with the tool result

- **WHEN** an integration test sends `tools/call` with `params.name = 'get_ayah'` and `params.arguments = {surah: 2, ayah: 255}` and the request is authorized and in-scope
- **THEN** the response is a JSON-RPC `2.0` envelope with the matching `id` and `result.content` containing the canonical Ayat al-Kursi text
- **AND** an `audit_log` row is appended with `tool_name='get_ayah'` and `result_status='ok'`

#### Scenario: malformed envelope returns a JSON-RPC error response

- **WHEN** an integration test sends `POST /mcp` with an authorized request whose body is not a valid JSON-RPC envelope (missing `jsonrpc` field, missing `method`, etc.)
- **THEN** the response is a JSON-RPC `2.0` error envelope (or a `400` with a JSON-RPC error body — whichever `mcp_dart`'s transport produces)
- **AND** no tool handler is invoked

### Requirement: MCP server SHALL manage per-client sessions via the mcp-session-id header

The streamable HTTP transport SHALL generate a unique `mcp-session-id` for each new client and SHALL accept that header on subsequent requests within the same client session. Sessions SHALL be in-memory only and SHALL be discarded when the server is stopped.

#### Scenario: First request creates a session

- **WHEN** an integration test sends a JSON-RPC request with no `mcp-session-id` header
- **THEN** the response includes a freshly generated `mcp-session-id` header value
- **AND** the value is a high-entropy string (UUID or equivalent)

#### Scenario: Subsequent requests with the same session-id reuse the session

- **WHEN** an integration test sends a second JSON-RPC request with the `mcp-session-id` header from the first response
- **THEN** the request is accepted by the transport without an `initialize` re-handshake
- **AND** the response includes the same `mcp-session-id` header

#### Scenario: Sessions do not survive server restart

- **WHEN** the server is stopped and restarted
- **THEN** a JSON-RPC request with the previous session's `mcp-session-id` header is treated as a new session (not rejected, but a new session-id is issued)

### Requirement: Resources SHALL be discoverable through the streamable HTTP transport

The five `quran://...` resources SHALL be registered with `mcp_dart`'s resource API so they are returned by the standard `resources/list` JSON-RPC method and readable through `resources/read`. The custom `/resource/<uri>` HTTP path is REMOVED.

#### Scenario: resources/list returns the five Quran resources

- **WHEN** an integration test sends `{"jsonrpc":"2.0","id":1,"method":"resources/list"}` over the transport
- **THEN** the response's `result.resources` array contains entries for `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, and `quran://reciters`

#### Scenario: resources/read for a static URI returns the resource contents

- **WHEN** an integration test sends `{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"quran://surahs"}}`
- **THEN** the response's `result.contents` contains the 114-surah list from `QuranRepository.listSurahs()`
- **AND** an `audit_log` row is appended with `tool_name='resource:quran://surahs'` (or the equivalent prefix the dispatcher uses) and `result_status='ok'`

### Requirement: Bearer-token gate SHALL run before the streamable HTTP transport

For every incoming HTTP request, the bearer-token check SHALL run before the request body is forwarded to `StreamableHTTPServerTransport`. Unauthorized requests SHALL receive a `401` response and SHALL NOT cause the transport to create a session, parse the body, or dispatch a method.

#### Scenario: Missing bearer token returns 401 with no session created

- **WHEN** an integration test sends a perfectly valid JSON-RPC `tools/list` request without the `Authorization` header
- **THEN** the response status is `401`
- **AND** the response does NOT include a `mcp-session-id` header
- **AND** no audit_log row is appended (the dispatcher is never reached)

#### Scenario: Wrong bearer token returns 401

- **WHEN** an integration test sends a valid JSON-RPC request with `Authorization: Bearer wrong-token`
- **THEN** the response status is `401`
- **AND** no transport state is mutated

### Requirement: Loopback origin check SHALL run before the streamable HTTP transport

The per-request `connectionInfo.remoteAddress.isLoopback` check SHALL fire on every request before the request body is forwarded to the transport. Non-loopback connections SHALL receive `403` and SHALL NOT cause the transport to be invoked.

#### Scenario: Non-loopback request is rejected before transport sees it

- **WHEN** an integration test simulates a request whose `connectionInfo.remoteAddress.isLoopback` is `false`
- **THEN** the response status is `403`
- **AND** no JSON-RPC envelope is parsed

### Requirement: Streamable HTTP tool calls SHALL preserve scope-check and audit-log semantics

Every `tools/call` flowing through the streamable HTTP transport SHALL pass through `Dispatcher.callTool`, which preserves the spec mcp-server R3 (scope-denied error) and R6 (both-modes audit write) contracts.

#### Scenario: Scope-denied Mode B call returns JSON-RPC error and writes audit row

- **WHEN** an integration test sends `tools/call` for `play_surah` with the playback scope OFF, over the streamable HTTP transport
- **THEN** the response is a JSON-RPC `2.0` envelope with an `error` field whose `code` or `data` indicates `scope_denied`
- **AND** an `audit_log` row is appended with `tool_name='play_surah'` and `result_status='scope_denied'`
- **AND** the audio bridge is not invoked

#### Scenario: Both Mode A and Mode B calls over the transport append audit rows

- **WHEN** an integration test sends `tools/call` for `search_quran` (Mode A) and then `pause_playback` (Mode B with playback scope ON), both over the streamable HTTP transport
- **THEN** two `audit_log` rows are appended, one per call, each with the correct `tool_name`, `result_status`, and `scope_at_time`

<!--
Note: the hand-rolled `POST /mcp` JSON shape, the `GET /mcp` discovery
endpoint, and the `/resource/<uri>` path that the realignment shipped were
never discrete `### Requirement:` blocks in the canonical `mcp-server` spec —
they were implementation details described inside other requirements'
scenarios. The ADDED requirements above supersede them; there is nothing to
list under a `## REMOVED Requirements` header. The README and the
add-streamable-http-transport proposal document the client-facing migration.
-->

