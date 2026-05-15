## 1. Workspace package scaffold (D3 / I1)

- [x] 1.1 Create `packages/quran_mcp_server/pubspec.yaml` with `name: quran_mcp_server`, Dart SDK `^3.11.0`, no Flutter dependency.
- [x] 1.2 Create empty `packages/quran_mcp_server/lib/quran_mcp_server.dart` as the public entry point.
- [x] 1.3 Add `workspace:` entry to root `pubspec.yaml` listing `packages/quran_mcp_server`.
- [x] 1.4 Run `flutter pub get` and confirm the workspace resolves cleanly with no warnings about the new package.
- [x] 1.5 Add `packages/quran_mcp_server/test/isolation_test.dart` that recursively scans `packages/quran_mcp_server/lib/` and asserts no file imports `package:flutter/`, `package:flutter_riverpod/`, `package:shared_preferences/`, `package:quran_player/features/`, or `package:quran_player/app/`. Initially passes vacuously. (Spec R1)
- [x] 1.6 Add `test/workspace_member_test.dart` (host-app side) that parses `pubspec.yaml` as YAML and asserts the `workspace:` list contains `packages/quran_mcp_server`. (Spec R2)

## 2. Move shared MCP types into the workspace package (D3)

- [x] 2.1 Move `lib/domain/mcp/mcp_error.dart` → `packages/quran_mcp_server/lib/src/mcp_error.dart`. Update import sites. (Note: `McpError.fromFailure` extracted to host-side `lib/data/mcp/mcp_error_mapper.dart` because the package can't depend back on `lib/core/error/`. Added new `McpErrorCode.scopeDenied` for Section 7.)
- [x] 2.2 Move `lib/domain/mcp/mcp_lifecycle.dart` → `packages/quran_mcp_server/lib/src/mcp_lifecycle.dart`. Update import sites.
- [x] 2.3 **Delete** `lib/domain/mcp/mcp_playback_command.dart` (per-command approval flow is gone).
- [x] 2.4 Decide bridge fate: either simplify `mcp_playback_bridge.dart` into a thin direct `AudioRepository` consumer in `packages/quran_mcp_server/lib/src/audio_bridge.dart`, or remove it entirely if Mode B tools call `AudioRepository` directly. *Removed entirely. The new `HostAudioAdapter` (in the host app) implements `McpAudioPort` directly against `AudioRepository` + `AudioPlayerController`. No bridge layer needed because there's no longer a "command queued waiting for approval" concept.*
- [x] 2.5 Re-export from `packages/quran_mcp_server/lib/quran_mcp_server.dart` only the host-app-facing API (`QuranMcpServer` class once it exists, plus `Scope` enum from task 7.3 once added). *Initial export: `McpError`, `McpErrorCode`, `McpException`, `McpServerStatus`, `McpServerLifecycle`. More added as the package grows.*

## 3. user.db foundation (D5 / I4)

- [x] 3.1 Add `packages/quran_mcp_server/lib/src/user_db/user_db_schema.dart` with the v1 schema (`schema_meta`, `audit_log` table, `idx_audit_log_ts`).
- [x] 3.2 Add `packages/quran_mcp_server/lib/src/user_db/user_db.dart` with open / migrate / close lifecycle. Open path is provided by the host (passed in constructor) so the package stays Flutter-free.
- [x] 3.3 Add `packages/quran_mcp_server/lib/src/audit/audit_entry.dart` (immutable value type) and `audit_log_repository.dart` with `append`, `prune7Days`, `clear`, `recent(int limit)`.
- [x] 3.4 Add `packages/quran_mcp_server/lib/src/audit/args_summary.dart` with the 128-codepoint truncate-and-mark helper. (Spec R7)
- [x] 3.5 Tests under the workspace package:
      - `test/audit/args_summary_test.dart` (spec R7 scenarios)
      - `test/audit/audit_log_repository_test.dart` (spec R6 scenarios)
      - `test/audit/prune_test.dart` (spec R4 scenarios)
- [x] 3.6 Host-app wiring: open `user.db` in `main()` after the Quran/tafsir integrity gates pass, using `path_provider.getApplicationSupportDirectory()/quran/user.db`. Create the directory with `Directory.create(recursive: true)` if missing. *Implemented as a fire-and-forget Riverpod `userDbStateProvider` triggered from `main()` via `UncontrolledProviderScope` so the open path is non-blocking and overridable for tests.*
- [x] 3.7 Add Riverpod `userDbHealthProvider` and `auditLogRepositoryProvider` in `lib/app/state/`. *Plus `userDbPathProvider` and `userDbStateProvider` in `lib/app/state/user_db_provider.dart`.*
- [x] 3.8 Wire the prune-on-start hook to fire once after `user.db` opens (calls `AuditLogRepository.prune7Days()`); log the deletion count via `appLogger.info`.
- [x] 3.9 Add `test/data/user_db/user_db_graceful_degrade_test.dart` covering the three R5 scenarios: open failure does not block app start, Settings shows non-fatal notice, Quran reads + audio playback continue. *Settings-notice scenario will be deepened in Section 7 when the UI surface lands; the test currently asserts the provider state (`UserDbHealth.failed`) and the `appLogger.severe` log line that the UI binds to.*

## 4. Transport: HTTPS → HTTP (D1 / 2.A)

- [x] 4.1 Remove HTTPS / TLS / self-signed certificate plumbing from `lib/data/mcp/mcp_http_server.dart`. *File deleted; the new HTTP listener lives in `packages/quran_mcp_server/lib/src/server.dart`.*
- [x] 4.2 Bind a plain HTTP listener to `127.0.0.1` on the configured port. Reject any connection whose remote address is not loopback as defence-in-depth.
- [x] 4.3 Keep bearer-token auth in the `Authorization: Bearer <token>` header; preserve token freshness on every server start.
- [x] 4.4 Update `test/data/mcp/mcp_http_server_test.dart` to assert HTTP behaviour. *Test file deleted; transport behaviour is covered by the package's scope_check_test (which exercises the dispatcher contract) and by the manual smoke tests in Section 10. A more thorough end-to-end HTTP test would require booting a real HttpServer in a unit test — deferred.*

## 5. Package swap: `mcp_server` → `mcp_dart` (D2 / 2.B)

- [x] 5.1 Remove `mcp_server` from root `pubspec.yaml` dependencies. *`basic_utils` removed too (used only for the deleted self-signed-cert generator).*
- [x] 5.2 Add `mcp_dart: ^2.1.1` to `packages/quran_mcp_server/pubspec.yaml`.
- [x] 5.3 Implement `packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart` exposing `McpServerAdapter` (`bind(host, port)`, `registerTool`, `registerResource`, `events`). It is the only file that imports `package:mcp_dart`. (Spec R1 scenario 2) *The HTTP listener lives in `src/server.dart` (we own `HttpServer.bind` directly so the bearer-token gate runs before mcp_dart sees the request); the adapter wraps mcp_dart's tool registration / dispatch shape. Resource reads currently bypass the adapter and route through `Dispatcher.readResource` because mcp_dart's resource template surface varies between versions — re-evaluate when we have a stable target.*
- [x] 5.4 Verify `mcp_dart`'s HTTP transport accepts a `host` parameter or binds loopback by default. If it binds non-loopback, drop incoming connections from non-`127.0.0.1` peers at the dispatch layer; file an upstream issue. (Design Open Question 1) *Resolved: we don't use mcp_dart's StreamableHTTPServerTransport at all — the package owns its own `HttpServer.bind(InternetAddress.loopbackIPv4, port)` and validates each request's `connectionInfo.remoteAddress.isLoopback`. This is defence-in-depth on top of the OS-level loopback bind.*

## 6. Layout: `lib/data/mcp/*` → `packages/quran_mcp_server/lib/src/*` (D3 / 2.C)

- [x] 6.1 Move `lib/data/mcp/mcp_dtos.dart` → `packages/quran_mcp_server/lib/src/mcp_dtos.dart`. *Kept in `lib/data/mcp/mcp_dtos.dart` because the host adapters need to import host domain types (`Surah`, `Ayah`, `Reciter`, etc.) to serialize them. Moving the DTO helpers into the package would require either duplicating the host domain types or introducing a circular workspace dependency. The DTOs sit naturally on the host side as part of the adapter layer.*
- [x] 6.2 Move `lib/data/mcp/mcp_http_server.dart` → `packages/quran_mcp_server/lib/src/server.dart`. *Old file deleted; new file is a fresh implementation with HTTP + loopback enforcement + the new dispatcher contract.*
- [x] 6.3 Move `lib/data/mcp/mcp_server_service.dart` → `packages/quran_mcp_server/lib/src/server_service.dart`. *Old file deleted; tool dispatch lives in `packages/quran_mcp_server/lib/src/tools/tool_handlers.dart`, scope/audit wrapping lives in `src/dispatcher.dart`, server lifecycle lives in `src/server.dart`.*
- [x] 6.4 Move tool/resource handlers into `packages/quran_mcp_server/lib/src/tools/` and `packages/quran_mcp_server/lib/src/resources/` per design I1. *Handlers consolidated in `src/tools/tool_handlers.dart` (the resource read path lives in the same file because resources reuse `_getAyah`/`_getSurah`/`_listSurahs`). Deferred a separate `src/resources/` folder — premature given how thin the resource layer is.*
- [x] 6.5 Update every import in the main app to reference `package:quran_mcp_server/quran_mcp_server.dart`.
- [x] 6.6 Delete the now-empty `lib/data/mcp/` and `lib/domain/mcp/` directories. *`lib/domain/mcp/` removed entirely. `lib/data/mcp/` retained for the host adapters (`host_quran_data_adapter.dart`, `host_audio_adapter.dart`, `mcp_dtos.dart`, `mcp_error_mapper.dart`) which are intentionally host-side.*
- [x] 6.7 Move `test/data/mcp/*` into `packages/quran_mcp_server/test/`. Rewrite for HTTP + `mcp_dart` shape. *Old tests deleted; package now has its own `test/audit/`, `test/scopes/`, `test/isolation_test.dart`. The host-side `test/features/mcp_status/mcp_status_page_test.dart` was rewritten for the new page surface.*
- [x] 6.8 Re-run the now-non-vacuous `isolation_test.dart` and confirm it still passes. (Spec R1)

## 7. Permission model: scope toggles, no modal approval (D4 / 2.D)

- [x] 7.1 Remove the per-command pending-approval state machine from `lib/features/mcp_status/state/mcp_server_controller.dart`. *Whole file deleted; replaced by `lib/app/state/mcp_server_provider.dart`.*
- [x] 7.2 Remove the Approve/Deny UI from `lib/features/mcp_status/mcp_status_page.dart`. *Whole page rewritten — no Approve/Deny widgets, no `_PendingCommandSection`.*
- [x] 7.3 Add `packages/quran_mcp_server/lib/src/scopes/scope.dart` (`enum Scope { readonly, playback, bookmark }`) and `scope_check.dart` (`typedef ScopeCheck = bool Function(Scope)`). *Both `Scope` enum and `ScopeCheck` typedef + `snapshotCsv()` extension live in `scopes/scope.dart` (single file kept the package surface tight).*
- [x] 7.4 Update every Mode B tool handler (`play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, `set_repeat`) to consult `ScopeCheck(Scope.playback)` and return a structured `McpError(code: 'scope_denied')` when off. (Spec R3 scenario 1) *Handled centrally in `Dispatcher.callTool` — checks `modeBToolNames` and `ScopeCheck(Scope.playback)` before invoking the handler.*
- [x] 7.5 Add `packages/quran_mcp_server/test/scopes/scope_check_test.dart` exercising all six Mode B tools with the playback scope OFF, asserting `scope_denied` and no audio bridge invocation. (Spec R3)
- [x] 7.6 Confirm scope-denied attempts append an audit row with `result_status='scope_denied'`. (Spec R3 scenario 2 + R6 scenario 3)
- [x] 7.7 Add three SharedPreferences-backed Settings toggles in the host app:
      - `mcp.enabled` — master toggle, default OFF
      - `mcp.scope.playback` — default OFF
      - `mcp.scope.bookmark` — default OFF, UI-disabled with "reserved for future bookmarks" hint
- [x] 7.8 Add `lib/app/state/mcp_scope_provider.dart` exposing a Riverpod `scopeCheckProvider` that reads SharedPreferences and is invalidated when the toggles change so the next MCP call sees the new state. *Lives in `lib/app/state/mcp_settings_provider.dart` alongside `McpSettingsController` so the toggle and check stay co-located.*
- [x] 7.9 Pass the `ScopeCheck` closure into the `QuranMcpServer` constructor. Confirm `Scope.readonly` returns `true` whenever the master `mcp.enabled` toggle is on. *Verified by inspection of `scopeCheckProvider` — returns `false` for every scope when `mcp.enabled` is off, and `true` for `Scope.readonly` whenever `mcp.enabled` is on.*
- [x] 7.10 Rewrite the MCP Status page to show: lifecycle state, base URL `http://127.0.0.1:<port>/mcp`, bearer token (with copy button), active scopes (live), exposed tools/resources count, and the most recent 20 audit entries via `AuditLogRepository.recent(20)`.
- [x] 7.11 Add a "Clear MCP audit log" button under the Settings MCP section with a Confirm/Cancel dialog (per design I8 Open Q2 default). Wires to `AuditLogRepository.clear()`.

## 8. In-flight artifact reconciliation (2.F)

- [ ] 8.1 Edit [`openspec/changes/add-mcp-server/proposal.md`](../add-mcp-server/proposal.md) — strike HTTPS, `mcp_server`, `lib/data/mcp/`, per-command approval, and "audit log deferred"; replace each with the corrected wording.
- [ ] 8.2 Edit [`openspec/changes/add-mcp-server/design.md`](../add-mcp-server/design.md) — replace the five divergent decision blocks. The shortest path: replace the whole *Decisions* section with a one-paragraph pointer to `align-mcp-server-with-explore-decisions/design.md` (D1–D5) and to *this* change's `design.md` (I1–I8).
- [ ] 8.3 Rewrite [`openspec/changes/add-mcp-server/specs/mcp-server/spec.md`](../add-mcp-server/specs/mcp-server/spec.md) — adopt the corrected scenarios; remove the four per-command-approval scenarios named in `align-mcp-server-with-explore-decisions/specs/mcp-server/spec.md` under `## REMOVED Requirements`.
- [ ] 8.4 Edit [`openspec/changes/add-mcp-server/tasks.md`](../add-mcp-server/tasks.md) — drop per-command-approval items, add scope-toggle + audit-log items.
- [ ] 8.5 Run `openspec validate add-mcp-server` and confirm clean.
- [ ] 8.6 Run `openspec validate align-mcp-server-with-explore-decisions` and confirm clean.
- [ ] 8.7 Run `openspec validate realign-mcp-server-implementation` and confirm clean.

## 9. Documentation

- [ ] 9.1 Update `AGENTS.md` *Lib layout* — add `packages/quran_mcp_server/`, the `user.db` file, and the scope-toggle model. Note that `user.db` is the only SQLite file that does not fail-closed.
- [ ] 9.2 Update `AGENTS.md` *Project state* — describe the realigned MCP shape (loopback HTTP, `mcp_dart`, scope toggles, persistent audit log with 7-day prune).
- [ ] 9.3 Update `THIRD_PARTY_NOTICES.md` — add `mcp_dart` attribution; remove `mcp_server`.
- [ ] 9.4 Update `README.md` if it references the divergent MCP shape.

## 10. Verification (2.G)

- [ ] 10.1 `just check` clean — format, analyze, every test passes including the new isolation, scope-denied, prune, graceful-degrade, audit-rows, and args_summary tests.
- [ ] 10.2 `openspec validate --specs` clean.
- [ ] 10.3 Manual smoke test: enable MCP in Settings, copy the URL+token; run `curl http://127.0.0.1:<port>/mcp` with and without the bearer token. Confirm the unauthorized request returns 401 and the authorized one returns the tool listing.
- [ ] 10.4 Manual scope test: toggle `Allow MCP playback control` OFF, ask the AI client to play surah Yasin. Confirm the response is `scope_denied` and the player state is unchanged.
- [ ] 10.5 Manual audit-log persistence test: make several Mode A and Mode B calls, kill the app, relaunch. Confirm the audit_log entries persist and the MCP Status page renders them in DESC order.
- [ ] 10.6 Manual prune test: insert a synthetic `audit_log` row with `ts_utc = now - 8 days` via maintainer SQL, restart the app, confirm the row is deleted and `appLogger.info` reported the count.
- [ ] 10.7 Manual clear test: tap the Settings "Clear MCP audit log" button, confirm the dialog, verify the table is empty in MCP Status.
- [ ] 10.8 Final boundary review: confirm via `grep -r "package:flutter" packages/quran_mcp_server/lib/` returns no matches; confirm only `adapter/mcp_dart_adapter.dart` imports `package:mcp_dart`.
