## ADDED Requirements

### Requirement: Model identity and version pinning

The semantic search subsystem SHALL use the NeoAraBERT_MSA model (`U4RASD/NeoAraBERT_MSA` on Hugging Face) exported to ONNX format. The exact upstream commit SHA, the ONNX export tooling version, the model dimension (768), and the SHA-256 of the bundled ONNX file MUST be recorded in the model's GitHub Release notes and in the app build's expected-hash constant. Switching to a different model OR a different version MUST be a separate, ratified change.

#### Scenario: Model is pinned to a specific upstream commit

- **WHEN** the app is built
- **THEN** the expected model SHA-256 baked into the build matches exactly one GitHub Release on this repository, whose release notes record the upstream Hugging Face commit SHA and the ONNX export tool version

#### Scenario: Unknown model files are rejected

- **WHEN** a file at the model's expected path exists but its SHA-256 does not match the app's expected hash
- **THEN** the file is treated as corrupt, is deleted, the relevant Settings toggle reverts to off, and an error is surfaced in Settings

### Requirement: Model is hosted as a GitHub Release artifact

The model bundle (ONNX file + tokenizer files + a `model.json` manifest) SHALL be distributed as a single attached asset on a versioned GitHub Release of this repository. The Release URL MUST be immutable for a given model version. Switching to another hosting mechanism MUST be a separate, ratified change.

#### Scenario: Download URL is the immutable Release asset URL

- **WHEN** the app initiates a model download
- **THEN** the URL it requests is the immutable GitHub Release asset URL, not Hugging Face's hosted file URL, not a redirect through any third party

#### Scenario: Bundle layout is recorded

- **WHEN** the GitHub Release is published
- **THEN** the attached asset is a single archive containing the ONNX model file, the tokenizer files required for inference, and a `model.json` recording dimension, model commit SHA, license, and exporter version

### Requirement: Model is not bundled in the app installer

The shipped app installer SHALL NOT include the semantic-search model. Users who do not enable semantic search MUST pay zero install-size cost for it.

#### Scenario: Fresh install lacks the model

- **WHEN** a user installs the app and never opens Settings → Search
- **THEN** the user's app-support directory contains no semantic-search model file, and the install size is identical to a build configured with semantic search disabled at compile time

#### Scenario: Enabling the toggle triggers the download

- **WHEN** a user enables the "Semantic search" toggle for the first time
- **THEN** the app initiates the model download from the GitHub Release asset URL and shows progress UI in Settings

### Requirement: Model storage in versioned user app-support directory

Downloaded model and embedding files SHALL be stored under `path_provider.getApplicationSupportDirectory()/semantic/<model-version>/`. Each model version MUST have its own subdirectory so a future version bump can land without colliding with the previous artefacts. Deleting the model SHALL remove the entire versioned directory including any downloaded embedding files.

#### Scenario: Versioned directory contains all semantic assets

- **WHEN** the user has enabled tier I and the model has been downloaded
- **THEN** the directory `<app-support>/semantic/<model-version>/` contains the ONNX model, tokenizer files, `model.json`, and the tier-I `quran.bin` plus its sidecar manifest

#### Scenario: Deleting the model removes embeddings too

- **WHEN** the user triggers "Delete semantic model and downloads" in Settings
- **THEN** the entire `<app-support>/semantic/<model-version>/` directory is removed; all three Settings toggles revert to off

### Requirement: Lazy model load on first semantic query of a session

The app SHALL NOT load the semantic-search model at startup. The model SHALL be loaded into memory on the first call to a semantic query within a session and SHALL be retained for subsequent queries. The loaded model SHALL be released only when the app process shuts down.

#### Scenario: Startup does not load the model

- **WHEN** the app launches with semantic search enabled
- **THEN** no ONNX runtime session is initialized until the user issues a meaning-mode query

#### Scenario: First query in a session pays the load cost

- **WHEN** the user issues the first meaning-mode query of a session
- **THEN** a "Preparing semantic search…" UX is shown while the model loads, and the query proceeds once load completes

#### Scenario: Subsequent queries in the same session are fast

- **WHEN** the user issues a second or later meaning-mode query in the same session
- **THEN** no model-load UX is shown and the results return within the warm latency budget

### Requirement: Vector search uses pure-Dart linear cosine scan

For every enabled tier, the semantic search subsystem SHALL compute similarity by iterating over the tier's row-major Float32 embedding file and computing a cosine (or normalized dot product) score for each row, returning the top-K rows by score. The implementation MUST NOT use a SQLite vector extension, an external vector database, or an approximate-nearest-neighbour index in this iteration of the design. Migration to an index-based approach MUST be a separate change with its own benchmarks.

#### Scenario: Tier I scan over Quran ayah vectors

- **WHEN** a meaning-mode query is issued and tier I is active
- **THEN** the subsystem scans the entire `quran.bin` file (6,236 × 768 float32 rows), computes a similarity score per row, and returns the top-K (default K=20) `(AyahKey, score)` pairs

#### Scenario: Scan strategy is pluggable per release but linear by spec

- **WHEN** the subsystem is profiled
- **THEN** the implementation under `lib/features/search/semantic/` does not reference any vector-index library, and the scan is implemented as a Dart loop over a memory-mapped or in-memory `Float32List`

### Requirement: Per-tier embedding files with sibling manifests

Each tier's embedding data SHALL ship as a `.bin` file (raw Float32, little-endian, row-major) with a sibling `manifest.json` recording dataset name, dimension, row count, model version, and SHA-256. The `.bin` file SHALL be downloaded on enabling the corresponding tier toggle and SHALL be SHA-256 verified before activation.

#### Scenario: Tier I file layout

- **WHEN** the user enables semantic search
- **THEN** the app downloads `quran.bin` plus `quran/manifest.json`, verifies the SHA-256 of `quran.bin` against the manifest, verifies the manifest's expected hash against the app's built-in expected hash, and only activates tier I if both checks pass

#### Scenario: Tier II file layout

- **WHEN** the user enables "Include topics in semantic results" and the topics dataset is installed
- **THEN** the app downloads `topics.bin` plus `topics/manifest.json`, verifies hashes, and activates tier II

#### Scenario: Tier III file layout

- **WHEN** the user enables "Include tafsir in semantic results" and the tafsir dataset is installed
- **THEN** the app downloads `tafsir.bin` plus `tafsir/manifest.json`, verifies hashes, and activates tier III

#### Scenario: Corrupt bin is deleted and surfaced

- **WHEN** a downloaded `.bin` file fails its SHA-256 verification
- **THEN** the file is deleted, the corresponding tier is marked inactive, the relevant Settings toggle reverts to off, and an error is surfaced in Settings

### Requirement: Topic embedding strategy is label + first-K representative ayahs

For tier II, the topic embedding input text SHALL be constructed as the topic's Arabic label followed by the text of up to 5 ayahs from that topic, selected as the first `min(5, link_count)` rows ordered by `(surah, ayah)`. Each topic SHALL be represented by a single 768-dimensional vector. The maintainer build tool for `topics.bin` MUST document and implement this construction exactly.

#### Scenario: Topic embedding input is well-formed

- **WHEN** the maintainer build tool constructs the embedding input for a topic with `k` ayah links where `k >= 1`
- **THEN** the input begins with the topic's `label_ar`, followed by a separator, followed by the text of the first `min(5, k)` ayahs ordered by `(surah, ayah)`

#### Scenario: One vector per topic

- **WHEN** `topics.bin` is loaded
- **THEN** the row count equals the topic count in the bundled topics DB, and each row is a 768-dimensional float32 vector

### Requirement: Three independent Settings toggles gate the semantic-search surface

The app SHALL expose three independent toggles under Settings → Search: a primary "Enable semantic search" toggle and two secondary toggles "Include topics in semantic results" and "Include tafsir in semantic results". Secondary toggles SHALL be visually greyed when their corresponding dataset is not installed. Secondary toggles SHALL function only while the primary toggle is on (i.e., flipping the primary off implicitly disables the secondaries until the primary is re-enabled).

#### Scenario: Primary toggle controls the meaning mode chip

- **WHEN** the primary "Enable semantic search" toggle is off
- **THEN** the Search page's mode-chip row does NOT show the [meaning] chip

#### Scenario: Topics secondary toggle requires topics dataset

- **WHEN** the topics dataset is not installed (no `assets/topics/mujam.sqlite` integrity-verified)
- **THEN** the "Include topics in semantic results" toggle is greyed and a tooltip explains the prerequisite

#### Scenario: Tafsir secondary toggle requires tafsir dataset

- **WHEN** the tafsir dataset is not installed (no `assets/tafsir/muyassar.sqlite` integrity-verified)
- **THEN** the "Include tafsir in semantic results" toggle is greyed and a tooltip explains the prerequisite

#### Scenario: Secondary toggles are independently controllable

- **WHEN** both topics and tafsir datasets are installed and the primary toggle is on
- **THEN** the user can independently enable or disable either secondary toggle without affecting the other

### Requirement: Per-tier download flow on toggle enablement

Enabling a tier toggle SHALL trigger any missing downloads required for that tier (the model itself, the tier's `.bin` file, or both). Each download SHALL show progress UI in Settings, support retry on failure, and verify hashes before activating the tier. A future "Download all" affordance is out of scope for this design.

#### Scenario: Enabling semantic search downloads the model

- **WHEN** the user enables the primary toggle and the model is not present
- **THEN** the app initiates the model download, shows progress in Settings, verifies the downloaded asset's SHA-256, and activates the toggle only on successful verification

#### Scenario: Enabling tier I downloads quran.bin

- **WHEN** the primary toggle is on AND the model is present AND `quran.bin` is not present
- **THEN** the app initiates the `quran.bin` download, shows progress, verifies the hash, and only then enables meaning-mode queries

#### Scenario: Download failure leaves toggle off and surfaces error

- **WHEN** any download fails (network error, hash mismatch, disk write error)
- **THEN** the toggle reverts to off, an error is surfaced in Settings with a retry affordance, and no partial files are left on disk

### Requirement: Query pipeline composes per-tier results

A meaning-mode query SHALL: (1) ensure the model is loaded, (2) tokenize and embed the query, (3) for each enabled tier, run the cosine scan against the tier's `.bin`, keeping the top-K per tier, and (4) compose a `SemanticSearchResult` containing per-tier result lists in a fixed order.

#### Scenario: Query embedding is performed locally

- **WHEN** a meaning-mode query is issued
- **THEN** the query is tokenized and embedded using the locally loaded ONNX model with no network call

#### Scenario: Only enabled tiers contribute to results

- **WHEN** the primary toggle is on and the topics secondary is off
- **THEN** the composed `SemanticSearchResult` contains an ayahs section (tier I) but does NOT contain a topics section, regardless of whether `topics.bin` is present on disk

#### Scenario: Result composition preserves section order

- **WHEN** a `SemanticSearchResult` is rendered
- **THEN** sections appear in the order: Topics (tier II), Ayahs (tier I), Tafsir mentions (tier III)

### Requirement: Sectioned UI for meaning-mode results

The Search page in meaning mode SHALL render results as up to three distinct sections (Topics, Ayahs, Tafsir mentions) with a per-section item cap. Sections SHALL NOT be fused into a single ranked list in this iteration of the design.

#### Scenario: Sections have per-section caps

- **WHEN** a meaning-mode query returns results
- **THEN** the Topics section shows at most 5 items, the Ayahs section shows at most 20 items, and the Tafsir mentions section shows at most 10 items

#### Scenario: Empty sections are hidden

- **WHEN** a tier produces zero results for a query
- **THEN** that tier's section is not rendered (no empty-state placeholder appears for inactive tiers)

#### Scenario: Topic tap expands to its ayahs

- **WHEN** the user taps a topic card in the Topics section
- **THEN** the topic's full ayah list opens (either inline within the result, or in a topic detail view; downstream tier-2 picks one and pins it)

### Requirement: Mode chips reflect available modes

The Search page SHALL show mode chips above the search input. The [keyword] chip SHALL always be present and SHALL be the default selection. The [topic] chip SHALL appear only when the topics dataset is installed and a future topic-search-mode toggle has been enabled. The [meaning] chip SHALL appear only when the primary semantic toggle is on AND the model and the tier-I bin are present and verified.

#### Scenario: Keyword chip is always present

- **WHEN** the user opens the Search page on any install
- **THEN** the [keyword] chip is present and selected by default

#### Scenario: Meaning chip is hidden until prerequisites are met

- **WHEN** the user has not enabled semantic search OR the model is not downloaded OR `quran.bin` is not downloaded
- **THEN** the [meaning] chip is NOT visible

#### Scenario: Mode switch preserves the input text

- **WHEN** the user switches between mode chips while text is in the search input
- **THEN** the input text is preserved across the switch

### Requirement: Failure modes do not disable keyword search

Every failure path in the semantic-search subsystem SHALL fail closed for the semantic feature only; keyword search MUST continue to function. The user-visible error MUST clearly indicate that keyword search is still available.

#### Scenario: ONNX runtime initialisation fails on this platform

- **WHEN** the app attempts to load the model and the ONNX runtime fails to initialise
- **THEN** the primary toggle reverts to off with an error message naming the platform issue, the [meaning] chip is hidden, and the [keyword] chip remains available and functional

#### Scenario: A specific query throws during inference

- **WHEN** a single meaning-mode query throws inside ONNX inference
- **THEN** the user sees an error for that query suggesting "try keyword search," the [meaning] chip remains available for the next query, and keyword search is unaffected

#### Scenario: Embedding bin missing for an enabled tier

- **WHEN** a tier's `.bin` file is missing or unreadable at query time
- **THEN** that tier's section is omitted from the result with a small inline message ("Tier unavailable — re-download in Settings"), other enabled tiers' sections still render, and keyword search is unaffected

### Requirement: Out-of-scope items are recorded for downstream changes

The following items SHALL be recorded as out-of-scope for this design AND for the entire semantic-search subtree of immediate downstream changes (`add-semantic-tier-1`, `add-semantic-tier-2`, `add-semantic-tier-3`, `add-topical-search-mode`). Implementing any of these MUST be a separate, later change.

- Semantic-keyword fusion ranking (single fused list across modes).
- Persistent query embedding cache across launches.
- Migration to `sqlite-vec` or any approximate-nearest-neighbour index.
- Multilingual queries (English, transliteration).
- Multi-vector representations per item.
- Cross-encoder re-ranking.
- Search history, query suggestions, auto-complete.
- MCP exposure of semantic search.

#### Scenario: Downstream tier proposals reference this design

- **WHEN** any of `add-semantic-tier-1`, `add-semantic-tier-2`, `add-semantic-tier-3`, or `add-topical-search-mode` is drafted
- **THEN** its proposal's "Out of scope" section explicitly cites this spec's out-of-scope list and does not silently include any item from it

#### Scenario: Out-of-scope items require their own ratified change

- **WHEN** the team decides to add any out-of-scope item to the product
- **THEN** a new OpenSpec change is proposed; the design either supersedes or extends this one; and the spec scenarios are updated in lock-step
