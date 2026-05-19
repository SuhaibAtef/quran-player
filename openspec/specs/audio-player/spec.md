# audio-player Specification

## Purpose
Defines Quran verse-audio playback, source attribution, queue behavior, and
reader synchronization for the desktop player.
## Requirements
### Requirement: Audio source is approved before playback is enabled

The system SHALL use exactly one approved default audio source and reciter for
the first player release. The source approval MUST record the provider name,
provider URL, reciter identity, audio access method, usage terms or license,
attribution wording, and whether client authentication is required. The Flutter
client MUST NOT store API secrets or use a source that requires an embedded
client secret.

#### Scenario: Approved source metadata is available

- **WHEN** the app initializes the audio data layer
- **THEN** the default reciter and audio source attribution are available through
  domain/data contracts with non-empty provider, reciter, URL, and terms fields

#### Scenario: Source requiring client secret is rejected

- **WHEN** the candidate audio source requires a client secret to be embedded in
  the desktop app
- **THEN** audio playback is not enabled for that source and implementation must
  choose a different approved source or revise the proposal

#### Scenario: Attribution is visible in app documentation

- **WHEN** the change ships
- **THEN** `THIRD_PARTY_NOTICES.md` and a user-reachable Settings attribution row
  identify the audio provider, reciter, terms/license, and upstream URL

### Requirement: Audio domain contracts are framework-free

The system SHALL expose audio domain types and contracts under
`lib/domain/audio/` with zero dependencies on Flutter, Riverpod, HTTP, storage,
or any playback package. Boundary methods that can fail MUST return `Result<T,
Failure>` and MUST NOT throw for source, network, parsing, or playback-state
errors.

#### Scenario: Domain layer compiles without Flutter or player packages

- **WHEN** the `lib/domain/audio/` directory is compiled or scanned in isolation
- **THEN** no import resolves to `package:flutter/`, `package:flutter_riverpod/`,
  HTTP packages, storage packages, `just_audio`, `media_kit`, or any other
  playback implementation package

#### Scenario: Invalid audio input returns Failure

- **WHEN** an audio repository method receives an invalid surah, ayah, reciter
  id, or malformed source response
- **THEN** it returns the appropriate `Failure` and does not throw across the
  repository boundary

### Requirement: Verse audio is resolved through an API-backed repository

The system SHALL resolve playable verse audio through an `AudioRepository` or
equivalent domain contract. Verse audio MUST be keyed by the existing Quran
`AyahKey`, MUST map source verse identifiers to the local Quran data model, and
MUST validate that returned verse keys match the requested ayah before playback.

#### Scenario: Get audio for a known ayah

- **WHEN** audio for `AyahKey(2, 255)` is requested for the default reciter
- **THEN** the repository returns `Result.ok` with a playable remote URI, the
  same ayah key, the default reciter id, source attribution, and format metadata
  if the source provides it

#### Scenario: Source returns mismatched verse key

- **WHEN** the audio source response for `AyahKey(2, 255)` contains a different
  verse key
- **THEN** the repository returns `Failure.dataIntegrity` or
  `Failure.dataAccess` and the mismatched audio is not queued

#### Scenario: Network failure is non-fatal

- **WHEN** the audio API cannot be reached
- **THEN** audio resolution returns a recoverable failure and the Quran text
  repository, reader, and shell remain usable

### Requirement: Surah playback builds a verse queue

The system SHALL support starting playback for a surah by building an ordered
queue of verse-level audio entries for that surah and the default reciter. Queue
entries MUST preserve Quran order and MUST reference local `AyahKey` values.

#### Scenario: Start queue for Al-Fatihah

- **WHEN** the user starts playback for Surah 1
- **THEN** the player queue contains 7 entries ordered from `1:1` through `1:7`
  and the current queue item is `1:1`

#### Scenario: Start queue for invalid surah

- **WHEN** the user attempts to start playback for Surah 115
- **THEN** the queue is not replaced and a recoverable invalid-input failure is
  surfaced

#### Scenario: Queue uses remote URIs through a source abstraction

- **WHEN** a queue item is handed to the playback engine
- **THEN** the player receives a resolved playable URI and metadata, without
  depending on whether that URI is remote today or local in a future download
  manager

### Requirement: Player controls manage playback state

The system SHALL expose player state through Riverpod or an equivalent app state
layer, including idle, loading, playing, paused, buffering, completed, and error
states; current queue item; current position; duration when known; and supported
transport actions. The UI SHALL provide play, pause, seek, next, and previous
controls.

#### Scenario: Play and pause

- **WHEN** a valid queue is loaded and the user presses play
- **THEN** playback starts and state transitions to playing
- **WHEN** the user presses pause
- **THEN** playback pauses and state transitions to paused without clearing the
  queue

#### Scenario: Seek within current item

- **WHEN** the user seeks to a position within the current audio item
- **THEN** the playback engine seeks to that position and the exposed player
  state reflects the new position

#### Scenario: Next and previous

- **WHEN** the user presses next while a later queue item exists
- **THEN** the player advances to the next `AyahKey`
- **WHEN** the user presses previous while an earlier queue item exists
- **THEN** the player moves to the previous `AyahKey`

#### Scenario: Playback error does not crash app

- **WHEN** the playback engine reports a loading or decoding error
- **THEN** player state transitions to error with a brief recoverable message and
  the rest of the app remains usable

### Requirement: Bottom mini player persists across app routes

The application SHALL render a compact bottom mini player from app-level shell
composition whenever a queue is loaded. The mini player MUST show reciter
image/artwork, reciter name, current ayah or surah label, progress, and core
transport controls. It MUST NOT add a new top-level navigation destination.

#### Scenario: Mini player is hidden before playback

- **WHEN** no audio queue has been loaded in the current session
- **THEN** the app shell renders without the mini player

#### Scenario: Mini player appears after queue starts

- **WHEN** the user starts a valid surah or ayah playback queue
- **THEN** the mini player appears at the bottom of the app shell and displays
  the default reciter identity, current ayah reference, progress, and controls

#### Scenario: Mini player persists across navigation

- **WHEN** a queue is loaded and the user navigates between Home/Surahs, Search,
  Bookmarks, Settings, MCP Status, and reader routes
- **THEN** the mini player remains visible and keeps the same queue state

#### Scenario: Shell navigation is unchanged

- **WHEN** the app shell is rendered with or without an active audio queue
- **THEN** the top-level destinations remain Home/Surahs, Search, Bookmarks,
  Settings, and MCP Status, with no Player destination added

### Requirement: Mini player expands to queue controls

The mini player SHALL be clickable outside of direct transport controls and SHALL
open an expanded player/queue panel. The expanded panel MUST show the current
reciter, larger controls, current progress, and the queued ayahs with the active
item indicated.

#### Scenario: Open expanded queue

- **WHEN** the user clicks the non-control area of the mini player
- **THEN** an expanded player panel opens and shows the current queue with the
  active ayah marked

#### Scenario: Selecting a queue item

- **WHEN** the user selects a later ayah from the expanded queue
- **THEN** playback moves to that queue item and the active ayah state updates to
  the selected `AyahKey`

#### Scenario: Transport buttons do not open panel

- **WHEN** the user clicks play, pause, next, previous, or seek controls inside
  the mini player
- **THEN** the corresponding transport action runs without also opening the
  expanded panel

### Requirement: Reader highlights active playback ayah when supported

The player SHALL expose the active playback `AyahKey` to reader UI. The reader
SHALL highlight the active ayah when the visible render mode can represent that
ayah without violating the canonical text and QCF import boundaries. Text mode
MUST support active ayah highlighting. Page mode MUST support precise ayah
highlighting only if it can do so through the existing page-rendering boundary;
otherwise it MUST avoid fake or misleading ayah highlights.

#### Scenario: Text reader highlights active ayah

- **WHEN** the text reader is showing Surah 2 and playback advances to `2:255`
- **THEN** the ayah row for `2:255` is visually marked as the active playback
  ayah

#### Scenario: Highlight clears when playback stops

- **WHEN** playback is stopped or the queue is cleared
- **THEN** the reader no longer marks any ayah as the active playback ayah

#### Scenario: Page mode preserves rendering boundary

- **WHEN** page mode cannot precisely highlight an ayah through the existing
  QCF-backed rendering boundary
- **THEN** it does not render a fake ayah highlight and the QCF package import
  boundary remains unchanged

### Requirement: Audio docs and project guidance are updated

The change SHALL update project documentation to describe the audio source,
runtime network requirement for streaming, player architecture, source
attribution, and the future download-manager seam.

#### Scenario: Project docs mention audio foundation

- **WHEN** the change ships
- **THEN** `AGENTS.md` and `README.md` describe the new player foundation, chosen
  source, current limitations, and relevant commands/tests

#### Scenario: Notices include audio source

- **WHEN** the change ships
- **THEN** `THIRD_PARTY_NOTICES.md` contains the audio provider and default
  reciter attribution required by the approved source

### Requirement: MCP playback commands reuse the app player

The audio player SHALL expose a controlled non-UI command path for MCP playback tools so approved commands use the same queue resolution, reciter defaults, highlighting, and playback behavior as user actions in the app. MCP playback commands MUST NOT create a separate audio backend or bypass existing player state.

#### Scenario: Approved play surah uses existing queue behavior

- **WHEN** an approved MCP `play_surah` command targets a valid surah
- **THEN** the audio player opens the same verse playlist that the UI surah playback flow would open

#### Scenario: Approved play ayah uses existing ayah behavior

- **WHEN** an approved MCP `play_ayah` command targets a valid ayah
- **THEN** the audio player plays the resolved ayah through the existing audio repository and player engine path

#### Scenario: Approved pause resumes current app player state

- **WHEN** approved MCP `pause_playback` and `resume_playback` commands are applied
- **THEN** they affect the existing app player state exactly as the UI play/pause control would

#### Scenario: Approved stop clears or stops through the app player contract

- **WHEN** an approved MCP `stop_playback` command is applied
- **THEN** the current player state changes through the existing player controller contract without creating a second backend

#### Scenario: Unapproved playback command is ignored

- **WHEN** an MCP playback command has not been approved by the user
- **THEN** the audio player receives no state-changing command from MCP

