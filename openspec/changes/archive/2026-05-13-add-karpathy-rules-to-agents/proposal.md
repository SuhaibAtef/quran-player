## Why

The project's `AGENTS.md` documents *what* the codebase is (current state, layout, tooling) but says little about *how* an agent should behave when it changes that codebase. We have repeatedly seen agents over-engineer simple tasks, "improve" adjacent code unprompted, and start implementing before clarifying ambiguity. Andrej Karpathy's published agent-coding guidelines distill four small, high-signal rules that directly counter those failure modes; adopting them gives every Claude session a shared behavioral baseline alongside the existing project conventions. We also want `AGENTS.md` to stay scannable, so the addition is paired with a trim to keep the file under 200 lines.

## What Changes

- Add a new top-level **"How to work in this repo"** section to `AGENTS.md` containing the four Karpathy rules — *Think Before Coding*, *Simplicity First*, *Surgical Changes*, *Goal-Driven Execution* — adapted to this project's language (OpenSpec, ForUI, Result/Failure, etc.). Place it near the top so it is read before the project-state walkthrough.
- Tighten the existing AGENTS.md sections to absorb the new content without exceeding 200 lines total:
  - Collapse the `Project state` "what's wired today" bullets into shorter one-line summaries that link out to source rather than re-describing each subsystem.
  - Merge `Cascading CLAUDE.md files` into a one-liner under `Tooling and conventions`.
  - Move the `Tooling paths on this machine` block down to a short footnote-style bullet under `Commands`.
  - Drop the redundant `Browser automation` section (already covered by the `agent-browser` skill bullet).
  - Trim `Notes for future work` to the load-bearing constraints (integrity check, ForUI pin, audio source rules) and remove restated information.
- Update the `CLAUDE.md`/`AGENTS.md` "keep docs current" reminder so it explicitly calls out keeping the new behavioral section in sync if guidance evolves.
- No code, lints, hooks, or tests are added or removed. This is a documentation-only change.

## Capabilities

### New Capabilities
- `agent-guidance`: Repo-level behavioral rules that govern how an AI coding agent approaches tasks in this project — what to do before writing code, how much code to write, how surgical to be when editing, and how to verify completion. Sourced from Andrej Karpathy's published guidelines and adapted to this project's tools (OpenSpec, ForUI, Result/Failure, git-flow).

### Modified Capabilities
<!-- None — no existing product spec changes behavior. The trimming of AGENTS.md is presentation-only and does not change any product requirement captured under openspec/specs/. -->

## Impact

- **Files:** `AGENTS.md` (rewritten; <200 lines). `CLAUDE.md` unchanged (still a pointer).
- **Specs:** new `openspec/specs/agent-guidance/spec.md` after this change is archived.
- **Code / runtime / tests:** none.
- **Tooling / hooks / CI:** none.
- **Humans / agents:** every Claude (or other agent) session reading `AGENTS.md` inherits the four rules. No behavior change is forced on contributors who do not use AI assistance.
- **Risk:** low — documentation only, easy to revert. The main risk is information loss during the trim, which is mitigated by keeping links to authoritative sources (Justfile, pubspec.yaml, IDEA.md, the platform `CLAUDE.md` files) instead of restating their contents.
