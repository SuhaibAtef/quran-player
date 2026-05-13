## ADDED Requirements

### Requirement: AGENTS.md SHALL document repo-level behavioral rules for AI coding agents

`AGENTS.md` SHALL contain a top-level section that sets behavioral expectations for any AI coding agent working in this repository, distinct from sections that describe project state, tooling, or conventions. The section SHALL appear before the `Project state` section so it is read first.

#### Scenario: Behavioral section exists near the top of AGENTS.md
- **WHEN** a reader opens `AGENTS.md` from line 1
- **THEN** they encounter a top-level heading dedicated to agent behavior (e.g. `## How to work in this repo`) before reaching the `## Project state` heading

#### Scenario: Behavioral section is distinct from tooling and conventions
- **WHEN** the file is parsed by its top-level (`##`) headings
- **THEN** the behavioral section is its own `##` heading and is not nested under `Tooling and conventions`, `Skills`, or `Project state`

### Requirement: Behavioral section SHALL encode the four Karpathy rules adapted to this project

The behavioral section SHALL include four named rules that correspond to the Karpathy guidelines, adapted to this project's vocabulary (OpenSpec, ForUI, `Result`/`Failure`, git-flow, `just check`). Each rule SHALL have a short imperative title and one or more concrete bullets explaining how it applies here.

#### Scenario: Four named rules are present
- **WHEN** the behavioral section is read
- **THEN** it contains rules titled (or clearly equivalent to) *Think Before Coding*, *Simplicity First*, *Surgical Changes*, and *Goal-Driven Execution*

#### Scenario: Each rule references project-local context
- **WHEN** an agent reads any of the four rules
- **THEN** at least one bullet in that rule references a concrete project artifact, command, or convention (for example `OpenSpec`, `ForUI`, `Result<T>`, `just check`, `git-flow`, `develop`, `/opsx:apply`) — not only generic guidance

#### Scenario: Rules use imperative voice and avoid restating project state
- **WHEN** a reviewer scans the rules
- **THEN** each bullet is phrased as an instruction (e.g. "Do X", "Don't Y") and does not duplicate facts already in the `Project state` section

### Requirement: AGENTS.md SHALL stay under 200 lines after the rewrite

The total line count of `AGENTS.md` SHALL be strictly less than 200 lines, measured by `(Get-Content AGENTS.md | Measure-Object -Line).Lines` (or equivalent), including the new behavioral section and trailing newline.

#### Scenario: Length check passes after the change is applied
- **WHEN** the line count of `AGENTS.md` is measured immediately after this change is implemented
- **THEN** the count is less than 200

#### Scenario: Future edits to AGENTS.md respect the cap
- **WHEN** a subsequent change adds content to `AGENTS.md`
- **THEN** that change either keeps the file under 200 lines or explicitly proposes raising the cap (via a new OpenSpec change) before merging

### Requirement: The trim SHALL preserve every load-bearing project fact

When trimming `AGENTS.md` to meet the 200-line cap, every fact that is currently load-bearing — paths to source files, package pins, integrity-check semantics, audio-source rules, git-flow rules, hook scripts, command list — SHALL either be retained or be replaced by a link to the file/directory that already documents it. No load-bearing fact may be deleted without a replacement pointer.

#### Scenario: Load-bearing facts retained or linked
- **WHEN** a reviewer diffs the rewritten `AGENTS.md` against the previous version
- **THEN** for every removed fact about ForUI pin, Dart SDK constraint, SQLite integrity check, audio source/reciter id, git-flow rules, hook scripts, or `just` recipes, there is either equivalent content in the new file or a markdown link to the source-of-truth file (e.g. `pubspec.yaml`, `assets/quran/manifest.json`, `Justfile`, `.claude/settings.json`)

#### Scenario: Browser automation duplication removed
- **WHEN** the rewritten file is searched for a standalone `## Browser automation` section
- **THEN** no such section exists; browser-automation guidance is delegated to the `agent-browser` skill bullet under `## Skills`

### Requirement: CLAUDE.md SHALL remain a pointer to AGENTS.md

`CLAUDE.md` SHALL continue to delegate to `AGENTS.md` and SHALL NOT contain project guidance of its own. This change SHALL NOT modify `CLAUDE.md`.

#### Scenario: CLAUDE.md is unchanged
- **WHEN** a reviewer diffs `CLAUDE.md` against the version before this change
- **THEN** the diff is empty

#### Scenario: CLAUDE.md still points at AGENTS.md
- **WHEN** an agent opens `CLAUDE.md`
- **THEN** the file references `AGENTS.md` as the source of project guidance and contains no behavioral or project-state content of its own

### Requirement: The behavioral section SHALL be discoverable from the "Keep docs current" rule

The existing "Keep docs current" instruction in `AGENTS.md` SHALL be updated to explicitly name the behavioral section as something to keep in sync when guidance evolves, so future changes know to update it rather than letting it drift.

#### Scenario: Keep-docs-current rule names the behavioral section
- **WHEN** an agent reads the "Keep docs current" paragraph in `AGENTS.md`
- **THEN** the paragraph instructs that updates to behavioral guidance go in the same change as the behavior they describe, alongside the existing instruction to update `AGENTS.md` / `README.md` / skill files
