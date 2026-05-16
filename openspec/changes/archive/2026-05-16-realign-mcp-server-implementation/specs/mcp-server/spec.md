## ADDED Requirements

This change ADDS code-level enforcement requirements to the `mcp-server` capability. The behavioural scenarios from [`align-mcp-server-with-explore-decisions`](../../../align-mcp-server-with-explore-decisions/specs/mcp-server/spec.md) are unchanged; this delta layers test-verifiable enforcement on top.

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
