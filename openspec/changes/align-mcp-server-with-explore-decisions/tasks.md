## 1. This correction (specification-only)

- [ ] 1.1 Branch from `develop` as `chore/propose-mcp-server-corrections` per the *one change, one branch* rule in [AGENTS.md](../../../AGENTS.md)
- [ ] 1.2 This proposal does NOT modify runtime code, in-flight artifacts, dependencies, or assets. It produces only:
      - [proposal.md](./proposal.md)
      - [design.md](./design.md)
      - [specs/mcp-server/spec.md](./specs/mcp-server/spec.md)
      - this tasks.md
- [ ] 1.3 Ship as a single PR. Merge before the re-application branch (Section 2 below) starts.

## 2. The re-application (separate follow-up branch — NOT this PR)

> The tasks in this section are reference for the implementer who lands the corrections on `chore/realign-mcp-server` (or by rebasing `feature/add-mcp-server` onto the corrected develop). They are NOT executed in this proposal's PR.

### Re-app 2.A — Transport (D1)

- [ ] 2.A.1 Remove HTTPS / TLS / self-signed-cert plumbing from the MCP server.
- [ ] 2.A.2 Bind a plain HTTP listener to `127.0.0.1` on the user-configured port.
- [ ] 2.A.3 Keep bearer-token auth in the `Authorization: Bearer <token>` header.
- [ ] 2.A.4 Update tests under `test/data/mcp/` that asserted HTTPS behaviour to assert HTTP behaviour. Rename `mcp_http_server.dart` if appropriate.

### Re-app 2.B — Package (D2)

- [ ] 2.B.1 Remove the in-flight `mcp_server` dependency from `pubspec.yaml` and any package-specific glue.
- [ ] 2.B.2 Add `mcp_dart: ^2.1.1` (or the latest compatible release in that lineage) to `packages/quran_mcp_server/pubspec.yaml`.
- [ ] 2.B.3 Implement the adapter so the package import surface is the only place that mentions `mcp_dart`.

### Re-app 2.C — Layout (D3)

- [ ] 2.C.1 Scaffold `packages/quran_mcp_server/` as a Dart workspace member (`pubspec.yaml`, `lib/quran_mcp_server.dart`, `lib/src/...`).
- [ ] 2.C.2 Add `workspace:` entry to the root `pubspec.yaml`.
- [ ] 2.C.3 Move existing MCP source files (`lib/data/mcp/*.dart`, `lib/domain/mcp/*.dart`) into the workspace package under `lib/src/`.
- [ ] 2.C.4 Update every import in the main app to reference the package's public entry point.
- [ ] 2.C.5 Add a test-time guard (similar to `domain/quran/domain_isolation_test.dart`) that asserts no file under `packages/quran_mcp_server/lib/` imports `package:flutter/`, `package:flutter_riverpod/`, or any `lib/features/` path.

### Re-app 2.D — Permission model (D4)

- [ ] 2.D.1 Remove the per-command pending-approval state machine from `lib/features/mcp_status/state/mcp_server_controller.dart` (or its successor).
- [ ] 2.D.2 Remove the Approve/Deny UI from `lib/features/mcp_status/mcp_status_page.dart`.
- [ ] 2.D.3 Add three Settings toggles persisted via `SharedPreferences`:
      - `mcp.scope.readonly` (master enable's child; implicitly on when MCP is enabled)
      - `mcp.scope.playback` (default OFF)
      - `mcp.scope.bookmark` (default OFF; reserved)
- [ ] 2.D.4 Implement scope-check helpers in `packages/quran_mcp_server/lib/src/scopes/`.
- [ ] 2.D.5 Update every Mode B tool handler to consult the relevant scope and return a structured `scope_denied` error when off.
- [ ] 2.D.6 Update the MCP Status page to show the active scopes (read-only computed from Settings), the bearer token while running, and a preview of the most recent N audit-log entries (D5).

### Re-app 2.E — Persistent audit log (D5)

- [ ] 2.E.1 Implement the user DB initialiser. Path: `path_provider.getApplicationSupportDirectory()/quran/user.db`. Schema v1 with `audit_log` table only; future tables (bookmarks, playback history) bump the schema.
- [ ] 2.E.2 Implement `audit_log_repository.dart` in the workspace package: append-only insert, prune older-than-7-days, clear-all.
- [ ] 2.E.3 Hook the prune into app start (after the read-only-DB integrity gates pass).
- [ ] 2.E.4 Add a "Clear MCP audit log" button to the Settings MCP section with a confirmation step.
- [ ] 2.E.5 Replace the in-flight in-memory recent-decisions surface with a SQL query against `audit_log` ordered by `ts_utc DESC LIMIT 20`.
- [ ] 2.E.6 Add `args_summary` redaction: `search_quran` queries truncated at 128 chars with an explicit truncation marker.
- [ ] 2.E.7 Add a graceful-degrade test: `user.db` open failure shows the Settings notice and the rest of the app continues to function.

### Re-app 2.F — In-flight artifact reconciliation

- [ ] 2.F.1 Edit [`openspec/changes/add-mcp-server/proposal.md`](../add-mcp-server/proposal.md) to reflect HTTP / `mcp_dart` / workspace / scope-toggles / persistent audit.
- [ ] 2.F.2 Edit [`openspec/changes/add-mcp-server/design.md`](../add-mcp-server/design.md) to replace the five divergent decision blocks.
- [ ] 2.F.3 Rewrite [`openspec/changes/add-mcp-server/specs/mcp-server/spec.md`](../add-mcp-server/specs/mcp-server/spec.md) to adopt this correction's scenarios and remove the four per-command-approval scenarios named in this correction's spec under `## REMOVED Requirements`.
- [ ] 2.F.4 Edit [`openspec/changes/add-mcp-server/tasks.md`](../add-mcp-server/tasks.md) to drop the per-command-approval task items and add the scope-toggle + audit-log task items.
- [ ] 2.F.5 Run `openspec validate add-mcp-server` and confirm the corrected delta validates.

### Re-app 2.G — Verification

- [ ] 2.G.1 `just check` clean — format, analyze, all tests pass including the new scope-denied and audit-log tests.
- [ ] 2.G.2 Manual smoke test: enable MCP in Settings, copy the URL+token, run `curl` against `http://127.0.0.1:<port>/mcp` with and without the token, confirm the unauthorized request is rejected and the authorized one returns tool listing.
- [ ] 2.G.3 Manual scope test: toggle `Allow MCP playback control` OFF, call `play_ayah` from an MCP client, confirm the response is `scope_denied` and no player state changes.
- [ ] 2.G.4 Manual audit-log test: make several Mode A calls, restart the app, confirm the audit-log entries persist; clear the log from Settings, confirm the table is empty.
- [ ] 2.G.5 Manual prune test: insert a synthetic entry with `ts_utc` 8 days in the past via maintainer SQL, restart the app, confirm the prune deletes the row.
