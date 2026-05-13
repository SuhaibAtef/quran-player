## Context

The bootstrap-foundation change shipped a Riverpod + go_router + ForUI app shell with placeholder pages. There is no Quran data on disk yet — every MVP slice (surah list, ayah reader, search, audio, MCP) needs a stable data substrate first. IDEA.md mandates exact text preservation, source attribution, integrity checks (114 surahs, 6,236 ayahs, no duplicates, stable checksums), and read-only MCP output that matches the app's own queries.

Constraints:

- Desktop-only MVP (Windows primary; macOS/Linux later). No Flutter mobile/web. `sqflite` does not work on desktop natively — must use `sqflite_common_ffi`.
- Dart 3.10.4 / Flutter 3.38.5 / ForUI 0.17.0 (pinned per CLAUDE.md).
- Privacy is local-first: zero network calls at app runtime for Quran text. Tanzil is downloaded **at maintainer build time only**.
- Errors flow through `Result<T, Failure>` ([lib/core/error/](../../../lib/core/error/)). No throws across boundaries.
- The same data must later back the read-only MCP server (`get_ayah`, `get_surah`, `search_quran`, `list_surahs`) without divergence.

Stakeholders: end-users (correctness), maintainers (build tool ergonomics), future MCP server (consistent contract), reviewers (PR-able diff size).

## Goals / Non-Goals

**Goals:**

- One canonical, attributed Quran text source vendored into the repo with a reproducible build process.
- Bundled SQLite asset that the app reads directly — no first-run downloads, no network calls.
- Runtime integrity verification that fails closed (loud, fatal error) on any tamper or build mistake.
- Framework-free domain types and a `QuranRepository` contract decoupled from SQLite, so a future MCP server or in-memory test double can implement it.
- A schema and FTS table laid out **once** so future search/MCP changes don't require migrations.
- First UI consumer (Surahs list) wired to prove the contract end-to-end.

**Non-Goals:**

- Translations, tafsir, transliteration. (V1+, separate licensing trail.)
- Search UX. The FTS5 table exists but no search query API or UI lands here.
- Audio metadata, reciters, playback. Separate change.
- Bookmarks. Separate change.
- MCP server itself. Separate change — but its data needs are anticipated in the repository surface.
- Schema migrations. v1 is locked; any future change creates v2 + a migration.
- Multi-script editions (IndoPak, Warsh, etc.). Uthmani only.

## Decisions

### D1: Source = Tanzil Uthmani plain text v1.0.2

- **Why:** Widely adopted, plain UTF-8, clear non-commercial+attribution license, stable versioning, byte-for-byte verifiable.
- **Alternatives considered:**
  - *King Fahd Complex (KFSHQC) Madani text* — higher visual fidelity for the printed mushaf, but licensing requires explicit permission. Defer until we have a documented permission trail.
  - *quran.com API* — rejected: we want offline-first, and pulling at runtime contradicts the privacy/integrity story.
  - *Custom-curated text* — rejected: every divergence from a canonical source is a correctness risk and a religious-trust risk.
- **Trade-off:** Uthmani plain text lacks fine typographic markers some users want (waqf marks, sajdah marks). Acceptable for MVP; reader UI can render what's there.

### D2: Storage = pre-built SQLite shipped as a Flutter asset

- **Why:** Random access, fast indexed lookups for `(surah, ayah)`, native FTS5 for the search slice that follows, ~5–7 MB on disk, no first-run extraction cost beyond opening the DB.
- **Alternatives considered:**
  - *JSON assets per surah* — easy to diff in git but every list/search needs full-load + linear scan; awkward for the MCP server's `search_quran` later.
  - *Hive/Isar* — adds another binary format; Hive is unmaintained for new work, Isar adds non-trivial native deps with shifting platform support.
  - *Generate at first launch* — pushes 5+ MB of work onto every first install, fights the "fail closed" integrity story.
- **Trade-off:** Binary asset is harder to inspect in PRs. Mitigated by committing a `manifest.json` (text) with checksums and counts, and a deterministic build tool so reviewers can re-derive the binary.

### D3: SQLite access via `sqflite_common_ffi`

- **Why:** Only viable option for Flutter on Windows/macOS/Linux desktop. Reuses the well-known `sqflite` API surface.
- **Alternatives considered:**
  - *`drift`* — code-gen ORM. Powerful but adds build_runner + generated source; overkill for a read-only corpus where we already have hand-written DAO methods.
  - *`sqlite3` (raw)* — used by the build tool for write paths. Possible at runtime too, but loses the connection management `sqflite` gives us. Keeping runtime on `sqflite_common_ffi` and build-time on `package:sqlite3` keeps boundaries tidy.
- **Trade-off:** Two SQLite client packages in the dep graph (one runtime, one dev-only). Acceptable — they don't interact.

### D4: Schema (locked at v1)

```sql
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);  -- holds: schema_version, source_name, source_version, source_url,
    --        license, retrieved_at_utc, text_sha256

CREATE TABLE surahs (
  number       INTEGER PRIMARY KEY CHECK(number BETWEEN 1 AND 114),
  name_arabic  TEXT NOT NULL,
  name_latin   TEXT NOT NULL,    -- e.g. "Al-Fatihah"
  revelation   TEXT NOT NULL CHECK(revelation IN ('meccan','medinan')),
  ayah_count   INTEGER NOT NULL CHECK(ayah_count > 0)
);

CREATE TABLE ayahs (
  surah   INTEGER NOT NULL REFERENCES surahs(number),
  ayah    INTEGER NOT NULL CHECK(ayah > 0),
  text    TEXT NOT NULL,
  PRIMARY KEY (surah, ayah)
);
CREATE INDEX idx_ayahs_surah ON ayahs(surah);

CREATE VIRTUAL TABLE ayah_fts USING fts5(
  text,
  content='ayahs',
  content_rowid='rowid',
  tokenize='unicode61 remove_diacritics 2'
);
-- Triggers sync ayahs → ayah_fts on insert (build-time only; DB is read-only at runtime).
```

`schema_version = 1` is recorded in `meta`. The runtime opens the DB read-only and refuses to start if `schema_version != 1`.

### D5: Integrity check = manifest-driven, fail-closed

`assets/quran/manifest.json` is generated alongside the DB and contains:

```json
{
  "schemaVersion": 1,
  "source": { "name": "Tanzil", "edition": "Uthmani plain text",
              "version": "1.0.2", "url": "https://tanzil.net/download/",
              "license": "Tanzil Quran Text License (non-commercial, attribution)",
              "retrievedAtUtc": "2026-05-09T00:00:00Z" },
  "counts":   { "surahs": 114, "ayahs": 6236 },
  "checksums": { "dbSha256": "<hex>", "textSha256": "<hex>" }
}
```

On first launch (and after every app upgrade), the app:

1. Opens the bundled DB read-only.
2. Reads `meta.schema_version`, `meta.text_sha256`, surah count, total ayah count.
3. Compares against `manifest.json`.
4. Computes SHA-256 of the bundled DB file and compares to `manifest.dbSha256`.
5. On mismatch → `Failure.dataIntegrity(...)` returned to the caller, app surfaces a fatal error screen. No fallback to wrong data.

Subsequent launches skip the SHA-256 hash if `meta.text_sha256` matched on the previous run and the install timestamp is unchanged (cached in `SharedPreferences`).

### D6: Domain layer is framework-free

[lib/domain/quran/](../../../lib/domain/quran/) imports nothing from `flutter`, `sqflite`, or `riverpod`. It defines:

- `AyahKey` value object (`surah`, `ayah`, with `toString() => "2:255"` and a parser).
- `Surah`, `Ayah`, `QuranSource`.
- `abstract class QuranRepository` with `Result`-returning methods:
  - `Future<Result<List<Surah>>> listSurahs()`
  - `Future<Result<Surah>> getSurah(int number)`
  - `Future<Result<Ayah>> getAyah(AyahKey key)`
  - `Future<Result<List<Ayah>>> getSurahAyahs(int number)`
  - `Future<Result<QuranSource>> getSource()`

The SQLite implementation lives in [lib/data/quran/](../../../lib/data/quran/) and is the only place that imports `sqflite_common_ffi`. This is the seam the MCP server will reuse.

### D7: Build tool is maintainer-run, idempotent, network-gated

`tool/build_quran_db.dart` is a Dart CLI:

- Inputs: a Tanzil source URL (default pinned), an output directory (default `assets/quran/`).
- Steps: download → SHA-256 verify against a pinned hash → parse → emit `quran.sqlite` + `manifest.json`.
- Deterministic: same input → same output bytes (uses `journal_mode=DELETE`, `VACUUM`, sorts inserts).
- Wrapped in `just build-quran-db`. Runs in CI optionally (we don't *need* CI to rebuild on every commit; the asset is committed).
- Lives under `dev_dependencies`; the runtime app never imports `tool/`.

### D8: Where the DB lives at runtime

Read-only access from the asset bundle. We do **not** copy the DB to the user's app-support directory unless we need to. Open via `databaseFactoryFfi.openDatabase(rootBundle.load(...))`-style read path.

Catch: `sqflite_common_ffi` opens DBs by file path. If we cannot open straight from `rootBundle`, fall back to a one-time copy into `path_provider.getApplicationSupportDirectory()/quran/quran.sqlite` on first launch, **after** integrity check has passed against the asset bytes (not the copied file). This gives us a deterministic verification path even if a copy is required.

This is the precise reason `path_provider` enters the dep graph here — flagged in proposal Impact.

### D9: Riverpod wiring

- `quranRepositoryProvider`: `Provider<QuranRepository>` — async-initialized via `FutureProvider` because DB open is async. Use the standard pattern: a `quranDatabaseProvider` (FutureProvider) plus a synchronous `quranRepositoryProvider` that depends on it.
- `quranIntegrityProvider`: runs once on app start (called from `main()` after `initLogging()` but before `runApp`), surfaces success/failure to a top-level error screen.
- The Surahs feature gets a `surahsProvider: FutureProvider<List<Surah>>` that calls `repo.listSurahs()`.

### D10: Logging and error surface

All boundary methods log via `appLogger` ([lib/core/logging/logger.dart](../../../lib/core/logging/logger.dart)). Failures map to `Failure` subtypes:

- `Failure.dataIntegrity` — manifest mismatch, schema mismatch, count mismatch.
- `Failure.dataAccess` — DB open or read errors.
- `Failure.notFound` — unknown surah/ayah key.

No `print`. No throws across the repository boundary.

## Risks / Trade-offs

- **License compliance for Tanzil** → record full attribution in `THIRD_PARTY_NOTICES.md`, surface in Settings (Settings page exists as a placeholder; this change adds the source row), pin version in the manifest. Also add a guard: build tool refuses to run if the license file is missing from the source archive.
- **Asset bloat** → 5–7 MB is acceptable; we cap at 10 MB. CI check on PR diff size warns if the DB changes; if the manifest's `dbSha256` changed without a corresponding `tool/build_quran_db.dart` change, reviewer should suspect tampering.
- **Schema migration debt** → locking v1 now means a future schema change requires a one-time migration (or a re-bundle). Mitigation: the v1 schema covers everything the MVP MCP tools need (`get_ayah`, `get_surah`, `list_surahs`, `search_quran` via FTS5), so we are unlikely to touch it.
- **`sqflite_common_ffi` on Linux** → some distros need `libsqlite3-dev` at runtime. Document in `linux/CLAUDE.md` and fail with a clear message rather than crashing.
- **DB file is a binary blob in git** → mitigated by deterministic build tool + manifest checksums; reviewers can re-run the tool and diff. Long-term: consider Git LFS if the asset grows (it shouldn't for Uthmani plain text).
- **Read-only at runtime, but `sqflite_common_ffi` opens RW by default** → explicitly pass `OpenDatabaseOptions(readOnly: true)` so accidental writes raise an error instead of corrupting the asset.
- **Drift between DB and manifest** → both are emitted by the same build tool in one run; the tool computes `dbSha256` *after* writing and refuses to exit if `meta.text_sha256` is empty. If a reviewer hand-edits one without the other, the integrity check trips on the next launch.

## Migration Plan

This is a greenfield capability — no existing data. Deployment steps:

1. Maintainer runs `just build-quran-db` once locally, commits `assets/quran/quran.sqlite` and `assets/quran/manifest.json`.
2. PR includes the build tool, generated asset, manifest, and `THIRD_PARTY_NOTICES.md` entry.
3. CI runs `flutter test` (covers integrity check and repository contract tests against the real bundled DB).
4. Rollback: revert the PR. The app still ships, but the Surahs page goes back to its placeholder. No user data is destroyed because nothing user-facing is persisted yet.

For future text-source bumps (e.g. Tanzil 1.0.3): re-run the build tool, expect new `dbSha256` and `textSha256`, bump `source.version` in the manifest, document the diff, and ship as a separate change.

## Open Questions

- **Should the integrity check copy the DB to app-support on first run, or always read from `rootBundle`?** Decision deferred to implementation: try read-from-bundle first; if `sqflite_common_ffi` requires a path on any of our three platforms, fall back to one-time copy with the asset bytes as the verification source. Document the chosen path in [windows/CLAUDE.md](../../../windows/CLAUDE.md) when known.
- **Where in the UI does source attribution surface?** Initial answer: a "Source" row in the Settings page (already a placeholder) and a small "Tanzil v1.0.2" line in the Surahs list footer. Final placement is an Impeccable concern, not a data-layer concern — flag for a follow-up if it expands.
- **Do we need a separate `english_name` column for surahs?** Tanzil ships a Latin transliteration; bundling it now is cheap and avoids a schema bump later. Going with `name_latin` in v1.
