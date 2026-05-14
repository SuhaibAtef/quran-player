## ADDED Requirements

### Requirement: Local-only MCP server lifecycle

The system SHALL provide a local MCP server for approved local clients and SHALL NOT expose any remote network listener, arbitrary file access, or shell command execution capability. The server lifecycle MUST be observable as `disabled`, `starting`, `running`, `stopped`, or `failed`.

#### Scenario: Server starts in local-only mode

- **WHEN** the MCP server is started
- **THEN** it accepts only local MCP transport connections and does not bind a public TCP, UDP, WebSocket, or remote-access listener

#### Scenario: Server status is reported

- **WHEN** the server transitions between disabled, starting, running, stopped, or failed states
- **THEN** the current state is available to the app's MCP status surface

#### Scenario: Arbitrary commands are unavailable

- **WHEN** an MCP client lists tools or resources
- **THEN** no tool or resource allows arbitrary filesystem reads, writes, process spawning, or shell command execution

### Requirement: Read-only Quran tools

The MCP server SHALL expose read-only tools named `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, and `list_reciters`. Quran text and references MUST come from the same verified app repositories used by the UI.

#### Scenario: List surahs tool returns verified metadata

- **WHEN** a client calls `list_surahs`
- **THEN** the response contains exactly 114 surah entries from `QuranRepository.listSurahs()`

#### Scenario: Get ayah tool returns canonical text

- **WHEN** a client calls `get_ayah` with surah `2` and ayah `255`
- **THEN** the response contains reference `2:255` and canonical Quran text from `QuranRepository.getAyah()`

#### Scenario: Get surah tool returns bounded ayahs

- **WHEN** a client calls `get_surah` with surah `1`
- **THEN** the response contains Al-Fatihah metadata and exactly 7 canonical ayahs from the repository

#### Scenario: Search tool uses existing search contract

- **WHEN** a client calls `search_quran` with a non-empty Arabic query
- **THEN** the response contains bounded `QuranSearchResult` entries from `QuranRepository.searchAyahs()` and no generated summary text

#### Scenario: List reciters returns approved reciter metadata

- **WHEN** a client calls `list_reciters`
- **THEN** the response contains the app's approved reciter metadata and does not invent unavailable reciters

### Requirement: Quran resources

The MCP server SHALL expose resources named `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, and `quran://reciters`. Resource responses MUST be read-only snapshots from the same repositories as the tools.

#### Scenario: Metadata resource includes attribution

- **WHEN** a client reads `quran://metadata`
- **THEN** the response includes source attribution from `QuranRepository.getSource()` and does not include generated religious commentary

#### Scenario: Surahs resource lists all surahs

- **WHEN** a client reads `quran://surahs`
- **THEN** the response contains exactly 114 surah metadata entries ordered by surah number

#### Scenario: Single surah resource validates the path

- **WHEN** a client reads `quran://surah/115`
- **THEN** the server returns a structured not-found or invalid-input error and no partial Quran data

#### Scenario: Single ayah resource validates the path

- **WHEN** a client reads `quran://ayah/1/8`
- **THEN** the server returns a structured not-found or invalid-input error and no invented ayah text

#### Scenario: Reciters resource mirrors list reciters

- **WHEN** a client reads `quran://reciters`
- **THEN** the response contains the same approved reciter metadata exposed by `list_reciters`

### Requirement: Strict MCP input validation and failure mapping

The MCP server SHALL validate every tool argument and resource URI before calling repositories or playback commands. Validation, repository, permission, and player failures MUST be returned as structured MCP errors without throwing raw exceptions across the protocol boundary.

#### Scenario: Empty search query is rejected

- **WHEN** a client calls `search_quran` with an empty or whitespace-only query
- **THEN** the server returns a structured invalid-input error and does not call `QuranRepository.searchAyahs()`

#### Scenario: Out-of-range Quran reference is rejected

- **WHEN** a client calls `get_ayah` with surah `0` or ayah `0`
- **THEN** the server returns a structured invalid-input error and does not invent a reference

#### Scenario: Repository failure is mapped

- **WHEN** a repository call returns `Failure.dataIntegrity`, `Failure.notFound`, or another expected `Failure`
- **THEN** the MCP response maps it to a structured protocol error with no raw stack trace

#### Scenario: Bootstrap failure blocks all Quran reads

- **WHEN** the app bootstrap status indicates Quran or tafsir integrity failure
- **THEN** Quran tools and resources return a structured unavailable or data-integrity error instead of serving partial data

### Requirement: Playback control tools require permission

The MCP server SHALL expose playback tools named `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, and `set_repeat`. Each playback tool MUST require explicit user approval before changing player state.

#### Scenario: Play surah waits for user approval

- **WHEN** a client calls `play_surah` for surah `36`
- **THEN** the command enters a pending approval state and no playback starts until the user approves it

#### Scenario: Play ayah waits for user approval

- **WHEN** a client calls `play_ayah` for reference `2:255`
- **THEN** the command enters a pending approval state and no playback starts until the user approves it

#### Scenario: Pause command waits for user approval

- **WHEN** a client calls `pause_playback`
- **THEN** the current playback state is unchanged until the user approves the pause command

#### Scenario: Denied command does not change playback

- **WHEN** the user denies a pending playback command
- **THEN** the server returns a structured permission-denied error and the player state remains unchanged

#### Scenario: Approved command uses app player behavior

- **WHEN** the user approves a valid `play_ayah` command
- **THEN** the app resolves the ayah through existing audio/player contracts and begins playback using the same behavior as the UI

#### Scenario: App unavailable blocks playback control

- **WHEN** a playback command is received while the app/player bridge is unavailable
- **THEN** the server returns a structured app-unavailable or player-unavailable error and does not start a second independent player

### Requirement: Repeat commands stay within supported playback behavior

The MCP server SHALL validate `set_repeat` arguments against repeat modes supported by the app. Unsupported repeat modes MUST fail with structured invalid-input errors.

#### Scenario: Supported repeat mode can be approved

- **WHEN** a client calls `set_repeat` with a supported repeat mode
- **THEN** the command enters pending approval and applies only after user approval

#### Scenario: Unsupported repeat mode is rejected

- **WHEN** a client calls `set_repeat` with an unsupported mode
- **THEN** the server returns a structured invalid-input error and does not prompt for approval
