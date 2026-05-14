## Why

Two downstream changes both need a *topical concordance* of the Quran on disk: a future "topic" search mode chip in the Search page (per IDEA.md "List ayahs that mention X"), and tier II of the semantic search subtree (see [add-semantic-search-design](../add-semantic-search-design/proposal.md)) which embeds topics for meaning-based discovery. Both want the same substrate — a hierarchical, attributed, integrity-checked topic dataset that maps `(surah, ayah)` ↔ `topic_id` — so it deserves its own change rather than getting bolted onto whichever consumer feature lands first. The dataset is also where IDEA.md's "only with verified licensing" rule kicks in: pinning source, license, and attribution up front protects the project's *trustworthy before powerful* principle. This change is intentionally independent of [add-tafsir-data](../add-tafsir-data/proposal.md) and can be implemented in parallel.

## What Changes

- Vendor the **King Fahd Complex's *Mu'jam Al-Mufahras Al-Maudu'i li Ayat al-Quran al-Karim*** as the canonical topical concordance, with upstream URL, version, and license terms recorded in-repo.
- Ship a pre-built **SQLite asset** at `assets/topics/mujam.sqlite` containing two tables (`topics` with a hierarchy, `topic_ayahs` joining each topic to one or more `(surah, ayah)` pairs) plus a `meta` table mirroring the `quran-data` and `tafsir-data` schema-lock pattern. Separate file from `quran.sqlite` and `muyassar.sqlite` per the locked "many DBs, one per dataset" decision.
- Add a **build-time tool** (`tool/build_topics_db.dart`) that downloads/normalizes the Mu'jam source and emits `mujam.sqlite` plus a sibling `manifest.json` with SHA-256 checksums, topic count, link count, and source attribution. Tool runs on maintainer machines only.
- Add a **runtime integrity check** scoped to the topics asset that fails closed on SHA mismatch, schema mismatch, count mismatch, or orphan links (i.e. a link pointing to an ayah that doesn't exist in the bundled Quran DB).
- Add a **framework-free domain layer** under `lib/domain/topics/` — `Topic`, `AyahTopicLink` value types, hierarchy helpers, and a `TopicsRepository` contract returning `Result<T, Failure>`.
- Add a **SQLite-backed implementation** under `lib/data/topics/` using the same `sqflite_common_ffi` plumbing as `quran-data` and `tafsir-data`, plus a Riverpod provider exposing the repository to the rest of the app.
- Add **source attribution surfaces**: a "Topical index source" row in the Settings page, and an entry in [THIRD_PARTY_NOTICES.md](../../../THIRD_PARTY_NOTICES.md). Settings shows attribution even though no consumer UI exists yet.
- Add a `just build-topics-db` recipe to the [Justfile](../../../Justfile).

Not in scope: topic UI (browse screen, filter chip, hierarchy tree); topic search mode in the Search page; topic embeddings (tier II); MCP topic tools; per-topic playback. Each is a follow-up change.

## Capabilities

### New Capabilities

- `topics-data`: Canonical topical concordance on disk, integrity-checked at runtime, exposed via a repository contract that returns domain types (topics, hierarchy, ayah links) and source attribution. Covers source vendoring policy, build-time DB generation, runtime integrity rules, repository surface, and attribution requirements. Mirrors the `quran-data` and (concurrent) `tafsir-data` spec patterns.

### Modified Capabilities

<!-- None. Settings page receives a new section but that is UI-only and doesn't change the `app-shell` capability's spec-level behavior. -->

## Impact

- **New dependencies (runtime):** none. Reuses `sqflite_common_ffi`, `path_provider`, `crypto`, and `path` already wired by the Quran data layer.
- **New dependencies (dev/tooling only):** none new — `http`, `archive`, `crypto`, `sqlite3` already in `dev_dependencies`.
- **Asset bundling:** registers `assets/topics/mujam.sqlite` and `assets/topics/manifest.json` under `flutter > assets` in [pubspec.yaml](../../../pubspec.yaml). Adds an estimated ~1–3 MB (topics + links are small compared to text corpora).
- **Repo additions:**
  - `tool/build_topics_db.dart` (maintainer-run, idempotent, byte-deterministic)
  - `lib/domain/topics/` (models + repository contract)
  - `lib/data/topics/` (SQLite implementation + integrity checker)
  - `assets/topics/mujam.sqlite` + `manifest.json` (generated, committed)
  - `THIRD_PARTY_NOTICES.md` entry for the Mu'jam / King Fahd Complex
- **Justfile:** new `just build-topics-db` recipe.
- **Tests:** integrity-check unit tests, repository contract tests against the real bundled DB (covering hierarchy traversal and lookups in both directions), source attribution widget test, orphan-link scenario, no-network guard.
- **Platforms affected:** Windows, macOS, Linux — same as Quran/tafsir data layers.
- **Risk hot-spots:** licensing trail for the Mu'jam (King Fahd Complex's redistribution terms must be confirmed before pinning), source format normalization (the upstream may ship as PDF, HTML, or structured data — implementer chooses the most reliable redistributable form), hierarchy correctness (broken parent links must be caught at build time, not at runtime).
- **Documentation:** [AGENTS.md](../../../AGENTS.md) gets an update during *this* implementation to mention the new topics data layer under "wired today." If `add-tafsir-data` lands first, its AGENTS.md edits provide a model; if this change lands first, it does the equivalent edits and `add-tafsir-data` extends them.
- **Branching:** implementation lands on its own `feature/add-topical-index-data` branch off `develop` and ships as a single PR per the *one change, one branch* rule in [AGENTS.md](../../../AGENTS.md).
- **Independence:** zero overlap with [add-tafsir-data](../add-tafsir-data/proposal.md) in code paths, files, or asset directories. The only shared mutation point is the Settings page (both add a new section) and `THIRD_PARTY_NOTICES.md` (both add a new entry) — both are append-only and conflict-free.
