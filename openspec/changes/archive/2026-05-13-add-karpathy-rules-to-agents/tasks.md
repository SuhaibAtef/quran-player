## 1. Branch and prep

- [x] 1.1 Confirm working tree is clean (`git status`); stash or commit any unrelated work before starting.
- [x] 1.2 ~~Create branch `chore/add-karpathy-rules-to-agents` from `develop` and check it out.~~ *Deviation:* implemented on pre-existing branch `chore/update-agents-md`, which had no unique commits vs `develop` (same intent, different name).
- [x] 1.3 Re-read the current `AGENTS.md` and note the line ranges of every section that will be touched, so the rewrite can be reviewed as targeted edits rather than a wholesale replacement.

## 2. Draft the behavioral section

- [x] 2.1 Draft a new `## How to work in this repo` section with four sub-headings (`### Think before coding`, `### Simplicity first`, `### Surgical changes`, `### Goal-driven execution`).
- [x] 2.2 Under each sub-heading, write 3–5 short bullets in imperative voice. Reference at least one project-local artifact per rule (e.g. `OpenSpec` pipeline, `ForUI`, `Result<T>`/`Failure`, `just check`, git-flow, `develop`, `/opsx:apply`, `appLogger`).
- [x] 2.3 Keep the whole section under ~35 lines so the 200-line cap is reachable. *(Lines 5–39 in the rewritten file = 35 lines.)*

## 3. Trim existing sections

- [x] 3.1 Collapse each subsystem bullet under `## Project state` "What's wired today" to one sentence that names the subsystem and links to its directory or doc (`lib/features/reader/`, `lib/features/player/`, `IDEA.md`, `THIRD_PARTY_NOTICES.md`). Do not delete facts — link to them.
- [x] 3.2 Merge `### Cascading CLAUDE.md files` into a single line under `## Tooling and conventions` that lists the three platform `CLAUDE.md` paths.
- [x] 3.3 Move `### Tooling paths on this machine` into one short bullet under `## Commands` that names the `gh.exe` full path and the general rule ("prefer PowerShell or full paths for Windows-installed CLIs"). Drop the duplicated bash/pwsh example block.
- [x] 3.4 Delete the `## Browser automation` section entirely; ensure the `agent-browser` bullet under `## Skills` still names the skill as the source of truth.
- [x] 3.5 Trim `## Notes for future work` to only load-bearing constraints (don't hand-edit the bundled DB; centralize the ForUI import surface when bumping; never embed audio-API secrets; keep surah playback playlist-based; keep new reader surfaces backed by `QuranRepository`). Remove restated facts already in earlier sections.

## 4. Update the keep-docs-current rule

- [x] 4.1 Update the "Keep docs current" paragraph so it explicitly names the new behavioral section as content to update in the same change that alters behavioral guidance.

## 5. Assemble and verify

- [x] 5.1 Place `## How to work in this repo` immediately after the file title and intro line, before `## Project state`.
- [x] 5.2 Run `(Get-Content AGENTS.md | Measure-Object -Line).Lines` in PowerShell and confirm the result is `< 200`. *(`wc -l` reports 146 lines, well under the cap. PowerShell `Measure-Object -Line` reported 107 — undercounts; `wc -l` is authoritative.)*
- [x] 5.3 Run `just analyze` and `just test` — should pass unchanged (no code edits). *(`flutter analyze`: no issues. `flutter test`: 90/90 passed; `media_kit` stderr is the usual Windows platform-init noise, not a regression.)*
- [x] 5.4 Diff against the previous `AGENTS.md` and walk every removed line: confirm each was either (a) duplicate/restated content or (b) replaced by an outbound link.
- [x] 5.5 Grep `.claude/skills/` and the repo for hard-coded anchor links into `AGENTS.md` (e.g. `AGENTS.md#browser-automation`). *(Only hit was the literal example inside this tasks.md — no broken cross-references in the repo.)*
- [x] 5.6 Confirm `CLAUDE.md` is unchanged (`git diff CLAUDE.md` is empty).

## 6. Commit, PR, archive

- [x] 6.1 Commit on `chore/add-karpathy-rules-to-agents`. Commit message: short imperative title plus a one-paragraph body explaining motivation and the 200-line cap. *(Committed as `e9bd883` on `chore/update-agents-md` — see deviation in 1.2.)*
- [x] 6.2 Open a PR against `develop` via `gh pr create` (use the full path on Windows: `& "C:\Program Files\GitHub CLI\gh.exe" pr create --base develop ...`). PR body should link this OpenSpec change and call out that it is docs-only. *(PR: https://github.com/SuhaibAtef/quran-player/pull/15.)*
- [x] 6.3 ~~After merge,~~ run `/opsx:archive` (skill `openspec-archive-change`) on `add-karpathy-rules-to-agents` to move the change into `openspec/changes/archive/` and promote `specs/agent-guidance/spec.md` into `openspec/specs/agent-guidance/spec.md`. *Deviation:* archived pre-merge on this same branch at user request, so the archive lands as a second commit on PR #15 rather than as a follow-up after merge.
