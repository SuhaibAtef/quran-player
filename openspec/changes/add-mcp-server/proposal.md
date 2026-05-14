## Why

The app now has verified Quran data, basic search, default reciter metadata, and a working audio player, but AI clients still have no trusted local surface for Quran lookups or user-approved playback control. IDEA.md defines MCP as the controlled integration layer for both accurate Quran data and safe player commands, so the server should land with read-only tools and playback controls together.

## What Changes

- Add an in-app local-only MCP server for Quran data access and playback control.
- Add MCP Status controls to start/stop the server and display the local Streamable HTTP URL plus a bearer token for local LLM/MCP clients.
- Expose the MVP tools `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, and `list_reciters`.
- Expose playback tools `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, and `set_repeat`.
- Expose the MVP resources `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, and `quran://reciters`.
- Require explicit user approval before any MCP playback command can affect player state.
- Validate every MCP input with strict schemas and return structured failures for invalid references, missing data, denied permissions, unavailable app/player state, and repository failures.
- Reuse the existing verified `QuranRepository`, audio reciter contract, and player controller seams so MCP output and playback targets cannot diverge from app behavior.
- Add app-visible MCP status for server availability, local-only mode, authenticated endpoint details, read-only tools, playback-control permission state, and recent command decisions.
- Keep remote MCP access, bookmarks over MCP, persistent audit logs, tafsir, semantic search, arbitrary file access, and shell command execution out of scope.

## Capabilities

### New Capabilities

- `mcp-server`: Local-only MCP server contract, read-only tool/resource surface, playback-control tools, permission gating, validation, lifecycle, and status behavior.

### Modified Capabilities

- `app-shell`: MCP Status stops being only a placeholder and becomes the user-visible status and permission surface for the local MCP server.
- `audio-player`: MCP playback tools become an approved non-UI entry point into existing player behavior without changing Quran text availability.

## Impact

- New server-side Dart code using the `mcp_server` Dart package for authenticated local Streamable HTTP MCP transport, tool/resource registration, and JSON DTO mapping.
- New app/domain contracts for MCP server lifecycle, permission prompts, and playback command status that can be consumed by the existing MCP Status route.
- Reuse of `lib/domain/quran/`, `lib/data/quran/`, `lib/domain/audio/`, and `lib/features/player/` controller seams without changing canonical Quran text or audio source policy.
- New `mcp_server` dependency plus focused HTTP smoke tests for missing-token rejection and authorized local tool calls.
- Tests for schema validation, repository-backed tool/resource responses, playback permission gating, failure mapping, lifecycle/status providers, and import/security boundaries.
