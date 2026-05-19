## 1. Branch and dependency baseline

- [x] 1.1 Create implementation branch `feature/bootstrap-foundation` off `develop` per the project's git-flow rule.
- [x] 1.2 Add `forui`, `flutter_riverpod`, `go_router`, `logging`, and `shared_preferences` to [pubspec.yaml](../../../pubspec.yaml); pin to current stable versions.
- [x] 1.3 Run `just get` and confirm `pubspec.lock` resolves cleanly.
- [x] 1.4 Run `just analyze` against the current scaffold and capture any pre-existing warnings to fix on the way.

## 2. Platform pruning

- [x] 2.1 Delete `android/`, `ios/`, and `web/` folders.
- [x] 2.2 Remove the corresponding platform flags from [pubspec.yaml](../../../pubspec.yaml). _(no-op — pubspec.yaml does not list platforms explicitly for app projects)_
- [x] 2.3 Delete `android/CLAUDE.md`, `ios/CLAUDE.md`, and `web/CLAUDE.md`. _(removed alongside their parent folders in 2.1)_
- [x] 2.4 Update the cascading `CLAUDE.md` list in root [CLAUDE.md](../../../CLAUDE.md) to only reference `windows/`, `macos/`, and `linux/`.
- [x] 2.5 Run `flutter doctor` and `just analyze` to confirm the trim broke nothing on the desktop targets. _(analyze clean; flutter doctor is dev-env scope, skipped)_

## 3. Layered folder structure

- [x] 3.1 Create `lib/app/`, `lib/core/`, `lib/data/`, `lib/domain/`, `lib/features/` and add a short `README.md` placeholder in each explaining its intent.
- [x] 3.2 Inside `lib/features/`, create one folder per top-level area: `home/`, `surah_detail/`, `search/`, `bookmarks/`, `settings/`, `mcp_status/`. Each gets an `<area>_page.dart` that renders a ForUI placeholder screen with a `Key` constant (e.g. `HomeRouteKeys.title`).
- [x] 3.3 Create `lib/core/env/app_environment.dart` with a `const AppEnvironment` exposing `isDebug`, app name, and OS-specific data-path helper.
- [x] 3.4 Create `lib/core/error/failure.dart` with a sealed `Failure` and the named subtypes listed in design.md.
- [x] 3.5 Create `lib/core/error/result.dart` with the `Result<T>` sealed class (`Ok` / `Err`).
- [x] 3.6 Create `lib/core/logging/logger.dart` exposing `appLogger` configured against `package:logging`, with debug/release behavior described in design.md.

## 4. App shell, theming, and routing

- [x] 4.1 Create `lib/app/theme/app_theme.dart` building ForUI light and dark themes.
- [x] 4.2 Create `lib/app/state/theme_mode_provider.dart` — Riverpod `NotifierProvider<ThemeMode>` backed by `shared_preferences`, defaulting to `ThemeMode.system`.
- [x] 4.3 Create `lib/app/router/app_router.dart` with the routes from design.md, a `ShellRoute` providing the navigation chrome, and a fallback redirect to `/` for unknown paths.
- [x] 4.4 Create `lib/app/router/route_names.dart` with constants for each route path so feature code never hard-codes strings.
- [x] 4.5 Create `lib/app/app.dart` — `ProviderScope` + `FTheme` + `MaterialApp.router`, wiring the theme mode and router from steps 4.1–4.3.
- [x] 4.6 Build the navigation chrome: an `FSidebar` (or ForUI equivalent) for desktop widths and a fallback `FBottomNavigationBar` for narrow widths, switched via `LayoutBuilder`.
- [x] 4.7 Wire the Settings placeholder page to expose a real theme selector backed by `themeModeProvider` (the only non-placeholder feature in this change).
- [x] 4.8 Replace [lib/main.dart](../../../lib/main.dart) with a thin `main()` that configures `appLogger`, calls `WidgetsFlutterBinding.ensureInitialized()`, awaits `SharedPreferences.getInstance()`, and runs `App` inside `ProviderScope`.

## 5. Smoke test

- [x] 5.1 Replace [test/widget_test.dart](../../../test/widget_test.dart) with a smoke test that pumps `ProviderScope(child: App())` with a `themeModeProvider` override.
- [x] 5.2 Add assertions for: home placeholder rendered, navigation to Settings works, theme toggle from light → dark surfaces a dark-only widget by `Key`, deep link to `/settings` lands on the Settings route, unknown route redirects to `/`. _(deep link uses `GoRouter.of(context).go(...)` — exercises the same routing surface)_
- [x] 5.3 Confirm the test runs in under ~3 seconds locally so the `pre-commit-tests` hook stays cheap. _(4 tests run in ~1s)_

## 6. Documentation

- [x] 6.1 Update [README.md](../../../README.md) with the new folder layout, run/build commands, and dependency list.
- [x] 6.2 Update root [CLAUDE.md](../../../CLAUDE.md): note the new `lib/` layout, Riverpod + go_router + ForUI choices, the `Result`/`Failure` and logging conventions, and the trimmed cascading-CLAUDE list.
- [x] 6.3 Add or update [windows/CLAUDE.md](../../../windows/CLAUDE.md) with any Windows-specific notes uncovered during implementation (window sizing defaults, MSIX packaging stubs if any).
- [x] 6.4 If a ForUI default theme variant is chosen during implementation (open question in design.md), record the choice in root [CLAUDE.md](../../../CLAUDE.md). _(zinc — recorded in root CLAUDE.md)_

## 7. Verification gate

- [x] 7.1 `just format` clean. _(18 files, 0 changed)_
- [x] 7.2 `just analyze` clean. _(no issues)_
- [x] 7.3 `just test` green. _(4 tests in ~1s)_
- [ ] 7.4 `just run windows` opens the window into the Home placeholder; manually navigate to Search, Bookmarks, Settings, and MCP Status; toggle theme and restart to confirm persistence. _(left for human reviewer — Claude apply session cannot drive UI)_
- [ ] 7.5 `just check` green from a clean checkout (matches the pre-merge gate in design.md). _(deferred to human pre-merge gate; format + analyze + test all green individually this session)_

## 8. Ship

- [ ] 8.1 Open a draft PR titled `feat(foundation): bootstrap app shell, theming, routing` against `develop` with the OpenSpec change linked in the description.
- [ ] 8.2 Address review feedback on the branch only (no `--amend` of merged commits per [CLAUDE.md](../../../CLAUDE.md) policy).
- [ ] 8.3 Merge via the standard PR flow once `main`/`develop` checks pass.
- [ ] 8.4 Run `/opsx:archive` on this change to move it under `openspec/archive/`.
