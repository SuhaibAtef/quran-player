# Quran Companion

A desktop Quran player built with Flutter, paired with a local MCP server that lets approved AI clients interact with Quran data through structured, audited tools.

The goal is a Quran player first — clean, respectful, accurate — with MCP as a controlled integration layer, not a generic AI religious assistant. See [IDEA.md](IDEA.md) for the full product brief, MVP scope, and out-of-scope list.

## What it does

- **Read** the Quran with accurate Arabic text and visible source attribution.
- **Listen** to high-quality recitations with play, pause, seek, next, and previous.
- **Search** Arabic ayah text locally.
- **Bookmark** and resume.
- **Expose** Quran data over MCP so AI clients can `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, and `list_reciters` without hallucinating references.
- **Control** playback over MCP only when the user has granted the playback scope in Settings (default OFF).

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
- MCP is loopback-only over plain HTTP on `127.0.0.1`. The bearer token is the auth boundary.
- MCP playback control is gated on a pre-granted Settings scope (`Allow MCP playback control`, default OFF). Scope-denied calls return a structured `scope_denied` error and never touch player state.
- Every MCP call (Mode A and Mode B) is recorded in a persistent SQLite audit log under the OS Application Support directory. The log auto-prunes rows older than 7 days at app start; a Settings button clears it.
- No remote MCP access. No arbitrary file access or shell command execution through MCP, ever.
- All MCP inputs are validated against strict schemas; secrets never live in the Flutter client.

## Architecture

```
Flutter Desktop App                  packages/quran_mcp_server/
  - Quran reader UI                    - Loopback HTTP listener (mcp_dart adapter)
  - Audio player                       - Read-only Quran tools + resources
  - Search                             - Mode B playback tools (scope-gated)
  - Bookmarks                          - Persistent SQLite audit log (user.db)
  - Settings: MCP toggles              - No Flutter / Riverpod / SharedPreferences imports
  - MCP status screen                  (host adapters bridge to Quran/Audio repos)
```

The MCP surface is local-only and intentionally narrow. The MCP server lives in a Dart workspace package at [packages/quran_mcp_server/](packages/quran_mcp_server/) — Flutter-free, with an `isolation_test` enforcing the boundary. Read-only tools/resources use the same verified repositories as the UI through host adapter ports. Playback tools route through the running app player and gate on a pre-granted Settings scope (`Allow MCP playback control`, default OFF) before they can change playback.

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
  data/quran/                  # SQLite-backed QuranRepository, manifest parser, integrity checker
  data/mcp/                    # host-side MCP adapters (HostQuranDataAdapter, HostAudioAdapter), DTOs, error mapper
  domain/quran/                # framework-free Quran contracts (Surah, Ayah, AyahKey, QuranSource, QuranRepository)
packages/quran_mcp_server/     # workspace member: loopback MCP server (HTTP, mcp_dart, scope toggles, audit log). Flutter-free.
tool/
  build_quran_db.dart          # maintainer-only build tool (see "Building the Quran DB")
assets/quran/
  quran.sqlite                 # bundled, byte-deterministic
  manifest.json                # source attribution + SHA-256 checksums
```

User-writable storage: `path_provider.getApplicationSupportDirectory()/quran/user.db`. Schema v1 has only `audit_log`. The bundled `quran.sqlite` and `muyassar.sqlite` remain read-only and fail-closed; `user.db` is the only SQLite file that fails soft (Quran reads + audio playback continue if it's unavailable).

Conventions:

- **State management** — [Riverpod](https://riverpod.dev) (`flutter_riverpod`). Providers live next to the feature; cross-cutting providers live under `lib/app/state/`.
- **Routing** — [`go_router`](https://pub.dev/packages/go_router). Paths in `RoutePaths`, named routes in `RouteNames` ([`lib/app/router/route_names.dart`](lib/app/router/route_names.dart)).
- **UI** — [ForUI](https://forui.dev/) `^0.21.3`, anchored on the `zinc` theme variant (desktop). Light/dark/system theme mode is persisted via `shared_preferences`.
- **Errors** — return `Result<T>` ([`lib/core/error/result.dart`](lib/core/error/result.dart)) at boundaries that can fail; throw only for programmer errors.
- **Logging** — `appLogger` ([`lib/core/logging/logger.dart`](lib/core/logging/logger.dart)). Configure once in `main()` via `initLogging()`; never `print`.

## Status

Foundation, Quran data layer, mushaf reader, audio-player foundation, basic Quran search, tafsir data, and the realigned local MCP surface are in place. The Surahs page renders the real 114-surah list from a bundled, integrity-checked SQLite asset; tapping a surah opens the reader, which renders either a printed-mushaf page view (`qcf_quran_plus`) or a continuous text scroll (from `QuranRepository`) — toggle in Settings. The player streams verse audio from the Quran.com / Quran Foundation public content API for one default reciter, exposes a bottom mini player with an expandable queue, and drives active-ayah highlighting in both reader modes. The Search page queries Arabic canonical Quran text through the bundled SQLite FTS index and opens results through the existing ayah reader route. The MCP layer lives in the workspace package at [packages/quran_mcp_server/](packages/quran_mcp_server/) — loopback HTTP on `127.0.0.1` via `mcp_dart`, pre-granted Settings scopes for Mode B playback, and a persistent SQLite audit log under the OS Application Support directory with a 7-day prune. Bookmarks land in a subsequent OpenSpec change against this foundation. Tracking lives in:

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
| `just mcp-smoke` | Workspace MCP package + MCP Status UI + user.db graceful-degrade smoke tests |
| `just run [device]` | Launch on a device (default: `windows`) |
| `just build <target>` | Release build (`windows`, `macos`, `linux`) |
| `just check` | format + analyze + test (pre-commit gate) |

If you don't have `just` installed, the underlying `flutter`/`dart` commands work directly.

## Data sources

Quran Companion bundles only verified, attributed text. Full credits live in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

- **Text:** **Tanzil's Uthmani plain text** (114 surahs, 6,236 ayahs), distributed under the [Tanzil Quran Text License](https://tanzil.net/docs/tanzil_license) — verbatim redistribution + attribution required, modification forbidden. The bundled SQLite asset is byte-deterministic and integrity-checked at every launch; if the check fails, the app refuses to render Quran data.
- **Tafsir:** **al-Muyassar** by the [King Fahd Complex for the Printing of the Holy Quran](https://qurancomplex.gov.sa/) (6,236 ayah-level commentaries in Arabic). Free non-commercial redistribution with attribution; no modification. Fetched at maintainer build time from the MIT-licensed [`spa5k/tafsir_api`](https://github.com/spa5k/tafsir_api) mirror at a pinned commit SHA recorded in [tool/build_tafsir_db.dart](tool/build_tafsir_db.dart). Bundled as a separate SQLite asset with its own manifest and integrity check (including an orphan-ayah cross-check against the Quran DB). Data-only in this release — no UI consumer yet.
- **Audio:** verse audio streams from the Quran.com / Quran Foundation public content API using ayah-by-ayah recitation id `9`, Mohamed Siddiq al-Minshawi. Runtime audio playback requires network access today. Surah queues are opened as a single preloaded playlist for smoother ayah-to-ayah playback. The player consumes resolved playable URIs through `AudioRepository`, so a future download manager can replace remote URLs with local cached files without changing player UI.
- **Mushaf rendering:** [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) (MIT) supplies QCF (King Fahd Glorious Qur'an Complex) glyph fonts and the standard 604-page Madani mushaf metadata used by the reader's page mode. **Layout and glyphs only** — canonical text always comes from Tanzil above. The QCF font license status and attribution are tracked in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Search limitations

MVP search is intentionally basic and trustworthy: it searches only the bundled Arabic Tanzil text through SQLite FTS. It does not search translations, tafsir, transliteration, semantic meaning, fuzzy variants, or saved search history.

## MCP local integration

The MCP implementation is intentionally local-only. Toggle **Enable MCP** in Settings, then open MCP Status in the app, click **Start MCP Server**, and use the displayed `http://127.0.0.1:<port>/mcp` URL and bearer token with a local MCP client. The server binds only to loopback (`127.0.0.1`), generates a fresh high-entropy token on each start, validates the bearer token before mcp_dart sees a request, and re-checks `connectionInfo.remoteAddress.isLoopback` per request as defence-in-depth.

Read-only tools (always enabled when MCP is on): `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, `list_reciters`.

Read-only resources: `quran://metadata`, `quran://surahs`, `quran://surah/{surah}`, `quran://ayah/{surah}/{ayah}`, `quran://reciters`.

Playback tools (gated on `Allow MCP playback control`, default OFF): `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, `set_repeat`. When the toggle is OFF, every Mode B call returns a structured `scope_denied` error without invoking the audio bridge. `set_repeat` currently accepts only `off`, matching the player’s current no-repeat behavior.

Every call — Mode A and Mode B, success and failure — is appended to a persistent SQLite `audit_log` table in `user.db` under `path_provider.getApplicationSupportDirectory()/quran/`. `search_quran` queries are truncated at 128 codepoints with a `…[+N more]` marker before being persisted. The MCP Status page renders the most recent 20 rows; Settings has a "Clear MCP audit log" button. Rows older than 7 days are pruned on app start.

Generic local MCP client shape:

```json
{
  "url": "http://127.0.0.1:<port>/mcp",
  "headers": {
    "Authorization": "Bearer <token shown in MCP Status>"
  }
}
```

The audio bridge is available only while the Flutter app and MCP server are running. Mode B tools fail with `scope_denied` if the playback scope is OFF, or with `app_unavailable` / `player_unavailable` if the player can't accept commands.

Development smoke check:

```sh
just mcp-smoke
```

## Building the Quran DB

`assets/quran/quran.sqlite` and `assets/quran/manifest.json` are produced by [tool/build_quran_db.dart](tool/build_quran_db.dart). To rebuild from upstream:

```sh
just build-quran-db
```

The tool downloads the pinned Tanzil Uthmani edition (currently via the [Islamic Network alquran.cloud API](https://alquran.cloud/api), which redistributes Tanzil's `quran-uthmani`), verifies its SHA-256 against an in-source pin, builds the database, and writes the manifest. Re-running with the same upstream produces a byte-identical DB. Commit `quran.sqlite` and `manifest.json` together — the manifest's `dbSha256` is the runtime tamper detector. Network access is required only for this maintainer step; the runtime app is fully offline.

## Building the tafsir DB

`assets/tafsir/muyassar.sqlite` and `assets/tafsir/manifest.json` are produced by [tool/build_tafsir_db.dart](tool/build_tafsir_db.dart). To rebuild:

```sh
just build-tafsir-db
```

The tool downloads 114 per-surah JSON files from `spa5k/tafsir_api` at the pinned commit SHA recorded in the tool source, validates that the parsed entry count is exactly 6,236 and that every `(surah, ayah)` key resolves against the bundled Quran DB, then writes the database and its sibling manifest. The Quran DB must exist first — run `just build-quran-db` if you're starting from a clean checkout. Re-running with the same pin produces a byte-identical DB. Commit `muyassar.sqlite` and `manifest.json` together.

## Contributing

Read [CLAUDE.md](CLAUDE.md) before opening a PR. It covers:

- The skill set vendored in the repo: Flutter, OpenSpec, Impeccable, agent-browser ([.claude/skills/](.claude/skills/)).
- Cascading per-platform notes ([windows](windows/CLAUDE.md), [macos](macos/CLAUDE.md), [linux](linux/CLAUDE.md)).
- Hooks that gate the agent: auto-format on save and test-on-commit, configured in [.claude/settings.json](.claude/settings.json).

PRs target `develop` and must build cleanly; `main` is release-only. Branch protection is on, force-pushes are blocked. Every major feature should arrive with: a Linear issue, an OpenSpec proposal, acceptance criteria, tests, and a linked GitHub pull request.
