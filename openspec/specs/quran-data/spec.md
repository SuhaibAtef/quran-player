# quran-data Specification

## Purpose
TBD - created by archiving change quran-data-layer. Update Purpose after archive.
## Requirements
### Requirement: Canonical Quran source vendoring

The system SHALL bundle exactly one canonical Quran text source — Tanzil Uthmani plain text — and SHALL record its name, edition, version, upstream URL, license, and retrieval timestamp in a committed manifest. The bundled text MUST NOT be modified, edited, or augmented at any layer (build tool, runtime, UI). Adding additional editions or scripts is out of scope and MUST be a separate change.

#### Scenario: Source attribution is recorded in the manifest

- **WHEN** the build tool produces `assets/quran/quran.sqlite` and `assets/quran/manifest.json`
- **THEN** `manifest.json` contains a `source` object with `name`, `edition`, `version`, `url`, `license`, and `retrievedAtUtc` fields, all non-empty

#### Scenario: Source is preserved byte-for-byte

- **WHEN** the build tool downloads the upstream Tanzil archive
- **THEN** it computes a SHA-256 of the raw text payload, stores it as `meta.text_sha256` in the DB and as `manifest.checksums.textSha256`, and refuses to emit output if either is empty

#### Scenario: Maintainer reproducibility

- **WHEN** a maintainer runs the build tool twice with the same pinned source version on the same platform
- **THEN** the produced `quran.sqlite` byte content and `manifest.checksums.dbSha256` are identical

### Requirement: Bundled SQLite asset and schema lock

The application SHALL ship a pre-built SQLite database as a Flutter asset at `assets/quran/quran.sqlite` containing the locked v1 schema (`meta`, `surahs`, `ayahs`, `ayah_fts`). The schema version MUST be recorded in `meta.schema_version`. Schema migrations are out of scope for this capability — any future schema change MUST land as a new version with an explicit migration plan.

#### Scenario: Schema v1 is present

- **WHEN** the app opens the bundled DB
- **THEN** the DB contains tables `meta`, `surahs`, `ayahs`, and the FTS5 virtual table `ayah_fts`, and `meta.schema_version` equals `'1'`

#### Scenario: App refuses to run on unknown schema version

- **WHEN** the app opens a DB whose `meta.schema_version` is missing or not `'1'`
- **THEN** the integrity check returns `Failure.dataIntegrity` and the app surfaces a fatal error screen

### Requirement: Runtime integrity verification fails closed

On first launch and after every app upgrade, the application SHALL verify the bundled Quran data against the manifest. The check MUST validate: schema version, surah count (114), ayah count (6,236), absence of duplicate `(surah, ayah)` rows, presence of all 114 surahs by number, and that the database SHA-256 matches `manifest.checksums.dbSha256`. Any mismatch MUST prevent the app from serving Quran data; the system MUST NOT fall back to a partial or alternate source.

#### Scenario: Healthy bundled DB passes verification

- **WHEN** the app opens the unmodified bundled DB and manifest
- **THEN** the integrity check returns `Result.ok` and Quran reads are enabled

#### Scenario: Tampered DB trips integrity check

- **WHEN** the bundled DB has been modified after build (e.g., a row deleted or text altered)
- **THEN** the computed `dbSha256` no longer matches `manifest.checksums.dbSha256`, the integrity check returns `Failure.dataIntegrity`, and Quran reads are disabled

#### Scenario: Surah count mismatch

- **WHEN** the bundled DB does not contain exactly 114 rows in `surahs` keyed 1..114
- **THEN** the integrity check returns `Failure.dataIntegrity` with a message naming the missing or extra surah numbers

#### Scenario: Ayah total mismatch

- **WHEN** `SELECT COUNT(*) FROM ayahs` does not equal 6,236
- **THEN** the integrity check returns `Failure.dataIntegrity`

#### Scenario: Duplicate ayah keys

- **WHEN** the DB contains more than one row sharing the same `(surah, ayah)` primary key (which would imply schema corruption rather than a normal write)
- **THEN** the integrity check returns `Failure.dataIntegrity`

#### Scenario: Integrity check is cached across launches

- **WHEN** integrity verification has succeeded for the current install on a previous launch and neither the bundled asset nor the install signature has changed
- **THEN** the SHA-256 hashing step is skipped on subsequent launches, but the cheap structural checks (schema version, counts) still run

### Requirement: Framework-free domain layer

The system SHALL expose Quran data through a domain layer under `lib/domain/quran/` that has zero dependencies on Flutter, Riverpod, or any storage package. Domain types MUST include `Surah`, `Ayah`, `AyahKey`, and `QuranSource`, and MUST be safe to use from non-UI contexts (tests, the future MCP server).

#### Scenario: Domain layer compiles without Flutter

- **WHEN** the `lib/domain/quran/` directory is compiled in isolation
- **THEN** no import resolves to `package:flutter/`, `package:flutter_riverpod/`, `package:sqflite/`, or `package:sqflite_common_ffi/`

#### Scenario: AyahKey round-trips through its string form

- **WHEN** an `AyahKey` is constructed with surah=2, ayah=255 and converted via `toString()`
- **THEN** the result is `"2:255"` and `AyahKey.parse("2:255")` returns an equal value

#### Scenario: AyahKey rejects out-of-range values

- **WHEN** `AyahKey.parse` receives `"0:1"`, `"115:1"`, `"2:0"`, or a malformed string
- **THEN** it returns a `Failure.invalidInput` rather than throwing

### Requirement: QuranRepository contract

The system SHALL expose an `abstract class QuranRepository` with the following methods, each returning `Future<Result<T, Failure>>`:

- `listSurahs()` → `List<Surah>`
- `getSurah(int number)` → `Surah` (with metadata only, no ayah list)
- `getSurahAyahs(int number)` → `List<Ayah>`
- `getAyah(AyahKey key)` → `Ayah`
- `getSource()` → `QuranSource`

The contract MUST NOT throw across its boundary; programmer errors are the only allowed exceptions. The same contract MUST be reusable by a future MCP server implementation without modification.

#### Scenario: List all surahs

- **WHEN** `listSurahs()` is called against a healthy repository
- **THEN** it returns `Result.ok` with exactly 114 `Surah` entries ordered by `number`

#### Scenario: Get a known surah

- **WHEN** `getSurah(1)` is called
- **THEN** it returns `Result.ok` with `Surah(number: 1, nameLatin: "Al-Fatihah", ayahCount: 7, revelation: 'meccan', ...)`

#### Scenario: Get a known ayah

- **WHEN** `getAyah(AyahKey(2, 255))` is called
- **THEN** it returns `Result.ok` with an `Ayah` whose `key` equals `AyahKey(2, 255)` and whose `text` is non-empty

#### Scenario: Unknown surah number

- **WHEN** `getSurah(115)` is called
- **THEN** it returns `Failure.notFound` and does not throw

#### Scenario: Unknown ayah within a surah

- **WHEN** `getAyah(AyahKey(1, 8))` is called (Al-Fatihah has 7 ayahs)
- **THEN** it returns `Failure.notFound` and does not throw

#### Scenario: Source attribution is reachable through the repository

- **WHEN** `getSource()` is called
- **THEN** it returns `Result.ok` with a `QuranSource` whose `name`, `version`, `url`, and `license` match the bundled manifest

### Requirement: Read-only runtime access with no network

The Quran repository implementation SHALL open the bundled SQLite database in read-only mode and SHALL NOT make any network call as part of serving Quran data at runtime. Any download or generation of Quran data MUST occur only inside the maintainer build tool under `tool/`.

#### Scenario: Database is opened read-only

- **WHEN** the SQLite-backed repository opens the database
- **THEN** it passes options that mark the connection read-only, and any attempted write returns a SQLite read-only error rather than corrupting the asset

#### Scenario: No runtime network access for Quran data

- **WHEN** the app starts and serves any number of repository calls
- **THEN** no HTTP, WebSocket, or other network call is made by code under `lib/data/quran/` or `lib/domain/quran/`

### Requirement: Source attribution is surfaced in the app

The application SHALL surface the bundled Quran source attribution (name, edition, version, license, and upstream URL) somewhere reachable from the main UI. The MVP placement is the Settings page; the wording MUST credit the source per its license terms.

#### Scenario: Attribution is reachable from Settings

- **WHEN** the user navigates to the Settings page
- **THEN** a "Quran source" section displays the source name, edition, version, license summary, and a non-clickable URL string

#### Scenario: Attribution data comes from the repository

- **WHEN** the Settings UI renders the attribution
- **THEN** the values are obtained via `QuranRepository.getSource()` and not hard-coded in the UI layer

### Requirement: Maintainer build tool

The system SHALL include a maintainer-run Dart CLI at `tool/build_quran_db.dart` that downloads the pinned Tanzil source, verifies its SHA-256 against a pinned hash, builds `assets/quran/quran.sqlite`, and writes `assets/quran/manifest.json`. The tool MUST be exposed as a `just` recipe and MUST refuse to emit output when any precondition fails (missing license file, hash mismatch, count mismatch).

#### Scenario: Build tool refuses on upstream hash mismatch

- **WHEN** the downloaded Tanzil archive's SHA-256 does not equal the pinned expected hash
- **THEN** the tool exits with a non-zero status and writes no output files

#### Scenario: Build tool emits both DB and manifest atomically

- **WHEN** the tool completes successfully
- **THEN** both `quran.sqlite` and `manifest.json` exist in the output directory and reference the same `textSha256`

#### Scenario: Build tool dependencies do not ship with the app

- **WHEN** `flutter build windows` is run on the project
- **THEN** none of `http`, `archive`, `crypto` (build-time), or `sqlite3` (build-time) appear in the runtime app's dep graph (they are confined to `dev_dependencies` and `tool/`)

### Requirement: Riverpod exposure of the repository

The system SHALL expose the `QuranRepository` to the rest of the app through a Riverpod provider, and SHALL run the integrity check exactly once per app launch. The integrity check MUST run before any UI consumer is allowed to call repository read methods.

#### Scenario: Repository is available via Riverpod

- **WHEN** any feature reads `quranRepositoryProvider`
- **THEN** it receives a fully initialized `QuranRepository` instance backed by the bundled SQLite asset

#### Scenario: Integrity check runs once per launch

- **WHEN** the app boots
- **THEN** the integrity check runs exactly once, its result is cached in a Riverpod provider, and subsequent reads of the integrity status do not re-hash the DB

#### Scenario: Failed integrity check blocks the UI

- **WHEN** the integrity check returns `Failure.dataIntegrity`
- **THEN** the router shows a fatal error screen instead of the normal app shell, and no Quran reads are served

### Requirement: Surahs page is wired to real data

The existing Surahs placeholder page SHALL be replaced with a list rendered from `QuranRepository.listSurahs()`. The page MUST render all 114 surahs with their number, Arabic name, and Latin name. UI polish (typography, motion, search-within-list) is out of scope for this change — only the data wiring must be in place.

#### Scenario: Surahs list renders 114 entries

- **WHEN** the user opens the Surahs page on a healthy install
- **THEN** the list contains 114 items, each showing the surah number, Arabic name, and Latin name

#### Scenario: Surahs page handles a loading state

- **WHEN** the repository is still initializing
- **THEN** the page shows a non-error loading indicator (a ForUI-styled progress widget) and does not flash empty content

#### Scenario: Surahs page handles a failure state

- **WHEN** the repository returns a failure (e.g., integrity not yet checked, or DB open failed)
- **THEN** the page shows an error state with a brief message and does not render a partial list

### Requirement: QuranRepository supports basic ayah search

The `QuranRepository` contract SHALL expose a read-only basic search method that accepts a plain text query and returns bounded `QuranSearchResult` entries from the bundled Quran corpus. The method MUST return `Result<T>` rather than throwing for invalid input, storage failures, or query parsing failures. Search result text MUST come from canonical `ayahs.text`, not from a secondary source or generated summary.

#### Scenario: Search returns canonical ayah results

- **WHEN** `searchAyahs("الله")` is called against a healthy repository
- **THEN** it returns `Result.ok` with one or more `QuranSearchResult` entries whose `key` values identify real ayahs and whose `text` values are non-empty canonical Quran text

#### Scenario: Search results include surah display metadata

- **WHEN** a search returns ayah `2:255`
- **THEN** the corresponding result includes the ayah key, canonical ayah text, Arabic surah name, and Latin surah name without requiring the caller to perform additional surah lookups

#### Scenario: Empty query is rejected

- **WHEN** `searchAyahs("")` or `searchAyahs("   ")` is called
- **THEN** it returns `Failure.invalidInput` and does not query the database

#### Scenario: Result count is bounded

- **WHEN** `searchAyahs` is called with a query that matches more rows than the configured limit
- **THEN** it returns no more than that limit and does not stream an unbounded result set

#### Scenario: Malformed search syntax does not escape the repository boundary

- **WHEN** `searchAyahs` receives user text containing punctuation or characters that SQLite FTS could otherwise interpret as query syntax
- **THEN** the repository returns either safe search results or a `Failure.invalidInput`, and no raw SQLite exception escapes the repository boundary

#### Scenario: Search uses the bundled read-only corpus

- **WHEN** `searchAyahs` serves any query at runtime
- **THEN** it reads from the existing bundled SQLite database and performs no network request

