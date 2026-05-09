## ADDED Requirements

### Requirement: Application launches into a themed shell

The application SHALL launch on Windows desktop and present a single top-level window themed with ForUI, with no dependency on the deleted counter demo.

#### Scenario: Cold start renders the home placeholder

- **WHEN** the application is launched via `flutter run -d windows` or the equivalent packaged binary
- **THEN** the window opens with the ForUI-themed shell and the Home (Surahs) placeholder route is rendered as the initial route

#### Scenario: Counter demo is removed

- **WHEN** the application is launched
- **THEN** no widget descended from the previous `MyHomePage` counter implementation is present anywhere in the widget tree

### Requirement: Top-level navigation skeleton is reachable

The application SHALL expose a navigation skeleton with one destination per top-level area in the IDEA.md MVP — Home/Surahs, Search, Bookmarks, Settings, and MCP Status — and SHALL allow the user to switch between them without errors.

#### Scenario: User navigates to each top-level destination

- **WHEN** the user activates each navigation destination in turn (Home, Search, Bookmarks, Settings, MCP Status)
- **THEN** each corresponding placeholder route is rendered, the destination becomes the active selection in the navigation chrome, and no exception is thrown

#### Scenario: Deep link to a top-level route

- **WHEN** the application is launched with a deep link to `/settings` (via `go_router`'s URL surface)
- **THEN** the Settings placeholder route is the initial route shown and the Settings destination is highlighted in the navigation chrome

#### Scenario: Unknown route falls back to home

- **WHEN** the user (or a test) navigates to a path that is not registered in the router
- **THEN** the router redirects to the Home (Surahs) placeholder route without throwing

### Requirement: Theme can be switched between light and dark

The application SHALL support light, dark, and system-driven theme modes, and the user SHALL be able to switch modes from the Settings route. The selected mode MUST persist across app restarts.

#### Scenario: User switches to dark mode

- **WHEN** the user selects "Dark" from the theme selector on the Settings route
- **THEN** the application theme switches to ForUI's dark theme on the next frame and a widget under a dark-only key is found in the tree

#### Scenario: Selected theme survives a restart

- **WHEN** the user has previously selected "Dark" mode and then relaunches the application
- **THEN** the application starts directly in dark mode without flashing the light theme

#### Scenario: Default theme follows system

- **WHEN** the user has never set a theme preference
- **THEN** the application uses `ThemeMode.system` and renders light or dark based on the operating system setting

### Requirement: Layered project structure is in place

The repository SHALL contain the layered folder structure under `lib/` that subsequent feature changes build into, and SHALL NOT contain the unsupported platform folders (`android/`, `ios/`, `web/`).

#### Scenario: Required folders exist

- **WHEN** the repository is checked out fresh after this change merges
- **THEN** the folders `lib/app/`, `lib/core/`, `lib/data/`, `lib/domain/`, and `lib/features/` all exist, and each contains at least one tracked file (source or `README.md` placeholder)

#### Scenario: Unsupported platform folders are removed

- **WHEN** the repository is checked out fresh after this change merges
- **THEN** the folders `android/`, `ios/`, and `web/` do not exist, and the corresponding platform flags do not appear in `pubspec.yaml`

### Requirement: Smoke test guards the shell

The repository SHALL include a Flutter widget test that boots the real `App` widget (with `ProviderScope`) and verifies the shell, navigation, and theme switch behave as specified. The test MUST be runnable via `flutter test` (and therefore `just test`) and MUST pass on a clean checkout.

#### Scenario: Smoke test passes on a clean checkout

- **WHEN** `flutter test test/widget_test.dart` is run on a clean checkout after this change merges
- **THEN** the test exits with code 0 and asserts the home placeholder, at least one non-home navigation destination, and the light-to-dark theme switch

#### Scenario: Pre-commit hook runs the smoke test

- **WHEN** a developer attempts a `git commit` and the [.claude/hooks/pre-commit-tests.ps1](../../../../.claude/hooks/pre-commit-tests.ps1) hook fires
- **THEN** the smoke test is included in the run and a failing test blocks the commit
