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

Android, iOS, and web are not in scope. The mobile/web folders that `flutter create` left behind will be removed once the desktop app stabilizes.

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

## Status

Fresh `flutter create` scaffold; no domain code yet. The [openspec/](openspec/) workspace is wired and waiting for the first proposal. Tracking lives in:

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
