## Why

The MCP server code that landed in PR #20 (`feature/add-mcp-server`) diverges from the architecture ratified during `/openspec-explore` on five specific decisions. PR #21 (`align-mcp-server-with-explore-decisions`) corrected the **spec** but explicitly deferred the implementation work — its `tasks.md` Section 2 is labelled "reference, NOT this PR". This change is the implementation follow-up: it lands Section 2 as actionable, checkbox-driven tasks against the code on develop, and adds a small set of code-level enforcement requirements that make the corrected behavioural scenarios verifiable in tests rather than only in prose.

## What Changes

- **Transport (D1):** **BREAKING** — replace HTTPS + self-signed certificate plumbing with plain HTTP on `127.0.0.1`. The bearer token in `Authorization: Bearer <token>` remains the auth boundary.
- **Package (D2):** **BREAKING** — swap the in-flight `mcp_server` dependency for `mcp_dart: ^2.1.1` behind a thin adapter; the adapter is the only place that imports the protocol package.
- **Layout (D3):** **BREAKING** — move all MCP code from `lib/data/mcp/*` and `lib/domain/mcp/*` into a new Dart workspace package at `packages/quran_mcp_server/`. The root `pubspec.yaml` declares it as a `workspace:` member; the main app depends on it via path dependency. Tools and resources still consume `QuranRepository` / `AudioRepository` via constructor injection — no parallel data path.
- **Permission model (D4):** **BREAKING** — delete the per-command modal-approval state machine and Approve/Deny UI. Add three pre-granted Settings toggles (`mcp.enabled`, `mcp.scope.playback` default OFF, `mcp.scope.bookmark` default OFF reserved). Mode B tools check the relevant scope at call time and return a structured `scope_denied` MCP error when the toggle is off.
- **Audit log (D5):** replace the ephemeral in-memory recent-decisions buffer with a persistent SQLite table. New user-writable database at `path_provider.getApplicationSupportDirectory()/quran/user.db`, schema v1 with one table `audit_log(id, ts_utc, tool_name, args_summary, result_status, scope_at_time)`. Prune-on-app-start deletes rows older than 7 days. Settings exposes a "Clear MCP audit log" button. Both Mode A reads and Mode B writes append rows. `search_quran` queries are truncated at 128 chars in `args_summary` with a `…[+N more]` marker.
- **Code-level enforcement (NEW):** add seven new requirements to `mcp-server` that lock the corrected behaviour into tests — workspace isolation test, workspace member registration check, scope-denied error mapping per Mode B tool, prune behaviour test, `user.db` graceful-degrade test (the user DB is the *only* SQLite file in the project that does NOT fail-closed on open failure), audit writes for both modes, and `args_summary` truncation.
- **In-flight artifact reconciliation:** edit `openspec/changes/add-mcp-server/{proposal,design,specs/mcp-server/spec,tasks}.md` so they describe what actually ships after this change, not the divergent shape. `openspec validate add-mcp-server` must pass after the edits. The two MCP openspec changes (`add-mcp-server`, `align-mcp-server-with-explore-decisions`) are then archive-ready in a follow-up `chore/` PR.

## Capabilities

### New Capabilities
*(none)*

### Modified Capabilities
- `mcp-server`: ADDED requirements that enforce the corrected architecture in code (workspace isolation, scope-denied error contract, persistent-audit-log lifecycle including prune and graceful-degrade, `args_summary` redaction). The behavioural scenarios from `align-mcp-server-with-explore-decisions` are unchanged; this change layers code-level enforcement on top.

## Impact

- **Dependencies (`pubspec.yaml`):** remove `mcp_server`; add `mcp_dart: ^2.1.1` (in the workspace package's pubspec, not the root); declare `packages/quran_mcp_server` as a workspace member; add `path_provider` and `sqflite_common_ffi` (or whichever sqlite binding the project already uses) for `user.db`.
- **Code moves:** `lib/data/mcp/*.dart` and `lib/domain/mcp/*.dart` move into `packages/quran_mcp_server/lib/src/`; the public API surface is `packages/quran_mcp_server/lib/quran_mcp_server.dart`.
- **Code removed:** HTTPS / TLS / cert-generation plumbing; `mcp_playback_command.dart` pending-approval state machine; Approve/Deny widgets in `lib/features/mcp_status/mcp_status_page.dart`; in-memory recent-decisions ring buffer.
- **Code added:** HTTP listener, scope-check helpers, `audit_log_repository.dart`, `user.db` initialiser with v1 migration shell, prune-on-start hook (after the Quran/tafsir integrity gates), three SharedPreferences-backed Settings toggles + persistence, "Clear MCP audit log" Settings button with confirmation, an MCP Status preview that reads `audit_log` via `ORDER BY ts_utc DESC LIMIT 20`.
- **Persistent storage:** introduces the **first user-writable SQLite file** in the project. The schema-lock + migration story starts at v1 with just `audit_log`. Future bookmarks and playback-history changes will share `user.db` and bump the schema. `user.db` is the **only** SQLite file in the project that does not fail-closed on open failure — Quran reads + audio playback continue, the Settings MCP section shows a non-fatal notice.
- **Tests:** rewrite `test/data/mcp/*` tests to exercise the workspace package import surface and HTTP behaviour; add new tests under the workspace package for isolation, scope-denied mapping, prune, graceful-degrade, audit writes, and `args_summary` truncation.
- **Docs:** `AGENTS.md` *Lib layout* and *Project state* sections updated to describe the workspace package, `user.db`, and the scope-toggle model. `THIRD_PARTY_NOTICES.md` adds `mcp_dart` attribution and removes `mcp_server`.
- **Hard constraints carried forward:** loopback-only (`127.0.0.1` always; never `0.0.0.0`); no parallel data path; bundled `quran.sqlite` and `muyassar.sqlite` remain read-only; pre-commit hook (`flutter test`) is honoured — no `--no-verify`.
- **Out of scope:** new MCP tools or resources beyond what `add-mcp-server` already specifies; threat-model changes; bookmarks UX (only the `bookmark` scope shape is reserved); changes to Quran / tafsir / search / audio-reciter behaviour.
