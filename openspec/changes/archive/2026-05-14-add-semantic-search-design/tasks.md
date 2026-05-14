## 1. Branch and PR

- [x] 1.1 Branch from `origin/develop` as `chore/add-semantic-search-design` per the *one change, one branch* rule in [AGENTS.md](../../../AGENTS.md)
- [x] 1.2 Ship as a single PR per the same rule; do NOT merge this design alongside any tier implementation

## 2. Ratification

This change is design-only. There is no code to write. Ratification consists of confirming that every decision in the design.md and every WHEN/THEN scenario in the spec is acceptable, and that downstream tier proposals can reference this design without ambiguity.

- [x] 2.1 Read [design.md](./design.md) end-to-end and confirm every decision D1–D16 reflects the locked architectural choices
- [x] 2.2 Read [specs/semantic-search/spec.md](./specs/semantic-search/spec.md) end-to-end and confirm every WHEN/THEN scenario is testable when the downstream tier changes implement it
- [x] 2.3 Confirm the out-of-scope list in spec Requirement *"Out-of-scope items are recorded for downstream changes"* is exhaustive enough that downstream tier proposals don't drift
- [x] 2.4 Resolve every entry in the design's *Open Questions* section by either: (a) committing to an answer here and updating the design + spec accordingly, or (b) explicitly deferring it to the tier change that will resolve it, with a note recording the deferral

## 3. Optional discoverability nudge

- [x] 3.1 (Optional) Add a one-line pointer under [AGENTS.md](../../../AGENTS.md) *Project state* noting "Semantic search architecture is ratified in `openspec/specs/semantic-search/spec.md`; tier implementations land separately." Skip if the implementer prefers to fold this into the [AGENTS.md](../../../AGENTS.md) edit that rides with `add-semantic-tier-1`

## 4. Hand-off

- [x] 4.1 Confirm `openspec list` shows this change as ready for archival once ratified, and that no downstream tier change has been started against an un-ratified design
- [x] 4.2 Note in the PR description that the next implementing change is `add-semantic-tier-1`, which will branch from `develop` AFTER this design is merged, NOT before
