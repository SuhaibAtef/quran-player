## Context

`AGENTS.md` is the root agent-facing context file for this repo (`CLAUDE.md` is a one-line pointer to it). Today it is 158 lines and covers project state, lib layout, conventions, cascading platform files, skills, browser automation, hooks (wired and planned), commands, tooling paths, and notes for future work. It is good at describing *the codebase* but does not encode *how to behave* when changing the codebase.

Andrej Karpathy's `multica-ai/andrej-karpathy-skills` repository publishes a short behavioral guide (Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution) explicitly designed to suppress the most common LLM coding failure modes: hidden assumptions, speculative abstractions, drive-by refactors, and "I think it works" completions without verification. Those failure modes are exactly the ones we keep observing on this project — and they cost time because each over-eager change has to be re-reviewed and trimmed.

Adopting the rules is cheap (docs only), reversible, and stacks with the existing project conventions (OpenSpec for spec-first work, `Result`/`Failure` at boundaries, ForUI-first UI, git-flow with one-change-one-branch). The constraint is that the user wants the rewritten `AGENTS.md` to stay under 200 lines so it remains scannable — meaning we must trim as well as add.

## Goals / Non-Goals

**Goals:**
- Encode the four Karpathy rules as a first-class section in `AGENTS.md`, adapted to this project's vocabulary so agents do not have to translate generic guidance into local terms.
- Place the new section *before* the project-state walkthrough so it is the first thing an agent reads after the file title.
- Keep total `AGENTS.md` length under 200 lines, including the new section.
- Preserve every load-bearing piece of project information (paths, pins, integrity-check semantics, audio-source rules, git-flow, hooks).
- Make the trim mechanical and easy to review: collapse, link out, and merge — do not paraphrase technical facts into something looser.

**Non-Goals:**
- Changing any code, tests, hooks, lints, or CI behavior.
- Editing `CLAUDE.md` beyond what is already there (it stays a pointer; the *content* of the pointer line does not change).
- Editing platform-specific `CLAUDE.md` files (`windows/`, `macos/`, `linux/`) — those are out of scope and the cascading-files link still points at them.
- Rewriting any of the vendored skills under `.claude/skills/`.
- Introducing a new automated enforcement mechanism for the rules (no hook, no lint). The rules are guidance, not gates.

## Decisions

**1. Adapt, don't copy, the Karpathy text.**
We rewrite each of the four rules in this project's own voice so they reference concrete local tools (OpenSpec, ForUI, `Result`/`Failure`, git-flow, `just check`). A verbatim copy would force agents to translate "write a failing test then make it pass" into "use `just test` against the bundled SQLite DB"; doing the translation once here saves doing it every session.
*Alternative considered:* link out to the upstream file. Rejected — `AGENTS.md` is the durable source of truth for this repo and we do not want a network fetch (or a stale external URL) to be a prerequisite for understanding how to behave.

**2. Place the behavioral rules near the top, under a new "How to work in this repo" heading.**
Agents read top-down. Putting the rules after 150 lines of project state means most sessions will reach for tooling first and only encounter the rules after the first mistake. Putting them at the top costs ~30 lines of "ceremony before content" but pays for itself the first time it prevents a drive-by refactor.
*Alternative considered:* fold the rules into the existing `Tooling and conventions` section. Rejected — they are behavioral, not tooling, and would get lost next to "use ForUI components."

**3. Trim by collapsing bullets and linking out, not by deleting facts.**
The current `Project state` walkthrough describes each subsystem in 3–6 sentences. We collapse each to one sentence that names the subsystem and links to the directory or doc that already explains it (`lib/features/reader/`, `IDEA.md`, `THIRD_PARTY_NOTICES.md`). The full story stays available; the agent-facing index gets shorter. Same approach for `Notes for future work`: keep the load-bearing constraints (don't hand-edit the DB, ForUI pin discipline, never embed audio-API secrets) and drop restatements of facts already in the section above.
*Alternative considered:* keep the project-state section verbatim and instead drop one of the planned-hooks bullets or the cascading-files block. Rejected — those are useful and stable; the bloat is in `Project state`, which restates information that is also in code and IDEA.md.

**4. Remove the `Browser automation` section entirely.**
It is four lines that the `agent-browser` skill bullet already implies. Anyone reaching for browser automation invokes the skill; the skill's `SKILL.md` is the right home for its workflow. Removing the section reclaims ~10 lines for the new behavioral content.
*Alternative considered:* keep it but move it under the `agent-browser` skill bullet as sub-bullets. Rejected — duplicates skill content and creates two sources of truth.

**5. Track the rules as a capability in OpenSpec.**
We could treat this as "just a docs PR" with no spec. We won't, because (a) `AGENTS.md` is the contract every agent reads, so its required content *is* a spec, and (b) treating behavioral guidance as a capability means future tweaks ("add a rule about not silently bumping deps") follow the same propose → spec → tasks pipeline and don't drift over time. The new spec lives at `openspec/specs/agent-guidance/spec.md` after archive.

## Risks / Trade-offs

- **Information loss during the trim** → Mitigation: every collapsed bullet retains a link to the directory/file that holds the detail. Reviewers can diff against the current `AGENTS.md` line-by-line and confirm nothing factual was dropped. The 200-line target is met by removing *restated* content, not source-of-truth content.
- **Karpathy rules conflict with a project habit we have not noticed** → Mitigation: rewrite each rule in our own voice so the conflict (if any) surfaces during this change rather than later. If a conflict appears, the project rule wins and the Karpathy rule gets a "in this project, …" caveat in the same bullet.
- **Agents ignore the new section because it is not enforced** → Accepted. The rules are guidance; they live next to other guidance (git-flow, ForUI-first, never `print`) that is also unenforced and which agents follow. If non-compliance becomes a pattern we can later add a `Stop` hook that asks the agent to self-audit against the rules, but that is out of scope here.
- **200-line ceiling becomes a straitjacket as the project grows** → Mitigation: the ceiling is for *this* rewrite, not a permanent invariant. Future changes can revisit it, but the bias toward "link out, don't restate" is a permanent improvement either way.
- **Section reordering breaks deep links from skill files or chat history** → Low risk; nothing currently links to a `#section` anchor inside `AGENTS.md`. A grep across `.claude/skills/` will confirm before merging.
