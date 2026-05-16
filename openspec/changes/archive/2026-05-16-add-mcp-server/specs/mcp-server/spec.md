## ADDED Requirements

> **Reviewer note:** the scenarios below describe the **shipped** shape of the `mcp-server` capability after the realignment in [`realign-mcp-server-implementation`](../../realign-mcp-server-implementation/). Five originally-proposed scenarios about per-command modal approval are explicitly REMOVED; the corrected scenarios are MODIFIED into the shipped scope-toggle shape. The cross-references to the correction's spec are kept inline so the lineage stays auditable.

### Requirement: Local-only MCP server lifecycle

The system SHALL provide an in-app local MCP server for approved local clients and SHALL NOT expose any remote network listener, arbitrary file access, or shell command execution capability. The server lifecycle MUST be observable as `disabled`, `starting`, `running`, `stopped`, or `failed`.

#### Scenario: Server starts in local-only mode

- **WHEN** the MCP server is started from the app
- **THEN** it binds only to a loopback address and does not bind a public TCP, UDP, WebSocket, or remote-access listener

#### Scenario: Server exposes plain HTTP local client details

> Originally proposed as `Server exposes authenticated HTTPS local client details`; corrected to plain HTTP per `align-mcp-server-with-explore-decisions` D1.

- **WHEN** the MCP server is running
- **THEN** the app exposes an `http://127.0.0.1:<port>/mcp` MCP URL and a per-server-start bearer token that local LLM/MCP clients can use

#### Scenario: Missing token is rejected

- **WHEN** a local client calls the HTTP MCP endpoint without the displayed bearer token in the `Authorization: Bearer <token>` header
- **THEN** the server returns a `401 Unauthorized` response and does not execute a tool or resource handler

#### Scenario: HTTP endpoint remains local

> Originally `HTTPS endpoint remains local`; TLS terminator removed.

- **WHEN** the app exposes the MCP URL
- **THEN** the HTTP listener binds only to `127.0.0.1` (never `0.0.0.0`, `::`, or any external interface) and rejects any request whose remote address is not loopback

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

The MCP server SHALL validate every tool argument and resource URI before calling repositories or playback commands. Validation, repository, scope, and player failures MUST be returned as structured MCP errors without throwing raw exceptions across the protocol boundary.

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

### Requirement: Playback control tools require playback scope

The MCP server SHALL expose playback tools named `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, and `set_repeat`. Each playback tool MUST gate on the `mcp.scope.playback` Settings toggle being ON. When the toggle is OFF, the tool returns a structured `scope_denied` MCP error and player state is unchanged. (Originally drafted as `Playback control tools require permission` with per-command modal approval; corrected to pre-granted scope toggle per `align-mcp-server-with-explore-decisions` D4. The four scenarios listed under `## REMOVED Requirements` in that correction's spec are removed from this requirement.)

#### Scenario: Play surah requires playback scope

- **WHEN** a client calls `play_surah` for surah `36` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error, no playback starts, and the player state is unchanged

#### Scenario: Play ayah requires playback scope

- **WHEN** a client calls `play_ayah` for reference `2:255` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error and no playback starts

#### Scenario: Pause command requires playback scope

- **WHEN** a client calls `pause_playback` AND the `mcp.scope.playback` toggle is OFF
- **THEN** the server returns a structured `scope_denied` MCP error and the current playback state is unchanged

#### Scenario: Scope-denied command does not change playback

- **WHEN** any Mode B tool returns `scope_denied`
- **THEN** the audio bridge is never invoked and the player state is unchanged

#### Scenario: Authorized-by-scope command uses app player behavior

- **WHEN** a client calls a valid `play_ayah` AND the `mcp.scope.playback` toggle is ON
- **THEN** the app resolves the ayah through existing audio/player contracts and begins playback using the same behavior as the UI

#### Scenario: App unavailable blocks playback control

- **WHEN** a playback command is received while the app/player bridge is unavailable
- **THEN** the server returns a structured app-unavailable or player-unavailable error and does not start a second independent player

### Requirement: Repeat commands stay within supported playback behavior

The MCP server SHALL validate `set_repeat` arguments against repeat modes supported by the app. Unsupported repeat modes MUST fail with structured invalid-input errors.

#### Scenario: Supported repeat mode is authorized by scope

> Originally `Supported repeat mode can be approved`; corrected per D4.

- **WHEN** a client calls `set_repeat` with a supported repeat mode AND the `mcp.scope.playback` toggle is ON
- **THEN** the command applies without further prompting

#### Scenario: Unsupported repeat mode is rejected

- **WHEN** a client calls `set_repeat` with an unsupported mode
- **THEN** the server returns a structured invalid-input error and does not change repeat behavior

### Requirement: Persistent audit log

The MCP server SHALL persist every tool call (Mode A and Mode B) to a SQLite `audit_log` table in a user-writable `user.db` at `path_provider.getApplicationSupportDirectory()/quran/user.db`. The log captures `tool_name`, `args_summary`, `result_status` (one of `ok`, `scope_denied`, `invalid_input`, `not_found`, `unavailable`, `error`), `scope_at_time`, and `ts_utc`. (Originally `Persistent audit logs are deferred`; un-deferred per `align-mcp-server-with-explore-decisions` D5.)

#### Scenario: Successful Mode A call is recorded

- **WHEN** a client calls `search_quran` and the handler returns successfully
- **THEN** an `audit_log` row is appended with `tool_name='search_quran'`, `result_status='ok'`, and the `args_summary` is the truncated query

#### Scenario: Failed Mode A call is recorded

- **WHEN** a client calls `get_ayah` with a malformed reference
- **THEN** an `audit_log` row is appended with `tool_name='get_ayah'` and `result_status='invalid_input'`

#### Scenario: 7-day prune fires on app start

- **WHEN** the app starts and `user.db` opens successfully
- **THEN** the prune deletes every `audit_log` row whose `ts_utc` is older than 7 days

#### Scenario: Clear button wipes the table

- **WHEN** the user taps "Clear MCP audit log" in Settings and confirms the dialog
- **THEN** every row in `audit_log` is deleted

#### Scenario: MCP Status page shows recent entries

- **WHEN** the user opens the MCP Status page
- **THEN** the page renders the most recent 20 audit_log rows ordered by `ts_utc DESC`
