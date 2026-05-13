# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## How to work in this repo

Four rules to read before you touch code. Adapted from Andrej Karpathy's published agent guidelines and tuned to this project's tools (OpenSpec, ForUI, `Result`/`Failure`, git-flow). They bias toward caution over speed; for trivial edits, use judgment.

### Think before coding

- State assumptions explicitly before writing code; if uncertain, ask.
- If multiple interpretations of a request exist, surface them — don't pick silently.
- For non-trivial work, run `/openspec-explore` or `/openspec-propose` first; the spec is the source of truth.
- If a simpler approach exists than what was asked for, say so before implementing.
- Confused? Stop, name what's confusing in plain text, ask. Don't guess.

### Simplicity first

- Minimum code that solves the problem. No features beyond what was asked.
- No abstractions for single-use code, no "flexibility" or "configurability" that wasn't requested.
- Return `Result<T>`/`Failure` only at real failure boundaries; don't handle errors for impossible cases.
- Prefer ForUI components and existing patterns (Riverpod providers next to features, `go_router` paths in `RoutePaths`) over inventing new shapes.
- If you wrote 200 lines and 50 would do, rewrite it. "A senior engineer would call this overcomplicated" is the failure signal.

### Surgical changes

- Touch only what the task requires. Don't "improve" adjacent code, comments, or formatting.
- Match existing style, even if you'd do it differently. Don't refactor what isn't broken.
- One OpenSpec change → one branch (`feature/<name>` / `chore/<name>` / `fix/<name>` from `develop`). Don't pile new work onto whatever branch is checked out.
- Remove orphans your edit created (unused imports, dead helpers). Don't delete pre-existing dead code unless asked — mention it.
- Every changed line should trace directly to the request. If it doesn't, drop it.

### Goal-driven execution

- Turn vague tasks into verifiable goals: "fix the bug" → "write a failing test that reproduces it, then make it pass."
- For multi-step work, state the plan as `[step] → verify: [check]` and loop until each check passes.
- Run `just check` (format + analyze + test) before announcing done. For UI changes, also exercise the feature in the running app.
- Mark `tasks.md` checkboxes (`- [ ]` → `- [x]`) as you finish each one, not in a batch at the end.
- Strong success criteria let you finish without a clarifying ping; weak ones ("make it work") need clarification *before* coding, not after a mistake.

## Project state

Foundation in place — **Quran Companion**, a desktop Quran player paired with a local MCP server for safe AI integration. See [IDEA.md](IDEA.md) for the full product brief (target platforms, MVP scope, MCP tool/resource surface, safety rules, *"trustworthy before powerful"* principle).

Wired today (after `bootstrap-foundation`, `quran-data-layer`, `mushaf-reader`, `audio-player-foundation`):

- ForUI-themed app shell with light/dark/system mode and persistent selection ([lib/app/](lib/app/)).
- `go_router` declarative routing with placeholder pages for every MVP top-level area ([lib/features/](lib/features/)).
- Riverpod state, `Result`/`Failure` types ([lib/core/error/](lib/core/error/)), and `appLogger` facade ([lib/core/logging/](lib/core/logging/)).
- **Quran data layer** — bundled SQLite Tanzil Uthmani edition (114 surahs / 6,236 ayahs), domain contracts in [lib/domain/quran/](lib/domain/quran/), SQLite-backed impl in [lib/data/quran/](lib/data/quran/), fail-closed integrity check, source attribution in Settings + [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- **Mushaf reader** ([lib/features/reader/](lib/features/reader/)) — printed-mushaf page view via [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) (default) and continuous text scroll. Three deep-link routes (`/reader/page/{n}`, `/reader/surah/{n}`, `/reader/ayah/{s}/{a}`). Framework-free `MushafLocator` ([lib/domain/quran/mushaf_locator.dart](lib/domain/quran/mushaf_locator.dart)) is the seam for future audio/search/bookmark/MCP work. Graceful text-mode fallback on QCF init failure — never fatal.
- **Audio player foundation** ([lib/features/player/](lib/features/player/) + [lib/domain/audio/](lib/domain/audio/) + [lib/data/audio/](lib/data/audio/)) — verse playback for Mohamed Siddiq al-Minshawi via Quran.com / Quran Foundation public content API (recitation id `9`). Bottom mini player from app shell; reader follows active playback. Surah playback opens resolved ayah URIs as one `media_kit` playlist. Streaming-only today; downloads land behind `AudioRepository` later.
- Smoke + integration + widget tests for shell, navigation, theme switch, unknown-route redirect, integrity check, repository contract, QCF locator + import boundary, reader routes, Surahs→reader handoff, graceful-degrade banner, Settings toggles ([test/](test/)).

Not yet implemented: search UX (FTS5 index exists), bookmarks, MCP server, offline audio downloads, multiple reciters, repeat/speed controls, MCP playback control. Each lands in its own OpenSpec change.

- Dart SDK `^3.11.0`, Flutter 3.41+ ([pubspec.yaml](pubspec.yaml)). ForUI pinned at `^0.21.3` on the zinc theme variant ([lib/app/state/theme_mode_provider.dart](lib/app/state/theme_mode_provider.dart)).
- Platforms shipped: Windows (MVP), macOS, Linux. `android/`, `ios/`, `web/` were removed; recreate via `flutter create --platforms=<target> .` if a future change reintroduces one.
- Lints come from `package:flutter_lints/flutter.yaml` via [analysis_options.yaml](analysis_options.yaml). Add rules under `linter.rules` rather than disabling lints inline.

### Lib layout

```
lib/
  main.dart                # logging + SharedPreferences + ProviderScope bootstrap
  app/                     # composition: router, theme, app-wide state, shell chrome
  core/                    # cross-cutting: env, error/Result, logging
  features/<area>/         # one folder per top-level area (Surahs + Reader + Player are wired)
  features/reader/         # ReaderScreen + PageMushafView (qcf_quran_plus) + TextReaderView
  features/player/         # mini player, expanded queue, playback state/controller + engine adapter
  domain/audio/            # framework-free contracts: reciters, tracks, queue items, playback state, AudioRepository
  domain/quran/            # framework-free contracts: Surah, Ayah, AyahKey, QuranSource, QuranRepository, MushafLocator
  data/audio/              # Quran.com / Quran Foundation API mapping; no secrets, no downloads
  data/quran/              # SQLite impl + QcfMushafLocator (only file allowed to import qcf_quran_plus, alongside features/reader/widgets/page_mushaf_view.dart)
tool/build_quran_db.dart   # maintainer-only: rebuild assets/quran/quran.sqlite + manifest.json
assets/quran/              # bundled, byte-deterministic DB + manifest with SHA-256 checksums
```

Conventions: **state** via `flutter_riverpod` (providers next to the feature; cross-cutting in [lib/app/state/](lib/app/state/)). **Routing** via `go_router` with paths in `RoutePaths`, names in `RouteNames` ([lib/app/router/route_names.dart](lib/app/router/route_names.dart)); unknown paths → `/`; shell switches `FSidebar` (≥768) ↔ `FBottomNavigationBar` ([lib/app/widgets/app_shell.dart](lib/app/widgets/app_shell.dart)). **Errors**: `Result<T>` ([lib/core/error/result.dart](lib/core/error/result.dart)) + sealed `Failure` ([lib/core/error/failure.dart](lib/core/error/failure.dart)); throw only on programmer errors. **Logging**: `appLogger` ([lib/core/logging/logger.dart](lib/core/logging/logger.dart)) configured once in `main()` via `initLogging()`. Never `print`.

## Tooling and conventions

- **Version control:** `git` on **GitHub**, **git-flow**. Every change ships through a PR — never directly to `main`. `main` must always build. **One change, one branch:** branch from `develop` before the first edit (`feature/<openspec-change-name>` / `chore/...` / `fix/...`); don't pile new work onto whatever is checked out. Stash or commit unrelated work first.
- **Project management:** **Linear** — issues, cycles, roadmap. Not GitHub Issues.
- **UI library:** [forui](https://forui.dev/) — prefer ForUI components over hand-rolled widgets and over `material`/`cupertino` primitives where an equivalent exists. Keep theming centralized.
- **Task runner:** [Justfile](Justfile) at the repo root. Add new repeatable workflows as `just` recipes, not ad-hoc shell snippets in docs.
- **Skills** are committed under [.claude/skills/](.claude/skills/) — one canonical location. Don't keep project skills only in your personal home directory.
- **Platform cascading docs:** each platform folder owns its own `CLAUDE.md` for signing/entitlements/build quirks — [windows/CLAUDE.md](windows/CLAUDE.md), [macos/CLAUDE.md](macos/CLAUDE.md), [linux/CLAUDE.md](linux/CLAUDE.md). Read in addition to this root file when working there.

**Keep docs current.** Each time you complete a task or learn something important, update `AGENTS.md`, `README.md`, or the relevant skill file in the *same* change that introduced the new behavior. If you tweak the agent guidance in *How to work in this repo*, update it in the change that proves out the new rule. `CLAUDE.md` is only a compatibility pointer to `AGENTS.md` — do not put project guidance there.

## Skills

Invoke via `/<skill-name>` when the work matches. All live under [.claude/skills/](.claude/skills/).

- **Flutter Skills** — Flutter/Dart guidance: app structure, state-management choice, widget composition, platform-channel boundaries, asset/font handling, idiomatic Dart. Ten sub-skills cover architecture, testing (widget/integration/previews), responsive layout/overflow, JSON serialization, declarative routing, localization, HTTP. Invoke any with `/flutter-<topic>`.
- **ForUI** ([.claude/skills/forui/SKILL.md](.claude/skills/forui/SKILL.md)) — UI-library reference: current pin (`forui: ^0.21.3`), desktop theme wiring (`FThemes.zinc.light.desktop` + `toApproximateMaterialTheme()` + `FLocalizations`), widget/export map, `FIcons` location (`forui_assets`), pointers to ForUI LLM docs. Check [.claude/skills/forui/INDEX.md](.claude/skills/forui/INDEX.md) before grepping the package cache.
- **OpenSpec** — spec-driven pipeline: `/openspec-explore` → `/openspec-propose` → `/openspec-apply-change` → `/openspec-archive-change`. The spec is the source of truth — update it when scope shifts, then re-implement against it.
- **Impeccable** — frontend quality bar: design audits, visual hierarchy, accessibility, motion, copy, theming. Run after a feature lands to polish, or before a redesign to plan. Out of scope: backend-only or non-UI logic.
- **agent-browser** — browser automation. Use whenever the task involves driving a real browser (visual regression for the web build, smoke-testing a deployed PWA, scraping recitation metadata). Run `agent-browser skills get core` for the actual workflow and command reference (or `agent-browser skills get --full` if you need the expanded version) rather than guessing flags.

## Hooks

Hooks live in committed [.claude/settings.json](.claude/settings.json) with PowerShell glue under [.claude/hooks/](.claude/hooks/). Each one gates the agent deterministically. Install PowerShell 7+ if not present (`winget install Microsoft.PowerShell`).

### Wired up today

- **Auto-formatting on save** — `PostToolUse` on `Edit`/`Write` runs `dart format <file>` on Dart sources via [.claude/hooks/format-on-save.ps1](.claude/hooks/format-on-save.ps1). Non-Dart edits are no-ops; failures print to stderr but never block.
- **Test-on-commit** — `PreToolUse` on `Bash` watches for `git commit` and runs `flutter test` first via [.claude/hooks/pre-commit-tests.ps1](.claude/hooks/pre-commit-tests.ps1). On failure the hook exits 2, blocking the commit and feeding test output back to the agent so it can fix-and-retry without human babysitting.

### Planned

- **Security scanning** — `PostToolUse` runs the deepsec scanner on touched files; flags any auth/authz change.
- **Dependency auditing** — `PreToolUse` on [pubspec.yaml](pubspec.yaml) edits runs a vulnerability check before commit.
- **Interactive checkpoints** — `PreToolUse` prompts the user on risky steps (new packages, schema migrations).
- **Automated sub-agent review** — `Stop` hook fires review subagents over the diff before work is "done."
- **License compliance** — when [pubspec.lock](pubspec.lock) changes, check transitive licenses against an allow-list (block GPL/AGPL/SSPL by default).
- **Skill and docs updates** — `Stop` hook prompts the agent to review whether the change should update `AGENTS.md`, `README.md`, or skill files (the *Keep docs current* rule).

## Commands

PowerShell is the default shell on this machine. Run from the repo root. Common workflows live in the [Justfile](Justfile) — run `just` to see all recipes.

| Just recipe | Underlying command | Purpose |
|---|---|---|
| `just get` | `flutter pub get` | Install deps after editing [pubspec.yaml](pubspec.yaml) |
| `just analyze` | `flutter analyze` | Static analysis (lints + type errors) |
| `just format` | `dart format .` | Format all Dart files |
| `just test` | `flutter test` | All widget/unit tests in `test/` |
| `just test-file <path>` | `flutter test <path>` | Single test file |
| `just test-name <name>` | `flutter test --name <name>` | Single test by name |
| `just run [device]` | `flutter run -d <device>` | Launch (default `windows`); `just devices` to list |
| `just build <target>` | `flutter build <target>` | Release build (`apk`, `windows`, `web`, …) |
| `just check` | format + analyze + test | Pre-commit gate |
| `just build-quran-db` | `dart run tool/build_quran_db.dart` | **Maintainer-only.** Rebuilds [assets/quran/quran.sqlite](assets/quran/quran.sqlite) + [assets/quran/manifest.json](assets/quran/manifest.json) from upstream Tanzil. Idempotent (byte-identical output). Commit both files together. |

If you don't have `just`, the underlying commands work directly. New repeatable workflows belong in the [Justfile](Justfile).

- **Windows-installed CLIs and `PATH`.** GitHub CLI ships at `C:\Program Files\GitHub CLI\gh.exe` and is **not** on the bash `PATH` exposed to Claude Code's `Bash` tool. Call it via PowerShell (where `gh` resolves) or its full path. Same pattern for other Windows-installed CLIs: when bash reports `command not found`, check `Get-Command` in PowerShell first — don't mutate `PATH`.

## Notes for future work

- Windows release metadata (CompanyName, FileDescription, ProductName, version) lives in [windows/runner/Runner.rc](windows/runner/Runner.rc). Update before distributing. macOS/Linux equivalents live in their platform folders.
- The Quran SQLite asset is byte-deterministic, so `dbSha256` in [assets/quran/manifest.json](assets/quran/manifest.json) is a real tamper detector. Don't hand-edit `quran.sqlite` or `manifest.json` — re-run `just build-quran-db`. Integrity check fails closed: any mismatch sends the user to a fatal error screen rather than serving wrong text.
- ForUI bumps are breaking. Centralize the import surface in [lib/app/theme/](lib/app/theme/) and [lib/app/widgets/app_shell.dart](lib/app/widgets/app_shell.dart) so the bump stays bounded. The mushaf reader uses [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) on top of `QuranRepository` and ships ~70 MB of QCF assets for the MVP — defer package replacement or font pruning until the project defines the long-term "perfect rendering" approach. Keep new reader surfaces backed by the repository so MCP and search share one source of truth.
- Audio streams from Quran.com / Quran Foundation today — treat it as remote, mutable metadata. Always validate `verse_key` against local `AyahKey`. Never let audio failures affect Quran text availability. Never embed API secrets in Flutter. Keep surah playback playlist-based so the audio backend can preload and advance without user-visible gaps. No reciter photo is bundled (neutral local artwork/initials). Future offline downloads resolve queue entries to local file URIs behind `AudioRepository` rather than changing player state or UI contracts.
