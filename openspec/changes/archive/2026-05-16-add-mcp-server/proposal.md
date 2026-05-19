## Why

The app now has verified Quran data, basic search, default reciter metadata, and a working audio player, but AI clients still have no trusted local surface for Quran lookups or playback control. IDEA.md defines MCP as the controlled integration layer for both accurate Quran data and safe player commands, so the server should land with read-only tools and playback controls together.

> **Note for reviewers:** this proposal as originally drafted (and as initially implemented in PR #20) diverged from the architecture ratified during `/openspec-explore` on five points. The correction is captured in [`align-mcp-server-with-explore-decisions`](../align-mcp-server-with-explore-decisions/) (PR #21, spec-only) and the implementation re-alignment in [`realign-mcp-server-implementation`](../realign-mcp-server-implementation/). The five items below have been edited to describe the **shipped** shape after re-alignment, not the divergent shape originally proposed.

## What Changes

- Add an in-app local-only MCP server for Quran data access and playback control.
- Add MCP Status controls to start/stop the server and display the local **HTTP** URL `http://127.0.0.1:<port>/mcp` plus a per-server-start bearer token for local LLM/MCP clients. (Loopback HTTP + bearer is the auth boundary; HTTPS adds cert-trust friction without security gain.)
- Expose the MVP tools `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, and `list_reciters`.
- Expose playback tools `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, and `set_repeat`.
- Expose the MVP resources `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, and `quran://reciters`.
- Gate Mode B (playback) commands on **pre-granted scope toggles** in Settings (`Allow MCP playback control` default OFF), not per-command modal approval. Scope-denied calls return a structured `scope_denied` MCP error.
- Validate every MCP input with strict schemas and return structured failures for invalid references, missing data, scope-denied calls, unavailable app/player state, and repository failures.
- Reuse the existing verified `QuranRepository`, audio reciter contract, and player controller seams so MCP output and playback targets cannot diverge from app behavior. Tools/resources consume these via constructor-injected adapter ports defined inside the workspace package.
- Add a **persistent audit log** in a new user-writable SQLite file (`user.db`) under `path_provider.getApplicationSupportDirectory()/quran/`, with one `audit_log` table at schema v1 and a 7-day prune that runs on app start. The log captures both Mode A reads and Mode B writes.
- Add app-visible MCP status: lifecycle, local-only transport, authenticated endpoint details, exposed tools/resources, active scopes, and the most recent 20 audit-log rows.
- Live in a Dart workspace member at `packages/quran_mcp_server/`. The Flutter app declares the package as a workspace member and depends on it via path. The package is Flutter-free; the host app provides adapters that bridge `QuranRepository` / `AudioRepository` / `AudioPlayerController` into the package's port interfaces.
- Use the **`mcp_dart`** package (`^2.1.1`) for the MCP protocol surface, behind a thin adapter (`packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart`) that is the only file allowed to import it.
- Keep remote MCP access, bookmarks over MCP, tafsir, semantic search, arbitrary file access, and shell command execution out of scope.

## Capabilities

### New Capabilities

- `mcp-server`: Local-only MCP server contract, read-only tool/resource surface, playback-control tools, scope-toggle gating, validation, lifecycle, persistent audit log, and status behavior.

### Modified Capabilities

- `app-shell`: MCP Status stops being only a placeholder and becomes the user-visible status surface (no Approve/Deny widgets). Settings gains the three MCP toggles and the Clear-audit button.
- `audio-player`: MCP playback tools become a scope-gated non-UI entry point into existing player behavior without changing Quran text availability.

## Impact

- Workspace package `packages/quran_mcp_server/` (new). Pure Dart, no Flutter / Riverpod / SharedPreferences imports — enforced by `test/isolation_test.dart`.
- Dependency: `mcp_dart: ^2.1.1` (in the package's pubspec, not the root). Replaces the originally-proposed `mcp_server` package; the self-signed-cert generator (`basic_utils`) is no longer needed.
- New user-writable SQLite file at `path_provider.getApplicationSupportDirectory()/quran/user.db`. The first such file in the project; uniquely fail-soft on open failure (Quran reads + audio playback continue, Settings shows a non-fatal notice).
- New host adapters in `lib/data/mcp/` (`host_quran_data_adapter.dart`, `host_audio_adapter.dart`) plus `mcp_dtos.dart` for the DTO mapping and `mcp_error_mapper.dart` for the `Failure` → `McpError` boundary.
- New host providers in `lib/app/state/` (`mcp_settings_provider.dart`, `mcp_server_provider.dart`, `user_db_provider.dart`).
- New Settings section in `lib/features/settings/settings_page.dart` with master Enable + playback + bookmark toggles and the Clear MCP audit log button.
- Rewritten `lib/features/mcp_status/mcp_status_page.dart` (no Approve/Deny; shows scopes + audit list).
- Tests: workspace package's own `test/audit/`, `test/scopes/`, `test/isolation_test.dart`, plus host-side `test/data/user_db/user_db_graceful_degrade_test.dart`, `test/workspace_member_test.dart`, and the rewritten MCP Status widget test. Spec mcp-server R1–R7 each have at least one passing test.
