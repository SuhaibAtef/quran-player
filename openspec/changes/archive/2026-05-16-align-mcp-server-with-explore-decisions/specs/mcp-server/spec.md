## MODIFIED Requirements

This correction MODIFIES specific scenarios introduced by the in-flight [`add-mcp-server`](../../../add-mcp-server/specs/mcp-server/spec.md) change. Each modification or removal below names the originating scenario explicitly.

### Requirement: MCP server binds plain HTTP on the loopback interface

The MCP server SHALL bind a plain HTTP listener (NOT HTTPS) to `127.0.0.1` on a user-configured port. The bearer token in the `Authorization: Bearer <token>` request header is the auth boundary; TLS is NOT used. Loopback binding + token are the threat model — sufficient because the server never accepts non-loopback connections.

#### Scenario: Server exposes plain HTTP local client details

> MODIFIES `add-mcp-server` scenario `Server exposes authenticated HTTPS local client details`. HTTPS → HTTP.

- **WHEN** the MCP server is running
- **THEN** the app exposes an `http://127.0.0.1:<port>/mcp` MCP URL and a per-server-start bearer token that local LLM/MCP clients can use

#### Scenario: HTTP endpoint remains local

> MODIFIES `add-mcp-server` scenario `HTTPS endpoint remains local`. HTTPS terminator removed.

- **WHEN** the app exposes the MCP URL
- **THEN** the HTTP listener binds only to `127.0.0.1` (never `0.0.0.0`, `::`, or any external interface) and rejects any request not arriving on the loopback interface

#### Scenario: Missing token is rejected (HTTP)

> MODIFIES `add-mcp-server` scenario `Missing token is rejected`. Endpoint wording from HTTPS → HTTP; semantics unchanged.

- **WHEN** a local client calls the HTTP MCP endpoint without the displayed bearer token in the `Authorization` header
- **THEN** the server returns a `401 Unauthorized` response and does not execute a tool or resource handler

#### Scenario: Token freshness

- **WHEN** the MCP server is started for the first time after the user enables it, OR is restarted after being stopped
- **THEN** a new high-entropy bearer token is generated and the previous token (if any) ceases to authorize requests

#### Scenario: Port is user-configurable

- **WHEN** the user sets the MCP port from Settings before starting the server
- **THEN** the server binds the chosen port on next start; if the port is occupied, the server start fails with a structured error surfaced in Settings, the toggle reverts to off, and no fallback port is silently chosen

### Requirement: MCP server uses the `mcp_dart` package

The protocol implementation SHALL depend on the `mcp_dart` package at version `^2.1.1` (or the latest compatible version in that lineage at implementation time). The package is consumed behind a thin adapter so future package swaps remain bounded.

#### Scenario: Package is `mcp_dart`

- **WHEN** the project's `pubspec.yaml` or workspace package `pubspec.yaml` is inspected
- **THEN** the MCP dependency is `mcp_dart: ^2.1.1` and no other MCP protocol package (`mcp_server`, etc.) is present

### Requirement: MCP server lives in a Dart workspace package

The MCP server code SHALL live in a Dart workspace member at `packages/quran_mcp_server/`. The Flutter app SHALL declare it as a `workspace:` member in the root `pubspec.yaml` and depend on it as a path dependency. The package SHALL NOT import `package:flutter/`, Flutter Riverpod, or any app-only feature module.

#### Scenario: Workspace package boundary holds

- **WHEN** any Dart file under `packages/quran_mcp_server/lib/` is compiled
- **THEN** no import resolves to `package:flutter/`, `package:flutter_riverpod/`, or any path under the main app's `lib/features/`

#### Scenario: App composition wires repositories in

- **WHEN** the Flutter app composition layer starts the MCP server
- **THEN** it constructs the package's public entry point with the existing `QuranRepository` and `AudioRepository` instances injected — the package does NOT instantiate its own data layer or audio engine

### Requirement: Mode B tools gate on pre-granted scope toggles, NOT per-command approval

The MCP server SHALL gate Mode B (playback) tools on persistent Settings toggles, NOT on per-command modal approval. Three scopes are defined:

- `mcp.scope.readonly` (master MCP toggle implies on; can never be disabled while MCP is enabled)
- `mcp.scope.playback` (default OFF, gates all six playback tools)
- `mcp.scope.bookmark` (default OFF, reserved for future bookmark tools)

Each Mode B tool checks the relevant scope at call time. If the scope is off, the tool returns a structured `scope_denied` MCP error and does NOT change player state. There is NO pending-approval flow, NO modal UI in MCP Status, and NO per-command timeout.

#### Scenario: Play surah requires playback scope

> REMOVES `add-mcp-server` scenario `Play surah waits for user approval`. Replaced with scope-toggle check.

- **WHEN** a client calls `play_surah` for surah `36` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error, no playback starts, and the player state is unchanged

#### Scenario: Play ayah requires playback scope

> REMOVES `add-mcp-server` scenario `Play ayah waits for user approval`. Replaced with scope-toggle check.

- **WHEN** a client calls `play_ayah` for reference `2:255` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error and no playback starts

#### Scenario: Pause command requires playback scope

> REMOVES `add-mcp-server` scenario `Pause command waits for user approval`. Replaced with scope-toggle check.

- **WHEN** a client calls `pause_playback` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error and current playback state is unchanged

#### Scenario: Scope-authorized playback uses app player behavior

> MODIFIES `add-mcp-server` scenario `Approved command uses app player behavior`. "Approved" → "authorized by scope"; semantics otherwise unchanged.

- **WHEN** a client calls a Mode B tool AND the `mcp.scope.playback` toggle is ON AND the input validates AND the app player bridge is available
- **THEN** the app resolves the request through the existing audio/player contracts and applies the playback change using the same behaviour as the UI

#### Scenario: Scope-denied set_repeat does not apply

> MODIFIES `add-mcp-server` scenario `Supported repeat mode can be approved`. "Approved" → "authorized by scope".

- **WHEN** a client calls `set_repeat` with a supported repeat mode AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error and the repeat mode is unchanged

#### Scenario: Mode A reads do not require the playback scope

- **WHEN** a client calls `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, or `list_reciters` AND the MCP master enable is ON
- **THEN** the call proceeds independent of the playback or bookmark scope toggles (Mode A is gated only by the master enable)

#### Scenario: Bookmark scope is reserved but unused

- **WHEN** this change ships
- **THEN** the `mcp.scope.bookmark` Settings toggle exists and persists, but no tool or resource gates on it (the toggle is shape-reserved for a future bookmark feature)

### Requirement: MCP server persists every tool call to an audit log

The MCP server SHALL persist every tool invocation (Mode A reads AND Mode B writes, regardless of outcome) to a SQLite-backed audit log table. The table SHALL be stored in a user-writable SQLite file at `path_provider.getApplicationSupportDirectory()/quran/user.db`, distinct from the read-only bundled `quran.sqlite` and `muyassar.sqlite` assets. Entries SHALL be pruned at app start if older than 7 days; the user MAY clear the log on demand from Settings.

#### Scenario: Successful tool call writes an audit entry

- **WHEN** a client calls `get_ayah(2, 255)` AND the call returns `ok`
- **THEN** an `audit_log` row is inserted with `tool_name='get_ayah'`, `result_status='ok'`, `ts_utc=<current epoch millis>`, `args_summary='2:255'` (or equivalent), and `scope_at_time` reflecting the active scopes at call time

#### Scenario: Failed tool call writes an audit entry with the failure status

- **WHEN** a client calls `play_ayah(2:255)` AND the `mcp.scope.playback` toggle is OFF
- **THEN** an `audit_log` row is inserted with `tool_name='play_ayah'`, `result_status='scope_denied'`, and the `scope_at_time` showing that playback was off

#### Scenario: App-start prune removes entries older than 7 days

- **WHEN** the app starts AND the `audit_log` table contains rows whose `ts_utc` is more than 7 days before the current time
- **THEN** those rows are deleted in one statement, and only rows within the 7-day window remain

#### Scenario: Clear button wipes the audit log

- **WHEN** the user taps "Clear MCP audit log" in Settings
- **THEN** all rows in the `audit_log` table are deleted in one statement and the MCP Status page's recent-entries surface shows an empty state

#### Scenario: MCP Status shows the most recent N entries

- **WHEN** the user opens the MCP Status page
- **THEN** the page displays the most recent 20 (or implementer-chosen N) audit-log entries ordered by `ts_utc` descending, each showing tool name, formatted timestamp, result status, and a short args summary

#### Scenario: search_quran args_summary is truncated to bounded length

- **WHEN** a client calls `search_quran` with a query longer than 128 characters
- **THEN** the audit entry's `args_summary` records the first 128 characters of the query and an explicit truncation marker

#### Scenario: User DB failure does not block app start

- **WHEN** the user-writable `user.db` is missing, unreadable, or corrupt at app start
- **THEN** the audit-log subsystem logs `appLogger.severe`, the Settings UI shows "MCP audit log unavailable: <reason>", AND the rest of the app (Quran reads, audio playback, MCP read-only tools) continues to function

## REMOVED Requirements

The following requirements from the in-flight `add-mcp-server` delta are NOT removed at the requirement level (their parent requirement, "Playback control tools require permission", still exists). Only the per-command-approval *scenarios* are removed; the parent requirement is reframed by D4 above as a scope-toggle check rather than a modal approval flow.

In particular, the in-flight `add-mcp-server` scenarios `Play surah waits for user approval`, `Play ayah waits for user approval`, `Pause command waits for user approval`, and `Denied command does not change playback` are REMOVED by this correction and replaced with their scope-gated equivalents above. The implementer of the re-application edits the in-flight spec file to delete those four scenarios and adopt this correction's wording.

## Preserved Requirements

For clarity, the following requirements from the in-flight `add-mcp-server` delta are preserved UNCHANGED by this correction:

- `Local-only MCP server lifecycle` (`disabled`, `starting`, `running`, `stopped`, `failed` states)
- `Read-only Quran tools` (`search_quran`, `get_ayah`, `get_surah`, `list_surahs`, `list_reciters` returning verified repository data)
- `Quran resources` (`quran://metadata`, `quran://surahs`, `quran://surah/{n}`, `quran://ayah/{s}/{a}`, `quran://reciters`)
- `Strict MCP input validation and failure mapping` (structured errors, bootstrap gate, no partial data)
- `Repeat commands stay within supported playback behavior` (the *invalid-input rejection* part of this requirement is preserved; only the "can be approved" wording for the supported-mode scenario is modified by D4)
- "Arbitrary commands are unavailable" (no shell, no arbitrary file access, no remote network listener)

The corrected delta spec is the union of (these preserved requirements, as written in `add-mcp-server`) and (the corrected requirements above, which supersede the named scenarios).
