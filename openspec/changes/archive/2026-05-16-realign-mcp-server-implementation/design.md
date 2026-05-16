## Context

This is the implementation companion to `align-mcp-server-with-explore-decisions` (PR #21, spec-only correction). That correction redesigned five decisions of the MCP server at the spec level; this change implements them in code. The behavioural decisions D1–D5 are not re-litigated here — they are the prior change's `design.md` and remain authoritative. This document focuses on the implementation choices that fall out of those decisions: workspace package shape, the protocol adapter, the user-DB lifecycle, the cross-package wiring of Settings toggles into a Flutter-free package, and the test strategy that locks the corrected behaviour into CI.

Current state on develop:
- `lib/data/mcp/{mcp_dtos.dart, mcp_http_server.dart, mcp_server_service.dart}` — HTTPS server using `mcp_server`, in-process.
- `lib/domain/mcp/{mcp_error.dart, mcp_lifecycle.dart, mcp_playback_bridge.dart, mcp_playback_command.dart}` — domain types incl. the per-command pending-approval state machine.
- `lib/features/mcp_status/{mcp_status_page.dart, state/mcp_server_controller.dart, state/mcp_playback_bridge.dart}` — Approve/Deny UI + controller.
- `test/data/mcp/*` and `test/features/mcp_status/*` — tests over the divergent shape.

Stakeholders: user (ratified the five decisions and resolved all five open questions on this branch); reviewer (needs a small, comprehensible diff); future bookmarks/playback-history changes (inherit `user.db` schema introduced here).

Constraints (from project rules and the prior correction):
- Loopback-only on `127.0.0.1`. No `0.0.0.0`.
- Tools/resources reuse `QuranRepository`/`AudioRepository` via constructor injection. No parallel data path.
- Bundled `quran.sqlite`, `muyassar.sqlite` are read-only; `user.db` is the only user-writable SQLite file.
- `flutter test` runs as a pre-commit hook; commits with failing tests are blocked. No `--no-verify`.

## Goals / Non-Goals

**Goals:**
- Land each of D1–D5 in code with the smallest credible diff.
- Move all MCP code into `packages/quran_mcp_server/` and prove (via test) that no Flutter-coupled symbol leaks into the package.
- Make `user.db` a coherent foundation for the future `bookmarks` and `playback_history` tables — schema v1 is `audit_log` only, but the migration shell supports versioned upgrades.
- Make `user.db` the **only** SQLite file in the project that does NOT fail-closed on open failure.
- Lock every corrected behaviour into a test, so a future regression that re-introduces HTTPS, modal approval, or in-memory audit gets caught at CI.
- Reconcile the in-flight `add-mcp-server` openspec artifacts so they describe what shipped, not what was originally proposed.

**Non-Goals:**
- New MCP tools or resources beyond what `add-mcp-server` already specifies.
- Threat-model changes (loopback + token + scopes + audit).
- Bookmarks tooling — only the scope toggle is shape-reserved.
- Touching Quran / tafsir / search / audio reciter behaviour.
- Replacing or removing `mcp_dart` — D2 picks it; later revisions can revisit.
- Migrating the in-flight implementer's git history (the realignment lands as new commits on `feature/realign-mcp-server-implementation`).

## Decisions

### I1: Workspace package layout and public surface

The workspace package exposes one public entry point. Internals live under `src/`:

```
packages/quran_mcp_server/
  pubspec.yaml                            # name: quran_mcp_server
  analysis_options.yaml?                  # NOT created (Q3 resolved: inherit)
  lib/
    quran_mcp_server.dart                 # public exports only
    src/
      server.dart                         # HTTP listener + mcp_dart adapter wiring
      adapter/
        mcp_dart_adapter.dart             # only file allowed to import package:mcp_dart
      tools/
        list_surahs_tool.dart
        get_surah_tool.dart
        get_ayah_tool.dart
        list_reciters_tool.dart
        search_quran_tool.dart
        play_surah_tool.dart
        play_ayah_tool.dart
        pause_playback_tool.dart
        resume_playback_tool.dart
        stop_playback_tool.dart
        set_repeat_tool.dart
      resources/
        quran_resources.dart              # quran://surahs, quran://ayah/<s>/<a>, ...
      audit/
        audit_log_repository.dart
        audit_entry.dart
        args_summary.dart                 # truncate-and-mark helper for search_quran
      scopes/
        scope.dart                        # enum Scope { readonly, playback, bookmark }
        scope_check.dart                  # callable: (Scope) -> bool
      user_db/
        user_db.dart                      # open / migrate / close
        user_db_schema.dart               # CREATE TABLE statements per version
  test/
    isolation_test.dart                   # asserts no flutter / riverpod / app imports
    audit/
      audit_log_repository_test.dart
      args_summary_test.dart
      prune_test.dart
    scopes/
      scope_check_test.dart
    user_db/
      user_db_open_test.dart
```

`packages/quran_mcp_server/lib/quran_mcp_server.dart` re-exports only what the host app needs to wire the server: a `QuranMcpServer` class with a constructor that takes `QuranRepository`, `AudioRepository`, `ScopeCheck` (a function `(Scope) -> bool`), `AuditLogRepository`, and a port; methods `start()`, `stop()`, `currentToken`, `lifecycleStream`. **No Riverpod types, no Flutter widgets, no SharedPreferences imports cross the package boundary.**

The `analysis_options.yaml` decision is resolved (Q3): the package inherits from the repo root via the workspace. No per-package file is created.

### I2: The protocol adapter

`adapter/mcp_dart_adapter.dart` is the **only** file allowed to import `package:mcp_dart`. It maps the package's HTTP request → tool dispatch → response shape into a small internal interface (`McpServerAdapter`) that the rest of the package codes against. This keeps the option open to swap `mcp_dart` for another package without touching tool/resource handlers.

The adapter exposes:
- `Future<void> bind(String host, int port)` — `host` is always `'127.0.0.1'`.
- `void registerTool(String name, ToolHandler handler)`.
- `void registerResource(String uriTemplate, ResourceHandler handler)`.
- `Stream<McpEvent> events`.

Tool handlers are pure async functions that take a typed args map and return either a typed result or a structured `McpError` (from `mcp_error.dart`, which moves over from `lib/domain/mcp/`). Errors **never** flow as thrown exceptions across the adapter boundary — the adapter catches and converts to the protocol error shape.

### I3: Settings → workspace package wiring (the cross-package boundary)

The workspace package is Flutter-free. It can't read `SharedPreferences` directly. The host app injects a `ScopeCheck` callable at server construction:

```dart
final server = QuranMcpServer(
  quran: ref.read(quranRepositoryProvider),
  audio: ref.read(audioRepositoryProvider),
  scopeCheck: (scope) => switch (scope) {
    Scope.readonly  => true,                         // implicit when MCP enabled
    Scope.playback  => prefs.getBool('mcp.scope.playback')  ?? false,
    Scope.bookmark  => prefs.getBool('mcp.scope.bookmark')  ?? false,
  },
  auditLog: auditLogRepository,
  port: prefs.getInt('mcp.port') ?? 0,
);
```

`ScopeCheck` is read on each tool call (not cached at start), so toggling a scope OFF in Settings affects the very next MCP request without restarting the server. The toggle widget invalidates a Riverpod provider that re-emits a fresh `ScopeCheck` closure if needed; the server holds the latest closure.

SharedPreferences keys (locked):
- `mcp.enabled` — master toggle (default OFF for first-run safety; user must opt in)
- `mcp.scope.playback` — Mode B playback scope (default OFF)
- `mcp.scope.bookmark` — Mode B bookmark scope (default OFF, reserved)
- `mcp.port` — port; 0 means "ask the OS" on next start

### I4: user.db lifecycle

`user.db` lives at `path_provider.getApplicationSupportDirectory()/quran/user.db`. It is created on first open. The directory is created with `Directory.create(recursive: true)` if missing.

Schema v1 — created by `user_db_schema.dart`:

```sql
CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
INSERT INTO schema_meta(key, value) VALUES ('version', '1');
INSERT INTO schema_meta(key, value) VALUES ('created_at_utc', '<epoch_millis>');

CREATE TABLE audit_log (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  ts_utc          INTEGER NOT NULL,
  tool_name       TEXT NOT NULL,
  args_summary    TEXT NOT NULL,
  result_status   TEXT NOT NULL CHECK(result_status IN
    ('ok','scope_denied','invalid_input','not_found','unavailable','error')),
  scope_at_time   TEXT NOT NULL
);
CREATE INDEX idx_audit_log_ts ON audit_log(ts_utc);
```

**Open lifecycle:**
1. `main()` opens `user.db` after the read-only Quran/tafsir integrity gates pass.
2. If open succeeds, check `schema_meta.version`; run any pending migrations (none for v1 → v1).
3. Run prune: `DELETE FROM audit_log WHERE ts_utc < (now_utc_millis - 7*86_400_000)`.
4. Make the repository available via Riverpod (`auditLogRepositoryProvider`).
5. If open fails: log `appLogger.severe('user.db open failed: $e')`, set a Riverpod `userDbHealthProvider` to `Failure(...)`, and **continue app start**. Quran reads + audio playback still work. The Settings MCP section reads `userDbHealthProvider` and shows a non-fatal notice ("MCP audit log unavailable — restart the app or check disk permissions"). The MCP server simply starts without an audit log; calls succeed but no rows are persisted (per call: `appLogger.warning('audit_log unavailable')`).

This is the **first** SQLite file in the project that does not fail-closed. The justification is: a corrupt audit log loses post-hoc audit but does not affect Quran-text correctness (the project's "trustworthy before powerful" threshold). Bookmarks and playback history would land later and need to choose their own degrade behaviour case-by-case.

### I5: Audit-log writes (both modes)

Q5 resolved: every tool call appends one row, regardless of mode. The handler wrapper (in `adapter/mcp_dart_adapter.dart`) is a single point that writes the audit row after the tool returns, capturing:

- `ts_utc`: `DateTime.now().toUtc().millisecondsSinceEpoch`
- `tool_name`: from registration
- `args_summary`: per-tool function (most tools render `key=value` pairs; `search_quran` uses `args_summary.dart`'s 128-char truncator with marker)
- `result_status`: derived from the handler return — `ok`, `scope_denied`, `invalid_input`, `not_found`, `unavailable`, `error`
- `scope_at_time`: a CSV like `"readonly,playback"` for the scopes that evaluated true at call time

The truncation marker is the literal three-character ellipsis `…` followed by `[+N more]` where `N` is the number of additional codepoints not stored. Example: a 200-char query becomes `<first 128 chars>…[+72 more]`.

### I6: MCP Status page rewrite (no Approve/Deny)

The current page in `lib/features/mcp_status/mcp_status_page.dart` shows pending approvals and offers Approve/Deny buttons. After this change it shows:

- Lifecycle state (running / stopped / error) — **PRESERVED** behaviour.
- The bearer token while running, with a copy button — **PRESERVED**.
- The base URL `http://127.0.0.1:<port>/mcp` — **PRESERVED** (just `http` not `https`).
- Active scopes (live-computed: read-only is implicit when running; playback/bookmark from SharedPreferences) — **NEW**.
- Exposed tools and resources count — **PRESERVED**.
- A list of the most recent 20 audit entries (timestamp, tool, status, scope) read from `audit_log ORDER BY ts_utc DESC LIMIT 20` — **NEW**, replaces the in-memory ring buffer.
- A "Clear MCP audit log" button (lives in Settings, but a link from this page navigates there) — **NEW**.

The Settings page gains an "MCP server" section with: master `Enable MCP` toggle, port input, two scope toggles (`Allow MCP playback control`, `Allow MCP bookmark access` — disabled with "reserved for future bookmarks" hint until that change ships), and a `Clear MCP audit log` button with a confirmation dialog.

### I7: Test strategy — locking the corrected behaviour into CI

Each new requirement in `specs/mcp-server/spec.md` (the delta in this change) maps 1:1 to a test:

| Requirement                                        | Test location                                                            |
|----------------------------------------------------|--------------------------------------------------------------------------|
| R1: Workspace isolation                            | `packages/quran_mcp_server/test/isolation_test.dart`                     |
| R2: Workspace registered in root pubspec           | `test/workspace_member_test.dart` (root) — parses pubspec.yaml YAML      |
| R3: Scope-denied returns structured `McpError`     | `packages/quran_mcp_server/test/scopes/scope_check_test.dart`            |
| R4: Audit prune deletes rows older than 7 days     | `packages/quran_mcp_server/test/audit/prune_test.dart`                   |
| R5: user.db open failure degrades gracefully       | `test/data/user_db/user_db_graceful_degrade_test.dart` (host app side)   |
| R6: Both Mode A and Mode B append audit rows       | `packages/quran_mcp_server/test/audit/audit_log_repository_test.dart`    |
| R7: search_quran args_summary truncates at 128     | `packages/quran_mcp_server/test/audit/args_summary_test.dart`            |

The HTTP smoke tests (`test/data/mcp/mcp_http_server_test.dart` today) move into the workspace package's test folder and are rewritten for HTTP (not HTTPS) and the `mcp_dart` shape.

### I8: In-flight artifact reconciliation order

Inside this branch, after the runtime code lands and tests pass:

1. Edit `openspec/changes/add-mcp-server/proposal.md` — strike the HTTPS line, the `mcp_server` mention, the `lib/data/mcp/` layout reference, the per-command approval description, and the "audit log deferred" line. Replace each with the corrected wording.
2. Edit `openspec/changes/add-mcp-server/design.md` — replace the five divergent decision blocks with the corrected ones (or, simpler, reduce the document to a brief that points at `align-mcp-server-with-explore-decisions/design.md` for D1–D5 and at *this* change's `design.md` for I1–I8).
3. Rewrite `openspec/changes/add-mcp-server/specs/mcp-server/spec.md` — adopt the corrected scenarios and remove the four per-command-approval scenarios named in `align-mcp-server-with-explore-decisions/specs/mcp-server/spec.md` under `## REMOVED Requirements`.
4. Edit `openspec/changes/add-mcp-server/tasks.md` — drop the per-command-approval items, add the scope-toggle + audit-log items.
5. Run `openspec validate add-mcp-server`. Must pass.

After this PR merges, `chore/archive-mcp-changes` archives both `add-mcp-server` and `align-mcp-server-with-explore-decisions` together (precedent: PR #22 + #23 archived two changes together).

## Risks / Trade-offs

- **`mcp_dart` API surface unknowns** → confirmed-stable enough at v2.1.1 for HTTP transport + tool/resource registration; if a blocker emerges, file a separate revision change rather than expanding scope here. Mitigation: the adapter (I2) keeps the swap shallow.
- **Workspace packages add a small Dart-tooling tax** (extra `dart pub get` resolution step) → negligible on a single-developer project; recoverable by `flutter clean && flutter pub get` if the resolver gets confused. Documented in `AGENTS.md` *Lib layout*.
- **`user.db` graceful-degrade is a deviation from the project's fail-closed-by-default posture for SQLite** → intentional and bounded: the bundled read-only DBs still fail closed; only `user.db` degrades. Justified in I4. Future user-writable tables (bookmarks) will need to argue their own degrade behaviour explicitly.
- **`args_summary` truncation could still leak sensitive content from non-search tools** → tools other than `search_quran` summarise structured arguments only (e.g., `get_ayah` → `surah=2,ayah=255`); none take free-text input from the AI client. If a future tool does, it must register its own summariser following the same pattern as `args_summary.dart`. Documented in I5.
- **Reviewer cognitive load** → the diff is large because it spans both code moves and spec deltas. Mitigation: the commit log on this branch is granular (transport / package / layout / permission / audit / reconciliation / verification — one commit each per task subsection), and the proposal explicitly maps every change back to a D-decision or an I-decision.
- **Pre-commit `flutter test` hook may flake on file-IO heavy `user.db` tests on Windows** → use `path_provider_platform_interface` overrides in tests so `user.db` lands in a temp dir per test, never the real Application Support folder.

## Migration Plan

Order of code edits on this branch (each is one commit; each commit ends with `flutter test` green so the pre-commit hook stays useful):

1. **Scaffold workspace package** (no code yet): `packages/quran_mcp_server/pubspec.yaml` + empty `lib/quran_mcp_server.dart`; root `pubspec.yaml` declares the workspace; `flutter pub get` resolves; the package's empty isolation test passes.
2. **Move domain types**: `lib/domain/mcp/{mcp_error.dart, mcp_lifecycle.dart}` into `packages/quran_mcp_server/lib/src/`. `lib/domain/mcp/mcp_playback_command.dart` is **deleted** (per-command approval is gone). Import sites updated.
3. **Add user.db** (no MCP wiring yet): `user_db/`, `audit/`, schema v1, prune, graceful-degrade. Host-app integration test for the degrade path lands in this commit.
4. **Move HTTP server + add mcp_dart adapter**: `lib/data/mcp/*` → `packages/quran_mcp_server/lib/src/`. Swap `mcp_server` → `mcp_dart`. Switch HTTPS → HTTP. Existing tool handlers move; HTTPS-specific code deleted.
5. **Add scope check**: `scopes/`, host app injects `ScopeCheck`, all Mode B tools consult it. Existing per-command-approval state machine and Approve/Deny UI deleted in this commit.
6. **Settings UI**: master `Enable MCP` + port + two scope toggles + Clear-audit button. MCP Status page reads from `audit_log`.
7. **Reconcile `add-mcp-server` artifacts**: edit proposal/design/spec/tasks; `openspec validate add-mcp-server` passes.
8. **Docs**: `AGENTS.md` Lib layout + Project state; `THIRD_PARTY_NOTICES.md` `mcp_dart` attribution.
9. **Final verification**: `just check` clean; manual smoke tests per the proposal's "What done looks like".

Rollback: revert this PR. The divergent code on develop returns. `add-mcp-server` and `align-mcp-server-with-explore-decisions` remain un-archived. No data loss because `user.db` lives outside the repo.

## Open Questions

*(The five from the prior correction were resolved on this branch. Remaining design-time questions are bounded.)*

- Does `mcp_dart`'s HTTP transport API at `^2.1.1` accept a `host` parameter, or does it bind `0.0.0.0` by default? **Verify in step 4 of the migration.** If it binds non-loopback, the adapter MUST drop incoming connections from any non-`127.0.0.1` peer at the dispatch layer as a defence-in-depth measure, and we file an upstream issue. The loopback-only rule is non-negotiable.
- Should the Settings "Clear MCP audit log" button require typed confirmation (`type "clear" to confirm`) or a simple `Confirm`/`Cancel` dialog? **Default to simple Confirm/Cancel** — the action is reversible only by re-running MCP calls, but it's not catastrophic. Revisit if a future change adds bookmarks-clear.
- When the master `Enable MCP` toggle goes from ON → OFF while the server is running, do in-flight requests complete or are they cancelled? **Default to: stop accepting new connections, let in-flight handlers finish (typically <50ms), then close the listener.** Standard graceful shutdown.
