## ADDED Requirements

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
