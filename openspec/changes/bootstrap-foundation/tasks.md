## 1. Branch and dependency baseline

- [ ] 1.1 Create implementation branch `feature/bootstrap-foundation` off `develop` per the project's git-flow rule.
- [ ] 1.2 Add `forui`, `flutter_riverpod`, `go_router`, `logging`, and `shared_preferences` to [pubspec.yaml](../../../pubspec.yaml); pin to current stable versions.
- [ ] 1.3 Run `just get` and confirm `pubspec.lock` resolves cleanly.
- [ ] 1.4 Run `just analyze` against the current scaffold and capture any pre-existing warnings to fix on the way.

## 2. Platform pruning

- [ ] 2.1 Delete `android/`, `ios/`, and `web/` folders.
- [ ] 2.2 Remove the corresponding platform flags from [pubspec.yaml](../../../pubspec.yaml).
- [ ] 2.3 Delete `android/CLAUDE.md`, `ios/CLAUDE.md`, and `web/CLAUDE.md`.
- [ ] 2.4 Update the cascading `CLAUDE.md` list in root [CLAUDE.md](../../../CLAUDE.md) to only reference `windows/`, `macos/`, and `linux/`.
- [ ] 2.5 Run `flutter doctor` and `just analyze` to confirm the trim broke nothing on the desktop targets.

## 3. Layered folder structure

- [ ] 3.1 Create `lib/app/`, `lib/core/`, `lib/data/`, `lib/domain/`, `lib/features/` and add a short `README.md` placeholder in each explaining its intent.
- [ ] 3.2 Inside `lib/features/`, create one folder per top-level area: `home/`, `surah_detail/`, `search/`, `bookmarks/`, `settings/`, `mcp_status/`. Each gets an `<area>_page.dart` that renders a ForUI placeholder screen with a `Key` constant (e.g. `HomeRouteKeys.title`).
- [ ] 3.3 Create `lib/core/env/app_environment.dart` with a `const AppEnvironment` exposing `isDebug`, app name, and OS-specific data-path helper.
- [ ] 3.4 Create `lib/core/error/failure.dart` with a sealed `Failure` and the named subtypes listed in design.md.
- [ ] 3.5 Create `lib/core/error/result.dart` with the `Result<T>` sealed class (`Ok` / `Err`).
- [ ] 3.6 Create `lib/core/logging/logger.dart` exposing `appLogger` configured against `package:logging`, with debug/release behavior described in design.md.

## 4. App shell, theming, and routing

- [ ] 4.1 Create `lib/app/theme/app_theme.dart` building ForUI light and dark themes.
- [ ] 4.2 Create `lib/app/state/theme_mode_provider.dart` — Riverpod `NotifierProvider<ThemeMode>` backed by `shared_preferences`, defaulting to `ThemeMode.system`.
- [ ] 4.3 Create `lib/app/router/app_router.dart` with the routes from design.md, a `ShellRoute` providing the navigation chrome, and a fallback redirect to `/` for unknown paths.
- [ ] 4.4 Create `lib/app/router/route_names.dart` with constants for each route path so feature code never hard-codes strings.
- [ ] 4.5 Create `lib/app/app.dart` — `ProviderScope` + `FTheme` + `MaterialApp.router`, wiring the theme mode and router from steps 4.1–4.3.
- [ ] 4.6 Build the navigation chrome: an `FSidebar` (or ForUI equivalent) for desktop widths and a fallback `FBottomNavigationBar` for narrow widths, switched via `LayoutBuilder`.
- [ ] 4.7 Wire the Settings placeholder page to expose a real theme selector backed by `themeModeProvider` (the only non-placeholder feature in this change).
- [ ] 4.8 Replace [lib/main.dart](../../../lib/main.dart) with a thin `main()` that configures `appLogger`, calls `WidgetsFlutterBinding.ensureInitialized()`, awaits `SharedPreferences.getInstance()`, and runs `App` inside `ProviderScope`.

## 5. Smoke test

- [ ] 5.1 Replace [test/widget_test.dart](../../../test/widget_test.dart) with a smoke test that pumps `ProviderScope(child: App())` with a `themeModeProvider` override.
- [ ] 5.2 Add assertions for: home placeholder rendered, navigation to Settings works, theme toggle from light → dark surfaces a dark-only widget by `Key`, deep link to `/settings` lands on the Settings route, unknown route redirects to `/`.
- [ ] 5.3 Confirm the test runs in under ~3 seconds locally so the `pre-commit-tests` hook stays cheap.

## 6. Documentation

- [ ] 6.1 Update [README.md](../../../README.md) with the new folder layout, run/build commands, and dependency list.
- [ ] 6.2 Update root [CLAUDE.md](../../../CLAUDE.md): note the new `lib/` layout, Riverpod + go_router + ForUI choices, the `Result`/`Failure` and logging conventions, and the trimmed cascading-CLAUDE list.
- [ ] 6.3 Add or update [windows/CLAUDE.md](../../../windows/CLAUDE.md) with any Windows-specific notes uncovered during implementation (window sizing defaults, MSIX packaging stubs if any).
- [ ] 6.4 If a ForUI default theme variant is chosen during implementation (open question in design.md), record the choice in root [CLAUDE.md](../../../CLAUDE.md).

## 7. Verification gate

- [ ] 7.1 `just format` clean.
- [ ] 7.2 `just analyze` clean.
- [ ] 7.3 `just test` green.
- [ ] 7.4 `just run windows` opens the window into the Home placeholder; manually navigate to Search, Bookmarks, Settings, and MCP Status; toggle theme and restart to confirm persistence.
- [ ] 7.5 `just check` green from a clean checkout (matches the pre-merge gate in design.md).

## 8. Ship

- [ ] 8.1 Open a draft PR titled `feat(foundation): bootstrap app shell, theming, routing` against `develop` with the OpenSpec change linked in the description.
- [ ] 8.2 Address review feedback on the branch only (no `--amend` of merged commits per [CLAUDE.md](../../../CLAUDE.md) policy).
- [ ] 8.3 Merge via the standard PR flow once `main`/`develop` checks pass.
- [ ] 8.4 Run `/opsx:archive` on this change to move it under `openspec/archive/`.
