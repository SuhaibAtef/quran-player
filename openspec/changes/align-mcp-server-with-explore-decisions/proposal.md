## Why

A prior implementer landed a working MCP server on [`feature/add-mcp-server`](../add-mcp-server/) with a thorough proposal, design, spec, and 4 implementation commits. The work is solid in its own right, but it was branched and built **without picking up five architectural decisions** that were ratified in the same `/openspec-explore` conversation that produced [add-tafsir-data](../archive/2026-05-14-add-tafsir-data/), [add-topical-index-data](../add-topical-index-data/), and [add-semantic-search-design](../archive/2026-05-14-add-semantic-search-design/). Those three changes all honored the decisions; the MCP work did not. This correction names the divergences explicitly and turns them into a tracked change so the next implementing PR re-aligns the runtime code AND the in-flight `add-mcp-server` artifacts.

This proposal is corrective scaffolding. It does NOT add new MCP tools, resources, or threat-model rules. It does NOT touch the Quran or tafsir data layers. It re-points the five specific decisions enumerated below at the agreed answers.

## What Changes

For each of the five divergences, the implementer:

- **Transport — HTTPS → HTTP.** Drop the self-signed-certificate plumbing. Bind a plain HTTP listener to `127.0.0.1` on the user-configured port. The bearer-token Authorization header remains the auth boundary; loopback binding + token is the threat model the user ratified.
- **MCP package — `mcp_server` → `mcp_dart` ^2.1.1.** Swap the protocol package. The thin adapter behind which the package sits stays unchanged so future swaps stay bounded.
- **Layout — `lib/data/mcp/` → `packages/quran_mcp_server/`.** Move the MCP server into a Dart workspace member. The Flutter app depends on it as a `workspace:` package. Public API exposes start/stop, scope checks, and token rotation; tools/resources still consume the existing `QuranRepository` / `AudioRepository` contracts via constructor injection from the app composition layer.
- **Permission model — per-command approval prompts → pre-granted scope toggles.** Replace the pending-approval flow with three independent Settings toggles (`Allow MCP read-only data`, `Allow MCP playback control`, `Allow MCP bookmark access` — the third is shape-reserved since bookmarks don't ship yet). Mode B tools check the relevant scope at call time and return a structured `scope_denied` error if the toggle is off. No modal UI, no timeouts, no deadlocked clients.
- **Audit log — ephemeral session-only → persistent with weekly auto-prune.** Implement the audit log against a new user-writable SQLite file at `path_provider.getApplicationSupportDirectory()/quran/user.db`. Table `audit_log` is append-only with `(id, ts_utc, tool_name, args_summary, result_status, scope_at_time)`. App start prunes rows older than 7 days. Settings exposes a "Clear MCP audit log" button. The MCP Status page shows the most recent N entries.

Out of scope: new MCP tools or resources, changes to canonical Quran text behavior, additional MCP threat-model rules (loopback-only, no shell, no arbitrary file access — all kept), tafsir UI, semantic-search work. Server start *mechanism* (Settings toggle vs MCP Status button) is a minor UX detail and is left to the implementer — both satisfy the user's "running server along the app" requirement as long as start is one-click and persists across launches.

## Capabilities

### Modified Capabilities

- `mcp-server`: still introduced by the in-flight [add-mcp-server](../add-mcp-server/) change; this correction MODIFIES specific scenarios in that change's delta spec (transport, permission flow) and ADDS new requirements (scope toggles, persistent audit log, workspace layout, mcp_dart pinning). The corrected delta spec lives at [`specs/mcp-server/spec.md`](specs/mcp-server/spec.md) and explicitly names every scenario it supersedes.

### New Capabilities

<!-- None. mcp-server is introduced by add-mcp-server; this proposal only corrects its shape. -->

## Impact

- **Code that will be re-touched once this correction lands:**
  - `lib/data/mcp/mcp_http_server.dart` → relocated under `packages/quran_mcp_server/lib/`; HTTPS bits removed
  - `lib/data/mcp/mcp_server_service.dart` → relocated, package import updated
  - `lib/data/mcp/mcp_protocol_handler.dart` (if reintroduced) → consumed by mcp_dart adapter
  - `lib/features/mcp_status/state/mcp_server_controller.dart` → drop pending-approval state; consume scope toggles via Riverpod
  - `lib/features/mcp_status/mcp_status_page.dart` → drop per-command Approve/Deny UI; surface scope toggles status + audit-log preview
  - `lib/features/settings/settings_page.dart` → add three MCP scope toggle rows + "Clear MCP audit log" button
  - new `lib/data/mcp/audit_log_repository.dart` (or under the workspace package) → SQLite-backed audit log
  - new user DB initialiser (writable, separate from the read-only Quran/tafsir DBs)
- **In-flight artifact edits:** [`openspec/changes/add-mcp-server/proposal.md`](../add-mcp-server/proposal.md), [`design.md`](../add-mcp-server/design.md), [`specs/mcp-server/spec.md`](../add-mcp-server/specs/mcp-server/spec.md), and [`tasks.md`](../add-mcp-server/tasks.md) are reconciled with this correction's scenarios. Specifically, six per-command-approval scenarios are removed and replaced with scope-gated equivalents; the HTTPS transport scenarios become HTTP; the package name is updated; the workspace layout and audit log requirements are added.
- **Dependencies:**
  - REMOVE: `mcp_server` (in-flight) and any TLS / certificate-generation dependency it pulled in.
  - ADD: `mcp_dart: ^2.1.1`.
  - Workspace member `packages/quran_mcp_server/` with its own `pubspec.yaml`. Reuses runtime deps already in the main app (`sqflite_common_ffi`, `shared_preferences`, `path_provider`, `path`, `crypto`).
- **Settings UI:** three new toggle rows under a new "MCP server" section, alongside the existing "MCP Status" top-level page. The port field is editable; the bearer token is shown read-only while running.
- **Tests that will be re-touched:** every existing `test/data/mcp/*` and `test/features/mcp_status/*` test gets re-pointed at the workspace package + scope-toggle world. New tests: scope-denied returns structured error, persistent audit log survives a simulated restart, port-conflict reports error and disables toggle.
- **Documentation:** [AGENTS.md](../../../AGENTS.md), [README.md](../../../README.md), and [THIRD_PARTY_NOTICES.md](../../../THIRD_PARTY_NOTICES.md) all get updates **when the re-application lands**, not in this correction PR.
- **Branching:** this correction lands on `chore/propose-mcp-server-corrections` (current branch). The actual code re-alignment happens on a follow-up branch — `chore/realign-mcp-server` — that rebases `feature/add-mcp-server` and edits both runtime code and the in-flight artifacts. This correction proposal does NOT modify any code in this PR; it only specifies what must change.
