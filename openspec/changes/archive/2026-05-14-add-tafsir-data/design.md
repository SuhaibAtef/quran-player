## Context

The `quran-data` capability shipped the substrate pattern for bundled, attributed, integrity-checked corpora: maintainer build tool → byte-deterministic SQLite asset → manifest with SHA-256 checksums → framework-free domain layer → SQLite-backed implementation behind a `Result`-returning repository contract → Riverpod exposure → fail-closed runtime integrity check → Settings attribution. This change reuses that pattern wholesale for a *second* corpus: al-Muyassar tafsir. The shape is intentionally near-identical so reviewers don't have to re-learn anything and so the third (`topical-index-data`) and fourth+ (`embeddings`) datasets can follow the same rails.

Constraints:

- Desktop-only MVP (Windows primary; macOS/Linux later).
- Dart SDK `^3.11.0`, Flutter 3.41+, ForUI `^0.21.3` per [AGENTS.md](../../../AGENTS.md).
- Privacy is local-first: zero network calls at runtime for tafsir data. The build tool downloads at maintainer time only.
- Errors flow through `Result<T, Failure>` ([lib/core/error/](../../../lib/core/error/)). No throws across boundaries.
- The same data must later back: a future "tafsir reader view" UI change and a tier III tafsir-embedding change. The repository surface must serve both without divergence.
- The bundled asset must be a *separate file* from `quran.sqlite` per the locked "many DBs, one per dataset" decision — so it can be versioned, attributed, and (eventually) replaced independently.

Stakeholders: end-users (correct, attributed tafsir), maintainers (build tool ergonomics, source verification), future tafsir UI (clean repository contract), future tier III semantic search (corpus is on disk and addressable by `AyahKey`), reviewers (PR diff stays interpretable thanks to deterministic build + manifest).

## Goals / Non-Goals

**Goals:**

- One canonical, attributed tafsir source vendored into the repo with a reproducible build process.
- Bundled SQLite asset that the app reads directly — no first-run downloads, no network calls.
- Runtime integrity verification that fails closed on tampering or build mistakes.
- Framework-free domain types and a `TafsirRepository` contract decoupled from SQLite, ready to power either the tafsir UI or the future embedding pipeline.
- A schema laid out **once** so future tafsir changes don't require migrations.
- Source attribution surfaced in Settings even before any tafsir UI exists.

**Non-Goals:**

- Tafsir UI (reader view, side panel, modal). Separate change.
- Showing tafsir under keyword search results. Separate change.
- Tafsir embeddings, tier III, or any vector work. Separate change ([add-semantic-search-design](../add-semantic-search-design/proposal.md)).
- Multiple tafsir sources or user-selectable defaults. al-Muyassar only for the MVP.
- Tafsir translations (English, etc.). Out of scope for the MVP.
- Schema migrations. v1 is locked.
- FTS5 search over tafsir text. The future keyword-search-over-tafsir change can add an FTS table; we don't ship one we won't read.

## Decisions

### D1: Source = al-Muyassar (King Fahd Complex)

- **Why:** Concise modern Arabic tafsir, widely redistributed under clear attribution terms, manageable size (~3–5 MB plain text), single-author voice keeps schema simple (one row per ayah), and the King Fahd Complex's license terms permit non-commercial redistribution with proper attribution.
- **Alternatives considered:**
  - *al-Saadi* — popular but ~5–10× the size and licensing varies by edition.
  - *Ibn Kathir* — comprehensive but >50 MB, multi-paragraph entries per ayah, ambiguous redistribution rights on some editions.
  - *al-Jalalayn* — public domain and tiny, but classical-style is harder to read for modern Arabic users and not the default the project's audience would expect.
- **Trade-off:** al-Muyassar is concise to the point of being terse for advanced study. That's acceptable for the MVP — users who want deeper exegesis are a V2+ audience, and adding richer tafsirs later is a separate change with its own licensing trail.

### D2: Storage = pre-built SQLite shipped as a Flutter asset, *separate file*

- **Why:** Mirrors `quran-data`'s storage decision so the runtime SQLite plumbing is reused. Separate file (not merged into `quran.sqlite`) means:
  1. Different ship/skip story per dataset (a future change could opt to download tafsir on demand without disturbing the Quran asset).
  2. Independent versioning — bumping al-Muyassar doesn't change the Quran DB's `dbSha256`.
  3. Clean reviewer workflow — a tafsir build artifact diffs separately from the Quran build artifact.
- **Alternatives considered:**
  - *Merge into `quran.sqlite`* — fewer files, but couples versioning and forces every future schema bump to touch both datasets at once.
  - *JSON assets per surah* — easy to diff but slow for `getTafsirForSurah` and impossible to share with a future MCP tafsir resource cleanly.
- **Trade-off:** Two DB files mean two integrity checks and two manifest entries. Mitigated by sharing the integrity-check code path (see D5).

### D3: SQLite access reuses `sqflite_common_ffi`

- **Why:** The Quran data layer already proves this works on Windows/macOS/Linux desktop, and `lib/data/quran/quran_database.dart` is the model. We add `lib/data/tafsir/tafsir_database.dart` following the same pattern: read-only mode, one-time copy to `path_provider.getApplicationSupportDirectory()/tafsir/muyassar.sqlite` if the platform requires a file path.
- **Trade-off:** Two database connections at runtime (one per asset). Negligible memory cost; both are read-only and small.

### D4: Schema (locked at v1)

```sql
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);  -- schema_version, source_name, source_version, source_url,
    -- license, retrieved_at_utc, text_sha256

CREATE TABLE tafsir (
  surah   INTEGER NOT NULL CHECK(surah BETWEEN 1 AND 114),
  ayah    INTEGER NOT NULL CHECK(ayah > 0),
  text    TEXT NOT NULL,
  PRIMARY KEY (surah, ayah)
);
CREATE INDEX idx_tafsir_surah ON tafsir(surah);
```

`schema_version = 1` recorded in `meta`. The runtime opens the DB read-only and refuses to start if `schema_version != 1`. No FTS5 table in v1 — the future "tafsir search" change will add `tafsir_fts` as a schema v2 with an explicit migration plan, exactly as `quran-data` locked v1 without prematurely adding the search surface.

### D5: Manifest layout — *sibling* manifest file per dataset

The Quran manifest lives at `assets/quran/manifest.json`. This change adds a *sibling* manifest at `assets/tafsir/manifest.json` rather than extending the Quran manifest. Reasons:

- Each dataset's manifest is self-contained and atomically updated by its own build tool.
- A multi-dataset manifest would couple build-tool invocations (rebuilding tafsir would need to read+rewrite the Quran manifest, fragile).
- Future datasets (topics, embeddings, more tafsirs) follow the same one-folder/one-manifest pattern without growing a central file.

The manifest schema mirrors the Quran one:

```json
{
  "schemaVersion": 1,
  "dataset": "tafsir-muyassar",
  "source": {
    "name": "al-Muyassar",
    "publisher": "King Fahd Complex for the Printing of the Holy Quran",
    "version": "<upstream version or release date>",
    "url": "<upstream URL>",
    "license": "<license summary; full text in THIRD_PARTY_NOTICES.md>",
    "retrievedAtUtc": "<ISO timestamp>"
  },
  "counts": { "ayahs": 6236 },
  "checksums": { "dbSha256": "<hex>", "textSha256": "<hex>" }
}
```

Note: `retrievedAtUtc` lives in the manifest only, not in the DB `meta` table, so the DB stays byte-deterministic across rebuilds (same lesson as `quran-data`'s implementation note).

### D6: Integrity check = manifest-driven, fail-closed, scoped to the tafsir asset

The check parallels the Quran integrity check but is independent of it. On first launch and after every app upgrade:

1. Open `assets/tafsir/muyassar.sqlite` read-only.
2. Read `meta.schema_version`, total tafsir-row count, distinct surah count.
3. Compare against `assets/tafsir/manifest.json`.
4. Compute SHA-256 of the bundled DB file and compare to `manifest.checksums.dbSha256`.
5. On mismatch → `Failure.dataIntegrity` → fatal error screen, **same screen** the Quran integrity check uses (we don't ship two near-identical error screens).

The check runs alongside (not nested inside) the Quran integrity check. Both must pass for the app to enter the main shell.

Cached subsequent runs skip the SHA-256 rehash if `manifest.checksums.dbSha256` is unchanged since last success, keyed in `SharedPreferences`. The cache key is **distinct** from the Quran cache key so they invalidate independently.

#### What if tafsir is missing on a clean checkout?

The build tool is maintainer-run; a brand-new clone does not have `muyassar.sqlite` until someone runs `just build-tafsir-db`. The app behaviour in that case is:

- Asset missing → `Failure.dataAccess` ("Tafsir asset not bundled. Maintainers: run `just build-tafsir-db`.")
- This trips the same fatal-error screen as a corrupt DB, with a message that distinguishes "not bundled" from "tampered."

This forces maintainers to run the tool before they can run the app, which is the right pressure. CI will run the tool in its setup step (documented in the implementation tasks).

### D7: Domain layer is framework-free

[lib/domain/tafsir/](../../../lib/domain/tafsir/) imports nothing from `flutter`, `sqflite`, or `riverpod`. It defines:

- `Tafsir { key: AyahKey, text: String, source: TafsirSourceRef }` — `TafsirSourceRef` is a lightweight reference (`name`, `version`) for inline display; full attribution comes from the repository's `getSource()` method.
- `TafsirSource { name, publisher, version, url, license, retrievedAtUtc }` — full attribution value object.
- `abstract class TafsirRepository`:

```dart
abstract class TafsirRepository {
  Future<Result<Tafsir>> getTafsirForAyah(AyahKey key);
  Future<Result<List<Tafsir>>> getTafsirForSurah(int number);
  Future<Result<TafsirSource>> getSource();
}
```

`AyahKey` is the existing value object from [lib/domain/quran/ayah_key.dart](../../../lib/domain/quran/ayah_key.dart). The tafsir domain reuses it rather than defining its own key type — they're semantically the same, and sharing keeps lookups joinable across the two datasets in the future without conversions.

The SQLite implementation lives in [lib/data/tafsir/](../../../lib/data/tafsir/) and is the only place that imports `sqflite_common_ffi`. This is the seam the future tafsir UI and the tier III embedding builder will both reuse.

### D8: Build tool = maintainer-run, idempotent, network-gated, byte-deterministic

`tool/build_tafsir_db.dart`:

- **Inputs:** source URL (default pinned), expected source SHA-256 (default pinned), output directory (default `assets/tafsir/`).
- **Steps:** download → SHA-256 verify against pinned hash → parse the upstream format into `(surah, ayah, text)` tuples → write SQLite + manifest.
- **Determinism:** sorted inserts, `journal_mode=DELETE`, `VACUUM`, `retrievedAtUtc` stored in manifest only, integer `surah`/`ayah` columns. Same input → same `dbSha256`.
- **License precondition:** the tool refuses to emit output if the upstream archive's license file is missing or if its SHA does not match a recorded expected hash. This guards against silently shipping content under an unrecognized license.
- **Count precondition:** the tool refuses to emit output if the parsed count is not exactly 6,236 ayahs (matches the Quran corpus). Discrepancies likely mean a parse bug.
- **`just build-tafsir-db`** wraps the invocation. Documented in the *Commands* table of [AGENTS.md](../../../AGENTS.md).
- **Dev-only dep graph:** `http`, `archive`, `crypto`, `sqlite3` are already in `dev_dependencies` for the Quran build tool and are reused. No new dep graph entries.

### D9: Riverpod wiring

- `tafsirDatabaseProvider` (FutureProvider) — opens the bundled tafsir DB.
- `tafsirRepositoryProvider` (Provider) — depends on the database provider, exposes `TafsirRepository`.
- `tafsirIntegrityProvider` (FutureProvider) — runs the tafsir integrity check exactly once per launch.
- A composite `bootstrapProvider` (or whatever the existing equivalent is in `lib/app/state/`) gates the UI on **both** Quran and tafsir integrity passing.

### D10: Logging and error surface

All boundary methods log via `appLogger` ([lib/core/logging/logger.dart](../../../lib/core/logging/logger.dart)). Failures map to existing `Failure` subtypes:

- `Failure.dataIntegrity` — manifest mismatch, schema mismatch, count mismatch.
- `Failure.dataAccess` — DB open or read errors, asset missing.
- `Failure.notFound` — unknown ayah key.

No `print`. No throws across the repository boundary.

### D11: Where the asset lives at runtime

Same as the Quran asset: read-only via `sqflite_common_ffi`. If the platform requires a file path, fall back to a one-time copy into `path_provider.getApplicationSupportDirectory()/tafsir/muyassar.sqlite` after verifying the asset SHA-256 against the manifest. The integrity check verifies the asset bytes, not the copied file (same pattern as the Quran data layer).

### D12: Documentation deltas land in *this* change

[AGENTS.md](../../../AGENTS.md) currently says "search UX (FTS5 index exists)" under "Not yet implemented" — that's stale after PR #14. The tafsir change updates the "Wired today" section to:

1. Mention the merged keyword search (basic FTS5 query + UI + repository method).
2. Mention the bundled tafsir data layer with its substrate-only scope.
3. Remove "search UX" from "Not yet implemented" (it's implemented; future enhancements are separate changes).

This rides along with the tafsir change rather than being a standalone docs PR, per the *Keep docs current* rule in [AGENTS.md](../../../AGENTS.md). The implementer adds these doc edits in the same branch.

## Risks / Trade-offs

- **License compliance for al-Muyassar** → record full attribution in `THIRD_PARTY_NOTICES.md`, surface in Settings, pin source version in the manifest, add a build-tool guard that refuses to run if the upstream license file is missing or hash-changed.
- **Asset bloat** → al-Muyassar is concise (~3–5 MB). Cap at 10 MB. CI check on PR diff size warns if the asset changes; mismatched `dbSha256` without a build-tool change should make reviewers suspicious.
- **Schema migration debt** → locking v1 without FTS5 means a future "tafsir search" change ships v2 + a migration. That's acceptable — the alternative (premature FTS) ships unused indexes and an unused tokenizer choice that may turn out wrong for tafsir text.
- **Two separate manifests increase reviewer cognitive load** → mitigated by identical layout (same field names, same checksum structure). Once the third dataset (topics) lands with the same pattern, it stops feeling like duplication and starts feeling like a convention.
- **Build tool runs on every clean checkout (no committed asset)** → contradicts the Quran data layer's "asset is committed" pattern. Decision: **the tafsir asset IS committed**, same as Quran. CI verifies the committed `dbSha256` matches by re-running the tool in a check job. Reviewers can re-derive locally.

Actually re-reading D6's "asset missing on clean checkout" subsection — that scenario is reserved for *contributors who haven't pulled LFS* or *partial checkouts*, not normal clones. The expected default is "asset is committed, fresh clone works out of the box." The fail-closed behaviour exists for the broken-state case, not the normal case. The implementation tasks must commit the asset and verify it's not gitignored.

- **al-Muyassar source format is less standardized than Tanzil's plain text** → the build tool's parse step is the riskiest non-trivial work. Mitigation: small focused parse-step tests in `test/tool/` that pin a few known ayahs (e.g. 1:1, 2:255, 114:6) against expected text.
- **Two DBs share an integrity-error screen** → the screen needs to distinguish *which* dataset failed and *why*. Implementation: `Failure.dataIntegrity` already carries a message field; the error screen renders it. No new failure type needed.

## Migration Plan

This is a greenfield capability — no existing tafsir data. Deployment steps:

1. Maintainer runs `just build-tafsir-db` once locally, commits `assets/tafsir/muyassar.sqlite` and `assets/tafsir/manifest.json`.
2. PR includes the build tool, generated asset, manifest, `THIRD_PARTY_NOTICES.md` entry, Settings UI delta, and the [AGENTS.md](../../../AGENTS.md) "Wired today" delta.
3. CI runs `flutter test` (covers integrity check and repository contract tests against the real bundled DB).
4. Rollback: revert the PR. The app continues to ship; Settings loses the tafsir source row; no user data is destroyed (no user-facing tafsir feature has shipped yet).

For future source bumps (e.g. a corrected al-Muyassar revision): re-run the build tool, expect new `dbSha256` and `textSha256`, bump `source.version` in the manifest, document the diff, and ship as a separate change.

## Open Questions

- **Where exactly does the upstream al-Muyassar archive live?** The Saudi Awqaf and King Fahd Complex publish PDFs and structured JSON via different distribution paths; the most reliable redistributable form (mirror or API) needs to be confirmed by the implementer before pinning the URL. If no satisfactory redistributable source exists, the change pauses for licensing clearance rather than ships with an ambiguous trail.
- **Does the `TafsirSourceRef` (lightweight inline reference) duplicate `TafsirSource` (full attribution)?** Probably yes for v1. If the future UI never needs inline attribution per row, we drop `TafsirSourceRef` in the tafsir UI change. For now, keep `Tafsir.text` and `Tafsir.key` only; lookups go through `getSource()` for attribution. Final answer: drop `TafsirSourceRef` from this change's domain — single-source MVP means attribution is global, not per-row.
- **Should the tafsir DB share `meta` table conventions with the Quran DB so a shared `MetaReader` utility can be extracted?** Yes, but the extraction can wait until the third dataset (topics) lands and the pattern is provably stable. Don't pre-abstract.
