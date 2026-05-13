# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Foundation in place — **Quran Companion**, a desktop Quran player paired with a local MCP server for safe AI integration. See [IDEA.md](IDEA.md) for the full product brief: target platforms (Windows MVP; macOS + Linux for V1), MVP scope, MCP tool/resource surface, safety rules, and the *"trustworthy before powerful"* project principle that should drive scope decisions.

What's wired today (after `bootstrap-foundation` and `quran-data-layer`):

- ForUI-themed app shell with light/dark/system mode and persistent selection ([lib/app/](lib/app/)).
- `go_router` declarative routing for every top-level area in IDEA.md MVP — Home/Surahs, Search, Bookmarks, Settings, MCP Status ([lib/features/](lib/features/)).
- Riverpod state, `Result`/`Failure` types in [lib/core/error/](lib/core/error/), and an `appLogger` facade in [lib/core/logging/](lib/core/logging/).
- **Quran data layer** — bundled SQLite asset ([assets/quran/quran.sqlite](assets/quran/quran.sqlite)) of the Tanzil Uthmani edition (114 surahs / 6,236 ayahs), produced by [tool/build_quran_db.dart](tool/build_quran_db.dart). Domain contracts in [lib/domain/quran/](lib/domain/quran/), SQLite-backed implementation in [lib/data/quran/](lib/data/quran/), runtime fail-closed integrity check, and a Riverpod `quranBootstrapProvider` that the router consumes. Surahs page now renders the real list. Source attribution surfaces in Settings; full credits in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- **Mushaf reader** — drill-down from the Surahs list with two render modes: a printed-mushaf page view backed by [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) (default) and a continuous text scroll backed by `QuranRepository`. Persisted toggle in Settings. Three deep-link routes: `/reader/page/{n}`, `/reader/surah/{n}`, `/reader/ayah/{s}/{a}` (the third redirects into whichever mode is active). Framework-free `MushafLocator` ([lib/domain/quran/mushaf_locator.dart](lib/domain/quran/mushaf_locator.dart)) + QCF-backed implementation ([lib/data/quran/mushaf_locator_qcf.dart](lib/data/quran/mushaf_locator_qcf.dart)) is the seam future audio/search/bookmark/MCP changes use to drive the reader without importing the rendering package directly. If `qcf_quran_plus` ever fails to initialize, the reader degrades to text mode for the session and shows a non-fatal banner — never the data-integrity fatal screen.
- **Audio player foundation** — API-backed verse playback for one approved default reciter, Mohamed Siddiq al-Minshawi via Quran.com / Quran Foundation public content API recitation id `9`. Domain contracts live under [lib/domain/audio/](lib/domain/audio/) and stay framework-free; API mapping lives under [lib/data/audio/](lib/data/audio/); playback state/UI lives under [lib/features/player/](lib/features/player/). The bottom mini player is mounted from the app shell and exposes play/pause/seek/next/previous plus an expandable queue. The reader follows active playback: text mode scrolls to and highlights the active ayah, and page mode passes a QCF highlight while moving to the active ayah's mushaf page. Surah playback opens the resolved ayah URIs as one `media_kit` playlist so the backend can preload/advance between verses instead of reopening each verse on completion. Runtime streaming requires network access; no audio files are downloaded yet. Keep future download-manager work behind `AudioRepository` so player UI consumes resolved URIs rather than caring whether audio is remote or cached.
- **Basic Quran search** — Search page queries Arabic canonical Quran text through `QuranRepository.searchAyahs()`, backed by the bundled SQLite `ayah_fts` index. Results show trustworthy ayah references, surah names, and Tanzil text, then open the existing `/reader/ayah/{s}/{a}` deep link so reader-mode routing stays centralized. MVP search is intentionally narrow: Arabic canonical text only, no translation, tafsir, fuzzy matching, semantic search, search history, or query persistence.
- Smoke + integration + widget tests guarding shell, navigation, theme switch, unknown-route redirect, the data-layer integrity check, the repository contract against the real bundled DB, the QCF locator + import-boundary, reader routes (page/surah/ayah deep links + redirects to / for malformed input), the Surahs-list → reader handoff, the graceful-degrade banner, and Settings toggles ([test/](test/)).

What's not yet implemented: bookmarks, MCP server, offline audio downloads, multiple reciters, repeat/speed controls, and MCP playback control. Each lands in its own OpenSpec change against this foundation.

- Dart SDK constraint: `^3.11.0` ([pubspec.yaml:22](pubspec.yaml#L22)). Flutter 3.41+. Bumped during the `mushaf-reader` change to unblock `qcf_quran_plus` (which also lifted the old ForUI 0.17 pin).
- Platforms shipped: Windows (MVP), macOS, Linux. `android/`, `ios/`, `web/` were removed; recreate via `flutter create --platforms=<target> .` if a future change reintroduces one.
- Lints come from `package:flutter_lints/flutter.yaml` via [analysis_options.yaml](analysis_options.yaml). Add project-specific rules under `linter.rules` rather than disabling lints inline.
- ForUI is wired via [`forui: ^0.21.3`](pubspec.yaml#L37) — anchored on the **zinc** theme variant. `FThemes.zinc.light` returns an `FPlatformThemeData` (desktop + touch pair); the project always resolves `.desktop` because we ship desktop-only. `FTheme` is rebuilt inside `MaterialApp.builder` with light/dark resolved from a `themeModeProvider` ([lib/app/state/theme_mode_provider.dart](lib/app/state/theme_mode_provider.dart)). `FLocalizations` delegates and supported locales are registered. Button styling now uses `FButtonVariant.primary | .outline | .secondary | .ghost | .destructive` instead of the old `FButtonStyle.primary()` factories.

### Lib layout

```
lib/
  main.dart                # logging + SharedPreferences + ProviderScope bootstrap
  app/                     # composition: router, theme, app-wide state, shell chrome
  core/                    # cross-cutting: env, error/Result, logging
  features/<area>/         # one folder per top-level area (Surahs, Search + Reader are wired to data; others are placeholders)
  features/reader/         # mushaf reader: ReaderScreen + PageMushafView (qcf_quran_plus) + TextReaderView
  features/player/         # mini player, expanded queue, playback state/controller + engine adapter
  domain/audio/            # framework-free contracts for reciters, tracks, queue items, playback state, AudioRepository
  domain/quran/            # framework-free contracts (Surah, Ayah, AyahKey, QuranSource, QuranRepository, MushafLocator)
  data/audio/              # Quran.com / Quran Foundation API mapping for verse audio; no secrets, no downloads
  data/quran/              # SQLite-backed implementation + QcfMushafLocator (the only file allowed to import qcf_quran_plus, alongside features/reader/widgets/page_mushaf_view.dart)
tool/
  build_quran_db.dart      # maintainer-only: download + build assets/quran/quran.sqlite + manifest.json
assets/quran/
  quran.sqlite             # bundled, byte-deterministic, regenerated via `just build-quran-db`
  manifest.json            # records source, counts, and SHA-256 checksums
```

State, error, logging conventions:

- **State management** — `flutter_riverpod`. Providers live next to the feature that owns them; cross-cutting providers (theme, environment) live in [lib/app/state/](lib/app/state/).
- **Routing** — `go_router`. Paths in `RoutePaths`, names in `RouteNames` ([lib/app/router/route_names.dart](lib/app/router/route_names.dart)). Unknown paths redirect to `/`. The shell switches between `FSidebar` (≥768 wide) and `FBottomNavigationBar` (narrower) via `LayoutBuilder` ([lib/app/widgets/app_shell.dart](lib/app/widgets/app_shell.dart)).
- **Errors** — return `Result<T>` ([lib/core/error/result.dart](lib/core/error/result.dart)) at boundaries that can fail. Use the sealed `Failure` hierarchy ([lib/core/error/failure.dart](lib/core/error/failure.dart)). Throwing is for programmer errors only.
- **Logging** — `appLogger` ([lib/core/logging/logger.dart](lib/core/logging/logger.dart)) configured once in `main()` via `initLogging()`. Never `print`.

## Tooling and conventions

- **Version control:** `git`, hosted on **GitHub**. Follow **git-flow**: every change ships through a PR, never directly to `main`. `main` must always build with no errors — if a PR breaks the build, revert before merging another change.
  - **One change, one branch.** Before the first edit of a new OpenSpec change (`/opsx:apply`) or any non-trivial multi-file work, create a dedicated branch from `develop` — typically `feature/<openspec-change-name>` (or `chore/...` / `fix/...` per the change type). Don't pile a new change onto whatever branch happens to be checked out, even if it looks "almost ready to merge." If the current branch already has uncommitted work, stash it (or ask the user) before switching. Announce the new branch as the first user-visible action of the implementation.
- **Project management:** **Linear** — issues, cycles, and roadmap live there, not in GitHub Issues.
- **UI library:** [forui](https://forui.dev/) — prefer ForUI components over hand-rolled widgets and over `material`/`cupertino` primitives where a ForUI equivalent exists. Keep theming centralized so a swap stays cheap.
- **Task runner:** **Justfile** at the repo root wraps the common `flutter`/`dart` commands. Add new repeatable workflows as `just` recipes rather than as ad-hoc shell snippets in docs.
- **Skills are committed to the repo under [.claude/skills/](.claude/skills/).** The old `.agents/skills/` tree was retired during the `mushaf-reader` change so this repository has one canonical skill location. Whatever skills the team relies on (Flutter Skills, OpenSpec, Impeccable, agent-browser, etc.) must live under version control there so teammates and future agents inherit the same toolkit. Don't keep project skills only in your personal home directory.

### Cascading CLAUDE.md files

This file is the root context. Each platform folder owns its own `CLAUDE.md` for platform-specific notes (signing, entitlements, build quirks, native deps). The MVP ships desktop only — `android/`, `ios/`, and `web/` were removed by the `bootstrap-foundation` change. If a future change reintroduces a mobile or web target, recreate the folder via `flutter create --platforms=<target> .` and add a sibling `CLAUDE.md`.

- [windows/CLAUDE.md](windows/CLAUDE.md)
- [macos/CLAUDE.md](macos/CLAUDE.md)
- [linux/CLAUDE.md](linux/CLAUDE.md)

When working inside one of those folders, read its `CLAUDE.md` in addition to this one. Keep platform-specific guidance out of this root file.

**Keep docs current.** Each time you complete a task or learn important information about the project, you must update `AGENTS.md`, `README.md`, or relevant skill files — in the same change that introduced the new behavior. `CLAUDE.md` is only a compatibility pointer to `AGENTS.md`; do not put project guidance there.

## Skills

The following skills are part of the standard workflow on this project. Skill files live under version control (see *Tooling and conventions* above) so the whole team and every Claude session shares the same toolkit. Invoke via `/<skill-name>` when the work matches.

- **Flutter Skills** — Flutter/Dart guidance: app structure, state-management choice, widget composition, platform-channel boundaries, asset/font handling, and idiomatic Dart. Reach for these whenever a question is Flutter-shaped rather than language-agnostic — e.g. "where should this provider live?", "how do I wire a `MethodChannel`?", "is this widget rebuild necessary?". The vendored set under [.claude/skills/](.claude/skills/) splits into ten focused sub-skills covering architecture, testing (widget/integration/previews), responsive layout and overflow fixes, JSON serialization, declarative routing, localization, and HTTP — invoke any with `/flutter-<topic>`.
- **ForUI** ([.claude/skills/forui/](.claude/skills/forui/SKILL.md)) — the project's UI-library reference. Captures the current pin (`forui: ^0.21.3`), desktop theme wiring (`FThemes.zinc.light.desktop` + `toApproximateMaterialTheme()` + `FLocalizations`), the current widget/export map, the `FIcons` location (`forui_assets`, not `forui`), and pointers to ForUI's LLM docs ([llms.txt](https://forui.dev/docs/llms.txt) / [llms-full.txt](https://forui.dev/docs/llms-full.txt)). Use the companion file [.claude/skills/forui/INDEX.md](.claude/skills/forui/INDEX.md) as the local 0.21.3 quick reference before grepping the package cache or hitting the network.
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
- **Skill and docs updates** — `Stop` hook prompts the agent to review whether the change should update `AGENTS.md`, `README.md`, or any skill file (matching the *Keep docs current* rule above).

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
| `just build-quran-db` | `dart run tool/build_quran_db.dart` | **Maintainer-only.** Downloads the upstream Tanzil Uthmani edition and rebuilds [assets/quran/quran.sqlite](assets/quran/quran.sqlite) + [assets/quran/manifest.json](assets/quran/manifest.json). Requires network access. Idempotent — re-running produces a byte-identical DB. Commit both files together. |

If you don't have `just` installed, the underlying commands above work directly. New repeatable workflows belong in the [Justfile](Justfile), not in ad-hoc docs.

### Tooling paths on this machine

GitHub CLI (`gh`) ships at `C:\Program Files\GitHub CLI\gh.exe` and is **not** on the bash `PATH` exposed to Claude Code's `Bash` tool. Either call it via the full path or use PowerShell, where `gh` resolves through the standard install. Examples:

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" pr create --base develop --title "..."
```

```bash
"/c/Program Files/GitHub CLI/gh.exe" pr list
```

This applies to other Windows-installed CLIs too — when the bash side reports `command not found`, check `Get-Command` in PowerShell first, and prefer running the command via PowerShell or its full path rather than mutating `PATH`.

## Notes for future work

- Windows-only release metadata (CompanyName, FileDescription, ProductName, version) lives in [windows/runner/Runner.rc](windows/runner/Runner.rc). Update before distributing a build. macOS/Linux equivalents live in their respective platform folders.
- ForUI is pinned at `^0.21.3` (raised from `^0.17.0` during the `mushaf-reader` change). If you bump again, expect breaking API changes; centralize the import surface in [lib/app/theme/](lib/app/theme/) and [lib/app/widgets/app_shell.dart](lib/app/widgets/app_shell.dart) so the bump is bounded.
- The Quran SQLite asset is byte-deterministic for a given upstream text, so `dbSha256` in [assets/quran/manifest.json](assets/quran/manifest.json) is a real tamper detector. Don't hand-edit `quran.sqlite` or `manifest.json` — re-run `just build-quran-db`. The runtime integrity check fails closed: any mismatch sends the user to a fatal error screen rather than serving wrong text.
- The visual mushaf reader uses [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) on top of the existing `QuranRepository` and ships its ~70 MB QCF asset bundle as-is for the MVP. Defer package replacement, font pruning/vendoring, or a different Quran rendering method until the project defines the long-term "perfect rendering" approach. Keep new reader surfaces backed by the repository so MCP and search continue to share one source of truth.
- The audio player streams verse files from Quran.com / Quran Foundation today. Treat that source as remote, mutable metadata: always validate `verse_key` against local `AyahKey`, never let audio failures affect Quran text availability, and never embed API secrets in Flutter. Keep surah playback playlist-based so the audio backend can preload and advance between ayahs without user-visible gaps. No approved reciter photo is bundled; the player uses neutral local artwork/initials. Future offline downloads should resolve queue entries to local file URIs behind `AudioRepository` rather than changing player state or UI contracts.
