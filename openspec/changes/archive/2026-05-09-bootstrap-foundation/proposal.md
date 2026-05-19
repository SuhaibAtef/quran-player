## Why

The repo is a default `flutter create` scaffold with a counter demo, while the product brief in [IDEA.md](../../../IDEA.md) calls for a Windows-first desktop Quran Companion built on ForUI, layered architecture, and a strict *"trustworthy before powerful"* principle. Every later feature (Quran reader, audio, search, bookmarks, MCP server) depends on conventions that do not yet exist — folder layout, state-management choice, theming, routing, navigation chrome, error/logging baseline. Establishing them in one focused change keeps subsequent feature proposals small and lets reviewers approve a shared contract once instead of relitigating it inside every PR.

## What Changes

- **BREAKING**: Replace the `flutter create` counter demo in [lib/main.dart](../../../lib/main.dart) with a real app entry point that boots a ForUI-themed window and a routing root.
- Adopt a layered Dart package structure under `lib/`: `data/`, `domain/`, `features/`, `app/`, `core/` — feature folders own their UI, controllers, and state; cross-cutting code lives in `core/`.
- Pick and wire a single state-management approach for the project (Riverpod) so later features inherit it.
- Add `go_router` for declarative navigation and a placeholder route per top-level app area listed in IDEA.md: Home/Surahs, Search, Bookmarks, Settings, MCP Status. Routes render empty placeholder pages — no feature behavior yet.
- Centralize ForUI theming in `lib/app/theme/` with light/dark themes and a runtime switch surfaced in Settings.
- Drop platform folders we do not ship in the MVP (`android/`, `ios/`, `web/`) and trim `pubspec.yaml` to the desktop targets — Windows now, macOS + Linux later. Keep the desktop folders.
- Establish baseline conventions: a logging facade in `core/logging/`, a typed `Result` / failure model in `core/error/`, and an `AppEnvironment` in `core/env/` so secrets and toggles never ship inside widgets.
- Replace [test/widget_test.dart](../../../test/widget_test.dart) with a smoke test that boots the new app shell, asserts the home placeholder renders, and toggles light/dark.
- Update [README.md](../../../README.md) and [CLAUDE.md](../../../CLAUDE.md) to describe the new layout and conventions, matching the *Keep docs current* rule.

## Capabilities

### New Capabilities

- `app-shell`: launchable Windows desktop app — ForUI-themed window with light/dark switching, declarative routing, navigation chrome, and placeholder pages for every top-level area defined in the IDEA.md MVP. Defines the user-observable contract that "the app boots, the user can navigate the empty skeleton, and the theme can be switched."

### Modified Capabilities

<!-- None — there are no existing specs in openspec/specs/ yet. -->

## Impact

- **Code**: full rewrite of [lib/main.dart](../../../lib/main.dart); new tree under `lib/app/`, `lib/core/`, `lib/features/`; rewritten [test/widget_test.dart](../../../test/widget_test.dart).
- **Dependencies**: adds `forui`, `flutter_riverpod`, `go_router`, `logging` (or equivalent) to [pubspec.yaml](../../../pubspec.yaml). Removes nothing critical.
- **Platforms**: removes `android/`, `ios/`, `web/` folders and their `pubspec.yaml` flags. Keeps `windows/`, `macos/`, `linux/`. Per-platform `CLAUDE.md` files for removed platforms are deleted; a Windows-focused [windows/CLAUDE.md](../../../windows/CLAUDE.md) is the only one expected to grow content during this change.
- **Docs**: [README.md](../../../README.md) and root [CLAUDE.md](../../../CLAUDE.md) updated to reflect the new structure, dependencies, and conventions. The cascading `CLAUDE.md` list is trimmed to match the surviving platforms.
- **CI / hooks**: [.claude/hooks/](../../../.claude/hooks/) `format-on-save` and `pre-commit-tests` already cover the new files. No hook changes required.
- **Out of scope**: any Quran data, audio, search, bookmark, or MCP behavior. Those land in subsequent OpenSpec proposals against this foundation.
