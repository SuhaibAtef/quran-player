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
packages/tarteel_qul/          # workspace member: QUL printed-mushaf rendering engine. Asset-agnostic, publishable.
tool/
  build_quran_db.dart          # maintainer-only build tool (see "Building the Quran DB")
assets/quran/
  quran.sqlite                 # bundled, byte-deterministic
  manifest.json                # source attribution + SHA-256 checksums
assets/qul/                    # gitignored — contributor-downloaded QUL mushaf data (see Setup)
```

User-writable storage: `path_provider.getApplicationSupportDirectory()/quran/user.db`. Schema v1 has only `audit_log`. The bundled `quran.sqlite` and `muyassar.sqlite` remain read-only and fail-closed; `user.db` is the only SQLite file that fails soft (Quran reads + audio playback continue if it's unavailable).

Conventions:

- **State management** — [Riverpod](https://riverpod.dev) (`flutter_riverpod`). Providers live next to the feature; cross-cutting providers live under `lib/app/state/`.
- **Routing** — [`go_router`](https://pub.dev/packages/go_router). Paths in `RoutePaths`, named routes in `RouteNames` ([`lib/app/router/route_names.dart`](lib/app/router/route_names.dart)).
- **UI** — [ForUI](https://forui.dev/) `^0.21.3`, anchored on the `zinc` theme variant (desktop). Light/dark/system theme mode is persisted via `shared_preferences`.
- **Errors** — return `Result<T>` ([`lib/core/error/result.dart`](lib/core/error/result.dart)) at boundaries that can fail; throw only for programmer errors.
- **Logging** — `appLogger` ([`lib/core/logging/logger.dart`](lib/core/logging/logger.dart)). Configure once in `main()` via `initLogging()`; never `print`.

## Status

Foundation, Quran data layer, mushaf reader, audio-player foundation, basic Quran search, tafsir data, and the realigned local MCP surface are in place. The Surahs page renders the real 114-surah list from a bundled, integrity-checked SQLite asset; tapping a surah opens the reader, which renders either a printed-mushaf page view (the in-repo `tarteel_qul` QUL rendering engine) or a continuous text scroll (from `QuranRepository`) — toggle in Settings. The player streams verse audio from the Quran.com / Quran Foundation public content API for one default reciter, exposes a bottom mini player with an expandable queue, and drives active-ayah highlighting in both reader modes. The Search page queries Arabic canonical Quran text through the bundled SQLite FTS index and opens results through the existing ayah reader route. The MCP layer lives in the workspace package at [packages/quran_mcp_server/](packages/quran_mcp_server/) — loopback HTTP on `127.0.0.1` via `mcp_dart`, pre-granted Settings scopes for Mode B playback, and a persistent SQLite audit log under the OS Application Support directory with a 7-day prune. Bookmarks land in a subsequent OpenSpec change against this foundation. Tracking lives in:

- **Linear** — issues, cycles, roadmap.
- **GitHub** — branches and pull requests. `develop` is the integration branch; `main` is release-only.
- **OpenSpec** ([openspec/](openspec/)) — every non-trivial change starts with a proposal under [openspec/changes/](openspec/changes/).

## Setup — download the QUL mushaf assets (required)

The reader's page mode renders the printed mushaf from **Tarteel QUL** (Quran
Universal Library) data. Those files are **not committed to this repository**
(~70 MB of third-party fonts and databases) — `assets/qul/` is gitignored. **A
fresh clone cannot `flutter build` or `flutter run` until the files below are
in place**, because `pubspec.yaml` declares them as Flutter assets.

Download the QPC V4 resources from [qul.tarteel.ai](https://qul.tarteel.ai/)
and place them in an `assets/qul/` directory:

| File | QUL resource |
|---|---|
| `assets/qul/qpc-v4-tajweed-15-lines.db` | QPC V4 — 15-line mushaf page layout |
| `assets/qul/qpc-v4.db` | QPC V4 — word-by-word glyph script |
| `assets/qul/ttf.zip` | QPC V4 — per-page fonts (604 `pN.ttf` files) |
| `assets/qul/surah_headers/QCF_SurahHeader_COLOR-Regular.ttf` | QUL ornamental surah-header colour font |
| `assets/qul/juz_name_font/quran-common.ttf` | QUL `quran-common` font (bismillah glyph) |

QUL exports the databases and header fonts inside `.zip` archives — unzip
those so the bare `.db` / `.ttf` files sit at the paths above. Keep `ttf.zip`
as a zip (the app unzips per-page fonts on demand). End users download
nothing: a published build already bundles these inside the app binary. If the
files are missing or invalid at runtime the reader degrades to text mode — it
never fails closed.

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
| `just ci` | format-check + analyze + test (the exact gate CI runs) |

If you don't have `just` installed, the underlying `flutter`/`dart` commands work directly.

## Continuous integration & releases

GitHub Actions runs two workflows ([.github/workflows/](.github/workflows/)):

- **CI** — on every pull request to `develop`/`main` and every push to those branches, runs the `just ci` gate (format check, static analysis, and tests for the host app plus the `quran_mcp_server` and `tarteel_qul` workspace packages) on Ubuntu. Run `just ci` locally to reproduce it exactly.
- **Release** — on push to `main`, builds release binaries for Windows, macOS, and Linux on native runners, packages each (`quran-companion-<version>-<platform>.zip` / `.tar.gz`), and publishes a GitHub Release tagged `v<version>` derived from `pubspec.yaml`. A merge that does not change the version is not republished.

**Released binaries are unsigned.** Windows SmartScreen and macOS Gatekeeper warn on first launch — on Windows choose *More info → Run anyway*; on macOS right-click the app and choose *Open*. Code signing and notarization are deferred enhancements.

### QUL CI bundle (maintainer)

CI runs on fresh checkouts where `assets/qul/` is empty — it is gitignored (see [Setup](#setup--download-the-qul-mushaf-assets-required)). Rather than committing the ~70 MB of QUL files, both workflows fetch them from a side-channel GitHub Release:

1. A maintainer zips the local `assets/qul/` contents — the three root files (`qpc-v4-tajweed-15-lines.db`, `qpc-v4.db`, `ttf.zip`) plus the `surah_headers/` and `juz_name_font/` directories — into `qul-ci-bundle.zip`, preserving that layout.
2. They create a **draft** GitHub Release tagged `qul-assets-v1` in this repository and upload `qul-ci-bundle.zip` as its asset. A draft keeps the bundle off the public Releases page while still letting `gh release download` retrieve it with the workflow's `GITHUB_TOKEN`.
3. The [setup-qul-assets](.github/actions/setup-qul-assets/action.yml) composite action restores `assets/qul/` from the runner cache, or on a cache miss `gh release download`s the bundle and extracts it — before any `flutter test`/`flutter build` step.

To refresh the bundle, upload a new asset under a new tag (`qul-assets-v2`) and bump the `release-tag` default in the composite action. The QUL files never enter git history.

## Data sources

Quran Companion bundles only verified, attributed text. Full credits live in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

- **Text:** **Tanzil's Uthmani plain text** (114 surahs, 6,236 ayahs), distributed under the [Tanzil Quran Text License](https://tanzil.net/docs/tanzil_license) — verbatim redistribution + attribution required, modification forbidden. The bundled SQLite asset is byte-deterministic and integrity-checked at every launch; if the check fails, the app refuses to render Quran data.
- **Tafsir:** **al-Muyassar** by the [King Fahd Complex for the Printing of the Holy Quran](https://qurancomplex.gov.sa/) (6,236 ayah-level commentaries in Arabic). Free non-commercial redistribution with attribution; no modification. Fetched at maintainer build time from the MIT-licensed [`spa5k/tafsir_api`](https://github.com/spa5k/tafsir_api) mirror at a pinned commit SHA recorded in [tool/build_tafsir_db.dart](tool/build_tafsir_db.dart). Bundled as a separate SQLite asset with its own manifest and integrity check (including an orphan-ayah cross-check against the Quran DB). Data-only in this release — no UI consumer yet.
- **Audio:** verse audio streams from the Quran.com / Quran Foundation public content API using ayah-by-ayah recitation id `9`, Mohamed Siddiq al-Minshawi. Runtime audio playback requires network access today. Surah queues are opened as a single preloaded playlist for smoother ayah-to-ayah playback. The player consumes resolved playable URIs through `AudioRepository`, so a future download manager can replace remote URLs with local cached files without changing player UI.
- **Mushaf rendering:** the reader's page mode renders **Tarteel QUL** (Quran Universal Library) QPC V4 data — page layout, word-by-word glyph script, and KFGQPC per-page fonts — through the in-repo [`tarteel_qul`](packages/tarteel_qul/) rendering engine. **Layout and glyphs only** — canonical text always comes from Tanzil above. The QUL files are a contributor download (see [Setup](#setup--download-the-qul-mushaf-assets-required)), bundled into the app binary; the `tarteel_qul` package itself ships no QUL data. License status and attribution are tracked in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Search limitations

MVP search is intentionally basic and trustworthy: it searches only the bundled Arabic Tanzil text through SQLite FTS. It does not search translations, tafsir, transliteration, semantic meaning, fuzzy variants, or saved search history.

## MCP local integration

The MCP implementation is intentionally local-only and speaks the standard MCP **streamable HTTP** wire protocol via [`mcp_dart`](https://pub.dev/packages/mcp_dart)'s `StreamableHTTPServerTransport`. Toggle **Enable MCP** in Settings, then open MCP Status in the app, click **Start MCP Server**, and use the displayed `http://127.0.0.1:<port>/mcp` URL and bearer token with any compliant streamable-HTTP MCP client. The server binds only to loopback (`127.0.0.1`), generates a fresh high-entropy token on each start, validates the bearer token before mcp_dart sees a request, and re-checks `connectionInfo.remoteAddress.isLoopback` per request as defence-in-depth.

Read-only tools (always enabled when MCP is on): `search_quran`, `get_ayah`, `get_surah`, `list_surahs`, `list_reciters`.

Read-only resources: `quran://metadata`, `quran://surahs`, `quran://reciters` (the templated `quran://surah/{surah}` and `quran://ayah/{surah}/{ayah}` are accessible via the equivalent `get_surah` / `get_ayah` tools).

Playback tools (gated on `Allow MCP playback control`, default OFF): `play_surah`, `play_ayah`, `pause_playback`, `resume_playback`, `stop_playback`, `set_repeat`. When the toggle is OFF, every Mode B call returns a structured `scope_denied` error without invoking the audio bridge. `set_repeat` currently accepts only `off`, matching the player’s current no-repeat behavior.

Every call — Mode A and Mode B, success and failure — is appended to a persistent SQLite `audit_log` table in `user.db` under `path_provider.getApplicationSupportDirectory()/quran/`. `search_quran` queries are truncated at 128 codepoints with a `…[+N more]` marker before being persisted. The MCP Status page renders the most recent 20 rows; Settings has a "Clear MCP audit log" button. Rows older than 7 days are pruned on app start.

### Connect with MCP Inspector

The fastest way to drive the server interactively:

```sh
npx @modelcontextprotocol/inspector
```

Pick **Streamable HTTP** as the transport, paste the URL from MCP Status, and add `Authorization: Bearer <token>` as a custom header. Click **List Tools** to see all eleven; pick one (e.g. `get_ayah` with `surah=2 ayah=255`) to call.

### Connect with curl (JSON-RPC `2.0`)

The transport speaks JSON-RPC `2.0`. Every call needs the bearer token and (after `initialize`) the `mcp-session-id` header from the initialize response. Set `URL` and `TOKEN` shell variables, then:

```sh
# 1. initialize — returns the mcp-session-id response header
curl -i "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"0.1"}}}'

# 2. tools/list — pass the session-id from step 1
SID="<paste mcp-session-id from step 1's response headers>"
curl "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "mcp-session-id: $SID" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

# 3. tools/call — the same session-id reused
curl "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "mcp-session-id: $SID" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_ayah","arguments":{"surah":2,"ayah":255}}}'

# Without the bearer token — 401, transport never sees it
curl -i "$URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
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
