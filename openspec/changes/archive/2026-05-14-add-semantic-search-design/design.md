## Context

PR #14 shipped keyword search (FTS5 over the bundled Quran SQLite) as the floor of the search story. The roadmap wants three additional capabilities on top of that floor, in a strict opt-in tier order: meaning-based search over Quran ayahs (tier I), topical participation in meaning search (tier II), and tafsir participation in meaning search (tier III). The user-facing model is NeoAraBERT_MSA, an Arabic embedding model on Hugging Face. The product principle from [IDEA.md](../../../IDEA.md) — *trustworthy before powerful* and local-first — constrains how the model is delivered, where it runs, and how it fails.

This design ratifies the architecture once so the four downstream changes (`add-semantic-tier-1`, `add-semantic-tier-2`, `add-semantic-tier-3`, `add-topical-search-mode`) have a single, stable source of truth.

Constraints:

- Desktop-only MVP (Windows primary; macOS/Linux later). The model must run on CPU on all three.
- Dart SDK `^3.11.0`, Flutter 3.41+, ForUI `^0.21.3` per [AGENTS.md](../../../AGENTS.md).
- Privacy is local-first: no remote calls for inference once the model is downloaded. The only network activity is the one-time model download (and per-tier embedding-file downloads), each triggered explicitly by the user.
- Errors flow through `Result<T, Failure>`. Semantic-search failure modes MUST NOT disable keyword search.
- The bundled-dataset pattern from `quran-data` is the model: byte-deterministic build tools where possible, per-dataset SHA-256 manifests, fail-closed integrity checks, framework-free domain layers, Settings attribution.

Stakeholders: end-users (meaningful search results without giving up offline use), maintainers (build tools and dataset bumps), reviewers (proposal interpretability), future MCP server (a `search_quran` tool that can opt into meaning mode).

## Goals / Non-Goals

**Goals:**

- Lock the model identity, version, source, and hosting strategy.
- Lock the embedding file format and per-tier layout.
- Lock the vector-search strategy.
- Lock the query pipeline and what "warm" vs "cold" inference means in UX terms.
- Lock the three-toggle Settings shape and the per-tier download flow.
- Lock the search result UI: sectioned results in meaning mode, not a single fused ranking.
- Lock model lifecycle behaviour (download/verify/delete/re-download, missing/corrupt handling).
- Lock failure modes so every downstream change knows what "fail closed" means here.
- Define out-of-scope items explicitly so downstream changes don't drift.

**Non-Goals (this design captures decisions for, but downstream tiers implement):**

- The actual Dart code for the query pipeline, model loader, or vector scan.
- The Settings UI widgets and copy.
- The Search page mode-chip widget.
- The maintainer build tools (`tool/build_*_embeddings.dart`).

**Out-of-scope for the entire semantic-search subtree (not just this design):**

- Remote inference APIs (violates local-first).
- Server-side hosting of embeddings (same).
- Semantic-keyword fusion ranking. Modes stay distinct; the user picks one at a time.
- Query embedding cache across launches (lazy-load means the first query of a session pays the load cost; that's acceptable).
- Migration to `sqlite-vec` or any vector index. Deferred until benchmarks show the linear scan hurts.
- Fine-tuning NeoAraBERT or using a custom model.
- Multilingual queries (English, transliteration). The model is Arabic; queries are Arabic.
- Translations of semantic results into English.
- MCP exposure of semantic search. That is its own future change after MCP read-only Mode A lands.

## Decisions

### D1: Model = NeoAraBERT_MSA, ONNX format, version-pinned

- **Identity:** `U4RASD/NeoAraBERT_MSA` on Hugging Face.
- **Format:** ONNX (export from the Hugging Face checkpoint; the export is recorded as a maintainer step in the future tier-1 build tool, not as a download from Hugging Face's auto-generated ONNX endpoint which has been unreliable for some models).
- **Pinning:** a specific commit SHA of the Hugging Face model repo is recorded in the design's appendix (or in the tier-1 change's design.md when it lands). Bumps are explicit changes.
- **Dimension:** 768 (standard BERT-base). Pinned in the per-tier manifest as `dim: 768` so loaders can validate.
- **Tokenizer:** the model's own tokenizer files (vocab, merges, special tokens) ship alongside the ONNX file in the model download payload.
- **Rationale:** the user identified NeoAraBERT_MSA explicitly. It is purpose-built for modern Arabic, has the right size for desktop CPU inference, and a tagged Hugging Face repo provides a stable identity.
- **Alternatives considered:** a smaller distilled multilingual model would shrink the download but degrade Arabic quality, defeating the purpose. A cloud API would violate local-first.

### D2: Model hosting = GitHub Release artifact on this repo

- **Why:** stable URL under the project's control; immune to Hugging Face renames, repo moves, or auth changes; free at this scale (a single ~400 MB asset per model version, well under GitHub's 2 GB per-file Release limit); versioning aligns with project tags rather than upstream's lifecycle.
- **Layout:** each model version becomes a tagged GitHub Release on this repo whose attached asset is a single `.tar.gz` (or `.zip`) bundle containing the ONNX file, tokenizer files, and a `model.json` recording dimension, model commit SHA from upstream, license, and the maintainer steps used to export it.
- **Verification:** the app downloads the asset, computes its SHA-256, and compares against an expected hash baked into the app build (passed via `--dart-define` or a compile-time constant). Mismatched hash → delete, log, surface error in Settings, do not enable semantic search.
- **Rotation:** changing the model is a coordinated change (new GitHub Release + new expected hash in the app + new tier-1 build of embeddings against the new model + ratified bump proposal).
- **Alternatives considered:** Hugging Face direct (depends on a third party); self-hosted CDN (ongoing cost and ops); bundle in app ([violates install-size budget — adds ~400 MB to every install whether the user wants semantic or not]).

### D3: Model storage = user app-support directory, not bundled

- **Path:** `path_provider.getApplicationSupportDirectory()/semantic/<model-version>/{model.onnx, tokenizer files, model.json}`.
- **Versioned directory** prevents stale-model artefacts from interfering when a future bump lands.
- **Bundled state:** the app ships *without* the model. Users who never enable semantic search pay zero install-size cost.
- **Deletion:** the Settings UI exposes a "Delete model" affordance that wipes the versioned directory and (per D7) also wipes any downloaded embedding bins, since those are tied to the model's dimension and tokenizer.

### D4: Inference = `flutter_onnxruntime` (or equivalent), lazy-loaded on first semantic query

- **Library:** `flutter_onnxruntime` is the leading Flutter ONNX runtime binding at the time of writing. The implementer of tier-1 verifies cross-platform support (Windows / macOS / Linux desktop) before committing; if it has gaps on one of the three platforms, the design accepts an equivalent library that meets the same contract.
- **Loading model:** the app does NOT load the model at startup. The first call to "meaning search" loads the model into memory (~3–10 s on a modern desktop CPU). Subsequent queries in the same session reuse the loaded model.
- **Memory:** loaded model occupies ~400–600 MB of RAM (model weights + tokenizer state + ORT session). The Settings UI documents this so users can decide.
- **Unloading:** the model is unloaded when the app shuts down. It is NOT unloaded between queries.
- **Warm/cold UX:**
  - *Cold* (first query in a session, OR first query after the user enables the toggle): show "Preparing semantic search…" message with progress, then run the query. ~3–10 s.
  - *Warm* (subsequent queries in the same session): no special UX, results appear in ~200–400 ms (query embedding + scan).
- **Rationale for lazy:** users who never search by meaning never pay the load cost. Users who do search by meaning are signing up explicitly via the Settings toggle and are willing to wait once per session.

### D5: Vector store = pure-Dart linear cosine scan, per-tier `.bin` file

- **Decision:** float32, row-major, dimension-checked at load. No SQLite vector extension, no `sqlite-vec`, no `objectbox`, no Faiss, no HNSW. Scan everything every query.
- **Why this works:**
  - Tier I: 6,236 ayahs × 768 floats × 4 bytes = ~19 MB. Scan is <5 ms on a modern desktop CPU.
  - Tier II: + a few hundred topic vectors. Negligible.
  - Tier III: + ~50,000 tafsir-paragraph vectors. ~150 MB. Scan ~50–100 ms.
- **Inference dominates anyway:** query embedding is ~200 ms warm. The scan is never the bottleneck at these scales.
- **Migration path:** if a future change pushes total vectors past ~500,000 (e.g., multi-tafsir corpora) and scan times exceed the inference cost, a follow-up change introduces `sqlite-vec` as a *strict swap-in* for the scan loop. The query pipeline and result shape do not change; only the scan implementation does.
- **File format:** raw `Float32List` bytes in little-endian order, row-major, with no header. The sidecar manifest carries everything needed to interpret the file (dimension, count, SHA-256). Format simplicity matters more than self-describing for files this small and well-attributed.

### D6: Embedding files = per-tier, per-dataset, sibling manifests

```
assets/embeddings/
  quran/
    quran.bin              ← tier I: 6,236 × 768 float32
    manifest.json          ← dataset: "embeddings-quran-v1", dim, count,
                             modelVersion, embeddedAt, sha256
  topics/
    topics.bin             ← tier II: N_topics × 768 float32
    manifest.json
  tafsir/
    tafsir.bin             ← tier III: N_paragraphs × 768 float32
    manifest.json
```

- **Bundling vs download:** the design defers to per-tier changes to decide whether each `.bin` file is *bundled in the app* or *downloaded on toggle*. The user's lock-in says **download per tier**, so the tier-1 change does not bundle `quran.bin`; it downloads it as part of enabling semantic search alongside the model. Tier-2 and tier-3 toggles trigger their respective downloads. A future "Download all" button is out of scope here.
- **Hosting:** same GitHub Release model as D2. Each tier's `.bin` file ships as an additional asset attached to the corresponding GitHub Release of the model (or its own per-tier release; final placement is a tier-1 implementation detail).
- **Verification:** each downloaded `.bin` is SHA-256 checked against an expected hash baked into the app build. Mismatch → delete, log, surface error in Settings, mark tier disabled.
- **Lifecycle:** if the user deletes the model (D3), all downloaded `.bin` files are also deleted, because they are tied to that specific model's tokenizer and dimension.

### D7: Topic embedding strategy = A+ (label + 2–5 representative ayahs)

For tier II, each topic's embedding input is constructed as:

```
"{topic.label_ar}\n\n{ayah_1.text}\n{ayah_2.text}\n…{ayah_k.text}"
```

where `k = min(5, link_count)` and the selected ayahs are the first `k` by `(surah, ayah)` order from `topic_ayahs` joined to the Quran DB. Single 768-dim vector per topic.

**Rationale:**

- *Why label + ayahs?* Embedding the label alone leaves descriptive queries (e.g., paraphrase, sentence) under-matched. Embedding all of a topic's content overruns the model's 512-token window and dilutes signal. Label + a few representative ayahs lands in the sweet spot.
- *Why first-by-(surah,ayah)?* Stable, byte-deterministic, no maintainer-curation step required. If quality measurement shows the first-k strategy is weak for specific topics, a follow-up change can switch to a curated representative set; the design accepts this swap as a future tier-2-v2 change.
- *Why a single vector per topic?* Keeps the topic-results section small and ranking simple. Multi-vector topic representations would push us toward fusion ranking, which is out of scope.

### D8: Three independent Settings toggles (β shape)

```
Settings → Search
  ☐ Enable semantic search                          (downloads model first time)
      └ ☐ Include topics in semantic results        (greyed if topics dataset not installed; downloads topics.bin)
      └ ☐ Include tafsir in semantic results        (greyed if tafsir dataset not installed; downloads tafsir.bin)
```

- **Primary toggle** gates whether the "meaning" mode chip appears on the Search page at all.
- **Secondary toggles** are independent — a user with Topics installed but not Tafsir can enable meaning + topics without touching tafsir. A user with both datasets installed can enable all three. A user without Topics installed sees the topics toggle greyed with a tooltip pointing to where to install Topics (this is the user's lock-in `Option β`).
- **Independence is intentional:** trying to force a tier order (e.g., "tier II requires tier I") matches the data dependency but constrains UX needlessly. The design prefers: dependencies are enforced *automatically* (you cannot enable tafsir-in-meaning without semantic-search enabled, because tafsir embeddings require the model) but the user is not forced through tiers as a sequence; they tick what they want.
- **Persistence:** toggles persist via `SharedPreferences`. Disabling a toggle does NOT delete the downloaded bin file by default — the user can re-enable without re-downloading. A separate "Delete downloads" button in Settings allows wiping.
- **State machine per toggle:**
  - *Off* → toggle off, no download, no UI surface.
  - *Toggle on, model missing* → trigger model download, then proceed.
  - *Toggle on, model present, bin missing* → trigger bin download.
  - *Toggle on, both present* → tier is active; UI surface appears.
  - *Download fails* → surface error in Settings, mark tier as off, log via `appLogger`.
  - *Integrity verification fails post-download* → delete the bin, mark tier as off, surface error.

### D9: Per-tier downloads (with future "Download all" button noted)

The user's lock-in: per-tier download. When a tier toggle flips on:

1. Check if the model is present.
   - If not, queue a model download. Show progress UI in Settings.
2. Check if the tier's bin is present.
   - If not, queue the bin download. Show progress UI in Settings.
3. When both arrive and verify, the tier becomes active.

A future "Download all" Settings button is out of scope for this design but is reserved as a single-click affordance that flips all three toggles on at once, batching the downloads. That change will reference this design.

### D10: Query pipeline (worked example)

```
User types: "ابتلاء"   (Arabic for "trial / affliction")
User presses [meaning] mode chip → query path begins.

1. SearchController calls QuerySemanticUseCase.run("ابتلاء")
2. UseCase ensures model is loaded (lazy-load if first call in session)
3. UseCase tokenizes "ابتلاء" via the model's tokenizer
4. UseCase runs ONNX inference → vec_query : Float32List(768)
5. For each enabled tier:
   a. UseCase memory-maps that tier's .bin file (load on first query, reuse after)
   b. UseCase iterates rows, computing cosine(vec_query, row)
   c. UseCase keeps top-K = 50 per tier
6. UseCase composes a SemanticSearchResult { topics, ayahs, tafsirMentions }
7. SearchController emits the result; the Search page renders sectioned UI
```

**Performance budget (warm):**
- Tokenize + inference: ~200 ms
- Quran scan: ~5 ms
- Topics scan: <1 ms
- Tafsir scan: ~50–100 ms
- Total warm: ~250–400 ms per query

**Cold path:** add 3–10 s for first model load and first bin mmap.

### D11: Search UI = sectioned results in meaning mode

Meaning-mode results are rendered as up to three sections, in this fixed order:

1. **Topics** (only if tier II is active): up to 5 topic cards, each showing label, ayah count, and similarity score. Tapping a topic shows its ayahs.
2. **Ayahs** (always present in meaning mode): up to 20 ayah results, each with `AyahKey`, snippet of text, similarity score, and a tap target into the reader.
3. **Tafsir mentions** (only if tier III is active): up to 10 tafsir snippets where the matched paragraph is shown with the surrounding ayah reference; tapping opens the future tafsir reader view (until that ships, tapping deep-links to the ayah in the reader and the tafsir text is shown inline in the result).

Section order, cap, and ranking are part of the spec scenarios. Mixed-section unified ranking is explicitly out of scope.

For the keyword and topic modes (non-semantic), result layout is unchanged from what the keyword search shipped (and what the topical search mode change introduces). Only the meaning mode is sectioned.

### D12: Mode chips on the Search page

Three mode chips appear above the search input, in this order:

```
[keyword]  [topic]  [meaning]
```

- *keyword* — always visible, always enabled. Default selected.
- *topic* — visible only if the topics dataset is installed AND the user has the (future) topic search mode toggle on.
- *meaning* — visible only if semantic search is enabled AND the model + at least the tier-I bin are downloaded and verified.

Switching modes is one tap; the input text is preserved across mode switches.

### D13: Model lifecycle

- **Download:** Settings shows progress (percent + bytes). Resume on interruption is best-effort (implementer's call whether to support HTTP `Range`; not a requirement).
- **Verify:** every downloaded asset is SHA-256 checked against an app-built-in expected hash. Mismatch → delete and surface error.
- **Activate:** after verification, the toggle's "downloading…" state flips to "ready."
- **Delete:** Settings exposes "Delete semantic model and downloads" that wipes the versioned directory under app-support and disables all three toggles.
- **Re-download:** triggered by re-enabling a toggle after deletion, identical to the first download.
- **Version bump:** if a future app version updates the expected hash, the existing on-disk model is deleted at first launch of the new version (since its hash will no longer match), and the next toggle re-enable triggers a fresh download.

### D14: Failure modes — each fails closed without disabling keyword search

| Failure | Behaviour |
|---|---|
| Model file missing | Toggle stuck at "Download required"; meaning mode chip hidden. Keyword search unaffected. |
| Model file corrupt (hash mismatch) | Delete on detection, toggle reverts to off with error message, meaning mode chip hidden. Keyword search unaffected. |
| Embedding bin missing | Tier's section absent from results. Other enabled tiers' sections still render. |
| Embedding bin corrupt | Delete + revert toggle; tier disabled with error message. |
| ONNX runtime init failure | Surface error in Settings ("Semantic search is unavailable on this platform: <reason>"); disable the toggle; meaning mode chip hidden. Keyword search unaffected. |
| Network failure during download | Pause progress, surface "retry" affordance. Keyword search unaffected. |
| Inference exception on a specific query | The query returns `Failure.unavailable` with a user-visible "Couldn't compute meaning for this query; try keyword search."; the chip stays available for the next query. |

In every case keyword search continues to function. The semantic search subtree is *additive* to keyword search; nothing it does is allowed to degrade the floor.

### D15: Out-of-scope items (documented so downstream tiers don't drift)

- **Semantic-keyword fusion ranking:** modes stay distinct. The user picks one at a time.
- **Query embedding cache across launches:** lazy-load per session is enough; persistent cache adds storage and invalidation pain for marginal latency gain.
- **`sqlite-vec` / vector index:** deferred until benchmarks show pain. Linear scan is the contract.
- **Multilingual queries:** the model is Arabic. English and transliteration are deferred.
- **Multi-vector representations** (e.g., per-paragraph for topics): single vector per item across all tiers.
- **Re-ranking with cross-encoders:** not in scope.
- **Search history, query suggestions, auto-complete:** all separate UX concerns.
- **MCP exposure of semantic search:** lands in a future MCP-mode-A extension change.

### D16: Documentation rides along with tier-1, not with this design

This design change does not edit [AGENTS.md](../../../AGENTS.md) or [README.md](../../../README.md). The tier-1 implementation is the right place to update *Wired today* and the *Commands* table, since that change actually wires the model loader, query path, and Settings UI.

The exception is a tiny optional pointer the implementer of this design may add to AGENTS.md *Project state* — "Semantic search architecture is ratified in `openspec/specs/semantic-search/spec.md`; tier implementations land separately" — to make the design discoverable. Optional.

## Risks / Trade-offs

- **`flutter_onnxruntime` cross-platform readiness** → the largest risk. If the binding has gaps on any of Windows/macOS/Linux desktop, the tier-1 change either swaps to an alternative library or pauses for upstream fixes. This design accepts that swap in principle but pins the *contract* the runtime must satisfy: load ONNX from disk, run inference on a tokenized input, return a Float32 tensor, available on all three desktop platforms.
- **Model size (~400 MB)** → user-visible cost; mitigated by opt-in download, clear Settings copy ("Downloads ~400 MB"), and the ability to delete and re-download.
- **First-query latency** → 3–10 s. Mitigated by showing "Preparing semantic search…" and by keeping the loaded model in memory for the rest of the session.
- **Embedding determinism** → ONNX inference is bitwise reproducible across the same runtime+platform but not guaranteed across runtimes. The maintainer build-tool note for tier I should record: which ORT version, which CPU isa flags, expected `dbSha256` of the produced `.bin`. Cross-platform rebuilds may yield bitwise-different bins but semantically-equivalent results; that's acceptable as long as the *committed* bin (whichever maintainer machine builds it) is the canonical artifact for that release.
- **Storage churn from per-tier downloads** → mitigated by "Delete model and downloads" Settings action.
- **Toggle state surface area** → three independent toggles plus two installed-dataset preconditions = several visible states. The design accepts the complexity in exchange for honest UX; downstream tier-1 must invest in copy and disabled-state tooltips.
- **Tafsir-paragraph cardinality estimate** → "~50,000 paragraphs" is a guess. If actual is materially higher (>200,000) the linear-scan budget gets uncomfortable, and tier III may need to ship with `sqlite-vec` after all. Tier III's design.md re-evaluates this with real numbers from the tafsir asset.
- **Hugging Face model export drift** → exporting NeoAraBERT_MSA to ONNX is a maintainer step that depends on transformer/optimum versions. The model GitHub Release pins the upstream commit SHA and the exporter version; a future bump records both.

## Migration Plan

This design proposal itself has no migration — it lands on `develop` as a documentation-only change, becomes the source of truth for downstream tier proposals, and the tier proposals reference it.

Downstream rollout sequence (each is its own change with its own branch and PR):

1. `add-semantic-tier-1` — implements all of D1–D14 as far as Quran-ayah meaning search. The first place real code lands. Largest change in the subtree.
2. `add-semantic-tier-2` — adds topic embeddings (strategy A+) and the topics section to the meaning-mode UI. Depends on `add-topical-index-data` having merged.
3. `add-semantic-tier-3` — adds tafsir-paragraph embeddings and the tafsir-mentions section. Depends on `add-tafsir-data` having merged.

Order between tier-2 and tier-3 is interchangeable; each only depends on its own dataset change being in.

Rollback for any tier change: revert the PR, delete the downloaded bin, the toggle reverts to greyed/off. Other tiers keep functioning. Keyword search is always unaffected.

## Open Questions

- **Is `flutter_onnxruntime` mature enough on macOS and Linux desktop?** Implementer of tier-1 verifies. If gaps exist, name the alternative library before implementation begins.
- **What is the exact GitHub Release naming and asset layout?** Specifics deferred to tier-1, which creates the first Release. The design only requires that an asset has an immutable URL and a recorded SHA-256.
- **How are tokenizer artifacts shipped — embedded in the ONNX file or as sidecar files?** Most BERT-style ONNX exports require sidecar tokenizer files. Tier-1 confirms and documents.
- **Does cosine similarity, dot product, or normalized dot product give the best ranking for NeoAraBERT_MSA?** Tier-1 picks one and pins it; the design's WHEN/THEN scenarios only require *some* similarity function returning a higher score for more relevant results.
- **What's the right `top_k` per section?** Design suggests 5 topics / 20 ayahs / 10 tafsir mentions. Tier changes may tune this from user feedback; the spec scenarios assert "at most N" rather than "exactly N" so tuning is allowed without re-spec.
- **Should the future MCP `search_quran` tool gain a `mode: "meaning"` parameter?** Yes in principle but defer the decision to a future MCP extension change. Out of scope here.

## Appendix: Decision Index

For reviewers who want to scan decisions without reading the prose:

```
D1  Model identity = NeoAraBERT_MSA, ONNX, pinned
D2  Hosting = GitHub Release on this repo
D3  Storage = app-support dir, not bundled
D4  Inference = flutter_onnxruntime, lazy-load per session
D5  Vector store = pure-Dart linear cosine scan
D6  Embedding files = per-tier .bin + sibling manifest
D7  Topic embedding = strategy A+ (label + 2–5 first-by-key ayahs)
D8  Settings = three independent toggles (β shape)
D9  Downloads = per-tier, "Download all" button deferred
D10 Query pipeline = tokenize → infer → per-tier cosine → compose
D11 UI = sectioned results in meaning mode
D12 Mode chips = [keyword] [topic] [meaning]
D13 Model lifecycle = download / verify / activate / delete / bump
D14 Failure modes = each fails closed, keyword search never degrades
D15 Out-of-scope catalog for the whole subtree
D16 Docs ride with tier-1, not with this design
```
