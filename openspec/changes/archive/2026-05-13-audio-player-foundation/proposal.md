## Why

Quran Companion is currently a trustworthy Quran reader, but it is not yet a
Quran player. Adding an API-backed audio foundation now unlocks the core product
promise while keeping the data model ready for later offline downloads, MCP
playback control, bookmarks, and search-to-play flows.

## What Changes

- Introduce a Quran audio domain model for reciters, verse audio, playback queue
  entries, and player state.
- Add an API-backed audio metadata/data layer for one approved default reciter,
  with source attribution and strict response validation.
- Add playback support for streaming verse audio from remote URLs, including
  play, pause, seek, next, and previous.
- Add an app-level mini player fixed at the bottom of the shell, visually similar
  in direction to a compact desktop music player: reciter image/artwork, current
  ayah/surah label, transport controls, and progress.
- Make the mini player expandable/clickable so the user can inspect the current
  queue and larger playback controls without adding a new top-level navigation
  destination.
- When verse-level playback data is available, surface the active ayah to the
  reader so the current ayah can be highlighted during playback.
- Preserve a future download-manager seam: the player consumes resolved playable
  URIs and metadata, so a later change can swap remote URLs for local cached
  files without rewriting playback UI.
- Record audio source and reciter attribution in the app and third-party notices.

## Capabilities

### New Capabilities

- `audio-player`: API-backed Quran audio metadata, verse playback queue,
  playback controls, bottom mini player, queue expansion, active ayah exposure,
  and attribution.

### Modified Capabilities

- None.

## Impact

- Adds new domain contracts under `lib/domain/audio/`.
- Adds new data implementation under `lib/data/audio/`, including an HTTP client
  boundary and source-specific response mapping.
- Adds new player state/controllers and UI under `lib/features/player/`.
- Updates the app shell composition so the mini player can persist across
  top-level routes.
- Updates the reader to observe active audio ayah state and highlight the active
  ayah when the current render mode supports it.
- Adds an audio playback dependency with Windows desktop support.
- Adds tests for API mapping, queue behavior, playback state transitions, shell
  mini-player rendering, expanded queue behavior, and reader highlighting.
- Updates `AGENTS.md`, `README.md`, and `THIRD_PARTY_NOTICES.md` with the audio
  architecture, source policy, and attribution.
