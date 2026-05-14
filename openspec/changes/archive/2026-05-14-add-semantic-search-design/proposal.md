## Why

The semantic-search subtree spans at least four implementation changes (`add-semantic-tier-1`, `add-semantic-tier-2`, `add-semantic-tier-3`, plus the `add-topical-search-mode` UI). They share architectural decisions — model packaging, hosting, vector format, query pipeline, ranking, Settings exposure, failure modes — that are easier to ratify once than to re-litigate per tier. This change captures those decisions as a *design-only* proposal so subsequent tier proposals can reference a single, stable source of truth without each one needing to re-argue first principles.

This is also the cheapest place to surface load-bearing risks (model download size, ONNX runtime cross-platform behaviour, embedding determinism, install-size budget) *before* any code commits to them. Better to find an architectural dead-end now than mid-tier-1.

## What Changes

This change is intentionally **design-only**. It produces:

- A `design.md` capturing every locked architectural decision for the semantic-search subtree (sources for tiers I/II/III, model identity and version, model hosting strategy, embedding format, vector store, query pipeline, UI shape, Settings exposure, failure modes, out-of-scope items).
- A `semantic-search` capability spec with WHEN/THEN scenarios that pin the architecture as *testable expectations* — even though no code lands here, the scenarios become the acceptance bar that each downstream tier change must satisfy.
- A `tasks.md` whose only items are "design ratified by maintainer" and "downstream tier changes reference this design as the source of truth."

No Dart code, no asset, no dependency change, no UI wiring. Subsequent tier changes (`add-semantic-tier-1` etc.) will reference this design and add their own implementation tasks against the spec scenarios.

The downstream changes this design unblocks (each is its own future OpenSpec proposal):

- `add-semantic-tier-1` — Quran-ayah embeddings, model download UX, query pipeline, "meaning" mode chip in Search.
- `add-semantic-tier-2` — topic embeddings (Strategy A+) and topic results section.
- `add-semantic-tier-3` — tafsir embeddings and tafsir results section.
- `add-topical-search-mode` — non-semantic "topic" mode chip (depends on `add-topical-index-data`, not on the semantic model).

## Capabilities

### New Capabilities

- `semantic-search`: Architectural capability covering how the app does meaning-based search across the bundled corpora. Captures: source-model identity, model hosting and download lifecycle, on-disk embedding format, vector-search strategy (pure-Dart linear cosine), query pipeline, three-tier opt-in model with independent Settings toggles, sectioned result UI, model lifecycle (download/verify/delete/re-download), failure modes (each fails closed without disabling keyword search), and the bounded scope (no remote API, no fusion ranking, no fine-tuning, no cross-tier ranking blending). This capability's WHEN/THEN scenarios are the acceptance bar that subsequent tier implementations must satisfy.

### Modified Capabilities

<!-- None. This proposal does not change any existing spec; it adds a new capability whose scenarios will be implemented by future changes. -->

## Impact

- **Code:** none. This change writes prose, not Dart.
- **Dependencies:** none added here. The design *names* the runtime deps that downstream tier changes will add (e.g., `flutter_onnxruntime` or equivalent, `path_provider`, `crypto`) but does not add them to [pubspec.yaml](../../../pubspec.yaml) — that's the tier changes' job.
- **Assets:** none added here. The design *names* the asset/file layout (`assets/embeddings/quran.bin`, `topics.bin`, `tafsir.bin` plus sibling manifest entries) but does not commit those files.
- **Settings UI:** unchanged here. The design *names* the three independent toggles that downstream tier changes will add.
- **Documentation:** [AGENTS.md](../../../AGENTS.md) may grow a one-line pointer under *Project state* noting "Semantic search architecture is ratified in `openspec/specs/semantic-search/spec.md`; tier implementations land separately." That one-line edit is optional and can ride with the first tier change rather than this design-only one.
- **Risk reduction:** large. By the time `add-semantic-tier-1` is being implemented, every architectural decision is already a written, reviewable WHEN/THEN scenario rather than a mid-implementation argument.
- **Branching:** this design proposal lives on its own `chore/add-semantic-search-design` branch and ships as its own PR. Per [AGENTS.md](../../../AGENTS.md)'s *one change, one branch* rule, the implementing tier changes each get their own branch+PR — they reference this design but do not co-merge with it.
