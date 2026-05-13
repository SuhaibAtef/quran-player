## Why

The bootstrap-foundation change shipped an empty app shell — every MVP feature in [IDEA.md](../../../IDEA.md) (surah list, ayah display, search, bookmarks, MCP server) is blocked on having a verified, queryable Quran corpus on disk. The IDEA.md *Project Principle* — "trustworthy before powerful" — means the very first feature change has to nail down: a single canonical source, integrity checks, and a stable repository contract. Once this lands, UI, audio, and MCP slices can each plug into it without re-litigating data correctness.

## What Changes

- Vendor the **Tanzil Uthmani plain-text** Quran (v1.0.2) as the canonical source for the MVP, with the upstream URL, version, and license terms recorded in-repo.
- Ship a pre-built **SQLite asset** at `assets/quran/quran.sqlite` containing `surahs`, `ayahs`, and an `ayah_fts` FTS5 virtual table for later search work.
- Add a **build-time tool** (`tool/build_quran_db.dart`) that downloads/normalizes the Tanzil source and emits the SQLite asset + a `manifest.json` with SHA-256 checksums, surah/ayah counts, and source attribution. The tool is run by maintainers, not at app startup.
- Add a **runtime integrity check** that runs once on first launch (and after upgrades): verifies the bundled DB matches the manifest, that there are exactly 114 surahs with the expected ayah counts (6,236 total), and no duplicate `(surah, ayah)` keys. On mismatch, the app surfaces a fatal error rather than serving wrong data.
- Add a **framework-free domain layer** under `lib/domain/quran/` — `Surah`, `Ayah`, `AyahKey`, `QuranSource` value types — and a `QuranRepository` contract returning `Result<T, Failure>`.
- Add a **SQLite-backed implementation** under `lib/data/quran/` using `sqflite_common_ffi` (Windows/macOS/Linux desktop) plus a Riverpod provider that exposes the repository to the UI and (later) the MCP server.
- Add **source attribution metadata** (`QuranSource { name, version, url, license, retrievedAt }`) surfaced through the repository so the UI can display it (per IDEA.md safety rules).
- Wire the existing Surahs placeholder page to load the surah list from the repository as the first consumer (proof-of-life; full reader UI is a later change).

Not in scope: ayah-reader UI polish, search UI, audio, bookmarks, MCP server, translations. Each is a follow-up change.

## Capabilities

### New Capabilities

- `quran-data`: Canonical Quran corpus on disk, integrity-checked at runtime, exposed via a repository contract that returns domain types and source attribution. Covers source vendoring policy, build-time DB generation, runtime integrity rules, repository surface, and attribution requirements.

### Modified Capabilities

<!-- None — this is the first feature capability after the foundation. -->

## Impact

- **New dependencies (runtime):** `sqflite_common_ffi`, `path` (transitive), `path_provider` (first need for an OS data dir surfaces here — see CLAUDE.md *Notes for future work*).
- **New dependencies (dev/tooling only):** `http` (download Tanzil source), `archive` (unzip), `crypto` (SHA-256), `sqlite3` (build-time DB writer). Wired under `dev_dependencies` so they don't ship with the app.
- **Asset bundling:** registers `assets/quran/quran.sqlite` and `assets/quran/manifest.json` in [pubspec.yaml](../../../pubspec.yaml). Adds ~5–7 MB to the app bundle.
- **Repo additions:**
  - `tool/build_quran_db.dart` (maintainer-run, idempotent)
  - `lib/domain/quran/` (models + repository contract)
  - `lib/data/quran/` (SQLite implementation + integrity checker)
  - `lib/features/surahs/state/surahs_provider.dart` (first consumer)
  - `assets/quran/quran.sqlite` + `manifest.json` (generated, committed)
  - `THIRD_PARTY_NOTICES.md` entry for Tanzil
- **Justfile:** new `just build-quran-db` recipe that runs the build tool.
- **Tests:** integrity-check unit tests, repository contract tests against the real bundled DB, regression test on the surah list (114 surahs, total 6,236 ayahs).
- **Platforms affected:** Windows, macOS, Linux. `sqflite_common_ffi` requires the SQLite native lib — bundled on Windows automatically; macOS/Linux usually have a system one but we should verify in the build tasks.
- **Risk hot-spots:** licensing trail for the Tanzil text (must be recorded), DB file size (must stay under a sane cap so PR review is reasonable), schema migrations (we lock v1 now to avoid churn later).
