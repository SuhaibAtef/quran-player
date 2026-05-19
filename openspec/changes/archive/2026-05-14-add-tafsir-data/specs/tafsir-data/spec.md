## ADDED Requirements

### Requirement: Canonical tafsir source vendoring

The system SHALL bundle exactly one canonical tafsir text source — al-Muyassar (King Fahd Complex for the Printing of the Holy Quran) — and SHALL record its name, publisher, version, upstream URL, license, and retrieval timestamp in a committed manifest. The bundled text MUST NOT be modified, edited, or augmented at any layer (build tool, runtime, UI). Adding additional tafsir sources is out of scope and MUST be a separate change.

#### Scenario: Source attribution is recorded in the manifest

- **WHEN** the build tool produces `assets/tafsir/muyassar.sqlite` and `assets/tafsir/manifest.json`
- **THEN** `manifest.json` contains a `source` object with `name`, `publisher`, `version`, `url`, `license`, and `retrievedAtUtc` fields, all non-empty

#### Scenario: Source is preserved byte-for-byte

- **WHEN** the build tool downloads the upstream al-Muyassar archive
- **THEN** it computes a SHA-256 of the raw text payload, stores it as `meta.text_sha256` in the DB and as `manifest.checksums.textSha256`, and refuses to emit output if either is empty

#### Scenario: Maintainer reproducibility

- **WHEN** a maintainer runs `tool/build_tafsir_db.dart` twice with the same pinned source version on the same platform
- **THEN** the produced `muyassar.sqlite` byte content and `manifest.checksums.dbSha256` are identical

### Requirement: Bundled tafsir SQLite asset and schema lock

The application SHALL ship a pre-built SQLite database as a Flutter asset at `assets/tafsir/muyassar.sqlite` containing the locked v1 schema (`meta`, `tafsir`). The schema version MUST be recorded in `meta.schema_version`. Schema migrations are out of scope for this capability — any future schema change (including adding FTS5 over tafsir text) MUST land as a new version with an explicit migration plan.

#### Scenario: Schema v1 is present

- **WHEN** the app opens the bundled tafsir DB
- **THEN** the DB contains tables `meta` and `tafsir`, the `tafsir` table has a primary key on `(surah, ayah)`, and `meta.schema_version` equals `'1'`

#### Scenario: App refuses to run on unknown schema version

- **WHEN** the app opens a tafsir DB whose `meta.schema_version` is missing or not `'1'`
- **THEN** the integrity check returns `Failure.dataIntegrity` and the app surfaces a fatal error screen

#### Scenario: Tafsir DB is a separate file from the Quran DB

- **WHEN** the maintainer build tools have run
- **THEN** `assets/quran/quran.sqlite` and `assets/tafsir/muyassar.sqlite` exist as distinct files with distinct sibling manifests (`assets/quran/manifest.json` and `assets/tafsir/manifest.json`), and neither manifest references the other's checksums

### Requirement: Runtime tafsir integrity verification fails closed

On first launch and after every app upgrade, the application SHALL verify the bundled tafsir data against its manifest. The check MUST validate: schema version, total row count in `tafsir`, that every `(surah, ayah)` row references a valid `(surah, ayah)` pair that exists in the bundled Quran DB, and that the database SHA-256 matches `manifest.checksums.dbSha256`. Any mismatch MUST prevent the app from serving tafsir data and MUST trip the same fatal error screen used by the Quran integrity check; the system MUST NOT fall back to a partial or alternate source.

#### Scenario: Healthy bundled tafsir DB passes verification

- **WHEN** the app opens the unmodified bundled tafsir DB and manifest
- **THEN** the tafsir integrity check returns `Result.ok` and tafsir reads are enabled

#### Scenario: Tampered tafsir DB trips integrity check

- **WHEN** the bundled tafsir DB has been modified after build (e.g., a row deleted or text altered)
- **THEN** the computed `dbSha256` no longer matches `manifest.checksums.dbSha256`, the integrity check returns `Failure.dataIntegrity`, and tafsir reads are disabled

#### Scenario: Tafsir row count mismatch

- **WHEN** `SELECT COUNT(*) FROM tafsir` does not equal the manifest's `counts.ayahs` value
- **THEN** the integrity check returns `Failure.dataIntegrity`

#### Scenario: Tafsir references an unknown ayah

- **WHEN** the `tafsir` table contains a `(surah, ayah)` row that does not exist in the bundled Quran DB's `ayahs` table
- **THEN** the integrity check returns `Failure.dataIntegrity` with a message naming the offending key

#### Scenario: Failed tafsir integrity check blocks the UI

- **WHEN** the tafsir integrity check returns `Failure.dataIntegrity`
- **THEN** the router shows the same fatal error screen used by the Quran integrity check, with a message that names the tafsir dataset as the failing source

#### Scenario: Integrity check is cached across launches

- **WHEN** tafsir integrity verification has succeeded for the current install on a previous launch and the bundled asset hash is unchanged
- **THEN** the SHA-256 hashing step is skipped on subsequent launches but the cheap structural checks (schema version, counts) still run, and the cache key is distinct from the Quran integrity cache key

### Requirement: Framework-free tafsir domain layer

The system SHALL expose tafsir data through a domain layer under `lib/domain/tafsir/` that has zero dependencies on Flutter, Riverpod, or any storage package. Domain types MUST include `Tafsir` and `TafsirSource`, MUST reuse the existing `AyahKey` value object from `lib/domain/quran/ayah_key.dart` as the row key, and MUST be safe to use from non-UI contexts (tests, the future tafsir UI, the future tier III embedding builder).

#### Scenario: Tafsir domain layer compiles without Flutter

- **WHEN** the `lib/domain/tafsir/` directory is compiled in isolation
- **THEN** no import resolves to `package:flutter/`, `package:flutter_riverpod/`, `package:sqflite/`, or `package:sqflite_common_ffi/`

#### Scenario: Tafsir uses the shared AyahKey

- **WHEN** a `Tafsir` value is constructed
- **THEN** its key field is of type `AyahKey` from `lib/domain/quran/ayah_key.dart` (not a new tafsir-local key type)

### Requirement: TafsirRepository contract

The system SHALL expose an `abstract class TafsirRepository` with the following methods, each returning `Future<Result<T, Failure>>`:

- `getTafsirForAyah(AyahKey key)` → `Tafsir`
- `getTafsirForSurah(int number)` → `List<Tafsir>` ordered by ayah number
- `getSource()` → `TafsirSource`

The contract MUST NOT throw across its boundary; programmer errors are the only allowed exceptions. The same contract MUST be reusable by a future tafsir UI and a future tier III embedding builder without modification.

#### Scenario: Get tafsir for a known ayah

- **WHEN** `getTafsirForAyah(AyahKey(2, 255))` is called against a healthy repository
- **THEN** it returns `Result.ok` with a `Tafsir` whose `key` equals `AyahKey(2, 255)` and whose `text` is non-empty

#### Scenario: Get tafsir for a known surah

- **WHEN** `getTafsirForSurah(1)` is called
- **THEN** it returns `Result.ok` with exactly 7 `Tafsir` entries ordered by ayah number 1..7

#### Scenario: Unknown ayah key

- **WHEN** `getTafsirForAyah(AyahKey(1, 99))` is called (Al-Fatihah has 7 ayahs)
- **THEN** it returns `Failure.notFound` and does not throw

#### Scenario: Unknown surah number

- **WHEN** `getTafsirForSurah(115)` is called
- **THEN** it returns `Failure.notFound` and does not throw

#### Scenario: Source attribution is reachable through the repository

- **WHEN** `getSource()` is called
- **THEN** it returns `Result.ok` with a `TafsirSource` whose `name`, `publisher`, `version`, `url`, and `license` match the bundled manifest

### Requirement: Read-only runtime access with no network

The tafsir repository implementation SHALL open the bundled SQLite database in read-only mode and SHALL NOT make any network call as part of serving tafsir data at runtime. Any download or generation of tafsir data MUST occur only inside the maintainer build tool under `tool/`.

#### Scenario: Tafsir database is opened read-only

- **WHEN** the SQLite-backed tafsir repository opens the database
- **THEN** it passes options that mark the connection read-only, and any attempted write returns a SQLite read-only error rather than corrupting the asset

#### Scenario: No runtime network access for tafsir data

- **WHEN** the app starts and serves any number of tafsir repository calls
- **THEN** no HTTP, WebSocket, or other network call is made by code under `lib/data/tafsir/` or `lib/domain/tafsir/`

### Requirement: Source attribution is surfaced in the app

The application SHALL surface the bundled tafsir source attribution (name, publisher, version, license, and upstream URL) somewhere reachable from the main UI. The MVP placement is the Settings page alongside the existing Quran source row. The wording MUST credit the source per its license terms even though no tafsir-consuming UI has shipped yet.

#### Scenario: Tafsir attribution is reachable from Settings

- **WHEN** the user navigates to the Settings page
- **THEN** a "Tafsir source" section displays the source name, publisher, version, license summary, and a non-clickable URL string

#### Scenario: Tafsir attribution data comes from the repository

- **WHEN** the Settings UI renders the tafsir attribution
- **THEN** the values are obtained via `TafsirRepository.getSource()` and not hard-coded in the UI layer

### Requirement: Maintainer build tool for tafsir

The system SHALL include a maintainer-run Dart CLI at `tool/build_tafsir_db.dart` that downloads the pinned al-Muyassar source, verifies its SHA-256 against a pinned hash, parses it, builds `assets/tafsir/muyassar.sqlite`, and writes `assets/tafsir/manifest.json`. The tool MUST be exposed as a `just build-tafsir-db` recipe and MUST refuse to emit output when any precondition fails (missing license file, hash mismatch, parsed count not equal to 6,236).

#### Scenario: Tafsir build tool refuses on upstream hash mismatch

- **WHEN** the downloaded al-Muyassar archive's SHA-256 does not equal the pinned expected hash
- **THEN** the tool exits with a non-zero status and writes no output files

#### Scenario: Tafsir build tool refuses on count mismatch

- **WHEN** the parsed tafsir entries are not exactly 6,236
- **THEN** the tool exits with a non-zero status, writes no output files, and surfaces a message naming the expected and actual counts

#### Scenario: Tafsir build tool emits both DB and manifest atomically

- **WHEN** the tool completes successfully
- **THEN** both `muyassar.sqlite` and `manifest.json` exist in `assets/tafsir/` and reference the same `textSha256`

#### Scenario: Tafsir build tool dependencies do not ship with the app

- **WHEN** `flutter build windows` is run on the project
- **THEN** none of the build-tool-only packages (`http`, `archive`, `crypto` write path, `sqlite3` write path) appear in the runtime app's dep graph beyond what `quran-data` already required

### Requirement: Riverpod exposure of the tafsir repository

The system SHALL expose the `TafsirRepository` to the rest of the app through a Riverpod provider, and SHALL run the tafsir integrity check exactly once per app launch. The tafsir integrity check MUST run before any feature is allowed to call tafsir repository read methods. The check MAY run in parallel with the Quran integrity check, but both MUST pass before the main UI is allowed to render.

#### Scenario: Tafsir repository is available via Riverpod

- **WHEN** any feature reads `tafsirRepositoryProvider`
- **THEN** it receives a fully initialized `TafsirRepository` instance backed by the bundled SQLite asset

#### Scenario: Tafsir integrity check runs once per launch

- **WHEN** the app boots
- **THEN** the tafsir integrity check runs exactly once, its result is cached in a Riverpod provider, and subsequent reads of the integrity status do not re-hash the DB

#### Scenario: Failed tafsir integrity check blocks the UI

- **WHEN** the tafsir integrity check returns `Failure.dataIntegrity`
- **THEN** the router shows the fatal error screen and no tafsir or main-shell reads are served
