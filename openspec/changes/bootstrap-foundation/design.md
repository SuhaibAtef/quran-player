## Context

The codebase is a stock `flutter create` scaffold. Before any feature lands, the team needs a single, agreed answer to the questions every Flutter project asks once and lives with: where state lives, how navigation works, how the UI is themed, how errors flow, and where cross-cutting concerns sit. [CLAUDE.md](../../../CLAUDE.md) already pins ForUI as the UI library and a Justfile-driven workflow; [IDEA.md](../../../IDEA.md) pins Windows desktop as the MVP target with macOS and Linux later, and binds the project to a *"trustworthy before powerful"* principle. This design fills in the remaining decisions so subsequent OpenSpec proposals (Quran reader, audio, search, bookmarks, MCP) can focus on behavior.

Stakeholders: the project maintainer (Suhaib) and any future contributor or Claude session that lands feature work. The audit surface — Linear issues, GitHub PRs, the cascading `CLAUDE.md` files — must keep working unchanged.

## Goals / Non-Goals

**Goals:**

- Pick a single state-management library and document the rationale, so feature proposals do not relitigate it.
- Pick a single declarative routing library and define the route table shape new features extend.
- Establish folder boundaries (`app/`, `core/`, `data/`, `domain/`, `features/`) that match Flutter's recommended layered architecture and the *Skills* guidance in [.claude/skills/](../../../.claude/skills/).
- Centralize ForUI theming (light + dark) and expose a runtime toggle that survives app restart.
- Define a `Result<T, F>` / failure type and a logging facade so feature code never reaches for `print` or untyped `Object` errors.
- Trim platform sprawl down to the desktop targets we actually plan to ship.
- Ship a smoke test the pre-commit hook can run in under a few seconds.

**Non-Goals:**

- No Quran data, no audio, no search, no bookmarks, no MCP server. Placeholder pages only.
- No persistence layer beyond `shared_preferences` for the theme choice. Database, migrations, and license-aware audio caching are deferred to feature proposals.
- No mobile (`android/`, `ios/`) or web targets. They are removed; reintroducing them is its own future change.
- No Linear/GitHub workflow changes. The existing `git-flow` + Linear pipeline stands.
- No new hooks. The existing `format-on-save` and `pre-commit-tests` hooks already cover the scope.

## Decisions

### State management — Riverpod

Use `flutter_riverpod` (latest 2.x with the code-generation flavor where it pays off, plain `Provider`/`Notifier` otherwise).

**Why over alternatives:**
- *Provider:* Riverpod is its successor; the maintainer recommends Riverpod for new apps and most of the Flutter ecosystem now mirrors that.
- *BLoC / `flutter_bloc`:* heavier ceremony for a desktop reader-style app where most state is straightforward (selected surah, selected reciter, theme mode, playback state). BLoC's strict event/state separation pays off in larger apps with deeply branching async flows; we do not need that overhead yet.
- *`setState` only:* fine for trivial UIs but cannot cleanly express the global concerns this app already has (theme, playback, MCP server status).
- *GetX / MobX:* less standard, smaller ecosystem, and GetX in particular blurs routing/state/DI in ways that fight ForUI and `go_router`.

Convention: providers live next to the feature they belong to (`features/<feature>/state/`). Cross-cutting providers (theme mode, app environment) live under `app/state/`.

### Routing — go_router

Use `go_router` with a single `GoRouter` configured in `app/router/app_router.dart`. Routes:

```
/                  -> HomeRoute (Surah list placeholder)
/surahs/:id        -> SurahDetailRoute (placeholder)
/search            -> SearchRoute (placeholder)
/bookmarks         -> BookmarksRoute (placeholder)
/settings          -> SettingsRoute (theme toggle lives here)
/mcp               -> McpStatusRoute (placeholder)
```

A `ShellRoute` wraps the five top-level destinations with the ForUI navigation chrome (likely an `FSidebar` on desktop widths, an `FBottomNavigationBar` fallback on narrow widths via `LayoutBuilder`). Deep links work for free since `go_router` is URL-based — useful if the MCP server later needs to deep-link the UI.

**Why over alternatives:**
- *Default `Navigator` 1.0:* imperative, no URL surface, painful for deep links — and IDEA.md's MCP layer is likely to want them.
- *AutoRoute / Beamer:* either heavier code-gen or smaller community than `go_router`, which is the Flutter-team-blessed choice today.

### Folder layout

```
lib/
  main.dart                      // bootstrap only
  app/
    app.dart                     // root ProviderScope + FTheme + MaterialApp.router
    router/                      // go_router config + route names
    theme/                       // ForUI light/dark theme builders + ThemeMode controller
    state/                       // app-wide providers (themeMode, environment)
  core/
    env/                         // AppEnvironment, build flags, paths
    error/                       // Failure sealed class, Result<T, F> typedef
    logging/                     // logger facade over package:logging
  features/
    home/                        // surah list placeholder (real impl in a later change)
    surah_detail/
    search/
    bookmarks/
    settings/                    // real toggle wired here, since theme is foundation work
    mcp_status/
  data/                          // empty for now; future data sources land here
  domain/                        // empty for now; future entities/use-cases land here
```

`data/` and `domain/` are created empty (with a `README.md` placeholder explaining intent) so feature proposals do not have to relitigate where Quran models or repositories belong.

### ForUI theming

- Build `lightTheme` and `darkTheme` once via ForUI's theme builders in `app/theme/app_theme.dart`.
- Wrap the app in `FTheme` at the top of `App` and feed the resolved theme into `MaterialApp.router`.
- A `themeModeProvider` (Riverpod `NotifierProvider`) holds `ThemeMode.system | light | dark`, persisted via `shared_preferences`. Settings page exposes a `FSelectGroup` (or equivalent) for the toggle.
- Custom colors / typography overrides for Arabic Quran display land in a later change. Foundation only ships the default ForUI palette plus light/dark.

### Error handling — `Result<T, F>` + sealed `Failure`

- `core/error/failure.dart`: a sealed `Failure` class with named subtypes (`UnknownFailure`, `IoFailure`, `NetworkFailure`, `ValidationFailure`). Feature changes extend it with their own subtypes when justified.
- `core/error/result.dart`: a `Result<T>` sealed class (`Ok(value)` / `Err(failure)`). Avoids a third-party `dartz`/`fpdart` dependency for the foundation; we can swap later if the team wants it.
- Feature controllers return `AsyncValue<Result<T>>` from Riverpod where async + typed failures matter. Pure-throwing UI code is allowed only for programmer errors (assertion-style), never for I/O or network.

### Logging — `package:logging` facade

- One `Logger appLogger` configured in `main.dart` to print to console in debug and write to a rolling file under the OS-specific app-data path in release. Levels: `INFO` and above go to file, `FINE` only in debug.
- `core/logging/logger.dart` exposes a single `Logger appLogger` and a `LoggerName` enum so feature code uses `appLogger.child('Reader').info(...)` instead of free-form strings.

### Platform pruning

Delete `android/`, `ios/`, `web/` and remove their flags from `pubspec.yaml`. Keep `windows/`, `macos/`, `linux/`. Update [CLAUDE.md](../../../CLAUDE.md) so the cascading list only references surviving folders. The change is a pure deletion — if mobile/web ever come back, that is its own proposal with platform-channel and asset implications.

### Smoke test

Replace the counter test with `widget_test.dart`:

1. Pumps `ProviderScope(child: App())` with an in-memory `themeModeProvider` override.
2. Asserts the home placeholder finds `find.text('Surahs')` (or the chosen home heading).
3. Toggles the provider to `ThemeMode.dark` and asserts a dark-theme-only widget key is present.
4. Taps the Settings nav destination and verifies the theme selector renders.

Total runtime target: < 3 seconds, so the `pre-commit-tests` hook stays cheap.

## Risks / Trade-offs

- *Riverpod lock-in.* If we later prefer BLoC, migration is rewrites. **Mitigation:** keep providers feature-local so the blast radius of a swap stays bounded. The `app/state/` layer is small (themeMode + environment) and trivially portable.
- *Removing `android/`, `ios/`, `web/` is destructive and hard to fully reverse without re-running `flutter create` for those platforms.* **Mitigation:** the deletion is a single commit; the recreate path is documented as `flutter create --platforms=android,ios,web .` if we need it back. Skip it for now and revisit only if a real product need shows up.
- *ForUI is a young library; breaking changes between minor versions are possible.* **Mitigation:** centralize all ForUI imports in `app/theme/` and feature-level UI files; a version bump should be a small surface-area change, not a project-wide search-and-replace.
- *`go_router` and Riverpod refresh interactions can surprise (rebuild loops, stale auth-style guards).* Foundation has no auth, so the surprise surface is small here, but future feature work with route guards must read the `go_router` + Riverpod refresh-listenable docs before adding redirects. Capture as a `core/router/` README note.
- *Smoke test depending on widget text is brittle to copy changes.* **Mitigation:** use `Key` constants (`HomeRouteKeys.title`, etc.) for assertions, not raw strings, so localization or copy edits do not break the test.
- *`shared_preferences` for theme persistence is fine cross-desktop but writes synchronously on some platforms.* For one boolean-ish setting on app start this is acceptable; revisit only if startup latency is a problem.

## Migration Plan

1. Land this change as a single PR off `develop` per the project's git-flow rule. Branch name `feature/bootstrap-foundation` (already partly on `docs/idea-and-readme`; the next branch is the implementation one).
2. Pre-merge gate: `just check` (format + analyze + test) green; smoke test green; `just run windows` opens a window that boots into the home placeholder and lets the user navigate the skeleton.
3. Post-merge: open the next OpenSpec proposal — recommended order matches IDEA.md's MVP list (Quran reader → audio → search → bookmarks → MCP read-only).
4. Rollback: `git revert` the merge commit. No database, no migrations, no external services touched, so rollback is purely code.

## Open Questions

- Which exact ForUI theme variant do we anchor on for the default light/dark palette? Pick during implementation; record the choice in [CLAUDE.md](../../../CLAUDE.md).
- Do we want `riverpod_generator` (`@riverpod` annotations) from day one, or hand-written providers until a feature genuinely needs the codegen ergonomics? Default to hand-written for the foundation; revisit when the first feature pulls in async families.
- Logging file rotation: do we ship a custom rolling appender or accept "one log file per launch" for the foundation? Default to per-launch — a feature change can introduce rotation when the volume justifies it.
