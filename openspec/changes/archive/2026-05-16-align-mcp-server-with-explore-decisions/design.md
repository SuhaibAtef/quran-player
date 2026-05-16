## Context

The `/openspec-explore` conversation that drove the search/tafsir/topics/semantic-search proposals also drove the MCP server design. Five decisions were ratified in that conversation:

1. Transport: plain HTTP over loopback (the user explicitly chose `do http` after I clarified that "local MCP via port" is the streamable HTTP transport, not raw TCP).
2. Package: `mcp_dart: ^2.1.1` (named by the user after I surfaced it as a candidate).
3. Layout: a Dart workspace package (`packages/quran_mcp_server/`) — the user said "it can be a workspace package."
4. Permission model: pre-granted independent scope toggles in Settings (the user chose Option β when I offered three permission shapes).
5. Audit log: persistent, with weekly auto-prune (the user wrote: *"Persistent. but we want an option to clear it each week for example so it does not load the storage. and keeping it for important stuff only."*).

The implementer of `feature/add-mcp-server` did not have that conversation in context. They built a thoughtful and IDEA.md-compliant server but on a different five points: HTTPS with self-signed cert, a different `mcp_server` package, in-process under `lib/data/mcp/`, per-command modal approval flow, and an ephemeral in-memory audit log explicitly marked as deferred.

This change is the correction. It does NOT redesign the MCP threat model; it does NOT add new tools or resources; it does NOT touch Quran or tafsir behavior. It re-points exactly five decisions at their ratified answers and specifies how the spec, the runtime code, and the in-flight `add-mcp-server` artifacts get reconciled.

Constraints (carried from `/openspec-explore` and from project rules):

- The MCP server stays loopback-only. No remote listener, no shell, no arbitrary file access. These principles were never in question and are unchanged.
- Errors flow through `Result<T>` / structured MCP errors. No raw exceptions across the protocol boundary.
- The Flutter app remains the boundary owner for Quran text correctness and audio reciter approval. Workspace-package separation does NOT mean a parallel data path — the package consumes the existing repository contracts via constructor injection.
- One change → one branch → one PR ([AGENTS.md](../../../AGENTS.md)). This correction is its own branch (`chore/propose-mcp-server-corrections`); the code re-alignment is a separate branch.

Stakeholders: the user (who ratified the divergent decisions originally), the implementer who built the in-flight branch (whose work is preserved in git history and partially re-used), the reviewer (who needs a crisp diff between "in-flight" and "corrected"), and downstream MCP-extension work (which inherits the corrected shape).

## Goals / Non-Goals

**Goals:**

- Restore each of the five ratified decisions in the spec, traceable to the `/openspec-explore` conversation.
- Name every in-flight scenario that this correction supersedes, so the reviewer can compare side-by-side.
- Specify the workspace-package layout cleanly so the implementer of the re-application knows exactly where files move.
- Specify the persistent audit log's SQLite schema and prune behaviour so the user DB layer starts with a coherent shape (since bookmarks and playback history will share it later).
- Keep this proposal correction-only — no scope creep into new tools, resources, or behaviours that weren't in the in-flight `add-mcp-server` design.

**Non-Goals:**

- Adding MCP tools or resources beyond what `add-mcp-server` already specifies.
- Changing the MCP threat model (loopback-only, no shell, no arbitrary file access — all preserved).
- Touching the Quran text behaviour, tafsir behaviour, search behaviour, or audio reciter behaviour.
- Designing the broader bookmarks feature (the user DB schema is anchored here only for the audit-log table; bookmarks land in their own change).
- Re-implementing the MCP server from scratch — the in-flight implementation is partially re-used. Only the five corrected decisions force code moves.

## Decisions

### D1: Transport — plain HTTP over `127.0.0.1`

The MCP server SHALL bind a plain HTTP listener (NOT HTTPS) to `127.0.0.1` on a user-configured port. The bearer token in the `Authorization: Bearer <token>` header is the auth boundary; TLS is not used.

- **Why:** the user ratified HTTP after I clarified the protocol shape. Loopback binding + per-server-start high-entropy token is the threat model. HTTPS-on-loopback would not raise security but would impose self-signed-certificate trust-store friction on every client install. The user-facing flow is "paste a URL and token into the MCP client config" — adding cert-trust is friction without security gain.
- **Replaces in-flight scenarios:**
  - `Server exposes authenticated HTTPS local client details` → corrected to HTTP
  - `HTTPS endpoint remains local` → corrected to HTTP
  - `Missing token is rejected` → wording updated from "HTTPS MCP endpoint" to "HTTP MCP endpoint"
- **What the implementer removes:** ephemeral self-signed cert generation, any TLS-related dependency, the documented client-trust step in copy.
- **What stays:** loopback-only binding, bearer-token gate, in-place port configuration, token freshness on every server start.

### D2: Package — `mcp_dart: ^2.1.1`

The protocol implementation SHALL use the `mcp_dart` package at version `^2.1.1` (or the latest compatible version in that lineage at implementation time). The in-flight `mcp_server` dependency is replaced.

- **Why:** the user named `mcp_dart` explicitly during `/openspec-explore` after I surfaced it. The spec is the source of truth; reverting that decision without an explicit revision violates project rules.
- **Replaces in-flight scenarios:** none directly — the in-flight spec does not name a package. The change is in the implementation + design documents.
- **What stays:** the thin adapter behind which the package sits. The adapter exposes a small surface (start, stop, register tools, register resources, handle requests) so the package itself remains swappable in future. mcp_dart is the v1 pin.
- **Risk note:** mcp_dart's API surface and version pin are recorded in design appendix; pubspec.yaml change happens in the re-application branch, not here.

### D3: Layout — `packages/quran_mcp_server/` workspace package

The MCP server code SHALL live in a Dart workspace package at `packages/quran_mcp_server/` rather than under `lib/data/mcp/`. The main Flutter app declares the package as a workspace member in its `pubspec.yaml` (`workspace:` entry) and depends on it as a path dependency.

```
quran_player/                   # Flutter app (root pubspec workspace)
  lib/                          # app composition only; no MCP code
  packages/
    quran_mcp_server/           # NEW workspace member
      pubspec.yaml
      lib/
        quran_mcp_server.dart   # public API
        src/
          server.dart           # HTTP listener, mcp_dart wiring
          tools/                # search_quran, get_ayah, ...
          resources/            # quran://surahs, quran://ayah/...
          audit/                # audit_log_repository.dart
          scopes/               # scope check helpers
```

- **Why:** cleaner architectural boundary. The MCP server is conceptually a separate component from the app shell. A workspace package prevents the server from accidentally importing Flutter widgets or app-only state. It also keeps the door open for a future headless / sidecar variant without re-architecting (e.g., `dart run packages/quran_mcp_server` from a CI verification step).
- **Replaces in-flight scenarios:** none directly — the in-flight spec doesn't dictate layout. The change is mechanical: move files, update imports.
- **What stays:** the tools/resources still consume the existing `QuranRepository` and `AudioRepository` contracts. The package does NOT have its own data layer. Constructor injection from the app composition layer wires the repositories in.
- **Risk note:** workspace packages require Dart SDK `^3.6.0`+. The project is on `^3.11.0` already; no SDK bump needed.

### D4: Permission model — pre-granted scope toggles, NO per-command prompts

The MCP server SHALL gate Mode B commands on **pre-granted scope toggles** persisted in Settings, not on per-command modal approval prompts. Three scopes are defined:

| Settings toggle | Mode | Default | Gates |
|---|---|---|---|
| `Allow MCP read-only data` | A | on (master MCP toggle is the parent) | `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, `list_reciters`, all `quran://...` resources |
| `Allow MCP playback control` | B | OFF | `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, `set_repeat` |
| `Allow MCP bookmark access` | B (reserved) | OFF | Shape-reserved for future bookmark tools — no tools or resources gate on this yet, but the toggle is listed so the UI doesn't shift when bookmarks ship |

Tools check the relevant scope at call time. A disabled scope returns a structured MCP error (`scope_denied`) and the tool never executes.

- **Why:** the user chose Option β (independent toggles) when offered three permission shapes. The reasoning: AI clients should feel like *trusted within their granted scope*. Modal prompts every time Claude asks to "play surah Yasin" would be infuriating and would deadlock any automation workflow. Pre-granted scopes are the standard MCP server pattern. The persistent audit log (D5) provides after-the-fact accountability — modal prompts try to provide that up-front but at high UX cost.
- **Replaces in-flight scenarios (this is the largest correction):**
  - `Play surah waits for user approval` → REMOVED; replaced with `Play surah requires playback scope`
  - `Play ayah waits for user approval` → REMOVED; replaced with `Play ayah requires playback scope`
  - `Pause command waits for user approval` → REMOVED; replaced with `Pause command requires playback scope`
  - `Denied command does not change playback` → REMOVED; replaced with `Scope-denied command does not change playback`
  - `Approved command uses app player behavior` → MODIFIED; "Approved" → "Authorized by scope"
  - `Supported repeat mode can be approved` → MODIFIED; "approved" → "authorized by scope"
- **What stays:** structured `app_unavailable` / `player_unavailable` errors when the app/player bridge is not ready; structured `invalid_input` errors when the repeat mode or Quran reference is malformed.
- **UI consequence:** the `add-mcp-server` MCP Status page's Approve/Deny UI is removed. The MCP Status page now shows: lifecycle state, active scopes (read-only computed from Settings), exposed tools/resources, the bearer token while running, and the most recent N audit-log entries (see D5). The Settings page gains a "MCP server" section with the three toggles + port + master enable.

### D5: Audit log — persistent, SQLite-backed, weekly auto-prune

The MCP server SHALL persist every tool call's audit entry to a SQLite database. The audit log table schema is:

```sql
CREATE TABLE audit_log (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  ts_utc          INTEGER NOT NULL,                 -- epoch millis
  tool_name       TEXT NOT NULL,
  args_summary    TEXT NOT NULL,                    -- short, max ~512 chars
  result_status   TEXT NOT NULL CHECK(result_status IN ('ok','scope_denied','invalid_input','not_found','unavailable','error')),
  scope_at_time   TEXT NOT NULL                     -- e.g. "readonly,playback"
);
CREATE INDEX idx_audit_log_ts ON audit_log(ts_utc);
```

The DB lives at `path_provider.getApplicationSupportDirectory()/quran/user.db` — a new **user-writable** SQLite file, distinct from the read-only bundled `quran.sqlite` and `muyassar.sqlite`. App start runs a one-time prune (`DELETE FROM audit_log WHERE ts_utc < (NOW_MILLIS - 7 days)`). The Settings page exposes a "Clear MCP audit log" button that runs `DELETE FROM audit_log`.

- **Why:** the user wanted persistence so they can review activity overnight or after a long session, with bounded storage via the weekly prune. The user wrote: *"Persistent. but we want an option to clear it each week for example so it does not load the storage."*
- **Replaces in-flight scenarios:** the in-flight design says "Persistent audit logs are deferred." This correction makes it un-deferred. A new requirement block in the corrected spec adds five scenarios: an entry per successful tool call, an entry per failed tool call (status reflects the failure), the prune fires on app start, the Clear button wipes the table, and the MCP Status page shows the most recent N entries with formatted timestamps.
- **User DB substrate:** this is the **first user-writable SQLite file** in the project. The design.md should anchor that fact for downstream changes:
  - Bookmarks (future) will share `user.db` with their own table (`bookmarks`).
  - Playback history (future) will share `user.db` with its own table (`playback_history`).
  - The schema-lock + migration story starts at v1 with just the `audit_log` table. Future changes that add tables bump to v2 with an explicit migration plan, exactly as `quran-data` does for the read-only DB.
- **What stays:** the in-session "recent decisions" surface on MCP Status — but now backed by a SQL `SELECT ... ORDER BY ts_utc DESC LIMIT 20` against the persistent table rather than an in-memory ring buffer.

## Risks / Trade-offs

- **In-flight implementation work is partially discarded.** The HTTPS plumbing, certificate generation, and per-command approval flow are removed and the workspace move re-locates files. Mitigated by: the re-application branch can cherry-pick valuable parts (validation logic, DTOs, tool handlers) before re-shaping the boundary.
- **`mcp_dart` maturity is the same unknown the `add-mcp-server` design flagged.** This correction does not reduce that risk; it picks the package the user named. If `mcp_dart` proves to have blocking gaps during re-application, that's a separate revision (and it would be the same scope-of-question whether we'd picked it originally or now).
- **Workspace packages add Dart-tooling overhead.** Slight: `dart pub get` resolves the path dependency, `flutter test` runs both packages' tests transparently, but IDE setup may need an `analysis_options.yaml` per package. Documented in the re-application's docs delta.
- **The user DB is a new failure surface.** A corrupt `user.db` would lose the audit log but should NOT block app start (unlike the read-only Quran/tafsir DBs, which fail-closed). Designed: on DB-open failure, log an `appLogger.severe`, surface a Settings notice "MCP audit log unavailable: <reason>", but keep Quran reads and audio playback functional.
- **Reviewer cognitive load.** Side-by-side comparing the in-flight `add-mcp-server` spec with the corrected one is non-trivial because of the five overlapping deltas. Mitigated by: the corrected spec file at [`specs/mcp-server/spec.md`](specs/mcp-server/spec.md) names every superseded scenario with a `MODIFIES <name>` or `REMOVES <name>` marker.
- **Audit-log args_summary may leak sensitive content.** The implementation must redact or truncate user query text in `args_summary` for `search_quran` calls (e.g. first 128 chars). Documented in the re-application's tasks.

## Migration Plan

This proposal is the spec-level correction. The actual file moves and code edits happen on a follow-up branch. Order of operations:

1. **This branch (`chore/propose-mcp-server-corrections`)** — proposal + design + spec + tasks merge to `develop`. No runtime code changes.
2. **`feature/add-mcp-server`** — if its PR has not yet merged, the implementer rebases it onto the corrected develop and edits proposal/design/spec/tasks + runtime code in the same branch. If its PR has already merged, a new `chore/realign-mcp-server` branch off develop does the same edits.
3. **The re-application branch** edits:
   - `pubspec.yaml`: swap `mcp_server` → `mcp_dart: ^2.1.1`, add `packages/quran_mcp_server` workspace member.
   - File moves: `lib/data/mcp/*` → `packages/quran_mcp_server/lib/src/*`.
   - Removes: HTTPS / cert generation, per-command approval state machine.
   - Adds: HTTP listener config, three Settings toggle widgets + persistence keys, `user.db` schema initialiser, `audit_log_repository.dart`, prune-on-start hook, "Clear audit log" button.
   - Spec edits: the in-flight `openspec/changes/add-mcp-server/specs/mcp-server/spec.md` is rewritten to match this correction's scenarios. The in-flight proposal/design are revised similarly.
4. **Verification on the re-application branch:** `just check` passes, manual smoke test of an authenticated HTTP request with curl or an MCP client, scope-denied behaviour validated by toggling the playback toggle off and calling `play_ayah`.

Rollback for this correction PR: revert it. The in-flight `add-mcp-server` work continues toward its original (divergent) shape. We'd lose the alignment but keep the work.

## Open Questions

- **Should the master MCP enable be a single toggle that also implies "read-only" scope, or two toggles (`Enable MCP` + `Allow MCP read-only`)?** Recommended: one toggle (`Enable MCP`). When off, the server doesn't start and no scope is queried. When on, read-only is implicit. The two Mode B toggles are independent. Resolved here unless reviewer disagrees.
- **What's the `args_summary` redaction policy for `search_quran` queries?** Recommended: truncate at 128 chars, no other redaction (the query is whatever the user told their AI client to search; not categorically sensitive). Defer detailed PII policy to a future change if the audit log ever surfaces user-typed prompts beyond search queries.
- **Does the workspace package need its own `analysis_options.yaml` or can it inherit?** Recommended: inherit from the root via `include: package:flutter_lints/flutter.yaml`. Re-application implementer confirms during code edits.
- **Should `set_repeat`'s `repeat_mode` enum be defined in `domain/audio/` or in the workspace package?** Recommended: `domain/audio/`. The MCP package consumes it. No domain split.
- **Does the audit log capture both reads and writes, or only writes (playback commands)?** Recommended: BOTH. The user can audit "what did Claude ask the Quran corpus for?" not just "what did Claude play?" — and the audit log is the only persistent record of MCP activity. Re-application implementer confirms this scope.

## Appendix: Mapping the divergences

For the reviewer's eye:

| # | Decision               | Ratified in `/openspec-explore` | `feature/add-mcp-server` shipped | Corrected here |
|---|------------------------|---------------------------------|----------------------------------|----------------|
| 1 | Transport              | HTTP on loopback                | HTTPS + self-signed cert         | HTTP           |
| 2 | MCP package            | `mcp_dart ^2.1.1`               | `mcp_server` (different)         | `mcp_dart`     |
| 3 | Layout                 | `packages/quran_mcp_server/`    | `lib/data/mcp/` in-process       | workspace pkg  |
| 4 | Permission model       | pre-granted scope toggles       | per-command modal approval       | scope toggles  |
| 5 | Audit log              | persistent, weekly prune        | ephemeral session-only           | SQLite + prune |
