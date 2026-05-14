## 1. Branch and dependencies

- [ ] 1.1 Branch from `origin/develop` as `feature/add-tafsir-data` per the *one change, one branch* rule in [AGENTS.md](../../../AGENTS.md)
- [ ] 1.2 Confirm runtime deps from `quran-data` already cover this change (`sqflite_common_ffi`, `path_provider`, `crypto`, `path`) — no new runtime additions expected
- [ ] 1.3 Confirm dev deps already cover the build tool (`http`, `archive`, `crypto`, `sqlite3` under `dev_dependencies`) — no new dev additions expected
- [ ] 1.4 Register asset paths `assets/tafsir/muyassar.sqlite` and `assets/tafsir/manifest.json` under `flutter > assets` in [pubspec.yaml](../../../pubspec.yaml)
- [ ] 1.5 Run `just get` and confirm `flutter analyze` is clean

## 2. Domain layer (framework-free)

- [ ] 2.1 Create `lib/domain/tafsir/tafsir.dart` with `Tafsir { key: AyahKey, text: String }` (immutable, equality, reuses `AyahKey` from `lib/domain/quran/ayah_key.dart`)
- [ ] 2.2 Create `lib/domain/tafsir/tafsir_source.dart` with `TafsirSource { name, publisher, version, url, license, retrievedAtUtc }`
- [ ] 2.3 Create `lib/domain/tafsir/tafsir_repository.dart` defining the abstract repository contract from the spec
- [ ] 2.4 Add a unit-test guard that imports `lib/domain/tafsir/` from a no-Flutter test and confirms it compiles standalone (mirrors the equivalent guard for `lib/domain/quran/`)

## 3. Maintainer build tool (`tool/build_tafsir_db.dart`)

- [ ] 3.1 Scaffold `tool/build_tafsir_db.dart` with CLI args `--source-url`, `--source-sha256`, `--out-dir` defaulting to the pinned al-Muyassar URL/hash and `assets/tafsir/`
- [ ] 3.2 Implement download step using `package:http`, write to a temp file, and verify SHA-256 against `--source-sha256`; abort on mismatch
- [ ] 3.3 Implement al-Muyassar parse: read the upstream format into a list of `(surah, ayah, text)` tuples; cover format quirks (line continuations, footnote markers, etc.) explicitly
- [ ] 3.4 Open output SQLite via `package:sqlite3`, create `meta` and `tafsir` tables per the spec
- [ ] 3.5 Insert all rows in deterministic order (sorted by `(surah, ayah)`); validate that the count is exactly 6,236 before commit, abort if not
- [ ] 3.6 Insert `meta` rows: `schema_version=1`, source attribution fields, `text_sha256` — note that `retrieved_at_utc` lives in manifest only (DB stays byte-deterministic)
- [ ] 3.7 `VACUUM` and close the DB; compute `dbSha256` of the final file
- [ ] 3.8 Emit `manifest.json` with `schemaVersion`, `dataset`, `source`, `counts { ayahs }`, and `checksums { dbSha256, textSha256 }`
- [ ] 3.9 Add license-precondition guard: tool refuses to write outputs if the upstream license file is missing or its hash doesn't match a pinned expected value
- [ ] 3.10 Add count-precondition guard: tool refuses to write if the parsed count is not exactly 6,236
- [ ] 3.11 Add `just build-tafsir-db` recipe to the [Justfile](../../../Justfile)
- [ ] 3.12 Run the tool locally, commit the produced `assets/tafsir/muyassar.sqlite` and `assets/tafsir/manifest.json`
- [ ] 3.13 Run the tool twice and verify byte-identical output (idempotence test)

## 4. Data layer (SQLite repository + integrity)

- [ ] 4.1 Create `lib/data/tafsir/tafsir_database.dart`: opens the bundled tafsir DB read-only via `sqflite_common_ffi`, mirrors the Quran data layer's asset-bytes-or-file-path handling
- [ ] 4.2 Create `lib/data/tafsir/manifest.dart`: loads `assets/tafsir/manifest.json` via `rootBundle` and parses it into a typed `TafsirManifest` object
- [ ] 4.3 Create `lib/data/tafsir/integrity_checker.dart`: full check (schema version, row count = manifest count, no orphan `(surah, ayah)` rows that don't exist in the Quran DB, `dbSha256` matches manifest); fast check (schema version + count) for cached subsequent runs
- [ ] 4.4 Cache integrity-check result keyed by manifest `dbSha256` in `SharedPreferences` under a key distinct from the Quran integrity cache key
- [ ] 4.5 Create `lib/data/tafsir/tafsir_repository_sqlite.dart` implementing `TafsirRepository` against the opened DB; wrap every SQL call with a `try/catch` that maps to `Failure.dataAccess`
- [ ] 4.6 Add a no-network guard: a test-time assertion that `lib/data/tafsir/` and `lib/domain/tafsir/` import no networking package
- [ ] 4.7 Unit-test the manifest parser (valid + missing fields)
- [ ] 4.8 Unit-test the integrity checker against (a) the real bundled DB, (b) a synthetically tampered DB, (c) a DB with a row pointing to a non-existent ayah
- [ ] 4.9 Repository contract test: `getTafsirForAyah(2:255)` returns non-empty text, `getTafsirForSurah(1)` returns 7 entries ordered 1..7, `getTafsirForAyah(1:99)` returns `Failure.notFound`, `getTafsirForSurah(115)` returns `Failure.notFound`, `getSource()` returns the manifest's source

## 5. Riverpod wiring + app boot

- [ ] 5.1 Create `lib/data/tafsir/providers.dart` with `tafsirDatabaseProvider` (FutureProvider) and `tafsirRepositoryProvider` (Provider, depends on the database)
- [ ] 5.2 Create `lib/app/state/tafsir_integrity_provider.dart` exposing `FutureProvider<Result<Unit>>` for the tafsir integrity status
- [ ] 5.3 Extend the existing app bootstrap so that both Quran and tafsir integrity checks must pass before the main shell renders (one composite gate, not two separate redirects)
- [ ] 5.4 Reuse the existing fatal error screen (`lib/features/_errors/data_integrity_screen.dart`); ensure its message slot is wired to the failing dataset's name so the user can distinguish "Quran integrity" from "Tafsir integrity"

## 6. Settings attribution surface

- [ ] 6.1 Update the Settings page to add a "Tafsir source" section that pulls from `TafsirRepository.getSource()`, placed directly under the existing "Quran source" section
- [ ] 6.2 Add a `THIRD_PARTY_NOTICES.md` entry with the al-Muyassar / King Fahd Complex license text and attribution exactly as required by the source license
- [ ] 6.3 Widget test: Settings page renders tafsir source name, publisher, version, license summary, and URL string

## 7. Documentation rides along

- [ ] 7.1 Update [AGENTS.md](../../../AGENTS.md) *Wired today* section to mention (a) merged keyword search (PR #14: `searchAyahs` on `QuranRepository`, FTS5-backed search page) and (b) this change's tafsir data layer
- [ ] 7.2 Update [AGENTS.md](../../../AGENTS.md) *Not yet implemented* section: remove "search UX (FTS5 index exists)" since search is now implemented (semantic and topical search are tracked under separate planned changes)
- [ ] 7.3 Update [AGENTS.md](../../../AGENTS.md) *Lib layout* tree to include `lib/domain/tafsir/` and `lib/data/tafsir/`
- [ ] 7.4 Update the *Commands* table in [AGENTS.md](../../../AGENTS.md) with the new `just build-tafsir-db` recipe
- [ ] 7.5 Update [README.md](../../../README.md) *Data sources* section to point at the new THIRD_PARTY_NOTICES.md entry and add a *Building the tafsir DB* maintainer note

## 8. Quality gates

- [ ] 8.1 `just format` clean
- [ ] 8.2 `just analyze` zero warnings
- [ ] 8.3 `just test` passes — new tests added: domain isolation guard, no-network guard, manifest parser, integrity checker against real DB + tampered DB + synthetic mini-DB, repository contract, Settings attribution
- [ ] 8.4 `flutter build windows --release` succeeds and produces an executable with `assets/tafsir/muyassar.sqlite` + `manifest.json` bundled under `data/flutter_assets/`
- [ ] 8.5 PR diff review: `dbSha256` in `manifest.json` matches the bytes of `muyassar.sqlite`; running `just build-tafsir-db` twice on a clean checkout produces identical output (the build tool is idempotent)
- [ ] 8.6 Confirm the change ships as a single PR on `feature/add-tafsir-data` → `develop` per [AGENTS.md](../../../AGENTS.md)
