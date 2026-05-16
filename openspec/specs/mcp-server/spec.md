# mcp-server Specification

## Purpose
TBD - created by archiving change add-mcp-server. Update Purpose after archive.
## Requirements
### Requirement: Local-only MCP server lifecycle

The system SHALL provide an in-app local MCP server for approved local clients and SHALL NOT expose any remote network listener, arbitrary file access, or shell command execution capability. The server lifecycle MUST be observable as `disabled`, `starting`, `running`, `stopped`, or `failed`.

#### Scenario: Server starts in local-only mode

- **WHEN** the MCP server is started from the app
- **THEN** it binds only to a loopback address and does not bind a public TCP, UDP, WebSocket, or remote-access listener

#### Scenario: Server exposes plain HTTP local client details

> Originally proposed as `Server exposes authenticated HTTPS local client details`; corrected to plain HTTP per `align-mcp-server-with-explore-decisions` D1.

- **WHEN** the MCP server is running
- **THEN** the app exposes an `http://127.0.0.1:<port>/mcp` MCP URL and a per-server-start bearer token that local LLM/MCP clients can use

#### Scenario: Missing token is rejected

- **WHEN** a local client calls the HTTP MCP endpoint without the displayed bearer token in the `Authorization: Bearer <token>` header
- **THEN** the server returns a `401 Unauthorized` response and does not execute a tool or resource handler

#### Scenario: HTTP endpoint remains local

> Originally `HTTPS endpoint remains local`; TLS terminator removed.

- **WHEN** the app exposes the MCP URL
- **THEN** the HTTP listener binds only to `127.0.0.1` (never `0.0.0.0`, `::`, or any external interface) and rejects any request whose remote address is not loopback

#### Scenario: Server status is reported

- **WHEN** the server transitions between disabled, starting, running, stopped, or failed states
- **THEN** the current state is available to the app's MCP status surface

#### Scenario: Arbitrary commands are unavailable

- **WHEN** an MCP client lists tools or resources
- **THEN** no tool or resource allows arbitrary filesystem reads, writes, process spawning, or shell command execution

### Requirement: Read-only Quran tools

The MCP server SHALL expose read-only tools named `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, and `list_reciters`. Quran text and references MUST come from the same verified app repositories used by the UI.

#### Scenario: List surahs tool returns verified metadata

- **WHEN** a client calls `list_surahs`
- **THEN** the response contains exactly 114 surah entries from `QuranRepository.listSurahs()`

#### Scenario: Get ayah tool returns canonical text

- **WHEN** a client calls `get_ayah` with surah `2` and ayah `255`
- **THEN** the response contains reference `2:255` and canonical Quran text from `QuranRepository.getAyah()`

#### Scenario: Get surah tool returns bounded ayahs

- **WHEN** a client calls `get_surah` with surah `1`
- **THEN** the response contains Al-Fatihah metadata and exactly 7 canonical ayahs from the repository

#### Scenario: Search tool uses existing search contract

- **WHEN** a client calls `search_quran` with a non-empty Arabic query
- **THEN** the response contains bounded `QuranSearchResult` entries from `QuranRepository.searchAyahs()` and no generated summary text

#### Scenario: List reciters returns approved reciter metadata

- **WHEN** a client calls `list_reciters`
- **THEN** the response contains the app's approved reciter metadata and does not invent unavailable reciters

### Requirement: Quran resources

The MCP server SHALL expose resources named `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, and `quran://reciters`. Resource responses MUST be read-only snapshots from the same repositories as the tools.

#### Scenario: Metadata resource includes attribution

- **WHEN** a client reads `quran://metadata`
- **THEN** the response includes source attribution from `QuranRepository.getSource()` and does not include generated religious commentary

#### Scenario: Surahs resource lists all surahs

- **WHEN** a client reads `quran://surahs`
- **THEN** the response contains exactly 114 surah metadata entries ordered by surah number

#### Scenario: Single surah resource validates the path

- **WHEN** a client reads `quran://surah/115`
- **THEN** the server returns a structured not-found or invalid-input error and no partial Quran data

#### Scenario: Single ayah resource validates the path

- **WHEN** a client reads `quran://ayah/1/8`
- **THEN** the server returns a structured not-found or invalid-input error and no invented ayah text

#### Scenario: Reciters resource mirrors list reciters

- **WHEN** a client reads `quran://reciters`
- **THEN** the response contains the same approved reciter metadata exposed by `list_reciters`

### Requirement: Strict MCP input validation and failure mapping

The MCP server SHALL validate every tool argument and resource URI before calling repositories or playback commands. Validation, repository, scope, and player failures MUST be returned as structured MCP errors without throwing raw exceptions across the protocol boundary.

#### Scenario: Empty search query is rejected

- **WHEN** a client calls `search_quran` with an empty or whitespace-only query
- **THEN** the server returns a structured invalid-input error and does not call `QuranRepository.searchAyahs()`

#### Scenario: Out-of-range Quran reference is rejected

- **WHEN** a client calls `get_ayah` with surah `0` or ayah `0`
- **THEN** the server returns a structured invalid-input error and does not invent a reference

#### Scenario: Repository failure is mapped

- **WHEN** a repository call returns `Failure.dataIntegrity`, `Failure.notFound`, or another expected `Failure`
- **THEN** the MCP response maps it to a structured protocol error with no raw stack trace

#### Scenario: Bootstrap failure blocks all Quran reads

- **WHEN** the app bootstrap status indicates Quran or tafsir integrity failure
- **THEN** Quran tools and resources return a structured unavailable or data-integrity error instead of serving partial data

### Requirement: Playback control tools require playback scope

The MCP server SHALL expose playback tools named `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, and `set_repeat`. Each playback tool MUST gate on the `mcp.scope.playback` Settings toggle being ON. When the toggle is OFF, the tool returns a structured `scope_denied` MCP error and player state is unchanged. (Originally drafted as `Playback control tools require permission` with per-command modal approval; corrected to pre-granted scope toggle per `align-mcp-server-with-explore-decisions` D4. The four scenarios listed under `## REMOVED Requirements` in that correction's spec are removed from this requirement.)

#### Scenario: Play surah requires playback scope

- **WHEN** a client calls `play_surah` for surah `36` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error, no playback starts, and the player state is unchanged

#### Scenario: Play ayah requires playback scope

- **WHEN** a client calls `play_ayah` for reference `2:255` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error and no playback starts

#### Scenario: Pause command requires playback scope

- **WHEN** a client calls `pause_playback` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error and the current playback state is unchanged

#### Scenario: Scope-denied command does not change playback

- **WHEN** any Mode B tool returns `scope_denied`
- **THEN** the audio bridge is never invoked and the player state is unchanged

#### Scenario: Authorized-by-scope command uses app player behavior

- **WHEN** a client calls a valid `play_ayah` AND the `mcp.scope.playback` toggle is ON
- **THEN** the app resolves the ayah through existing audio/player contracts and begins playback using the same behavior as the UI

#### Scenario: App unavailable blocks playback control

- **WHEN** a playback command is received while the app/player bridge is unavailable
- **THEN** the server returns a structured app-unavailable or player-unavailable error and does not start a second independent player

### Requirement: Repeat commands stay within supported playback behavior

The MCP server SHALL validate `set_repeat` arguments against repeat modes supported by the app. Unsupported repeat modes MUST fail with structured invalid-input errors.

#### Scenario: Supported repeat mode is authorized by scope

> Originally `Supported repeat mode can be approved`; corrected per D4.

- **WHEN** a client calls `set_repeat` with a supported repeat mode AND the `mcp.scope.playback` toggle is ON
- **THEN** the command applies without further prompting

#### Scenario: Unsupported repeat mode is rejected

- **WHEN** a client calls `set_repeat` with an unsupported mode
- **THEN** the server returns a structured invalid-input error and does not change repeat behavior

### Requirement: Persistent audit log

The MCP server SHALL persist every tool call (Mode A and Mode B) to a SQLite `audit_log` table in a user-writable `user.db` at `path_provider.getApplicationSupportDirectory()/quran/user.db`. The log captures `tool_name`, `args_summary`, `result_status` (one of `ok`, `scope_denied`, `invalid_input`, `not_found`, `unavailable`, `error`), `scope_at_time`, and `ts_utc`. (Originally `Persistent audit logs are deferred`; un-deferred per `align-mcp-server-with-explore-decisions` D5.)

#### Scenario: Successful Mode A call is recorded

- **WHEN** a client calls `search_quran` and the handler returns successfully
- **THEN** an `audit_log` row is appended with `tool_name='search_quran'`, `result_status='ok'`, and the `args_summary` is the truncated query

#### Scenario: Failed Mode A call is recorded

- **WHEN** a client calls `get_ayah` with a malformed reference
- **THEN** an `audit_log` row is appended with `tool_name='get_ayah'` and `result_status='invalid_input'`

#### Scenario: 7-day prune fires on app start

- **WHEN** the app starts and `user.db` opens successfully
- **THEN** the prune deletes every `audit_log` row whose `ts_utc` is older than 7 days

#### Scenario: Clear button wipes the table

- **WHEN** the user taps "Clear MCP audit log" in Settings and confirms the dialog
- **THEN** every row in `audit_log` is deleted

#### Scenario: MCP Status page shows recent entries

- **WHEN** the user opens the MCP Status page
- **THEN** the page renders the most recent 20 audit_log rows ordered by `ts_utc DESC`

### Requirement: Workspace package SHALL be free of Flutter and app-only imports

The `packages/quran_mcp_server/` workspace member SHALL NOT import `package:flutter/`, `package:flutter_riverpod/`, `package:shared_preferences/`, or any path under the main app's `lib/features/` or `lib/app/`. The boundary is enforced by an automated import-scan test inside the package's own `test/` folder.

#### Scenario: Workspace import boundary holds at test time

- **WHEN** the package's `test/isolation_test.dart` runs as part of `flutter test`
- **THEN** the test recursively scans every Dart file under `packages/quran_mcp_server/lib/` and asserts none of them contain an `import` of `package:flutter/`, `package:flutter_riverpod/`, `package:shared_preferences/`, or any string starting with `package:quran_player/features/` or `package:quran_player/app/`
- **AND** if any such import is found the test fails with a message naming the offending file and import line

#### Scenario: Adapter is the only file that imports the protocol package

- **WHEN** the same isolation test scans for `import 'package:mcp_dart`
- **THEN** the only file that contains that import is `packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart`
- **AND** if any other file imports `package:mcp_dart` the test fails

### Requirement: Workspace package SHALL be registered in the root pubspec

The root `pubspec.yaml` SHALL declare `packages/quran_mcp_server` as a workspace member so the Dart toolchain resolves it as part of `flutter pub get`. This is verified by parsing `pubspec.yaml` in a host-app test rather than relying on developer convention.

#### Scenario: Root pubspec lists the workspace member

- **WHEN** `test/workspace_member_test.dart` parses `pubspec.yaml` as YAML
- **THEN** the `workspace:` key is a list that contains the literal string `packages/quran_mcp_server`
- **AND** the test fails with a clear message if the entry is missing

### Requirement: Mode B tools SHALL return a structured `scope_denied` error when the scope is off

Every Mode B (playback) tool handler — `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, `set_repeat` — SHALL check the relevant scope at call time and return a structured `McpError` with code `scope_denied` when the scope is OFF. The handler SHALL NOT throw an exception, SHALL NOT call into the audio bridge, and SHALL NOT mutate any player state.

#### Scenario: Each Mode B tool returns scope_denied when playback scope is off

- **WHEN** the package's scope-check test calls each Mode B tool handler in turn with the playback scope-check returning `false`
- **THEN** every handler returns an `McpError` whose `code` field is the string `scope_denied`
- **AND** none of them throw, none of them invoke the injected audio bridge, and none of them write any side effect outside the audit log

#### Scenario: Audit log records the scope-denied attempt

- **WHEN** a Mode B tool returns `scope_denied`
- **THEN** an audit_log row is appended with `tool_name` set to the called tool, `result_status` set to `scope_denied`, and `scope_at_time` reflecting the scopes that were on at call time

### Requirement: Audit log SHALL prune entries older than 7 days at app start

A prune operation SHALL run once per app start, after the read-only Quran/tafsir integrity gates pass and after `user.db` opens successfully. The prune SHALL execute `DELETE FROM audit_log WHERE ts_utc < (now_utc_millis - 7*86_400_000)` and SHALL log a single `appLogger.info` line with the deletion count. The prune SHALL NOT run while a tool call is in progress.

#### Scenario: Backdated row is pruned on next start

- **WHEN** the test inserts an `audit_log` row with `ts_utc` equal to `now - 8 days`, then triggers the prune entrypoint
- **THEN** the row is deleted
- **AND** rows with `ts_utc` newer than `now - 7 days` remain

#### Scenario: Prune logs deletion count

- **WHEN** the prune deletes one or more rows
- **THEN** `appLogger.info` is called once with a message that includes the deletion count
- **AND** if zero rows were eligible the log line still fires with `count=0`

### Requirement: user.db SHALL degrade gracefully on open failure

If `user.db` cannot be opened (file missing-and-uncreatable, permission denied, corruption), app start SHALL NOT abort. The host app SHALL log `appLogger.severe` with the failure reason, mark a Riverpod `userDbHealthProvider` as failed, and continue start-up. The MCP server SHALL still start (when enabled) but every tool call SHALL log `appLogger.warning('audit_log unavailable')` and proceed without writing an audit row. Quran reads and audio playback SHALL be unaffected.

#### Scenario: Open failure does not block app start

- **WHEN** the host-app test simulates a `user.db` open failure (e.g., the path resolves to a directory or a permission-denied file)
- **THEN** `appLogger.severe` is called once with the failure reason
- **AND** `userDbHealthProvider` resolves to a `Failure(...)` value
- **AND** the app shell still renders (no fatal-error screen)

#### Scenario: Settings shows non-fatal notice

- **WHEN** the user opens Settings while `userDbHealthProvider` is in the failed state
- **THEN** the MCP section shows a non-fatal notice along the lines of "MCP audit log unavailable — restart the app or check disk permissions"
- **AND** all other Settings rows remain interactive

#### Scenario: Quran reads and audio playback continue

- **WHEN** `userDbHealthProvider` is in the failed state
- **THEN** `QuranRepository` reads still return `Success(...)` for valid ayah keys
- **AND** the audio player still resolves and plays an ayah from `AudioRepository`

### Requirement: Audit log SHALL record both Mode A and Mode B tool calls

Every successful or failed tool call SHALL append exactly one row to `audit_log`. This applies to Mode A read-only tools (`search_quran`, `get_ayah`, `get_surah`, `list_surahs`, `list_reciters`) and Mode B playback tools alike. The row SHALL be written after the handler returns (success or failure) and SHALL NOT block the response on the write completing.

#### Scenario: Mode A call appends an audit row

- **WHEN** the test calls `search_quran` with a valid query and the handler returns successfully
- **THEN** exactly one row is appended to `audit_log` with `tool_name='search_quran'`, `result_status='ok'`, and `scope_at_time` containing `readonly`

#### Scenario: Mode B call appends an audit row

- **WHEN** the test calls `pause_playback` with the playback scope ON and the audio bridge available
- **THEN** exactly one row is appended to `audit_log` with `tool_name='pause_playback'`, `result_status='ok'`, and `scope_at_time` containing both `readonly` and `playback`

#### Scenario: Failed call still appends a row

- **WHEN** the test calls `get_ayah` with a malformed reference (e.g., surah=200)
- **THEN** the handler returns an `McpError` with code `invalid_input`
- **AND** exactly one row is appended to `audit_log` with `tool_name='get_ayah'` and `result_status='invalid_input'`

### Requirement: search_quran args_summary SHALL truncate at 128 characters

For the `search_quran` tool, the `args_summary` value persisted to `audit_log` SHALL be the first 128 characters of the user's query, followed by a marker `…[+N more]` when truncation occurred, where `N` is the number of additional codepoints not stored. Queries of 128 codepoints or fewer SHALL be stored verbatim with no marker.

#### Scenario: Long query is truncated with a marker

- **WHEN** the test calls `search_quran` with a 200-codepoint query
- **THEN** the persisted `args_summary` is exactly the first 128 codepoints of the query, immediately followed by `…[+72 more]`
- **AND** no other transformation (case-folding, normalization) is applied

#### Scenario: Short query is stored verbatim

- **WHEN** the test calls `search_quran` with a 50-codepoint query
- **THEN** the persisted `args_summary` equals the original query exactly
- **AND** no `…[+N more]` marker is appended

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

