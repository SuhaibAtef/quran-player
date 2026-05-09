# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Foundation in place — **Quran Companion**, a desktop Quran player paired with a local MCP server for safe AI integration. See [IDEA.md](IDEA.md) for the full product brief: target platforms (Windows MVP; macOS + Linux for V1), MVP scope, MCP tool/resource surface, safety rules, and the *"trustworthy before powerful"* project principle that should drive scope decisions.

What's wired today (after the `bootstrap-foundation` change):

- ForUI-themed app shell with light/dark/system mode and persistent selection ([lib/app/](lib/app/)).
- `go_router` declarative routing with placeholder pages for every top-level area in IDEA.md MVP — Home/Surahs, Search, Bookmarks, Settings, MCP Status ([lib/features/](lib/features/)).
- Riverpod state, `Result`/`Failure` types in [lib/core/error/](lib/core/error/), and an `appLogger` facade in [lib/core/logging/](lib/core/logging/).
- Smoke test guarding shell, navigation, theme switch, and unknown-route redirect ([test/widget_test.dart](test/widget_test.dart)).

What's not yet implemented: Quran data, audio, search, bookmarks, MCP server. Each lands in its own OpenSpec change against this foundation.

- Dart SDK constraint: `^3.10.4` ([pubspec.yaml:22](pubspec.yaml#L22)).
- Platforms shipped: Windows (MVP), macOS, Linux. `android/`, `ios/`, `web/` were removed; recreate via `flutter create --platforms=<target> .` if a future change reintroduces one.
- Lints come from `package:flutter_lints/flutter.yaml` via [analysis_options.yaml](analysis_options.yaml). Add project-specific rules under `linter.rules` rather than disabling lints inline.
- ForUI is wired via [`forui: ^0.17.0`](pubspec.yaml#L37) — anchored on the **zinc** theme variant. `FTheme` is rebuilt inside `MaterialApp.builder` with light/dark resolved from a `themeModeProvider` ([lib/app/state/theme_mode_provider.dart](lib/app/state/theme_mode_provider.dart)). `FLocalizations` delegates and supported locales are registered. Pinned at 0.17 because 0.18+ requires Flutter 3.41+; bump Flutter first if the constraint is raised.

### Lib layout

```
lib/
  main.dart                # logging + SharedPreferences + ProviderScope bootstrap
  app/                     # composition: router, theme, app-wide state, shell chrome
  core/                    # cross-cutting: env, error/Result, logging
  features/<area>/         # one folder per top-level area (placeholder pages today)
  data/   domain/          # populated by future changes; framework-free contracts in domain/
```

State, error, logging conventions:

- **State management** — `flutter_riverpod`. Providers live next to the feature that owns them; cross-cutting providers (theme, environment) live in [lib/app/state/](lib/app/state/).
- **Routing** — `go_router`. Paths in `RoutePaths`, names in `RouteNames` ([lib/app/router/route_names.dart](lib/app/router/route_names.dart)). Unknown paths redirect to `/`. The shell switches between `FSidebar` (≥768 wide) and `FBottomNavigationBar` (narrower) via `LayoutBuilder` ([lib/app/widgets/app_shell.dart](lib/app/widgets/app_shell.dart)).
- **Errors** — return `Result<T>` ([lib/core/error/result.dart](lib/core/error/result.dart)) at boundaries that can fail. Use the sealed `Failure` hierarchy ([lib/core/error/failure.dart](lib/core/error/failure.dart)). Throwing is for programmer errors only.
- **Logging** — `appLogger` ([lib/core/logging/logger.dart](lib/core/logging/logger.dart)) configured once in `main()` via `initLogging()`. Never `print`.

## Tooling and conventions

- **Version control:** `git`, hosted on **GitHub**. Follow **git-flow**: every change ships through a PR, never directly to `main`. `main` must always build with no errors — if a PR breaks the build, revert before merging another change.
- **Project management:** **Linear** — issues, cycles, and roadmap live there, not in GitHub Issues.
- **UI library:** [forui](https://forui.dev/) — prefer ForUI components over hand-rolled widgets and over `material`/`cupertino` primitives where a ForUI equivalent exists. Keep theming centralized so a swap stays cheap.
- **Task runner:** **Justfile** at the repo root wraps the common `flutter`/`dart` commands. Add new repeatable workflows as `just` recipes rather than as ad-hoc shell snippets in docs.
- **Skills are committed to the repo.** Whatever skills the team relies on (Flutter Skills, OpenSpec, Impeccable, agent-browser, etc.) live under version control so teammates and future Claude instances inherit the same toolset. Don't keep skills only in your personal `~/.claude/`.

### Cascading CLAUDE.md files

This file is the root context. Each platform folder owns its own `CLAUDE.md` for platform-specific notes (signing, entitlements, build quirks, native deps). The MVP ships desktop only — `android/`, `ios/`, and `web/` were removed by the `bootstrap-foundation` change. If a future change reintroduces a mobile or web target, recreate the folder via `flutter create --platforms=<target> .` and add a sibling `CLAUDE.md`.

- [windows/CLAUDE.md](windows/CLAUDE.md)
- [macos/CLAUDE.md](macos/CLAUDE.md)
- [linux/CLAUDE.md](linux/CLAUDE.md)

When working inside one of those folders, read its `CLAUDE.md` in addition to this one. Keep platform-specific guidance out of this root file.

**Keep docs current.** Each time you complete a task or learn important information about the project, you must update the `CLAUDE.md`, `README.md`, or relevant skill files — in the same change that introduced the new behavior. Stale guidance is worse than no guidance.

## Skills

The following skills are part of the standard workflow on this project. Skill files live under version control (see *Tooling and conventions* above) so the whole team and every Claude session shares the same toolkit. Invoke via `/<skill-name>` when the work matches.

- **Flutter Skills** — Flutter/Dart guidance: app structure, state-management choice, widget composition, platform-channel boundaries, asset/font handling, and idiomatic Dart. Reach for these whenever a question is Flutter-shaped rather than language-agnostic — e.g. "where should this provider live?", "how do I wire a `MethodChannel`?", "is this widget rebuild necessary?". The vendored set under [.claude/skills/](.claude/skills/) splits into ten focused sub-skills covering architecture, testing (widget/integration/previews), responsive layout and overflow fixes, JSON serialization, declarative routing, localization, and HTTP — invoke any with `/flutter-<topic>`.
- **ForUI** ([.claude/skills/forui/](.claude/skills/forui/SKILL.md)) — the project's UI-library reference. Captures the pinned version (`forui: ^0.17.0`), theming wiring (`FThemes.zinc.light` + `toApproximateMaterialTheme()` + `FLocalizations`), the widget map by category, and pointers to ForUI's LLM docs ([llms.txt](https://forui.dev/docs/llms.txt) / [llms-full.txt](https://forui.dev/docs/llms-full.txt)). Invoke `/forui` (or let it auto-trigger) for any UI work — picking widgets, adding screens, theming, or deciding when Material/Cupertino primitives are still appropriate.
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

## Hooks

Hooks live in committed [.claude/settings.json](.claude/settings.json), with shell glue under [.claude/hooks/](.claude/hooks/). Each one gates the agent deterministically so problems get caught without human babysitting.

Hook scripts are PowerShell (`pwsh`). On a fresh machine, install PowerShell 7+ if it's not already present (Windows: `winget install Microsoft.PowerShell`).

### Wired up today

- **Auto-formatting on save** — `PostToolUse` on `Edit`/`Write` runs `dart format <file>` on Dart sources via [.claude/hooks/format-on-save.ps1](.claude/hooks/format-on-save.ps1). Non-Dart edits are no-ops; failures print to stderr but never block the agent.
- **Test-on-commit** — `PreToolUse` on `Bash` watches for `git commit` and runs `flutter test` first via [.claude/hooks/pre-commit-tests.ps1](.claude/hooks/pre-commit-tests.ps1). On failure the hook exits 2, blocking the commit and feeding the test output back into the agent's context so it can fix-and-retry without human intervention.

### Planned

Implement these as the project matures, and move them to *Wired up today* when they ship.

- **Security scanning** — `PostToolUse` on `Edit`/`Write` runs the deepsec scanner on the touched file. Catches secrets and known vulnerable patterns; flags any change to auth/authz code before the agent moves on.
- **Dependency auditing** — `PreToolUse` on edits to [pubspec.yaml](pubspec.yaml) runs a vulnerability check against the new package(s) before the agent commits.
- **Interactive checkpoints** — `PreToolUse` on dependency adds, schema migrations, or any other risky step prompts the user (e.g. "the agent wants to add `package:foo` — approve?"). Keeps a human in the loop without watching every step.
- **Automated sub-agent review** — `Stop` hook fires a review subagent (or several in parallel) over the diff before the work is considered done. Surfaces issues the implementing agent missed.
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

- Windows-only release metadata (CompanyName, FileDescription, ProductName, version) lives in [windows/runner/Runner.rc](windows/runner/Runner.rc). Update before distributing a build. macOS/Linux equivalents live in their respective platform folders.
- ForUI is pinned at `^0.17.0` because 0.18+ requires Flutter 3.41+ and the project is on 3.38.5. If you bump Flutter, you can bump ForUI in the same change — but expect breaking API changes; centralize the import surface in [lib/app/theme/](lib/app/theme/) and [lib/app/widgets/app_shell.dart](lib/app/widgets/app_shell.dart) so the bump is bounded.
- `path_provider` is intentionally **not** a dependency yet. When the first feature needs an OS-specific data path (audio cache, log files, Quran DB), add it then — and revisit the file-logging plan in [lib/core/logging/logger.dart](lib/core/logging/logger.dart).
