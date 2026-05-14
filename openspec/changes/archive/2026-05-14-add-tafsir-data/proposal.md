## Why

PR #14 shipped keyword search on top of the bundled Quran corpus, and the next two roadmap items both depend on a *second* corpus on disk: a future "tafsir reader" view (per [IDEA.md](../../../IDEA.md) V1) and tier III of the semantic search subtree (see [add-semantic-search-design](../add-semantic-search-design/proposal.md)). Both want the same substrate — an integrity-checked, attributed tafsir dataset that can be queried by `AyahKey` — so it deserves its own change rather than getting bolted onto whichever UI feature lands first. Tafsir is also where IDEA.md's "only with verified licensing" rule is sharpest: pinning the source, license, and attribution up front protects the project's *trustworthy before powerful* principle.

## What Changes

- Vendor **al-Muyassar** (King Fahd Complex for the Printing of the Holy Quran) as the canonical tafsir source for the MVP, with the upstream URL, version, and license terms recorded in-repo.
- Ship a pre-built **SQLite asset** at `assets/tafsir/muyassar.sqlite` containing a `tafsir` table keyed by `(surah, ayah)` plus a `meta` table mirroring the `quran-data` capability's schema-lock pattern. The asset is a *separate* file from `quran.sqlite` — per the locked "many DBs, one per dataset" decision.
- Add a **build-time tool** (`tool/build_tafsir_db.dart`) that downloads/normalizes the al-Muyassar source and emits `muyassar.sqlite` plus a sibling `manifest.json` (or an entry in a multi-dataset manifest — chosen in design.md) with SHA-256 checksums, ayah count, and source attribution. Tool runs on maintainer machines only.
- Add a **runtime integrity check** scoped to the tafsir asset that fails closed on SHA mismatch, schema mismatch, or row-count mismatch, mirroring the existing Quran integrity check.
- Add a **framework-free domain layer** under `lib/domain/tafsir/` — `Tafsir` value type and a `TafsirRepository` contract returning `Result<T, Failure>`. Domain types stay reusable for the future tafsir UI and the future tier III embedding work.
- Add a **SQLite-backed implementation** under `lib/data/tafsir/` using the same `sqflite_common_ffi` plumbing as `quran-data`, plus a Riverpod provider exposing the repository to the rest of the app.
- Add **source attribution surfaces**: a "Tafsir source" row in the Settings page, and an entry in [THIRD_PARTY_NOTICES.md](../../../THIRD_PARTY_NOTICES.md). Settings shows attribution even though no consumer UI exists yet — the data is on disk and the user has a right to know what's bundled.
- Add a `just build-tafsir-db` recipe and update `just check` to keep working when the new asset is missing during a clean checkout (until the maintainer runs the tool).

Not in scope: tafsir UI (reader view, side panel, tap-to-reveal); tafsir-in-keyword-search results; tafsir embeddings (tier III); multi-tafsir support; tafsir translations. Each is a follow-up change.

## Capabilities

### New Capabilities

- `tafsir-data`: Canonical tafsir corpus on disk, integrity-checked at runtime, exposed via a repository contract that returns domain types and source attribution. Covers source vendoring policy, build-time DB generation, runtime integrity rules, repository surface, and attribution requirements. Mirrors the `quran-data` spec's shape so reviewers and downstream changes can rely on a consistent pattern across bundled datasets.

### Modified Capabilities

<!-- None. Settings page receives a new section but that is UI-only and doesn't change the `app-shell` capability's spec-level behavior. -->

## Impact

- **New dependencies (runtime):** none. Reuses the existing `sqflite_common_ffi`, `path_provider`, `crypto`, and `path` from the Quran data layer.
- **New dependencies (dev/tooling only):** none new in principle — `http`, `archive`, `crypto`, and `sqlite3` are already wired under `dev_dependencies` for the Quran build tool and are reused here.
- **Asset bundling:** registers `assets/tafsir/muyassar.sqlite` and the tafsir entry in the manifest under `flutter > assets` in [pubspec.yaml](../../../pubspec.yaml). Adds ~3–5 MB to the app bundle (al-Muyassar is concise).
- **Repo additions:**
  - `tool/build_tafsir_db.dart` (maintainer-run, idempotent, byte-deterministic where the source allows)
  - `lib/domain/tafsir/` (models + repository contract)
  - `lib/data/tafsir/` (SQLite implementation + integrity checker)
  - `assets/tafsir/muyassar.sqlite` + manifest entry (generated, committed)
  - `THIRD_PARTY_NOTICES.md` entry for al-Muyassar / King Fahd Complex
- **Justfile:** new `just build-tafsir-db` recipe.
- **Tests:** integrity-check unit tests, repository contract tests against the real bundled DB, source attribution widget test, missing-ayah scenario, no-network guard.
- **Platforms affected:** Windows, macOS, Linux — same as Quran data layer.
- **Risk hot-spots:** licensing trail for al-Muyassar (must record every required attribution clause), source format inconsistency (the upstream distribution may need normalization steps documented in the build tool), schema decisions that need to play nicely with the future tier III embedding sidecar.
- **Documentation:** [AGENTS.md](../../../AGENTS.md) gets an update during *this* implementation to mention both the merged keyword search (PR #14) and the new tafsir data layer under "wired today" — that docs delta rides along with this change rather than being its own change.
- **Branching:** implementation lands on its own `feature/add-tafsir-data` branch off `develop` and ships as a single PR per the *one change, one branch* rule in [AGENTS.md](../../../AGENTS.md).
