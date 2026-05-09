# Quran Companion

A desktop Quran player built with Flutter, paired with a local MCP server that lets approved AI clients interact with Quran data through structured, audited tools.

The goal is a Quran player first — clean, respectful, accurate — with MCP as a controlled integration layer, not a generic AI religious assistant. See [IDEA.md](IDEA.md) for the full product brief, MVP scope, and out-of-scope list.

## What it does

- **Read** the Quran with accurate Arabic text and visible source attribution.
- **Listen** to high-quality recitations with play, pause, seek, next, and previous.
- **Search** ayahs and surahs locally.
- **Bookmark** and resume.
- **Expose** Quran data over MCP so AI clients can `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, and `list_reciters` without hallucinating references.

## Target platforms

| Phase | Platforms |
|---|---|
| MVP | Windows desktop |
| V1 | macOS, Linux |

Android, iOS, and web are not in scope. The mobile/web folders were removed by the `bootstrap-foundation` change ([openspec/changes/bootstrap-foundation/](openspec/changes/bootstrap-foundation/)); reintroducing a target means recreating the folder via `flutter create --platforms=<target> .` and adding a sibling `CLAUDE.md`.

## Project principles

> *The app should remain trustworthy before it becomes powerful.*

Accuracy, attribution, privacy, and respectful Quran handling are more important than adding many features quickly:

- Quran text is preserved exactly as sourced — no edits, no AI regeneration, no invented references.
- Translations and tafsir ship only with clear licensing and attribution.
- MCP is **disabled or read-only by default**. Playback control via MCP requires user approval.
- No remote MCP access in the MVP. No arbitrary file access or shell command execution through MCP, ever.
- All MCP inputs are validated against strict schemas; secrets never live in the Flutter client.

## Architecture

```
Flutter Desktop App         Local Quran MCP Server (sidecar)
  - Quran reader UI           - Quran resources (read)
  - Audio player              - Quran tools (search, get_ayah, …)
  - Search                    - Playback tools (V1, user-gated)
  - Bookmarks                 - Permission checks
  - Settings                  - Audit log
  - MCP status screen
```

The MCP server is a local sidecar process — not a network service — so AI clients on the same machine can pull Quran data through a controlled surface.

### Code layout

```
lib/
  main.dart                    # bootstrap: logging + SharedPreferences + ProviderScope
  app/
    app.dart                   # MaterialApp.router + FTheme builder
    router/                    # go_router config + path/name constants
    state/                     # app-wide Riverpod providers (themeMode, prefs)
    theme/                     # ForUI light/dark + ThemeMode resolver
    widgets/                   # AppShell (FSidebar / FBottomNavigationBar switch)
  core/
    env/                       # AppEnvironment (isDebug, platform helpers)
    error/                     # sealed Failure + Result<T> = Ok | Err
    logging/                   # appLogger facade over package:logging
  features/                    # one folder per top-level area; placeholders today
    home/  surah_detail/  search/  bookmarks/  settings/  mcp_status/
  data/                        # repositories — populated by future changes
  domain/                      # entities + use-cases — populated by future changes
```

Conventions:

- **State management** — [Riverpod](https://riverpod.dev) (`flutter_riverpod`). Providers live next to the feature; cross-cutting providers live under `lib/app/state/`.
- **Routing** — [`go_router`](https://pub.dev/packages/go_router). Paths in `RoutePaths`, named routes in `RouteNames` ([`lib/app/router/route_names.dart`](lib/app/router/route_names.dart)).
- **UI** — [ForUI](https://forui.dev/) `^0.17.0`, anchored on the `zinc` theme variant. Light/dark/system theme mode is persisted via `shared_preferences`. Pinned at 0.17 because 0.18+ requires Flutter 3.41+; bump Flutter first.
- **Errors** — return `Result<T>` ([`lib/core/error/result.dart`](lib/core/error/result.dart)) at boundaries that can fail; throw only for programmer errors.
- **Logging** — `appLogger` ([`lib/core/logging/logger.dart`](lib/core/logging/logger.dart)). Configure once in `main()` via `initLogging()`; never `print`.

## Status

Foundation in place — ForUI-themed shell with declarative routing, Riverpod state, and a smoke test. No domain code yet (Quran data, audio, search, bookmarks, MCP all land in subsequent OpenSpec changes). Tracking lives in:

- **Linear** — issues, cycles, roadmap.
- **GitHub** — branches and pull requests. `develop` is the integration branch; `main` is release-only.
- **OpenSpec** ([openspec/](openspec/)) — every non-trivial change starts with a proposal under [openspec/changes/](openspec/changes/).

## Development workflow

```
Linear issue → OpenSpec proposal → feature branch → implementation → tests → PR → review → merge
```

Day-to-day commands are wrapped in the [Justfile](Justfile) — run `just` to list every recipe:

| Recipe | Purpose |
|---|---|
| `just get` | Install Dart/Flutter dependencies |
| `just analyze` | Lints and type errors |
| `just test` | All widget/unit tests |
| `just run [device]` | Launch on a device (default: `windows`) |
| `just build <target>` | Release build (`windows`, `macos`, `linux`) |
| `just check` | format + analyze + test (pre-commit gate) |

If you don't have `just` installed, the underlying `flutter`/`dart` commands work directly.

## Contributing

Read [CLAUDE.md](CLAUDE.md) before opening a PR. It covers:

- The skill set vendored in the repo: Flutter, OpenSpec, Impeccable, agent-browser ([.claude/skills/](.claude/skills/)).
- Cascading per-platform notes ([windows](windows/CLAUDE.md), [macos](macos/CLAUDE.md), [linux](linux/CLAUDE.md)).
- Hooks that gate the agent: auto-format on save and test-on-commit, configured in [.claude/settings.json](.claude/settings.json).

PRs target `develop` and must build cleanly; `main` is release-only. Branch protection is on, force-pushes are blocked. Every major feature should arrive with: a Linear issue, an OpenSpec proposal, acceptance criteria, tests, and a linked GitHub pull request.
