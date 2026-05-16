## 1. Protocol and Lifecycle

- [x] 1.1 Choose an isolated MCP protocol adapter. *Originally `mcp_server`; corrected to `mcp_dart ^2.1.1` per align-mcp-server D2.*
- [x] 1.2 Add MCP server module structure for protocol routing, DTOs, validation, errors, lifecycle state, and tests. *Lives in `packages/quran_mcp_server/` per align-mcp-server D3.*
- [x] 1.3 Implement local-only server startup/shutdown with states `disabled`, `starting`, `running`, `stopped`, and `failed`.
- [x] 1.4 Add import/security boundary tests proving MCP code exposes no arbitrary file, shell, or remote network listener capability. *Implemented as `packages/quran_mcp_server/test/isolation_test.dart` (R1).*

## 2. Read-only Tools and Resources

- [x] 2.1 Implement explicit MCP DTOs for Quran source metadata, surahs, ayahs, search results, and reciters. *Lives at `lib/data/mcp/mcp_dtos.dart` (host-side because it imports host domain types).*
- [x] 2.2 Implement `list_surahs`, `get_ayah`, `get_surah`, `search_quran`, and `list_reciters` by reusing existing repository contracts via the `McpQuranDataPort` adapter.
- [x] 2.3 Implement resources `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, and `quran://reciters`.
- [x] 2.4 Add schema validation and structured error mapping for malformed inputs, out-of-range references, repository failures, and bootstrap failures.
- [x] 2.5 Add fixture-style tests for tool listing, scope handling, and audit-log writes (covered by the workspace package's `test/scopes/scope_check_test.dart`).

## 3. Playback Scope and Bridge

> **Reworked from "Playback Permission and Bridge" — per align-mcp-server D4 the per-command approval flow is replaced with pre-granted scope toggles.**

- [x] 3.1 Define a Mode B tool set (`play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, `set_repeat`) and gate them centrally on `Scope.playback` in the dispatcher.
- [x] 3.2 Add three SharedPreferences-backed Settings toggles: `mcp.enabled` (master, default OFF), `mcp.scope.playback` (default OFF), `mcp.scope.bookmark` (default OFF, reserved).
- [x] 3.3 Implement the `HostAudioAdapter` so Mode B tools reuse the existing audio repository and player controller behavior when their scope is granted.
- [x] 3.4 Validate playback command inputs before invoking the bridge, including Quran references and supported repeat modes.
- [x] 3.5 Return structured `scope_denied`, `app_unavailable`, `player_unavailable`, `invalid_input`, and `unavailable` errors as appropriate.
- [x] 3.6 Add tests proving scope-denied commands do not change player state and authorized commands invoke the existing player path (`packages/quran_mcp_server/test/scopes/scope_check_test.dart`).

## 4. MCP Status UI

- [x] 4.1 Replace the MCP Status placeholder with a ForUI-based status page showing lifecycle state, local-only mode, exposed tools/resources, and active scopes.
- [x] 4.2 *Removed.* The original task added Approve/Deny controls for pending commands; the realignment removes the per-command UI entirely.
- [x] 4.3 Show the most recent 20 audit_log rows from `user.db` ordered DESC.
- [x] 4.4 Add widget tests for lifecycle states, local-only copy, scope display, and audit-row rendering.

## 5. Persistent Audit Log

> **New section — un-deferred per align-mcp-server D5.**

- [x] 5.1 Add the `user.db` schema v1 (`schema_meta`, `audit_log` table, `idx_audit_log_ts`) inside the workspace package.
- [x] 5.2 Add the `AuditLogRepository` (append, prune7Days, clear, recent) with full unit tests (R4, R6).
- [x] 5.3 Add the `args_summary` truncate-and-mark helper for `search_quran` queries (R7).
- [x] 5.4 Wire the prune-on-app-start hook in the host app via the `userDbStateProvider`.
- [x] 5.5 Add a "Clear MCP audit log" button in Settings with a Confirm/Cancel dialog.
- [x] 5.6 Add the `user.db` graceful-degrade test (R5): open failure does not block app start, Settings shows non-fatal notice, Quran reads + audio playback continue.

## 6. Tooling and Documentation

- [x] 6.1 Add a Justfile recipe for smoke-testing the MCP server (`just mcp-smoke`).
- [x] 6.2 Update README.md and AGENTS.md with the shipped MCP behavior, local-only safety model, and verification commands. *Pending in [realign-mcp-server-implementation Section 9](../realign-mcp-server-implementation/tasks.md).*
- [x] 6.3 Document MCP client configuration needed to launch the server locally. *Pending in [realign-mcp-server-implementation Section 9](../realign-mcp-server-implementation/tasks.md).*

## 7. Verification

- [x] 7.1 Run focused MCP data, scope, audit, and MCP Status widget tests.
- [x] 7.2 Run `just check`.
- [ ] 7.3 Manually exercise the app MCP Status flow on Windows: start the server, copy URL+token, run `curl` with and without the bearer token, toggle the playback scope OFF and confirm `scope_denied`, restart the app and confirm audit_log persistence, insert a backdated row and confirm the prune deletes it. *Pending in [realign-mcp-server-implementation Section 10](../realign-mcp-server-implementation/tasks.md).*
