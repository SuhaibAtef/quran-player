## ADDED Requirements

### Requirement: Canonical topical concordance source vendoring

The system SHALL bundle exactly one canonical topical-concordance source — the King Fahd Complex's *Mu'jam Al-Mufahras Al-Maudu'i li Ayat al-Quran al-Karim* — and SHALL record its name, publisher, version, upstream URL, license, and retrieval timestamp in a committed manifest. The bundled data MUST NOT be modified, edited, or augmented at any layer (build tool, runtime, UI). Adding additional topic sources or auto-generating topics is out of scope and MUST be a separate change.

#### Scenario: Source attribution is recorded in the manifest

- **WHEN** the build tool produces `assets/topics/mujam.sqlite` and `assets/topics/manifest.json`
- **THEN** `manifest.json` contains a `source` object with `name`, `publisher`, `version`, `url`, `license`, and `retrievedAtUtc` fields, all non-empty

#### Scenario: Source is preserved byte-for-byte

- **WHEN** the build tool downloads the upstream Mu'jam archive
- **THEN** it computes a SHA-256 of the raw source payload, stores it as `meta.text_sha256` in the DB and as `manifest.checksums.textSha256`, and refuses to emit output if either is empty

#### Scenario: Maintainer reproducibility

- **WHEN** a maintainer runs `tool/build_topics_db.dart` twice with the same pinned source version on the same platform
- **THEN** the produced `mujam.sqlite` byte content and `manifest.checksums.dbSha256` are identical

### Requirement: Bundled topics SQLite asset and schema lock

The application SHALL ship a pre-built SQLite database as a Flutter asset at `assets/topics/mujam.sqlite` containing the locked v1 schema (`meta`, `topics`, `topic_ayahs`). The schema version MUST be recorded in `meta.schema_version`. Schema migrations are out of scope — any future schema change MUST land as a new version with an explicit migration plan.

#### Scenario: Schema v1 is present

- **WHEN** the app opens the bundled topics DB
- **THEN** the DB contains tables `meta`, `topics` (with `id`, `parent_id`, `label_ar`, `sort_order`), and `topic_ayahs` (with `topic_id`, `surah`, `ayah` as composite primary key), and `meta.schema_version` equals `'1'`

#### Scenario: App refuses to run on unknown schema version

- **WHEN** the app opens a topics DB whose `meta.schema_version` is missing or not `'1'`
- **THEN** the integrity check returns `Failure.dataIntegrity` and the app surfaces a fatal error screen

#### Scenario: Topics DB is a separate file from other dataset DBs

- **WHEN** the maintainer build tools have run
- **THEN** `assets/topics/mujam.sqlite` exists as a distinct file from `assets/quran/quran.sqlite` and `assets/tafsir/muyassar.sqlite`, with its own sibling manifest `assets/topics/manifest.json`, and the manifests do not cross-reference checksums

### Requirement: Runtime topics integrity verification fails closed

On first launch and after every app upgrade, the application SHALL verify the bundled topics data against its manifest. The check MUST validate: schema version, topic count, link count, that every `topics.parent_id` references an existing `topics.id`, that every `topic_ayahs.(surah, ayah)` references a real ayah in the bundled Quran DB, and that the database SHA-256 matches `manifest.checksums.dbSha256`. Any mismatch MUST prevent the app from serving topics data and MUST trip the same fatal error screen used by the Quran integrity check; the system MUST NOT fall back to a partial or alternate source.

#### Scenario: Healthy bundled topics DB passes verification

- **WHEN** the app opens the unmodified bundled topics DB and manifest
- **THEN** the topics integrity check returns `Result.ok` and topic reads are enabled

#### Scenario: Tampered topics DB trips integrity check

- **WHEN** the bundled topics DB has been modified after build (e.g., a row deleted or a label altered)
- **THEN** the computed `dbSha256` no longer matches `manifest.checksums.dbSha256`, the integrity check returns `Failure.dataIntegrity`, and topic reads are disabled

#### Scenario: Topic count mismatch

- **WHEN** `SELECT COUNT(*) FROM topics` does not equal the manifest's `counts.topics` value
- **THEN** the integrity check returns `Failure.dataIntegrity`

#### Scenario: Link count mismatch

- **WHEN** `SELECT COUNT(*) FROM topic_ayahs` does not equal the manifest's `counts.links` value
- **THEN** the integrity check returns `Failure.dataIntegrity`

#### Scenario: Orphan parent pointer

- **WHEN** a `topics.parent_id` is non-null and does not reference any row in `topics.id`
- **THEN** the integrity check returns `Failure.dataIntegrity` with a message naming the offending topic id

#### Scenario: Orphan ayah link

- **WHEN** a `topic_ayahs.(surah, ayah)` does not reference a real ayah in the bundled Quran DB
- **THEN** the integrity check returns `Failure.dataIntegrity` with a message naming the offending key

#### Scenario: Failed topics integrity check blocks the UI

- **WHEN** the topics integrity check returns `Failure.dataIntegrity`
- **THEN** the router shows the same fatal error screen used by the Quran integrity check, with a message that names the topics dataset as the failing source

#### Scenario: Integrity check is cached across launches

- **WHEN** topics integrity verification has succeeded for the current install on a previous launch and the bundled asset hash is unchanged
- **THEN** the SHA-256 hashing step is skipped on subsequent launches but the cheap structural checks (schema version, counts) still run, and the cache key is distinct from the Quran and tafsir integrity cache keys

### Requirement: Framework-free topics domain layer

The system SHALL expose topics data through a domain layer under `lib/domain/topics/` that has zero dependencies on Flutter, Riverpod, or any storage package. Domain types MUST include `Topic`, `TopicNode` (a recursive tree node), `TopicAyahLink`, and `TopicsSource`, MUST reuse the existing `AyahKey` value object from `lib/domain/quran/ayah_key.dart` for ayah references, and MUST be safe to use from non-UI contexts (tests, the future topics UI, the future tier II embedding builder).

#### Scenario: Topics domain layer compiles without Flutter

- **WHEN** the `lib/domain/topics/` directory is compiled in isolation
- **THEN** no import resolves to `package:flutter/`, `package:flutter_riverpod/`, `package:sqflite/`, or `package:sqflite_common_ffi/`

#### Scenario: Topic links use the shared AyahKey

- **WHEN** a `TopicAyahLink` value is constructed or a `TopicsRepository` method returns ayah references
- **THEN** the ayah field is of type `AyahKey` from `lib/domain/quran/ayah_key.dart` (not a new topics-local key type)

### Requirement: TopicsRepository contract

The system SHALL expose an `abstract class TopicsRepository` with the following methods, each returning `Future<Result<T, Failure>>`:

- `listTopics()` → `List<Topic>` ordered by `(parent_id NULLS FIRST, sort_order, id)`
- `getTopicTree()` → `TopicNode` covering the entire hierarchy starting from a synthetic root
- `getAyahsForTopic(int topicId)` → `List<AyahKey>` ordered by `(surah, ayah)`
- `getTopicsForAyah(AyahKey key)` → `List<Topic>` (zero or more)
- `getSource()` → `TopicsSource`

The contract MUST NOT throw across its boundary; programmer errors are the only allowed exceptions. The same contract MUST be reusable by a future topics UI and a future tier II embedding builder without modification.

#### Scenario: List all topics

- **WHEN** `listTopics()` is called against a healthy repository
- **THEN** it returns `Result.ok` with all topics in the bundled DB, ordered by `(parent_id NULLS FIRST, sort_order, id)`

#### Scenario: Get the topic tree

- **WHEN** `getTopicTree()` is called
- **THEN** it returns `Result.ok` with a `TopicNode` whose direct children are every top-level topic (rows where `parent_id IS NULL`), recursively descended; the total count of `Topic` values reachable from the tree equals `listTopics().length`

#### Scenario: Get ayahs for a known topic

- **WHEN** `getAyahsForTopic(<existing-id>)` is called
- **THEN** it returns `Result.ok` with at least one `AyahKey`; every returned key references a real ayah in the bundled Quran DB

#### Scenario: Get topics for a known ayah

- **WHEN** `getTopicsForAyah(AyahKey(2, 155))` is called
- **THEN** it returns `Result.ok` with zero or more `Topic` values (zero is valid for ayahs the source did not categorize)

#### Scenario: Unknown topic id

- **WHEN** `getAyahsForTopic(<non-existent-id>)` is called
- **THEN** it returns `Failure.notFound` and does not throw

#### Scenario: Source attribution is reachable through the repository

- **WHEN** `getSource()` is called
- **THEN** it returns `Result.ok` with a `TopicsSource` whose `name`, `publisher`, `version`, `url`, and `license` match the bundled manifest

### Requirement: Read-only runtime access with no network

The topics repository implementation SHALL open the bundled SQLite database in read-only mode and SHALL NOT make any network call as part of serving topics data at runtime. Any download or generation of topics data MUST occur only inside the maintainer build tool under `tool/`.

#### Scenario: Topics database is opened read-only

- **WHEN** the SQLite-backed topics repository opens the database
- **THEN** it passes options that mark the connection read-only, and any attempted write returns a SQLite read-only error rather than corrupting the asset

#### Scenario: No runtime network access for topics data

- **WHEN** the app starts and serves any number of topics repository calls
- **THEN** no HTTP, WebSocket, or other network call is made by code under `lib/data/topics/` or `lib/domain/topics/`

### Requirement: Source attribution is surfaced in the app

The application SHALL surface the bundled topics source attribution (name, publisher, version, license, and upstream URL) somewhere reachable from the main UI. The MVP placement is the Settings page alongside the existing Quran source row (and tafsir source row, when that change is also merged). The wording MUST credit the source per its license terms even though no topics-consuming UI has shipped yet.

#### Scenario: Topics attribution is reachable from Settings

- **WHEN** the user navigates to the Settings page
- **THEN** a "Topical index source" section displays the source name, publisher, version, license summary, and a non-clickable URL string

#### Scenario: Topics attribution data comes from the repository

- **WHEN** the Settings UI renders the topics attribution
- **THEN** the values are obtained via `TopicsRepository.getSource()` and not hard-coded in the UI layer

### Requirement: Maintainer build tool for topics

The system SHALL include a maintainer-run Dart CLI at `tool/build_topics_db.dart` that downloads the pinned Mu'jam source, verifies its SHA-256 against a pinned hash, parses it, validates hierarchy correctness and link validity against the already-built Quran DB, builds `assets/topics/mujam.sqlite`, and writes `assets/topics/manifest.json`. The tool MUST be exposed as a `just build-topics-db` recipe and MUST refuse to emit output when any precondition fails (missing license file, hash mismatch, orphan parent, orphan ayah link, duplicate links).

#### Scenario: Topics build tool refuses on upstream hash mismatch

- **WHEN** the downloaded Mu'jam archive's SHA-256 does not equal the pinned expected hash
- **THEN** the tool exits with a non-zero status and writes no output files

#### Scenario: Topics build tool refuses on orphan parent

- **WHEN** any parsed topic has a `parent_id` that does not exist among the parsed topic ids
- **THEN** the tool exits with a non-zero status, writes no output files, and surfaces a message naming the offending topic

#### Scenario: Topics build tool refuses on orphan ayah link

- **WHEN** any parsed link's `(surah, ayah)` does not exist in the already-built Quran DB
- **THEN** the tool exits with a non-zero status, writes no output files, and surfaces a message naming the offending link

#### Scenario: Topics build tool emits both DB and manifest atomically

- **WHEN** the tool completes successfully
- **THEN** both `mujam.sqlite` and `manifest.json` exist in `assets/topics/` and reference the same `textSha256`

#### Scenario: Topics build tool dependencies do not ship with the app

- **WHEN** `flutter build windows` is run on the project
- **THEN** none of the build-tool-only packages appear in the runtime app's dep graph beyond what `quran-data` already required

### Requirement: Riverpod exposure and bootstrap gate participation

The system SHALL expose the `TopicsRepository` to the rest of the app through a Riverpod provider, and SHALL run the topics integrity check exactly once per app launch. The topics integrity check MUST participate in the composite bootstrap gate so that the main UI is not allowed to render until all bundled-dataset integrity checks have passed.

#### Scenario: Topics repository is available via Riverpod

- **WHEN** any feature reads `topicsRepositoryProvider`
- **THEN** it receives a fully initialized `TopicsRepository` instance backed by the bundled SQLite asset

#### Scenario: Topics integrity check runs once per launch

- **WHEN** the app boots
- **THEN** the topics integrity check runs exactly once, its result is cached in a Riverpod provider, and subsequent reads of the integrity status do not re-hash the DB

#### Scenario: Topics integrity participates in the bootstrap gate

- **WHEN** the app boots
- **THEN** the main shell does not render until the Quran integrity check, the topics integrity check, and (when the tafsir change is also merged) the tafsir integrity check have all returned `Result.ok`

#### Scenario: Failed topics integrity check blocks the UI

- **WHEN** the topics integrity check returns `Failure.dataIntegrity`
- **THEN** the router shows the fatal error screen and no main-shell reads are served
