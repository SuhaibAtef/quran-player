## Context

Quran Companion already had the foundations needed for the MCP surface in IDEA.md: an integrity-checked Tanzil SQLite asset, a framework-free `QuranRepository`, Arabic text search through `searchAyahs`, one approved default reciter behind the audio domain contract, and a player controller that can play surahs/ayahs through the app shell. The shell also has a top-level MCP Status route, originally a placeholder.

This change turns those seams into an in-app local MCP server with two modes:

```text
Mode A: read-only Quran and reciter data
Mode B: playback control, only when the corresponding scope is granted in Settings
```

The server stays trustworthy before powerful: it never invents Quran references, never mutates the Quran corpus, never exposes remote access, never runs arbitrary commands.

> **Note for reviewers:** this design's *Decisions* section originally diverged from the architecture ratified during `/openspec-explore` on five points (transport, package, layout, permission model, audit log). The corrected decisions live in:
>
> - [`align-mcp-server-with-explore-decisions/design.md`](../align-mcp-server-with-explore-decisions/design.md) — Decisions D1–D5 (the *what* and *why* of each correction)
> - [`realign-mcp-server-implementation/design.md`](../realign-mcp-server-implementation/design.md) — Decisions I1–I8 (the implementation choices that fall out of D1–D5: workspace layout, mcp_dart adapter, scope-check wiring, user.db lifecycle, audit-write strategy, MCP Status rewrite, test strategy, in-flight artifact reconciliation order)
>
> Reviewers comparing the shipped code against this proposal should read those two design docs as the source of truth for the *Decisions* the original draft of this section got wrong.

Stakeholders: users who want AI clients to query local verified Quran data and drive listening sessions, maintainers who need one reusable repository/player path, reviewers who need clear safety boundaries, and future bookmark/audit MCP work that builds on a locked contract.

## Goals / Non-Goals

**Goals:**

- Ship an in-app local-only MCP server for the five read-only tools, five resources, and six playback tools named in IDEA.md.
- Let the user start/stop the server from MCP Status and copy an `http://127.0.0.1:<port>/mcp` URL plus bearer token into local LLM/MCP clients.
- Reuse existing verified domain repositories and player controller seams instead of adding parallel data or playback paths.
- Validate tool/resource inputs strictly and map all expected failures to structured MCP errors.
- Gate `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, and `set_repeat` on a pre-granted **playback scope** in Settings (default OFF). Scope-denied calls return a structured `scope_denied` MCP error and never change player state.
- Surface MCP server lifecycle, local-only mode, active scopes, exposed tools/resources, and the most recent 20 audit-log rows in the existing MCP Status screen.
- Persist every tool call (Mode A and Mode B) to a `user.db` `audit_log` table; prune rows older than 7 days at app start; expose a Clear button in Settings.
- Keep the server safe to run from approved local MCP clients without arbitrary file, non-loopback listener, or shell capabilities.
- Cover the tool/resource/playback contract with automated tests in the workspace package + host-app integration tests.

**Non-Goals:**

- Remote or non-loopback MCP access.
- Tafsir, semantic search, translations, or bookmarks over MCP.
- Any mutation of Quran text, reciter metadata, settings, bookmarks, or source attribution.
- General religious Q&A, generated explanations, or model-authored Quran references.
- Multiple reciter selection beyond listing the currently supported reciter and using existing playback defaults.
- Offline audio downloads or new audio cache behavior.

## Decisions

> **The five primary decisions for this capability live in the two follow-up changes:**
>
> | # | Decision         | Source |
> |---|------------------|--------|
> | D1 | Transport: plain HTTP on `127.0.0.1` | [align-mcp-server-with-explore-decisions/design.md § D1](../align-mcp-server-with-explore-decisions/design.md) |
> | D2 | MCP package: `mcp_dart ^2.1.1` behind a thin adapter | [align-mcp-server-with-explore-decisions/design.md § D2](../align-mcp-server-with-explore-decisions/design.md) |
> | D3 | Layout: `packages/quran_mcp_server/` workspace member | [align-mcp-server-with-explore-decisions/design.md § D3](../align-mcp-server-with-explore-decisions/design.md) |
> | D4 | Permission model: pre-granted scope toggles (no per-command modal approval) | [align-mcp-server-with-explore-decisions/design.md § D4](../align-mcp-server-with-explore-decisions/design.md) |
> | D5 | Audit log: persistent SQLite (`user.db`), 7-day prune at app start | [align-mcp-server-with-explore-decisions/design.md § D5](../align-mcp-server-with-explore-decisions/design.md) |
>
> **Implementation-level choices** (workspace layout, adapter shape, scope-check wiring, user.db lifecycle, audit-write strategy, MCP Status rewrite, test strategy) are documented in [realign-mcp-server-implementation/design.md § I1–I8](../realign-mcp-server-implementation/design.md).

### Reuse existing repositories, player commands, and explicit DTOs

`list_surahs`, `get_surah`, `get_ayah`, and `search_quran` call `QuranRepository`; `list_reciters` calls the audio reciter metadata contract. `play_surah` and `play_ayah` resolve validated Quran references through the same audio repository / controller path as the UI. MCP responses are explicit JSON maps shaped for stable client consumption, not raw Dart object serialization.

The host app implements two adapter classes (`HostQuranDataAdapter`, `HostAudioAdapter`) that wrap these repositories behind the workspace package's port interfaces (`McpQuranDataPort`, `McpAudioPort`). The package never sees host-side `Failure` types or `Result` — the adapters do the boundary mapping at construction.

Why: the server must return exactly the same canonical Quran text and control exactly the same playback targets as the app. Explicit DTOs avoid leaking internal fields. The port pattern keeps the package Flutter-free without duplicating data-layer code.

### Fail closed on bootstrap and validation; user.db is the only fail-soft surface

The server runs the same Quran and tafsir bootstrap gates the app shell uses before serving Quran data. Invalid references, malformed resource URIs, empty search queries, oversized limits, unsupported repeat modes, unavailable app/player state, scope-denied calls, and repository/player failures all return structured MCP errors rather than partial data or silent no-ops.

The new `user.db` is the *only* SQLite file in the project that does NOT fail-closed on open failure: the audit log is forensically valuable but not data-correctness-critical. Quran reads and audio playback continue if `user.db` is unavailable, with a non-fatal notice in Settings.

### Keep lifecycle and status user-visible

The MCP Status page shows server state (`disabled`, `starting`, `running`, `stopped`, `failed`), local-only transport, base URL, bearer token, exposed tools/resources, **active scopes** (live from Settings), and the **most recent 20 audit-log rows** read from `user.db`.

Settings exposes the master `Enable MCP` toggle, the `Allow MCP playback control` toggle (default OFF), the `Allow MCP bookmark access` toggle (default OFF, reserved for future bookmarks), and a `Clear MCP audit log` button with Confirm/Cancel dialog.

## Risks / Trade-offs

- `mcp_dart` maturity changes quickly → Keep protocol dependency isolated behind the adapter (`packages/quran_mcp_server/lib/src/adapter/mcp_dart_adapter.dart`); a future package swap is bounded to that file.
- Client expectations differ by MCP version → The package owns its own `HttpServer.bind` so the bearer-token gate and loopback check run before mcp_dart sees a request. Per-tool dispatcher tests cover the contract independent of mcp_dart's protocol shape.
- Local ports can collide → Bind to loopback on a preferred port with the OS-assigned fallback (`port=0`); MCP Status displays the actual URL.
- Token exposure in UI is sensitive → Generate a fresh high-entropy token per server start; show only while running.
- `args_summary` for `search_quran` could leak query content → Truncate at 128 codepoints with a `…[+N more]` marker before persisting (spec mcp-server R7).
- Status page could imply remote discoverability → Copy and labels say loopback-only; never mention remote access.
- A corrupt `user.db` would lose the audit log → Open is fail-soft; Quran/audio still work; Settings shows a non-fatal notice.

## Migration Plan

1. Add the workspace package + isolation test scaffolding.
2. Add the `user.db` foundation (schema v1, audit log, prune, graceful-degrade test).
3. Build the new server in the package (scopes, ports, dispatcher, mcp_dart adapter, HTTP listener) with full unit-test coverage for spec R1–R7.
4. Add host adapters and Settings UI; rewrite MCP Status; delete the divergent code.
5. Reconcile the originally-proposed artifacts (this proposal, design, spec, tasks) against what shipped.
6. Verify: `just check` clean, manual curl smoke tests, scope-denied tests, persistent-audit smoke test.

Rollback: revert the realignment PR. The divergent code returns. `user.db` is at `getApplicationSupportDirectory()/quran/user.db` and is independent of the bundled assets — no data loss.
