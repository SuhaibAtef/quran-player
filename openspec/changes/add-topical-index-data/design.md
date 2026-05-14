## Context

The `quran-data` capability shipped the substrate pattern for bundled, attributed, integrity-checked corpora: maintainer build tool → byte-deterministic SQLite asset → manifest with SHA-256 checksums → framework-free domain layer → SQLite-backed implementation behind a `Result`-returning repository contract → Riverpod exposure → fail-closed runtime integrity check → Settings attribution. This change reuses that pattern for a *third* dataset (after `quran-data` and the concurrent `tafsir-data`): the King Fahd Complex's *Mu'jam Al-Mufahras Al-Maudu'i li Ayat al-Quran al-Karim* — a topical concordance mapping each ayah to one or more subjects, with a topic hierarchy.

Constraints:

- Desktop-only MVP (Windows primary; macOS/Linux later).
- Dart SDK `^3.11.0`, Flutter 3.41+, ForUI `^0.21.3` per [AGENTS.md](../../../AGENTS.md).
- Privacy is local-first: zero network calls at runtime for topic data. The build tool downloads at maintainer time only.
- Errors flow through `Result<T, Failure>` ([lib/core/error/](../../../lib/core/error/)). No throws across boundaries.
- The same data must later back: a future "topic" search mode chip in the Search page and a tier II topic-embedding change. The repository surface must serve both without divergence.
- The bundled asset must be a *separate file* from `quran.sqlite` and `muyassar.sqlite` per the locked "many DBs, one per dataset" decision.

Stakeholders: end-users (correct, attributed topical groupings), maintainers (build tool ergonomics, source verification), future topic UI (clean repository contract with hierarchy and reverse lookups), future tier II semantic search (corpus is on disk and embeddings can read it via the same repository), reviewers (PR diff stays interpretable thanks to deterministic build + manifest).

## Goals / Non-Goals

**Goals:**

- One canonical, attributed topical concordance vendored into the repo with a reproducible build process.
- Bundled SQLite asset that the app reads directly — no first-run downloads, no network calls.
- Runtime integrity verification that fails closed on tampering or build mistakes (including orphan-link detection).
- Framework-free domain types covering both *topics* (hierarchy) and *links* (many-to-many to ayahs), and a `TopicsRepository` contract decoupled from SQLite.
- A schema laid out **once** so future topic changes don't require migrations.
- Source attribution surfaced in Settings even before any topic UI exists.

**Non-Goals:**

- Topic UI (browse screen, filter chip, hierarchy tree, breadcrumbs). Separate change.
- Topic search mode in the Search page. Separate change.
- Topic embeddings, tier II, or any vector work. Separate change ([add-semantic-search-design](../add-semantic-search-design/proposal.md)).
- Multiple topic sources or user-selectable defaults. Mu'jam Al-Mufahras Al-Maudu'i only for the MVP.
- Translations of topic labels (English, etc.). Out of scope for the MVP.
- Schema migrations. v1 is locked.
- Per-topic playback or per-topic bookmarks. Future changes.

## Decisions

### D1: Source = Mu'jam Al-Mufahras Al-Maudu'i li Ayat al-Quran al-Karim (King Fahd Complex)

- **Why:** Authoritative Saudi compilation, redistributable with proper attribution under the Complex's terms, hierarchical structure (top-level subject → sub-subject → ayah links) maps cleanly to a parent-child SQL schema, broad enough to be useful for the kinds of "list ayahs about patience / family / charity" queries the IDEA.md examples suggest.
- **Alternatives considered:**
  - *Egyptian Awqaf topical compilations* — comparable in coverage but redistribution status varies by edition; harder to pin a clear license trail.
  - *Community-maintained datasets on GitHub (e.g., quran-json topic tags)* — convenient but lineage often unclear; using one of these would mean shipping topics without a verified attribution chain, which contradicts the project's safety rules.
  - *Auto-tag with NeoAraBERT* — appealing for completeness but yields opinionated tags; would mean shipping algorithmically derived topics with no scholarly authority. The whole point of bundling a vetted source is to *not* let the model invent religious categorizations.
- **Trade-off:** A single authoritative source means coverage gaps will exist (some users will expect topics this compilation doesn't include). Acceptable for MVP. Future changes can layer in additional sources with explicit per-source attribution rather than blending categories silently.

### D2: Storage = pre-built SQLite shipped as a Flutter asset, *separate file*

Same reasoning as the `quran-data` and `tafsir-data` storage decisions. Two tables in one file (`topics` + `topic_ayahs`) — both belong to the same dataset, share the same source, and version together.

- **Alternatives considered:**
  - *Merge into `quran.sqlite`* — couples versioning unhelpfully.
  - *JSON assets* — easy to diff but slow for hierarchy traversal, awkward for tier II embedding builder.
- **Trade-off:** Third DB file means a third integrity check and a third manifest. Mitigated by sharing the integrity-check code path with `quran-data` and `tafsir-data`.

### D3: SQLite access reuses `sqflite_common_ffi`

Same pattern as `quran-data` and `tafsir-data`. Read-only at runtime, one-time copy to app-support dir if the platform requires a file path.

### D4: Schema (locked at v1)

```sql
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);  -- schema_version, source_name, source_version, source_url,
    -- license, retrieved_at_utc, text_sha256

CREATE TABLE topics (
  id          INTEGER PRIMARY KEY,             -- stable upstream id when available; else build-tool-assigned
  parent_id   INTEGER REFERENCES topics(id),   -- nullable for top-level
  label_ar    TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0       -- preserves upstream ordering
);
CREATE INDEX idx_topics_parent ON topics(parent_id);

CREATE TABLE topic_ayahs (
  topic_id  INTEGER NOT NULL REFERENCES topics(id),
  surah     INTEGER NOT NULL CHECK(surah BETWEEN 1 AND 114),
  ayah      INTEGER NOT NULL CHECK(ayah > 0),
  PRIMARY KEY (topic_id, surah, ayah)
);
CREATE INDEX idx_topic_ayahs_ayah ON topic_ayahs(surah, ayah);
CREATE INDEX idx_topic_ayahs_topic ON topic_ayahs(topic_id);
```

`schema_version = 1` recorded in `meta`. The runtime opens the DB read-only and refuses to start if `schema_version != 1`.

The two indexes on `topic_ayahs` are deliberate:

- `(surah, ayah)` index → fast "what topics is this ayah in" lookup (the reverse direction the reader UI and tier II will both need).
- `topic_id` index → fast "list ayahs in this topic" lookup.

### D5: Manifest layout — sibling manifest file per dataset

```json
{
  "schemaVersion": 1,
  "dataset": "topics-mujam",
  "source": {
    "name": "Mu'jam Al-Mufahras Al-Maudu'i li Ayat al-Quran al-Karim",
    "publisher": "King Fahd Complex for the Printing of the Holy Quran",
    "version": "<upstream version or release date>",
    "url": "<upstream URL>",
    "license": "<license summary; full text in THIRD_PARTY_NOTICES.md>",
    "retrievedAtUtc": "<ISO timestamp>"
  },
  "counts": {
    "topics": <int>,
    "links":  <int>
  },
  "checksums": { "dbSha256": "<hex>", "textSha256": "<hex>" }
}
```

Same per-dataset isolation reasoning as `tafsir-data`: each dataset owns its own manifest under its own asset directory.

### D6: Integrity check = manifest-driven, fail-closed, scoped to the topics asset

On first launch and after every app upgrade:

1. Open `assets/topics/mujam.sqlite` read-only.
2. Read `meta.schema_version`, total topic count, total link count, root-topic count.
3. Compare against `assets/topics/manifest.json`.
4. Compute SHA-256 of the bundled DB file and compare to `manifest.checksums.dbSha256`.
5. Validate that every `topic.parent_id` references an existing `topics.id` (no orphan parent pointers).
6. Validate that every `topic_ayahs.(surah, ayah)` references a real ayah in the bundled Quran DB (no orphan ayah links).
7. On mismatch → `Failure.dataIntegrity` → fatal error screen (same screen as the other integrity checks).

Cached subsequent runs skip the SHA-256 rehash if the manifest checksum is unchanged; cache key distinct from Quran and tafsir cache keys.

Validating against the Quran DB means the topics integrity check has an ordering dependency on the Quran DB being loaded. The bootstrap gate (see D9) ensures Quran integrity runs first or in parallel with topics integrity in a way that produces a coherent failure message if either trips.

### D7: Domain layer is framework-free

[lib/domain/topics/](../../../lib/domain/topics/) imports nothing from `flutter`, `sqflite`, or `riverpod`. It defines:

- `Topic { id: int, parentId: int?, labelAr: String, sortOrder: int }`
- `TopicNode { topic: Topic, children: List<TopicNode> }` — convenience tree shape returned by `getTopicTree()` to keep UI code thin.
- `TopicAyahLink { topicId: int, key: AyahKey }` — joins use the existing `AyahKey` from `lib/domain/quran/ayah_key.dart`.
- `TopicsSource { name, publisher, version, url, license, retrievedAtUtc }` — full attribution.
- `abstract class TopicsRepository`:

```dart
abstract class TopicsRepository {
  Future<Result<List<Topic>>> listTopics();
  Future<Result<TopicNode>> getTopicTree();                    // entire hierarchy
  Future<Result<List<AyahKey>>> getAyahsForTopic(int topicId);
  Future<Result<List<Topic>>> getTopicsForAyah(AyahKey key);
  Future<Result<TopicsSource>> getSource();
}
```

The SQLite implementation lives in [lib/data/topics/](../../../lib/data/topics/) and is the only place that imports `sqflite_common_ffi`. This is the seam the future topic UI and the tier II embedding builder will both reuse.

### D8: Build tool = maintainer-run, idempotent, network-gated, byte-deterministic

`tool/build_topics_db.dart`:

- **Inputs:** source URL (default pinned), expected source SHA-256 (default pinned), output directory (default `assets/topics/`).
- **Steps:** download → SHA-256 verify against pinned hash → parse upstream into `Topic` rows + `topic_ayahs` rows → write SQLite + manifest.
- **Determinism:** sorted inserts by `(parent_id NULLS FIRST, sort_order, id)` and `(topic_id, surah, ayah)`, `journal_mode=DELETE`, `VACUUM`, `retrieved_at_utc` in manifest only.
- **License precondition:** the tool refuses to emit output if the upstream license file is missing or hash-changed.
- **Validation preconditions:** before commit, the tool validates that every parent_id resolves, every (surah, ayah) link is in 1..114 / 1..ayahCount[surah] (read from the already-built Quran DB), and that there are no duplicate links.
- **`just build-topics-db`** wraps the invocation. Documented in the *Commands* table of [AGENTS.md](../../../AGENTS.md).
- **Dev-only dep graph:** reuses existing dev deps from the Quran build tool.

### D9: Riverpod wiring and bootstrap gate

- `topicsDatabaseProvider` (FutureProvider) — opens the bundled topics DB.
- `topicsRepositoryProvider` (Provider) — depends on the database provider, exposes `TopicsRepository`.
- `topicsIntegrityProvider` (FutureProvider) — runs the topics integrity check exactly once per launch.

The composite app bootstrap gate now waits for *three* integrity checks (Quran, tafsir, topics) before entering the main shell. The gate's logic:

- Quran integrity is the prerequisite for both tafsir and topics integrity (their orphan-check steps query the Quran DB).
- Tafsir and topics integrity can run in parallel after Quran integrity succeeds.
- If any one trips, the fatal error screen names the failing dataset.

If `add-tafsir-data` has not landed yet at the time this change merges, the gate waits for Quran + topics only and a follow-up edit to the gate code lands in the tafsir change. The bootstrap module is intentionally tiny precisely so these additions are mechanical.

### D10: Logging and error surface

Same `Failure` taxonomy: `Failure.dataIntegrity`, `Failure.dataAccess`, `Failure.notFound`. No `print`, no throws across the repository boundary.

### D11: Where the asset lives at runtime

Same as the Quran asset: read-only via `sqflite_common_ffi`. If the platform requires a file path, fall back to a one-time copy into `path_provider.getApplicationSupportDirectory()/topics/mujam.sqlite` after verifying the asset SHA-256 against the manifest.

### D12: Documentation deltas land in *this* change

[AGENTS.md](../../../AGENTS.md) gains a "Topics data layer" line under *Wired today*, and `lib/domain/topics/` + `lib/data/topics/` are added to the *Lib layout* tree. The *Commands* table gains `just build-topics-db`. If this change lands after `add-tafsir-data`, the *Wired today* update extends what that change added. If it lands first, the docs delta is foundational and `add-tafsir-data` builds on it.

## Risks / Trade-offs

- **License compliance for the Mu'jam** → record full attribution in `THIRD_PARTY_NOTICES.md`, surface in Settings, pin source version in the manifest, add a build-tool guard that refuses to run if the upstream license file is missing or hash-changed. If the King Fahd Complex's redistribution terms are unclear, the change pauses on licensing clearance rather than ships with an ambiguous trail.
- **Topic hierarchy correctness** → parent-id orphans and cycles must be caught at build time. The build tool runs a transitive-closure check before committing the DB. Runtime integrity check catches the simpler "parent_id doesn't exist" case as a backstop, but the build tool is the primary guard.
- **Orphan ayah links** → every `(surah, ayah)` link must reference a real ayah in the Quran DB. The build tool validates this by reading the already-built Quran DB; the runtime integrity check re-validates as a backstop.
- **Upstream source format uncertainty** → the Mu'jam is distributed in multiple forms (PDFs, structured exports, third-party JSON). The implementer picks the most reliable form (preferably a structured export from the King Fahd Complex directly) and documents the parse step in the build tool. If only PDFs are available, that's a non-starter — flag for re-scoping rather than ship a fragile PDF parser.
- **Three DBs and three manifests** → mitigated by the now-stable convention. By this point, reviewers should recognize the shape immediately. If the pattern feels duplicative, a follow-up "extract dataset bootstrap" change can factor out shared code — but only after the third dataset proves the pattern is the same.

## Migration Plan

Greenfield capability. Steps mirror `add-tafsir-data`:

1. Maintainer runs `just build-topics-db` once locally, commits `assets/topics/mujam.sqlite` and `assets/topics/manifest.json`.
2. PR includes the build tool, generated asset, manifest, `THIRD_PARTY_NOTICES.md` entry, Settings UI delta, and the [AGENTS.md](../../../AGENTS.md) "Wired today" delta.
3. CI runs `flutter test` (covers integrity check and repository contract tests against the real bundled DB).
4. Rollback: revert the PR. The app continues to ship; Settings loses the topics source row; no user data is destroyed (no user-facing topics feature has shipped yet).

For future source bumps: re-run the build tool, expect new `dbSha256` and `textSha256`, bump `source.version` in the manifest, document the diff, and ship as a separate change.

## Open Questions

- **What is the exact redistributable form of the Mu'jam?** The implementer's first task before any code is to confirm the King Fahd Complex publishes a structured (JSON/XML/CSV) export under terms that permit non-commercial redistribution with attribution. If only PDF is available, the change pauses for re-scoping.
- **Is topic id stability across upstream versions guaranteed?** Probably not. The build tool should record both the upstream id (if available) and a build-tool-assigned canonical id; the runtime uses the canonical id. Future source bumps may need a remap step documented at that time.
- **Should we ship a denormalized `topic_path` column (e.g., "Worship / Prayer / Voluntary prayer")?** Tempting for UI, but it's a pre-optimization. Compute paths at runtime from the parent_id chain via the `getTopicTree()` traversal until benchmarks show it matters.
- **Hierarchy depth cap?** Unknown until the source is in hand. The schema doesn't impose one; if a future tier needs a depth limit, it lands as a v2 migration.
