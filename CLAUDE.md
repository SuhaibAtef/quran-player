# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Freshly scaffolded Flutter app (`flutter create`) intended to become a Quran player. [lib/main.dart](lib/main.dart) is still the default counter demo and [test/widget_test.dart](test/widget_test.dart) tests that demo — both will need to be replaced as real features land.

- Dart SDK constraint: `^3.10.4` ([pubspec.yaml:22](pubspec.yaml#L22))
- All six Flutter platforms are enabled (android, ios, web, windows, macos, linux). Drop the platforms you don't ship from `pubspec.yaml` and remove their folders rather than letting them rot.
- Lints come from `package:flutter_lints/flutter.yaml` via [analysis_options.yaml](analysis_options.yaml). Add project-specific rules under `linter.rules` rather than disabling lints inline.

## Tooling and conventions

- **Version control:** `git`, hosted on **GitHub**. Follow **git-flow**: every change ships through a PR, never directly to `main`. `main` must always build with no errors — if a PR breaks the build, revert before merging another change.
- **Project management:** **Linear** — issues, cycles, and roadmap live there, not in GitHub Issues.
- **UI library:** [forui](https://forui.dev/) — prefer ForUI components over hand-rolled widgets and over `material`/`cupertino` primitives where a ForUI equivalent exists. Keep theming centralized so a swap stays cheap.
- **Task runner:** **Justfile** at the repo root wraps the common `flutter`/`dart` commands. Add new repeatable workflows as `just` recipes rather than as ad-hoc shell snippets in docs.
- **Skills are committed to the repo.** Whatever skills the team relies on (Flutter Skills, OpenSpec, Impeccable, agent-browser, etc.) live under version control so teammates and future Claude instances inherit the same toolset. Don't keep skills only in your personal `~/.claude/`.

### Cascading CLAUDE.md files

This file is the root context. Each platform folder owns its own `CLAUDE.md` for platform-specific notes (signing, entitlements, build quirks, native deps):

- [android/CLAUDE.md](android/CLAUDE.md)
- [ios/CLAUDE.md](ios/CLAUDE.md)
- [web/CLAUDE.md](web/CLAUDE.md)
- [windows/CLAUDE.md](windows/CLAUDE.md)
- [linux/CLAUDE.md](linux/CLAUDE.md)

When working inside one of those folders, read its `CLAUDE.md` in addition to this one. Keep platform-specific guidance out of this root file.

**Keep docs current.** Each time you complete a task or learn important information about the project, you must update the `CLAUDE.md`, `README.md`, or relevant skill files — in the same change that introduced the new behavior. Stale guidance is worse than no guidance.

## Skills

The following skills are part of the standard workflow on this project. Skill files live under version control (see *Tooling and conventions* above) so the whole team and every Claude session shares the same toolkit. Invoke via `/<skill-name>` when the work matches.

- **Flutter Skills** — Flutter/Dart guidance: app structure, state-management choice, widget composition, platform-channel boundaries, asset/font handling, and idiomatic Dart. Reach for these whenever a question is Flutter-shaped rather than language-agnostic — e.g. "where should this provider live?", "how do I wire a `MethodChannel`?", "is this widget rebuild necessary?".
- **OpenSpec** — spec-driven workflow. Use the four sub-skills as a pipeline before non-trivial work: `/openspec-explore` to think through the problem, `/openspec-propose` to generate the proposal + specs + tasks, `/openspec-apply-change` to implement against the spec, `/openspec-archive-change` to finalize and move it to the archive once shipped. The spec is the source of truth — update it when scope shifts, then re-implement against it.
- **Impeccable** — frontend quality bar. Use for design audits, visual hierarchy, accessibility, motion, copy, theming, and "this looks fine but feels off" reviews. Run after a feature lands to polish, or before a redesign to plan. Out of scope: backend or non-UI logic.
- **agent-browser** — browser automation skill (see the *Browser automation* section below for the workflow). Use whenever the task involves driving a real browser — visual regression checks for the web build, smoke-testing the deployed PWA, scraping recitation metadata from public sources, etc.

## Browser automation

Use `agent-browser` for web automation. Run `agent-browser --help` for all commands.

Core workflow:

1. `agent-browser open <url>` — Navigate to page
2. `agent-browser snapshot -i` — Get interactive elements with refs (`@e1`, `@e2`)
3. `agent-browser click @e1` / `fill @e2 "text"` — Interact using refs
4. Re-snapshot after page changes

## Hooks (planned)

These hooks belong in `.claude/settings.json` (configure with the `update-config` skill). Each one wires a deterministic gate around the agent so we catch issues without human babysitting. Treat this list as the project's intended automation surface — implement them as the project matures, and update this section when one ships or changes.

- **Auto-formatting on save** — `PostToolUse` on `Edit`/`Write` runs `dart format <file>` (and `clang-format` for native runner code) so style nits never reach review.
- **Security scanning** — `PostToolUse` on `Edit`/`Write` runs the deepsec scanner on the touched file. Catches secrets and known vulnerable patterns; flags any change to auth/authz code before the agent moves on.
- **Dependency auditing** — `PreToolUse` on edits to [pubspec.yaml](pubspec.yaml) runs a vulnerability check against the new package(s) before the agent commits.
- **Interactive checkpoints** — `PreToolUse` on dependency adds, schema migrations, or any other risky step prompts the user (e.g. "the agent wants to add `package:foo` — approve?"). Keeps a human in the loop without watching every step.
- **Automated sub-agent review** — `Stop` hook fires a review subagent (or several in parallel) over the diff before the work is considered done. Surfaces issues the implementing agent missed.
- **Test-on-commit** — `PreToolUse` on `git commit` runs `flutter test`; failures are fed back into the agent's context automatically so it can fix and re-commit without human intervention.
- **License compliance** — when `pubspec.lock` changes, check new transitive licenses against the project's allow-list. Block GPL/AGPL/SSPL by default.
- **Skill and docs updates** — `Stop` hook prompts the agent to review whether the change should update `CLAUDE.md`, `README.md`, or any skill file (matching the *Keep docs current* rule above).

## Commands

PowerShell is the default shell on this machine. Run from the repo root. Common workflows are wrapped in the [Justfile](Justfile) — run `just` to see all recipes.

| Just recipe | Underlying command | Purpose |
|---|---|---|
| `just get` | `flutter pub get` | Install deps after editing [pubspec.yaml](pubspec.yaml) |
| `just analyze` | `flutter analyze` | Static analysis (lints + type errors) |
| `just format` | `dart format .` | Format all Dart files |
| `just test` | `flutter test` | All widget/unit tests in `test/` |
| `just test-file <path>` | `flutter test <path>` | Single test file |
| `just test-name <name>` | `flutter test --name <name>` | Single test by name |
| `just run [device]` | `flutter run -d <device>` | Launch on a device (default `windows`); `just devices` to list |
| `just build <target>` | `flutter build <target>` | Release build (`apk`, `windows`, `web`, …) |
| `just check` | format + analyze + test | Pre-commit gate |

If you don't have `just` installed, the underlying commands above work directly. New repeatable workflows belong in the [Justfile](Justfile), not in ad-hoc docs.

## Notes for future work

- The `package:quran_player/main.dart` import in [test/widget_test.dart:11](test/widget_test.dart#L11) will break the moment `MyApp` is renamed or moved — update the test alongside any restructure of `lib/`.
- Android package id is `com.example.quran_player` ([android/app/src/main/kotlin/com/example/quran_player/MainActivity.kt](android/app/src/main/kotlin/com/example/quran_player/MainActivity.kt)). Change it before any real release; renaming requires updating the Kotlin path, `applicationId` in `android/app/build.gradle.kts`, and the iOS bundle id in `ios/Runner.xcodeproj/project.pbxproj`.
