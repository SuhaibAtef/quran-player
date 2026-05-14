## Context

Quran Companion already has the foundations needed for the MCP surface in IDEA.md: an integrity-checked Tanzil SQLite asset, a framework-free `QuranRepository`, Arabic text search through `searchAyahs`, one approved default reciter behind the audio domain contract, and a player controller that can play surahs/ayahs through the app shell. The shell also has a top-level MCP Status route, but it is still a placeholder.

This change turns those seams into an in-app local MCP server with two modes:

```text
Mode A: read-only Quran and reciter data
Mode B: playback control, only while the app/player is available and only after user approval
```

The server must stay trustworthy before powerful: it must never invent Quran references, never mutate the Quran corpus, never expose remote access, never run arbitrary commands, and never let an AI client control playback without a visible user decision.

Stakeholders: users who want AI clients to query local verified Quran data and drive listening sessions, maintainers who need one reusable repository/player path, reviewers who need clear safety boundaries, and future bookmark/audit MCP work that must build on a locked contract.

## Goals / Non-Goals

**Goals:**

- Ship an in-app local-only MCP server for the five read-only tools, five resources, and six playback tools named in IDEA.md.
- Let the user start/stop the server from MCP Status and copy a localhost URL plus bearer token into local LLM/MCP clients.
- Reuse existing verified domain repositories and player controller seams instead of adding parallel data or playback paths.
- Validate tool/resource inputs strictly and map all expected failures to structured MCP errors.
- Require explicit user approval before `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, or `set_repeat` can change player state.
- Surface MCP server lifecycle, local-only mode, playback permission state, and recent command decisions in the existing MCP Status screen.
- Keep the server safe to run from approved local MCP clients without arbitrary file, non-loopback listener, or shell capabilities.
- Cover the tool/resource/playback contract with automated tests and sample client-style request fixtures.

**Non-Goals:**

- Remote or non-loopback MCP access.
- Tafsir, semantic search, translations, bookmarks, or persistent audit logs over MCP.
- Any mutation of Quran text, reciter metadata, settings, bookmarks, or source attribution.
- General religious Q&A, generated explanations, or model-authored Quran references.
- Multiple reciter selection beyond listing the currently supported reciter and using existing playback defaults.
- Offline audio downloads or new audio cache behavior.

## Decisions

### Use authenticated local Streamable HTTP from inside the app

The MCP server will start inside the Flutter app from MCP Status using the `mcp_server` Dart package's Streamable HTTP transport. It will bind only to loopback (`127.0.0.1`) and require a generated bearer token. MCP Status will show the URL and token while running. No part of this change will bind a remote TCP, UDP, WebSocket, or public named-pipe listener.

Why: the user needs to use the server from local LLM/MCP clients, and playback control belongs in the running app because `media_kit` player state lives there. Loopback Streamable HTTP with a bearer token is usable by local clients while preserving IDEA.md's no-remote-access rule.

Alternative considered: stdio sidecar only. That works for some MCP clients but cannot bridge playback approvals into the running Flutter app without a second IPC layer, and it leaves the MCP Status page unable to show a usable client URL/token.

### Split read-only service from playback bridge

Implementation should add an `mcp_server` adapter that routes read-only calls to the existing MCP data service and playback calls to a small app bridge that depends on existing player commands. Tool handlers must not import Flutter widgets or build UI directly; the UI starts/stops the server and consumes lifecycle and permission state through providers.

Why: `QuranRepository` was designed for non-UI consumers, while playback needs app runtime state. Splitting the services keeps Quran data query behavior usable even when playback is unavailable, and makes denial/unavailable errors explicit.

Alternative considered: implement all handlers directly in the MCP Status feature. That is quicker but couples protocol behavior to widgets and makes it hard to test command semantics without UI.

### Reuse existing repositories, player commands, and explicit DTOs

`list_surahs`, `get_surah`, `get_ayah`, and `search_quran` will call `QuranRepository`; `list_reciters` will call the audio reciter metadata contract. `play_surah` and `play_ayah` will resolve validated Quran references through the same audio repository/controller path as the UI. MCP responses will be explicit JSON maps shaped for stable client consumption, not raw Dart object serialization.

Why: the server must return exactly the same canonical Quran text and control exactly the same playback targets as the app. Explicit DTOs avoid leaking internal fields or package-specific serialization quirks into the MCP contract.

Alternative considered: query SQLite directly and instantiate `media_kit` playback from the server. That would bypass app bootstrap/player state and risks a second, divergent player.

### Gate every playback command with user approval

Playback tools will enter a pending approval state before changing playback. The MCP Status screen will show the requested command, reference/range, reciter/default behavior, and client identity if available. The user can approve or deny; denial returns a structured MCP error and no player state changes. Approval should be per command in this change, not a long-lived blanket grant.

Why: IDEA.md is explicit that playback commands must require user permission. Per-command approval is conservative and avoids silently granting broad remote control over listening.

Alternative considered: a global "allow playback control" toggle. That is simpler but too broad for the first MCP control surface and makes accidental commands more likely.

### Fail closed on bootstrap and validation

The server will run the same Quran and tafsir bootstrap gates that the app shell uses before serving Quran data. Invalid references, malformed resource URIs, empty search queries, oversized limits, unsupported repeat modes, unavailable app/player state, denied permissions, and repository/player failures will return structured MCP errors rather than partial data or silent no-ops.

Why: IDEA.md requires consistent MCP output with app database output and fail-closed data integrity. Reusing bootstrap behavior keeps a tampered asset from being served or played through MCP when the UI would refuse to run.

Alternative considered: allow per-call repository errors without a server-level bootstrap gate. That gives more granular errors but risks exposing partial behavior before integrity is known.

### Keep lifecycle and status user-visible

The MCP Status page will show server state (`disabled`, `starting`, `running`, `stopped`, `failed`), local-only transport, exposed tools/resources, playback permission state, pending command details, and recent command decisions for the current session. Persistent audit logs are deferred.

Why: users need to understand both availability and control. A playback prompt with recent in-session decisions gives immediate safety feedback without committing to the fuller V1 audit-log feature.

Alternative considered: leave MCP Status as a simple enabled/disabled display. That hides the most important safety behavior: who asked to control playback and what happened.

## Risks / Trade-offs

- MCP package maturity changes quickly -> Keep protocol dependency isolated behind a tiny adapter and evaluate the current Dart MCP ecosystem during implementation before adding a package.
- Client expectations differ by MCP version -> Add request/response fixture tests for initialization, tool listing, resource listing, and every read/playback operation.
- Playback bridge needs app runtime state -> Return an explicit `app_unavailable` or `player_unavailable` error when the app is not running or cannot accept commands.
- Approval prompts can deadlock MCP clients -> Define a bounded pending state and return a timeout/denied error if the user does not approve in time.
- Local ports can collide -> Bind to loopback on a preferred port with fallback/random local ports and display the actual URL in MCP Status.
- Token exposure in UI is sensitive -> Generate a fresh high-entropy token per server start and show it only while running.
- Large `get_surah` responses may be heavy -> Return full surahs because they are bounded, but do not stream generated summaries.
- Search queries can contain FTS syntax or hostile input -> Continue relying on `QuranRepository.searchAyahs` normalization/escaping and add MCP-level schema bounds before calling it.
- Status page could imply the server is remotely discoverable -> Copy and labels must say local-only mode and must not mention remote access.

## Migration Plan

1. Add the MCP data service, DTOs, validation, and authenticated local `mcp_server` adapter behind tests.
2. Add the playback bridge, permission state model, and player command handlers behind tests.
3. Replace the MCP Status placeholder with lifecycle, capability, and approval UI.
4. Add Justfile/dev documentation and a local client smoke test for the loopback URL/token workflow.
5. Keep existing app behavior unchanged when the server is disabled, not launched, or when playback commands are denied.

Rollback is straightforward: remove the in-app HTTP adapter, MCP service/providers, playback bridge, status UI wiring, and dependency/Justfile additions. The Quran, tafsir, search, and audio repository contracts remain valid without MCP.

## Open Questions

- Should packaged Windows builds auto-start the local server? Recommended for MVP: no, require the user to press Start in MCP Status so token visibility and consent are explicit.
- What timeout should apply to pending playback approval? Recommended for MVP: short enough to avoid hanging clients, long enough for a user to review the prompt, with an explicit timeout error.
- Should `get_surah` return every ayah by default, or require a caller-provided include flag? Recommended for MVP: return the full surah because IDEA.md names `get_surah` as a read-only data tool and surahs are bounded.
