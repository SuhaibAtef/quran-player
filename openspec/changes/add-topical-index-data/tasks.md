## 1. Branch and dependencies

- [ ] 1.1 Branch from `origin/develop` as `feature/add-topical-index-data` per the *one change, one branch* rule in [AGENTS.md](../../../AGENTS.md)
- [ ] 1.2 Confirm runtime deps from `quran-data` already cover this change (no new runtime additions expected)
- [ ] 1.3 Confirm dev deps already cover the build tool (no new dev additions expected)
- [ ] 1.4 Register asset paths `assets/topics/mujam.sqlite` and `assets/topics/manifest.json` under `flutter > assets` in [pubspec.yaml](../../../pubspec.yaml)
- [ ] 1.5 Run `just get` and confirm `flutter analyze` is clean

## 2. Source verification (do this before any code)

- [ ] 2.1 Confirm the King Fahd Complex's *Mu'jam Al-Mufahras Al-Maudu'i* is available in a structured (JSON/XML/CSV) redistributable form. If only PDF is available, stop and re-scope this change.
- [ ] 2.2 Read the full upstream license; record the exact attribution text required for `THIRD_PARTY_NOTICES.md` and Settings display
- [ ] 2.3 Pin the source URL and an expected SHA-256 of the upstream archive

## 3. Domain layer (framework-free)

- [ ] 3.1 Create `lib/domain/topics/topic.dart` with `Topic { id, parentId, labelAr, sortOrder }` (immutable, equality)
- [ ] 3.2 Create `lib/domain/topics/topic_node.dart` with `TopicNode { topic, children }` (recursive)
- [ ] 3.3 Create `lib/domain/topics/topic_ayah_link.dart` with `TopicAyahLink { topicId, key: AyahKey }` (reuses `AyahKey` from `lib/domain/quran/`)
- [ ] 3.4 Create `lib/domain/topics/topics_source.dart` with `TopicsSource { name, publisher, version, url, license, retrievedAtUtc }`
- [ ] 3.5 Create `lib/domain/topics/topics_repository.dart` defining the abstract repository contract from the spec
- [ ] 3.6 Add a unit-test guard that imports `lib/domain/topics/` from a no-Flutter test and confirms it compiles standalone

## 4. Maintainer build tool (`tool/build_topics_db.dart`)

- [ ] 4.1 Scaffold `tool/build_topics_db.dart` with CLI args `--source-url`, `--source-sha256`, `--quran-db` (default `assets/quran/quran.sqlite`), `--out-dir`
- [ ] 4.2 Implement download step using `package:http`, write to a temp file, and verify SHA-256 against `--source-sha256`; abort on mismatch
- [ ] 4.3 Implement Mu'jam parse: read upstream format into `Topic` rows + `TopicAyahLink` rows; preserve upstream ordering via `sort_order`
- [ ] 4.4 Open the Quran DB read-only for cross-reference validation
- [ ] 4.5 Validate hierarchy: every non-null `parent_id` exists in the parsed topic set; no cycles (do a transitive-closure check); abort with a clear message if either fails
- [ ] 4.6 Validate links: every `(surah, ayah)` exists in the Quran DB's `ayahs` table; no duplicate `(topic_id, surah, ayah)` tuples; abort on either failure
- [ ] 4.7 Open output SQLite via `package:sqlite3`, create `meta`, `topics`, `topic_ayahs` tables plus the three indexes per the spec
- [ ] 4.8 Insert rows in deterministic order: topics by `(parent_id NULLS FIRST, sort_order, id)`, links by `(topic_id, surah, ayah)`
- [ ] 4.9 Insert `meta` rows: `schema_version=1`, source attribution, `text_sha256` (note: `retrieved_at_utc` lives in manifest only)
- [ ] 4.10 `VACUUM` and close the DB; compute `dbSha256`
- [ ] 4.11 Emit `manifest.json` with `schemaVersion`, `dataset: "topics-mujam"`, `source`, `counts { topics, links }`, `checksums { dbSha256, textSha256 }`
- [ ] 4.12 Add license-precondition guard; tool refuses if upstream license file is missing or hash-changed
- [ ] 4.13 Add `just build-topics-db` recipe to the [Justfile](../../../Justfile)
- [ ] 4.14 Run the tool locally, commit the produced `assets/topics/mujam.sqlite` and `assets/topics/manifest.json`
- [ ] 4.15 Run the tool twice and verify byte-identical output (idempotence test)

## 5. Data layer (SQLite repository + integrity)

- [ ] 5.1 Create `lib/data/topics/topics_database.dart`: opens the bundled topics DB read-only via `sqflite_common_ffi`, mirrors the existing data layer's asset-bytes-or-file-path handling
- [ ] 5.2 Create `lib/data/topics/manifest.dart`: loads `assets/topics/manifest.json` via `rootBundle` and parses it into a typed `TopicsManifest` object
- [ ] 5.3 Create `lib/data/topics/integrity_checker.dart`: full check (schema version, counts, no orphan parents, no orphan ayah links against the Quran DB, `dbSha256` matches manifest); fast check (schema version + counts) for cached subsequent runs
- [ ] 5.4 Cache integrity-check result keyed by manifest `dbSha256` in `SharedPreferences` under a key distinct from the Quran and tafsir integrity cache keys
- [ ] 5.5 Create `lib/data/topics/topics_repository_sqlite.dart` implementing `TopicsRepository`:
  - `listTopics()` — single SELECT ordered by `(parent_id NULLS FIRST, sort_order, id)`
  - `getTopicTree()` — load all topics, build the tree in-memory from a synthetic root
  - `getAyahsForTopic(int)` — JOIN, ordered by `(surah, ayah)`, return `AyahKey` list
  - `getTopicsForAyah(AyahKey)` — JOIN in reverse direction
  - `getSource()` — read from `meta` table
- [ ] 5.6 Wrap every SQL call with a `try/catch` that maps to `Failure.dataAccess`
- [ ] 5.7 Add a no-network guard: a test-time assertion that `lib/data/topics/` and `lib/domain/topics/` import no networking package
- [ ] 5.8 Unit-test the manifest parser (valid + missing fields)
- [ ] 5.9 Unit-test the integrity checker against (a) the real bundled DB, (b) tampered DB, (c) a DB with an orphan parent_id, (d) a DB with a link to a non-existent ayah
- [ ] 5.10 Repository contract test covering: list ordering, tree shape (total node count == listTopics().length), known-topic ayah lookup, known-ayah topics lookup, unknown-topic returns `Failure.notFound`, `getSource()` returns the manifest values

## 6. Riverpod wiring + bootstrap gate

- [ ] 6.1 Create `lib/data/topics/providers.dart` with `topicsDatabaseProvider` (FutureProvider) and `topicsRepositoryProvider` (Provider, depends on the database)
- [ ] 6.2 Create `lib/app/state/topics_integrity_provider.dart` exposing `FutureProvider<Result<Unit>>` for the topics integrity status
- [ ] 6.3 Extend the existing bootstrap gate to also wait for topics integrity to pass before allowing the main shell to render; document the dependency order (Quran integrity is a prerequisite for topics integrity since topics integrity cross-references the Quran DB)
- [ ] 6.4 Wire the fatal error screen to name the failing dataset ("Topical index") so the user can distinguish failures

## 7. Settings attribution surface

- [ ] 7.1 Update the Settings page to add a "Topical index source" section that pulls from `TopicsRepository.getSource()`
- [ ] 7.2 Add a `THIRD_PARTY_NOTICES.md` entry with the Mu'jam / King Fahd Complex license text and attribution exactly as required
- [ ] 7.3 Widget test: Settings page renders topics source name, publisher, version, license summary, and URL string

## 8. Documentation rides along

- [ ] 8.1 Update [AGENTS.md](../../../AGENTS.md) *Wired today* section to mention this change's topics data layer; if [add-tafsir-data](../add-tafsir-data/proposal.md) has merged first, extend its entry; if not, this change writes the foundational entry and the tafsir change extends it
- [ ] 8.2 Update [AGENTS.md](../../../AGENTS.md) *Lib layout* tree to include `lib/domain/topics/` and `lib/data/topics/`
- [ ] 8.3 Update the *Commands* table in [AGENTS.md](../../../AGENTS.md) with the new `just build-topics-db` recipe
- [ ] 8.4 Update [README.md](../../../README.md) *Data sources* section to point at the new THIRD_PARTY_NOTICES.md entry and add a *Building the topics DB* maintainer note

## 9. Quality gates

- [ ] 9.1 `just format` clean
- [ ] 9.2 `just analyze` zero warnings
- [ ] 9.3 `just test` passes — new tests added: domain isolation guard, no-network guard, manifest parser, integrity checker against real DB + tampered DB + synthetic mini-DB + orphan-parent + orphan-ayah, repository contract (5 methods), tree shape, Settings attribution
- [ ] 9.4 `flutter build windows --release` succeeds and produces an executable with `assets/topics/mujam.sqlite` + `manifest.json` bundled
- [ ] 9.5 PR diff review: `dbSha256` in `manifest.json` matches the bytes of `mujam.sqlite`; running `just build-topics-db` twice on a clean checkout produces identical output (idempotence verified)
- [ ] 9.6 Confirm the change ships as a single PR on `feature/add-topical-index-data` → `develop` per [AGENTS.md](../../../AGENTS.md)
