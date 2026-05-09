## 1. Dependencies and project wiring

- [x] 1.1 Add runtime deps to [pubspec.yaml](../../../pubspec.yaml): `sqflite_common_ffi`, `path_provider`, `path`
- [x] 1.2 Add dev-only deps under `dev_dependencies` for the build tool: `http`, `archive`, `crypto`, `sqlite3`
- [x] 1.3 Register asset paths `assets/quran/quran.sqlite` and `assets/quran/manifest.json` under `flutter > assets` in [pubspec.yaml](../../../pubspec.yaml)
- [x] 1.4 Run `just get` and confirm `flutter analyze` is clean

## 2. Domain layer (framework-free)

- [x] 2.1 Create `lib/domain/quran/ayah_key.dart` with `AyahKey { surah, ayah }`, `toString()`, `parse(String)` returning `Result<AyahKey>`, equality, and range checks
- [x] 2.2 Create `lib/domain/quran/surah.dart` with `Surah { number, nameArabic, nameLatin, revelation, ayahCount }` (immutable)
- [x] 2.3 Create `lib/domain/quran/ayah.dart` with `Ayah { key, text }` (immutable)
- [x] 2.4 Create `lib/domain/quran/quran_source.dart` with `QuranSource { name, edition, version, url, license, retrievedAtUtc }`
- [x] 2.5 Create `lib/domain/quran/quran_repository.dart` defining the abstract repository contract from the spec
- [x] 2.6 Add a unit-test guard that imports `lib/domain/quran/` from a no-Flutter test and confirms it compiles standalone (lint-only, no Flutter widget dependency)
- [x] 2.7 Unit-test `AyahKey.parse` for happy path, out-of-range, and malformed input

> **Follow-up note (added mid-implementation):** the mushaf-page reader UI will land in a separate change using [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) for visual page rendering, sitting on top of the `QuranRepository` defined here. Source attribution and integrity guarantees stay anchored on Tanzil + the manifest produced by `tool/build_quran_db.dart`.

## 3. Maintainer build tool (`tool/build_quran_db.dart`)

- [x] 3.1 Scaffold `tool/build_quran_db.dart` with CLI args `--source-url`, `--source-sha256`, `--out-dir` (defaulting to the pinned Tanzil URL/hash and `assets/quran/`)
- [x] 3.2 Implement download step using `package:http`, write to a temp file, and verify SHA-256 against `--source-sha256`; abort on mismatch
- [x] 3.3 Implement Tanzil parse: read the plain-text edition into a list of `(surah, ayah, text)` tuples
- [x] 3.4 Implement surah metadata table seed (numbers, Arabic names, Latin names, revelation type, ayah counts) — bundle as a static dataset inside the tool, sourced from Tanzil's metadata file
- [x] 3.5 Open output SQLite via `package:sqlite3`, create `meta`, `surahs`, `ayahs` tables and the `ayah_fts` FTS5 virtual table per the design
- [x] 3.6 Insert all rows in deterministic order (sorted), populate `ayah_fts` via the standard `INSERT INTO ayah_fts(rowid, text) SELECT ...` pattern
- [x] 3.7 Insert `meta` rows: `schema_version=1`, source attribution fields, `text_sha256`, `retrieved_at_utc`
- [x] 3.8 `VACUUM` and close the DB; compute `dbSha256` of the final file
- [x] 3.9 Emit `manifest.json` with `schemaVersion`, `source`, `counts { surahs, ayahs }`, and `checksums { dbSha256, textSha256 }`
- [x] 3.10 Add a precondition guard: tool refuses to write outputs if upstream license file is missing or counts ≠ 114/6,236
- [x] 3.11 Add `just build-quran-db` recipe to the [Justfile](../../../Justfile)
- [x] 3.12 Run the tool locally, commit the produced `assets/quran/quran.sqlite` and `assets/quran/manifest.json`

> **Implementation notes (Section 3):**
> - Upstream switched from a direct Tanzil ZIP (no longer served as a stable URL) to the Islamic Network alquran.cloud API, which redistributes Tanzil's `quran-uthmani` edition. Source attribution in the manifest still names Tanzil; `manifest.source.fetchUrl` records the actual API endpoint and `manifest.source.distribution` notes the redistribution path.
> - `retrieved_at_utc` is recorded in `manifest.json` only, not in the DB `meta` table — keeps the DB byte-deterministic across rebuilds so `dbSha256` is a real tamper detector and PR diffs are meaningful.
> - FTS5 uses external-content mode (`content='ayahs'`) populated via `INSERT INTO ayah_fts(ayah_fts) VALUES('rebuild')`. Tokenizer tuning for Arabic diacritic / alef-wasla normalization is a follow-up search-feature concern.

## 4. Data layer (SQLite repository + integrity)

- [x] 4.1 Create `lib/core/error/failure.dart` additions if needed: `Failure.dataIntegrity(message)`, `Failure.dataAccess(...)`, `Failure.notFound(...)`, `Failure.invalidInput(...)`
- [x] 4.2 Create `lib/data/quran/quran_database.dart`: opens the bundled DB read-only via `sqflite_common_ffi`. If the platform requires a file path, copy the asset bytes once into `path_provider.getApplicationSupportDirectory()/quran/quran.sqlite` after verifying the asset SHA-256 against the manifest
- [x] 4.3 Create `lib/data/quran/manifest.dart`: loads `assets/quran/manifest.json` via `rootBundle` and parses it into a typed `QuranManifest` object
- [x] 4.4 Create `lib/data/quran/integrity_checker.dart`: full check (schema version, surah count = 114, ayah count = 6,236, no duplicate `(surah, ayah)`, all surah numbers 1..114 present, `dbSha256` matches manifest); fast check (schema version + counts only) for cached subsequent runs
- [x] 4.5 Cache integrity-check result keyed by manifest `dbSha256` in `SharedPreferences` so subsequent launches skip SHA hashing
- [x] 4.6 Create `lib/data/quran/quran_repository_sqlite.dart` implementing `QuranRepository` against the opened DB; wrap every SQL call with a `try/catch` that maps to `Failure.dataAccess`
- [x] 4.7 Add a no-network guard: a static analysis or test-time assertion that `lib/data/quran/` and `lib/domain/quran/` import no networking package
- [x] 4.8 Unit-test the manifest parser (valid + missing fields)
- [x] 4.9 Unit-test the integrity checker against (a) the real bundled DB, (b) a synthetically tampered DB, (c) a DB with a deleted ayah
- [x] 4.10 Repository contract test: `listSurahs()` returns 114, `getSurah(1)` returns Al-Fatihah with 7 ayahs, `getAyah(2:255)` returns non-empty text, `getSurah(115)` returns `Failure.notFound`, `getAyah(1:8)` returns `Failure.notFound`, `getSource()` returns the manifest's source

> **Implementation note (Section 4):** `crypto` was promoted from dev-only to a runtime dependency because the runtime integrity check needs SHA-256 (the spec mandates fail-closed verification with a real hash, not just structural counts). `archive` and `sqlite3` (write path) stay dev-only.

## 5. Riverpod wiring + app boot

- [x] 5.1 Create `lib/data/quran/providers.dart` with `quranDatabaseProvider` (FutureProvider) and `quranRepositoryProvider` (Provider, depends on the database)
- [x] 5.2 Create `lib/app/state/quran_integrity_provider.dart` exposing `FutureProvider<Result<Unit>>` for the integrity status
- [x] 5.3 Update [lib/main.dart](../../../lib/main.dart) to await integrity check exactly once before `runApp` (or surface it via a top-level `AsyncValue` that the router consumes)
- [x] 5.4 Update the router to redirect to a fatal error screen when integrity has failed (use the existing unknown-route pattern as a template)
- [x] 5.5 Create the fatal error screen widget under `lib/features/_errors/data_integrity_screen.dart` using ForUI primitives

> **Implementation note (Section 5):** I took the "AsyncValue surfaced through router" path rather than awaiting in `main()`. The bootstrap is a `FutureProvider` that fires when the router's `_IntegrityListenable` first subscribes; while loading, the router redirects every path to `/_loading` (BootstrappingScreen) and on failure to `/_error/data-integrity`. This keeps `main.dart` simple and avoids a black-screen blocking await. Existing widget tests now override `quranBootstrapProvider` with a `FakeQuranRepository`-backed bootstrap so they don't need the real bundle.

## 6. Surahs feature wiring

- [x] 6.1 Create `lib/features/surahs/state/surahs_provider.dart`: `FutureProvider<List<Surah>>` calling `repo.listSurahs()`
- [x] 6.2 Replace the Surahs placeholder body with a `FList`/`FTile` (or equivalent ForUI primitive) that renders surah number + Arabic name + Latin name
- [x] 6.3 Render loading state with a ForUI progress indicator
- [x] 6.4 Render error state with a ForUI alert/banner; do not render a partial list
- [x] 6.5 Widget test: 114 surah tiles render on a healthy DB
- [x] 6.6 Widget test: error state shows when the provider yields a failure

## 7. Source attribution surfaces

- [x] 7.1 Update the Settings page to add a "Quran source" section that pulls from `QuranRepository.getSource()`
- [x] 7.2 Add `THIRD_PARTY_NOTICES.md` (new file at repo root) with the Tanzil license text and attribution exactly as required by the source license
- [x] 7.3 Widget test: Settings page renders source name, edition, version, license summary, and URL string

## 8. Documentation and platform notes

- [x] 8.1 Update [CLAUDE.md](../../../CLAUDE.md): under *Project state* note that the Quran data layer has shipped, list the new dirs (`lib/domain/quran/`, `lib/data/quran/`, `tool/`), and remove the *path_provider not yet a dependency* caveat from *Notes for future work*
- [x] 8.2 Update [README.md](../../../README.md): add a *Data sources* section pointing at THIRD_PARTY_NOTICES.md and a *Building the Quran DB* maintainer section
- [x] 8.3 Update [windows/CLAUDE.md](../../../windows/CLAUDE.md) with any sqflite_common_ffi runtime notes discovered during implementation
- [x] 8.4 Update [linux/CLAUDE.md](../../../linux/CLAUDE.md) with the `libsqlite3-dev` runtime requirement and the failure message users will see if it is missing
- [x] 8.5 Document `just build-quran-db` in the *Commands* table of [CLAUDE.md](../../../CLAUDE.md)

## 9. Quality gates

- [x] 9.1 `just format` — repo is formatted (43 files, 0 changed)
- [x] 9.2 `just analyze` — zero analyzer warnings
- [x] 9.3 `just test` — all unit and widget tests pass (38 tests, including domain isolation, no-network guard, manifest parser, integrity-checker against the real DB + tampered DB + synthetic mini-DB, repository contract, Surahs UI happy + error paths, Settings attribution)
- [x] 9.4 `flutter build windows --release` succeeds (68.7s) and produces `build/windows/x64/runner/Release/quran_player.exe` with `assets/quran/quran.sqlite` + `manifest.json` bundled under `data/flutter_assets/`
- [x] 9.5 Manually confirm the integrity check trips when the bundled DB is corrupted — covered automatically by the *fails when the on-disk DB is tampered* test in [test/data/quran/integrity_checker_test.dart](../../../test/data/quran/integrity_checker_test.dart) (it appends a byte to a copy of the bundled DB and asserts `DataIntegrityFailure`). A manual repro is `cp assets/quran/quran.sqlite /tmp/x && python -c "open('/tmp/x','ab').write(b'\\0')"`, swap into the app-support dir, and observe the data-integrity error screen on next launch.
- [x] 9.6 PR diff review: `dbSha256` in `manifest.json` matches the bytes of `quran.sqlite` (the build tool computes it from the final file). `dart run tool/build_quran_db.dart` is idempotent: two consecutive runs produce identical `dbSha256` (verified during Section 3). Reviewers can re-run the tool and confirm the manifest's recorded hash matches.
