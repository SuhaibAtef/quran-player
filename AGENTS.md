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

Wired today (after `bootstrap-foundation`, `quran-data-layer`, `mushaf-reader`, `audio-player-foundation`, `basic-quran-search`, `add-tafsir-data`, `add-mcp-server`, `add-tarteel-qul-mushaf-engine`):

- ForUI-themed app shell with light/dark/system mode and persistent selection ([lib/app/](lib/app/)).
- `go_router` declarative routing for every top-level area in IDEA.md MVP — Home/Surahs, Search, Bookmarks, Settings, MCP Status ([lib/features/](lib/features/)).
- Riverpod state, `Result`/`Failure` types in [lib/core/error/](lib/core/error/), and an `appLogger` facade in [lib/core/logging/](lib/core/logging/).
- **Quran data layer** — bundled SQLite asset ([assets/quran/quran.sqlite](assets/quran/quran.sqlite)) of the Tanzil Uthmani edition (114 surahs / 6,236 ayahs), produced by [tool/build_quran_db.dart](tool/build_quran_db.dart). Domain contracts in [lib/domain/quran/](lib/domain/quran/), SQLite-backed implementation in [lib/data/quran/](lib/data/quran/), runtime fail-closed integrity check, and a Riverpod `quranBootstrapProvider` that the router consumes. Surahs page now renders the real list. Source attribution surfaces in Settings; full credits in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- **Mushaf reader** — drill-down from the Surahs list with two render modes: a printed-mushaf page view backed by the `tarteel_qul` mushaf engine (default) and a continuous text scroll backed by `QuranRepository`. Persisted toggle in Settings. Three deep-link routes: `/reader/page/{n}`, `/reader/surah/{n}`, `/reader/ayah/{s}/{a}` (the third redirects into whichever mode is active). Framework-free `MushafLocator` ([lib/domain/quran/mushaf_locator.dart](lib/domain/quran/mushaf_locator.dart)) + QUL-backed `QulMushafLocator` ([lib/data/quran/mushaf_engine.dart](lib/data/quran/mushaf_engine.dart)) is the seam future audio/search/bookmark/MCP changes use to drive the reader without importing the rendering package directly. The QUL engine opens lazily via `mushafEngineProvider`; if it fails to open (assets missing, schema mismatch, smoke test fails) or a page font fails to load, the reader degrades to text mode for the session and shows a non-fatal banner — never the data-integrity fatal screen.
- **Tarteel QUL mushaf engine** — page mode renders the printed mushaf through [`packages/tarteel_qul/`](packages/tarteel_qul/), a standalone, publishable, asset-agnostic Flutter rendering engine that bundles **zero** QUL data: a consumer supplies layout + word + per-page-font bytes through one `MushafAssetSource` abstraction. Public surface: `MushafAssetSource`, `MushafLayoutRepository` (layout/word parsing + a page↔ayah coordinate API), `MushafController`, and the mode-agnostic, event-emitting `MushafView` widget. The QUL files (`qpc-v4-tajweed-15-lines.db`, `qpc-v4.db`, `ttf.zip`) are a contributor download into a **gitignored** `assets/qul/`, declared as Flutter assets so a build bundles them into the binary — end users download nothing; a fresh clone cannot `flutter build` until the README download step runs. `package:tarteel_qul/` is imported by exactly two host files — [lib/data/quran/mushaf_engine.dart](lib/data/quran/mushaf_engine.dart) (the host `MushafAssetSource` + `QulMushafLocator` + `openMushafEngine`) and [lib/features/reader/widgets/page_mushaf_view.dart](lib/features/reader/widgets/page_mushaf_view.dart) (rendering) — enforced by [test/data/quran/tarteel_qul_import_boundary_test.dart](test/data/quran/tarteel_qul_import_boundary_test.dart). The engine has its own test suite under [packages/tarteel_qul/test/](packages/tarteel_qul/test/) and a runnable `example/` driven by a synthetic `DemoMushafAssetSource`. The QPC V4 fonts are `COLR`/`CPAL` colour fonts carrying six palettes; `MushafView.palette` selects one by rewriting the font's `CPAL` (Flutter renders palette 0 only). The host exposes all six palettes as selectable **colour styles** (`MushafColorScheme` — tajweed/plain × light/dark/variant, each a palette index + `darkPage` flag, persisted via `mushafColorSchemeProvider`, picked in Settings with a live preview that renders page 1 / al-Fātiḥah through the real `MushafView`) — this replaced the dead `qcf`-era tajweed toggle. The chosen style is explicit and independent of the app theme; the dark styles render a dark page with the white-base palette. `surah_name` / `basmallah` lines render the QUL ornamental surah-header (`QCF_SurahHeader_COLOR`) and `quran-common` bismillah fonts, loaded by [lib/data/quran/mushaf_fonts.dart](lib/data/quran/mushaf_fonts.dart); the QUL "surah name" OpenType-SVG font is unused (Flutter cannot render SVG colour fonts).
- **Audio player foundation** — API-backed verse playback for one approved default reciter, Mohamed Siddiq al-Minshawi via Quran.com / Quran Foundation public content API recitation id `9`. Domain contracts live under [lib/domain/audio/](lib/domain/audio/) and stay framework-free; API mapping lives under [lib/data/audio/](lib/data/audio/); playback state/UI lives under [lib/features/player/](lib/features/player/). The bottom mini player is mounted from the app shell and exposes play/pause/seek/next/previous plus an expandable queue. The reader follows active playback: text mode scrolls to and highlights the active ayah, and page mode passes a `MushafView` decoration while moving to the active ayah's mushaf page. Surah playback opens the resolved ayah URIs as one `media_kit` playlist so the backend can preload/advance between verses instead of reopening each verse on completion. Runtime streaming requires network access; no audio files are downloaded yet. Keep future download-manager work behind `AudioRepository` so player UI consumes resolved URIs rather than caring whether audio is remote or cached.
- **Basic Quran search** — Search page queries Arabic canonical Quran text through `QuranRepository.searchAyahs()`, backed by the bundled SQLite `ayah_fts` index (populated by the build tool with alef-wasla / hamza / alef-maksura folded text from [lib/data/quran/arabic_normalization.dart](lib/data/quran/arabic_normalization.dart) so plain queries match the bundled `ٱللَّه`-style tokens). Results show trustworthy ayah references, surah names, and Tanzil text, then open the existing `/reader/ayah/{s}/{a}` deep link so reader-mode routing stays centralized. MVP search is intentionally narrow: Arabic canonical text only, no translation, tafsir, fuzzy matching, semantic search, search history, or query persistence.
- **Tafsir data layer** — bundled SQLite asset ([assets/tafsir/muyassar.sqlite](assets/tafsir/muyassar.sqlite)) of al-Muyassar by the King Fahd Complex (6,236 ayah commentaries), produced by [tool/build_tafsir_db.dart](tool/build_tafsir_db.dart) from `spa5k/tafsir_api` at a pinned commit SHA. Domain contracts in [lib/domain/tafsir/](lib/domain/tafsir/), SQLite-backed implementation in [lib/data/tafsir/](lib/data/tafsir/), runtime fail-closed integrity check (counts + dbSha256 + orphan-key cross-check against the Quran DB) and a Riverpod `tafsirBootstrapProvider` that the router gates on alongside the Quran bootstrap via a new `appBootstrapStatusProvider`. Tafsir source attribution surfaces in Settings under the Quran source row; full credits in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). **Data-only** — no UI consumer yet; the future tafsir reader view and tier III semantic search will both read through `TafsirRepository`.
- **Local MCP surface** — Dart workspace package at [packages/quran_mcp_server/](packages/quran_mcp_server/) (the only file allowed to import `package:mcp_dart` is its `lib/src/adapter/mcp_dart_adapter.dart`; an `isolation_test.dart` enforces this and the wider Flutter-free boundary). The host app provides adapter ports ([lib/data/mcp/host_quran_data_adapter.dart](lib/data/mcp/host_quran_data_adapter.dart), [lib/data/mcp/host_audio_adapter.dart](lib/data/mcp/host_audio_adapter.dart)) that bridge `QuranRepository` and the audio repository / player controller into the package's `McpQuranDataPort` / `McpAudioPort`. The package owns its own `HttpServer.bind(InternetAddress.loopbackIPv4, port)` listener, runs the bearer-token gate before mcp_dart sees a request, and re-checks `connectionInfo.remoteAddress.isLoopback` per request as defence-in-depth. Authorized requests are forwarded to `mcp_dart`'s `StreamableHTTPServerTransport`, so the server speaks the standard MCP streamable-HTTP wire protocol (JSON-RPC `2.0` envelope + `mcp-session-id` header lifecycle) — MCP Inspector and other compliant clients connect directly. MCP Status starts/stops the server and shows the `http://127.0.0.1:<port>/mcp` URL, the fresh bearer token, the active scopes, and the most recent 20 audit-log rows. The five read-only tools (`search_quran`, `get_ayah`, `get_surah`, `list_surahs`, `list_reciters`) and resources (`quran://metadata`, `quran://surahs`, `quran://reciters`; the templated `quran://surah/{surah}` and `quran://ayah/{surah}/{ayah}` are reachable via the equivalent `get_surah` / `get_ayah` tools) are gated by the implicit `Scope.readonly` (granted whenever MCP is enabled). The six Mode B playback tools (`play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, `set_repeat`) gate on `Scope.playback`, which lives behind the **`Allow MCP playback control`** Settings toggle (default OFF). Scope-denied calls return a structured `scope_denied` MCP error and never touch the audio bridge. No non-loopback listener, arbitrary file access, shell execution, tafsir over MCP, semantic search over MCP, or bookmarks over MCP yet.
- **Persistent MCP audit log** — first user-writable SQLite file in the project, at `path_provider.getApplicationSupportDirectory()/quran/user.db`. The `audit_log(id, ts_utc, tool_name, args_summary, result_status, scope_at_time)` table is schema v1. Every MCP call (Mode A and Mode B, success and failure) appends one row. `search_quran` queries are truncated at 128 codepoints with a `…[+N more]` marker before being persisted. Prune runs once on app start and deletes rows older than 7 days. Settings exposes a "Clear MCP audit log" button with Confirm/Cancel. **`user.db` is the only SQLite file in the project that does NOT fail-closed on open failure** — Quran reads + audio playback continue, the Settings MCP section shows a non-fatal notice.
- **Bookmarks & resume** — `user.db` schema v2 adds a `bookmark(surah, ayah, created_at_utc, UNIQUE(surah,ayah))` table and a single-row `reading_position(id=1, surah, ayah, updated_at_utc)` table; the v1→v2 migration is additive and idempotent (`user_db_schema.dart` / `user_db.dart` in the MCP package, which owns the `user.db` file format). Domain contracts live in [lib/domain/bookmarks/](lib/domain/bookmarks/) and [lib/domain/reading/](lib/domain/reading/); SQLite impls in [lib/data/bookmarks/](lib/data/bookmarks/) and [lib/data/reading/](lib/data/reading/), exposed by `userDbStateProvider` via `bookmarkRepositoryProvider` / `readingPositionRepositoryProvider` (null when `user.db` is down → every bookmark/resume surface degrades, never crashes). The **Bookmarks** page lists saved ayahs (newest-first, opens the `/reader/ayah` deep link). Tapping a verse in either reader mode opens a **verse action menu** (`showVerseActionMenu`, a modal sheet) — *Play from here*, *Bookmark*/*Remove bookmark*, and a disabled *Highlight* placeholder. The reader records the last-read position as the user reads — page mode on `onPageChanged`, text mode on scroll-settle + first frame (never in `dispose()`; `WidgetRef` is unusable there) — and the Home page shows a "Continue reading" card that reopens it. MCP bookmark tools are still out of scope; `BookmarkRepository` is shaped so a future MCP change can read through it.
- Smoke + integration + widget tests guarding shell, navigation, theme switch, unknown-route redirect, the data-layer integrity check (Quran + tafsir), the repository contracts against the real bundled DBs, the `QulMushafLocator` + `tarteel_qul` import-boundary, reader routes (page/surah/ayah deep links + redirects to / for malformed input), the Surahs-list → reader handoff, the graceful-degrade banner, the workspace member declaration, the user.db graceful-degrade path, the bookmark + reading-position repository contracts, the Bookmarks page, the verse action menu, the Home resume card, and Settings toggles ([test/](test/)). The workspace packages have their own test suites: [packages/quran_mcp_server/test/](packages/quran_mcp_server/test/) (isolation, scope-denied behaviour, audit-log writes, prune, `args_summary` truncation, the v1→v2 `user.db` schema migration) and [packages/tarteel_qul/test/](packages/tarteel_qul/test/) (isolation/no-bundled-assets, layout + word parsing, schema validation, the coordinate API, `MushafView` event emission + lazy font loading).

What's not yet implemented: offline audio downloads, multiple reciters, real repeat/speed controls, MCP bookmark tools, ayah highlighting, tafsir UI / reader view, topical index (deferred — no public structured concordance available), and semantic search (tiers I/II/III). Each lands in its own OpenSpec change against this foundation. Semantic-search architecture is ratified up front in [`openspec/specs/semantic-search/spec.md`](openspec/specs/semantic-search/spec.md); the tier-1/2/3 implementations land separately and reference that spec.

- Dart SDK `^3.11.0`, Flutter 3.41+ ([pubspec.yaml](pubspec.yaml)). ForUI pinned at `^0.21.3` on the zinc theme variant ([lib/app/state/theme_mode_provider.dart](lib/app/state/theme_mode_provider.dart)).
- Platforms shipped: Windows (MVP), macOS, Linux. `android/`, `ios/`, `web/` were removed; recreate via `flutter create --platforms=<target> .` if a future change reintroduces one.
- Lints come from `package:flutter_lints/flutter.yaml` via [analysis_options.yaml](analysis_options.yaml). Add rules under `linter.rules` rather than disabling lints inline.

### Lib layout

```
lib/
  main.dart                # logging + SharedPreferences + ProviderScope bootstrap
  app/                     # composition: router, theme, app-wide state, shell chrome
  core/                    # cross-cutting: env, error/Result, logging
  features/<area>/         # one folder per top-level area (Surahs, Search + Reader are wired to data; others are placeholders)
  features/reader/         # mushaf reader: ReaderScreen + PageMushafView (tarteel_qul MushafView) + TextReaderView
  features/player/         # mini player, expanded queue, playback state/controller + engine adapter
  domain/audio/            # framework-free contracts: reciters, tracks, queue items, playback state, AudioRepository
  domain/quran/            # framework-free contracts: Surah, Ayah, AyahKey, QuranSource, QuranRepository, MushafLocator
  domain/tafsir/           # framework-free contracts: Tafsir, TafsirSource, TafsirRepository (reuses AyahKey)
  domain/bookmarks/        # framework-free contracts: Bookmark, BookmarkRepository (reuses AyahKey)
  domain/reading/          # framework-free contracts: ReadingPosition, ReadingPositionRepository
  data/audio/              # Quran.com / Quran Foundation API mapping; no secrets, no downloads
  data/mcp/                # host-side MCP adapters: HostQuranDataAdapter, HostAudioAdapter, mcp_dtos, error mapper
  data/quran/              # SQLite impl + mushaf_engine.dart (host MushafAssetSource + QulMushafLocator + openMushafEngine — one of two files allowed to import tarteel_qul, alongside features/reader/widgets/page_mushaf_view.dart)
  data/tafsir/             # SQLite impl + manifest + integrity checker (cross-checks ayah keys against the Quran DB)
  data/bookmarks/          # SQLite impl of BookmarkRepository over the user.db `bookmark` table
  data/reading/            # SQLite impl of ReadingPositionRepository over the user.db `reading_position` table
packages/quran_mcp_server/ # workspace member: loopback MCP server (HTTP, mcp_dart, scope toggles, persistent audit log). Flutter-free; isolation_test enforces the boundary
packages/tarteel_qul/      # workspace member: QUL printed-mushaf rendering engine. Asset-agnostic, publishable; isolation_test enforces no host dep + no bundled QUL data
tool/build_quran_db.dart   # maintainer-only: rebuild assets/quran/quran.sqlite + manifest.json
tool/build_tafsir_db.dart  # maintainer-only: rebuild assets/tafsir/muyassar.sqlite + manifest.json (requires the Quran DB to exist)
assets/quran/              # bundled, byte-deterministic DB + manifest with SHA-256 checksums
assets/tafsir/             # bundled, byte-deterministic tafsir DB + manifest with SHA-256 checksums
assets/qul/                # GITIGNORED — contributor-downloaded QUL mushaf data (layout DB, word DB, ttf.zip, surah-header + quran-common fonts); declared as Flutter assets, bundled at build time
```

User-writable storage: `path_provider.getApplicationSupportDirectory()/quran/user.db`, opened in the background at every app start (`main.dart`) regardless of MCP state. Schema v2 holds `audit_log` (v1) plus `bookmark` and `reading_position` (v2); future playback-history work shares this DB and bumps the schema again. The bundled `quran.sqlite` and `muyassar.sqlite` remain read-only and fail-closed; `user.db` fail-soft.

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
| `just mcp-smoke` | focused `flutter test` files | Workspace MCP package + MCP Status UI + user.db graceful-degrade smoke tests |
| `just test-file <path>` | `flutter test <path>` | Single test file |
| `just test-name <name>` | `flutter test --name <name>` | Single test by name |
| `just run [device]` | `flutter run -d <device>` | Launch (default `windows`); `just devices` to list |
| `just build <target>` | `flutter build <target>` | Release build (`apk`, `windows`, `web`, …) |
| `just check` | format + analyze + test | Pre-commit gate |
| `just build-quran-db` | `dart run tool/build_quran_db.dart` | **Maintainer-only.** Rebuilds [assets/quran/quran.sqlite](assets/quran/quran.sqlite) + [assets/quran/manifest.json](assets/quran/manifest.json) from upstream Tanzil. Idempotent (byte-identical output). Commit both files together. |
| `just build-tafsir-db` | `dart run tool/build_tafsir_db.dart` | **Maintainer-only.** Rebuilds [assets/tafsir/muyassar.sqlite](assets/tafsir/muyassar.sqlite) + [assets/tafsir/manifest.json](assets/tafsir/manifest.json) from `spa5k/tafsir_api` at the pinned commit SHA recorded in the tool source. Requires the Quran DB to already exist (the tool cross-checks every ayah key). Idempotent. Commit both files together. |

If you don't have `just`, the underlying commands work directly. New repeatable workflows belong in the [Justfile](Justfile).

- **Windows-installed CLIs and `PATH`.** GitHub CLI ships at `C:\Program Files\GitHub CLI\gh.exe` and is **not** on the bash `PATH` exposed to Claude Code's `Bash` tool. Call it via PowerShell (where `gh` resolves) or its full path. Same pattern for other Windows-installed CLIs: when bash reports `command not found`, check `Get-Command` in PowerShell first — don't mutate `PATH`.

## Notes for future work

- Windows release metadata (CompanyName, FileDescription, ProductName, version) lives in [windows/runner/Runner.rc](windows/runner/Runner.rc). Update before distributing. macOS/Linux equivalents live in their platform folders.
- The Quran SQLite asset is byte-deterministic, so `dbSha256` in [assets/quran/manifest.json](assets/quran/manifest.json) is a real tamper detector. Don't hand-edit `quran.sqlite` or `manifest.json` — re-run `just build-quran-db`. Integrity check fails closed: any mismatch sends the user to a fatal error screen rather than serving wrong text.
- The tafsir SQLite asset follows the same pattern as the Quran asset — byte-deterministic, fail-closed, attribution-tracked. The build tool also cross-checks every ayah key against the Quran DB at build time and the runtime integrity check repeats that join as defense-in-depth. The composite [`appBootstrapStatusProvider`](lib/app/state/app_bootstrap_status_provider.dart) gates the UI on both integrity checks passing before the main shell renders. Widget tests that override `quranBootstrapProvider` must also override `tafsirBootstrapProvider` (see [test/_fakes/fake_tafsir_bootstrap.dart](test/_fakes/fake_tafsir_bootstrap.dart)).
- ForUI bumps are breaking. Centralize the import surface in [lib/app/theme/](lib/app/theme/) and [lib/app/widgets/app_shell.dart](lib/app/widgets/app_shell.dart) so the bump stays bounded.
- Page mode renders through the in-repo `tarteel_qul` engine on Tarteel QUL data. The QUL files are **not committed** — a contributor downloads `qpc-v4-tajweed-15-lines.db`, `qpc-v4.db`, and `ttf.zip` from qul.tarteel.ai into the gitignored `assets/qul/` (README setup step); `pubspec.yaml` declares them as Flutter assets so a build bundles them into the binary. A fresh clone cannot `flutter build` (or `flutter test`) until the download is done — this is accepted (D6). The QUL files are third-party downloads, not byte-deterministic project assets, so there is no SHA-256 fail-closed gate: `openMushafEngine` does a light structural check (604 pages + a smoke test) and degrades to text mode on any failure. Keep `package:tarteel_qul/` confined to its two host files and keep new reader surfaces backed by `QuranRepository` so MCP and search share one source of truth. The `tarteel_qul` package ships ~0 bytes of QUL data and stays publishable; the *app* binary redistributes the KFGQPC fonts (see `THIRD_PARTY_NOTICES.md`). Font pruning (~167 MB unzipped) is a later optimization.
- Audio streams from Quran.com / Quran Foundation today — treat it as remote, mutable metadata. Always validate `verse_key` against local `AyahKey`. Never let audio failures affect Quran text availability. Never embed API secrets in Flutter. Keep surah playback playlist-based so the audio backend can preload and advance without user-visible gaps. No reciter photo is bundled (neutral local artwork/initials). Future offline downloads resolve queue entries to local file URIs behind `AudioRepository` rather than changing player state or UI contracts.
- MCP is local-only and deliberately narrow. The workspace package at [packages/quran_mcp_server/](packages/quran_mcp_server/) owns its own `HttpServer.bind(InternetAddress.loopbackIPv4, port)` listener, validates each request's `Authorization: Bearer <token>` header and `connectionInfo.remoteAddress.isLoopback` as defence-in-depth, then forwards authorized requests to `mcp_dart`'s `StreamableHTTPServerTransport` (standard JSON-RPC `2.0` MCP wire protocol). The bearer + loopback gates MUST stay in `server.dart` ahead of the transport — never move them into `mcp_dart`'s transport options where the `isolation_test` can't see them. Do not add non-loopback transports, arbitrary filesystem reads, shell execution, or new scopes without a new OpenSpec change. Read-only MCP calls must go through the existing `QuranRepository`/`AudioRepository` via the host adapter ports. Mode B playback tools gate on the `Allow MCP playback control` Settings toggle (Riverpod `scopeCheckProvider`); a scope-denied call returns a structured `scope_denied` MCP error and never invokes the audio bridge. Both Mode A reads and Mode B writes append a row to the persistent `user.db` audit log. `set_repeat` currently supports only `off` because repeat playback is not implemented yet.
